// One Durable Object per live match. It keeps the write key, the state, the
// two photos and the open viewers; the state lives in the object's storage,
// so an evicted object (nobody watching for a while) comes back as it was.
// An alarm removes the session once nobody updated it for `IDLE_MINUTES`.
// Keys, viewers (SSE), alarm and the end are in ViewerSession.

import { ViewerSession } from './viewer-session.js';

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

  /** The last stand goes to the viewers with the end */
  async endedPayload(reason) {
    return { reason, snapshot: await this.ctx.storage.get('snapshot') };
  }
}
