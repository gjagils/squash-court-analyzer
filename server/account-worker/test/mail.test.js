import { env } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { mailDeps, mailReset, resetGoogleToken } from '../src/mail.js';
import { wipeOldRequests } from '../src/index.js';
import { BASE, call, newPlayer } from './helpers.js';

// A stand-in for Google (token + Identity Toolkit) and Cirrux: users by uid,
// the mails that went out, and the admin updates
let users;
let mails;
let updates;
const realFetch = mailDeps.fetch;

function uidOf(auth) {
  const claims = JSON.parse(atob(auth.slice(7).split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
  return claims.sub;
}

function answer(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function fakeFetch(url, init = {}) {
  const body = init.body && init.body.startsWith('{') ? JSON.parse(init.body) : {};
  if (url === 'https://oauth2.googleapis.com/token') return answer(200, { access_token: 'google-token', expires_in: 3600 });
  const method = /accounts:(\w+)$/.exec(url)?.[1];
  if (method) {
    expect(init.headers.Authorization).toBe('Bearer google-token');
    if (method === 'lookup') {
      const found = body.localId
        ? body.localId.map((uid) => users[uid] && { localId: uid, ...users[uid] })
        : Object.entries(users).filter(([, u]) => body.email.includes(u.email)).map(([uid, u]) => ({ localId: uid, ...u }));
      return answer(200, { users: found.filter(Boolean) });
    }
    if (method === 'sendOobCode') {
      if (!Object.values(users).some((u) => u.email === body.email)) return answer(400, { error: { message: 'EMAIL_NOT_FOUND' } });
      const mode = body.requestType === 'VERIFY_EMAIL' ? 'verifyEmail' : 'resetPassword';
      return answer(200, { oobLink: `https://squash-analyzer-18fb3.firebaseapp.com/__/auth/action?mode=${mode}&oobCode=OOB${mode}&apiKey=AIzaKEY&lang=nl` });
    }
    if (method === 'update') {
      updates.push(body);
      if (Object.entries(users).some(([uid, u]) => uid !== body.localId && u.email === body.email)) {
        return answer(400, { error: { message: 'EMAIL_EXISTS' } });
      }
      users[body.localId].email = body.email;
      return answer(200, {});
    }
  }
  if (url === 'https://api.cirrux.co/public_api/v1/drafts') {
    expect(init.headers.Authorization).toBe('Bearer cxk_test');
    mails.push({ to: body.to[0].address, subject: body.subject, markdown: body.markdown, from: body.from, mailbox: body.mailbox_uuid });
    return answer(201, { uuid: `draft-${mails.length}` });
  }
  if (/\/drafts\/draft-\d+\/send$/.test(url)) return answer(200, { ok: true });
  throw new Error(`unexpected fetch ${url}`);
}

/** The code from a link in a mail */
const codeIn = (mail) => /[?&]code=([A-Z2-9]{32})/.exec(mail.markdown)[1];

beforeEach(() => {
  users = {};
  mails = [];
  updates = [];
  resetGoogleToken();
  mailDeps.fetch = fakeFetch;
});
afterEach(() => { mailDeps.fetch = realFetch; });

let addressCounter = 0;
async function player(provider = 'password') {
  const { auth } = await newPlayer({ name: 'Peter' });
  const email = `peter${addressCounter++}@example.com`;
  users[uidOf(auth)] = { email, providerUserInfo: [{ providerId: provider }] };
  return { auth, email };
}

describe('account mails', () => {
  it('verify: a link to the own page with Firebase code, in the asked language', async () => {
    const { auth, email } = await player();
    const res = await call('POST', '/api/v1/mail/verify', { auth, body: { lang: 'en' } });
    expect(res.status).toBe(202);
    expect(mails).toHaveLength(1);
    expect(mails[0]).toMatchObject({ to: email, subject: 'Confirm your email address', from: 'noreply@squashanalyzer.com', mailbox: 'mailbox-uuid' });
    expect(mails[0].markdown).toContain('Hi Peter,');
    expect(mails[0].markdown).toContain('https://www.squashanalyzer.com/account/?mode=verifyEmail&oobCode=OOBverifyEmail&apiKey=AIzaKEY&lang=en');
  });

  it('verify needs a signed-in caller', async () => {
    expect((await call('POST', '/api/v1/mail/verify', { body: {} })).status).toBe(401);
  });

  it('reset: the same answer with or without an account, a mail only for a known address', async () => {
    const { email } = await player();
    expect((await call('POST', '/api/v1/mail/reset', { body: { email: email.toUpperCase(), lang: 'nl' } })).status).toBe(202);
    expect((await call('POST', '/api/v1/mail/reset', { body: { email: 'nobody@example.com' } })).status).toBe(202);
    expect(mails).toHaveLength(1);
    expect(mails[0].subject).toBe('Kies een nieuw wachtwoord');
    expect(mails[0].markdown).toContain(`(${email})`);
    expect(mails[0].markdown).toContain('mode=resetPassword');
    expect((await call('POST', '/api/v1/mail/reset', { body: { email: 'geen adres' } })).status).toBe(400);
  });

  it('at most three mails per address an hour', async () => {
    const { email } = await player();
    for (let i = 0; i < 3; i++) expect((await call('POST', '/api/v1/mail/reset', { body: { email } })).status).toBe(202);
    expect((await call('POST', '/api/v1/mail/reset', { body: { email } })).status).toBe(429);
    expect(mails).toHaveLength(3);
  });

  it('without the secrets: 503, so the app lets Firebase send', async () => {
    const request = new Request(`${BASE}/api/v1/mail/reset`, { method: 'POST', body: JSON.stringify({ email: 'a@b.nl' }) });
    const res = await mailReset(request, { ...env, CIRRUX_API_KEY: '' });
    expect(res.status).toBe(503);
  });

  it('change: link to the new address, the change on confirm, then an undo mail to the old one', async () => {
    const { auth, email } = await player();
    const uid = uidOf(auth);
    expect((await call('POST', '/api/v1/mail/change', { auth, body: { email: 'Nieuw@Example.com', lang: 'nl' } })).status).toBe(202);
    expect(users[uid].email).toBe(email);
    expect(mails[0]).toMatchObject({ to: 'nieuw@example.com', subject: 'Bevestig je nieuwe e-mailadres' });
    expect(mails[0].markdown).toContain('https://www.squashanalyzer.com/account/?mode=changeEmail&code=');

    const confirmed = await call('POST', '/api/v1/mail/confirm', { body: { code: codeIn(mails[0]) } });
    expect(confirmed).toMatchObject({ status: 200, json: { kind: 'change', email: 'nieuw@example.com' } });
    expect(users[uid].email).toBe('nieuw@example.com');
    expect(updates[0]).toMatchObject({ localId: uid, email: 'nieuw@example.com', emailVerified: true });
    expect(mails[1]).toMatchObject({ to: email, subject: 'Je e-mailadres is gewijzigd' });
    expect(mails[1].markdown).toContain('mode=undoEmail');
    // A change link works once
    expect((await call('POST', '/api/v1/mail/confirm', { body: { code: codeIn(mails[0]) } })).status).toBe(410);

    const undone = await call('POST', '/api/v1/mail/confirm', { body: { code: codeIn(mails[1]) } });
    expect(undone).toMatchObject({ status: 200, json: { kind: 'undo', email } });
    expect(users[uid].email).toBe(email);
    expect(updates[1].validSince).toMatch(/^\d+$/);
    expect(mails[2]).toMatchObject({ to: email, subject: 'Kies een nieuw wachtwoord' });
    expect((await call('POST', '/api/v1/mail/confirm', { body: { code: codeIn(mails[1]) } })).status).toBe(410);
  });

  it('change refuses the same address, a taken one, and an Apple account', async () => {
    const one = await player();
    const two = await player();
    expect((await call('POST', '/api/v1/mail/change', { auth: one.auth, body: { email: one.email } })).json.error).toBe('same email');
    const taken = await call('POST', '/api/v1/mail/change', { auth: one.auth, body: { email: two.email } });
    expect(taken).toMatchObject({ status: 409, json: { error: 'email taken' } });
    const apple = await player('apple.com');
    expect((await call('POST', '/api/v1/mail/change', { auth: apple.auth, body: { email: 'x@example.com' } })).json.error).toBe('not password');
    expect(mails).toHaveLength(0);
  });

  it('only the newest change link works, and an old one expires after a day', async () => {
    const { auth } = await player();
    await call('POST', '/api/v1/mail/change', { auth, body: { email: 'een@example.com' } });
    await call('POST', '/api/v1/mail/change', { auth, body: { email: 'twee@example.com' } });
    expect((await call('POST', '/api/v1/mail/confirm', { body: { code: codeIn(mails[0]) } })).status).toBe(410);
    const realNow = mailDeps.now;
    mailDeps.now = () => realNow() + 25 * 60 * 60 * 1000;
    try {
      expect((await call('POST', '/api/v1/mail/confirm', { body: { code: codeIn(mails[1]) } })).status).toBe(410);
    } finally {
      mailDeps.now = realNow;
    }
  });

  it('confirm answers the account page with CORS, and refuses a malformed code', async () => {
    const headers = { Origin: 'https://www.squashanalyzer.com', 'Content-Type': 'application/json' };
    const { SELF } = await import('cloudflare:test');
    const pre = await SELF.fetch(`${BASE}/api/v1/mail/confirm`, { method: 'OPTIONS', headers });
    expect(pre.status).toBe(204);
    expect(pre.headers.get('Access-Control-Allow-Origin')).toBe('https://www.squashanalyzer.com');
    const bad = await SELF.fetch(`${BASE}/api/v1/mail/confirm`, { method: 'POST', headers, body: JSON.stringify({ code: 'kort' }) });
    expect(bad.status).toBe(400);
    expect(bad.headers.get('Access-Control-Allow-Origin')).toBe('https://www.squashanalyzer.com');
  });

  it('deleting the account removes its pending change', async () => {
    const { auth } = await player();
    await call('POST', '/api/v1/mail/change', { auth, body: { email: 'weg@example.com' } });
    expect((await call('DELETE', '/api/v1/me', { auth })).status).toBeLessThan(300);
    const { results } = await env.DB.prepare('SELECT * FROM email_changes WHERE uid = ?').bind(uidOf(auth)).all();
    expect(results).toHaveLength(0);
  });

  it('the nightly job clears old mail counts and expired changes', async () => {
    await env.DB.prepare('INSERT INTO mail_log (key_hash, sent_at) VALUES (?, ?)').bind('oud', Date.now() - 2 * 86400000).run();
    await wipeOldRequests(env);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM mail_log WHERE key_hash = 'oud'").first()).n).toBe(0);
  });
});

