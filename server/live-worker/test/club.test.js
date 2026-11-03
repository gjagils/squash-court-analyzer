// The club screen (club.js): the secret link, which team matches are on it, and when they leave.
import { SELF, env, runDurableObjectAlarm } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { clubWalls, wallsOfTeam } from '../src/club.js';

const BASE = 'https://live.test';
const ALL_INN = 'all-inn-test-key-0123456789abcdef';
const DELFT = 'delft-test-key-0123456789abcdefgh';

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

const wallIds = async (clubId, key) => (await call('GET', `/api/club/${clubId}?k=${key}`)).json.matches.map((match) => match.id);
const header = (home, away) => ({ home, away, date: Date.now() });
const partij = { p1: 'Jan', p2: 'Piet', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0], server: 1, side: 'R', status: 'playing' };

describe('the clubs with a screen', () => {
  it('reads the secret and leaves out wrong entries', () => {
    expect(clubWalls({}).length).toBe(0);
    expect(clubWalls({ CLUB_WALLS: 'geen json' }).length).toBe(0);
    expect(clubWalls({ CLUB_WALLS: '{"id":"1"}' }).length).toBe(0);
    expect(clubWalls(env).map((wall) => wall.id)).toEqual(['101', '202']);
  });

  it('a team belongs to a club when its name starts with the official name, as whole words', () => {
    const walls = clubWalls(env);
    const ids = (home, away) => wallsOfTeam({ home, away }, walls).map((wall) => wall.id);
    expect(ids('All Inn Squash 8', 'Squash Delft 3')).toEqual(['101', '202']);
    expect(ids('all inn squash 2', 'Utrecht 1')).toEqual(['101']);
    expect(ids('All Inn Squash Dames 1', 'Utrecht 1')).toEqual(['101']);
    expect(ids('All Inn Squashers 1', 'Utrecht 1')).toEqual([]);
    expect(ids('All Inn 8', 'Utrecht 1')).toEqual([]);
    expect(ids('All Inn Squash 7', 'All Inn Squash 8')).toEqual(['101']);
  });
});

describe('the secret link', () => {
  it('only the right key opens the page and the data; a wrong one looks like no screen at all', async () => {
    const page = await call('GET', `/c/101?k=${ALL_INN}`);
    expect(page.status).toBe(200);
    expect(page.text).toContain('"name":"All Inn Squash"');
    expect(page.text).toContain('noindex');
    expect(page.headers.get('referrer-policy')).toBe('no-referrer');
    // The preview does not name the club
    expect(page.text).toMatch(/<title>SquashAnalyzer · clubscherm<\/title>/);
    for (const path of ['/c/101', `/c/101?k=${DELFT}`, `/c/999?k=${ALL_INN}`, '/c/303?k=kort', '/api/club/101', `/api/club/101/events?k=${DELFT}`]) {
      expect((await call('GET', path)).status, path).toBe(404);
    }
  });
});

describe('team matches on the screen', () => {
  it('shows a new team match on both clubs, with the stand, and it leaves with Live stoppen', async () => {
    const created = await call('POST', '/api/team', header('All Inn Squash 8', 'Squash Delft 3'));
    const { id, writeKey, ownerKey } = created.json;
    expect(await wallIds('101', ALL_INN)).toContain(id);
    expect(await wallIds('202', DELFT)).toContain(id);
    expect((await call('PUT', `/api/team/${id}/partij/1`, partij, writeKey)).status).toBe(204);
    const stand = (await call('GET', `/api/club/101?k=${ALL_INN}`)).json.matches.find((match) => match.id === id);
    expect(stand.team.home).toBe('All Inn Squash 8');
    expect(stand.partijen[1].score).toEqual([3, 2]);
    expect((await call('DELETE', `/api/team/${id}`, undefined, ownerKey)).status).toBe(204);
    expect(await wallIds('101', ALL_INN)).not.toContain(id);
    expect(await wallIds('202', DELFT)).not.toContain(id);
  });

  it('another club, or a name typed differently, stays off the screen', async () => {
    const created = await call('POST', '/api/team', header('Utrecht 1', 'All Inn 8'));
    expect(created.status).toBe(201);
    expect(await wallIds('101', ALL_INN)).not.toContain(created.json.id);
  });

  it('follows new team names: off the old club, on the new one', async () => {
    const { id, ownerKey } = (await call('POST', '/api/team', header('All Inn Squash 5', 'Utrecht 2'))).json;
    expect(await wallIds('101', ALL_INN)).toContain(id);
    expect((await call('PUT', `/api/team/${id}`, header('Squash Delft 5', 'Utrecht 2'), ownerKey)).status).toBe(204);
    expect(await wallIds('101', ALL_INN)).not.toContain(id);
    expect(await wallIds('202', DELFT)).toContain(id);
  });

  it('leaves the screen two hours after its last update', async () => {
    const { id } = (await call('POST', '/api/team', header('All Inn Squash 6', 'Utrecht 3'))).json;
    const wall = env.CLUB.get(env.CLUB.idFromName('101'));
    await wall.setMatch(id, header('All Inn Squash 6', 'Utrecht 3'), {}, Date.now() - 3 * 3600 * 1000);
    expect(await runDurableObjectAlarm(wall)).toBe(true);
    expect(await wallIds('101', ALL_INN)).not.toContain(id);
  });

  it('a team match without a club screen works as before', async () => {
    const created = await call('POST', '/api/team', header('Kampong 1', 'Utrecht 4'));
    expect(created.status).toBe(201);
    expect((await call('PUT', `/api/team/${created.json.id}/partij/1`, partij, created.json.writeKey)).status).toBe(204);
  });
});
