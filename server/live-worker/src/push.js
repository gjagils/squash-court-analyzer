// Live score op het vergrendelscherm: pushes the stand to the phones that
// follow a match without being there. iOS gets a Live Activity update through
// APNs (token-based auth, ES256 JWT from the .p8 key), Android a data message
// through FCM HTTP v1 (OAuth token from the service account, RS256 JWT).
// Both platforms are off when their secrets are missing, so a server without
// them keeps working as before (registering answers 503).
//
// `pushDeps.fetch` and `pushDeps.now` can be replaced in tests.

import { cleanLang, LANGS } from './validate.js';

export const pushDeps = {
  fetch: (...args) => fetch(...args),
  now: () => Date.now(),
};

const APNS_PRODUCTION = 'https://api.push.apple.com';
const APNS_SANDBOX = 'https://api.sandbox.push.apple.com';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
/** Provider tokens are valid for an hour; renew a bit before */
const TOKEN_LIFETIME_MS = 50 * 60 * 1000;
/** Pushes in flight at once per fan-out */
export const PUSH_CONCURRENCY = 20;

const encoder = new TextEncoder();

// ---- Configuration --------------------------------------------------------

/** The Firebase service account from FCM_SERVICE_ACCOUNT, or null when missing or unusable */
export function fcmServiceAccount(env) {
  const text = env.FCM_SERVICE_ACCOUNT;
  if (typeof text !== 'string' || !text.trim()) return null;
  try {
    const account = JSON.parse(text);
    if (!account || typeof account.client_email !== 'string' || typeof account.private_key !== 'string'
      || typeof account.project_id !== 'string') return null;
    return account;
  } catch {
    return null;
  }
}

function apnsSettings(env) {
  const key = typeof env.APNS_KEY === 'string' ? env.APNS_KEY.trim() : '';
  const keyId = typeof env.APNS_KEY_ID === 'string' ? env.APNS_KEY_ID.trim() : '';
  const teamId = typeof env.APNS_TEAM_ID === 'string' ? env.APNS_TEAM_ID.trim() : '';
  if (!key || !keyId || !teamId) return null;
  const bundleId = String(env.APNS_BUNDLE_ID || '').trim() || 'com.squashanalyzer.app';
  return { key, keyId, teamId, bundleId };
}

/** Which platforms this server can push to: { ios, android } */
export function pushAvailability(env) {
  return { ios: Boolean(apnsSettings(env)), android: Boolean(fcmServiceAccount(env)) };
}

// ---- Followers ------------------------------------------------------------

// Live Activity tokens can be 128 bytes (256 hex) or more: room up to 512
const IOS_TOKEN = /^[0-9a-f]{32,512}$/;
const ANDROID_TOKEN = /^[A-Za-z0-9:_\-.]{1,4096}$/;

/** The body of POST/DELETE /api/live/:id/followers as { platform, token, sandbox }, or null */
export function validateFollower(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  if (typeof input.token !== 'string') return null;
  if (input.platform === 'ios') {
    const token = input.token.toLowerCase();
    if (!IOS_TOKEN.test(token)) return null;
    return { platform: 'ios', token, sandbox: input.sandbox === true, alerts: input.alerts !== false, lang: cleanLang(input.lang) };
  }
  if (input.platform === 'android') {
    if (!ANDROID_TOKEN.test(input.token)) return null;
    return { platform: 'android', token: input.token, sandbox: false, alerts: input.alerts !== false, lang: cleanLang(input.lang) };
  }
  return null;
}

// ---- JWTs -----------------------------------------------------------------

export function base64url(bytes) {
  const array = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let binary = '';
  for (const b of array) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const base64urlJson = (value) => base64url(encoder.encode(JSON.stringify(value)));

/** The DER bytes of a PEM ("-----BEGIN PRIVATE KEY-----" ...) */
function pemBytes(pem) {
  const body = pem.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function signJwt(header, claims, pem, importAlgorithm, signAlgorithm) {
  const key = await crypto.subtle.importKey('pkcs8', pemBytes(pem), importAlgorithm, false, ['sign']);
  const input = `${base64urlJson(header)}.${base64urlJson(claims)}`;
  // WebCrypto's ECDSA signature is already raw r||s, as JWT wants it
  const signature = await crypto.subtle.sign(signAlgorithm, key, encoder.encode(input));
  return `${input}.${base64url(signature)}`;
}

/** APNs provider token (ES256), cached per key for 50 minutes */
const apnsTokenCache = new Map();

export async function apnsJwt(settings) {
  const now = pushDeps.now();
  const cacheKey = `${settings.teamId}:${settings.keyId}`;
  const cached = apnsTokenCache.get(cacheKey);
  if (cached && now - cached.at < TOKEN_LIFETIME_MS) return cached.jwt;
  const jwt = await signJwt(
    { alg: 'ES256', kid: settings.keyId },
    { iss: settings.teamId, iat: Math.floor(now / 1000) },
    settings.key,
    { name: 'ECDSA', namedCurve: 'P-256' },
    { name: 'ECDSA', hash: 'SHA-256' },
  );
  apnsTokenCache.set(cacheKey, { jwt, at: now });
  return jwt;
}

/** The service account's assertion for Google's token endpoint (RS256) */
export async function googleAssertion(account) {
  const iat = Math.floor(pushDeps.now() / 1000);
  return signJwt(
    { alg: 'RS256', typ: 'JWT' },
    { iss: account.client_email, scope: FCM_SCOPE, aud: GOOGLE_TOKEN_URL, iat, exp: iat + 3600 },
    account.private_key,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    { name: 'RSASSA-PKCS1-v1_5' },
  );
}

/** FCM OAuth access token, cached per service account for 50 minutes */
const fcmTokenCache = new Map();

export function fcmAccessToken(account) {
  const now = pushDeps.now();
  const cached = fcmTokenCache.get(account.client_email);
  if (cached && now - cached.at < TOKEN_LIFETIME_MS) return cached.token;
  // The promise is cached: a fan-out to many phones asks Google once
  const token = requestAccessToken(account);
  fcmTokenCache.set(account.client_email, { token, at: now });
  token.catch(() => {
    if (fcmTokenCache.get(account.client_email)?.token === token) fcmTokenCache.delete(account.client_email);
  });
  return token;
}

async function requestAccessToken(account) {
  const assertion = await googleAssertion(account);
  const response = await pushDeps.fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${assertion}`,
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || !body || typeof body.access_token !== 'string') {
    throw new Error(`google token ${response.status} ${body && body.error ? body.error : ''}`.trim());
  }
  return body.access_token;
}

/** For tests: forget the cached provider tokens */
export function clearPushTokenCaches() {
  apnsTokenCache.clear();
  fcmTokenCache.clear();
}

// ---- Payloads -------------------------------------------------------------

/**
 * The words of the alerts per language ("nl" is the default; a follower from
 * before 3.0 has no `lang` and gets Dutch). Names, scores and "E1"-"E4" are
 * the same in both.
 */
const ALERT_WORDS = {
  nl: {
    wins: 'wint', result: 'Uitslag', gameFor: 'voor', draw: 'gelijkspel', partijen: 'partijen', done: 'klaar',
    retired: 'opgave', walkover: 'walkover',
  },
  en: {
    wins: 'wins', result: 'Result', gameFor: 'to', draw: 'draw', partijen: 'matches', done: 'done',
    retired: 'retired', walkover: 'walkover',
  },
};

const wordsFor = (lang) => ALERT_WORDS[lang] || ALERT_WORDS.nl;

/** "Jan wint 3–1" ("Jan wins 3–1" in English), or null when the snapshot has no winner */
export function resultLine(snapshot, lang = 'nl') {
  if (snapshot.winner !== 1 && snapshot.winner !== 2) return null;
  const name = snapshot.winner === 1 ? snapshot.p1 : snapshot.p2;
  const [a, b] = snapshot.gamesWon;
  return `${name} ${wordsFor(lang).wins} ${Math.max(a, b)}–${Math.min(a, b)}`;
}

/** The game scores as "11–7 · 8–11" */
function gamesLine(snapshot) {
  return snapshot.games.map((game) => `${game[0]}–${game[1]}`).join(' · ');
}

/**
 * The notification that goes with a change, like a goal in a football app:
 * only at the end of a game and at the end of the match, never per rally.
 * { title, body } or null. Older followers (no `alerts`) get it too.
 */
export function scoreAlert(previous, snapshot, lang = 'nl') {
  const words = wordsFor(lang);
  if (snapshot.status === 'finished') {
    const line = resultLine(snapshot, lang);
    if (!line || (previous && previous.status === 'finished')) return null;
    return { title: `${words.result}: ${line}`, body: `${snapshot.p1} – ${snapshot.p2} · ${gamesLine(snapshot)}` };
  }
  if (!previous || snapshot.games.length <= previous.games.length || snapshot.games.length === 0) return null;
  const last = snapshot.games[snapshot.games.length - 1];
  if (last[0] === last[1]) return null;
  const winner = last[0] > last[1] ? snapshot.p1 : snapshot.p2;
  const [a, b] = snapshot.gamesWon;
  return {
    title: `Game ${snapshot.games.length} ${words.gameFor} ${winner}`,
    body: `${snapshot.p1} – ${snapshot.p2}: ${last[0]}–${last[1]} · games ${a}–${b}`,
  };
}

// ---- Team matches -----------------------------------------------------------

const TEAM_SLOTS = [1, 2, 3, 4];

/** A partij is decided (as "klaar" on the team page): a winner, finished, or given up / not played */
export function partijDecided(partij) {
  if (!partij) return false;
  return partij.winner === 1 || partij.winner === 2 || partij.status === 'finished'
    || partij.end === 'retired' || partij.end === 'walkover';
}

/** All four partijen of a team match are decided */
export function teamDecided(partijen) {
  return TEAM_SLOTS.every((slot) => partijDecided(partijen && partijen[slot]));
}

/** 1 home, 2 away, 0 unknown: the winner, else whoever has more games */
export function partijWinner(partij) {
  if (partij.winner === 1 || partij.winner === 2) return partij.winner;
  const [a, b] = partij.gamesWon;
  return a > b ? 1 : b > a ? 2 : 0;
}

/** Games won per team over the partijen, as the team page counts them */
function teamGames(partijen) {
  let home = 0;
  let away = 0;
  for (const slot of TEAM_SLOTS) {
    const partij = partijen[slot];
    if (partij) { home += partij.gamesWon[0]; away += partij.gamesWon[1]; }
  }
  return [home, away];
}

/**
 * The lock screen stand of a team match (APNs content-state, FCM `team`):
 * the team names and the partijen that exist, by slot, without games list,
 * last point or order, so it stays far below the 4 KB of APNs. `server`
 * only for a partij in a rally.
 */
export function teamContentState(team, partijen) {
  const list = [];
  for (const slot of TEAM_SLOTS) {
    const partij = partijen && partijen[slot];
    if (!partij) continue;
    const item = {
      slot, p1: partij.p1, p2: partij.p2, bestOf: partij.bestOf, gamesWon: partij.gamesWon, score: partij.score,
      status: partij.status,
    };
    if (partij.winner === 1 || partij.winner === 2) item.winner = partij.winner;
    if (partij.end === 'retired' || partij.end === 'walkover') item.end = partij.end;
    // Who serves (1 home, 2 away), only in a rally: the serve dot on the lock
    // screen. Apps before 3.0 build 5 ignore the extra field.
    if (partij.status === 'playing' && (partij.server === 1 || partij.server === 2) && !item.winner && !item.end) {
      item.server = partij.server;
    }
    list.push(item);
  }
  return { home: team.home, away: team.away, partijen: list };
}

/**
 * The notification of a team match change: a partij that is decided now
 * ("E2: Paul wint 3–1"), or the result when all four are ("Uitslag: All Inn 8
 * wint 9–4", winner by the SBN rule of teamWinner). Never per rally or per game.
 * { title, body } or null.
 */
/**
 * The winner of a decided team match by the SBN rule (as TeamMatchScore in
 * Core, reglement art. 23): most partijen; equal → the team with a full
 * line-up (a lost walkover = not full); → most games; → most rally points;
 * → the team that won E1. 1 home, 2 away, 0 a draw.
 */
export function teamWinner(partijen) {
  const won = [0, 0];
  const full = [true, true];
  const points = [0, 0];
  for (const slot of TEAM_SLOTS) {
    const partij = partijen[slot];
    const winner = partijWinner(partij);
    if (winner) won[winner - 1] += 1;
    if (partij.end === 'walkover' && winner) full[2 - winner] = false;
    for (const game of partij.games || []) { points[0] += game[0]; points[1] += game[1]; }
  }
  if (won[0] !== won[1]) return won[0] > won[1] ? 1 : 2;
  if (full[0] !== full[1]) return full[0] ? 1 : 2;
  const [home, away] = teamGames(partijen);
  if (home !== away) return home > away ? 1 : 2;
  if (points[0] !== points[1]) return points[0] > points[1] ? 1 : 2;
  return partijWinner(partijen[1]);
}

export function teamAlert(previous, team, partijen, lang = 'nl') {
  const words = wordsFor(lang);
  const before = previous || {};
  const [home, away] = teamGames(partijen);
  if (teamDecided(partijen)) {
    if (teamDecided(before)) return null;
    const won = [0, 0];
    for (const slot of TEAM_SLOTS) {
      const winner = partijWinner(partijen[slot]);
      if (winner) won[winner - 1] += 1;
    }
    const winner = teamWinner(partijen);
    // The winner's games first, as the WhatsApp report ("wint met 8–9" can happen)
    const title = winner === 0
      ? `${words.result}: ${words.draw} ${home}–${away}`
      : `${words.result}: ${winner === 1 ? team.home : team.away} ${words.wins} ${winner === 1 ? home : away}–${winner === 1 ? away : home}`;
    return { title, body: `${team.home} – ${team.away} · ${words.partijen} ${won[0]}–${won[1]}` };
  }
  for (const slot of TEAM_SLOTS) {
    const partij = partijen[slot];
    if (!partijDecided(partij) || partijDecided(before[slot])) continue;
    const winner = partijWinner(partij);
    let line = words.done;
    if (winner) {
      const name = (winner === 1 ? partij.p1 : partij.p2) || `${winner === 1 ? team.home : team.away} E${slot}`;
      const [a, b] = partij.gamesWon;
      const how = partij.end === 'retired' ? `(${words.retired})` : partij.end === 'walkover' ? `(${words.walkover})`
        : `${Math.max(a, b)}–${Math.min(a, b)}`;
      line = `${name} ${words.wins} ${how}`;
    }
    return { title: `E${slot}: ${line}`, body: `${team.home} ${home} – ${away} ${team.away}` };
  }
  return null;
}

/**
 * The APNs body for a Live Activity: event "update" or "end", with the alert of
 * a game or the result. An end stays 4 hours when finished (a live match by its
 * status, a team match says so), else a minute.
 */
export function apnsPayload(snapshot, event, nowMs, alert = null, finished = snapshot.status === 'finished') {
  const now = Math.floor(nowMs / 1000);
  const aps = { timestamp: now, event, 'content-state': snapshot };
  if (event === 'update') aps['stale-date'] = now + 900;
  if (event === 'end') aps['dismissal-date'] = finished ? now + 4 * 3600 : now + 60;
  if (alert) {
    aps.alert = { title: alert.title, body: alert.body };
    aps.sound = 'default';
  }
  return { aps };
}

/**
 * The FCM HTTP v1 body: a data message (all values strings); the alert as
 * alertTitle/alertBody. A live match has its stand in `snapshot`, a team match
 * in `team`.
 */
export function fcmPayload(token, id, server, snapshot, event, alert = null, kind = 'live') {
  const data = { kind, id, server, event, [kind === 'team' ? 'team' : 'snapshot']: JSON.stringify(snapshot) };
  if (alert) {
    data.alertTitle = alert.title;
    data.alertBody = alert.body;
  }
  return {
    message: {
      token,
      android: { priority: 'high', ttl: '300s', collapse_key: id },
      data,
    },
  };
}

// ---- Sending --------------------------------------------------------------

/** One APNs push: { result: "ok", "dead" (forget this token) or "error", detail for the log } */
async function sendApns(settings, follower, payload, nowMs) {
  const jwt = await apnsJwt(settings);
  const host = follower.sandbox ? APNS_SANDBOX : APNS_PRODUCTION;
  const response = await pushDeps.fetch(`${host}/3/device/${follower.token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-push-type': 'liveactivity',
      'apns-topic': `${settings.bundleId}.push-type.liveactivity`,
      'apns-priority': '10',
      'apns-expiration': String(Math.floor(nowMs / 1000) + 60),
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  if (response.ok) return { result: 'ok', detail: 'apns 200' };
  const body = await response.json().catch(() => null);
  const reason = body && typeof body.reason === 'string' ? body.reason : '';
  const detail = `apns ${response.status} ${reason}`.trim();
  if (response.status === 410) return { result: 'dead', detail };
  if (response.status === 400 && (reason === 'BadDeviceToken' || reason === 'DeviceTokenNotForTopic')) return { result: 'dead', detail };
  console.error('apns push failed', response.status, reason);
  return { result: 'error', detail };
}

/** One FCM push: { result, detail } as sendApns */
async function sendFcm(account, follower, id, server, snapshot, event, alert, kind) {
  const accessToken = await fcmAccessToken(account);
  const response = await pushDeps.fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify(fcmPayload(follower.token, id, server, snapshot, event, alert, kind)),
  });
  if (response.ok) return { result: 'ok', detail: 'fcm 200' };
  const body = await response.json().catch(() => null);
  const status = body && body.error && typeof body.error.status === 'string' ? body.error.status : '';
  const details = body && body.error && Array.isArray(body.error.details) ? body.error.details : [];
  const unregistered = status === 'UNREGISTERED' || details.some((d) => d && d.errorCode === 'UNREGISTERED');
  const detail = `fcm ${response.status} ${unregistered ? 'UNREGISTERED' : status}`.trim();
  if (response.status === 404 || unregistered) return { result: 'dead', detail };
  // Only a token FCM calls invalid is forgotten: an INVALID_ARGUMENT about our
  // own message must not cost every Android follower
  const message = body && body.error && typeof body.error.message === 'string' ? body.error.message : '';
  if (response.status === 400 && status === 'INVALID_ARGUMENT' && /registration token/i.test(message)) {
    return { result: 'dead', detail };
  }
  console.error('fcm push failed', response.status, status);
  return { result: 'error', detail };
}

/**
 * The alert of a push in one language: `alert` is { title, body } (the same
 * for everyone), { nl, en } (one per language, each may be null) or null
 */
export function alertIn(alert, lang) {
  if (!alert) return null;
  if (typeof alert.title === 'string') return alert;
  return alert[lang] || alert.nl || null;
}

/** Runs `task` over `items` with at most `limit` at once */
async function eachLimited(items, limit, task) {
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const item = items[next++];
      await task(item);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
}

/**
 * Sends one event ("update" or "end") with this snapshot (kind "live") or team
 * stand (kind "team") to every follower. `finished` (default: the snapshot's
 * status) keeps an end on the lock screen for 4 hours. Platforms without
 * configuration are skipped. Returns the followers whose token is dead, to be
 * forgotten.
 */
/**
 * `alert`: see alertIn. A follower gets it in the `lang` it registered with
 * (Dutch when it has none).
 */
export async function pushToFollowers(env, { id, server, snapshot, event, followers, alert = null, kind = 'live', finished }) {
  const apns = apnsSettings(env);
  const fcm = fcmServiceAccount(env);
  const nowMs = pushDeps.now();
  const done = finished === undefined ? snapshot.status === 'finished' : finished;
  // Followers who turned the game alerts off get the same stand without one;
  // the others get it in their language
  const apnsQuiet = apnsPayload(snapshot, event, nowMs, null, done);
  const apnsWithAlert = {};
  for (const lang of LANGS) apnsWithAlert[lang] = apnsPayload(snapshot, event, nowMs, alertIn(alert, lang), done);
  const dead = [];
  // What the services answered, counted (no tokens or names): "apns 200": 3
  const answers = {};
  await eachLimited(followers, PUSH_CONCURRENCY, async (follower) => {
    let outcome = { result: 'skip', detail: `${follower.platform} off` };
    try {
      const wantsAlert = follower.alerts !== false;
      const lang = cleanLang(follower.lang);
      if (follower.platform === 'ios' && apns) {
        outcome = await sendApns(apns, follower, wantsAlert ? apnsWithAlert[lang] : apnsQuiet, nowMs);
      } else if (follower.platform === 'android' && fcm) {
        outcome = await sendFcm(fcm, follower, id, server, snapshot, event, wantsAlert ? alertIn(alert, lang) : null, kind);
      }
    } catch (error) {
      console.error(`${follower.platform} push error`, error && error.message);
      outcome = { result: 'error', detail: `${follower.platform} exception` };
    }
    answers[outcome.detail] = (answers[outcome.detail] || 0) + 1;
    if (outcome.result === 'dead') dead.push(follower);
  });
  console.log('push', kind, event, JSON.stringify(answers), 'forgotten', dead.length);
  return dead;
}
