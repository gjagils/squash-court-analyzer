// One Durable Object per live team match (Competitie): the two team names,
// the day and up to four partijen (E1-E4), each in the shape of a live match.
// Any phone with the team key (the one in the invitation) writes a slot; only
// the owner key, which stays on the phone that started the live page, may
// change the team names or end it. Viewers get everything over
// Server-Sent Events. Like LiveSession: state in storage, an alarm removes it
// `IDLE_MINUTES` after the last update of any partij (so two hours after the
// last partij), nothing else is kept.
//
// Photos: per slot a thumbnail of the home and the away player
// ("photo:<slot>:1" / ":2"), with flags next to them so a state does not read
// them. Followers (lock screen, storage in ViewerSession) get the compact team
// stand after every change, an alert when a partij is decided and the result
// when all four are (push.js), and the end once.

import { ViewerSession, sameKey } from './viewer-session.js';
import { teamAlert, teamContentState, teamDecided } from './push.js';
import { LANGS } from './validate.js';

const SLOT_KEYS = ['1', '2', '3', '4'];
const photoKey = (slot, index) => `photo:${slot}:${index}`;

export class TeamSession extends ViewerSession {
  /** Creates the session; false when this id is already in use */
  async create(key, ownerKey, team, id, lang = 'nl') {
    if (await this.ctx.storage.get('key')) return false;
    const now = Date.now();
    // The id is kept in storage too: the limiter is released by it, and the
    // name of a jurisdiction object id must not be what that depends on.
    // `lang` is the starter's language, for the link preview.
    await this.ctx.storage.put({ key, ownerKey, team, id, partijen: {}, updatedAt: now, lang });
    await this.scheduleIdleAlarm(now);
    return true;
  }

  /**
   * What viewers get: the team match, the partijen by slot, the time of the last
   * update, and per slot (all four) whether home and away have a photo, with the
   * photo version for the image URL
   */
  async state() {
    const [key, team, partijen, updatedAt, photoFlags, photoVersion] = await Promise.all([
      this.ctx.storage.get('key'), this.ctx.storage.get('team'), this.ctx.storage.get('partijen'),
      this.ctx.storage.get('updatedAt'), this.ctx.storage.get('photoFlags'), this.ctx.storage.get('photoVersion'),
    ]);
    if (!key) return null;
    const photos = {};
    for (const slot of SLOT_KEYS) photos[slot] = (photoFlags && photoFlags[slot]) || [false, false];
    return { team, partijen: partijen || {}, updatedAt, photos, photoVersion: photoVersion || 0 };
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
    const partijen = (await this.ctx.storage.get('partijen')) || {};
    await this.touch({ team });
    await this.pushUpdate(team, partijen, partijen);
    return 204;
  }

  /** One slot (1-4) gets this partij, or is cleared (`{ empty: true }`, its photos too) */
  async setPartij(given, slot, partij) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    const [stored, team] = await Promise.all([this.ctx.storage.get('partijen'), this.ctx.storage.get('team')]);
    const previous = stored || {};
    const partijen = { ...previous };
    if (partij.empty) {
      delete partijen[slot];
      await this.clearPhotos(slot);
    } else {
      partijen[slot] = partij;
    }
    await this.touch({ partijen });
    await this.pushUpdate(team, partijen, previous);
    return 204;
  }

  // ---- Photos -------------------------------------------------------------------

  /** The home and away thumbnail of a slot (Uint8Array or null each), team or owner key: 404, 401, 204 */
  async setPhotos(given, slot, photo1, photo2) {
    const role = await this.role(given);
    if (role === 404 || role === 401) return role;
    const flags = (await this.ctx.storage.get('photoFlags')) || {};
    const version = ((await this.ctx.storage.get('photoVersion')) || 0) + 1;
    if (photo1) await this.ctx.storage.put(photoKey(slot, 1), photo1); else await this.ctx.storage.delete(photoKey(slot, 1));
    if (photo2) await this.ctx.storage.put(photoKey(slot, 2), photo2); else await this.ctx.storage.delete(photoKey(slot, 2));
    flags[slot] = [Boolean(photo1), Boolean(photo2)];
    await this.ctx.storage.put({ photoFlags: flags, photoVersion: version });
    this.broadcast('state', await this.state());
    return 204;
  }

  /** A cleared slot loses its photos (the version goes up when there were any) */
  async clearPhotos(slot) {
    const flags = (await this.ctx.storage.get('photoFlags')) || {};
    if (!flags[slot] || (!flags[slot][0] && !flags[slot][1])) return;
    await this.ctx.storage.delete([photoKey(slot, 1), photoKey(slot, 2)]);
    delete flags[slot];
    const version = ((await this.ctx.storage.get('photoVersion')) || 0) + 1;
    await this.ctx.storage.put({ photoFlags: flags, photoVersion: version });
  }

  /** A thumbnail of slot 1-4, home (1) or away (2), or null */
  async photo(slot, index) {
    if (!(await this.ctx.storage.get('key'))) return null;
    return (await this.ctx.storage.get(photoKey(slot, index))) || null;
  }

  // ---- Followers (lock screen pushes) ----------------------------------------

  /**
   * After a change: "update" to the followers, or "end" once when all four
   * partijen are decided (a correction back to undecided makes updates resume).
   * The alert: a partij decided now, or the result.
   */
  async pushUpdate(team, partijen, previous) {
    const followers = await this.followers();
    if (followers.length === 0) return;
    const done = teamDecided(partijen);
    const event = await this.followerEvent(done);
    if (!event) return;
    const content = { kind: 'team', state: teamContentState(team, partijen), finished: done };
    // The alert in every language; each follower gets its own
    const alert = Object.fromEntries(LANGS.map((lang) => [lang, teamAlert(previous, team, partijen, lang)]));
    this.schedulePush(await this.pushJob(event, followers, content, alert.nl ? alert : null));
  }

  /** The stand for the end the followers get when the session goes (Live stoppen, idle): gone in a minute */
  async pushContent() {
    const [team, partijen] = await Promise.all([this.ctx.storage.get('team'), this.ctx.storage.get('partijen')]);
    return team ? { kind: 'team', state: teamContentState(team, partijen || {}), finished: false } : null;
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
