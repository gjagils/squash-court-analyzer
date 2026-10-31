// Who is asking. Two kinds of callers:
// - a signed-in player: a Firebase ID token (RS256 JWT), checked against
//   Google's public keys, the project id and the clock. Firebase only knows who
//   you are; what you play stays here.
// - a phone that sends a match without an account: a device key from
//   POST /api/v1/devices, kept here only as a SHA-256 hash.

const GOOGLE_KEYS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

/** Replaced in tests */
export const authDeps = {
  fetch: (...args) => fetch(...args),
  now: () => Date.now(),
};

let cachedKeys = null;
let cachedUntil = 0;

/** Google's signing keys ({ kid: CryptoKey }), cached as long as Google allows */
async function signingKeys(env) {
  const now = authDeps.now();
  if (cachedKeys && now < cachedUntil) return cachedKeys;
  let jwks;
  let maxAge = 3600;
  if (env.TEST_FIREBASE_JWKS) {
    jwks = JSON.parse(env.TEST_FIREBASE_JWKS);
  } else {
    const res = await authDeps.fetch(GOOGLE_KEYS);
    if (!res.ok) throw new Error(`google keys ${res.status}`);
    const match = /max-age=(\d+)/.exec(res.headers.get('Cache-Control') || '');
    if (match) maxAge = Number(match[1]);
    jwks = await res.json();
  }
  const keys = {};
  for (const jwk of jwks.keys || []) {
    keys[jwk.kid] = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  }
  cachedKeys = keys;
  cachedUntil = now + maxAge * 1000;
  return keys;
}

/** Forget the cached keys (tests switch key sets) */
export function resetKeyCache() {
  cachedKeys = null;
  cachedUntil = 0;
}

function base64UrlDecode(text) {
  const padded = text.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((text.length + 3) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * The Firebase uid of a valid ID token, or null. Follows Firebase's rules for
 * verifying ID tokens: RS256, a known kid, aud = project, iss =
 * securetoken.google.com/<project>, not expired, not issued in the future,
 * a non-empty sub.
 */
export async function verifyIdToken(token, env) {
  const parts = (token || '').split('.');
  if (parts.length !== 3) return null;
  let header;
  let claims;
  try {
    header = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[0])));
    claims = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1])));
  } catch {
    return null;
  }
  if (header.alg !== 'RS256' || !header.kid) return null;
  const keys = await signingKeys(env);
  const key = keys[header.kid];
  if (!key) return null;
  const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, base64UrlDecode(parts[2]), signed);
  if (!valid) return null;
  const project = env.FIREBASE_PROJECT_ID;
  const now = Math.floor(authDeps.now() / 1000);
  const skew = 60;
  if (claims.aud !== project) return null;
  if (claims.iss !== `https://securetoken.google.com/${project}`) return null;
  if (typeof claims.exp !== 'number' || claims.exp < now - skew) return null;
  if (typeof claims.iat !== 'number' || claims.iat > now + skew) return null;
  if (typeof claims.auth_time === 'number' && claims.auth_time > now + skew) return null;
  if (typeof claims.sub !== 'string' || claims.sub.length === 0 || claims.sub.length > 128) return null;
  return claims.sub;
}

/** Hex SHA-256 of a text */
export async function sha256(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** A random text from an unambiguous alphabet (no 0/O, 1/I/L) */
export function randomText(length) {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let out = '';
  for (const b of bytes) out += alphabet[b % alphabet.length];
  return out;
}

/** The two texts are equal, in constant time */
export function sameText(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
