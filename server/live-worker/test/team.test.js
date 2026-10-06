// Live team matches (Competitie): /api/team, the page at /t/:id and the
// TeamSession object. Same style as api.test.js, own limiter counts.
import { SELF, env, runDurableObjectAlarm } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { cleanPartijName, cleanTeamName, validatePartij, validateTeamHeader } from '../src/validate.js';

const BASE = 'https://live.test';
const DAY = Date.UTC(2026, 9, 30, 19, 0, 0);
const header = { home: 'All Inn Squash 8', away: 'Squash Delft 8', date: DAY };
const partij = {
  p1: 'Gerd-Jan van Gils', p2: 'Ronald', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0],
  server: 1, side: 'R', status: 'playing',
};

let ipCounter = 0;
const nextIp = () => `10.3.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

async function call(method, path, body, key) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': nextIp() };
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await SELF.fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json, text, headers: res.headers };
}

async function openEvents(id) {
  const res = await SELF.fetch(`${BASE}/api/team/${id}/events`, { headers: { 'CF-Connecting-IP': '10.0.0.2' } });
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

const teamStub = (id) => env.TEAM.get(env.TEAM.idFromName(id));

describe('input', () => {
  it('team names keep letters, digits and a few marks', () => {
    expect(cleanTeamName('  Squash   Delft 8 ', 'x')).toBe('Squash Delft 8');
    expect(cleanTeamName('<b>All Inn</b>', 'x')).toBe('bAll Innb');
    expect(cleanTeamName('', 'fallback')).toBe('fallback');
    expect(cleanTeamName('a'.repeat(80), 'x').length).toBe(40);
  });

  it('a header needs both teams; an odd day becomes now', () => {
    expect(validateTeamHeader({ home: 'A', away: '' })).toBeNull();
    expect(validateTeamHeader('nope')).toBeNull();
    expect(validateTeamHeader(header)).toEqual({ home: 'All Inn Squash 8', away: 'Squash Delft 8', date: DAY });
    const odd = validateTeamHeader({ home: 'A', away: 'B', date: 12 });
    expect(Math.abs(odd.date - Date.now())).toBeLessThan(5000);
    expect(validateTeamHeader({ home: 'A', away: 'B', date: '2026-10-30T19:00:00Z' }).date).toBe(DAY);
  });

  it('a partij: first names, or none; scores optional for a hand-filled one', () => {
    expect(cleanPartijName('Gerd-Jan van Gils')).toBe('Gerd-Jan');
    expect(cleanPartijName('')).toBe('');
    expect(cleanPartijName(7)).toBe('');
    const clean = validatePartij({ ...partij, email: 'x@y.z', lastPoint: 'Jan: Winner' });
    expect(clean.p1).toBe('Gerd-Jan');
    expect(clean.email).toBeUndefined();
    expect(clean.lastPoint).toBe('Jan: Winner');
    // Only who won: no games with a score, no names
    const filled = validatePartij({ status: 'finished', gamesWon: [3, 1], winner: 1 });
    expect(filled).toMatchObject({ p1: '', p2: '', bestOf: 5, games: [], score: [0, 0], gamesWon: [3, 1], winner: 1, side: 'R', server: 1 });
    expect(validatePartij({ empty: true })).toEqual({ empty: true });
    expect(validatePartij({ ...partij, status: 'raar' })).toBeNull();
    expect(validatePartij({ ...partij, gamesWon: [3] })).toBeNull();
    expect(validatePartij({ ...partij, games: [[11]] })).toBeNull();
    expect(validatePartij('nope')).toBeNull();
  });
});

describe('team sessions', () => {
  it('create, fill the partijen, read and delete', async () => {
    const created = await call('POST', '/api/team', header);
    expect(created.status).toBe(201);
    const { id, writeKey, url } = created.json;
    expect(id).toMatch(/^[a-z0-9]{12}$/);
    expect(url).toBe(`${BASE}/t/${id}`);

    const empty = await call('GET', `/api/team/${id}`);
    expect(empty.json.team).toEqual({ home: 'All Inn Squash 8', away: 'Squash Delft 8', date: DAY });
    expect(empty.json.partijen).toEqual({});

    // Two phones, two slots: each writes its own
    expect((await call('PUT', `/api/team/${id}/partij/1`, partij, writeKey)).status).toBe(204);
    expect((await call('PUT', `/api/team/${id}/partij/3`, { status: 'finished', gamesWon: [0, 3], winner: 2 }, writeKey)).status).toBe(204);
    const read = await call('GET', `/api/team/${id}`);
    expect(Object.keys(read.json.partijen)).toEqual(['1', '3']);
    expect(read.json.partijen['1'].p1).toBe('Gerd-Jan');
    expect(read.json.partijen['3'].p1).toBe('');
    expect(read.json.partijen['3'].winner).toBe(2);

    // Another update of slot 1 leaves slot 3 alone; a slot can be cleared
    await call('PUT', `/api/team/${id}/partij/1`, { ...partij, score: [4, 2] }, writeKey);
    expect((await call('GET', `/api/team/${id}`)).json.partijen['3']).toBeTruthy();
    expect((await call('PUT', `/api/team/${id}/partij/3`, { empty: true }, writeKey)).status).toBe(204);
    expect(Object.keys((await call('GET', `/api/team/${id}`)).json.partijen)).toEqual(['1']);

    // New team names
    expect((await call('PUT', `/api/team/${id}`, { ...header, away: 'Delft 7' }, writeKey)).status).toBe(204);
    expect((await call('GET', `/api/team/${id}`)).json.team.away).toBe('Delft 7');

    expect((await call('DELETE', `/api/team/${id}`, undefined, writeKey)).status).toBe(204);
    expect((await call('GET', `/api/team/${id}`)).status).toBe(404);
    expect((await call('PUT', `/api/team/${id}/partij/1`, partij, writeKey)).status).toBe(404);
  });

  it('wrong key, wrong slot and odd bodies are refused', async () => {
    const { id, writeKey } = (await call('POST', '/api/team', header)).json;
    expect((await call('PUT', `/api/team/${id}/partij/1`, partij, 'nope')).status).toBe(401);
    expect((await call('PUT', `/api/team/${id}/partij/1`, partij)).status).toBe(401);
    expect((await call('PUT', `/api/team/${id}/partij/5`, partij, writeKey)).status).toBe(404);
    expect((await call('PUT', `/api/team/${id}/partij/0`, partij, writeKey)).status).toBe(404);
    expect((await call('PUT', `/api/team/${id}/partij/1`, { ...partij, status: 'x' }, writeKey)).status).toBe(400);
    expect((await call('POST', '/api/team', { home: 'Alleen een team' })).status).toBe(400);
    expect((await call('DELETE', `/api/team/${id}`, undefined, 'nope')).status).toBe(401);
    expect((await call('GET', '/api/team/abc')).status).toBe(404);
    expect((await call('GET', '/api/team/aaaaaaaaaaaa')).status).toBe(404);
    expect((await call('PATCH', `/api/team/${id}`, {}, writeKey)).status).toBe(405);
  });

  it('viewers get every change and the end over SSE', async () => {
    const { id, writeKey } = (await call('POST', '/api/team', header)).json;
    const events = await openEvents(id);
    expect(events.status).toBe(200);
    await call('PUT', `/api/team/${id}/partij/2`, partij, writeKey);
    await call('PUT', `/api/team/${id}/partij/2`, { ...partij, score: [5, 2] }, writeKey);
    const got = await events.read(3);
    expect(got.map((e) => e.event)).toEqual(['state', 'state', 'state']);
    expect(got[0].data.partijen).toEqual({});
    expect(got[2].data.partijen['2'].score).toEqual([5, 2]);
    await call('DELETE', `/api/team/${id}`, undefined, writeKey);
    const all = await events.read(4);
    expect(all[3].event).toBe('ended');
    expect(all[3].data.partijen['2']).toBeTruthy();
    events.close();
  });

  it('the page shows the teams and the games in the link preview, and escapes them', async () => {
    const { id, writeKey } = (await call('POST', '/api/team', { home: 'All <Inn> 8', away: 'Delft & Co', date: DAY })).json;
    await call('PUT', `/api/team/${id}/partij/1`, { status: 'finished', gamesWon: [3, 0], winner: 1 }, writeKey);
    await call('PUT', `/api/team/${id}/partij/2`, { status: 'finished', gamesWon: [1, 3], winner: 2 }, writeKey);
    const page = await call('GET', `/t/${id}`);
    expect(page.status).toBe(200);
    expect(page.headers.get('content-type')).toContain('text/html');
    expect(page.text).toContain(`<title>🔴 Live: All Inn 8 – Delft &amp; Co · 4-3</title>`);
    expect(page.text).toContain(`var id = "${id}"`);
    expect(page.text).not.toContain('{{');
    // Unknown or odd ids: the "afgelopen" page, never an echo of the id
    const gone = await call('GET', '/t/aaaaaaaaaaaa');
    expect(gone.text).toContain('<title>SquashAnalyzer · teamwedstrijd</title>');
    const odd = await call('GET', '/t/%3Cscript%3E');
    expect(odd.text).toContain('var id = ""');
  });

  it('an idle team match is removed by its alarm, two hours after the last update', async () => {
    const { id, writeKey } = (await call('POST', '/api/team', header)).json;
    await call('PUT', `/api/team/${id}/partij/4`, partij, writeKey);
    expect(await runDurableObjectAlarm(teamStub(id))).toBe(true);
    expect((await call('GET', `/api/team/${id}`)).status).toBe(404);
  });

  it('team matches count in the health check and are released', async () => {
    const before = (await call('GET', '/health')).json.sessions;
    const { id, writeKey } = (await call('POST', '/api/team', header)).json;
    expect((await call('GET', '/health')).json.sessions).toBe(before + 1);
    await call('DELETE', `/api/team/${id}`, undefined, writeKey);
    expect((await call('GET', '/health')).json.sessions).toBe(before);
  });
});
