// One Durable Object per live team match (Competitie): the two team names,
// the day and up to four partijen (E1-E4), each in the shape of a live match.
// Any phone with the team key (the one in the invitation) writes a slot; only
// the owner key, which stays on the phone that started the live page, may
// change the team names or end it. Viewers get everything over
// Server-Sent Events. Like LiveSession: state in storage, an alarm removes it
// `IDLE_MINUTES` after the last update of any partij (so two hours after the
// last partij), nothing else is kept.

import { ViewerSession, sameKey } from './viewer-session.js';

export class TeamSession extends ViewerSession {
  /** Creates the session; false when this id is already in use */
  async create(key, ownerKey, team, id) {
    if (await this.ctx.storage.get('key')) return false;
    const now = Date.now();
    // The id is kept in storage too: the limiter is released by it, and the
    // name of a jurisdiction object id must not be what that depends on
    await this.ctx.storage.put({ key, ownerKey, team, id, partijen: {}, updatedAt: now });
    await this.scheduleIdleAlarm(now);
    return true;
  }

  /** What viewers get: the team match, the partijen by slot and the time of the last update */
  async state() {
    const [key, team, partijen, updatedAt] = await Promise.all([
      this.ctx.storage.get('key'), this.ctx.storage.get('team'), this.ctx.storage.get('partijen'),
      this.ctx.storage.get('updatedAt'),
    ]);
    if (!key) return null;
    return { team, partijen: partijen || {}, updatedAt };
  }

  /** The owner key; a session from before owner keys has none and takes the team key */
  async ownerEquals(given) {
    const owner = await this.ctx.storage.get('ownerKey');
    return sameKey(given, owner || (await this.ctx.storage.get('key')));
  }

  /** 404 unknown, 401 wrong key, else what this key may do: "owner" or "writer" */
  async role(given) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (await this.ownerEquals(given)) return 'owner';
    if (await this.keyEquals(given)) return 'writer';
    return 401;
  }

  async touch(extra) {
    const now = Date.now();
    await this.ctx.storage.put({ ...extra, updatedAt: now });
    await this.scheduleIdleAlarm(now);
    this.broadcast('state', await this.state());
  }

  /** 404 unknown, 401 wrong key (the owner key is needed), 204 done */
  async setTeam(given, team) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.ownerEquals(given))) return 401;
    await this.touch({ team });
    return 204;
  }

  /** One slot (1-4) gets this partij, or is cleared (`{ empty: true }`) */
  async setPartij(given, slot, partij) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    const partijen = (await this.ctx.storage.get('partijen')) || {};
    if (partij.empty) delete partijen[slot]; else partijen[slot] = partij;
    await this.touch({ partijen });
    return 204;
  }

  /** The team match is over for good (Live stoppen, owner key): everything goes at once */
  async remove(given) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.ownerEquals(given))) return 401;
    await this.end('finished');
    return 204;
  }

  /** The team match as it was goes to the viewers with the end */
  async endedPayload(reason) {
    return { reason, ...((await this.state()) || {}) };
  }

  /** The limiter knows team matches as `t:<id>`, apart from single matches */
  limiterKey(id) {
    return `t:${id}`;
  }
}
