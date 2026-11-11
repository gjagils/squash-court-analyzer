// Squash Analyzer website: the static files (website/) plus one API,
// POST /api/vraag: a short answer from the manual (help.js). Everything else
// goes straight to the static assets. Since 11 November 2026 each question is
// kept for 180 days in the account database (without IP address; e-mail
// addresses and phone numbers taken out), and GET /api/vraag/stats shows them
// to the owner with the STATS_KEY secret.
import { MANUALS, cleanQuestion, parseSections, pickSections, redact, statsView, systemPrompt, userPrompt } from './help.js';

const MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
const cache = new Map();

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

async function sections(env, request, path) {
  if (cache.has(path)) return cache.get(path);
  const response = await env.ASSETS.fetch(new Request(new URL(path, request.url)));
  const list = response.ok ? parseSections(await response.text()) : [];
  if (list.length > 0) cache.set(path, list);
  return list;
}

/** Keeps the question for the owner; never lets a storage problem spoil the answer */
async function remember(env, entry) {
  if (!env.DB) return;
  try {
    await env.DB.prepare(
      'INSERT INTO manual_questions (asked_at, lang, platform, source, question, answered) VALUES (?, ?, ?, ?, ?, ?)',
    ).bind(Date.now(), entry.lang, entry.platform, entry.source, redact(entry.question), entry.answered ? 1 : 0).run();
  } catch (error) {
    console.error('vraag opslaan', error && error.name);
  }
}

async function stats(request, env, url) {
  const key = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/, '');
  if (!env.STATS_KEY || key !== env.STATS_KEY) return json(401, { error: 'key' });
  const days = Math.min(Math.max(Number(url.searchParams.get('days')) || 30, 1), 180);
  const since = Date.now() - days * 86400000;
  const { results } = await env.DB.prepare(
    'SELECT asked_at, lang, platform, source, question, answered FROM manual_questions WHERE asked_at >= ? ORDER BY asked_at DESC',
  ).bind(since).all();
  return json(200, statsView(results, days, Date.now()));
}

async function vraag(request, env, ctx) {
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
  if (env.VRAAG_LIMIT) {
    const { success } = await env.VRAAG_LIMIT.limit({ key: ip });
    if (!success) return json(429, { error: 'te veel vragen' });
  }
  let body;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'vraag' });
  }
  const question = cleanQuestion(body && body.question);
  if (!question) return json(400, { error: 'vraag' });
  const lang = body.lang === 'en' ? 'en' : 'nl';
  const platform = body.platform === 'android' ? 'android' : 'iphone';
  const source = body.source === 'app' ? 'app' : 'web';
  const path = MANUALS[lang][platform];
  const picked = pickSections(await sections(env, request, path), question);
  if (picked.length === 0) return json(503, { error: 'handleiding' });
  const result = await env.AI.run(MODEL, {
    messages: [
      { role: 'system', content: systemPrompt(lang) },
      { role: 'user', content: userPrompt(question, picked) },
    ],
    max_tokens: 300,
    temperature: 0.2,
  });
  const answer = (result && result.response ? String(result.response) : '').trim();
  ctx.waitUntil(remember(env, { lang, platform, source, question, answered: Boolean(answer) }));
  if (!answer) return json(502, { error: 'geen antwoord' });
  return json(200, { answer, links: picked.slice(0, 2).map((section) => ({ title: section.title, href: `${path}#${section.id}` })) });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === '/api/vraag/stats' && request.method === 'GET') {
      try {
        return await stats(request, env, url);
      } catch (error) {
        console.error('vraag stats', error && error.name);
        return json(500, { error: 'server' });
      }
    }
    if (url.pathname === '/api/vraag') {
      if (request.method !== 'POST') return json(405, { error: 'method' });
      try {
        return await vraag(request, env, ctx);
      } catch (error) {
        // No question text in the logs
        console.error('vraag', error && error.name);
        return json(500, { error: 'server' });
      }
    }
    return env.ASSETS.fetch(request);
  },
};
