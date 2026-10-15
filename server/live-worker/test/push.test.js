// Live score op het vergrendelscherm: followers and the pushes to APNs and FCM,
// with throwaway keys (vitest.config.js, project "push") and a fake fetch.
import { SELF, env, runInDurableObject } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  apnsJwt, apnsPayload, clearPushTokenCaches, fcmServiceAccount, googleAssertion, pushDeps, validateFollower,
} from '../src/push.js';

const BASE = 'https://live.test';
const snapshot = {
  p1: 'Jan', p2: 'Piet', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0], server: 1, side: 'R', status: 'playing',
};
const finished = {
  ...snapshot, games: [[11, 8], [9, 11], [11, 5], [11, 7]], score: [0, 0], gamesWon: [3, 1], status: 'finished', winner: 1,
};
const IOS = 'ab'.repeat(32);
const IOS_SANDBOX = 'cd'.repeat(32);
const IOS_DEAD = 'de'.repeat(32);
const ANDROID = 'fcm-token:abc_DEF-123.x';
const ANDROID_GONE = 'gone:token';
const ANDROID_INVALID = 'invalid:token';
const ANDROID_OTHER_400 = 'other400:token';

let ipCounter = 0;
const nextIp = () => `10.4.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

async function call(method, path, body, key) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': nextIp() };
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await SELF.fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json };
}

const stub = (id) => env.SESSION.get(env.SESSION.idFromName(id));
const follow = (id, body) => call('POST', `/api/live/${id}/followers`, body);
const followers = (id) => runInDurableObject(stub(id), (instance) => instance.followers());

function decodePart(part) {
  const base64 = part.replace(/-/g, '+').replace(/_/g, '/');
  return JSON.parse(atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4)));
}

function bytesOf(part) {
  const base64 = part.replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4)), (c) => c.charCodeAt(0));
}

async function verifyJwt(jwt, publicPem, algorithm, verifyAlgorithm) {
  const der = Uint8Array.from(atob(publicPem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('spki', der, algorithm, false, ['verify']);
  const [header, claims, signature] = jwt.split('.');
  return crypto.subtle.verify(verifyAlgorithm, key, bytesOf(signature), new TextEncoder().encode(`${header}.${claims}`));
}

// ---- The fake APNs, Google and FCM ------------------------------------------

let sent = [];
const realFetch = pushDeps.fetch;

function fakeFetch(url, init) {
  const request = { url, method: init.method, headers: init.headers, body: init.body };
  sent.push(request);
  const json = (status, body) => new Response(body === undefined ? null : JSON.stringify(body), { status });
  if (url === 'https://oauth2.googleapis.com/token') return json(200, { access_token: 'ya29.test', expires_in: 3599 });
  if (url.includes('push.apple.com/3/device/')) {
    if (url.endsWith(IOS_DEAD)) return json(400, { reason: 'BadDeviceToken' });
    return json(200);
  }
  if (url.startsWith('https://fcm.googleapis.com/')) {
    const token = JSON.parse(init.body).message.token;
    if (token === ANDROID_GONE) return json(404, { error: { code: 404, status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } });
    if (token === ANDROID_INVALID) {
      return json(400, { error: { code: 400, status: 'INVALID_ARGUMENT', message: 'The registration token is not a valid FCM registration token' } });
    }
    if (token === ANDROID_OTHER_400) return json(400, { error: { code: 400, status: 'INVALID_ARGUMENT', message: 'Invalid value at message.data' } });
    return json(200, { name: 'projects/squash-test/messages/1' });
  }
  return json(500);
}

const apnsCalls = () => sent.filter((r) => r.url.includes('push.apple.com'));
const fcmCalls = () => sent.filter((r) => r.url.startsWith('https://fcm.googleapis.com/'));

beforeEach(() => {
  sent = [];
  clearPushTokenCaches();
  pushDeps.fetch = fakeFetch;
});
afterEach(() => {
  pushDeps.fetch = realFetch;
});

// ---- Tests ------------------------------------------------------------------

describe('registering', () => {
  it('both platforms are on with the secrets', async () => {
    expect((await call('GET', '/api/push')).json).toEqual({ ios: true, android: true });
    expect(fcmServiceAccount({ FCM_SERVICE_ACCOUNT: 'not json' })).toBeNull();
  });

  it('only valid tokens are accepted', () => {
    expect(validateFollower({ platform: 'ios', token: 'AB'.repeat(32) })).toEqual({ platform: 'ios', token: 'ab'.repeat(32), sandbox: false });
    expect(validateFollower({ platform: 'ios', token: IOS, sandbox: true }).sandbox).toBe(true);
    expect(validateFollower({ platform: 'ios', token: 'ab'.repeat(15) })).toBeNull();
    expect(validateFollower({ platform: 'ios', token: 'a'.repeat(201) })).toBeNull();
    expect(validateFollower({ platform: 'ios', token: 'zz'.repeat(32) })).toBeNull();
    expect(validateFollower({ platform: 'android', token: ANDROID })).toEqual({ platform: 'android', token: ANDROID, sandbox: false });
    expect(validateFollower({ platform: 'android', token: 'a'.repeat(4096) })).not.toBeNull();
    expect(validateFollower({ platform: 'android', token: 'a'.repeat(4097) })).toBeNull();
    expect(validateFollower({ platform: 'android', token: 'a b' })).toBeNull();
    expect(validateFollower({ platform: 'android', token: '' })).toBeNull();
    expect(validateFollower({ platform: 'web', token: IOS })).toBeNull();
    expect(validateFollower({ platform: 'ios', token: 42 })).toBeNull();
    expect(validateFollower([])).toBeNull();
  });

  it('register, again without a duplicate, the cap, unregister, gone with the session', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    expect((await follow(id, { platform: 'ios', token: IOS.toUpperCase(), sandbox: true })).status).toBe(201);
    const again = await follow(id, { platform: 'ios', token: IOS, sandbox: true });
    expect(again.status).toBe(201);
    expect(again.json).toEqual({ ok: true });
    expect(await followers(id)).toEqual([{ platform: 'ios', token: IOS, sandbox: true }]);
    expect((await follow(id, { platform: 'ios', token: 'nothex' })).status).toBe(400);
    expect((await follow(id, { platform: 'android', token: ANDROID })).status).toBe(201);
    // A long FCM token fits in the body limit
    expect((await follow(id, { platform: 'android', token: 'x'.repeat(4096) })).status).toBe(201);
    // MAX_FOLLOWERS_PER_SESSION is 3 here; a known token still answers 201
    expect((await follow(id, { platform: 'android', token: 'one-too-many' })).status).toBe(429);
    expect((await follow(id, { platform: 'android', token: ANDROID })).status).toBe(201);

    expect((await call('DELETE', `/api/live/${id}/followers`, { platform: 'android', token: 'x'.repeat(4096) })).status).toBe(204);
    expect((await call('DELETE', `/api/live/${id}/followers`, { platform: 'android', token: 'never-there' })).status).toBe(204);
    expect((await call('DELETE', `/api/live/${id}/followers`, { platform: 'android' })).status).toBe(400);
    expect((await follow(id, { platform: 'android', token: 'now-there-is-room' })).status).toBe(201);
    expect((await followers(id)).length).toBe(3);

    expect((await call('DELETE', `/api/live/${id}`, undefined, writeKey)).status).toBe(204);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
    const left = await runInDurableObject(stub(id), async (_, state) => (await state.storage.list()).size);
    expect(left).toBe(0);
    expect((await follow(id, { platform: 'ios', token: IOS })).status).toBe(404);
    expect((await call('DELETE', `/api/live/${id}/followers`, { platform: 'ios', token: IOS })).status).toBe(404);
  });
});

describe('pushing', () => {
  it('an update goes to every follower, and dead tokens are forgotten', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    await follow(id, { platform: 'ios', token: IOS });
    await follow(id, { platform: 'ios', token: IOS_SANDBOX, sandbox: true });
    await follow(id, { platform: 'android', token: ANDROID });
    // Creating and registering push nothing
    expect(sent).toEqual([]);

    const before = Math.floor(Date.now() / 1000);
    expect((await call('PUT', `/api/live/${id}`, { ...snapshot, score: [4, 2], lastPoint: 'Winner' }, writeKey)).status).toBe(204);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());

    const apns = apnsCalls();
    expect(apns.map((r) => r.url).sort()).toEqual([
      `https://api.push.apple.com/3/device/${IOS}`,
      `https://api.sandbox.push.apple.com/3/device/${IOS_SANDBOX}`,
    ]);
    const headers = apns[0].headers;
    expect(headers['apns-push-type']).toBe('liveactivity');
    expect(headers['apns-topic']).toBe('com.squashanalyzer.app.push-type.liveactivity');
    expect(headers['apns-priority']).toBe('10');
    expect(Number(headers['apns-expiration'])).toBeGreaterThanOrEqual(before + 60);
    expect(headers.authorization).toMatch(/^bearer [\w-]+\.[\w-]+\.[\w-]+$/);
    const { aps } = JSON.parse(apns[0].body);
    expect(aps.event).toBe('update');
    expect(aps.timestamp).toBeGreaterThanOrEqual(before);
    expect(aps['stale-date']).toBe(aps.timestamp + 900);
    expect(aps['dismissal-date']).toBeUndefined();
    expect(aps.alert).toBeUndefined();
    expect(aps['content-state']).toEqual({ ...snapshot, score: [4, 2], lastPoint: 'Winner' });

    // One OAuth token for the fan-out, then FCM HTTP v1
    expect(sent.filter((r) => r.url === 'https://oauth2.googleapis.com/token').length).toBe(1);
    const tokenRequest = sent.find((r) => r.url === 'https://oauth2.googleapis.com/token');
    expect(tokenRequest.body).toMatch(/^grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=[\w-]+\.[\w-]+\.[\w-]+$/);
    const fcm = fcmCalls();
    expect(fcm.length).toBe(1);
    expect(fcm[0].url).toBe('https://fcm.googleapis.com/v1/projects/squash-test/messages:send');
    expect(fcm[0].headers.authorization).toBe('Bearer ya29.test');
    const { message } = JSON.parse(fcm[0].body);
    expect(message.token).toBe(ANDROID);
    expect(message.android).toEqual({ priority: 'high', ttl: '300s', collapse_key: id });
    expect(message.data).toEqual({
      kind: 'live', id, server: BASE, event: 'update',
      snapshot: JSON.stringify({ ...snapshot, score: [4, 2], lastPoint: 'Winner' }),
    });
    for (const value of Object.values(message.data)) expect(typeof value).toBe('string');

    // A dead APNs token (BadDeviceToken) is forgotten (the cap here is 3)
    await call('DELETE', `/api/live/${id}/followers`, { platform: 'ios', token: IOS_SANDBOX });
    await follow(id, { platform: 'ios', token: IOS_DEAD });
    expect((await followers(id)).length).toBe(3);
    sent = [];
    await call('PUT', `/api/live/${id}`, { ...snapshot, score: [5, 2] }, writeKey);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
    expect(apnsCalls().length).toBe(2);
    const left = (await followers(id)).map((f) => f.token).sort();
    expect(left).toEqual([ANDROID, IOS].sort());

    // The Google token is cached: the next fan-out does not ask again
    expect(sent.some((r) => r.url === 'https://oauth2.googleapis.com/token')).toBe(false);
    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
  });

  it('an FCM token that is gone is forgotten too', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    await follow(id, { platform: 'android', token: ANDROID_GONE });
    await follow(id, { platform: 'android', token: ANDROID });
    await call('PUT', `/api/live/${id}`, snapshot, writeKey);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
    expect(fcmCalls().length).toBe(2);
    expect((await followers(id)).map((f) => f.token)).toEqual([ANDROID]);
    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
  });

  it('an invalid FCM token is forgotten, a 400 about the message is not', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    await follow(id, { platform: 'android', token: ANDROID_INVALID });
    await follow(id, { platform: 'android', token: ANDROID_OTHER_400 });
    await call('PUT', `/api/live/${id}`, snapshot, writeKey);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
    expect((await followers(id)).map((f) => f.token)).toEqual([ANDROID_OTHER_400]);
    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
  });

  it('a finished match sends the end once, with the result as an alert', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    await follow(id, { platform: 'ios', token: IOS });
    await follow(id, { platform: 'android', token: ANDROID });
    await call('PUT', `/api/live/${id}`, finished, writeKey);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());

    const { aps } = JSON.parse(apnsCalls()[0].body);
    expect(aps.event).toBe('end');
    expect(aps['content-state']).toEqual(finished);
    expect(aps['dismissal-date']).toBe(aps.timestamp + 4 * 3600);
    expect(aps['stale-date']).toBeUndefined();
    expect(aps.alert).toEqual({ title: 'Uitslag', body: 'Jan wint 3–1' });
    expect(JSON.parse(fcmCalls()[0].body).message.data.event).toBe('end');

    // The same finished stand again, and then Live stoppen: no second end
    sent = [];
    await call('PUT', `/api/live/${id}`, finished, writeKey);
    expect((await call('DELETE', `/api/live/${id}`, undefined, writeKey)).status).toBe(204);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
    expect(sent).toEqual([]);
  });

  it('Live stoppen before the end sends the end with the last stand, gone in a minute', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    await follow(id, { platform: 'ios', token: IOS });
    await follow(id, { platform: 'android', token: ANDROID });
    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());

    const { aps } = JSON.parse(apnsCalls()[0].body);
    expect(aps.event).toBe('end');
    expect(aps['content-state']).toEqual(snapshot);
    expect(aps['dismissal-date']).toBe(aps.timestamp + 60);
    expect(aps.alert).toBeUndefined();
    const { message } = JSON.parse(fcmCalls()[0].body);
    expect(message.data.event).toBe('end');
    expect(message.data.id).toBe(id);
    expect(message.data.server).toBe(BASE);
  });

  it('a failing push is logged and does not break the update', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    await follow(id, { platform: 'ios', token: IOS });
    pushDeps.fetch = () => { throw new Error('network down'); };
    expect((await call('PUT', `/api/live/${id}`, snapshot, writeKey)).status).toBe(204);
    await runInDurableObject(stub(id), (instance) => instance.pushesDone());
    // Not a dead token: kept
    expect((await followers(id)).length).toBe(1);
    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
  });
});

describe('tokens', () => {
  it('the APNs provider token is an ES256 JWT with the key id and team, and cached', async () => {
    const settings = { key: env.APNS_KEY, keyId: 'TESTKEY123', teamId: 'TEAM456789', bundleId: 'x' };
    const jwt = await apnsJwt(settings);
    const [header, claims] = jwt.split('.');
    expect(decodePart(header)).toEqual({ alg: 'ES256', kid: 'TESTKEY123' });
    const decoded = decodePart(claims);
    expect(decoded.iss).toBe('TEAM456789');
    expect(Math.abs(decoded.iat - Date.now() / 1000)).toBeLessThan(5);
    // Raw r||s: 64 bytes for P-256
    expect(bytesOf(jwt.split('.')[2]).length).toBe(64);
    expect(await verifyJwt(jwt, env.TEST_APNS_PUBLIC_KEY, { name: 'ECDSA', namedCurve: 'P-256' }, { name: 'ECDSA', hash: 'SHA-256' })).toBe(true);
    expect(await apnsJwt(settings)).toBe(jwt);
  });

  it('the Google assertion is an RS256 JWT for the FCM scope', async () => {
    const account = fcmServiceAccount(env);
    const jwt = await googleAssertion(account);
    const [header, claims] = jwt.split('.');
    expect(decodePart(header)).toEqual({ alg: 'RS256', typ: 'JWT' });
    const decoded = decodePart(claims);
    expect(decoded.iss).toBe('push@squash-test.iam.gserviceaccount.com');
    expect(decoded.scope).toBe('https://www.googleapis.com/auth/firebase.messaging');
    expect(decoded.aud).toBe('https://oauth2.googleapis.com/token');
    expect(decoded.exp - decoded.iat).toBe(3600);
    expect(await verifyJwt(jwt, env.TEST_FCM_PUBLIC_KEY, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, { name: 'RSASSA-PKCS1-v1_5' })).toBe(true);
  });

  it('a stand without a winner has no alert', () => {
    const body = apnsPayload({ ...finished, winner: undefined }, 'end', 1_000_000);
    expect(body.aps.alert).toBeUndefined();
    expect(body.aps.timestamp).toBe(1000);
  });
});
