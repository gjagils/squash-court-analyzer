// Live team matches to find (6 November 2026, docs/voorstel-teamwedstrijd-vinden-4.0.md):
// teammates find the live team match of their team, the opponent finds it for a
// match in its own programme and gets only the referee key.
import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { deps, teamLiveExpiry, wipeOldRequests } from '../src/index.js';
import { cleanFixture } from '../src/validate.js';
import { call, newPlayer } from './helpers.js';

const LEAGUE = '0A1B2C3D-0000-4000-8000-0000000000AA';
const OTHER_LEAGUE = '0A1B2C3D-0000-4000-8000-0000000000BB';
let counter = 0;
const next = () => counter++;
const aKey = (c) => c.repeat(43);
const liveId = () => `live${String(100000000 + next()).slice(1)}`;

function setUp() {
  const n = next();
  return {
    home: `${LEAGUE}/${500 + n}`,
    away: `${LEAGUE}/${700 + n}`,
    fixture: `/league/${LEAGUE.toLowerCase()}/team-match/${9000 + n}`,
    stored: `/league/${LEAGUE}/team-match/${9000 + n}`,
  };
}

const register = (auth, body) => call('PUT', '/api/v1/me/team/lives', { auth, body });
const lives = (auth, fixtures = []) =>
  call('GET', `/api/v1/me/team/lives?fixtures=${encodeURIComponent(fixtures.join(','))}`, { auth });
const registration = (fixture, extra = {}) => ({
  fixture, date: Date.now() + 3600 * 1000, teamName: 'Squash City 2', liveId: liveId(),
  writeKey: aKey('w'), refereeKey: aKey('r'), ...extra,
});

describe('input', () => {
  it('a fixture is the SBN match link, the league in capitals', () => {
    expect(cleanFixture(`/league/${LEAGUE.toLowerCase()}/team-match/12`)).toBe(`/league/${LEAGUE}/team-match/12`);
    expect(cleanFixture('/league/nope/team-match/12')).toBe('');
    expect(cleanFixture(`https://sbn.toernooi.nl/league/${LEAGUE}/team-match/12`)).toBe('');
    expect(cleanFixture(42)).toBe('');
  });

  it('a registration lasts until the start of the second day after the match', () => {
    expect(teamLiveExpiry(Date.UTC(2026, 10, 6, 19, 0))).toBe(Date.UTC(2026, 10, 8));
  });
});

describe('finding the live team match', () => {
  it('teammates get it with the invitation key; a second registration gets the first back', async () => {
    const { home, fixture, stored } = setUp();
    const kees = await newPlayer({ name: 'Kees', teamKey: home });
    const mate = await newPlayer({ name: 'Gerd-Jan', teamKey: home });
    const first = registration(fixture);
    const made = await register(kees.auth, first);
    expect(made.status).toBe(200);
    expect(made.json).toMatchObject({ fixture: stored, liveId: first.liveId, writeKey: first.writeKey, starterName: 'Kees', own: true });

    const found = await lives(mate.auth);
    expect(found.json.lives).toHaveLength(1);
    expect(found.json.lives[0]).toMatchObject({ liveId: first.liveId, writeKey: first.writeKey, refereeKey: first.refereeKey });

    // Gerd-Jan made his own at the same time: he gets Kees's and joins that one
    const second = await register(mate.auth, registration(fixture));
    expect(second.status).toBe(409);
    expect(second.json.liveId).toBe(first.liveId);
  });

  it('a registration whose session is gone is replaced with `replaces`', async () => {
    const { home, fixture } = setUp();
    const kees = await newPlayer({ teamKey: home });
    const mate = await newPlayer({ teamKey: home });
    const first = registration(fixture);
    await register(kees.auth, first);
    const wrong = await register(mate.auth, registration(fixture, { replaces: 'aaaaaaaaaaaa' }));
    expect(wrong.status).toBe(409);
    const fresh = registration(fixture, { replaces: first.liveId });
    const replaced = await register(mate.auth, fresh);
    expect(replaced.status).toBe(200);
    expect((await lives(kees.auth)).json.lives[0].liveId).toBe(fresh.liveId);
  });

  it('the opponent finds it only for a match it asks for, without the invitation key', async () => {
    const { home, away, fixture } = setUp();
    const kees = await newPlayer({ teamKey: home });
    const lisa = await newPlayer({ teamKey: away });
    const reg = registration(fixture);
    await register(kees.auth, reg);
    expect((await lives(lisa.auth)).json.lives).toEqual([]);
    const found = (await lives(lisa.auth, [fixture])).json.lives;
    expect(found).toHaveLength(1);
    expect(found[0]).toMatchObject({ liveId: reg.liveId, teamName: 'Squash City 2', refereeKey: reg.refereeKey, own: false });
    expect(found[0].writeKey).toBeUndefined();
  });

  it('a team in another league can look but gets no referee key', async () => {
    const { home, fixture } = setUp();
    const kees = await newPlayer({ teamKey: home });
    const stranger = await newPlayer({ teamKey: `${OTHER_LEAGUE}/1` });
    await register(kees.auth, registration(fixture));
    const found = (await lives(stranger.auth, [fixture])).json.lives;
    expect(found).toHaveLength(1);
    expect(found[0].refereeKey).toBeUndefined();
    expect(found[0].writeKey).toBeUndefined();
  });

  it('without a team nothing is found and nothing can be registered', async () => {
    const { fixture } = setUp();
    const lonely = await newPlayer();
    expect((await lives(lonely.auth, [fixture])).json.lives).toEqual([]);
    expect((await register(lonely.auth, registration(fixture))).status).toBe(404);
  });

  it('odd registrations are refused', async () => {
    const { home, fixture } = setUp();
    const kees = await newPlayer({ teamKey: home });
    expect((await register(kees.auth, registration('/league/x/team-match/1'))).json.error).toBe('fixture');
    expect((await register(kees.auth, registration(`/league/${OTHER_LEAGUE}/team-match/1`))).json.error).toBe('league');
    expect((await register(kees.auth, registration(fixture, { liveId: 'NOPE' }))).json.error).toBe('liveId');
    expect((await register(kees.auth, registration(fixture, { writeKey: 'short' }))).json.error).toBe('writeKey');
    expect((await register(kees.auth, registration(fixture, { refereeKey: 'short' }))).json.error).toBe('refereeKey');
    expect((await register(kees.auth, registration(fixture, { teamName: '' }))).json.error).toBe('teamName');
    expect((await register(kees.auth, registration(fixture, { date: Date.now() - 3 * 86400000 }))).json.error).toBe('date');
    // Without a referee key: fine, the opponent then only looks
    expect((await register(kees.auth, registration(fixture, { refereeKey: null }))).status).toBe(200);
    expect((await call('PUT', '/api/v1/me/team/lives', { body: registration(fixture) })).status).toBe(401);
  });

  it('only the one who registered removes it; the account going removes it too', async () => {
    const { home, fixture } = setUp();
    const kees = await newPlayer({ teamKey: home });
    const mate = await newPlayer({ teamKey: home });
    await register(kees.auth, registration(fixture));
    const remove = (auth) => call('DELETE', `/api/v1/me/team/lives?fixture=${encodeURIComponent(fixture)}`, { auth });
    expect((await remove(mate.auth)).status).toBe(204);
    expect((await lives(mate.auth)).json.lives).toHaveLength(1);
    expect((await remove(kees.auth)).status).toBe(204);
    expect((await lives(mate.auth)).json.lives).toHaveLength(0);

    await register(kees.auth, registration(fixture));
    expect((await call('DELETE', '/api/v1/me', { auth: kees.auth })).status).toBe(204);
    expect((await lives(mate.auth)).json.lives).toHaveLength(0);
  });

  it('after the day after the match it is gone, and the daily task wipes it', async () => {
    const { home, fixture } = setUp();
    const kees = await newPlayer({ teamKey: home });
    await register(kees.auth, registration(fixture));
    const real = deps.now;
    try {
      deps.now = () => Date.now() + 3 * 86400000;
      expect((await lives(kees.auth)).json.lives).toHaveLength(0);
      await wipeOldRequests(env);
      const left = await env.DB.prepare('SELECT COUNT(*) AS n FROM team_lives WHERE team_key = ?').bind(home).first();
      expect(left.n).toBe(0);
    } finally {
      deps.now = real;
    }
  });
});
