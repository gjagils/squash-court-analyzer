// One Durable Object per live match. It keeps the write key, the state, the
// two photos and the open viewers; the state lives in the object's storage,
// so an evicted object (nobody watching for a while) comes back as it was.
// An alarm removes the session once nobody updated it for `IDLE_MINUTES`.
// Keys, viewers (SSE), alarm and the end are in ViewerSession.
//
// Followers (Live score op het vergrendelscherm): phones that registered a push
// token. Each is its own storage entry ("follower:" + SHA-256 of platform and
// token), wiped with the session. After every update they get a push (push.js),
// and the end of the match once: on a finished stand, or else when the session
// ends (Live stoppen, idle alarm).

import { ViewerSession, encoder } from './viewer-session.js';
import { pushToFollowers } from './push.js';

const FOLLOWER_PREFIX = 'follower:';

async function followerKey(follower) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(`${follower.platform}\n${follower.token}`));
  return FOLLOWER_PREFIX + Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

export class LiveSession extends ViewerSession {
  /** Creates the session; false when this id is already in use */
  async create(key, snapshot, id) {
    if (await this.ctx.storage.get('key')) return false;
    const now = Date.now();
    // The id is kept in storage too: the limiter is released by it, and the
    // name of a jurisdiction object id must not be what that depends on
    await this.ctx.storage.put({ key, snapshot, id, updatedAt: now, photoVersion: 0 });
    await this.scheduleIdleAlarm(now);
    return true;
  }

  /** What viewers get with every state: whether there is a photo per player, and its version (for the image URL) */
  async state() {
    const [key, snapshot, updatedAt, photoVersion] = await Promise.all([
      this.ctx.storage.get('key'), this.ctx.storage.get('snapshot'), this.ctx.storage.get('updatedAt'),
      this.ctx.storage.get('photoVersion'),
    ]);
    if (!key) return null;
    return { snapshot, updatedAt, photos: await this.photoFlags(), photoVersion: photoVersion || 0 };
  }

  /**
   * Whether each player has a photo. Kept as two flags next to the photos, so a
   * state (sent with every rally) does not read two 24 KB photos from storage.
   * A session from before the flags reads the photos once and stores the flags.
   */
  async photoFlags() {
    const flags = await this.ctx.storage.get('photoFlags');
    if (Array.isArray(flags)) return flags;
    const [photo1, photo2] = await Promise.all([this.ctx.storage.get('photo1'), this.ctx.storage.get('photo2')]);
    const computed = [Boolean(photo1), Boolean(photo2)];
    await this.ctx.storage.put('photoFlags', computed);
    return computed;
  }

  /** 404 unknown, 401 wrong key, 204 done */
  async update(given, snapshot) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    const now = Date.now();
    await this.ctx.storage.put({ snapshot, updatedAt: now });
    await this.scheduleIdleAlarm(now);
    this.broadcast('state', await this.state());
    await this.pushUpdate(snapshot);
    return 204;
  }

  /** The players' thumbnails (Uint8Array or null each), once after creating */
  async setPhotos(given, photo1, photo2) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    const version = ((await this.ctx.storage.get('photoVersion')) || 0) + 1;
    await this.ctx.storage.put({ photoVersion: version });
    if (photo1) await this.ctx.storage.put('photo1', photo1); else await this.ctx.storage.delete('photo1');
    if (photo2) await this.ctx.storage.put('photo2', photo2); else await this.ctx.storage.delete('photo2');
    await this.ctx.storage.put('photoFlags', [Boolean(photo1), Boolean(photo2)]);
    this.broadcast('state', await this.state());
    return 204;
  }

  /** A player's thumbnail (1 or 2), or null */
  async photo(index) {
    if (!(await this.ctx.storage.get('key'))) return null;
    const bytes = await this.ctx.storage.get(index === 1 ? 'photo1' : 'photo2');
    return bytes || null;
  }

  /** Match over (Live stoppen): 404 unknown, 401 wrong key, 204 gone */
  async remove(given) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    await this.end('finished');
    return 204;
  }

  // ---- Followers (lock screen pushes) ----------------------------------------

  /** Registers a push token: 404 unknown, 429 full, 201 done (also when it was there already) */
  async addFollower(follower, server) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    const key = await followerKey(follower);
    if (!(await this.ctx.storage.get(key))) {
      const count = (await this.ctx.storage.list({ prefix: FOLLOWER_PREFIX })).size;
      if (count >= this.config.maxFollowersPerSession) return 429;
    }
    // The public address of this server goes into the Android pushes
    await this.ctx.storage.put({ [key]: follower, pushServer: server });
    return 201;
  }

  /** Forgets a push token: 404 unknown session, 204 done (also when it was not there) */
  async removeFollower(follower) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    await this.ctx.storage.delete(await followerKey(follower));
    return 204;
  }

  /** The registered followers ({ platform, token, sandbox }) */
  async followers() {
    return Array.from((await this.ctx.storage.list({ prefix: FOLLOWER_PREFIX })).values());
  }

  /** After an update: "update" to the followers, or "end" once when the match is finished */
  async pushUpdate(snapshot) {
    const followers = await this.followers();
    if (followers.length === 0) return;
    let event = 'update';
    if (snapshot.status === 'finished') {
      if (await this.ctx.storage.get('endPushed')) return;
      event = 'end';
      await this.ctx.storage.put('endPushed', true);
    } else {
      // Back from finished (a corrected last rally): updates again
      await this.ctx.storage.delete('endPushed');
    }
    const id = this.id || (await this.ctx.storage.get('id')) || '';
    this.schedulePush({ id, server: (await this.ctx.storage.get('pushServer')) || '', snapshot, event, followers });
  }

  /**
   * Sends in the background (the PUT does not wait), one fan-out after the
   * other so the phones get the stands in order. Dead tokens are forgotten.
   */
  schedulePush(job) {
    const run = async () => {
      const dead = await pushToFollowers(this.env, job);
      if (dead.length === 0 || !(await this.ctx.storage.get('key'))) return;
      await this.ctx.storage.delete(await Promise.all(dead.map(followerKey)));
    };
    this.pushChain = (this.pushChain || Promise.resolve()).then(run).catch((error) => {
      console.error('push fan-out failed', error && error.message);
    });
    if (this.ctx.waitUntil) this.ctx.waitUntil(this.pushChain);
    return this.pushChain;
  }

  /** For tests: resolves when the pushes queued so far are done */
  async pushesDone() {
    await this.pushChain;
  }

  /** The end (Live stoppen, idle): the followers hear it once, with the last stand */
  async end(reason) {
    const [followers, snapshot, endPushed, server, storedId] = await Promise.all([
      this.followers(), this.ctx.storage.get('snapshot'), this.ctx.storage.get('endPushed'),
      this.ctx.storage.get('pushServer'), this.ctx.storage.get('id'),
    ]);
    await super.end(reason);
    if (followers.length > 0 && snapshot && !endPushed) {
      this.schedulePush({ id: this.id || storedId || '', server: server || '', snapshot, event: 'end', followers });
    }
  }

  /** The last stand goes to the viewers with the end */
  async endedPayload(reason) {
    return { reason, snapshot: await this.ctx.storage.get('snapshot') };
  }
}
