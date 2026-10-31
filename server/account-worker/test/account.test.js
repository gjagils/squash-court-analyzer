// The player account API against the Worker (SELF) with a local D1.
import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { deps, wipeOldRequests } from '../src/index.js';
import { aMatch, call, idToken, newDevice, newPlayer, signedIn } from './helpers.js';

describe('health and routing', () => {
  it('answers the health check and 404 for the rest', async () => {
    expect((await call('GET', '/health')).json).toEqual({ ok: true });
    expect((await call('GET', '/nope')).status).toBe(404);
  });
});

describe('signing in', () => {
  it('refuses calls without a valid Firebase token', async () => {
    expect((await call('GET', '/api/v1/me')).status).toBe(401);
    expect((await call('GET', '/api/v1/me', { auth: 'Bearer nonsense' })).status).toBe(401);
  });

  it('refuses tokens for another project, expired, from the future, unknown key or without uid', async () => {
    const now = Math.floor(Date.now() / 1000);
    const bad = [
      await idToken('u1', { aud: 'other-project' }),
      await idToken('u1', { iss: 'https://securetoken.google.com/other-project' }),
      await idToken('u1', { exp: now - 3600 }),
      await idToken('u1', { iat: now + 3600 }),
      await idToken('', {}),
      await idToken('u1', {}, { kid: 'unknown' }),
      await idToken('u1', {}, { alg: 'HS256' }),
    ];
    for (const token of bad) {
      expect((await call('GET', '/api/v1/me', { auth: `Bearer ${token}` })).status).toBe(401);
    }
    const tampered = (await idToken('u1')).replace(/\.[^.]+\./, `.${btoa(JSON.stringify({ sub: 'someone-else' }))}.`);
    expect((await call('GET', '/api/v1/me', { auth: `Bearer ${tampered}` })).status).toBe(401);
  });

  it('a valid token without an account gets 404 until the account is made', async () => {
    const auth = await signedIn('fresh-user');
    expect((await call('GET', '/api/v1/me', { auth })).status).toBe(404);
    expect((await call('GET', '/api/v1/me/inbox', { auth })).status).toBe(404);
  });
});

describe('making an account', () => {
  it('needs consent, a name and a birth year of 16 or older', async () => {
    const auth = await signedIn('maker');
    const year = new Date().getUTCFullYear();
    expect((await call('POST', '/api/v1/me', { auth, body: { name: 'A', birthYear: 1990 } })).json.error).toBe('consent');
    expect((await call('POST', '/api/v1/me', { auth, body: { name: ' ', birthYear: 1990, consent: true } })).json.error).toBe('name');
    expect((await call('POST', '/api/v1/me', { auth, body: { name: 'A', birthYear: '1990', consent: true } })).json.error).toBe('birthYear');
    expect((await call('POST', '/api/v1/me', { auth, body: { name: 'A', birthYear: year - 15, consent: true } })).status).toBe(403);
    const made = await call('POST', '/api/v1/me', { auth, body: { name: 'Anna', birthYear: year - 16, consent: true } });
    expect(made.status).toBe(201);
    expect(made.json.name).toBe('Anna');
    expect(made.json.code).toMatch(/^[A-Z2-9]{10}$/);
    // Asking again returns the same account
    const again = await call('POST', '/api/v1/me', { auth, body: { name: 'Other', birthYear: 1990, consent: true } });
    expect(again.json.playerId).toBe(made.json.playerId);
  });

  it('an SBN player path can belong to one account only', async () => {
    await newPlayer({ sbnPath: '/player/sbn-1' });
    const auth = await signedIn('second-claimer');
    const res = await call('POST', '/api/v1/me', { auth, body: { name: 'X', birthYear: 1990, consent: true, sbnPath: '/player/sbn-1' } });
    expect(res.status).toBe(409);
  });
});

describe('sending and answering matches', () => {
  it('a device key is needed to send, and only a hash of it is stored', async () => {
    expect((await call('POST', '/api/v1/submissions', { body: aMatch() })).status).toBe(401);
    expect((await call('POST', '/api/v1/submissions', { auth: 'Device x.y', body: aMatch() })).status).toBe(401);
    const res = await call('POST', '/api/v1/devices', { body: {} });
    const row = await env.DB.prepare('SELECT key_hash FROM devices WHERE id = ?').bind(res.json.deviceId).first();
    expect(row.key_hash).not.toBe(res.json.deviceKey);
    expect(row.key_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('a match sent with the player code waits in the inbox; use moves it to the matches', async () => {
    const { auth, player } = await newPlayer();
    const device = await newDevice();
    const match = aMatch();
    const sent = await call('POST', '/api/v1/submissions', { auth: device, body: { ...match, to: { code: player.code }, senderName: 'Coach Kees' } });
    expect(sent.status).toBe(202);
    // A retry with the same match id does not make a second request
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...match, to: { code: player.code } } });
    const inbox = await call('GET', '/api/v1/me/inbox', { auth });
    expect(inbox.json.matches).toHaveLength(1);
    expect(inbox.json.matches[0]).toMatchObject({ matchId: match.matchId, senderName: 'Coach Kees', opponent: 'Mark' });
    expect(inbox.json.matches[0].rallies).toBeUndefined();

    expect((await call('GET', '/api/v1/me/matches', { auth })).json.matches).toHaveLength(0);
    const used = await call('POST', `/api/v1/me/inbox/${match.matchId}`, { auth, body: { use: true } });
    expect(used.status).toBe(200);
    expect(used.json.rallies).toEqual(match.rallies);
    expect((await call('GET', '/api/v1/me/inbox', { auth })).json.matches).toHaveLength(0);
    const matches = (await call('GET', '/api/v1/me/matches', { auth })).json.matches;
    expect(matches.map((m) => m.matchId)).toEqual([match.matchId]);
    expect(matches[0].summary).toEqual(match.summary);
  });

  it('a match for an SBN player path reaches that player', async () => {
    const { auth } = await newPlayer({ sbnPath: '/player/sbn-2' });
    const device = await newDevice();
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...aMatch({ teamKey: 'team-1:E2' }), to: { sbnPath: '/player/sbn-2' } } });
    const inbox = await call('GET', '/api/v1/me/inbox', { auth });
    expect(inbox.json.matches).toHaveLength(1);
    expect(inbox.json.matches[0].teamKey).toBe('team-1:E2');
  });

  it('the sender gets the same answer for an unknown player: nobody learns who has an account', async () => {
    const device = await newDevice();
    const res = await call('POST', '/api/v1/submissions', { auth: device, body: { ...aMatch(), to: { code: 'NOBODYHERE' } } });
    expect(res.status).toBe(202);
  });

  it('not using a match wipes it, and blocking keeps that phone out', async () => {
    const { auth, player } = await newPlayer();
    const device = await newDevice();
    const first = aMatch();
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...first, to: { code: player.code } } });
    expect((await call('POST', `/api/v1/me/inbox/${first.matchId}`, { auth, body: { use: false, block: true } })).status).toBe(204);
    const row = await env.DB.prepare('SELECT 1 FROM matches WHERE id = ?').bind(first.matchId).first();
    expect(row).toBeNull();
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...aMatch(), to: { code: player.code } } });
    expect((await call('GET', '/api/v1/me/inbox', { auth })).json.matches).toHaveLength(0);
    // Another phone still gets through
    await call('POST', '/api/v1/submissions', { auth: await newDevice(), body: { ...aMatch(), to: { code: player.code } } });
    expect((await call('GET', '/api/v1/me/inbox', { auth })).json.matches).toHaveLength(1);
  });

  it('a player can only answer their own requests', async () => {
    const owner = await newPlayer();
    const other = await newPlayer();
    const match = aMatch();
    await call('POST', '/api/v1/submissions', { auth: await newDevice(), body: { ...match, to: { code: owner.player.code } } });
    expect((await call('POST', `/api/v1/me/inbox/${match.matchId}`, { auth: other.auth, body: { use: true } })).status).toBe(404);
    expect((await call('GET', '/api/v1/me/inbox', { auth: other.auth })).json.matches).toHaveLength(0);
  });

  it('rejects malformed and oversized matches', async () => {
    const { player } = await newPlayer();
    const device = await newDevice();
    const to = { code: player.code };
    expect((await call('POST', '/api/v1/submissions', { auth: device, body: { ...aMatch({ matchId: 'x' }), to } })).json.error).toBe('matchId');
    expect((await call('POST', '/api/v1/submissions', { auth: device, body: { ...aMatch({ playedAt: 'gisteren' }), to } })).json.error).toBe('playedAt');
    const huge = aMatch({ rallies: 'x'.repeat(40 * 1024) });
    expect((await call('POST', '/api/v1/submissions', { auth: device, body: { ...huge, to } })).json.error).toBe('size');
  });
});

describe('limits', () => {
  it('one phone may send SUBMISSIONS_PER_DAY matches a day', async () => {
    const { player } = await newPlayer();
    const device = await newDevice();
    const statuses = [];
    for (let i = 0; i < 4; i++) {
      statuses.push((await call('POST', '/api/v1/submissions', { auth: device, body: { ...aMatch(), to: { code: player.code } } })).status);
    }
    expect(statuses).toEqual([202, 202, 202, 429]);
  });

  it('one address may make DEVICES_PER_HOUR device keys an hour', async () => {
    const ip = '10.9.9.9';
    const statuses = [];
    for (let i = 0; i < 3; i++) statuses.push((await call('POST', '/api/v1/devices', { body: {}, ip })).status);
    expect(statuses).toEqual([201, 201, 429]);
  });
});

describe('own matches and awards', () => {
  it('own matches count at once and replace a pending copy of the same match', async () => {
    const { auth, player } = await newPlayer();
    const match = aMatch();
    await call('POST', '/api/v1/submissions', { auth: await newDevice(), body: { ...match, to: { code: player.code } } });
    const own = await call('POST', '/api/v1/me/matches', { auth, body: { matches: [match, aMatch()] } });
    expect(own.json.stored).toBe(2);
    expect((await call('GET', '/api/v1/me/inbox', { auth })).json.matches).toHaveLength(0);
    expect((await call('GET', '/api/v1/me/matches', { auth })).json.matches).toHaveLength(2);
    expect((await call('POST', '/api/v1/me/matches', { auth, body: { matches: [] } })).status).toBe(400);
  });

  it('merges awards and a deleted award stays deleted', async () => {
    const { auth } = await newPlayer();
    let res = await call('PUT', '/api/v1/me/awards', { auth, body: { awards: [{ id: 'a1', value: { b: 'iron-man' } }, { id: 'a2', value: { b: 'rock-solid' } }] } });
    expect(res.json.awards).toHaveLength(2);
    // Phone A deletes a1
    await call('PUT', '/api/v1/me/awards', { auth, body: { awards: [{ id: 'a1', value: { b: 'iron-man' }, deletedAt: 1000 }] } });
    // Phone B, which still has a1, merges it again: it stays deleted
    res = await call('PUT', '/api/v1/me/awards', { auth, body: { awards: [{ id: 'a1', value: { b: 'iron-man' } }] } });
    const a1 = res.json.awards.find((a) => a.id === 'a1');
    expect(a1.deletedAt).toBe(1000);
    expect(res.json.awards.find((a) => a.id === 'a2').deletedAt).toBeNull();
  });
});

describe('deleting the account and wiping old requests', () => {
  it('deleting removes the account, player, matches, awards and blocks', async () => {
    const { auth, player } = await newPlayer();
    const device = await newDevice();
    const match = aMatch();
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...match, to: { code: player.code } } });
    await call('POST', `/api/v1/me/inbox/${match.matchId}`, { auth, body: { use: false, block: true } });
    await call('POST', '/api/v1/me/matches', { auth, body: { matches: [aMatch()] } });
    await call('PUT', '/api/v1/me/awards', { auth, body: { awards: [{ id: 'z', value: 1 }] } });
    expect((await call('DELETE', '/api/v1/me', { auth })).status).toBe(204);
    expect((await call('GET', '/api/v1/me', { auth })).status).toBe(404);
    for (const table of ['matches', 'awards', 'blocks']) {
      const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE player_id = ?`).bind(player.playerId).first();
      expect(row.n).toBe(0);
    }
    expect(await env.DB.prepare('SELECT 1 FROM players WHERE id = ?').bind(player.playerId).first()).toBeNull();
  });

  it('requests older than PENDING_DAYS are wiped, accepted matches stay', async () => {
    const { auth, player } = await newPlayer();
    const old = aMatch();
    const accepted = aMatch();
    const device = await newDevice();
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...old, to: { code: player.code } } });
    await call('POST', '/api/v1/submissions', { auth: device, body: { ...accepted, to: { code: player.code } } });
    await call('POST', `/api/v1/me/inbox/${accepted.matchId}`, { auth, body: { use: true } });
    const realNow = deps.now;
    deps.now = () => realNow() + 91 * 24 * 60 * 60 * 1000;
    try {
      expect(await wipeOldRequests(env)).toBeGreaterThanOrEqual(1);
    } finally {
      deps.now = realNow;
    }
    expect((await call('GET', '/api/v1/me/inbox', { auth })).json.matches).toHaveLength(0);
    expect((await call('GET', '/api/v1/me/matches', { auth })).json.matches).toHaveLength(1);
  });
});
