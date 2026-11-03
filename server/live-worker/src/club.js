// Squash Analyzer — live meekijken on Cloudflare Workers: the club screen, a
// page for the TV in the club's canteen with every live team match of that club
// (docs/voorstel-clubscherm.md). The first version is a free trial behind a
// secret link, handed out by hand: /c/<SBN club id>?k=<key>.
//
// The clubs come from the secret CLUB_WALLS (not in this public repo): JSON,
// [{ "id": "123", "name": "All Inn Squash", "key": "…" }], with the id and the
// official name from the SBN club search. A live team match knows only team
// names, so it belongs to a club when a team name starts with that official name ("All Inn Squash 8", "All Inn Squash Dames 1").
// No app change is needed; a team name typed differently by hand is simply not
// on the screen.
//
// One ClubWall object per club keeps a copy of its live team matches: the team
// names, the day and the partijen (first names and the stand, no photos). A team
// match reports after every change and leaves when it is stopped. Nothing else
// is kept: an entry goes `IDLE_MINUTES` after its last update.

import { ViewerSession } from './viewer-session.js';

const MATCH_PREFIX = 'match:';
const CLUB_ID = /^[0-9]{1,10}$/;
const MIN_KEY_LENGTH = 24;

/** The clubs with a screen; a wrong entry (or no secret) is left out, so it never breaks a team match */
export function clubWalls(env) {
  let list;
  try {
    list = JSON.parse(String(env.CLUB_WALLS || '[]'));
  } catch {
    return [];
  }
  if (!Array.isArray(list)) return [];
  return list.filter((wall) => wall && CLUB_ID.test(String(wall.id)) && typeof wall.name === 'string' && wall.name.trim()
    && typeof wall.key === 'string' && wall.key.length >= MIN_KEY_LENGTH)
    .map((wall) => ({ id: String(wall.id), name: wall.name.trim(), key: wall.key }));
}

/** The team name is the club's name, or starts with it as whole words */
function sameClub(team, wall) {
  const name = String(team || '').trim().toLowerCase();
  const club = wall.name.toLowerCase();
  return name === club || name.startsWith(`${club} `);
}

/** The screens a team match belongs on: home's and away's club (once when they are the same) */
export function wallsOfTeam(team, walls) {
  if (!team) return [];
  return walls.filter((wall) => sameClub(team.home, wall) || sameClub(team.away, wall));
}

/** The ClubWall object of a club, in the same jurisdiction as the team matches it shows */
export function wallFor(env, config, clubId) {
  const namespace = config.jurisdiction ? env.CLUB.jurisdiction(config.jurisdiction) : env.CLUB;
  return namespace.get(namespace.idFromName(clubId));
}

export class ClubWall extends ViewerSession {
  /** What the screen gets: the live team matches, in a fixed order so nothing jumps */
  async state() {
    const entries = await this.ctx.storage.list({ prefix: MATCH_PREFIX });
    const matches = Array.from(entries.values());
    matches.sort((a, b) => `${a.team.home}${a.id}`.localeCompare(`${b.team.home}${b.id}`));
    return { matches };
  }

  /** A team match started or changed */
  async setMatch(id, team, partijen, updatedAt) {
    await this.ctx.storage.put(MATCH_PREFIX + id, { id, team: { home: team.home, away: team.away, date: team.date }, partijen, updatedAt });
    await this.scheduleCleanup();
    this.broadcast('state', await this.state());
  }

  /** A team match was stopped, or no longer belongs to this club */
  async removeMatch(id) {
    await this.ctx.storage.delete(MATCH_PREFIX + id);
    this.broadcast('state', await this.state());
  }

  async scheduleCleanup() {
    if (!(await this.ctx.storage.getAlarm())) await this.ctx.storage.setAlarm(Date.now() + this.config.idleMs);
  }

  /** Team matches without an update for `IDLE_MINUTES` leave the screen; the viewers stay connected */
  async alarm() {
    const now = Date.now();
    const entries = await this.ctx.storage.list({ prefix: MATCH_PREFIX });
    const old = [];
    let oldest = null;
    for (const [key, match] of entries) {
      if (now - match.updatedAt >= this.config.idleMs) old.push(key);
      else if (oldest === null || match.updatedAt < oldest) oldest = match.updatedAt;
    }
    if (old.length) {
      await this.ctx.storage.delete(old);
      this.broadcast('state', await this.state());
    }
    if (oldest !== null) await this.ctx.storage.setAlarm(oldest + this.config.idleMs);
  }
}
