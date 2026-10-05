// One Durable Object for the whole service: how many sessions were created
// per IP and in total in the last minute, and which sessions exist (for the
// session cap and the health check). Kept in storage, so an evicted object
// does not forget the counts.

import { DurableObject } from 'cloudflare:workers';
import { readConfig } from './config.js';

const MINUTE = 60 * 1000;

export class LiveLimiter extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.config = readConfig(env);
  }

  /** One more session for `ip` within the limits per IP and in total? Counts the attempt. */
  async allowCreate(ip) {
    const now = Date.now();
    const minuteAgo = now - MINUTE;
    const creates = (await this.ctx.storage.get('creates')) || {};
    let all = ((await this.ctx.storage.get('allCreates')) || []).filter((t) => t > minuteAgo);
    for (const key of Object.keys(creates)) {
      creates[key] = creates[key].filter((t) => t > minuteAgo);
      if (creates[key].length === 0) delete creates[key];
    }
    if (all.length >= this.config.globalCreatesPerMinute) return false;
    const recent = creates[ip] || [];
    if (recent.length >= this.config.createsPerMinute) return false;
    recent.push(now);
    creates[ip] = recent;
    all.push(now);
    await this.ctx.storage.put({ creates, allCreates: all });
    return true;
  }

  /** Registers a new session; false when the cap is reached */
  async register(id) {
    const sessions = await this.liveSessions();
    if (Object.keys(sessions).length >= this.config.maxSessions) return false;
    sessions[id] = Date.now();
    await this.ctx.storage.put('sessions', sessions);
    return true;
  }

  async release(id) {
    const sessions = await this.liveSessions();
    if (!(id in sessions)) return;
    delete sessions[id];
    await this.ctx.storage.put('sessions', sessions);
  }

  async count() {
    return Object.keys(await this.liveSessions()).length;
  }

  /** The registry, without entries whose release got lost (older than the idle time plus a margin) */
  async liveSessions() {
    const sessions = (await this.ctx.storage.get('sessions')) || {};
    const cutoff = Date.now() - this.config.idleMs - 10 * MINUTE;
    for (const id of Object.keys(sessions)) {
      if (sessions[id] < cutoff) delete sessions[id];
    }
    return sessions;
  }
}
