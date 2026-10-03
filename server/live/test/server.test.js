'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createLiveServer, validateSnapshot, cleanName, cleanPhoto } = require('../server.js');

const snapshot = {
  p1: 'Jan de Vries', p2: 'Piet', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0],
  server: 1, side: 'R', status: 'playing',
};

async function start(options = {}) {
  const live = createLiveServer({ quiet: true, port: 0, ...options });
  await new Promise((resolve) => live.server.listen(0, '127.0.0.1', resolve));
  const { port } = live.server.address();
  const base = `http://127.0.0.1:${port}`;
  return { ...live, base, stop: () => new Promise((resolve) => { live.server.closeAllConnections(); live.server.close(resolve); }) };
}

async function call(base, method, path, body, key) {
  const headers = { 'Content-Type': 'application/json' };
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await fetch(base + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json, text, headers: res.headers };
}

/** Reads SSE events until `count` arrived */
function readEvents(url, count) {
  return new Promise((resolve, reject) => {
    const events = [];
    const req = http.get(url, (res) => {
      let buffer = '';
      res.on('data', (chunk) => {
        buffer += chunk.toString();
        let index;
        while ((index = buffer.indexOf('\n\n')) >= 0) {
          const block = buffer.slice(0, index);
          buffer = buffer.slice(index + 2);
          const event = /^event: (.*)$/m.exec(block);
          const data = /^data: (.*)$/m.exec(block);
          if (event && data) events.push({ event: event[1], data: JSON.parse(data[1]) });
          if (events.length >= count) { req.destroy(); resolve(events); return; }
        }
      });
      res.on('end', () => resolve(events));
    });
    req.on('error', (error) => (events.length >= count ? resolve(events) : reject(error)));
  });
}

test('first names only, letters kept', () => {
  assert.equal(cleanName('Jan de Vries', 'x'), 'Jan');
  assert.equal(cleanName('  Anne-Marie Jansen', 'x'), 'Anne-Marie');
  assert.equal(cleanName('<script>alert(1)</script>', 'x'), 'scriptalertscript');
  assert.equal(cleanName('', 'Speler 1'), 'Speler 1');
  assert.equal(cleanName(42, 'Speler 2'), 'Speler 2');
});

test('a snapshot keeps only known, valid fields', () => {
  const clean = validateSnapshot({ ...snapshot, email: 'x@y.z', lastPoint: 'Winner · Volley drop' });
  assert.equal(clean.p1, 'Jan');
  assert.equal(clean.email, undefined);
  assert.equal(clean.lastPoint, 'Winner · Volley drop');
  assert.equal(validateSnapshot({ ...snapshot, status: 'raar' }), null);
  assert.equal(validateSnapshot({ ...snapshot, score: [3] }), null);
  assert.equal(validateSnapshot({ ...snapshot, side: 'X' }), null);
  assert.equal(validateSnapshot('nope'), null);
});

test('create, update, read and delete a session', async () => {
  const live = await start();
  try {
    const created = await call(live.base, 'POST', '/api/live', snapshot);
    assert.equal(created.status, 201);
    assert.match(created.json.id, /^[a-z0-9]{12}$/);
    assert.ok(created.json.writeKey.length >= 40);
    assert.equal(created.json.url, `${live.base}/l/${created.json.id}`);
    const id = created.json.id;

    const read = await call(live.base, 'GET', `/api/live/${id}`);
    assert.equal(read.json.snapshot.p1, 'Jan');

    // Without or with the wrong key nobody can write
    assert.equal((await call(live.base, 'PUT', `/api/live/${id}`, snapshot)).status, 401);
    assert.equal((await call(live.base, 'PUT', `/api/live/${id}`, snapshot, 'wrong')).status, 401);
    assert.equal((await call(live.base, 'DELETE', `/api/live/${id}`, undefined, 'wrong')).status, 401);

    const update = await call(live.base, 'PUT', `/api/live/${id}`, { ...snapshot, score: [4, 2] }, created.json.writeKey);
    assert.equal(update.status, 204);
    assert.deepEqual((await call(live.base, 'GET', `/api/live/${id}`)).json.snapshot.score, [4, 2]);

    assert.equal((await call(live.base, 'DELETE', `/api/live/${id}`, undefined, created.json.writeKey)).status, 204);
    assert.equal((await call(live.base, 'GET', `/api/live/${id}`)).status, 404);
    assert.equal(live.sessions.size, 0, 'nothing is kept after the match');
  } finally {
    await live.stop();
  }
});

test('viewers get every state and the end over SSE', async () => {
  const live = await start();
  try {
    const created = await call(live.base, 'POST', '/api/live', snapshot);
    const { id, writeKey } = created.json;
    const events = readEvents(`${live.base}/api/live/${id}/events`, 3);
    await new Promise((resolve) => setTimeout(resolve, 100));
    await call(live.base, 'PUT', `/api/live/${id}`, { ...snapshot, score: [5, 2] }, writeKey);
    await call(live.base, 'DELETE', `/api/live/${id}`, undefined, writeKey);
    const received = await events;
    assert.deepEqual(received.map((e) => e.event), ['state', 'state', 'ended']);
    assert.deepEqual(received[1].data.snapshot.score, [5, 2]);
    assert.deepEqual(received[2].data.snapshot.score, [5, 2], 'the final state goes with the end');
  } finally {
    await live.stop();
  }
});

test('the viewer page shows the names in the link preview and escapes them', async () => {
  const live = await start({ publicUrl: 'https://live.example.com' });
  try {
    const created = await call(live.base, 'POST', '/api/live', { ...snapshot, p2: "O'Neil" });
    const page = await call(live.base, 'GET', `/l/${created.json.id}`);
    assert.equal(page.status, 200);
    assert.match(page.text, /<title>🔴 Live: Jan – O&#39;Neil<\/title>/);
    assert.match(page.text, /og:url" content="https:\/\/live\.example\.com\/l\/[a-z0-9]{12}"/);
    assert.match(page.headers.get('content-security-policy'), /default-src 'self'/);

    const gone = await call(live.base, 'GET', '/l/abcdefghjkmn');
    assert.match(gone.text, /Deze livewedstrijd is afgelopen/);
    const odd = await call(live.base, 'GET', "/l/x'%3Balert(1)%3B'");
    assert.ok(!odd.text.includes('alert(1)'), 'a strange id never reaches the script');
  } finally {
    await live.stop();
  }
});

test('idle sessions are swept', async () => {
  let clock = 1_000_000;
  const live = await start({ now: () => clock, idleMs: 1000 });
  try {
    await call(live.base, 'POST', '/api/live', snapshot);
    assert.equal(live.sessions.size, 1);
    clock += 999;
    live.sweep();
    assert.equal(live.sessions.size, 1);
    clock += 2;
    live.sweep();
    assert.equal(live.sessions.size, 0);
  } finally {
    await live.stop();
  }
});

test('a viewer who leaves is removed from the session', async () => {
  const live = await start();
  try {
    const { id } = (await call(live.base, 'POST', '/api/live', snapshot)).json;
    await readEvents(`${live.base}/api/live/${id}/events`, 1);
    // readEvents closed the connection after the first state
    for (let i = 0; i < 20 && live.sessions.get(id).viewers.size > 0; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    assert.equal(live.sessions.get(id).viewers.size, 0);
  } finally {
    await live.stop();
  }
});

test('viewers of an idle session hear it ended when it is swept', async () => {
  let clock = 1_000_000;
  const live = await start({ now: () => clock, idleMs: 1000 });
  try {
    const { id } = (await call(live.base, 'POST', '/api/live', snapshot)).json;
    const events = readEvents(`${live.base}/api/live/${id}/events`, 2);
    await new Promise((resolve) => setTimeout(resolve, 100));
    clock += 2000;
    live.sweep();
    const received = await events;
    assert.deepEqual(received.map((e) => e.event), ['state', 'ended']);
    assert.equal(received[1].data.reason, 'idle');
    assert.deepEqual(received[1].data.snapshot.score, [3, 2], 'the last state stays on their page');
  } finally {
    await live.stop();
  }
});

test('limits: body size, creations per minute, number of sessions', async () => {
  const live = await start({ createsPerMinute: 2, maxSessions: 3, trustProxy: true });
  try {
    const big = await call(live.base, 'POST', '/api/live', { ...snapshot, lastPoint: 'x'.repeat(5000) });
    assert.equal(big.status, 413);
    assert.equal((await call(live.base, 'POST', '/api/live', snapshot)).status, 201);
    assert.equal((await call(live.base, 'POST', '/api/live', snapshot)).status, 429, 'big request counted as an attempt');
    const otherIp = { 'X-Forwarded-For': '10.0.0.2' };
    const res = await fetch(`${live.base}/api/live`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...otherIp }, body: JSON.stringify(snapshot) });
    assert.equal(res.status, 201);
    await fetch(`${live.base}/api/live`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': '10.0.0.3' }, body: JSON.stringify(snapshot) });
    const full = await fetch(`${live.base}/api/live`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': '10.0.0.4' }, body: JSON.stringify(snapshot) });
    assert.equal(full.status, 503);
  } finally {
    await live.stop();
  }
});

test('without TRUST_PROXY a forged X-Forwarded-For does not get past the limit', async () => {
  const live = await start({ createsPerMinute: 1 });
  try {
    assert.equal((await call(live.base, 'POST', '/api/live', snapshot)).status, 201);
    const forged = await fetch(`${live.base}/api/live`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': '10.9.9.9', 'CF-Connecting-IP': '10.8.8.8' },
      body: JSON.stringify(snapshot),
    });
    assert.equal(forged.status, 429);
  } finally {
    await live.stop();
  }
});

test('behind the tunnel CF-Connecting-IP is the client, and there is a global limit', async () => {
  const live = await start({ createsPerMinute: 1, globalCreatesPerMinute: 2, trustProxy: true });
  const post = (ip) => fetch(`${live.base}/api/live`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': ip }, body: JSON.stringify(snapshot),
  });
  try {
    assert.equal((await post('10.0.0.1')).status, 201);
    assert.equal((await post('10.0.0.1')).status, 429, 'per IP');
    assert.equal((await post('10.0.0.2')).status, 201);
    assert.equal((await post('10.0.0.3')).status, 429, 'global');
  } finally {
    await live.stop();
  }
});

test('viewers per session are limited', async () => {
  const live = await start({ maxViewersPerSession: 1 });
  try {
    const created = await call(live.base, 'POST', '/api/live', snapshot);
    const first = readEvents(`${live.base}/api/live/${created.json.id}/events`, 2);
    await new Promise((resolve) => setTimeout(resolve, 100));
    const second = await fetch(`${live.base}/api/live/${created.json.id}/events`);
    assert.equal(second.status, 503);
    await call(live.base, 'DELETE', `/api/live/${created.json.id}`, undefined, created.json.writeKey);
    await first;
  } finally {
    await live.stop();
  }
});

test('stopping the server tells viewers the session ended', async () => {
  const live = await start();
  const created = await call(live.base, 'POST', '/api/live', snapshot);
  const events = readEvents(`${live.base}/api/live/${created.json.id}/events`, 2);
  await new Promise((resolve) => setTimeout(resolve, 100));
  await new Promise((resolve) => live.shutdown(resolve));
  const received = await events;
  assert.equal(received[1].event, 'ended');
  assert.equal(received[1].data.reason, 'restart');
  assert.equal(live.sessions.size, 0);
});

// A tiny valid JPEG start (FF D8 FF) with some bytes; the server only checks the header and the size
const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 7)]).toString('base64');

test('photos: only small JPEGs are kept', () => {
  assert.ok(cleanPhoto(jpeg, 24 * 1024));
  assert.equal(cleanPhoto(Buffer.from('<svg onload=alert(1)>').toString('base64'), 24 * 1024), null, 'not a JPEG');
  assert.equal(cleanPhoto(Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(30000)]).toString('base64'), 24 * 1024), null, 'too large');
  assert.equal(cleanPhoto('not base64 !', 24 * 1024), null);
  assert.equal(cleanPhoto(42, 24 * 1024), null);
});

test('photos are sent once, shown to viewers and gone with the session', async () => {
  const live = await start();
  try {
    const { id, writeKey } = (await call(live.base, 'POST', '/api/live', snapshot)).json;
    const before = await call(live.base, 'GET', `/api/live/${id}`);
    assert.deepEqual(before.json.photos, [false, false]);

    assert.equal((await call(live.base, 'PUT', `/api/live/${id}/photos`, { p1: jpeg, p2: 'kapot' })).status, 401, 'needs the key');
    assert.equal((await call(live.base, 'PUT', `/api/live/${id}/photos`, { p1: jpeg, p2: 'kapot' }, writeKey)).status, 204);
    const after = await call(live.base, 'GET', `/api/live/${id}`);
    assert.deepEqual(after.json.photos, [true, false], 'an invalid photo is simply no photo');
    assert.equal(after.json.photoVersion, 1);

    const image = await fetch(`${live.base}/api/live/${id}/photo/1`);
    assert.equal(image.status, 200);
    assert.equal(image.headers.get('content-type'), 'image/jpeg');
    assert.equal(image.headers.get('cache-control'), 'no-store');
    assert.equal((await call(live.base, 'GET', `/api/live/${id}/photo/2`)).status, 404);
    assert.equal((await call(live.base, 'GET', `/api/live/${id}/photo/3`)).status, 404);

    // A rally keeps the photos
    await call(live.base, 'PUT', `/api/live/${id}`, { ...snapshot, score: [4, 2] }, writeKey);
    assert.deepEqual((await call(live.base, 'GET', `/api/live/${id}`)).json.photos, [true, false]);

    await call(live.base, 'DELETE', `/api/live/${id}`, undefined, writeKey);
    assert.equal((await call(live.base, 'GET', `/api/live/${id}/photo/1`)).status, 404, 'gone with the session');
  } finally {
    await live.stop();
  }
});

test('health check', async () => {
  const live = await start();
  try {
    const health = await call(live.base, 'GET', '/health');
    assert.equal(health.status, 200);
    assert.equal(health.json.ok, true);
  } finally {
    await live.stop();
  }
});
