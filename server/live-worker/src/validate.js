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
  const tooLarge = () => Object.assign(new Error('Te groot'), { status: 413 });
  // Refuse on the announced size before anything is read, and read a body
  // without (or with a wrong) length in pieces, stopping at the limit
  const declared = Number(request.headers.get('content-length'));
  if (Number.isFinite(declared) && declared > limit) throw tooLarge();
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > limit) {
      await reader.cancel();
      throw tooLarge();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  if (bytes.length === 0) return null;
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw Object.assign(new Error('bad json'), { status: 400 });
  }
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

// ---- Teamwedstrijden (Competitie) --------------------------------------------

export const TEAM_NAME_MAX = 40;
export const SLOTS = [1, 2, 3, 4];

/** A team name: letters, digits, spaces and a few marks; "Squash Delft 8". Not a person, so no first-name rule. */
export function cleanTeamName(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const kept = Array.from(value).filter((c) => /[\p{L}\p{N}]|[ \-'.&()+]/u.test(c)).join('').replace(/\s+/g, ' ').trim();
  return kept.slice(0, TEAM_NAME_MAX) || fallback;
}

/** A first name for a partij, or '' when the app has none (the page then shows "Delft 8 E1") */
export function cleanPartijName(value) {
  if (typeof value !== 'string' || !value.trim()) return '';
  return cleanName(value, '');
}

/** The team match itself: both team names and the day (milliseconds or ISO text), or null */
export function validateTeamHeader(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  const home = cleanTeamName(input.home, '');
  const away = cleanTeamName(input.away, '');
  if (!home || !away) return null;
  let date = typeof input.date === 'number' ? input.date : Date.parse(String(input.date || ''));
  const now = Date.now();
  if (!Number.isFinite(date) || Math.abs(date - now) > 2 * 365 * 24 * 3600 * 1000) date = now;
  return { home, away, date: Math.round(date) };
}

/**
 * One partij of a team match, home player first (p1 = home). Like a snapshot
 * but the names may be empty, and a hand-filled partij has fewer games than
 * games won (their scores are unknown). `{ empty: true }` clears the slot.
 */
export function validatePartij(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  if (input.empty === true) return { empty: true };
  const bestOf = input.bestOf === undefined ? 5 : cleanInt(input.bestOf, 1, 7);
  const gamesWon = cleanPair(input.gamesWon, 7);
  const score = input.score === undefined ? [0, 0] : cleanPair(input.score, 99);
  const server = input.server === undefined ? 1 : cleanInt(input.server, 1, 2);
  const side = input.side === undefined ? 'R' : input.side;
  if (bestOf === null || gamesWon === null || score === null || server === null) return null;
  // A partij is decided at the games to win: nobody has more, and not both have them
  const toWin = Math.floor(bestOf / 2) + 1;
  if (gamesWon[0] > toWin || gamesWon[1] > toWin || (gamesWon[0] === toWin && gamesWon[1] === toWin)) return null;
  if (!STATUSES.has(input.status)) return null;
  if (side !== 'L' && side !== 'R') return null;
  const gamesInput = input.games === undefined ? [] : input.games;
  if (!Array.isArray(gamesInput) || gamesInput.length > 7) return null;
  const games = [];
  for (const game of gamesInput) {
    const pair = cleanPair(game, 99);
    if (!pair) return null;
    games.push(pair);
  }
  const partij = {
    p1: cleanPartijName(input.p1), p2: cleanPartijName(input.p2),
    bestOf, games, score, gamesWon, server, side, status: input.status,
  };
  if (typeof input.lastPoint === 'string' && input.lastPoint.trim()) {
    partij.lastPoint = input.lastPoint.trim().slice(0, LAST_POINT_MAX);
  }
  const winner = cleanInt(input.winner, 1, 2);
  if (winner !== null) partij.winner = winner;
  return partij;
}
