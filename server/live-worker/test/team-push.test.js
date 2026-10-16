// Live score op het vergrendelscherm for team matches: followers, photos per
// partij and the pushes to APNs and FCM (project "push": throwaway keys, a fake
// fetch, MAX_FOLLOWERS_PER_SESSION 3).
import { SELF, env, runDurableObjectAlarm, runInDurableObject } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { apnsPayload, clearPushTokenCaches, fcmPayload, partijDecided, pushDeps, teamAlert, teamContentState, teamWinner } from '../src/push.js';

const BASE = 'https://live.test';
const header = { home: 'All Inn 8', away: 'Delft 8', date: Date.UTC(2026, 9, 30, 19) };
const team = { home: 'All Inn 8', away: 'Delft 8' };
const playing = {
  p1: 'Gerd-Jan', p2: 'Thomas', bestOf: 5, games: [[11, 8]], score: [3, 2], gamesWon: [1, 0], server: 1, side: 'R',
  status: 'playing', lastPoint: 'Gerd-Jan: Winner', order: [0],
};
const won = (p1, p2, gamesWon, winner, extra = {}) => ({
  p1, p2, bestOf: 5, games: [], score: [0, 0], gamesWon, server: 1, side: 'R', status: 'finished', winner, ...extra,
});
const IOS = 'ab'.repeat(32);
const ANDROID = 'fcm-token:abc_DEF-123.x';
// A tiny "JPEG": the three magic bytes and some more
const JPEG = btoa(String.fromCharCode(0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4));
const JPEG2 = btoa(String.fromCharCode(0xff, 0xd8, 0xff, 0xe1, 9, 9));

let ipCounter = 0;
const nextIp = () => `10.5.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

async function call(method, path, body, key) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': nextIp() };
  if (key) headers.Authorization = `Bearer ${key}`;
  const res = await SELF.fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const buffer = new Uint8Array(await res.arrayBuffer());
  const text = new TextDecoder().decode(buffer);
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json, bytes: buffer, headers: res.headers };
}

const stub = (id) => env.TEAM.get(env.TEAM.idFromName(id));
const follow = (id, body) => call('POST', `/api/team/${id}/followers`, body);
const followers = (id) => runInDurableObject(stub(id), (instance) => instance.followers());
const pushesDone = (id) => runInDurableObject(stub(id), (instance) => instance.pushesDone());

async function newTeam() {
  const created = await call('POST', '/api/team', header);
  expect(created.status).toBe(201);
  return created.json;
}

let sent = [];
const realFetch = pushDeps.fetch;

function fakeFetch(url, init) {
  sent.push({ url, headers: init.headers, body: init.body });
  const json = (status, body) => new Response(body === undefined ? null : JSON.stringify(body), { status });
  if (url === 'https://oauth2.googleapis.com/token') return json(200, { access_token: 'ya29.test', expires_in: 3599 });
  if (url.includes('push.apple.com/3/device/')) return json(200);
  if (url.startsWith('https://fcm.googleapis.com/')) return json(200, { name: 'projects/squash-test/messages/1' });
  return json(500);
}

const apnsBodies = () => sent.filter((r) => r.url.includes('push.apple.com')).map((r) => JSON.parse(r.body).aps);
const fcmData = () => sent.filter((r) => r.url.startsWith('https://fcm.googleapis.com/')).map((r) => JSON.parse(r.body).message);

beforeEach(() => {
  sent = [];
  clearPushTokenCaches();
  pushDeps.fetch = fakeFetch;
});
afterEach(() => {
  pushDeps.fetch = realFetch;
});

describe('team followers', () => {
  it('register, again, the cap, unregister, bad bodies, gone with the team match', async () => {
    const { id, ownerKey } = await newTeam();
    expect((await follow(id, { platform: 'ios', token: IOS.toUpperCase(), sandbox: true })).status).toBe(201);
    const again = await follow(id, { platform: 'ios', token: IOS, sandbox: true });
    expect(again.status).toBe(201);
    expect(again.json).toEqual({ ok: true });
    expect(await followers(id)).toEqual([{ platform: 'ios', token: IOS, sandbox: true, alerts: true }]);
    expect((await follow(id, { platform: 'ios', token: 'nothex' })).status).toBe(400);
    expect((await follow(id, { platform: 'android', token: ANDROID, alerts: false })).status).toBe(201);
    expect((await follow(id, { platform: 'android', token: 'third' })).status).toBe(201);
    expect((await follow(id, { platform: 'android', token: 'one-too-many' })).status).toBe(429);
    expect((await call('DELETE', `/api/team/${id}/followers`, { platform: 'android', token: 'third' })).status).toBe(204);
    expect((await call('DELETE', `/api/team/${id}/followers`, { platform: 'android' })).status).toBe(400);
    expect((await followers(id)).length).toBe(2);
    // Registering pushes nothing
    expect(sent).toEqual([]);

    expect((await call('DELETE', `/api/team/${id}`, undefined, ownerKey)).status).toBe(204);
    await pushesDone(id);
    const left = await runInDurableObject(stub(id), async (_, state) => (await state.storage.list()).size);
    expect(left).toBe(0);
    expect((await follow(id, { platform: 'ios', token: IOS })).status).toBe(404);
    expect((await call('DELETE', `/api/team/${id}/followers`, { platform: 'ios', token: IOS })).status).toBe(404);
    expect((await follow('aaaaaaaaaaaa', { platform: 'ios', token: IOS })).status).toBe(404);
  });
});

describe('team photos', () => {
  it('put, get, flags and version, replace, cleared with the slot', async () => {
    const { id, writeKey, ownerKey } = await newTeam();
    const start = (await call('GET', `/api/team/${id}`)).json;
    expect(start.photos).toEqual({ 1: [false, false], 2: [false, false], 3: [false, false], 4: [false, false] });
    expect(start.photoVersion).toBe(0);

    expect((await call('PUT', `/api/team/${id}/partij/2/photos`, { p1: JPEG, p2: null })).status).toBe(401);
    expect((await call('PUT', `/api/team/${id}/partij/2/photos`, { p1: JPEG }, 'wrong')).status).toBe(401);
    expect((await call('PUT', `/api/team/${id}/partij/5/photos`, { p1: JPEG }, writeKey)).status).toBe(404);
    expect((await call('PUT', '/api/team/aaaaaaaaaaaa/partij/2/photos', { p1: JPEG }, writeKey)).status).toBe(404);
    expect((await call('PUT', `/api/team/${id}/partij/2/photos`, 'text', writeKey)).status).toBe(400);
    // Too large a body
    const big = 'A'.repeat(24 * 1024 * 3 + 10);
    expect((await call('PUT', `/api/team/${id}/partij/2/photos`, { p1: big }, writeKey)).status).toBe(413);

    // Writer key; a non-JPEG is no photo
    expect((await call('PUT', `/api/team/${id}/partij/2/photos`, { p1: JPEG, p2: btoa('not a jpeg') }, writeKey)).status).toBe(204);
    let state = (await call('GET', `/api/team/${id}`)).json;
    expect(state.photos['2']).toEqual([true, false]);
    expect(state.photos['1']).toEqual([false, false]);
    expect(state.photoVersion).toBe(1);
    const photo = await call('GET', `/api/team/${id}/photo/2/1`);
    expect(photo.status).toBe(200);
    expect(photo.headers.get('content-type')).toBe('image/jpeg');
    expect(photo.headers.get('cache-control')).toBe('no-store');
    expect(Array.from(photo.bytes)).toEqual([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
    expect((await call('GET', `/api/team/${id}/photo/2/2`)).status).toBe(404);
    expect((await call('GET', `/api/team/${id}/photo/1/1`)).status).toBe(404);
    expect((await call('GET', `/api/team/${id}/photo/9/1`)).status).toBe(404);
    expect((await call('GET', `/api/team/${id}/photo/2/3`)).status).toBe(404);

    // Owner key, both photos, another slot
    expect((await call('PUT', `/api/team/${id}/partij/3/photos`, { p1: JPEG, p2: JPEG2 }, ownerKey)).status).toBe(204);
    state = (await call('GET', `/api/team/${id}`)).json;
    expect(state.photos['3']).toEqual([true, true]);
    expect(state.photoVersion).toBe(2);
    expect(Array.from((await call('GET', `/api/team/${id}/photo/3/2`)).bytes)).toEqual([0xff, 0xd8, 0xff, 0xe1, 9, 9]);

    // Clearing slot 3 drops its photos, slot 2 keeps them
    await call('PUT', `/api/team/${id}/partij/3`, playing, writeKey);
    expect((await call('PUT', `/api/team/${id}/partij/3`, { empty: true }, writeKey)).status).toBe(204);
    state = (await call('GET', `/api/team/${id}`)).json;
    expect(state.photos['3']).toEqual([false, false]);
    expect(state.photos['2']).toEqual([true, false]);
    expect(state.photoVersion).toBe(3);
    expect((await call('GET', `/api/team/${id}/photo/3/1`)).status).toBe(404);
    // Clearing a slot without photos does not bump the version
    await call('PUT', `/api/team/${id}/partij/4`, { empty: true }, writeKey);
    expect((await call('GET', `/api/team/${id}`)).json.photoVersion).toBe(3);

    await call('DELETE', `/api/team/${id}`, undefined, ownerKey);
    expect((await call('GET', `/api/team/${id}/photo/2/1`)).status).toBe(404);
  });
});

describe('team payload', () => {
  it('only slots with a partij, sorted, without games, last point or order; end when given', () => {
    const partijen = {
      3: won('Paul', '', [3, 1], 1),
      1: playing,
      4: won('', 'Kees', [0, 3], 2, { end: 'walkover', endAfter: 0 }),
    };
    const state = teamContentState(team, partijen);
    expect(state).toEqual({
      home: 'All Inn 8', away: 'Delft 8',
      partijen: [
        { slot: 1, p1: 'Gerd-Jan', p2: 'Thomas', bestOf: 5, gamesWon: [1, 0], score: [3, 2], status: 'playing' },
        { slot: 3, p1: 'Paul', p2: '', bestOf: 5, gamesWon: [3, 1], score: [0, 0], status: 'finished', winner: 1 },
        { slot: 4, p1: '', p2: 'Kees', bestOf: 5, gamesWon: [0, 3], score: [0, 0], status: 'finished', winner: 2, end: 'walkover' },
      ],
    });
  });

  it('stays below 4 KB for APNs with the longest names', () => {
    const longTeam = { home: 'W'.repeat(40), away: 'M'.repeat(40) };
    const partijen = {};
    for (const slot of [1, 2, 3, 4]) {
      partijen[slot] = won('Ä'.repeat(20), 'Ö'.repeat(20), [3, 2], 1, { end: 'retired', score: [99, 99] });
    }
    const state = teamContentState(longTeam, partijen);
    const alert = { title: `Uitslag: ${'W'.repeat(40)} wint 12–8`, body: `${'W'.repeat(40)} – ${'M'.repeat(40)} · partijen 4–0` };
    const body = JSON.stringify(apnsPayload(state, 'end', Date.now(), alert, true));
    expect(new TextEncoder().encode(body).length).toBeLessThan(4096);
    const fcm = JSON.stringify(fcmPayload('t', 'abcdefghjkmn', BASE, state, 'end', alert, 'team'));
    expect(new TextEncoder().encode(fcm).length).toBeLessThan(4096);
  });

  it('decided: a winner, finished, or given up / not played', () => {
    expect(partijDecided(undefined)).toBe(false);
    expect(partijDecided(playing)).toBe(false);
    expect(partijDecided({ ...playing, winner: 2 })).toBe(true);
    expect(partijDecided({ ...playing, status: 'finished' })).toBe(true);
    expect(partijDecided({ ...playing, end: 'retired' })).toBe(true);
    expect(partijDecided({ ...playing, end: 'walkover' })).toBe(true);
  });

  it('alerts: a partij decided, given up, not played, the result, a draw; nothing per rally', () => {
    expect(teamAlert({}, team, { 1: playing })).toBeNull();
    expect(teamAlert({ 1: playing }, team, { 1: { ...playing, score: [4, 2] } })).toBeNull();
    // Game won within a partij: no alert in a team match
    expect(teamAlert({ 1: playing }, team, { 1: { ...playing, gamesWon: [2, 0], status: 'between' } })).toBeNull();
    const two = { 1: playing, 2: won('Paul', 'Jan', [3, 1], 1) };
    expect(teamAlert({ 1: playing }, team, two)).toEqual({ title: 'E2: Paul wint 3–1', body: 'All Inn 8 4 – 1 Delft 8' });
    // Already decided before: no second alert
    expect(teamAlert(two, team, two)).toBeNull();
    // No name: the team and slot
    expect(teamAlert({}, team, { 2: won('Paul', '', [1, 3], 2) }).title).toBe('E2: Delft 8 E2 wint 3–1');
    expect(teamAlert({}, team, { 3: won('Paul', 'Jan', [1, 0], 2, { end: 'retired' }) }).title).toBe('E3: Jan wint (opgave)');
    expect(teamAlert({}, team, { 4: won('', 'Kees', [0, 3], 2, { end: 'walkover' }) }).title).toBe('E4: Kees wint (walkover)');

    const three = { 1: won('A', 'B', [3, 0], 1), 2: won('C', 'D', [3, 1], 1), 3: won('E', 'F', [3, 2], 1) };
    const all = { ...three, 4: won('G', 'H', [0, 3], 2) };
    expect(teamAlert(three, team, all)).toEqual({ title: 'Uitslag: All Inn 8 wint 9–6', body: 'All Inn 8 – Delft 8 · partijen 3–1' });
    expect(teamAlert(all, team, all)).toBeNull();
    const draw = { 1: won('A', 'B', [3, 0], 1), 2: won('C', 'D', [0, 3], 2), 3: won('E', 'F', [3, 2], 1), 4: won('G', 'H', [2, 3], 2) };
    // SBN rule: 2–2 in partijen and 8–8 in games, both teams full: the team that won E1
    expect(teamAlert({ 1: draw[1], 2: draw[2], 3: draw[3] }, team, draw).title).toBe('Uitslag: All Inn 8 wint 8–8');
    // Most partijen wins, even with fewer games
    const partijenFirst = { 1: won('A', 'B', [3, 2], 1), 2: won('C', 'D', [3, 2], 1), 3: won('E', 'F', [3, 2], 1), 4: won('G', 'H', [0, 3], 2) };
    expect(teamWinner(partijenFirst)).toBe(1);
    const fewerGames = { 1: won('A', 'B', [3, 2], 1), 2: won('C', 'D', [3, 2], 1), 3: won('E', 'F', [0, 3], 2), 4: won('G', 'H', [0, 3], 2) };
    expect(teamWinner(fewerGames)).toBe(2);
    // Equal partijen, a team that lost a walkover is not full
    const walkover = { 1: won('A', 'B', [3, 0], 1), 2: won('C', 'D', [3, 0], 1), 3: won('', 'F', [0, 3], 2, { end: 'walkover' }), 4: won('G', 'H', [0, 3], 2) };
    expect(teamWinner(walkover)).toBe(2);
    const awayWins = { 1: won('A', 'B', [0, 3], 2), 2: won('C', 'D', [0, 3], 2), 3: won('E', 'F', [3, 2], 1), 4: won('G', 'H', [1, 3], 2) };
    expect(teamAlert({}, team, awayWins)).toEqual({ title: 'Uitslag: Delft 8 wint 11–4', body: 'All Inn 8 – Delft 8 · partijen 1–3' });
  });
});

describe('team pushes', () => {
  it('every partij and team change is an update; alerts only when a partij is decided; the FCM data', async () => {
    const { id, writeKey, ownerKey } = await newTeam();
    await follow(id, { platform: 'ios', token: IOS });
    await follow(id, { platform: 'android', token: ANDROID });

    const before = Math.floor(Date.now() / 1000);
    expect((await call('PUT', `/api/team/${id}/partij/1`, playing, writeKey)).status).toBe(204);
    await pushesDone(id);
    let [aps] = apnsBodies();
    expect(aps.event).toBe('update');
    expect(aps.timestamp).toBeGreaterThanOrEqual(before);
    expect(aps['stale-date']).toBe(aps.timestamp + 900);
    expect(aps.alert).toBeUndefined();
    const expected = {
      home: 'All Inn 8', away: 'Delft 8',
      partijen: [{ slot: 1, p1: 'Gerd-Jan', p2: 'Thomas', bestOf: 5, gamesWon: [1, 0], score: [3, 2], status: 'playing' }],
    };
    expect(aps['content-state']).toEqual(expected);
    const apnsRequest = sent.find((r) => r.url.includes('push.apple.com'));
    expect(apnsRequest.url).toBe(`https://api.push.apple.com/3/device/${IOS}`);
    expect(apnsRequest.headers['apns-topic']).toBe('com.squashanalyzer.app.push-type.liveactivity');
    expect(apnsRequest.headers['apns-push-type']).toBe('liveactivity');
    let [message] = fcmData();
    expect(message.android).toEqual({ priority: 'high', ttl: '300s', collapse_key: id });
    expect(message.data).toEqual({ kind: 'team', id, server: BASE, event: 'update', team: JSON.stringify(expected) });

    // A partij decided: alert on both
    sent = [];
    await call('PUT', `/api/team/${id}/partij/2`, won('Paul', 'Jan', [3, 1], 1), writeKey);
    await pushesDone(id);
    [aps] = apnsBodies();
    expect(aps.event).toBe('update');
    expect(aps.alert).toEqual({ title: 'E2: Paul wint 3–1', body: 'All Inn 8 4 – 1 Delft 8' });
    expect(aps.sound).toBe('default');
    [message] = fcmData();
    expect(message.data.alertTitle).toBe('E2: Paul wint 3–1');
    expect(message.data.alertBody).toBe('All Inn 8 4 – 1 Delft 8');

    // New team names (owner): an update without alert
    sent = [];
    expect((await call('PUT', `/api/team/${id}`, { ...header, away: 'Squash Delft 8' }, ownerKey)).status).toBe(204);
    await pushesDone(id);
    [aps] = apnsBodies();
    expect(aps.event).toBe('update');
    expect(aps.alert).toBeUndefined();
    expect(aps['content-state'].away).toBe('Squash Delft 8');
    expect(aps['content-state'].partijen.map((p) => p.slot)).toEqual([1, 2]);

    // Cleared slot: an update without it
    sent = [];
    await call('PUT', `/api/team/${id}/partij/2`, { empty: true }, writeKey);
    await pushesDone(id);
    expect(apnsBodies()[0]['content-state'].partijen.map((p) => p.slot)).toEqual([1]);

    // Live stoppen: the end once, gone in a minute, no alert
    sent = [];
    await call('DELETE', `/api/team/${id}`, undefined, ownerKey);
    await pushesDone(id);
    [aps] = apnsBodies();
    expect(aps.event).toBe('end');
    expect(aps['dismissal-date']).toBe(aps.timestamp + 60);
    expect(aps.alert).toBeUndefined();
    expect(fcmData()[0].data.event).toBe('end');
    expect(fcmData()[0].data.kind).toBe('team');
  });

  it('all four decided: the end with the result once; a correction resumes the updates; no second end at Live stoppen', async () => {
    const { id, writeKey, ownerKey } = await newTeam();
    await follow(id, { platform: 'ios', token: IOS });
    await follow(id, { platform: 'android', token: ANDROID, alerts: false });
    await call('PUT', `/api/team/${id}/partij/1`, won('A', 'B', [3, 0], 1), writeKey);
    await call('PUT', `/api/team/${id}/partij/2`, won('C', 'D', [3, 1], 1), writeKey);
    await call('PUT', `/api/team/${id}/partij/3`, won('E', 'F', [3, 2], 1), writeKey);
    await pushesDone(id);
    expect(apnsBodies().map((a) => a.event)).toEqual(['update', 'update', 'update']);
    // The follower without alerts gets the same stand without one
    expect(fcmData().every((m) => m.data.alertTitle === undefined)).toBe(true);

    sent = [];
    await call('PUT', `/api/team/${id}/partij/4`, won('G', 'H', [0, 3], 2, { end: 'retired' }), writeKey);
    await pushesDone(id);
    let [aps] = apnsBodies();
    expect(aps.event).toBe('end');
    expect(aps['dismissal-date']).toBe(aps.timestamp + 4 * 3600);
    expect(aps['stale-date']).toBeUndefined();
    expect(aps.alert).toEqual({ title: 'Uitslag: All Inn 8 wint 9–6', body: 'All Inn 8 – Delft 8 · partijen 3–1' });
    expect(aps['content-state'].partijen[3]).toEqual({
      slot: 4, p1: 'G', p2: 'H', bestOf: 5, gamesWon: [0, 3], score: [0, 0], status: 'finished', winner: 2, end: 'retired',
    });
    expect(fcmData()[0].data.event).toBe('end');
    expect(fcmData()[0].data.alertTitle).toBeUndefined();

    // Still all decided (a corrected score, new names): nothing more
    sent = [];
    await call('PUT', `/api/team/${id}/partij/1`, won('A', 'B', [3, 1], 1), writeKey);
    await call('PUT', `/api/team/${id}`, header, ownerKey);
    await pushesDone(id);
    expect(sent).toEqual([]);

    // E4 corrected back to playing: updates again, then decided again: a new end with the result
    await call('PUT', `/api/team/${id}/partij/4`, playing, writeKey);
    await pushesDone(id);
    [aps] = apnsBodies();
    expect(aps.event).toBe('update');
    expect(aps.alert).toBeUndefined();
    sent = [];
    await call('PUT', `/api/team/${id}/partij/4`, won('G', 'H', [3, 0], 1), writeKey);
    await pushesDone(id);
    [aps] = apnsBodies();
    expect(aps.event).toBe('end');
    expect(aps.alert.title).toBe('Uitslag: All Inn 8 wint 12–4');

    // Live stoppen after the end: nothing more
    sent = [];
    expect((await call('DELETE', `/api/team/${id}`, undefined, ownerKey)).status).toBe(204);
    await pushesDone(id);
    expect(sent).toEqual([]);
  });

  it('the idle alarm sends the end once, gone in a minute', async () => {
    const { id, writeKey } = await newTeam();
    await follow(id, { platform: 'ios', token: IOS });
    await call('PUT', `/api/team/${id}/partij/1`, playing, writeKey);
    await pushesDone(id);
    sent = [];
    expect(await runDurableObjectAlarm(stub(id))).toBe(true);
    await pushesDone(id);
    const [aps] = apnsBodies();
    expect(aps.event).toBe('end');
    expect(aps['dismissal-date']).toBe(aps.timestamp + 60);
    expect(aps['content-state'].partijen.length).toBe(1);
    expect((await call('GET', `/api/team/${id}`)).status).toBe(404);
  });

  it('without followers nothing is sent', async () => {
    const { id, writeKey, ownerKey } = await newTeam();
    await call('PUT', `/api/team/${id}/partij/1`, playing, writeKey);
    await call('DELETE', `/api/team/${id}`, undefined, ownerKey);
    await pushesDone(id);
    expect(sent).toEqual([]);
  });
});
