// Squash Analyzer website: the static files (website/) plus one API,
// POST /api/vraag: a short answer from the manual (help.js). Everything else
// goes straight to the static assets. Questions are not stored or logged.
import { MANUALS, cleanQuestion, parseSections, pickSections, systemPrompt, userPrompt } from './help.js';

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

async function vraag(request, env) {
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
  if (!answer) return json(502, { error: 'geen antwoord' });
  return json(200, { answer, links: picked.slice(0, 2).map((section) => ({ title: section.title, href: `${path}#${section.id}` })) });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/api/vraag') {
      if (request.method !== 'POST') return json(405, { error: 'method' });
      try {
        return await vraag(request, env);
      } catch (error) {
        // No question text in the logs
        console.error('vraag', error && error.name);
        return json(500, { error: 'server' });
      }
    }
    return env.ASSETS.fetch(request);
  },
};
