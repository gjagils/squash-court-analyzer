// "Je team is begonnen" (21 November 2026): a signed-in phone leaves its push
// token; when someone makes a team match visible for the team, the phones of
// the other accounts of that team are signed up at the live Worker.
import { env } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { deps, wipeOldRequests } from '../src/index.js';
import { call, newPlayer } from './helpers.js';

const LEAGUE = '0A1B2C3D-0000-4000-8000-0000000000CC';
const IOS = 'ab'.repeat(32);
const ANDROID = 'fcm-token:abc_DEF-123.x';
let counter = 0;
const team = () => `${LEAGUE}/${900 + counter++}`;
const registration = (extra = {}) => ({
  fixture: `/league/${LEAGUE}/team-match/${7000 + counter++}`, date: Date.now() + 3600 * 1000, teamName: 'Squash City 2',
  liveId: `live${String(100000000 + counter++).slice(1)}`, writeKey: 'w'.repeat(43), ...extra,
});
const putPush = (auth, body) => call('PUT', '/api/v1/me/push', { auth, body });
const tokensOf = async (playerId) =>
  (await env.DB.prepare('SELECT * FROM push_tokens WHERE player_id = ? ORDER BY token').bind(playerId).all()).results;

let sent = [];
const realFetch = deps.fetch;
const realNow = deps.now;
beforeEach(() => {
  sent = [];
  env.LIVE_SERVER = 'https://live.test/';
  deps.fetch = async (url, init) => {
    sent.push({ url, body: JSON.parse(init.body) });
    return new Response(null, { status: 201 });
  };
});
afterEach(() => {
  deps.fetch = realFetch;
  deps.now = realNow;
});

describe('the push token of a phone', () => {
  it('is kept per account, replaced, and bad ones are refused', async () => {
    const kees = await newPlayer({ name: 'Kees', teamKey: team() });
    expect((await putPush(kees.auth, { platform: 'ios', token: IOS.toUpperCase(), sandbox: true, lang: 'en', device: 'device-aaaa-1111' })).status).toBe(204);
    expect((await putPush(kees.auth, { platform: 'ios', token: IOS, lang: 'xx' })).status).toBe(204);
    const rows = await tokensOf(kees.player.playerId);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ platform: 'ios', token: IOS, sandbox: 0, lang: 'nl', device: null });
    expect((await putPush(kees.auth, { platform: 'ios', token: 'nope' })).status).toBe(400);
    expect((await putPush(kees.auth, { platform: 'web', token: IOS })).status).toBe(400);
    expect((await call('PUT', '/api/v1/me/push', { body: { platform: 'ios', token: IOS } })).status).toBe(401);
  });

  it('moves to the account that signs in on the phone, and goes on sign-out, with the account and after 60 days', async () => {
    const shared = team();
    const kees = await newPlayer({ name: 'Kees', teamKey: shared });
    const jan = await newPlayer({ name: 'Jan', teamKey: shared });
    await putPush(kees.auth, { platform: 'android', token: ANDROID });
    await putPush(jan.auth, { platform: 'android', token: ANDROID });
    expect(await tokensOf(kees.player.playerId)).toHaveLength(0);
    expect(await tokensOf(jan.player.playerId)).toHaveLength(1);

    expect((await call('DELETE', '/api/v1/me/push', { auth: jan.auth, body: { token: ANDROID } })).status).toBe(204);
    expect(await tokensOf(jan.player.playerId)).toHaveLength(0);

    await putPush(kees.auth, { platform: 'ios', token: IOS });
    await putPush(jan.auth, { platform: 'android', token: ANDROID });
    expect((await call('DELETE', '/api/v1/me', { auth: kees.auth })).status).toBe(204);
    expect(await tokensOf(kees.player.playerId)).toHaveLength(0);

    deps.now = () => Date.now() + 61 * 24 * 3600 * 1000;
    await wipeOldRequests(env);
    expect(await tokensOf(jan.player.playerId)).toHaveLength(0);
  });
});

describe('je team is begonnen', () => {
  it('signs the phones of the teammates up at the live Worker, once, and not the starter or another team', async () => {
    const shared = team();
    const kees = await newPlayer({ name: 'Kees', teamKey: shared });
    const jan = await newPlayer({ name: 'Jan', teamKey: shared });
    const piet = await newPlayer({ name: 'Piet', teamKey: shared });
    const other = await newPlayer({ name: 'Other', teamKey: team() });
    await putPush(kees.auth, { platform: 'ios', token: 'cd'.repeat(32) });
    await putPush(jan.auth, { platform: 'ios', token: IOS, sandbox: true, lang: 'en', device: 'device-bbbb-2222' });
    await putPush(piet.auth, { platform: 'android', token: ANDROID });
    await putPush(other.auth, { platform: 'android', token: 'other-token' });

    const first = registration();
    expect((await call('PUT', '/api/v1/me/team/lives', { auth: kees.auth, body: first })).status).toBe(200);
    expect(sent).toHaveLength(2);
    expect(sent.every((request) => request.url === `https://live.test/api/team/${first.liveId}/followers`)).toBe(true);
    expect(sent.map((request) => request.body)).toContainEqual({
      platform: 'ios', token: IOS, mode: 'alerts', lang: 'en', announce: true, sandbox: true, device: 'device-bbbb-2222',
    });
    expect(sent.map((request) => request.body)).toContainEqual({
      platform: 'android', token: ANDROID, mode: 'alerts', lang: 'nl', announce: true,
    });

    // The same registration again, and a teammate who comes second: nobody is told again
    sent = [];
    expect((await call('PUT', '/api/v1/me/team/lives', { auth: kees.auth, body: first })).status).toBe(200);
    const second = { ...first, liveId: `live${String(100000000 + counter++).slice(1)}` };
    expect((await call('PUT', '/api/v1/me/team/lives', { auth: jan.auth, body: second })).status).toBe(409);
    expect(sent).toEqual([]);
  });

  it('a live Worker that does not answer never fails the registration; without LIVE_SERVER nothing is sent', async () => {
    const shared = team();
    const kees = await newPlayer({ name: 'Kees', teamKey: shared });
    const jan = await newPlayer({ name: 'Jan', teamKey: shared });
    await putPush(jan.auth, { platform: 'android', token: ANDROID });
    deps.fetch = async () => { throw new Error('down'); };
    expect((await call('PUT', '/api/v1/me/team/lives', { auth: kees.auth, body: registration() })).status).toBe(200);
    env.LIVE_SERVER = '';
    let asked = 0;
    deps.fetch = async () => { asked += 1; return new Response(null, { status: 201 }); };
    expect((await call('PUT', '/api/v1/me/team/lives', { auth: kees.auth, body: registration() })).status).toBe(200);
    expect(asked).toBe(0);
  });
});
