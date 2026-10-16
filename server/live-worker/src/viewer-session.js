// What a live match (LiveSession) and a live team match (TeamSession) share: one
// Durable Object per session with a write key in storage, an alarm that removes it
// after `IDLE_MINUTES` without an update, and viewers that follow it over
// Server-Sent Events. The subclass says what its state is (`state()`), what the
// viewers get at the end (`endedPayload()`) and how the limiter knows it
// (`limiterKey()`).
//
// Followers (Live score op het vergrendelscherm) live here too: phones that
// registered a push token. Each is its own storage entry ("follower:" + SHA-256
// of platform and token), wiped with the session. The subclass decides when
// they get a push; the fan-out runs in the background, in order, and forgets
// dead tokens. At the end of the session (Live stoppen, idle alarm) they get
// the end once, if the subclass did not send it already (`endPushed`).

import { DurableObject } from 'cloudflare:workers';
import { readConfig } from './config.js';
import { pushToFollowers } from './push.js';

export const encoder = new TextEncoder();

const FOLLOWER_PREFIX = 'follower:';

async function followerKey(follower) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(`${follower.platform}\n${follower.token}`));
  return FOLLOWER_PREFIX + Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Constant-time comparison of a given key with the stored one */
export function sameKey(given, expected) {
  const a = encoder.encode(given || '');
  const b = encoder.encode(expected || '');
  if (!expected || a.length !== b.length) return false;
  return crypto.subtle.timingSafeEqual(a, b);
}

export function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
  });
}

export class ViewerSession extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.config = readConfig(env);
    /** Open SSE streams: stream controller -> ping timer */
    this.viewers = new Map();
  }

  get id() {
    return this.ctx.id.name || '';
  }

  /** What viewers get now, or null when this session does not exist (subclass) */
  async state() {
    throw new Error('state() is up to the subclass');
  }

  /** What viewers get with the `ended` event, read before the storage is wiped (subclass) */
  async endedPayload() {
    throw new Error('endedPayload() is up to the subclass');
  }

  /** The name the limiter registers this session under (subclass may prefix it) */
  limiterKey(id) {
    return id;
  }

  async keyEquals(given) {
    return sameKey(given, await this.ctx.storage.get('key'));
  }

  /** Sets the alarm that removes the session `IDLE_MINUTES` from now */
  async scheduleIdleAlarm(now) {
    await this.ctx.storage.setAlarm(now + this.config.idleMs);
  }

  /**
   * What the followers get with a push: { kind: "live" | "team", state, finished? },
   * or null (subclass). `finished` false makes an end go away in a minute.
   */
  async pushContent() {
    return null;
  }

  /** Viewers learn the session ended (with the last state), then everything goes */
  async end(reason) {
    const finalPush = await this.finalPushJob();
    const payload = await this.endedPayload(reason);
    const id = this.id || (await this.ctx.storage.get('id')) || '';
    this.broadcast('ended', payload);
    for (const [controller, ping] of this.viewers) {
      clearInterval(ping);
      try { controller.close(); } catch { /* already gone */ }
    }
    this.viewers.clear();
    // Free the place first: a failing release must not stop the clean-up (a
    // lost entry expires in the limiter after the idle time anyway)
    try {
      await this.env.LIMITER.get(this.env.LIMITER.idFromName('global')).release(this.limiterKey(id));
    } catch { /* expires on its own */ }
    await this.ctx.storage.deleteAlarm();
    await this.ctx.storage.deleteAll();
    if (finalPush) this.schedulePush(finalPush);
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

  /** The registered followers ({ platform, token, sandbox, alerts }) */
  async followers() {
    return Array.from((await this.ctx.storage.list({ prefix: FOLLOWER_PREFIX })).values());
  }

  /**
   * The event for the followers after a change: "end" once when the session is
   * done now, null when that end went out already, else "update" (and a later
   * end may go again, after a correction back to not done).
   */
  async followerEvent(done) {
    if (done) {
      if (await this.ctx.storage.get('endPushed')) return null;
      await this.ctx.storage.put('endPushed', true);
      return 'end';
    }
    await this.ctx.storage.delete('endPushed');
    return 'update';
  }

  /** A push job for the followers: { id, server, kind, snapshot, finished, event, followers, alert } */
  async pushJob(event, followers, content, alert = null) {
    const [server, storedId] = await Promise.all([this.ctx.storage.get('pushServer'), this.ctx.storage.get('id')]);
    return {
      id: this.id || storedId || '', server: server || '', kind: content.kind, snapshot: content.state,
      finished: content.finished, event, followers, alert,
    };
  }

  /** The end for the followers when the session goes, unless it went out already */
  async finalPushJob() {
    const [followers, endPushed] = await Promise.all([this.followers(), this.ctx.storage.get('endPushed')]);
    if (followers.length === 0 || endPushed) return null;
    const content = await this.pushContent();
    if (!content || !content.state) return null;
    return this.pushJob('end', followers, content);
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

  /** Nobody updated the session for IDLE_MINUTES: a lost phone, or the evening is long over */
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
    // The browser left (closed the tab, lost the network): the place is free now,
    // not only when the next ping fails
    request.signal?.addEventListener('abort', () => {
      if (!entry) return;
      clearInterval(entry[1]);
      viewers.delete(entry[0]);
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
