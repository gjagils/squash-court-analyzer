// One Durable Object per live team match (Competitie): the two team names,
// the day and up to four partijen (E1-E4), each in the shape of a live match.
// Any phone with the team key writes its own slot; viewers get everything over
// Server-Sent Events. Like LiveSession: state in storage, an alarm removes it
// `IDLE_MINUTES` after the last update of any partij (so two hours after the
// last partij), nothing else is kept.

import { DurableObject } from 'cloudflare:workers';
import { readConfig } from './config.js';

const encoder = new TextEncoder();

export class TeamSession extends DurableObject {
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
  async create(key, team) {
    if (await this.ctx.storage.get('key')) return false;
    const now = Date.now();
    await this.ctx.storage.put({ key, team, partijen: {}, updatedAt: now });
    await this.ctx.storage.setAlarm(now + this.config.idleMs);
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

  async keyEquals(given) {
    const expected = await this.ctx.storage.get('key');
    const a = encoder.encode(given || '');
    const b = encoder.encode(expected || '');
    if (!expected || a.length !== b.length) return false;
    return crypto.subtle.timingSafeEqual(a, b);
  }

  async touch(extra) {
    const now = Date.now();
    await this.ctx.storage.put({ ...extra, updatedAt: now });
    await this.ctx.storage.setAlarm(now + this.config.idleMs);
    this.broadcast('state', await this.state());
  }

  /** 404 unknown, 401 wrong key, 204 done */
  async setTeam(given, team) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
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

  /** The team match is over for good (Live stoppen): everything goes at once */
  async remove(given) {
    if (!(await this.ctx.storage.get('key'))) return 404;
    if (!(await this.keyEquals(given))) return 401;
    await this.end('finished');
    return 204;
  }

  /** Viewers learn the session ended (with the last state), then everything goes */
  async end(reason) {
    const state = await this.state();
    this.broadcast('ended', { reason, ...(state || {}) });
    for (const [controller, ping] of this.viewers) {
      clearInterval(ping);
      try { controller.close(); } catch { /* already gone */ }
    }
    this.viewers.clear();
    await this.ctx.storage.deleteAlarm();
    await this.ctx.storage.deleteAll();
    await this.env.LIMITER.get(this.env.LIMITER.idFromName('global')).release(`t:${this.id}`);
  }

  /** Nobody updated any partij for IDLE_MINUTES: the evening is long over */
  async alarm() {
    if (!(await this.ctx.storage.get('key'))) return;
    await this.end('idle');
  }

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

  /** GET /events: a Server-Sent Events stream with the state now and after every change */
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
