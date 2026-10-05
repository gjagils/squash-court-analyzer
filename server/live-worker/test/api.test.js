// The same scenarios as server/live/test/server.test.js, against the Worker
// (SELF) with its Durable Objects. The limits have their own file
// (limits.test.js), since the limiter counts across tests.
import { SELF, env, runDurableObjectAlarm, runInDurableObject } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { cleanName, cleanPhoto, validateSnapshot } from '../src/validate.js';

const BASE = 'https://live.test';

const snapshot = {
  p1: 'Jan de Vries', p2: 'Piet', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0],
  server: 1, side: 'R', status: 'playing',
};

// Every call from its own address: the creation limit per IP never interferes
let ipCounter = 0;
const nextIp = () => `10.1.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

async function call(method, path, body, key, extraHeaders = {}) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': nextIp(), ...extraHeaders };
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await SELF.fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json, text, headers: res.headers };
}

/** Opens the SSE stream and reads events until `count` arrived */
async function openEvents(id) {
  const res = await SELF.fetch(`${BASE}/api/live/${id}/events`, { headers: { 'CF-Connecting-IP': '10.0.0.1' } });
  const reader = res.body ? res.body.getReader() : null;
  const events = [];
  let buffer = '';
  const decoder = new TextDecoder();
  async function read(count) {
    while (events.length < count) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let index;
      while ((index = buffer.indexOf('\n\n')) >= 0) {
        const block = buffer.slice(0, index);
        buffer = buffer.slice(index + 2);
        const event = /^event: (.*)$/m.exec(block);
        const data = /^data: (.*)$/m.exec(block);
        if (event && data) events.push({ event: event[1], data: JSON.parse(data[1]) });
      }
    }
    return events;
  }
  return { status: res.status, read, close: () => reader.cancel() };
}

const sessionStub = (id) => env.SESSION.get(env.SESSION.idFromName(id));

describe('input', () => {
  it('first names only, letters kept', () => {
    expect(cleanName('Jan de Vries', 'x')).toBe('Jan');
    expect(cleanName('  Anne-Marie Jansen', 'x')).toBe('Anne-Marie');
    expect(cleanName('<script>alert(1)</script>', 'x')).toBe('scriptalertscript');
    expect(cleanName('', 'Speler 1')).toBe('Speler 1');
    expect(cleanName(42, 'Speler 2')).toBe('Speler 2');
  });

  it('a snapshot keeps only known, valid fields', () => {
    const clean = validateSnapshot({ ...snapshot, email: 'x@y.z', lastPoint: 'Winner · Volley drop' });
    expect(clean.p1).toBe('Jan');
    expect(clean.email).toBeUndefined();
    expect(clean.lastPoint).toBe('Winner · Volley drop');
    expect(validateSnapshot({ ...snapshot, status: 'raar' })).toBeNull();
    expect(validateSnapshot({ ...snapshot, score: [3] })).toBeNull();
    expect(validateSnapshot({ ...snapshot, side: 'X' })).toBeNull();
    expect(validateSnapshot('nope')).toBeNull();
  });
});

describe('sessions', () => {
  it('create, update, read and delete a session', async () => {
    const created = await call('POST', '/api/live', snapshot);
    expect(created.status).toBe(201);
    expect(created.json.id).toMatch(/^[a-z0-9]{12}$/);
    expect(created.json.writeKey.length).toBeGreaterThanOrEqual(40);
    expect(created.json.url).toBe(`${BASE}/l/${created.json.id}`);
    const id = created.json.id;

    const read = await call('GET', `/api/live/${id}`);
    expect(read.json.snapshot.p1).toBe('Jan');

    // Without or with the wrong key nobody can write
    expect((await call('PUT', `/api/live/${id}`, snapshot)).status).toBe(401);
    expect((await call('PUT', `/api/live/${id}`, snapshot, 'wrong')).status).toBe(401);
    expect((await call('DELETE', `/api/live/${id}`, undefined, 'wrong')).status).toBe(401);

    const update = await call('PUT', `/api/live/${id}`, { ...snapshot, score: [4, 2] }, created.json.writeKey);
    expect(update.status).toBe(204);
    expect((await call('GET', `/api/live/${id}`)).json.snapshot.score).toEqual([4, 2]);

    const before = (await call('GET', '/health')).json.sessions;
    expect((await call('DELETE', `/api/live/${id}`, undefined, created.json.writeKey)).status).toBe(204);
    expect((await call('GET', `/api/live/${id}`)).status).toBe(404);
    expect((await call('GET', '/health')).json.sessions).toBe(before - 1);
  });

  it('viewers get every state and the end over SSE', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    const stream = await openEvents(id);
    expect(stream.status).toBe(200);
    await stream.read(1);
    await call('PUT', `/api/live/${id}`, { ...snapshot, score: [5, 2] }, writeKey);
    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
    const received = await stream.read(3);
    expect(received.map((e) => e.event)).toEqual(['state', 'state', 'ended']);
    expect(received[1].data.snapshot.score).toEqual([5, 2]);
    expect(received[2].data.reason).toBe('finished');
    expect(received[2].data.snapshot.score).toEqual([5, 2]);
  });

  it('the viewer page shows the names in the link preview and escapes them', async () => {
    const created = await call('POST', '/api/live', { ...snapshot, p2: "O'Neil" });
    const page = await call('GET', `/l/${created.json.id}`);
    expect(page.status).toBe(200);
    expect(page.text).toMatch(/<title>🔴 Live: Jan – O&#39;Neil<\/title>/);
    expect(page.text).toMatch(/og:url" content="https:\/\/live\.test\/l\/[a-z0-9]{12}"/);
    expect(page.headers.get('content-security-policy')).toMatch(/default-src 'self'/);

    const gone = await call('GET', '/l/abcdefghjkmn');
    expect(gone.text).toMatch(/Deze livewedstrijd is afgelopen/);
    const odd = await call('GET', "/l/x'%3Balert(1)%3B'");
    expect(odd.text.includes('alert(1)')).toBe(false);
  });

  it('an idle session is removed by its alarm, and viewers hear it ended', async () => {
    const { id } = (await call('POST', '/api/live', snapshot)).json;
    const stub = sessionStub(id);
    const alarm = await runInDurableObject(stub, (_, state) => state.storage.getAlarm());
    expect(alarm - Date.now()).toBeGreaterThan(119 * 60 * 1000);
    expect(alarm - Date.now()).toBeLessThanOrEqual(120 * 60 * 1000);

    const stream = await openEvents(id);
    await stream.read(1);
    const before = (await call('GET', '/health')).json.sessions;
    expect(await runDurableObjectAlarm(stub)).toBe(true);
    const received = await stream.read(2);
    expect(received[1].event).toBe('ended');
    expect(received[1].data.reason).toBe('idle');
    expect(received[1].data.snapshot.score).toEqual([3, 2]);
    expect((await call('GET', `/api/live/${id}`)).status).toBe(404);
    expect((await call('GET', '/health')).json.sessions).toBe(before - 1);
  });

  it('a rally pushes the idle alarm forward', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    const stub = sessionStub(id);
    const first = await runInDurableObject(stub, (_, state) => state.storage.getAlarm());
    await new Promise((resolve) => setTimeout(resolve, 5));
    await call('PUT', `/api/live/${id}`, snapshot, writeKey);
    const second = await runInDurableObject(stub, (_, state) => state.storage.getAlarm());
    expect(second).toBeGreaterThanOrEqual(first);
  });

  it('an unknown or odd id is not found', async () => {
    expect((await call('GET', '/api/live/abcdefghjkmn')).status).toBe(404);
    expect((await call('GET', '/api/live/../etc')).status).toBe(404);
    expect((await call('PUT', '/api/live/abcdefghjkmn', snapshot, 'x')).status).toBe(404);
    expect((await call('GET', '/api/live/abcdefghjkmn/events')).status).toBe(404);
  });
});

// A tiny valid JPEG start (FF D8 FF) with some bytes; the server only checks the header and the size
function base64(bytes) {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}
const jpeg = base64(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, ...new Array(200).fill(7)]));

describe('photos', () => {
  it('only small JPEGs are kept', () => {
    expect(cleanPhoto(jpeg)).toBeTruthy();
    expect(cleanPhoto(btoa('<svg onload=alert(1)>'))).toBeNull();
    expect(cleanPhoto(base64(new Uint8Array([0xff, 0xd8, 0xff, ...new Array(30000).fill(0)])))).toBeNull();
    expect(cleanPhoto('not base64 !')).toBeNull();
    expect(cleanPhoto(42)).toBeNull();
  });

  it('photos are sent once, shown to viewers and gone with the session', async () => {
    const { id, writeKey } = (await call('POST', '/api/live', snapshot)).json;
    expect((await call('GET', `/api/live/${id}`)).json.photos).toEqual([false, false]);

    expect((await call('PUT', `/api/live/${id}/photos`, { p1: jpeg, p2: 'kapot' })).status).toBe(401);
    expect((await call('PUT', `/api/live/${id}/photos`, { p1: jpeg, p2: 'kapot' }, writeKey)).status).toBe(204);
    const after = await call('GET', `/api/live/${id}`);
    expect(after.json.photos).toEqual([true, false]);
    expect(after.json.photoVersion).toBe(1);

    const image = await SELF.fetch(`${BASE}/api/live/${id}/photo/1`);
    expect(image.status).toBe(200);
    expect(image.headers.get('content-type')).toBe('image/jpeg');
    expect(image.headers.get('cache-control')).toBe('no-store');
    expect((await image.arrayBuffer()).byteLength).toBe(204);
    expect((await call('GET', `/api/live/${id}/photo/2`)).status).toBe(404);
    expect((await call('GET', `/api/live/${id}/photo/3`)).status).toBe(404);

    // A rally keeps the photos
    await call('PUT', `/api/live/${id}`, { ...snapshot, score: [4, 2] }, writeKey);
    expect((await call('GET', `/api/live/${id}`)).json.photos).toEqual([true, false]);

    await call('DELETE', `/api/live/${id}`, undefined, writeKey);
    expect((await call('GET', `/api/live/${id}/photo/1`)).status).toBe(404);
  });
});

describe('service', () => {
  it('health check and logo', async () => {
    const health = await call('GET', '/health');
    expect(health.status).toBe(200);
    expect(health.json.ok).toBe(true);
    const logo = await SELF.fetch(`${BASE}/logo.png`);
    expect(logo.status).toBe(200);
    expect(logo.headers.get('content-type')).toMatch(/image\/png/);
  });
});
