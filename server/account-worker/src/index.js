// Squash Analyzer 4.0: the player account (docs/voorstel-spelersaccount-4.0.md).
//
// Anyone may send a match for a player, with a device key and no account; the
// player decides per match whether it counts. Only the player, signed in with
// Firebase, can read or change their own data. The app works out badges with
// BadgeEngine and stores the awards here; the server never scores anything.
//
//   GET    /health
//   POST   /api/v1/devices                   new device key (no account)
//   POST   /api/v1/submissions               a match for a player (device key)
//   GET    /api/v1/me                        own account and player
//   POST   /api/v1/me                        make the account (16+, consent)
//   DELETE /api/v1/me                        delete the account and everything
//   GET    /api/v1/me/inbox                  matches waiting for an answer
//   POST   /api/v1/me/inbox/:id              { use: true | false, block?: true }
//   GET    /api/v1/me/matches?since=         accepted matches
//   POST   /api/v1/me/matches                own matches, counted at once (batch)
//   GET    /api/v1/me/awards
//   PUT    /api/v1/me/awards                 merge awards, tombstones win

import { randomText, sameText, sha256, verifyIdToken } from './auth.js';
import { cleanText, latestBirthYear, LIMITS, readMatch } from './validate.js';

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;

/** Replaced in tests */
export const deps = { now: () => Date.now() };

function json(status, body) {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function config(env) {
  const number = (value, fallback) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  };
  return {
    pendingDays: number(env.PENDING_DAYS, 90),
    submissionsPerDay: number(env.SUBMISSIONS_PER_DAY, 20),
    devicesPerHour: number(env.DEVICES_PER_HOUR, 5),
  };
}

function bearer(request) {
  const header = request.headers.get('Authorization') || '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : '';
}

/** The account of the signed-in caller: { uid, account } (account null when not made yet), or null */
async function signedIn(request, env) {
  const uid = await verifyIdToken(bearer(request), env);
  if (!uid) return null;
  const account = await env.DB.prepare('SELECT * FROM accounts WHERE uid = ?').bind(uid).first();
  return { uid, account };
}

/** The device behind a "Device <id>.<key>" header, or null */
async function device(request, env) {
  const header = request.headers.get('Authorization') || '';
  if (!header.startsWith('Device ')) return null;
  const [id, key] = header.slice(7).trim().split('.');
  if (!id || !key) return null;
  const row = await env.DB.prepare('SELECT id, key_hash FROM devices WHERE id = ?').bind(id).first();
  if (!row) return null;
  return sameText(row.key_hash, await sha256(key)) ? row.id : null;
}

function clientIp(request) {
  return request.headers.get('CF-Connecting-IP') || '0.0.0.0';
}

// MARK: - Devices and submissions (no account)

async function createDevice(request, env) {
  const now = deps.now();
  // The address only as a hash, and only to brake mass creation
  const ipHash = await sha256(`device:${clientIp(request)}`);
  const recent = await env.DB.prepare('SELECT COUNT(*) AS n FROM devices WHERE ip_hash = ? AND created_at > ?')
    .bind(ipHash, now - HOUR).first();
  if ((recent?.n || 0) >= config(env).devicesPerHour) return json(429, { error: 'too many devices' });
  const id = crypto.randomUUID();
  const key = randomText(40);
  await env.DB.prepare('INSERT INTO devices (id, key_hash, ip_hash, created_at) VALUES (?, ?, ?, ?)')
    .bind(id, await sha256(key), ipHash, now).run();
  return json(201, { deviceId: id, deviceKey: key });
}

/** The player a submission is for: by player code or by SBN player path */
async function recipient(env, to) {
  if (!to || typeof to !== 'object') return null;
  const code = cleanText(to.code, 20).toUpperCase();
  if (code) return env.DB.prepare('SELECT id FROM players WHERE code = ?').bind(code).first();
  const path = cleanText(to.sbnPath, LIMITS.sbnPath);
  if (path) return env.DB.prepare('SELECT id FROM players WHERE sbn_path = ?').bind(path).first();
  return null;
}

async function submit(request, env) {
  const deviceId = await device(request, env);
  if (!deviceId) return json(401, { error: 'device' });
  const body = await readJson(request);
  const { match, error } = readMatch(body);
  if (error) return json(400, { error });
  const now = deps.now();
  const sent = await env.DB.prepare('SELECT COUNT(*) AS n FROM matches WHERE device_id = ? AND received_at > ?')
    .bind(deviceId, now - DAY).first();
  if ((sent?.n || 0) >= config(env).submissionsPerDay) return json(429, { error: 'too many matches today' });
  // The same answer whether or not the player exists or blocked this phone:
  // a sender cannot find out who has an account
  const player = await recipient(env, body.to);
  if (player) {
    const blocked = await env.DB.prepare('SELECT 1 FROM blocks WHERE player_id = ? AND device_id = ?')
      .bind(player.id, deviceId).first();
    if (!blocked) {
      // INSERT OR IGNORE: a retry with the same match id never makes a second request
      await env.DB.prepare(
        `INSERT OR IGNORE INTO matches
           (player_id, id, status, device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies)
         VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(player.id, match.id, deviceId, cleanText(body.senderName, LIMITS.name), match.playedAt, now,
        match.teamKey, match.opponent, match.summary, match.rallies).run();
    }
  }
  return json(202, { received: match.id });
}

// MARK: - The signed-in player

function playerView(player, account) {
  return {
    playerId: player.id,
    name: player.name,
    code: player.code,
    sbnPath: player.sbn_path || null,
    birthYear: account.birth_year,
    createdAt: account.created_at,
  };
}

async function me(env, caller) {
  if (!caller.account) return json(404, { error: 'no account' });
  const player = await env.DB.prepare('SELECT * FROM players WHERE id = ?').bind(caller.account.player_id).first();
  return json(200, playerView(player, caller.account));
}

async function createAccount(request, env, caller) {
  if (caller.account) return me(env, caller);
  const body = await readJson(request);
  if (!body || body.consent !== true) return json(400, { error: 'consent' });
  const name = cleanText(body.name, LIMITS.name);
  if (!name) return json(400, { error: 'name' });
  const now = deps.now();
  const birthYear = body.birthYear;
  if (!Number.isInteger(birthYear) || birthYear < 1900) return json(400, { error: 'birthYear' });
  // Under 16 needs a parent's consent (AVG); 4.0 starts at 16 (decided 31 October)
  if (birthYear > latestBirthYear(now)) return json(403, { error: 'too young' });
  const sbnPath = cleanText(body.sbnPath, LIMITS.sbnPath) || null;
  if (sbnPath) {
    const taken = await env.DB.prepare('SELECT 1 FROM players WHERE sbn_path = ?').bind(sbnPath).first();
    if (taken) return json(409, { error: 'sbnPath taken' });
  }
  const playerId = crypto.randomUUID();
  let code = randomText(10);
  while (await env.DB.prepare('SELECT 1 FROM players WHERE code = ?').bind(code).first()) code = randomText(10);
  await env.DB.batch([
    env.DB.prepare('INSERT INTO players (id, name, code, sbn_path, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(playerId, name, code, sbnPath, now),
    env.DB.prepare('INSERT INTO accounts (uid, player_id, birth_year, consent_at, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(caller.uid, playerId, birthYear, now, now),
  ]);
  const account = await env.DB.prepare('SELECT * FROM accounts WHERE uid = ?').bind(caller.uid).first();
  const player = await env.DB.prepare('SELECT * FROM players WHERE id = ?').bind(playerId).first();
  return json(201, playerView(player, account));
}

/** Everything of the player, at once. The Apple token is revoked by the app before it calls this. */
async function deleteAccount(env, caller) {
  if (!caller.account) return json(204);
  const playerId = caller.account.player_id;
  await env.DB.batch([
    env.DB.prepare('DELETE FROM matches WHERE player_id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM awards WHERE player_id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM blocks WHERE player_id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM players WHERE id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM accounts WHERE uid = ?').bind(caller.uid),
  ]);
  return json(204);
}

function matchView(row, withRallies) {
  const view = {
    matchId: row.id,
    status: row.status,
    senderName: row.sender_name,
    fromDevice: row.device_id,
    playedAt: row.played_at,
    receivedAt: row.received_at,
    teamKey: row.team_key,
    opponent: row.opponent,
    summary: JSON.parse(row.summary),
  };
  if (withRallies) view.rallies = JSON.parse(row.rallies);
  return view;
}

async function inbox(env, playerId) {
  const { results } = await env.DB.prepare(
    "SELECT * FROM matches WHERE player_id = ? AND status = 'pending' ORDER BY received_at",
  ).bind(playerId).all();
  return json(200, { matches: results.map((row) => matchView(row, false)) });
}

async function answer(request, env, playerId, matchId) {
  const body = await readJson(request);
  if (!body || typeof body.use !== 'boolean') return json(400, { error: 'use' });
  const row = await env.DB.prepare("SELECT * FROM matches WHERE player_id = ? AND id = ? AND status = 'pending'")
    .bind(playerId, matchId).first();
  if (!row) return json(404, { error: 'not found' });
  const now = deps.now();
  if (body.use) {
    await env.DB.prepare("UPDATE matches SET status = 'accepted', decided_at = ? WHERE player_id = ? AND id = ?")
      .bind(now, playerId, matchId).run();
    return json(200, matchView({ ...row, status: 'accepted' }, true));
  }
  const steps = [env.DB.prepare('DELETE FROM matches WHERE player_id = ? AND id = ?').bind(playerId, matchId)];
  if (body.block === true && row.device_id) {
    steps.push(env.DB.prepare('INSERT OR IGNORE INTO blocks (player_id, device_id, created_at) VALUES (?, ?, ?)')
      .bind(playerId, row.device_id, now));
  }
  await env.DB.batch(steps);
  return json(204);
}

async function acceptedMatches(env, playerId, url) {
  const since = Number(url.searchParams.get('since') || 0);
  const { results } = await env.DB.prepare(
    "SELECT * FROM matches WHERE player_id = ? AND status = 'accepted' AND decided_at > ? ORDER BY decided_at",
  ).bind(playerId, Number.isFinite(since) ? since : 0).all();
  return json(200, { matches: results.map((row) => matchView(row, true)) });
}

/** Own matches (entered on the player's own phone, or "Eerdere wedstrijden meenemen"): they count at once */
async function addOwnMatches(request, env, playerId) {
  const body = await readJson(request);
  const list = body && Array.isArray(body.matches) ? body.matches : null;
  if (!list || list.length === 0 || list.length > LIMITS.batch) return json(400, { error: 'matches' });
  const now = deps.now();
  const steps = [];
  for (const item of list) {
    const { match, error } = readMatch(item);
    if (error) return json(400, { error, matchId: item && item.matchId });
    // An own match replaces a pending copy of the same match (a coach sent it too)
    steps.push(env.DB.prepare(
      `INSERT INTO matches (player_id, id, status, device_id, sender_name, played_at, received_at, decided_at, team_key, opponent, summary, rallies)
       VALUES (?, ?, 'accepted', NULL, '', ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (player_id, id) DO UPDATE SET status = 'accepted', decided_at = excluded.decided_at,
         summary = excluded.summary, rallies = excluded.rallies`,
    ).bind(playerId, match.id, match.playedAt, now, now, match.teamKey, match.opponent, match.summary, match.rallies));
  }
  await env.DB.batch(steps);
  return json(200, { stored: steps.length });
}

async function awards(env, playerId) {
  const { results } = await env.DB.prepare('SELECT id, value, deleted_at FROM awards WHERE player_id = ?')
    .bind(playerId).all();
  return json(200, {
    awards: results.map((row) => ({ id: row.id, value: JSON.parse(row.value), deletedAt: row.deleted_at })),
  });
}

/**
 * Merges awards from a phone. An award the server already has deleted stays
 * deleted (the tombstone wins); a deletion from the phone is kept as a
 * tombstone. Award ids are stable per badge, match and card (AwardValue.awardId),
 * so two phones that work out the same award do not make two.
 */
async function mergeAwards(request, env, playerId) {
  const body = await readJson(request);
  const list = body && Array.isArray(body.awards) ? body.awards : null;
  if (!list || list.length > LIMITS.awards) return json(400, { error: 'awards' });
  const now = deps.now();
  const steps = [];
  for (const item of list) {
    const id = cleanText(item && item.id, 64);
    if (!id) return json(400, { error: 'award id' });
    const value = JSON.stringify(item.value ?? null);
    if (value.length > LIMITS.awardValue) return json(400, { error: 'award size' });
    const deletedAt = typeof item.deletedAt === 'number' ? Math.floor(item.deletedAt) : null;
    steps.push(env.DB.prepare(
      `INSERT INTO awards (player_id, id, value, deleted_at, updated_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT (player_id, id) DO UPDATE SET
         deleted_at = COALESCE(awards.deleted_at, excluded.deleted_at),
         value = CASE WHEN awards.deleted_at IS NULL THEN excluded.value ELSE awards.value END,
         updated_at = excluded.updated_at`,
    ).bind(playerId, id, value, deletedAt, now));
  }
  if (steps.length > 0) await env.DB.batch(steps);
  return awards(env, playerId);
}

// MARK: - Routing

async function handle(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '');
  const method = request.method;

  if (path === '/health' && method === 'GET') return json(200, { ok: true });
  if (path === '/api/v1/devices' && method === 'POST') return createDevice(request, env);
  if (path === '/api/v1/submissions' && method === 'POST') return submit(request, env);

  if (path === '/api/v1/me' || path.startsWith('/api/v1/me/')) {
    const caller = await signedIn(request, env);
    if (!caller) return json(401, { error: 'sign in' });
    if (path === '/api/v1/me') {
      if (method === 'GET') return me(env, caller);
      if (method === 'POST') return createAccount(request, env, caller);
      if (method === 'DELETE') return deleteAccount(env, caller);
      return json(405, { error: 'method' });
    }
    if (!caller.account) return json(404, { error: 'no account' });
    const playerId = caller.account.player_id;
    if (path === '/api/v1/me/inbox' && method === 'GET') return inbox(env, playerId);
    const answerMatch = /^\/api\/v1\/me\/inbox\/([A-Za-z0-9-]{8,64})$/.exec(path);
    if (answerMatch && method === 'POST') return answer(request, env, playerId, answerMatch[1]);
    if (path === '/api/v1/me/matches' && method === 'GET') return acceptedMatches(env, playerId, url);
    if (path === '/api/v1/me/matches' && method === 'POST') return addOwnMatches(request, env, playerId);
    if (path === '/api/v1/me/awards' && method === 'GET') return awards(env, playerId);
    if (path === '/api/v1/me/awards' && method === 'PUT') return mergeAwards(request, env, playerId);
  }
  return json(404, { error: 'not found' });
}

/** Requests nobody answered within PENDING_DAYS */
export async function wipeOldRequests(env) {
  const cutoff = deps.now() - config(env).pendingDays * DAY;
  const result = await env.DB.prepare("DELETE FROM matches WHERE status = 'pending' AND received_at < ?").bind(cutoff).run();
  return result.meta?.changes || 0;
}

export default {
  async fetch(request, env) {
    try {
      return await handle(request, env);
    } catch (error) {
      // No names or e-mail addresses in the logs: only the kind of failure
      console.error('account worker', error && error.name, error && error.message && error.message.slice(0, 120));
      return json(500, { error: 'server' });
    }
  },
  async scheduled(_event, env) {
    await wipeOldRequests(env);
  },
};
