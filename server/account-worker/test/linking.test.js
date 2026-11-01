// Linking without a player code (1 November 2026): matches wait for an SBN
// player, for a name in a team, or for whoever opens a shared link.
import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { deps, wipeOldRequests } from '../src/index.js';
import { aMatch, call, newDevice, newPlayer } from './helpers.js';

let teamCounter = 0;
const aTeam = () => `0A1B2C3D-0000-4000-8000-00000000000${teamCounter % 10}/${100 + teamCounter++}`;
let pathCounter = 0;
const aPath = () => `/league/0A1B2C3D-0000-4000-8000-000000000000/player/${1000 + pathCounter++}`;
const send = (device, match, to) => call('POST', '/api/v1/submissions', { auth: device, body: { ...match, to } });

describe('a match for an SBN player without an account', () => {
  it('waits and lands in the inbox when the player makes an account', async () => {
    const path = aPath();
    const device = await newDevice();
    const match = aMatch();
    const sent = await send(device, match, { sbnPath: path });
    expect(sent.status).toBe(202);
    expect(sent.json).toEqual({ received: match.matchId });
    const { auth } = await newPlayer({ sbnPath: path });
    const inbox = await call('GET', '/api/v1/me/inbox', { auth });
    expect(inbox.json.matches.map((m) => m.matchId)).toEqual([match.matchId]);
    const left = await env.DB.prepare('SELECT COUNT(*) AS n FROM open_matches WHERE target = ?').bind(`sbn:${path}`).first();
    expect(left.n).toBe(0);
  });

  it('also when the SBN player is chosen later, but only once', async () => {
    const path = aPath();
    const device = await newDevice();
    const match = aMatch();
    await send(device, match, { sbnPath: path });
    const { auth } = await newPlayer();
    const set = await call('PATCH', '/api/v1/me', { auth, body: { sbnPath: path } });
    expect(set.json.sbnPath).toBe(path);
    expect((await call('GET', '/api/v1/me/inbox', { auth })).json.matches).toHaveLength(1);
    expect((await call('PATCH', '/api/v1/me', { auth, body: { sbnPath: aPath() } })).json.error).toBe('sbnPath set');
    const other = await newPlayer();
    expect((await call('PATCH', '/api/v1/me', { auth: other.auth, body: { sbnPath: path } })).json.error).toBe('sbnPath taken');
  });
});

describe('a match for a name in a team', () => {
  it('teammates see it without rallies, "dat ben ik" counts it and teaches the sending phone', async () => {
    const team = aTeam();
    const coach = await newDevice();
    const match = aMatch();
    await send(coach, match, { team, name: 'Gerd Lasso' });
    const path = aPath();
    const me = await newPlayer({ name: 'Gerd-Jan van Gils', sbnPath: path, teamKey: team });
    const stranger = await newPlayer({ teamKey: aTeam() });
    expect((await call('GET', '/api/v1/me/team', { auth: stranger.auth })).json.matches).toHaveLength(0);
    const open = await call('GET', '/api/v1/me/team', { auth: me.auth });
    expect(open.json.matches).toHaveLength(1);
    expect(open.json.matches[0]).toMatchObject({ matchId: match.matchId, status: 'open', name: 'Gerd Lasso', opponent: 'Mark' });
    expect(open.json.matches[0].rallies).toBeUndefined();
    expect((await call('POST', `/api/v1/me/team/${match.matchId}`, { auth: me.auth, body: { name: 'Iemand' } })).status).toBe(404);
    const claimed = await call('POST', `/api/v1/me/team/${match.matchId}`, { auth: me.auth, body: { name: 'Gerd Lasso' } });
    expect(claimed.status).toBe(200);
    expect(claimed.json.status).toBe('accepted');
    expect(claimed.json.rallies).toBeDefined();
    expect((await call('GET', '/api/v1/me/matches', { auth: me.auth })).json.matches).toHaveLength(1);
    // Gone for the rest of the team, and nobody can claim it twice
    const mate = await newPlayer({ teamKey: team });
    expect((await call('GET', '/api/v1/me/team', { auth: mate.auth })).json.matches).toHaveLength(0);
    expect((await call('POST', `/api/v1/me/team/${match.matchId}`, { auth: mate.auth, body: { name: 'Gerd Lasso' } })).status).toBe(404);
    // The coach's phone learns the link; its next match for that name goes straight to the inbox
    const links = await call('GET', '/api/v1/devices/links', { auth: coach });
    expect(links.json.links).toEqual([{ teamKey: team, name: 'gerd lasso', sbnPath: path }]);
    const next = aMatch();
    await send(coach, next, { team, name: 'gerd  LASSO' });
    expect((await call('GET', '/api/v1/me/inbox', { auth: me.auth })).json.matches.map((m) => m.matchId)).toEqual([next.matchId]);
    // Another phone did not learn it
    expect((await call('GET', '/api/v1/devices/links', { auth: await newDevice() })).json.links).toEqual([]);
  });

  it('other waiting matches of that phone for that name come along to the inbox', async () => {
    const team = aTeam();
    const coach = await newDevice();
    const first = aMatch();
    const second = aMatch();
    await send(coach, first, { team, name: 'Piet' });
    await send(coach, second, { team, name: 'Piet' });
    const me = await newPlayer({ sbnPath: aPath(), teamKey: team });
    await call('POST', `/api/v1/me/team/${first.matchId}`, { auth: me.auth, body: { name: 'Piet' } });
    expect((await call('GET', '/api/v1/me/inbox', { auth: me.auth })).json.matches.map((m) => m.matchId)).toEqual([second.matchId]);
  });

  it('a player who blocked the phone does not see its team matches', async () => {
    const team = aTeam();
    const coach = await newDevice();
    const me = await newPlayer({ sbnPath: aPath(), teamKey: team });
    const first = aMatch();
    await send(coach, first, { sbnPath: me.player.sbnPath });
    await call('POST', `/api/v1/me/inbox/${first.matchId}`, { auth: me.auth, body: { use: false, block: true } });
    await send(coach, aMatch(), { team, name: 'Jan' });
    expect((await call('GET', '/api/v1/me/team', { auth: me.auth })).json.matches).toHaveLength(0);
  });
});

describe('a match behind a shared link', () => {
  it('only the link claims it, once', async () => {
    const device = await newDevice();
    const match = aMatch();
    const sent = await send(device, match, { link: true });
    expect(sent.status).toBe(202);
    expect(sent.json.claimToken).toMatch(/^[A-Za-z0-9]{24}$/);
    const me = await newPlayer();
    expect((await call('POST', '/api/v1/me/claim', { auth: me.auth, body: { token: 'nope' } })).status).toBe(404);
    const claimed = await call('POST', '/api/v1/me/claim', { auth: me.auth, body: { token: sent.json.claimToken } });
    expect(claimed.json).toMatchObject({ matchId: match.matchId, status: 'accepted' });
    const other = await newPlayer();
    expect((await call('POST', '/api/v1/me/claim', { auth: other.auth, body: { token: sent.json.claimToken } })).status).toBe(404);
  });
});

describe('the account', () => {
  it('the name can be corrected and the team set', async () => {
    const { auth } = await newPlayer({ name: 'Gerd-Jan van Gls' });
    expect((await call('PATCH', '/api/v1/me', { auth, body: { name: ' ' } })).json.error).toBe('name');
    const team = aTeam();
    const fixed = await call('PATCH', '/api/v1/me', { auth, body: { name: 'Gerd-Jan van Gils', teamKey: team } });
    expect(fixed.json).toMatchObject({ name: 'Gerd-Jan van Gils', teamKey: team });
  });

  it('deleting takes what claims taught phones about the player', async () => {
    const team = aTeam();
    const coach = await newDevice();
    const match = aMatch();
    await send(coach, match, { team, name: 'Kees' });
    const me = await newPlayer({ sbnPath: aPath(), teamKey: team });
    await call('POST', `/api/v1/me/team/${match.matchId}`, { auth: me.auth, body: { name: 'Kees' } });
    expect((await call('GET', '/api/v1/devices/links', { auth: coach })).json.links).toHaveLength(1);
    await call('DELETE', '/api/v1/me', { auth: me.auth });
    expect((await call('GET', '/api/v1/devices/links', { auth: coach })).json.links).toHaveLength(0);
  });

  it('waiting matches older than PENDING_DAYS are wiped too', async () => {
    const device = await newDevice();
    await send(device, aMatch(), { team: aTeam(), name: 'Oud' });
    const realNow = deps.now;
    deps.now = () => realNow() + 91 * 24 * 60 * 60 * 1000;
    try {
      await wipeOldRequests(env);
    } finally {
      deps.now = realNow;
    }
    const left = await env.DB.prepare("SELECT COUNT(*) AS n FROM open_matches WHERE name = 'Oud'").first();
    expect(left.n).toBe(0);
  });
});
