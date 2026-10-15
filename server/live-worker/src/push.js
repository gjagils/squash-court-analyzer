// Live score op het vergrendelscherm: pushes the stand to the phones that
// follow a match without being there. iOS gets a Live Activity update through
// APNs (token-based auth, ES256 JWT from the .p8 key), Android a data message
// through FCM HTTP v1 (OAuth token from the service account, RS256 JWT).
// Both platforms are off when their secrets are missing, so a server without
// them keeps working as before (registering answers 503).
//
// `pushDeps.fetch` and `pushDeps.now` can be replaced in tests.

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

const IOS_TOKEN = /^[0-9a-f]{32,200}$/;
const ANDROID_TOKEN = /^[A-Za-z0-9:_\-.]{1,4096}$/;

/** The body of POST/DELETE /api/live/:id/followers as { platform, token, sandbox }, or null */
export function validateFollower(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  if (typeof input.token !== 'string') return null;
  if (input.platform === 'ios') {
    const token = input.token.toLowerCase();
    if (!IOS_TOKEN.test(token)) return null;
    return { platform: 'ios', token, sandbox: input.sandbox === true };
  }
  if (input.platform === 'android') {
    if (!ANDROID_TOKEN.test(input.token)) return null;
    return { platform: 'android', token: input.token, sandbox: false };
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

/** "Jan wint 3–1", or null when the snapshot has no winner */
export function resultLine(snapshot) {
  if (snapshot.winner !== 1 && snapshot.winner !== 2) return null;
  const name = snapshot.winner === 1 ? snapshot.p1 : snapshot.p2;
  const [a, b] = snapshot.gamesWon;
  return `${name} wint ${Math.max(a, b)}–${Math.min(a, b)}`;
}

/** The APNs body for a Live Activity: event "update" or "end" */
export function apnsPayload(snapshot, event, nowMs) {
  const now = Math.floor(nowMs / 1000);
  const finished = snapshot.status === 'finished';
  const aps = { timestamp: now, event, 'content-state': snapshot };
  if (event === 'update') aps['stale-date'] = now + 900;
  if (event === 'end') aps['dismissal-date'] = finished ? now + 4 * 3600 : now + 60;
  const line = finished ? resultLine(snapshot) : null;
  if (line) aps.alert = { title: 'Uitslag', body: line };
  return { aps };
}

/** The FCM HTTP v1 body: a data message (all values strings) */
export function fcmPayload(token, id, server, snapshot, event) {
  return {
    message: {
      token,
      android: { priority: 'high', ttl: '300s', collapse_key: id },
      data: { kind: 'live', id, server, event, snapshot: JSON.stringify(snapshot) },
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
async function sendFcm(account, follower, id, server, snapshot, event) {
  const accessToken = await fcmAccessToken(account);
  const response = await pushDeps.fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify(fcmPayload(follower.token, id, server, snapshot, event)),
  });
  if (response.ok) return { result: 'ok', detail: 'fcm 200' };
  const body = await response.json().catch(() => null);
  const status = body && body.error && typeof body.error.status === 'string' ? body.error.status : '';
  const details = body && body.error && Array.isArray(body.error.details) ? body.error.details : [];
  const unregistered = status === 'UNREGISTERED' || details.some((d) => d && d.errorCode === 'UNREGISTERED');
  const detail = `fcm ${response.status} ${unregistered ? 'UNREGISTERED' : status}`.trim();
  if (response.status === 404 || unregistered) return { result: 'dead', detail };
  if (response.status === 400 && status === 'INVALID_ARGUMENT') return { result: 'dead', detail };
  console.error('fcm push failed', response.status, status);
  return { result: 'error', detail };
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
 * Sends one event ("update" or "end") with this snapshot to every follower.
 * Platforms without configuration are skipped. Returns the followers whose
 * token is dead, to be forgotten.
 */
export async function pushToFollowers(env, { id, server, snapshot, event, followers }) {
  const apns = apnsSettings(env);
  const fcm = fcmServiceAccount(env);
  const nowMs = pushDeps.now();
  const apnsBody = apnsPayload(snapshot, event, nowMs);
  const dead = [];
  // What the services answered, counted (no tokens or names): "apns 200": 3
  const answers = {};
  await eachLimited(followers, PUSH_CONCURRENCY, async (follower) => {
    let outcome = { result: 'skip', detail: `${follower.platform} off` };
    try {
      if (follower.platform === 'ios' && apns) outcome = await sendApns(apns, follower, apnsBody, nowMs);
      else if (follower.platform === 'android' && fcm) outcome = await sendFcm(fcm, follower, id, server, snapshot, event);
    } catch (error) {
      console.error(`${follower.platform} push error`, error && error.message);
      outcome = { result: 'error', detail: `${follower.platform} exception` };
    }
    answers[outcome.detail] = (answers[outcome.detail] || 0) + 1;
    if (outcome.result === 'dead') dead.push(follower);
  });
  console.log('push', event, JSON.stringify(answers), 'forgotten', dead.length);
  return dead;
}
