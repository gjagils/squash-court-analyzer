// Squash Analyzer — live meekijken on Cloudflare Workers (the beta of
// server/live). Same API as the Node version: the app creates a session,
// sends the whole match state after every rally and deletes the session when
// the match is over; viewers follow it in the browser through Server-Sent
// Events. One Durable Object per session holds the state (see session.js),
// one more counts creations and sessions (limiter.js). Nothing leaves
// Cloudflare's edge, and a session is gone two hours after its last update.

import {
  cleanPhoto, escapeHtml, ID_PATTERN, MAX_PHOTO_BYTES, newSessionId, newWriteKey, readJson, validateSnapshot,
} from './validate.js';
import { readConfig } from './config.js';

export { LiveSession } from './session.js';
export { LiveLimiter } from './limiter.js';

const JSON_HEADERS = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

function send(status, body, headers = {}) {
  const isJson = body !== undefined && typeof body !== 'string';
  return new Response(body === undefined ? null : isJson ? JSON.stringify(body) : body, {
    status,
    headers: { ...JSON_HEADERS, ...(isJson ? {} : { 'Content-Type': 'text/plain; charset=utf-8' }), ...headers },
  });
}

function bearer(request) {
  const header = request.headers.get('authorization') || '';
  return header.startsWith('Bearer ') ? header.slice(7) : '';
}

function baseUrl(request, config) {
  if (config.publicUrl) return config.publicUrl;
  const url = new URL(request.url);
  return `${url.protocol}//${url.host}`;
}

/** The viewer page from the static assets, with the link preview filled in */
async function viewerPage(request, env, config, id, state) {
  const template = await (await env.ASSETS.fetch(new Request(new URL('/live.html', request.url)))).text();
  const title = state ? `🔴 Live: ${state.snapshot.p1} – ${state.snapshot.p2}` : 'SquashAnalyzer · live';
  const description = state ? 'Volg de wedstrijd live in SquashAnalyzer' : 'Deze livewedstrijd is afgelopen.';
  const base = baseUrl(request, config);
  const html = template
    .replaceAll('{{TITLE}}', escapeHtml(title))
    .replaceAll('{{DESCRIPTION}}', escapeHtml(description))
    .replaceAll('{{URL}}', escapeHtml(`${base}/l/${id}`))
    .replaceAll('{{IMAGE}}', escapeHtml(`${base}/logo.png`))
    // In a script: a JSON string literal, "<" escaped so it cannot end the tag
    .replaceAll('{{ID_JSON}}', JSON.stringify(id).replace(/</g, '\\u003c'));
  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      'Content-Security-Policy': "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:",
    },
  });
}

async function handle(request, env) {
  const config = readConfig(env);
  const url = new URL(request.url);
  const parts = url.pathname.split('/').filter(Boolean);
  const limiter = env.LIMITER.get(env.LIMITER.idFromName('global'));
  const sessionFor = (id) => env.SESSION.get(env.SESSION.idFromName(id));

  if (request.method === 'GET' && url.pathname === '/health') {
    return send(200, { ok: true, sessions: await limiter.count() });
  }
  if (request.method === 'GET' && url.pathname === '/logo.png') {
    return env.ASSETS.fetch(request);
  }
  if (request.method === 'GET' && parts[0] === 'l' && parts.length === 2) {
    // Only ids this server could have made reach the page (and its script)
    const pageId = ID_PATTERN.test(parts[1]) ? parts[1] : '';
    const state = pageId ? await sessionFor(pageId).state() : null;
    return viewerPage(request, env, config, pageId, state);
  }

  if (parts[0] !== 'api' || parts[1] !== 'live') return send(404, 'Not found');
  const id = parts[2];

  // POST /api/live: new session
  if (request.method === 'POST' && parts.length === 2) {
    // Cloudflare sets CF-Connecting-IP itself; nobody can forge it here
    const ip = request.headers.get('cf-connecting-ip') || 'unknown';
    if (!(await limiter.allowCreate(ip))) return send(429, { error: 'Te veel nieuwe sessies, probeer het zo opnieuw' });
    const snapshot = validateSnapshot(await readJson(request));
    if (!snapshot) return send(400, { error: 'Ongeldige stand' });
    let newId = newSessionId();
    const key = newWriteKey();
    if (!(await limiter.register(newId))) return send(503, { error: 'Even geen ruimte voor nieuwe livewedstrijden' });
    // An id already in use (practically never): pick another
    while (!(await sessionFor(newId).create(key, snapshot))) {
      await limiter.release(newId);
      newId = newSessionId();
      if (!(await limiter.register(newId))) return send(503, { error: 'Even geen ruimte voor nieuwe livewedstrijden' });
    }
    return send(201, { id: newId, writeKey: key, url: `${baseUrl(request, config)}/l/${newId}` });
  }

  if (!id || !ID_PATTERN.test(id) || parts.length > 5) return send(404, 'Not found');
  const session = sessionFor(id);

  // GET /api/live/:id/photo/1 or 2: a player's thumbnail, for the viewer page
  if (request.method === 'GET' && parts[3] === 'photo' && parts.length === 5) {
    const index = parts[4] === '1' ? 1 : parts[4] === '2' ? 2 : 0;
    const photo = index ? await session.photo(index) : null;
    if (!photo) return send(404, 'Not found');
    return new Response(photo, {
      status: 200,
      headers: {
        'Content-Type': 'image/jpeg',
        'Content-Length': String(photo.byteLength),
        // Not kept by browsers or Cloudflare: gone with the session
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      },
    });
  }
  if (parts.length === 5) return send(404, 'Not found');

  // GET /api/live/:id/events: Server-Sent Events for viewers, served by the session itself
  if (request.method === 'GET' && parts[3] === 'events') {
    return session.fetch(new Request(new URL('/events', request.url), { headers: request.headers, signal: request.signal }));
  }
  if (parts.length !== 3 && !(parts.length === 4 && parts[3] === 'photos')) return send(404, 'Not found');

  // GET /api/live/:id: current state
  if (request.method === 'GET' && parts.length === 3) {
    const state = await session.state();
    return state ? send(200, state) : send(404, { error: 'Afgelopen' });
  }

  const key = bearer(request);
  const answer = (status) => {
    if (status === 404) return send(404, { error: 'Onbekende sessie' });
    if (status === 401) return send(401, { error: 'Geen toegang' });
    return send(204);
  };

  // PUT /api/live/:id/photos: the players' thumbnails, once after creating
  // ({ p1, p2 }: base64 JPEG or null; a missing or invalid one is no photo)
  if (request.method === 'PUT' && parts[3] === 'photos') {
    const body = await readJson(request, MAX_PHOTO_BYTES * 3);
    if (!body || typeof body !== 'object') return send(400, { error: "Ongeldige foto's" });
    return answer(await session.setPhotos(key, cleanPhoto(body.p1), cleanPhoto(body.p2)));
  }
  if (parts.length !== 3) return send(404, 'Not found');

  // PUT /api/live/:id: the whole new state
  if (request.method === 'PUT') {
    const snapshot = validateSnapshot(await readJson(request));
    if (!snapshot) return send(400, { error: 'Ongeldige stand' });
    return answer(await session.update(key, snapshot));
  }

  // DELETE /api/live/:id: match over, gone at once
  if (request.method === 'DELETE') {
    return answer(await session.remove(key));
  }
  return send(405, 'Method not allowed');
}

export default {
  async fetch(request, env) {
    try {
      return await handle(request, env);
    } catch (error) {
      return send(error.status || 500, { error: error.status ? error.message : 'Serverfout' });
    }
  },
};
