import { SELF, env } from 'cloudflare:test';

export const BASE = 'https://account.test';

let ipCounter = 0;
/** Every call from its own address unless a test picks one: the device limit per IP never interferes */
export const nextIp = () => `10.2.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

export async function call(method, path, { body, auth, ip } = {}) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': ip || nextIp() };
  if (auth) headers.Authorization = auth;
  const res = await SELF.fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* empty */ }
  return { status: res.status, json };
}

function base64Url(bytes) {
  let binary = '';
  for (const b of new Uint8Array(bytes)) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
const encodeJson = (value) => base64Url(new TextEncoder().encode(JSON.stringify(value)));

/** A Firebase-like ID token signed with the test key; `claims` overrides the defaults */
export async function idToken(uid, claims = {}, header = {}) {
  const pem = env.TEST_FIREBASE_PRIVATE_KEY.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const now = Math.floor(Date.now() / 1000);
  const project = env.FIREBASE_PROJECT_ID;
  const head = encodeJson({ alg: 'RS256', kid: 'test-kid', typ: 'JWT', ...header });
  const body = encodeJson({
    iss: `https://securetoken.google.com/${project}`, aud: project, sub: uid,
    iat: now, exp: now + 3600, auth_time: now, ...claims,
  });
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${base64Url(signature)}`;
}

export const signedIn = async (uid, claims) => `Bearer ${await idToken(uid, claims)}`;

let uidCounter = 0;
/** A fresh signed-in player with an account: { auth, player } */
export async function newPlayer(extra = {}) {
  const auth = await signedIn(`uid-${uidCounter++}-${Math.random().toString(36).slice(2, 8)}`);
  const res = await call('POST', '/api/v1/me', { auth, body: { name: 'Peter', birthYear: 1980, consent: true, ...extra } });
  return { auth, player: res.json };
}

/** A fresh device: the Authorization header value */
export async function newDevice() {
  const res = await call('POST', '/api/v1/devices', { body: {} });
  return `Device ${res.json.deviceId}.${res.json.deviceKey}`;
}

let matchCounter = 0;
export function aMatch(extra = {}) {
  return {
    matchId: `match-${Date.now()}-${matchCounter++}`,
    playedAt: Date.UTC(2026, 9, 30, 20, 0),
    opponent: 'Mark',
    summary: { games: [[11, 7], [9, 11], [11, 5], [11, 8]], won: true },
    rallies: [[1, 2, 3, 4, 24, 0, 1]],
    ...extra,
  };
}
