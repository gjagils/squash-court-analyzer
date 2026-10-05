// The limits, in one sequence because the limiter counts across tests:
// two sessions per IP per minute, six in total, three live at once, one
// viewer per session (vitest.config.js, project "limits").
import { SELF } from 'cloudflare:test';
import { expect, it } from 'vitest';

const BASE = 'https://live.test';
const snapshot = {
  p1: 'Jan', p2: 'Piet', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0], server: 1, side: 'R', status: 'playing',
};

async function post(ip, body = snapshot) {
  const res = await SELF.fetch(`${BASE}/api/live`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': ip }, body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}

it('body size, creations per IP and in total, live sessions and viewers are limited', async () => {
  // 1. Too large: refused, but counted as an attempt (global 1, a 1)
  expect((await post('10.0.0.1', { ...snapshot, lastPoint: 'x'.repeat(5000) })).status).toBe(413);
  // 2. a: 201 (global 2, a 2, sessions 1); 3. a again: per-IP limit
  const first = await post('10.0.0.1');
  expect(first.status).toBe(201);
  expect((await post('10.0.0.1')).status).toBe(429);
  // 4, 5. b and c: 201 (global 4, sessions 3)
  const second = await post('10.0.0.2');
  expect(second.status).toBe(201);
  expect((await post('10.0.0.3')).status).toBe(201);
  // 6. d: the cap of three live sessions (global 5)
  expect((await post('10.0.0.4')).status).toBe(503);
  const health = await (await SELF.fetch(`${BASE}/health`)).json();
  expect(health.sessions).toBe(3);
  // 7. b's match is over: room for e (global 6)
  const gone = await SELF.fetch(`${BASE}/api/live/${second.json.id}`, {
    method: 'DELETE', headers: { Authorization: `Bearer ${second.json.writeKey}` },
  });
  expect(gone.status).toBe(204);
  expect((await post('10.0.0.5')).status).toBe(201);
  // 8. f: the global limit of six creations per minute
  expect((await post('10.0.0.6')).status).toBe(429);

  // 9. One viewer per session
  const viewer = await SELF.fetch(`${BASE}/api/live/${first.json.id}/events`);
  expect(viewer.status).toBe(200);
  const reader = viewer.body.getReader();
  await reader.read();
  const another = await SELF.fetch(`${BASE}/api/live/${first.json.id}/events`);
  expect(another.status).toBe(503);
  await reader.cancel();
});
