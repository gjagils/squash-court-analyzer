// Live score op het vergrendelscherm for team matches: followers, photos per
// partij and the pushes to APNs and FCM (project "push": throwaway keys, a fake
// fetch, MAX_FOLLOWERS_PER_SESSION 3).
import { SELF, env, runDurableObjectAlarm, runInDurableObject } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  alertForFollower, apnsPayload, clearPushTokenCaches, fcmPayload, partijDecided, pushDeps, teamAlert, teamAlerts, teamContentState,
  teamWinner,
} from '../src/push.js';

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
    expect(await followers(id)).toEqual([{ platform: 'ios', token: IOS, sandbox: true, alerts: true, lang: 'nl' }]);
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
  it('only slots with a partij, sorted, without games, last point or order; end when given; server in a rally', () => {
    const partijen = {
      3: won('Paul', '', [3, 1], 1),
      1: { ...playing, server: 2 },
      2: { ...playing, status: 'between' },
      4: won('', 'Kees', [0, 3], 2, { end: 'walkover', endAfter: 0 }),
    };
    const state = teamContentState(team, partijen);
    expect(state).toEqual({
      home: 'All Inn 8', away: 'Delft 8',
      partijen: [
        { slot: 1, p1: 'Gerd-Jan', p2: 'Thomas', bestOf: 5, gamesWon: [1, 0], score: [3, 2], status: 'playing', server: 2 },
        { slot: 2, p1: 'Gerd-Jan', p2: 'Thomas', bestOf: 5, gamesWon: [1, 0], score: [3, 2], status: 'between' },
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

  it('alerts in English: the same names and scores, English words', () => {
    const two = { 1: playing, 2: won('Paul', 'Jan', [3, 1], 1) };
    expect(teamAlert({ 1: playing }, team, two, 'en')).toEqual({ title: 'E2: Paul wins 3–1', body: 'All Inn 8 4 – 1 Delft 8' });
    expect(teamAlert({}, team, { 3: won('Paul', 'Jan', [1, 0], 2, { end: 'retired' }) }, 'en').title).toBe('E3: Jan wins (retired)');
    expect(teamAlert({}, team, { 4: won('', 'Kees', [0, 3], 2, { end: 'walkover' }) }, 'en').title).toBe('E4: Kees wins (walkover)');
    expect(teamAlert({}, team, { 1: { ...playing, gamesWon: [1, 1], status: 'finished' } }, 'en').title).toBe('E1: done');
    const three = { 1: won('A', 'B', [3, 0], 1), 2: won('C', 'D', [3, 1], 1), 3: won('E', 'F', [3, 2], 1) };
    const all = { ...three, 4: won('G', 'H', [0, 3], 2) };
    expect(teamAlert(three, team, all, 'en')).toEqual({ title: 'Result: All Inn 8 wins 9–6', body: 'All Inn 8 – Delft 8 · matches 3–1' });
  });

  it('each follower gets the team alert in its own language', async () => {
    const { id, writeKey } = await newTeam();
    await follow(id, { platform: 'ios', token: IOS, lang: 'nl' });
    await follow(id, { platform: 'android', token: ANDROID, lang: 'en' });
    await call('PUT', `/api/team/${id}/partij/2`, won('Paul', 'Jan', [3, 1], 1), writeKey);
    await pushesDone(id);
    expect(apnsBodies()[0].alert.title).toBe('E2: Paul wint 3–1');
    expect(fcmData()[0].data.alertTitle).toBe('E2: Paul wins 3–1');
    // The stand is the same for both
    expect(JSON.parse(fcmData()[0].data.team)).toEqual(apnsBodies()[0]['content-state']);
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
      partijen: [{ slot: 1, p1: 'Gerd-Jan', p2: 'Thomas', bestOf: 5, gamesWon: [1, 0], score: [3, 2], status: 'playing', server: 1 }],
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

// 4.0 (T6): the players of a team match follow it with plain notifications
const DEVICE_A = 'device-aaaa-1111';
const DEVICE_B = 'device-bbbb-2222';
const IOS_DEVICE = 'cd'.repeat(32);

async function writeAs(device, id, slot, partij, key) {
  const headers = { 'Content-Type': 'application/json', 'CF-Connecting-IP': nextIp(), Authorization: `Bearer ${key}` };
  if (device) headers['X-Squash-Device'] = device;
  const res = await SELF.fetch(`${BASE}/api/team/${id}/partij/${slot}`, { method: 'PUT', headers, body: JSON.stringify(partij) });
  await res.arrayBuffer();
  return res.status;
}

const apnsRequests = () => sent.filter((r) => r.url.includes('push.apple.com'));

describe('alerts followers', () => {
  it('register with mode and device; apart from a lock screen follower with the same token; not for a single match', async () => {
    const { id } = await newTeam();
    expect((await follow(id, { platform: 'android', token: ANDROID, mode: 'alerts', device: DEVICE_A, lang: 'en' })).status).toBe(201);
    expect((await follow(id, { platform: 'android', token: ANDROID })).status).toBe(201);
    const list = await followers(id);
    expect(list.length).toBe(2);
    expect(list).toContainEqual({ platform: 'android', token: ANDROID, sandbox: false, alerts: true, lang: 'en', mode: 'alerts', device: DEVICE_A });
    expect(list).toContainEqual({ platform: 'android', token: ANDROID, sandbox: false, alerts: true, lang: 'nl' });
    // Forgetting the alerts follower keeps the lock screen one
    expect((await call('DELETE', `/api/team/${id}/followers`, { platform: 'android', token: ANDROID, mode: 'alerts' })).status).toBe(204);
    expect(await followers(id)).toEqual([{ platform: 'android', token: ANDROID, sandbox: false, alerts: true, lang: 'nl' }]);
    // An unknown mode, and alerts on a single match, are refused
    expect((await follow(id, { platform: 'android', token: ANDROID, mode: 'other' })).status).toBe(400);
    const live = await call('POST', '/api/live', playing);
    expect(live.status).toBe(201);
    expect((await call('POST', `/api/live/${live.json.id}/followers`, { platform: 'android', token: ANDROID, mode: 'alerts' })).status).toBe(400);
    // A bad device id is left out
    expect((await follow(id, { platform: 'ios', token: IOS_DEVICE, mode: 'alerts', device: 'bad id!' })).status).toBe(201);
    expect((await followers(id)).find((f) => f.platform === 'ios').device).toBeUndefined();
  });

  it("a teammate's partij started and decided, the result; nothing per rally; not about the own partij; no lock screen push", async () => {
    const { id, writeKey } = await newTeam();
    await follow(id, { platform: 'ios', token: IOS_DEVICE, sandbox: true, mode: 'alerts', device: DEVICE_A });
    await follow(id, { platform: 'android', token: ANDROID, mode: 'alerts', device: DEVICE_B, lang: 'en' });

    // Phone A starts E1: B hears about it, A not
    expect(await writeAs(DEVICE_A, id, 1, playing, writeKey)).toBe(204);
    await pushesDone(id);
    expect(apnsRequests()).toEqual([]);
    const [message] = fcmData();
    expect(message.data).toEqual({
      kind: 'alert', id, server: BASE, slot: '1', alertTitle: 'E1 started: Gerd-Jan – Thomas', alertBody: 'All Inn 8 1 – 0 Delft 8',
    });
    expect(message.android).toEqual({ priority: 'high', ttl: '600s' });

    // A rally and a game in E1: nothing
    sent = [];
    await writeAs(DEVICE_A, id, 1, { ...playing, score: [5, 2] }, writeKey);
    await writeAs(DEVICE_A, id, 1, { ...playing, gamesWon: [2, 0], status: 'between' }, writeKey);
    await pushesDone(id);
    expect(sent).toEqual([]);

    // Phone B starts E2 without names: A hears it, as a plain APNs alert
    await writeAs(DEVICE_B, id, 2, { ...playing, p1: '', p2: '' }, writeKey);
    await pushesDone(id);
    expect(fcmData()).toEqual([]);
    const [request] = apnsRequests();
    expect(request.url).toBe(`https://api.sandbox.push.apple.com/3/device/${IOS_DEVICE}`);
    expect(request.headers['apns-push-type']).toBe('alert');
    expect(request.headers['apns-topic']).toBe('com.squashanalyzer.app');
    expect(JSON.parse(request.body)).toEqual({
      aps: { alert: { title: 'E2 begonnen: All Inn 8 E2 – Delft 8 E2', body: 'All Inn 8 3 – 0 Delft 8' }, sound: 'default', 'thread-id': `team-${id}` },
      kind: 'team', id, slot: 2,
    });

    // E1 decided by A: only B; then E2 decided by B: only A
    sent = [];
    await writeAs(DEVICE_A, id, 1, won('Gerd-Jan', 'Thomas', [3, 1], 1), writeKey);
    await pushesDone(id);
    expect(apnsRequests()).toEqual([]);
    expect(fcmData()[0].data.alertTitle).toBe('E1: Gerd-Jan wins 3–1');
    sent = [];
    await writeAs(DEVICE_B, id, 2, won('', '', [0, 3], 2), writeKey);
    await pushesDone(id);
    expect(fcmData()).toEqual([]);
    expect(JSON.parse(apnsRequests()[0].body).aps.alert.title).toBe('E2: Delft 8 E2 wint 3–0');

    // E3 from a phone without an install id (an app before 4.0): both hear it
    sent = [];
    await writeAs(null, id, 3, won('E', 'F', [3, 2], 1), writeKey);
    await pushesDone(id);
    expect(apnsRequests().length).toBe(1);
    expect(fcmData().length).toBe(1);

    // The last one by A: the result for everyone, A too
    sent = [];
    await writeAs(DEVICE_A, id, 4, won('G', 'H', [3, 0], 1), writeKey);
    await pushesDone(id);
    expect(JSON.parse(apnsRequests()[0].body).aps.alert.title).toBe('Uitslag: All Inn 8 wint 9–6');
    expect(fcmData()[0].data.alertTitle).toBe('Result: All Inn 8 wins 9–6');
  });

  it('decided before started; a cleared slot forgets its writers; dead tokens go; no end at Live stoppen', async () => {
    const { id, writeKey, ownerKey } = await newTeam();
    await follow(id, { platform: 'android', token: ANDROID, mode: 'alerts', device: DEVICE_B });
    await writeAs(DEVICE_B, id, 1, playing, writeKey);
    await pushesDone(id);
    expect(sent).toEqual([]);
    // B clears E1; A puts a partij there: B hears it now
    await writeAs(DEVICE_B, id, 1, { empty: true }, writeKey);
    await writeAs(DEVICE_A, id, 1, playing, writeKey);
    await pushesDone(id);
    expect(fcmData().map((m) => m.data.alertTitle)).toEqual(['E1 begonnen: Gerd-Jan – Thomas']);

    // The order of the list: decided first, then started
    const list = teamAlerts({ 1: playing }, team, { 1: won('A', 'B', [3, 0], 1), 2: playing });
    expect(list.map((a) => [a.slot, Boolean(a.started)])).toEqual([[1, false], [2, true]]);
    expect(alertForFollower({ device: DEVICE_A }, list, { 1: [DEVICE_A] }).slot).toBe(2);
    expect(alertForFollower({}, list, { 1: [DEVICE_A] }).slot).toBe(1);
    // The lock screen alert never says "started"
    expect(teamAlert({}, team, { 2: playing })).toBeNull();

    // FCM says the token is gone: forgotten
    sent = [];
    pushDeps.fetch = (url, init) => {
      sent.push({ url, headers: init.headers, body: init.body });
      if (url === 'https://oauth2.googleapis.com/token') return new Response(JSON.stringify({ access_token: 'ya29.test' }), { status: 200 });
      return new Response(JSON.stringify({ error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }), { status: 404 });
    };
    await writeAs(DEVICE_A, id, 2, playing, writeKey);
    await pushesDone(id);
    expect(await followers(id)).toEqual([]);

    pushDeps.fetch = fakeFetch;
    await follow(id, { platform: 'android', token: ANDROID, mode: 'alerts', device: DEVICE_B });
    sent = [];
    expect((await call('DELETE', `/api/team/${id}`, undefined, ownerKey)).status).toBe(204);
    await pushesDone(id);
    expect(sent).toEqual([]);
  });
});
