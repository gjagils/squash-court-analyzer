// One Durable Object per live team match (Competitie): the two team names,
// the day and up to four partijen (E1-E4), each in the shape of a live match.
// Any phone with the team key (the one in the invitation) writes a slot; only
// the owner key, which stays on the phone that started the live page, may
// change the team names or end it. Viewers get everything over
// Server-Sent Events. Like LiveSession: state in storage, an alarm removes it
// `TEAM_IDLE_MINUTES` after the last update of any partij (a day, see
// scheduleIdleAlarm), nothing else is kept.
//
// 4.0 (docs/voorstel-teamwedstrijd-vinden-4.0.md): a session can carry a
// referee key for the opponent, which writes only the partijen they referee
// (`refereeSlots`, set by the owner), and a header with `clubScreen: false`
// stays off the club screens until Live delen is on.
//
// Photos: per slot a thumbnail of the home and the away player
// ("photo:<slot>:1" / ":2"), with flags next to them so a state does not read
// them. Followers (lock screen, storage in ViewerSession) get the compact team
// stand after every change, an alert when a partij is decided and the result
// when all four are (push.js), and the end once. Alerts followers (4.0, the
// players themselves) only get a notification when a partij starts or is
// decided and at the result, never about a partij their phone wrote
// (`slotWriters`: per slot the install ids from X-Squash-Device).

import { ViewerSession, sameKey } from './viewer-session.js';
import { alertForFollower, isAlertFollower, teamAlert, teamAlerts, teamContentState, teamDecided } from './push.js';
import { cleanLang, LANGS } from './validate.js';
import { clubWalls, wallFor, wallsOfTeam } from './club.js';

const SLOT_KEYS = ['1', '2', '3', '4'];
/** Install ids kept per slot as its writers (alerts followers, 4.0) */
const MAX_WRITERS_PER_SLOT = 6;
const photoKey = (slot, index) => `photo:${slot}:${index}`;

export class TeamSession extends ViewerSession {
  /** A team match is removed `TEAM_IDLE_MINUTES` (a day) after the last update, not `IDLE_MINUTES` */
  async scheduleIdleAlarm(now) {
    await this.ctx.storage.setAlarm(now + this.config.teamIdleMs);
  }

  /**
   * Creates the session; false when this id is already in use. `referee`
   * ({ key, slots }) lets the opponent write the partijen they referee.
   */
  async create(key, ownerKey, team, id, lang = 'nl', referee = null) {
    if (await this.ctx.storage.get('key')) return false;
    const now = Date.now();
    // The id is kept in storage too: the limiter is released by it, and the
    // name of a jurisdiction object id must not be what that depends on.
    // `lang` is the starter's language, for the link preview.
    const extra = referee ? { refereeKey: referee.key, refereeSlots: referee.slots } : {};
    await this.ctx.storage.put({ key, ownerKey, team, id, partijen: {}, updatedAt: now, lang, ...extra });
    await this.scheduleIdleAlarm(now);
    await this.reportToClubs(team, {}, now, id);
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

  /** 404 unknown, 401 wrong key, else what this key may do: "owner", "writer" or "referee" */
  async role(given) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (await this.ownerEquals(given)) return 'owner';
    if (await this.keyEquals(given)) return 'writer';
    if (await this.refereeEquals(given)) return 'referee';
    return 401;
  }

  /** The opponent's key (none on a session made without one) */
  async refereeEquals(given) {
    const referee = await this.ctx.storage.get('refereeKey');
    return Boolean(referee) && sameKey(given, referee);
  }

  /** The slots the opponent referees; [] when there are none */
  async refereeSlots() {
    return (await this.ctx.storage.get('refereeSlots')) || [];
  }

  /** What /verify answers: the role, and for the referee key its slots */
  async access(given) {
    const role = await this.role(given);
    if (role !== 'referee') return role;
    return { role, slots: await this.refereeSlots() };
  }

  /** May this key write this slot: the team key any, the referee key only its own */
  async maySlot(given, slot) {
    if (await this.keyEquals(given)) return true;
    return (await this.refereeEquals(given)) && (await this.refereeSlots()).includes(slot);
  }

  /** The owner changes which partijen the opponent referees (none: []): 404, 401, 409 without a referee key, 204 */
  async setRefereeSlots(given, slots) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.ownerEquals(given))) return 401;
    if (!(await this.ctx.storage.get('refereeKey'))) return 409;
    await this.ctx.storage.put({ refereeSlots: slots });
    return 204;
  }

  async touch(extra) {
    const now = Date.now();
    await this.ctx.storage.put({ ...extra, updatedAt: now });
    await this.scheduleIdleAlarm(now);
    this.broadcast('state', await this.state());
    const [team, partijen, id] = await Promise.all([
      this.ctx.storage.get('team'), this.ctx.storage.get('partijen'), this.ctx.storage.get('id'),
    ]);
    await this.reportToClubs(team, partijen || {}, now, id);
  }

  // ---- The club screen (club.js) ---------------------------------------------

  /** The screens of this team match get the new stand. A failing screen never fails the write. */
  async reportToClubs(team, partijen, updatedAt, id) {
    for (const wall of wallsOfTeam(team, clubWalls(this.env))) {
      try {
        await wallFor(this.env, this.config, wall.id).setMatch(id, team, partijen, updatedAt);
      } catch (error) {
        console.error('club screen error', error && error.message);
      }
    }
  }

  /** These screens no longer show this team match (it stopped, or its team names changed) */
  async leaveClubs(team, id, stillOn = []) {
    for (const wall of wallsOfTeam(team, clubWalls(this.env))) {
      if (stillOn.some((other) => other.id === wall.id)) continue;
      try {
        await wallFor(this.env, this.config, wall.id).removeMatch(id);
      } catch (error) {
        console.error('club screen error', error && error.message);
      }
    }
  }

  /** Gone from the club screens first, then everything else (Live stoppen, idle alarm) */
  async end(reason) {
    const [team, id] = await Promise.all([this.ctx.storage.get('team'), this.ctx.storage.get('id')]);
    await this.leaveClubs(team, id);
    return super.end(reason);
  }

  /** 404 unknown, 401 wrong key (the owner key is needed), 204 done */
  async setTeam(given, team) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.ownerEquals(given))) return 401;
    const [before, id, stored] = await Promise.all([
      this.ctx.storage.get('team'), this.ctx.storage.get('id'), this.ctx.storage.get('partijen'),
    ]);
    const partijen = stored || {};
    // An app without the SBN team pages (before 3.2 build 4) keeps those of the page while the teams stay the same
    if (before && before.home === team.home && before.away === team.away) {
      if (!team.homeTeam && before.homeTeam) team.homeTeam = before.homeTeam;
      if (!team.awayTeam && before.awayTeam) team.awayTeam = before.awayTeam;
    }
    await this.leaveClubs(before, id, wallsOfTeam(team, clubWalls(this.env)));
    await this.touch({ team });
    await this.pushUpdate(team, partijen, partijen);
    return 204;
  }

  /**
   * One slot (1-4) gets this partij, or is cleared (`{ empty: true }`, its
   * photos too). `device` (header X-Squash-Device, 4.0) is the install id of
   * the phone that wrote it: that phone gets no alert about this partij.
   */
  async setPartij(given, slot, partij, device = null) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.maySlot(given, slot))) return 401;
    const [stored, team, storedWriters] = await Promise.all([
      this.ctx.storage.get('partijen'), this.ctx.storage.get('team'), this.ctx.storage.get('slotWriters'),
    ]);
    const previous = stored || {};
    const partijen = { ...previous };
    const writers = { ...(storedWriters || {}) };
    if (partij.empty) {
      delete partijen[slot];
      delete writers[slot];
      await this.clearPhotos(slot);
    } else {
      partijen[slot] = partij;
      if (device) {
        // A few phones per slot at most (a scorer, a correction by hand); the newest kept
        const list = (writers[slot] || []).filter((other) => other !== device);
        writers[slot] = [...list, device].slice(-MAX_WRITERS_PER_SLOT);
      }
    }
    await this.touch({ partijen, slotWriters: writers });
    await this.pushUpdate(team, partijen, previous);
    return 204;
  }

  // ---- Photos -------------------------------------------------------------------

  /** The home and away thumbnail of a slot (Uint8Array or null each), team or owner key, or the referee key on its slots: 404, 401, 204 */
  async setPhotos(given, slot, photo1, photo2) {
    const role = await this.role(given);
    if (role === 404 || role === 401) return role;
    if (role === 'referee' && !(await this.refereeSlots()).includes(slot)) return 401;
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
    const all = await this.followers();
    if (all.length === 0) return;
    await this.pushAlertsUpdate(all.filter(isAlertFollower), team, partijen, previous);
    const followers = all.filter((follower) => !isAlertFollower(follower));
    if (followers.length === 0) return;
    const done = teamDecided(partijen);
    const event = await this.followerEvent(done);
    if (!event) return;
    const content = { kind: 'team', state: teamContentState(team, partijen), finished: done };
    // The alert in every language; each follower gets its own
    const alert = Object.fromEntries(LANGS.map((lang) => [lang, teamAlert(previous, team, partijen, lang)]));
    this.schedulePush(await this.pushJob(event, followers, content, alert.nl ? alert : null));
  }

  /**
   * 4.0 (T6): the players of the team match follow it with plain
   * notifications: a partij started, a partij decided, the result; never per
   * rally or game. Each gets the first that is not about a partij its own
   * phone wrote, in its language; no push when there is none.
   */
  async pushAlertsUpdate(followers, team, partijen, previous) {
    if (followers.length === 0) return;
    const writers = (await this.ctx.storage.get('slotWriters')) || {};
    const alerts = Object.fromEntries(LANGS.map((lang) => [lang, teamAlerts(previous, team, partijen, lang)]));
    if (alerts.nl.length === 0) return;
    const items = [];
    for (const follower of followers) {
      const alert = alertForFollower(follower, alerts[cleanLang(follower.lang)] || alerts.nl, writers);
      if (alert) items.push({ follower, alert });
    }
    if (items.length === 0) return;
    const [server, id] = await Promise.all([this.ctx.storage.get('pushServer'), this.ctx.storage.get('id')]);
    this.schedulePush({ mode: 'alerts', id: this.id || id || '', server: server || '', items });
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
