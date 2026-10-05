// One Durable Object per live match. It keeps the write key, the state, the
// two photos and the open viewers; the state lives in the object's storage,
// so an evicted object (nobody watching for a while) comes back as it was.
// An alarm removes the session once nobody updated it for `IDLE_MINUTES`.

import { DurableObject } from 'cloudflare:workers';
import { readConfig } from './config.js';

const encoder = new TextEncoder();

export class LiveSession extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.config = readConfig(env);
    /** Open SSE streams: stream controller -> ping timer */
    this.viewers = new Map();
  }

  get id() {
    return this.ctx.id.name || '';
  }

  /** Creates the session; false when this id is already in use */
  async create(key, snapshot) {
    if (await this.ctx.storage.get('key')) return false;
    const now = Date.now();
    await this.ctx.storage.put({ key, snapshot, updatedAt: now, photoVersion: 0 });
    await this.ctx.storage.setAlarm(now + this.config.idleMs);
    return true;
  }

  /** What viewers get with every state: whether there is a photo per player, and its version (for the image URL) */
  async state() {
    const [key, snapshot, updatedAt, photoVersion, photo1, photo2] = await Promise.all([
      this.ctx.storage.get('key'), this.ctx.storage.get('snapshot'), this.ctx.storage.get('updatedAt'),
      this.ctx.storage.get('photoVersion'), this.ctx.storage.get('photo1'), this.ctx.storage.get('photo2'),
    ]);
    if (!key) return null;
    return { snapshot, updatedAt, photos: [Boolean(photo1), Boolean(photo2)], photoVersion: photoVersion || 0 };
  }

  async keyEquals(given) {
    const expected = await this.ctx.storage.get('key');
    const a = encoder.encode(given || '');
    const b = encoder.encode(expected || '');
    if (!expected || a.length !== b.length) return false;
    return crypto.subtle.timingSafeEqual(a, b);
  }

  /** 404 unknown, 401 wrong key, 204 done */
  async update(given, snapshot) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    const now = Date.now();
    await this.ctx.storage.put({ snapshot, updatedAt: now });
    await this.ctx.storage.setAlarm(now + this.config.idleMs);
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

  /** Viewers learn the session ended (with the last state), then everything goes */
  async end(reason) {
    const snapshot = await this.ctx.storage.get('snapshot');
    this.broadcast('ended', { reason, snapshot });
    for (const [controller, ping] of this.viewers) {
      clearInterval(ping);
      try { controller.close(); } catch { /* already gone */ }
    }
    this.viewers.clear();
    await this.ctx.storage.deleteAlarm();
    await this.ctx.storage.deleteAll();
    await this.env.LIMITER.get(this.env.LIMITER.idFromName('global')).release(this.id);
  }

  /** Nobody updated the session for IDLE_MINUTES: a lost phone, or the match is long over */
  async alarm() {
    if (!(await this.ctx.storage.get('key'))) return;
    await this.end('idle');
  }

  /** Queues a message for every viewer; a stream that is gone is dropped */
  broadcast(event, data) {
    const message = encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    for (const [controller, ping] of Array.from(this.viewers)) {
      try {
        controller.enqueue(message);
      } catch {
        clearInterval(ping);
        this.viewers.delete(controller);
      }
    }
  }

  /** GET /events: a Server-Sent Events stream with the state now and after every rally */
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname !== '/events') return new Response('Not found', { status: 404 });
    const state = await this.state();
    if (!state) return json(404, { error: 'Afgelopen' });
    if (this.viewers.size >= this.config.maxViewersPerSession) {
      return json(503, { error: 'Te veel kijkers, probeer het zo opnieuw' });
    }
    const viewers = this.viewers;
    let entry = null;
    // A ReadableStream with a controller: enqueue never waits for the reader,
    // and cancel() tells us the browser left
    const readable = new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode('retry: 3000\n\n'));
        controller.enqueue(encoder.encode(`event: state\ndata: ${JSON.stringify(state)}\n\n`));
        const ping = setInterval(() => {
          try {
            controller.enqueue(encoder.encode(': ping\n\n'));
          } catch {
            clearInterval(ping);
            viewers.delete(controller);
          }
        }, 25000);
        entry = [controller, ping];
        viewers.set(controller, ping);
      },
      cancel() {
        if (!entry) return;
        clearInterval(entry[1]);
        viewers.delete(entry[0]);
      },
    });
    return new Response(readable, {
      status: 200,
      headers: {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      },
    });
  }

  /** For tests: how many viewers are connected */
  viewerCount() {
    return this.viewers.size;
  }
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
  });
}
