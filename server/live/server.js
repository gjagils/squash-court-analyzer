'use strict';
// Squash Analyzer — live meekijken (docs/plan-live-meekijken.md).
//
// The app creates a session, sends the whole match state after every rally and
// deletes the session when the match is over. Viewers follow it in the
// browser through Server-Sent Events. Nothing is written to disk: sessions live
// in memory only and hold first names and scores, and the players' photos as
// small thumbnails when the coach shares them; nothing else.
//
// No dependencies: node:http and node:crypto only.

const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const DEFAULTS = {
  port: Number(process.env.PORT || 8080),
  // Public base URL the app shares, e.g. https://live.squashanalyzer.com
  publicUrl: (process.env.PUBLIC_URL || '').replace(/\/+$/, ''),
  maxSessions: Number(process.env.MAX_SESSIONS || 200),
  maxBodyBytes: 4096,
  // Player photos (optional, sent once): a small JPEG thumbnail each
  maxPhotoBytes: 24 * 1024,
  // A session nobody updates for this long is removed (lost phone, no network)
  idleMs: Number(process.env.IDLE_MINUTES || 120) * 60 * 1000,
  // Session creations per IP per minute, and in total
  createsPerMinute: Number(process.env.CREATES_PER_MINUTE || 10),
  globalCreatesPerMinute: Number(process.env.GLOBAL_CREATES_PER_MINUTE || 60),
  // Viewers (open SSE streams) per session and in total
  maxViewersPerSession: Number(process.env.MAX_VIEWERS_PER_SESSION || 200),
  maxViewers: Number(process.env.MAX_VIEWERS || 2000),
  // Only behind a proxy we control (Cloudflare Tunnel) may the client IP come
  // from a header; otherwise anyone could pick a new IP per request
  trustProxy: process.env.TRUST_PROXY === '1',
  sweepMs: 60 * 1000,
};

const STATUSES = new Set(['warmup', 'playing', 'between', 'finished']);
const NAME_MAX = 20;
const LAST_POINT_MAX = 80;

/** First name only, letters/hyphen/apostrophe, as LiveSnapshot.firstName in the app */
function cleanName(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const first = value.trim().split(/\s+/)[0] || '';
  const kept = Array.from(first).filter((c) => /\p{L}|[-']/u.test(c)).join('').slice(0, NAME_MAX);
  return kept || fallback;
}

/** A base64 JPEG thumbnail as a Buffer, or null (wrong type, not a JPEG, too large) */
function cleanPhoto(value, maxBytes) {
  if (typeof value !== 'string' || value.length > Math.ceil(maxBytes / 3) * 4 + 4) return null;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return null;
  const bytes = Buffer.from(value, 'base64');
  if (bytes.length < 4 || bytes.length > maxBytes) return null;
  // JPEG starts with FF D8 FF
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) return null;
  return bytes;
}

function cleanInt(value, min, max) {
  const n = Number(value);
  if (!Number.isInteger(n) || n < min || n > max) return null;
  return n;
}

function cleanPair(value, max) {
  if (!Array.isArray(value) || value.length !== 2) return null;
  const a = cleanInt(value[0], 0, max);
  const b = cleanInt(value[1], 0, max);
  return a === null || b === null ? null : [a, b];
}

/**
 * Validates a snapshot from the app and returns a clean copy, or null. Only
 * known fields survive, so nothing else the app might send is ever served.
 */
function validateSnapshot(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  const bestOf = cleanInt(input.bestOf, 1, 7);
  const score = cleanPair(input.score, 99);
  const gamesWon = cleanPair(input.gamesWon, 7);
  const server = cleanInt(input.server, 1, 2);
  if (bestOf === null || score === null || gamesWon === null || server === null) return null;
  if (!STATUSES.has(input.status)) return null;
  if (input.side !== 'L' && input.side !== 'R') return null;
  if (!Array.isArray(input.games) || input.games.length > 7) return null;
  const games = [];
  for (const game of input.games) {
    const pair = cleanPair(game, 99);
    if (!pair) return null;
    games.push(pair);
  }
  const snapshot = {
    p1: cleanName(input.p1, 'Speler 1'),
    p2: cleanName(input.p2, 'Speler 2'),
    bestOf, games, score, gamesWon, server, side: input.side, status: input.status,
  };
  if (typeof input.lastPoint === 'string' && input.lastPoint.trim()) {
    snapshot.lastPoint = input.lastPoint.trim().slice(0, LAST_POINT_MAX);
  }
  const winner = cleanInt(input.winner, 1, 2);
  if (winner !== null) snapshot.winner = winner;
  return snapshot;
}

function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function createLiveServer(options = {}) {
  const config = { ...DEFAULTS, ...options };
  const now = options.now || (() => Date.now());
  /** id -> { key, snapshot, updatedAt, viewers: Set<res> } */
  const sessions = new Map();
  /** ip -> [timestamps] */
  const creates = new Map();
  /** All creations, for the global limit */
  let allCreates = [];
  const viewerPage = fs.readFileSync(path.join(__dirname, 'public', 'live.html'), 'utf8');

  function newId() {
    // 12 characters from an unambiguous alphabet: not guessable, easy to read aloud
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    const bytes = crypto.randomBytes(12);
    let id = '';
    for (const b of bytes) id += alphabet[b % alphabet.length];
    return id;
  }

  function send(res, status, body, headers = {}) {
    const isJson = body !== undefined && typeof body !== 'string';
    res.writeHead(status, {
      'Content-Type': isJson ? 'application/json; charset=utf-8' : 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...headers,
    });
    res.end(body === undefined ? '' : isJson ? JSON.stringify(body) : body);
  }

  function readBody(req, limit = config.maxBodyBytes) {
    return new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on('data', (chunk) => {
        size += chunk.length;
        // Too large: keep reading (so the client gets the answer) but keep nothing
        if (size <= limit) chunks.push(chunk);
      });
      req.on('end', () => {
        if (size > limit) return reject(Object.assign(new Error('Te groot'), { status: 413 }));
        if (size === 0) return resolve(null);
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
        } catch {
          reject(Object.assign(new Error('bad json'), { status: 400 }));
        }
      });
      req.on('error', reject);
    });
  }

  function authorized(req, session) {
    const header = req.headers.authorization || '';
    const given = Buffer.from(header.startsWith('Bearer ') ? header.slice(7) : '');
    const expected = Buffer.from(session.key);
    return given.length === expected.length && crypto.timingSafeEqual(given, expected);
  }

  /** What viewers get with every state: whether there is a photo per player, and its version (for the image URL) */
  function stateMessage(session) {
    return {
      snapshot: session.snapshot,
      updatedAt: session.updatedAt,
      photos: [Boolean(session.photos[0]), Boolean(session.photos[1])],
      photoVersion: session.photoVersion,
    };
  }

  function broadcast(session, event, data) {
    const message = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const viewer of session.viewers) viewer.write(message);
  }

  function removeSession(id, reason) {
    const session = sessions.get(id);
    if (!session) return false;
    // Viewers keep the last state on their page; they learn the session is gone
    broadcast(session, 'ended', { reason, snapshot: session.snapshot });
    for (const viewer of session.viewers) viewer.end();
    sessions.delete(id);
    return true;
  }

  function sweep() {
    const cutoff = now() - config.idleMs;
    for (const [id, session] of sessions) {
      if (session.updatedAt < cutoff) removeSession(id, 'idle');
    }
    const minuteAgo = now() - 60 * 1000;
    for (const [ip, times] of creates) {
      const recent = times.filter((t) => t > minuteAgo);
      if (recent.length) creates.set(ip, recent); else creates.delete(ip);
    }
    allCreates = allCreates.filter((t) => t > minuteAgo);
  }

  function allowCreate(ip) {
    const minuteAgo = now() - 60 * 1000;
    allCreates = allCreates.filter((t) => t > minuteAgo);
    if (allCreates.length >= config.globalCreatesPerMinute) return false;
    const recent = (creates.get(ip) || []).filter((t) => t > minuteAgo);
    if (recent.length >= config.createsPerMinute) return false;
    recent.push(now());
    creates.set(ip, recent);
    allCreates.push(now());
    return true;
  }

  function clientIp(req) {
    if (config.trustProxy) {
      // Cloudflare Tunnel: the visitor is in CF-Connecting-IP (also first in X-Forwarded-For)
      const cf = String(req.headers['cf-connecting-ip'] || '').trim();
      if (cf) return cf;
      // On purpose (docs/bewuste-keuzes.md): a plain reverse proxy (README) only sends X-Forwarded-For
      const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
      if (forwarded) return forwarded;
    }
    return req.socket.remoteAddress || 'unknown';
  }

  function viewerCount() {
    let count = 0;
    for (const session of sessions.values()) count += session.viewers.size;
    return count;
  }

  /** Stopping (container restart): viewers learn the session ended, then everything closes */
  function shutdown(callback) {
    for (const id of Array.from(sessions.keys())) removeSession(id, 'restart');
    server.close(callback);
    if (typeof server.closeAllConnections === 'function') server.closeAllConnections();
  }

  function baseUrl(req) {
    if (config.publicUrl) return config.publicUrl;
    const proto = String(req.headers['x-forwarded-proto'] || 'http').split(',')[0].trim();
    return `${proto}://${req.headers.host}`;
  }

  function viewerHtml(req, id) {
    const session = sessions.get(id);
    const title = session
      ? `🔴 Live: ${session.snapshot.p1} – ${session.snapshot.p2}`
      : 'SquashAnalyzer · live';
    const description = session ? 'Volg de wedstrijd live in SquashAnalyzer' : 'Deze livewedstrijd is afgelopen.';
    return viewerPage
      .replaceAll('{{TITLE}}', escapeHtml(title))
      .replaceAll('{{DESCRIPTION}}', escapeHtml(description))
      .replaceAll('{{URL}}', escapeHtml(`${baseUrl(req)}/l/${id}`))
      .replaceAll('{{IMAGE}}', escapeHtml(`${baseUrl(req)}/logo.png`))
      // In a script: a JSON string literal, "<" escaped so it cannot end the tag
      .replaceAll('{{ID_JSON}}', JSON.stringify(id).replace(/</g, '\\u003c'));
  }

  async function handle(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const parts = url.pathname.split('/').filter(Boolean);

    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, 200, { ok: true, sessions: sessions.size });
    }
    if (req.method === 'GET' && url.pathname === '/logo.png') {
      const file = path.join(__dirname, 'public', 'logo.png');
      if (!fs.existsSync(file)) return send(res, 404, 'Not found');
      res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=86400' });
      return fs.createReadStream(file).pipe(res);
    }
    if (req.method === 'GET' && parts[0] === 'l' && parts.length === 2) {
      // Only ids this server could have made reach the page (and its script)
      const pageId = /^[a-z0-9]{12}$/.test(parts[1]) ? parts[1] : '';
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
        'Referrer-Policy': 'no-referrer',
        'Content-Security-Policy': "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:",
      });
      return res.end(viewerHtml(req, pageId));
    }

    if (parts[0] !== 'api' || parts[1] !== 'live') return send(res, 404, 'Not found');
    const id = parts[2];

    // POST /api/live: new session
    if (req.method === 'POST' && parts.length === 2) {
      if (!allowCreate(clientIp(req))) return send(res, 429, { error: 'Te veel nieuwe sessies, probeer het zo opnieuw' });
      if (sessions.size >= config.maxSessions) return send(res, 503, { error: 'Even geen ruimte voor nieuwe livewedstrijden' });
      const snapshot = validateSnapshot(await readBody(req));
      if (!snapshot) return send(res, 400, { error: 'Ongeldige stand' });
      let newSessionId = newId();
      while (sessions.has(newSessionId)) newSessionId = newId();
      const key = crypto.randomBytes(32).toString('base64url');
      sessions.set(newSessionId, { key, snapshot, updatedAt: now(), viewers: new Set(), photos: [null, null], photoVersion: 0 });
      return send(res, 201, { id: newSessionId, writeKey: key, url: `${baseUrl(req)}/l/${newSessionId}` });
    }

    if (!id || parts.length > 5) return send(res, 404, 'Not found');
    const session = sessions.get(id);

    // GET /api/live/:id/photo/1 or 2: a player's thumbnail, for the viewer page
    if (req.method === 'GET' && parts[3] === 'photo' && parts.length === 5) {
      const index = parts[4] === '1' ? 0 : parts[4] === '2' ? 1 : -1;
      const photo = session && index >= 0 ? session.photos[index] : null;
      if (!photo) return send(res, 404, 'Not found');
      res.writeHead(200, {
        'Content-Type': 'image/jpeg',
        'Content-Length': photo.length,
        // Not kept by browsers or Cloudflare: gone with the session
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      });
      return res.end(photo);
    }
    if (parts.length === 5) return send(res, 404, 'Not found');

    // GET /api/live/:id/events: Server-Sent Events for viewers
    if (req.method === 'GET' && parts[3] === 'events') {
      if (!session) return send(res, 404, { error: 'Afgelopen' });
      if (session.viewers.size >= config.maxViewersPerSession || viewerCount() >= config.maxViewers) {
        return send(res, 503, { error: 'Te veel kijkers, probeer het zo opnieuw' });
      }
      res.writeHead(200, {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-store',
        Connection: 'keep-alive',
        // nginx and friends: do not buffer the stream
        'X-Accel-Buffering': 'no',
      });
      res.write('retry: 3000\n\n');
      res.write(`event: state\ndata: ${JSON.stringify(stateMessage(session))}\n\n`);
      session.viewers.add(res);
      const ping = setInterval(() => res.write(': ping\n\n'), 25000);
      req.on('close', () => {
        clearInterval(ping);
        session.viewers.delete(res);
      });
      return undefined;
    }
    if (parts.length !== 3 && !(parts.length === 4 && parts[3] === 'photos')) return send(res, 404, 'Not found');

    // GET /api/live/:id: current state
    if (req.method === 'GET' && parts.length === 3) {
      if (!session) return send(res, 404, { error: 'Afgelopen' });
      return send(res, 200, stateMessage(session));
    }
    if (!session) return send(res, 404, { error: 'Onbekende sessie' });
    if (!authorized(req, session)) return send(res, 401, { error: 'Geen toegang' });

    // PUT /api/live/:id/photos: the players' thumbnails, once after creating
    // ({ p1, p2 }: base64 JPEG or null; a missing or invalid one is no photo)
    if (req.method === 'PUT' && parts[3] === 'photos') {
      const body = await readBody(req, config.maxPhotoBytes * 3);
      if (!body || typeof body !== 'object') return send(res, 400, { error: 'Ongeldige foto\'s' });
      session.photos = [cleanPhoto(body.p1, config.maxPhotoBytes), cleanPhoto(body.p2, config.maxPhotoBytes)];
      session.photoVersion += 1;
      broadcast(session, 'state', stateMessage(session));
      return send(res, 204);
    }
    if (parts.length !== 3) return send(res, 404, 'Not found');

    // PUT /api/live/:id: the whole new state
    if (req.method === 'PUT') {
      const snapshot = validateSnapshot(await readBody(req));
      if (!snapshot) return send(res, 400, { error: 'Ongeldige stand' });
      session.snapshot = snapshot;
      session.updatedAt = now();
      broadcast(session, 'state', stateMessage(session));
      return send(res, 204);
    }

    // DELETE /api/live/:id: match over, gone at once
    if (req.method === 'DELETE') {
      removeSession(id, 'finished');
      return send(res, 204);
    }
    return send(res, 405, 'Method not allowed');
  }

  const server = http.createServer((req, res) => {
    handle(req, res).catch((error) => {
      if (!res.headersSent) send(res, error.status || 500, { error: error.status ? error.message : 'Serverfout' });
    });
  });
  // Log method, path without the session id, and status only: no scores, no names
  server.on('request', (req, res) => {
    res.on('finish', () => {
      if (options.quiet) return;
      const pathOnly = req.url.split('?')[0].replace(/^\/(l|api\/live)\/[^/]+/, '/$1/:id');
      console.log(`${req.method} ${pathOnly} ${res.statusCode}`);
    });
  });
  const timer = setInterval(sweep, config.sweepMs);
  timer.unref();
  server.on('close', () => clearInterval(timer));
  return { server, sessions, sweep, config, shutdown };
}

module.exports = { createLiveServer, validateSnapshot, cleanName, cleanPhoto };

if (require.main === module) {
  const { server, config, shutdown } = createLiveServer();
  server.listen(config.port, () => console.log(`squash-live listening on ${config.port}`));
  const stop = () => shutdown(() => process.exit(0));
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}
