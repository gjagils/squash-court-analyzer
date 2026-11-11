// The account mails, sent by us through Cirrux (11 November 2026) instead of by
// Firebase, whose templates this project cannot edit (docs/firebase-mailteksten.md §7).
//
//   POST /api/v1/mail/verify    (ID token) { lang }            confirm your address
//   POST /api/v1/mail/reset     { email, lang }                choose a new password
//   POST /api/v1/mail/change    (ID token) { email, lang }     a new address: a link to the new one
//   POST /api/v1/mail/confirm   { code }                       from squashanalyzer.com/account/:
//                                                              the change goes through, or is undone
//
// Verify and reset: Firebase makes the action link (Identity Toolkit with the
// service account, returnOobLink, so Firebase sends nothing) and the link goes to
// our own page. Changing the address is our own flow: a code here, the change
// with the admin API (which mails nobody), then a mail to the old address with a
// link that puts it back and signs every phone out.
//
// Secrets: FIREBASE_SERVICE_ACCOUNT (the JSON), CIRRUX_API_KEY, CIRRUX_MAILBOX.
// Without them the mail routes answer 503 and the app lets Firebase send.

import { randomText, sha256 } from './auth.js';

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const PAGE = 'https://www.squashanalyzer.com/account/';
const CIRRUX = 'https://api.cirrux.co/public_api/v1';
const IDENTITY = 'https://identitytoolkit.googleapis.com/v1';
const FROM = 'noreply@squashanalyzer.com';
export const CHANGE_HOURS = 24;
export const UNDO_DAYS = 7;
/** Mails per address and per IP address per hour */
const PER_ADDRESS = 3;
const PER_IP = 10;

/** Replaced in tests */
export const mailDeps = {
  fetch: (...args) => fetch(...args),
  now: () => Date.now(),
};

const ORIGINS = ['https://www.squashanalyzer.com', 'https://squashanalyzer.com'];

export function cors(request) {
  const origin = request.headers.get('Origin') || '';
  if (!ORIGINS.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(status, body, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...extra },
  });
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

export function mailConfigured(env) {
  return Boolean(env.FIREBASE_SERVICE_ACCOUNT && env.CIRRUX_API_KEY && env.CIRRUX_MAILBOX);
}

const lang = (value) => (value === 'en' ? 'en' : 'nl');

/** A plausible address, lower case; '' otherwise */
export function cleanEmail(value) {
  const text = String(value || '').trim().toLowerCase();
  if (text.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text)) return '';
  return text;
}

// MARK: - Google (the service account)

let cachedToken = null;
let cachedUntil = 0;

export function resetGoogleToken() {
  cachedToken = null;
  cachedUntil = 0;
}

function base64Url(bytes) {
  let binary = '';
  for (const b of new Uint8Array(bytes)) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
const encodeJson = (value) => base64Url(new TextEncoder().encode(JSON.stringify(value)));

/** An OAuth access token for the service account, cached until shortly before it expires */
async function googleToken(env) {
  const now = mailDeps.now();
  if (cachedToken && now < cachedUntil) return cachedToken;
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const iat = Math.floor(now / 1000);
  const head = encodeJson({ alg: 'RS256', typ: 'JWT', kid: account.private_key_id });
  const claims = encodeJson({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/cloud-platform',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  });
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${claims}`));
  const res = await mailDeps.fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${head}.${claims}.${base64Url(signature)}`,
  });
  if (!res.ok) throw new Error(`google token ${res.status}`);
  const answer = await res.json();
  cachedToken = answer.access_token;
  cachedUntil = now + (Number(answer.expires_in) || 3600) * 1000 - 5 * 60 * 1000;
  return cachedToken;
}

/** The admin Identity Toolkit API: the answer, or { error: 'EMAIL_EXISTS' … } */
async function identity(env, method, body) {
  const token = await googleToken(env);
  const res = await mailDeps.fetch(`${IDENTITY}/projects/${env.FIREBASE_PROJECT_ID}/accounts:${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ ...body, targetProjectId: env.FIREBASE_PROJECT_ID }),
  });
  const answer = await res.json().catch(() => ({}));
  if (res.ok) return answer;
  const message = String(answer?.error?.message || `status ${res.status}`);
  return { error: message.split(/[ :]/)[0] };
}

/** The Firebase user: { email, password } (password: signs in with a password), or null */
async function userByUid(env, uid) {
  const answer = await identity(env, 'lookup', { localId: [uid] });
  const user = answer.users && answer.users[0];
  if (!user) return null;
  const password = (user.providerUserInfo || []).some((p) => p.providerId === 'password');
  return { email: (user.email || '').toLowerCase(), password };
}

async function emailInUse(env, email) {
  const answer = await identity(env, 'lookup', { email: [email] });
  return Boolean(answer.users && answer.users.length);
}

/**
 * Firebase's action link, turned into a link to our own page (same mode,
 * oobCode and apiKey); null when Firebase knows no such user
 */
async function actionLink(env, requestType, email, language) {
  const answer = await identity(env, 'sendOobCode', { requestType, email, returnOobLink: true });
  if (answer.error === 'EMAIL_NOT_FOUND' || answer.error === 'USER_NOT_FOUND') return null;
  if (answer.error || !answer.oobLink) throw new Error(`oob ${answer.error || 'no link'}`);
  const firebase = new URL(answer.oobLink);
  const link = new URL(PAGE);
  for (const name of ['mode', 'oobCode', 'apiKey']) link.searchParams.set(name, firebase.searchParams.get(name) || '');
  link.searchParams.set('lang', language);
  return link.toString();
}

// MARK: - Cirrux

/** Sends one mail: a draft, then send. Mail through the API stays in the mailbox's Sent folder. */
export async function sendMail(env, to, subject, markdown) {
  const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${env.CIRRUX_API_KEY}` };
  const draft = await mailDeps.fetch(`${CIRRUX}/drafts`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      mailbox_uuid: env.CIRRUX_MAILBOX, body_format: 'markdown', from: FROM, to: [{ address: to }], subject, markdown,
    }),
  });
  if (!draft.ok) throw new Error(`cirrux draft ${draft.status}`);
  const made = await draft.json().catch(() => ({}));
  const uuid = made.uuid || made.draft?.uuid || made.data?.uuid;
  if (!uuid) throw new Error('cirrux draft without uuid');
  const sent = await mailDeps.fetch(`${CIRRUX}/drafts/${uuid}/send`, { method: 'POST', headers });
  if (!sent.ok) throw new Error(`cirrux send ${sent.status}`);
}

// MARK: - The texts (docs/firebase-mailteksten.md §5), one language per mail

/** A name in a greeting: no markdown characters, at most 40 */
function greeting(language, name) {
  const clean = String(name || '').replace(/[\\`*_[\]()<>#!|~]/g, '').trim().slice(0, 40);
  if (language === 'en') return clean ? `Hi ${clean},` : 'Hi,';
  return clean ? `Hoi ${clean},` : 'Hoi,';
}

const SIGN = { nl: 'Groeten,  \nSquashAnalyzer', en: 'Cheers,  \nSquashAnalyzer' };

export const texts = {
  verify: (l, name, link) => (l === 'en'
    ? { subject: 'Confirm your email address', body: `${greeting(l, name)}\n\nThanks for creating a SquashAnalyzer account. Tap the link below to confirm your email address.\n\n[Confirm my email address](${link})\n\nDidn't create an account? You can ignore this email.\n\n${SIGN.en}` }
    : { subject: 'Bevestig je e-mailadres', body: `${greeting(l, name)}\n\nFijn dat je een account hebt gemaakt bij SquashAnalyzer. Tik op de link hieronder om je e-mailadres te bevestigen.\n\n[Bevestig mijn e-mailadres](${link})\n\nHeb jij geen account gemaakt? Dan kun je deze mail negeren.\n\n${SIGN.nl}` }),
  reset: (l, name, link, email) => (l === 'en'
    ? { subject: 'Choose a new password', body: `${greeting(l, name)}\n\nYou asked for a new password for your SquashAnalyzer account (${email}). Tap the link below to choose one.\n\n[Choose a new password](${link})\n\nDidn't ask for this? You can ignore this email; your password stays the same.\n\n${SIGN.en}` }
    : { subject: 'Kies een nieuw wachtwoord', body: `${greeting(l, name)}\n\nJe hebt gevraagd om een nieuw wachtwoord voor je SquashAnalyzer-account (${email}). Tik op de link hieronder om er een te kiezen.\n\n[Kies een nieuw wachtwoord](${link})\n\nHeb je dit niet zelf gevraagd? Dan kun je deze mail negeren; je wachtwoord blijft hetzelfde.\n\n${SIGN.nl}` }),
  change: (l, name, link) => (l === 'en'
    ? { subject: 'Confirm your new email address', body: `${greeting(l, name)}\n\nYou want to sign in to SquashAnalyzer with this address from now on. Tap the link below to confirm it. The link works for ${CHANGE_HOURS} hours.\n\n[Confirm my new email address](${link})\n\nDidn't ask for this? You can ignore this email; nothing changes.\n\n${SIGN.en}` }
    : { subject: 'Bevestig je nieuwe e-mailadres', body: `${greeting(l, name)}\n\nJe wilt voortaan met dit adres inloggen bij SquashAnalyzer. Tik op de link hieronder om het te bevestigen. De link werkt ${CHANGE_HOURS} uur.\n\n[Bevestig mijn nieuwe e-mailadres](${link})\n\nHeb je dit niet zelf gevraagd? Dan kun je deze mail negeren; er verandert niets.\n\n${SIGN.nl}` }),
  changed: (l, name, link, newEmail) => (l === 'en'
    ? { subject: 'Your email address was changed', body: `${greeting(l, name)}\n\nThe email address of your SquashAnalyzer account was changed to ${newEmail}.\n\nDidn't do this yourself? [Restore your old address](${link}). We then sign out every phone and send you a link to choose a new password. The link works for ${UNDO_DAYS} days.\n\n${SIGN.en}` }
    : { subject: 'Je e-mailadres is gewijzigd', body: `${greeting(l, name)}\n\nHet e-mailadres van je SquashAnalyzer-account is gewijzigd naar ${newEmail}.\n\nHeb je dit niet zelf gedaan? [Zet je oude adres terug](${link}). Daarna loggen we elke telefoon uit en krijg je een link om een nieuw wachtwoord te kiezen. De link werkt ${UNDO_DAYS} dagen.\n\n${SIGN.nl}` }),
};

// MARK: - Limits

/** Counts this mail; false when the address or the IP address sent too many this hour */
async function allowed(env, request, email) {
  const now = mailDeps.now();
  const keys = [await sha256(`mail:${email}`), await sha256(`mailip:${request.headers.get('CF-Connecting-IP') || '0.0.0.0'}`)];
  const counts = await env.DB.batch(keys.map((key) => env.DB.prepare('SELECT COUNT(*) AS n FROM mail_log WHERE key_hash = ? AND sent_at > ?').bind(key, now - HOUR)));
  if ((counts[0].results[0]?.n || 0) >= PER_ADDRESS || (counts[1].results[0]?.n || 0) >= PER_IP) return false;
  await env.DB.batch(keys.map((key) => env.DB.prepare('INSERT INTO mail_log (key_hash, sent_at) VALUES (?, ?)').bind(key, now)));
  return true;
}

function pageLink(env, mode, code, language) {
  const link = new URL(PAGE);
  link.searchParams.set('mode', mode);
  link.searchParams.set('code', code);
  link.searchParams.set('lang', language);
  // The page asks the Worker that made the code
  if (env.MAIL_SERVER === 'test') link.searchParams.set('server', 'test');
  return link.toString();
}

async function playerName(env, uid) {
  const row = await env.DB.prepare('SELECT p.name FROM accounts a JOIN players p ON p.id = a.player_id WHERE a.uid = ?').bind(uid).first();
  return row?.name || '';
}

// MARK: - Routes

/** Confirm your address: for the signed-in caller's own address */
export async function mailVerify(request, env, uid) {
  if (!mailConfigured(env)) return json(503, { error: 'mail off' });
  const body = (await readJson(request)) || {};
  const language = lang(body.lang);
  const user = await userByUid(env, uid);
  if (!user || !user.email) return json(404, { error: 'not found' });
  if (!(await allowed(env, request, user.email))) return json(429, { error: 'too many mails' });
  const link = await actionLink(env, 'VERIFY_EMAIL', user.email, language);
  if (!link) return json(404, { error: 'not found' });
  const text = texts.verify(language, await playerName(env, uid), link);
  await sendMail(env, user.email, text.subject, text.body);
  return json(202, { ok: true });
}

/** Choose a new password. The same answer whether the address has an account or not. */
export async function mailReset(request, env) {
  if (!mailConfigured(env)) return json(503, { error: 'mail off' });
  const body = (await readJson(request)) || {};
  const email = cleanEmail(body.email);
  if (!email) return json(400, { error: 'email' });
  const language = lang(body.lang);
  if (!(await allowed(env, request, email))) return json(429, { error: 'too many mails' });
  const link = await actionLink(env, 'PASSWORD_RESET', email, language);
  if (link) {
    const text = texts.reset(language, '', link, email);
    await sendMail(env, email, text.subject, text.body);
  }
  return json(202, { ok: true });
}

/** A new address for the signed-in caller (password accounts only): a link to the new address */
export async function mailChange(request, env, uid) {
  if (!mailConfigured(env)) return json(503, { error: 'mail off' });
  const body = (await readJson(request)) || {};
  const email = cleanEmail(body.email);
  if (!email) return json(400, { error: 'email' });
  const language = lang(body.lang);
  const user = await userByUid(env, uid);
  if (!user) return json(404, { error: 'not found' });
  if (!user.password) return json(409, { error: 'not password' });
  if (user.email === email) return json(400, { error: 'same email' });
  if (await emailInUse(env, email)) return json(409, { error: 'email taken' });
  if (!(await allowed(env, request, email))) return json(429, { error: 'too many mails' });
  const now = mailDeps.now();
  const code = randomText(32);
  // Only the newest change link works
  await env.DB.batch([
    env.DB.prepare("DELETE FROM email_changes WHERE uid = ? AND kind = 'change'").bind(uid),
    env.DB.prepare("INSERT INTO email_changes (code_hash, uid, kind, old_email, new_email, lang, expires_at) VALUES (?, ?, 'change', ?, ?, ?, ?)")
      .bind(await sha256(code), uid, user.email, email, language, now + CHANGE_HOURS * HOUR),
  ]);
  const text = texts.change(language, await playerName(env, uid), pageLink(env, 'changeEmail', code, language));
  await sendMail(env, email, text.subject, text.body);
  return json(202, { ok: true });
}

/** From the account page: a change link (the address changes) or an undo link (the old one comes back) */
export async function mailConfirm(request, env) {
  const headers = cors(request);
  if (!mailConfigured(env)) return json(503, { error: 'mail off' }, headers);
  const body = (await readJson(request)) || {};
  const code = String(body.code || '');
  if (!/^[A-Z2-9]{32}$/.test(code)) return json(400, { error: 'code' }, headers);
  const now = mailDeps.now();
  const row = await env.DB.prepare('SELECT * FROM email_changes WHERE code_hash = ?').bind(await sha256(code)).first();
  if (!row || row.expires_at <= now) return json(410, { error: 'expired' }, headers);
  const user = await userByUid(env, row.uid);
  if (!user) return json(404, { error: 'not found' }, headers);

  if (row.kind === 'change') {
    // Changed some other way in between: this link is stale
    if (user.email !== row.old_email) return json(410, { error: 'expired' }, headers);
    const result = await identity(env, 'update', { localId: row.uid, email: row.new_email, emailVerified: true });
    if (result.error === 'EMAIL_EXISTS') return json(409, { error: 'email taken' }, headers);
    if (result.error) throw new Error(`update ${result.error}`);
    const undo = randomText(32);
    await env.DB.batch([
      env.DB.prepare('DELETE FROM email_changes WHERE code_hash = ?').bind(row.code_hash),
      env.DB.prepare("INSERT INTO email_changes (code_hash, uid, kind, old_email, new_email, lang, expires_at) VALUES (?, ?, 'undo', ?, ?, ?, ?)")
        .bind(await sha256(undo), row.uid, row.old_email, row.new_email, row.lang, now + UNDO_DAYS * DAY),
    ]);
    const text = texts.changed(row.lang, await playerName(env, row.uid), pageLink(env, 'undoEmail', undo, row.lang), row.new_email);
    await sendMail(env, row.old_email, text.subject, text.body);
    return json(200, { kind: 'change', email: row.new_email }, headers);
  }

  // Undo: the old address back, every session ends, and a link for a new password
  const result = await identity(env, 'update', {
    localId: row.uid, email: row.old_email, emailVerified: true, validSince: String(Math.floor(now / 1000)),
  });
  if (result.error === 'EMAIL_EXISTS') return json(409, { error: 'email taken' }, headers);
  if (result.error) throw new Error(`update ${result.error}`);
  await env.DB.prepare('DELETE FROM email_changes WHERE uid = ?').bind(row.uid).run();
  const link = await actionLink(env, 'PASSWORD_RESET', row.old_email, row.lang);
  if (link) {
    const text = texts.reset(row.lang, await playerName(env, row.uid), link, row.old_email);
    await sendMail(env, row.old_email, text.subject, text.body);
  }
  return json(200, { kind: 'undo', email: row.old_email }, headers);
}
