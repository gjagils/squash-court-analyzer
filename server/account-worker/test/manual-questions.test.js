import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { wipeOldRequests } from '../src/index.js';

describe('manual questions', () => {
  it('the nightly job deletes questions older than 180 days and keeps newer ones', async () => {
    const day = 24 * 60 * 60 * 1000;
    const insert = (age, text) => env.DB.prepare(
      "INSERT INTO manual_questions (asked_at, lang, platform, source, question, answered) VALUES (?, 'nl', 'iphone', 'app', ?, 1)",
    ).bind(Date.now() - age, text).run();
    await insert(181 * day, 'oud');
    await insert(10 * day, 'nieuw');
    await wipeOldRequests(env);
    const { results } = await env.DB.prepare('SELECT question FROM manual_questions').all();
    expect(results.map((row) => row.question)).toEqual(['nieuw']);
  });
});
