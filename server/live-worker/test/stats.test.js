// The usage counts (stats.js): one row per day and kind, without anything that
// points to a person, read only with the STATS_KEY secret.
import { SELF, env, runInDurableObject } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { clubName, dayOf, isSampleMatch, isTestTeam, totalsOf } from '../src/stats.js';

const BASE = 'https://live.test';
const KEY = 'test-stats-key';

const snapshot = {
  p1: 'Jan de Vries', p2: 'Piet', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0],
  server: 1, side: 'R', status: 'playing',
};
const header = { home: 'All Inn Squash 8', away: 'Squash Delft 8', date: Date.now() };

let ipCounter = 0;
const nextIp = () => `10.3.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

async function call(method, path, body, key) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': nextIp() };
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await SELF.fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json, text };
}

async function stats(query = '') {
  return call('GET', `/api/stats${query}`, undefined, KEY);
}

/** The count of the rows that match the fields, today */
function countOf(rows, fields) {
  const today = dayOf();
  return rows
    .filter((row) => row.day === today && Object.keys(fields).every((name) => row[name] === fields[name]))
    .reduce((sum, row) => sum + row.n, 0);
}

describe('usage counts', () => {
  it('counts a started live match with its platform and language, without names or ids', async () => {
    const before = countOf((await stats()).json.rows, { kind: 'live', platform: 'ios', lang: 'en', test: 0 });
    const created = await call('POST', '/api/live', { ...snapshot, lang: 'en', platform: 'iOS' });
    expect(created.status).toBe(201);
    const { rows } = (await stats()).json;
    expect(countOf(rows, { kind: 'live', platform: 'ios', lang: 'en', test: 0 })).toBe(before + 1);
    const row = rows.find((r) => r.kind === 'live' && r.platform === 'ios');
    expect(row.club).toBe('');
    expect(JSON.stringify(rows)).not.toContain(created.json.id);
    expect(JSON.stringify(rows)).not.toContain('Jan');
    expect(JSON.stringify(rows)).not.toContain('10.3.');
  });

  it('adds up: two starts on one day are one row with n = 2', async () => {
    const before = countOf((await stats()).json.rows, { kind: 'live', platform: 'android', lang: 'nl', test: 0 });
    await call('POST', '/api/live', { ...snapshot, platform: 'android' });
    await call('POST', '/api/live', { ...snapshot, platform: 'android' });
    const { rows } = (await stats()).json;
    expect(countOf(rows, { kind: 'live', platform: 'android', lang: 'nl', test: 0 })).toBe(before + 2);
    const matching = rows.filter((r) => r.day === dayOf() && r.kind === 'live' && r.platform === 'android' && r.lang === 'nl' && r.test === 0);
    expect(matching.length).toBe(1);
  });

  it('an older app without platform counts as unknown', async () => {
    const before = countOf((await stats()).json.rows, { kind: 'live', platform: 'unknown' });
    await call('POST', '/api/live', snapshot);
    expect(countOf((await stats()).json.rows, { kind: 'live', platform: 'unknown' })).toBe(before + 1);
  });

  it('a match with the sample players counts apart', async () => {
    const before = countOf((await stats()).json.rows, { kind: 'live', test: 1 });
    await call('POST', '/api/live', { ...snapshot, p1: 'Bob', p2: 'Wim' });
    await call('POST', '/api/live', { ...snapshot, p1: 'Bombardino', p2: 'Jan' });
    const { rows, totals } = (await stats()).json;
    expect(countOf(rows, { kind: 'live', test: 1 })).toBe(before + 2);
    expect(totals.live.test).toBeGreaterThanOrEqual(2);
  });

  it('counts a team match per club, and a test team apart', async () => {
    const before = countOf((await stats()).json.rows, { kind: 'team', club: 'All Inn Squash', test: 0 });
    expect((await call('POST', '/api/team', { ...header, platform: 'ios' })).status).toBe(201);
    expect((await call('POST', '/api/team', { ...header, home: 'Testteam 1' })).status).toBe(201);
    const { rows } = (await stats()).json;
    expect(countOf(rows, { kind: 'team', club: 'All Inn Squash', test: 0 })).toBe(before + 1);
    expect(countOf(rows, { kind: 'team', club: 'Testteam', test: 1 })).toBe(1);
    // The opponent is not in the counts: a row is never one specific match
    expect(JSON.stringify(rows)).not.toContain('Squash Delft');
  });

  it('counts viewers of a live match and of a team match', async () => {
    const liveBefore = countOf((await stats()).json.rows, { kind: 'viewer-live' });
    const teamBefore = countOf((await stats()).json.rows, { kind: 'viewer-team' });
    const live = (await call('POST', '/api/live', snapshot)).json;
    const team = (await call('POST', '/api/team', header)).json;
    const liveStream = await SELF.fetch(`${BASE}/api/live/${live.id}/events`, { headers: { 'CF-Connecting-IP': '10.3.9.1' } });
    expect(liveStream.status).toBe(200);
    await liveStream.body.cancel();
    const teamStream = await SELF.fetch(`${BASE}/api/team/${team.id}/events`, { headers: { 'CF-Connecting-IP': '10.3.9.2' } });
    expect(teamStream.status).toBe(200);
    await teamStream.body.cancel();
    // A stream of a session that does not exist is not a viewer
    const gone = await SELF.fetch(`${BASE}/api/live/aaaaaaaaaaaa/events`, { headers: { 'CF-Connecting-IP': '10.3.9.3' } });
    expect(gone.status).toBe(404);
    const { rows } = (await stats()).json;
    expect(countOf(rows, { kind: 'viewer-live' })).toBe(liveBefore + 1);
    expect(countOf(rows, { kind: 'viewer-team' })).toBe(teamBefore + 1);
  });

  it('is only readable with the key, and filters by day', async () => {
    expect((await call('GET', '/api/stats')).status).toBe(404);
    expect((await call('GET', '/api/stats', undefined, 'wrong')).status).toBe(404);
    const all = await stats();
    expect(all.status).toBe(200);
    expect(all.json.rows.length).toBeGreaterThan(0);
    const none = await stats('?from=2000-01-01&to=2000-01-02');
    expect(none.json.rows).toEqual([]);
    const today = await stats(`?from=${dayOf()}&to=${dayOf()}`);
    expect(today.json.rows.length).toBe(all.json.rows.filter((r) => r.day === dayOf()).length);
    const bad = await stats('?from=gisteren');
    expect(bad.status).toBe(200);
  });

  it('keeps only counts in the object: no names, ids or addresses', async () => {
    const id = env.STATS.idFromName('global');
    const stub = env.STATS.get(id);
    const columns = await runInDurableObject(stub, (instance) => instance.ctx.storage.sql.exec('SELECT * FROM counts LIMIT 1').columnNames);
    expect(columns).toEqual(['day', 'kind', 'platform', 'lang', 'country', 'region', 'club', 'test', 'n']);
  });
});

describe('the helpers', () => {
  it('finds the club in a team name', () => {
    expect(clubName('All Inn Squash 8')).toBe('All Inn Squash');
    expect(clubName('Squash Delft 12')).toBe('Squash Delft');
    expect(clubName('Victoria H1')).toBe('Victoria');
    expect(clubName('Zwolle 2 D1')).toBe('Zwolle');
    expect(clubName('  Leiden  ')).toBe('Leiden');
    expect(clubName('8')).toBe('8');
    expect(clubName(null)).toBe('');
  });

  it('knows the sample players', () => {
    expect(isSampleMatch('Bob', 'Wim')).toBe(true);
    expect(isSampleMatch(' wim ', 'BOB')).toBe(true);
    expect(isSampleMatch('Bob', 'Tim')).toBe(false);
    expect(isSampleMatch('Whiskey', 'Tim')).toBe(true);
    expect(isSampleMatch('Jan', 'bombardino')).toBe(true);
    expect(isSampleMatch('Jan', 'Piet')).toBe(false);
    expect(isSampleMatch(null, undefined)).toBe(false);
  });

  it('knows a test team', () => {
    expect(isTestTeam('Testteam 1', 'Squash Delft 8')).toBe(true);
    expect(isTestTeam('All Inn Squash 8', 'Voorbeeldspelers')).toBe(true);
    expect(isTestTeam('All Inn Squash 8', 'Squash Delft 8')).toBe(false);
    expect(isTestTeam('Protest 3', 'Delft')).toBe(false);
  });

  it('adds the totals per kind, real and test apart', () => {
    const totals = totalsOf([
      { kind: 'live', test: 0, n: 3 }, { kind: 'live', test: 1, n: 2 }, { kind: 'team', test: 0, n: 1 }, { kind: 'x', test: 0, n: 9 },
    ]);
    expect(totals.live).toEqual({ real: 3, test: 2 });
    expect(totals.team).toEqual({ real: 1, test: 0 });
    expect(totals['viewer-live']).toEqual({ real: 0, test: 0 });
    expect(totals.x).toBeUndefined();
  });

  it('writes the day as YYYY-MM-DD', () => {
    expect(dayOf()).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    // 23:30 UTC on 1 January is already 2 January in the Netherlands
    expect(dayOf(Date.UTC(2026, 0, 1, 23, 30))).toBe('2026-01-02');
  });
});
