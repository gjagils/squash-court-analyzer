// Squash Analyzer 4.0: the player account (docs/voorstel-spelersaccount-4.0.md).
//
// Anyone may send a match for a player, with a device key and no account; the
// player decides per match whether it counts. Only the player, signed in with
// Firebase, can read or change their own data. The app works out badges with
// BadgeEngine and stores the awards here; the server never scores anything.
//
//   GET    /health
//   POST   /api/v1/devices                   new device key (no account)
//   GET    /api/v1/devices/links             names this phone uses that a claim linked to an SBN player
//   POST   /api/v1/submissions               a match for a player (device key)
//   GET    /api/v1/me                        own account and player
//   POST   /api/v1/me                        make the account (16+, consent)
//   PATCH  /api/v1/me                        { name?, sbnPath?, teamKey? }
//   DELETE /api/v1/me                        delete the account and everything
//   GET    /api/v1/me/inbox                  matches waiting for an answer
//   POST   /api/v1/me/inbox/:id              { use: true | false, block?: true }
//   GET    /api/v1/me/team                   matches of the own team that wait for a name
//   POST   /api/v1/me/team/:id               { name }: "dat ben ik", counts at once
//   POST   /api/v1/me/claim                  { token }: a match from a shared link, counts at once
//   GET    /api/v1/me/matches?since=         accepted matches
//   POST   /api/v1/me/matches                own matches, counted at once (batch)
//   GET    /api/v1/me/awards
//   PUT    /api/v1/me/awards                 merge awards, tombstones win
//   GET    /api/v1/me/team/lives?fixtures=   live team matches of the own team, and of opponents for these matches
//   PUT    /api/v1/me/team/lives             { fixture, date, teamName, liveId, writeKey, refereeKey?, replaces? }
//   DELETE /api/v1/me/team/lives?fixture=    the own registration goes

import { randomText, sameText, sha256, verifyIdToken } from './auth.js';
import {
  cleanFixture, cleanText, latestBirthYear, leagueOf, LIMITS, LIVE_ID_PATTERN, LIVE_KEY_PATTERN, readMatch,
} from './validate.js';

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

/** A name as a key: the same name with other capitals or spaces is the same name */
function nameKey(name) {
  return name.toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Who a submission is for: `{ player }` when the player has an account,
 * `{ target, name }` for a match that waits until someone claims it, or null.
 *   { code }            the player code (kept for older builds)
 *   { sbnPath }         an SBN player
 *   { team, name }      the name the sender uses in an SBN team; a claim
 *                       taught this phone that name before, the SBN player
 *   { link: true }      whoever opens the link the app shares
 */
async function recipient(env, to, deviceId) {
  if (!to || typeof to !== 'object') return null;
  const code = cleanText(to.code, 20).toUpperCase();
  if (code) {
    const player = await env.DB.prepare('SELECT id FROM players WHERE code = ?').bind(code).first();
    return player ? { player } : null;
  }
  let path = cleanText(to.sbnPath, LIMITS.sbnPath);
  const team = cleanText(to.team, LIMITS.teamKey);
  const name = cleanText(to.name, LIMITS.name);
  if (!path && team && name) {
    const learned = await env.DB.prepare('SELECT sbn_path FROM learned_links WHERE device_id = ? AND team_key = ? AND name = ?')
      .bind(deviceId, team, nameKey(name)).first();
    if (!learned) return { target: `team:${team}`, name };
    path = learned.sbn_path;
  }
  if (path) {
    const player = await env.DB.prepare('SELECT id FROM players WHERE sbn_path = ?').bind(path).first();
    return player ? { player } : { target: `sbn:${path}`, name: '' };
  }
  if (to.link === true) return { target: 'link:', name: '' };
  return null;
}

/** Matches this phone sent in the last day, also the ones that still wait for a player */
async function sentToday(env, deviceId, now) {
  const counts = await env.DB.batch([
    env.DB.prepare('SELECT COUNT(*) AS n FROM matches WHERE device_id = ? AND received_at > ?').bind(deviceId, now - DAY),
    env.DB.prepare('SELECT COUNT(*) AS n FROM open_matches WHERE device_id = ? AND received_at > ?').bind(deviceId, now - DAY),
  ]);
  return counts.reduce((sum, result) => sum + (result.results[0]?.n || 0), 0);
}

async function submit(request, env) {
  const deviceId = await device(request, env);
  if (!deviceId) return json(401, { error: 'device' });
  const body = await readJson(request);
  const { match, error } = readMatch(body);
  if (error) return json(400, { error });
  const now = deps.now();
  if (await sentToday(env, deviceId, now) >= config(env).submissionsPerDay) {
    return json(429, { error: 'too many matches today' });
  }
  // The same answer whether or not the player exists or blocked this phone:
  // a sender cannot find out who has an account
  const to = await recipient(env, body.to, deviceId);
  const senderName = cleanText(body.senderName, LIMITS.name);
  if (to && to.target) {
    // Waits for a claim. A link gets a token only the sender's link carries.
    let target = to.target;
    let token = null;
    if (target === 'link:') {
      token = randomText(24);
      target = `link:${await sha256(token)}`;
    }
    await env.DB.prepare(
      `INSERT OR IGNORE INTO open_matches
         (id, target, name, device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(match.id, target, to.name, deviceId, senderName, match.playedAt, now,
      match.teamKey, match.opponent, match.summary, match.rallies).run();
    return json(202, token ? { received: match.id, claimToken: token } : { received: match.id });
  }
  const player = to && to.player;
  if (player) {
    const blocked = await env.DB.prepare('SELECT 1 FROM blocks WHERE player_id = ? AND device_id = ?')
      .bind(player.id, deviceId).first();
    if (!blocked) {
      // INSERT OR IGNORE: a retry with the same match id never makes a second request
      await env.DB.prepare(
        `INSERT OR IGNORE INTO matches
           (player_id, id, status, device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies)
         VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(player.id, match.id, deviceId, senderName, match.playedAt, now,
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
    teamKey: player.team_key || null,
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
  const teamKey = cleanText(body.teamKey, LIMITS.teamKey) || null;
  const playerId = crypto.randomUUID();
  let code = randomText(10);
  while (await env.DB.prepare('SELECT 1 FROM players WHERE code = ?').bind(code).first()) code = randomText(10);
  await env.DB.batch([
    env.DB.prepare('INSERT INTO players (id, name, code, sbn_path, team_key, created_at) VALUES (?, ?, ?, ?, ?, ?)')
      .bind(playerId, name, code, sbnPath, teamKey, now),
    env.DB.prepare('INSERT INTO accounts (uid, player_id, birth_year, consent_at, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(caller.uid, playerId, birthYear, now, now),
  ]);
  if (sbnPath) await adoptWaiting(env, playerId, sbnPath);
  const account = await env.DB.prepare('SELECT * FROM accounts WHERE uid = ?').bind(caller.uid).first();
  const player = await env.DB.prepare('SELECT * FROM players WHERE id = ?').bind(playerId).first();
  return json(201, playerView(player, account));
}

/** Matches sent for this SBN player before the account existed: into the inbox */
async function adoptWaiting(env, playerId, sbnPath) {
  const target = `sbn:${sbnPath}`;
  await env.DB.batch([
    env.DB.prepare(
      `INSERT OR IGNORE INTO matches
         (player_id, id, status, device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies)
       SELECT ?, id, 'pending', device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies
         FROM open_matches WHERE target = ?
           AND (device_id IS NULL OR device_id NOT IN (SELECT device_id FROM blocks WHERE player_id = ?))`,
    ).bind(playerId, target, playerId),
    env.DB.prepare('DELETE FROM open_matches WHERE target = ?').bind(target),
  ]);
}

/** A typo in the name, or "Dit ben ik" chosen later: the SBN player can be set once, the team changed */
async function updateAccount(request, env, caller) {
  if (!caller.account) return json(404, { error: 'no account' });
  const body = await readJson(request);
  if (!body || typeof body !== 'object') return json(400, { error: 'body' });
  const playerId = caller.account.player_id;
  const player = await env.DB.prepare('SELECT * FROM players WHERE id = ?').bind(playerId).first();
  const steps = [];
  if (body.name != null) {
    const name = cleanText(body.name, LIMITS.name);
    if (!name) return json(400, { error: 'name' });
    steps.push(env.DB.prepare('UPDATE players SET name = ? WHERE id = ?').bind(name, playerId));
  }
  if (body.teamKey != null) {
    const teamKey = cleanText(body.teamKey, LIMITS.teamKey) || null;
    steps.push(env.DB.prepare('UPDATE players SET team_key = ? WHERE id = ?').bind(teamKey, playerId));
  }
  let newPath = null;
  if (body.sbnPath != null) {
    const sbnPath = cleanText(body.sbnPath, LIMITS.sbnPath);
    if (!sbnPath) return json(400, { error: 'sbnPath' });
    if (sbnPath !== player.sbn_path) {
      // Once set it stays: otherwise anyone could hop from player to player and collect their matches
      if (player.sbn_path) return json(409, { error: 'sbnPath set' });
      const taken = await env.DB.prepare('SELECT 1 FROM players WHERE sbn_path = ?').bind(sbnPath).first();
      if (taken) return json(409, { error: 'sbnPath taken' });
      steps.push(env.DB.prepare('UPDATE players SET sbn_path = ? WHERE id = ?').bind(sbnPath, playerId));
      newPath = sbnPath;
    }
  }
  if (steps.length > 0) await env.DB.batch(steps);
  if (newPath) await adoptWaiting(env, playerId, newPath);
  return me(env, caller);
}

/** Everything of the player, at once. The Apple token is revoked by the app before it calls this. */
async function deleteAccount(env, caller) {
  if (!caller.account) return json(204);
  const playerId = caller.account.player_id;
  await env.DB.batch([
    env.DB.prepare('DELETE FROM matches WHERE player_id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM awards WHERE player_id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM blocks WHERE player_id = ?').bind(playerId),
    env.DB.prepare('DELETE FROM team_lives WHERE starter_id = ?').bind(playerId),
    // What claims taught other phones about this player goes too
    env.DB.prepare('DELETE FROM learned_links WHERE sbn_path = (SELECT sbn_path FROM players WHERE id = ?)').bind(playerId),
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
    decidedAt: row.decided_at ?? null,
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

/** A match waiting in open_matches becomes the player's, counted at once */
async function takeOpen(env, playerId, row) {
  const now = deps.now();
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO matches
         (player_id, id, status, device_id, sender_name, played_at, received_at, decided_at, team_key, opponent, summary, rallies)
       VALUES (?, ?, 'accepted', ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (player_id, id) DO UPDATE SET status = 'accepted', decided_at = excluded.decided_at`,
    ).bind(playerId, row.id, row.device_id, row.sender_name, row.played_at, row.received_at, now,
      row.team_key, row.opponent, row.summary, row.rallies),
    env.DB.prepare('DELETE FROM open_matches WHERE id = ? AND target = ? AND name = ?').bind(row.id, row.target, row.name),
  ]);
  return matchView({ ...row, status: 'accepted' }, true);
}

/**
 * Matches of the own team for a name nobody claimed yet ("Gerd Lasso", as a
 * teammate calls you). Only the result, the date and who sent it: the rallies
 * come after "dat ben ik".
 */
async function teamOpen(env, playerId) {
  const player = await env.DB.prepare('SELECT team_key FROM players WHERE id = ?').bind(playerId).first();
  if (!player || !player.team_key) return json(200, { matches: [] });
  const { results } = await env.DB.prepare(
    `SELECT * FROM open_matches WHERE target = ?
       AND id NOT IN (SELECT id FROM matches WHERE player_id = ?)
       AND (device_id IS NULL OR device_id NOT IN (SELECT device_id FROM blocks WHERE player_id = ?))
     ORDER BY played_at DESC`,
  ).bind(`team:${player.team_key}`, playerId, playerId).all();
  return json(200, {
    // open_matches has no status column: 'open' says it waits for a name
    matches: results.map((row) => ({ ...matchView({ ...row, status: 'open' }, false), name: row.name })),
  });
}

async function claimTeam(request, env, playerId, matchId) {
  const body = await readJson(request);
  const name = cleanText(body && body.name, LIMITS.name);
  if (!name) return json(400, { error: 'name' });
  const player = await env.DB.prepare('SELECT team_key, sbn_path FROM players WHERE id = ?').bind(playerId).first();
  if (!player || !player.team_key) return json(404, { error: 'not found' });
  const row = await env.DB.prepare('SELECT * FROM open_matches WHERE id = ? AND target = ? AND name = ?')
    .bind(matchId, `team:${player.team_key}`, name).first();
  if (!row) return json(404, { error: 'not found' });
  const view = await takeOpen(env, playerId, row);
  // The sending phone learns that its name for this player is this SBN player,
  // and the rest of its matches for that name come along
  if (player.sbn_path && row.device_id) {
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO learned_links (device_id, team_key, name, sbn_path, created_at) VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (device_id, team_key, name) DO UPDATE SET sbn_path = excluded.sbn_path, created_at = excluded.created_at`,
      ).bind(row.device_id, player.team_key, nameKey(name), player.sbn_path, deps.now()),
      env.DB.prepare(
        `INSERT OR IGNORE INTO matches
           (player_id, id, status, device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies)
         SELECT ?, id, 'pending', device_id, sender_name, played_at, received_at, team_key, opponent, summary, rallies
           FROM open_matches WHERE target = ? AND name = ? AND device_id = ?`,
      ).bind(playerId, row.target, row.name, row.device_id),
      env.DB.prepare('DELETE FROM open_matches WHERE target = ? AND name = ? AND device_id = ?')
        .bind(row.target, row.name, row.device_id),
    ]);
  }
  return json(200, view);
}

async function claimLink(request, env, playerId) {
  const body = await readJson(request);
  const token = cleanText(body && body.token, 64);
  if (!token) return json(400, { error: 'token' });
  const row = await env.DB.prepare('SELECT * FROM open_matches WHERE target = ?')
    .bind(`link:${await sha256(token)}`).first();
  if (!row) return json(404, { error: 'not found' });
  return json(200, await takeOpen(env, playerId, row));
}

// MARK: - Live team matches to find (docs/voorstel-teamwedstrijd-vinden-4.0.md)

/**
 * When a registration goes: the start of the second day after the match day
 * (00:00 UTC, so 01:00 or 02:00 in the Netherlands). The live team match
 * itself lasts a day after its last update.
 */
export function teamLiveExpiry(matchAt) {
  const day = new Date(matchAt);
  return Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate() + 2);
}

function teamLiveView(row, own) {
  const view = { fixture: row.fixture, teamName: row.team_name, liveId: row.live_id, starterName: row.starter_name, matchAt: row.match_at, own };
  // The invitation key only for the own team; the opponent gets the referee key
  if (own) view.writeKey = row.write_key;
  if (row.referee_key) view.refereeKey = row.referee_key;
  return view;
}

/**
 * The live team matches of the own team, and for the matches asked
 * (`fixtures`, from the phone's own programme) those of the opponent: without
 * the invitation key, and the referee key only within the same league.
 */
async function teamLives(env, playerId, url) {
  const player = await env.DB.prepare('SELECT team_key FROM players WHERE id = ?').bind(playerId).first();
  const teamKey = player && player.team_key;
  if (!teamKey) return json(200, { lives: [] });
  const now = deps.now();
  const asked = [];
  for (const part of (url.searchParams.get('fixtures') || '').split(',')) {
    const fixture = cleanFixture(part);
    if (fixture && !asked.includes(fixture) && asked.length < LIMITS.fixtures) asked.push(fixture);
  }
  const own = await env.DB.prepare('SELECT * FROM team_lives WHERE team_key = ? AND expires_at > ? ORDER BY match_at')
    .bind(teamKey, now).all();
  const lives = own.results.map((row) => teamLiveView(row, true));
  if (asked.length > 0) {
    const others = await env.DB.prepare(
      `SELECT * FROM team_lives WHERE fixture IN (${asked.map(() => '?').join(',')}) AND team_key != ? AND expires_at > ?
       ORDER BY match_at`,
    ).bind(...asked, teamKey, now).all();
    const league = leagueOf(teamKey);
    for (const row of others.results) {
      const view = teamLiveView(row, false);
      if (!league || leagueOf(row.fixture) !== league) delete view.refereeKey;
      lives.push(view);
    }
  }
  return json(200, { lives });
}

/**
 * Registers the live team match of the own team for an SBN match. One per team
 * and match: when there is one already, 409 with that one (the phone joins it
 * instead), unless `replaces` names it (its session was gone on the live Worker).
 */
async function registerTeamLive(request, env, playerId) {
  const body = await readJson(request);
  if (!body || typeof body !== 'object') return json(400, { error: 'body' });
  const fixture = cleanFixture(body.fixture);
  if (!fixture) return json(400, { error: 'fixture' });
  const teamName = cleanText(body.teamName, LIMITS.teamName);
  if (!teamName) return json(400, { error: 'teamName' });
  const liveId = cleanText(body.liveId, 12);
  if (!LIVE_ID_PATTERN.test(liveId)) return json(400, { error: 'liveId' });
  const writeKey = cleanText(body.writeKey, 64);
  if (!LIVE_KEY_PATTERN.test(writeKey)) return json(400, { error: 'writeKey' });
  const refereeKey = body.refereeKey == null ? null : cleanText(body.refereeKey, 64);
  if (refereeKey !== null && !LIVE_KEY_PATTERN.test(refereeKey)) return json(400, { error: 'refereeKey' });
  const now = deps.now();
  const matchAt = typeof body.date === 'number' && Number.isFinite(body.date) ? Math.floor(body.date) : NaN;
  // A match of today or the coming weeks; one that is already over cannot be registered
  if (!(matchAt > now - DAY && matchAt < now + 60 * DAY)) return json(400, { error: 'date' });
  const player = await env.DB.prepare('SELECT team_key, name FROM players WHERE id = ?').bind(playerId).first();
  if (!player || !player.team_key) return json(404, { error: 'no team' });
  if (leagueOf(fixture) !== leagueOf(player.team_key)) return json(400, { error: 'league' });
  const replaces = body.replaces == null ? null : cleanText(body.replaces, 12);

  const values = [player.team_key, fixture, teamName, liveId, writeKey, refereeKey, playerId, player.name,
    matchAt, now, teamLiveExpiry(matchAt)];
  const columns = `(team_key, fixture, team_name, live_id, write_key, referee_key, starter_id, starter_name,
                    match_at, created_at, expires_at)`;
  await env.DB.batch([
    env.DB.prepare('DELETE FROM team_lives WHERE expires_at <= ?').bind(now),
    replaces
      ? env.DB.prepare(`UPDATE team_lives SET team_name = ?, live_id = ?, write_key = ?, referee_key = ?, starter_id = ?,
                          starter_name = ?, match_at = ?, created_at = ?, expires_at = ?
                        WHERE team_key = ? AND fixture = ? AND live_id = ?`)
        .bind(...values.slice(2), player.team_key, fixture, replaces)
      : env.DB.prepare('SELECT 1'),
    env.DB.prepare(`INSERT INTO team_lives ${columns} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING`)
      .bind(...values),
  ]);
  const row = await env.DB.prepare('SELECT * FROM team_lives WHERE team_key = ? AND fixture = ?')
    .bind(player.team_key, fixture).first();
  const view = teamLiveView(row, true);
  return json(row.live_id === liveId ? 200 : 409, view);
}

/** The own registration goes (team match removed, or no longer visible); someone else's stays */
async function removeTeamLive(env, playerId, url) {
  const fixture = cleanFixture(url.searchParams.get('fixture') || '');
  if (!fixture) return json(400, { error: 'fixture' });
  await env.DB.prepare('DELETE FROM team_lives WHERE fixture = ? AND starter_id = ?').bind(fixture, playerId).run();
  return json(204);
}

/** The names this phone uses that a claim linked to an SBN player */
async function deviceLinks(request, env) {
  const deviceId = await device(request, env);
  if (!deviceId) return json(401, { error: 'device' });
  const { results } = await env.DB.prepare('SELECT team_key, name, sbn_path FROM learned_links WHERE device_id = ?')
    .bind(deviceId).all();
  return json(200, { links: results.map((row) => ({ teamKey: row.team_key, name: row.name, sbnPath: row.sbn_path })) });
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
  if (path === '/api/v1/devices/links' && method === 'GET') return deviceLinks(request, env);
  if (path === '/api/v1/submissions' && method === 'POST') return submit(request, env);

  if (path === '/api/v1/me' || path.startsWith('/api/v1/me/')) {
    const caller = await signedIn(request, env);
    if (!caller) return json(401, { error: 'sign in' });
    if (path === '/api/v1/me') {
      if (method === 'GET') return me(env, caller);
      if (method === 'POST') return createAccount(request, env, caller);
      if (method === 'PATCH') return updateAccount(request, env, caller);
      if (method === 'DELETE') return deleteAccount(env, caller);
      return json(405, { error: 'method' });
    }
    if (!caller.account) return json(404, { error: 'no account' });
    const playerId = caller.account.player_id;
    if (path === '/api/v1/me/inbox' && method === 'GET') return inbox(env, playerId);
    const answerMatch = /^\/api\/v1\/me\/inbox\/([A-Za-z0-9-]{8,64})$/.exec(path);
    if (answerMatch && method === 'POST') return answer(request, env, playerId, answerMatch[1]);
    if (path === '/api/v1/me/team' && method === 'GET') return teamOpen(env, playerId);
    if (path === '/api/v1/me/team/lives') {
      if (method === 'GET') return teamLives(env, playerId, url);
      if (method === 'PUT') return registerTeamLive(request, env, playerId);
      if (method === 'DELETE') return removeTeamLive(env, playerId, url);
      return json(405, { error: 'method' });
    }
    const teamMatch = /^\/api\/v1\/me\/team\/([A-Za-z0-9-]{8,64})$/.exec(path);
    if (teamMatch && method === 'POST') return claimTeam(request, env, playerId, teamMatch[1]);
    if (path === '/api/v1/me/claim' && method === 'POST') return claimLink(request, env, playerId);
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
  const results = await env.DB.batch([
    env.DB.prepare("DELETE FROM matches WHERE status = 'pending' AND received_at < ?").bind(cutoff),
    env.DB.prepare('DELETE FROM open_matches WHERE received_at < ?').bind(cutoff),
    env.DB.prepare('DELETE FROM learned_links WHERE created_at < ?').bind(cutoff),
    env.DB.prepare('DELETE FROM team_lives WHERE expires_at <= ?').bind(deps.now()),
  ]);
  return results.reduce((sum, result) => sum + (result.meta?.changes || 0), 0);
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
