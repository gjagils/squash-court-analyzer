// Squash Analyzer — live meekijken on Cloudflare Workers (the beta of
// server/live). Same API as the Node version: the app creates a session,
// sends the whole match state after every rally and deletes the session when
// the match is over; viewers follow it in the browser through Server-Sent
// Events. One Durable Object per session holds the state (see session.js),
// one more counts creations and sessions (limiter.js). Nothing leaves
// Cloudflare's edge, and a session is gone two hours after its last update.

import {
  cleanPhoto, escapeHtml, ID_PATTERN, MAX_PHOTO_BYTES, newSessionId, newWriteKey, readJson, SLOTS, validatePartij,
  validateSnapshot, validateTeamHeader,
} from './validate.js';
import { readConfig } from './config.js';

export { LiveSession } from './session.js';
export { LiveLimiter } from './limiter.js';
export { TeamSession } from './team.js';

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

/** A viewer page from the static assets, with the link preview filled in */
async function renderPage(request, template, title, description, pageUrl, imageUrl, idJson) {
  const html = template
    .replaceAll('{{TITLE}}', escapeHtml(title))
    .replaceAll('{{DESCRIPTION}}', escapeHtml(description))
    .replaceAll('{{URL}}', escapeHtml(pageUrl))
    .replaceAll('{{IMAGE}}', escapeHtml(imageUrl))
    // In a script: a JSON string literal, "<" escaped so it cannot end the tag
    .replaceAll('{{ID_JSON}}', idJson.replace(/</g, '\\u003c'));
  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      'Content-Security-Policy': "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self'; frame-ancestors 'none'",
    },
  });
}

async function viewerPage(request, env, config, id, state) {
  const template = await (await env.ASSETS.fetch(new Request(new URL('/live.html', request.url)))).text();
  const title = state ? `🔴 Live: ${state.snapshot.p1} – ${state.snapshot.p2}` : 'SquashAnalyzer · live';
  const description = state ? 'Volg de wedstrijd live in SquashAnalyzer' : 'Deze livewedstrijd is afgelopen.';
  const base = baseUrl(request, config);
  return renderPage(request, template, title, description, `${base}/l/${id}`, `${base}/logo.png`, JSON.stringify(id));
}

/** The team match page: "🔴 Live: All Inn Squash 8 – Squash Delft 8 · 5-3" */
async function teamPage(request, env, config, id, state) {
  const template = await (await env.ASSETS.fetch(new Request(new URL('/team.html', request.url)))).text();
  let title = 'SquashAnalyzer · teamwedstrijd';
  let description = 'Deze teamwedstrijd is afgelopen.';
  if (state) {
    let home = 0;
    let away = 0;
    for (const slot of SLOTS) {
      const partij = state.partijen[slot];
      if (partij) { home += partij.gamesWon[0]; away += partij.gamesWon[1]; }
    }
    title = `🔴 Live: ${state.team.home} – ${state.team.away} · ${home}-${away}`;
    description = 'Volg de teamwedstrijd live in SquashAnalyzer';
  }
  const base = baseUrl(request, config);
  return renderPage(request, template, title, description, `${base}/t/${id}`, `${base}/logo.png`, JSON.stringify(id));
}

async function handle(request, env) {
  const config = readConfig(env);
  const url = new URL(request.url);
  const parts = url.pathname.split('/').filter(Boolean);
  const limiter = env.LIMITER.get(env.LIMITER.idFromName('global'));
  // The wedstrijd data (names, photos, the stand) stays in the jurisdiction of
  // LIVE_JURISDICTION ("eu"); sessions made before this setting are not found
  const where = (namespace) => (config.jurisdiction ? namespace.jurisdiction(config.jurisdiction) : namespace);
  const sessionFor = (id) => where(env.SESSION).get(where(env.SESSION).idFromName(id));
  const teamFor = (id) => where(env.TEAM).get(where(env.TEAM).idFromName(id));

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

  if (request.method === 'GET' && parts[0] === 't' && parts.length === 2) {
    const pageId = ID_PATTERN.test(parts[1]) ? parts[1] : '';
    const state = pageId ? await teamFor(pageId).state() : null;
    return teamPage(request, env, config, pageId, state);
  }
  if (parts[0] === 'api' && parts[1] === 'team') return handleTeam(request, env, config, parts, limiter, teamFor);

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
    // An id already in use (practically never): pick another. The colliding id
    // belongs to the session that has it: it is not released here.
    while (!(await sessionFor(newId).create(key, snapshot, newId))) {
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

/**
 * /api/team: a live team match (Competitie). POST makes one (id, team key for
 * the invitation, owner key for the starter, viewer link); every phone with the
 * team key PUTs its partij to /api/team/:id/partij/:slot; only the owner key
 * changes the team names (PUT) or ends it (DELETE); GET /verify tells what a key
 * may do; viewers read it or follow /events.
 */
async function handleTeam(request, env, config, parts, limiter, teamFor) {
  const id = parts[2];

  // POST /api/team: a new team match
  if (request.method === 'POST' && parts.length === 2) {
    const ip = request.headers.get('cf-connecting-ip') || 'unknown';
    if (!(await limiter.allowCreate(ip))) return send(429, { error: 'Te veel nieuwe sessies, probeer het zo opnieuw' });
    const team = validateTeamHeader(await readJson(request));
    if (!team) return send(400, { error: 'Ongeldige teamwedstrijd' });
    let newId = newSessionId();
    const key = newWriteKey();
    const ownerKey = newWriteKey();
    if (!(await limiter.register(`t:${newId}`))) return send(503, { error: 'Even geen ruimte voor nieuwe livewedstrijden' });
    while (!(await teamFor(newId).create(key, ownerKey, team, newId))) {
      newId = newSessionId();
      if (!(await limiter.register(`t:${newId}`))) return send(503, { error: 'Even geen ruimte voor nieuwe livewedstrijden' });
    }
    return send(201, { id: newId, writeKey: key, ownerKey, url: `${baseUrl(request, config)}/t/${newId}` });
  }

  if (!id || !ID_PATTERN.test(id) || parts.length > 5) return send(404, 'Not found');
  const session = teamFor(id);

  // GET /api/team/:id/verify: does this key work, and what may it do ("owner" or "writer")
  if (request.method === 'GET' && parts[3] === 'verify' && parts.length === 4) {
    const role = await session.role(bearer(request));
    if (role === 404) return send(404, { error: 'Onbekende teamwedstrijd' });
    if (role === 401) return send(401, { error: 'Geen toegang' });
    return send(200, { role });
  }

  // GET /api/team/:id/events: Server-Sent Events for viewers
  if (request.method === 'GET' && parts[3] === 'events' && parts.length === 4) {
    return session.fetch(new Request(new URL('/events', request.url), { headers: request.headers, signal: request.signal }));
  }

  // GET /api/team/:id: the current state
  if (request.method === 'GET' && parts.length === 3) {
    const state = await session.state();
    return state ? send(200, state) : send(404, { error: 'Afgelopen' });
  }

  const key = bearer(request);
  const answer = (status) => {
    if (status === 404) return send(404, { error: 'Onbekende teamwedstrijd' });
    if (status === 401) return send(401, { error: 'Geen toegang' });
    return send(204);
  };

  // PUT /api/team/:id/partij/:slot: one partij of this phone
  if (request.method === 'PUT' && parts[3] === 'partij' && parts.length === 5) {
    const slot = Number(parts[4]);
    if (!SLOTS.includes(slot)) return send(404, 'Not found');
    const partij = validatePartij(await readJson(request));
    if (!partij) return send(400, { error: 'Ongeldige partij' });
    return answer(await session.setPartij(key, slot, partij));
  }
  if (parts.length !== 3) return send(404, 'Not found');

  // PUT /api/team/:id: new team names or day
  if (request.method === 'PUT') {
    const team = validateTeamHeader(await readJson(request));
    if (!team) return send(400, { error: 'Ongeldige teamwedstrijd' });
    return answer(await session.setTeam(key, team));
  }

  // DELETE /api/team/:id: live stopped, gone at once
  if (request.method === 'DELETE') return answer(await session.remove(key));
  return send(405, 'Method not allowed');
}

export default {
  async fetch(request, env) {
    try {
      return await handle(request, env);
    } catch (error) {
      // A failure the client did not cause is logged (Observability shows it, without request data)
      if (!error.status) console.error('worker error', error && error.message);
      return send(error.status || 500, { error: error.status ? error.message : 'Serverfout' });
    }
  },
};
