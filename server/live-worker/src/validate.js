// Squash Analyzer — live meekijken on Cloudflare Workers: input checks.
// The same rules as server/live/server.js (the Node version), without Buffer:
// only known fields survive, names are first names, photos are small JPEGs.

export const STATUSES = new Set(['warmup', 'playing', 'between', 'finished']);
export const NAME_MAX = 20;
export const LAST_POINT_MAX = 80;
export const MAX_BODY_BYTES = 4096;
export const MAX_PHOTO_BYTES = 24 * 1024;

/** First name only, letters/hyphen/apostrophe, as LiveSnapshot.firstName in the app */
export function cleanName(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const first = value.trim().split(/\s+/)[0] || '';
  const kept = Array.from(first).filter((c) => /\p{L}|[-']/u.test(c)).join('').slice(0, NAME_MAX);
  return kept || fallback;
}

/** A base64 JPEG thumbnail as a Uint8Array, or null (wrong type, not a JPEG, too large) */
export function cleanPhoto(value, maxBytes = MAX_PHOTO_BYTES) {
  if (typeof value !== 'string' || value.length > Math.ceil(maxBytes / 3) * 4 + 4) return null;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return null;
  let binary;
  try {
    binary = atob(value);
  } catch {
    return null;
  }
  if (binary.length < 4 || binary.length > maxBytes) return null;
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
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
export function validateSnapshot(input) {
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

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/**
 * Reads a JSON body of at most `limit` bytes. Throws { status: 413 } when
 * larger, { status: 400 } when not JSON; resolves null for an empty body.
 */
export async function readJson(request, limit = MAX_BODY_BYTES) {
  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length > limit) throw Object.assign(new Error('Te groot'), { status: 413 });
  if (bytes.length === 0) return null;
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw Object.assign(new Error('bad json'), { status: 400 });
  }
}

/** Constant-time comparison of the write key from the Authorization header */
export function keyMatches(request, expected) {
  const header = request.headers.get('authorization') || '';
  const given = header.startsWith('Bearer ') ? header.slice(7) : '';
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected || '');
  if (a.length !== b.length || a.length === 0) return false;
  return crypto.subtle.timingSafeEqual(a, b);
}

/** 12 characters from an unambiguous alphabet: not guessable, easy to read aloud */
export function newSessionId() {
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  let id = '';
  for (const b of bytes) id += alphabet[b % alphabet.length];
  return id;
}

export function newWriteKey() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export const ID_PATTERN = /^[a-z0-9]{12}$/;
