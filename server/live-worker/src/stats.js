// Usage counts of the live service (Gerd-Jan, 23 October 2026): how often a
// live match or a live team match is started and how often viewers and lock
// screen followers connect, per day, without anything that points to a
// person: no IP addresses, no session ids, no names, no time finer than a day.
// One Durable Object for the whole service, read with GET /api/stats and the
// STATS_KEY secret. See docs/voorstel-gebruikscijfers.md.

import { DurableObject } from 'cloudflare:workers';

export const KINDS = ['live', 'team', 'viewer-live', 'viewer-team', 'follower-live', 'follower-team'];
/**
 * The daily usage count of the app itself (3.1 and later, docs/voorstel-gebruikstelling-app.md):
 * `app` = opened that day, `app-first` = the first report of an installation, and per part of
 * the app whether it was used that day. Kept in their own table, with the app version.
 */
export const APP_PARTS = ['coach', 'referee', 'analysis', 'competition'];
export const APP_KINDS = ['app', 'app-first', ...APP_PARTS.map((part) => `app-${part}`)];
const VERSION_PATTERN = /^\d{1,3}(\.\d{1,3}){0,2}$/;
const PLATFORMS = ['ios', 'android'];
/** The sample players of the app (Bob and Wim): a match between the two is a try-out, counted apart */
const SAMPLE_PLAYERS = ['bob', 'wim'];
/** The sample players of the test period: never real names, so one of them is enough */
const TEST_ONLY_PLAYERS = ['bombardino', 'whiskey'];
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const TEXT_MAX = 40;

/** The `platform` an app (3.0.1 and later) sends with a new session: "ios", "android" or unknown (older apps) */
export function cleanPlatform(value) {
  if (typeof value !== 'string') return 'unknown';
  const base = value.trim().toLowerCase();
  return PLATFORMS.includes(base) ? base : 'unknown';
}

/** The club of an SBN team name: the name without the team number at the end ("All Inn Squash 8" → "All Inn Squash") */
export function clubName(team) {
  if (typeof team !== 'string') return '';
  const trimmed = team.trim();
  const club = trimmed.replace(/(\s+[A-Za-z]?\d{1,2}[A-Za-z]?)+$/, '').trim();
  return (club || trimmed).slice(0, TEXT_MAX);
}

/**
 * A match with the sample players: Bob against Wim (both: a real Bob playing a
 * real Tim counts as a real match), or Bombardino or Whiskey on either side.
 */
export function isSampleMatch(p1, p2) {
  const names = [p1, p2].map((name) => String(name || '').trim().toLowerCase());
  if (names.some((name) => TEST_ONLY_PLAYERS.includes(name))) return true;
  return names.every((name) => SAMPLE_PLAYERS.includes(name));
}

/** A team match for trying out: a team called test or voorbeeld */
export function isTestTeam(home, away) {
  return [home, away].some((name) => /\b(test|voorbeeld)/i.test(String(name || '')));
}

/** The day in the Netherlands as YYYY-MM-DD; the UTC day when the time zone is unknown here */
export function dayOf(now = Date.now()) {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Amsterdam', year: 'numeric', month: '2-digit', day: '2-digit' })
      .format(new Date(now));
  } catch {
    return new Date(now).toISOString().slice(0, 10);
  }
}

/** The marketing version an app sends ("3.1"); anything else is unknown */
export function cleanVersion(value) {
  if (typeof value !== 'string') return 'unknown';
  const text = value.trim();
  return VERSION_PATTERN.test(text) ? text : 'unknown';
}

/** The known parts in a report, each once, in a fixed order; anything else is dropped */
export function cleanParts(value) {
  if (!Array.isArray(value)) return [];
  return APP_PARTS.filter((part) => value.includes(part));
}

function cleanText(value, max = TEXT_MAX) {
  if (typeof value !== 'string') return 'unknown';
  const text = value.trim();
  return text ? text.slice(0, max) : 'unknown';
}

/**
 * Per kind: how many real and how many test (sample players, test team) events the rows hold.
 * The app rows (`appRows`) have no test column: they all count as real.
 */
export function totalsOf(rows, appRows = []) {
  const totals = {};
  for (const kind of [...KINDS, ...APP_KINDS]) totals[kind] = { real: 0, test: 0 };
  for (const row of appRows) {
    if (totals[row.kind]) totals[row.kind].real += Number(row.n) || 0;
  }
  for (const row of rows) {
    if (!totals[row.kind]) continue;
    totals[row.kind][row.test ? 'test' : 'real'] += Number(row.n) || 0;
  }
  return totals;
}

export class StatsCounter extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS counts (
      day TEXT NOT NULL, kind TEXT NOT NULL, platform TEXT NOT NULL, lang TEXT NOT NULL,
      country TEXT NOT NULL, region TEXT NOT NULL, club TEXT NOT NULL, test INTEGER NOT NULL,
      n INTEGER NOT NULL,
      PRIMARY KEY (day, kind, platform, lang, country, region, club, test))`);
    this.ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS app_days (
      day TEXT NOT NULL, kind TEXT NOT NULL, platform TEXT NOT NULL, version TEXT NOT NULL,
      lang TEXT NOT NULL, country TEXT NOT NULL, region TEXT NOT NULL, n INTEGER NOT NULL,
      PRIMARY KEY (day, kind, platform, version, lang, country, region))`);
  }

  /** One more of `kind` today. Unknown kinds are ignored; nothing here can fail the request. */
  async bump(kind, fields = {}) {
    if (!KINDS.includes(kind)) return;
    this.ctx.storage.sql.exec(
      `INSERT INTO counts (day, kind, platform, lang, country, region, club, test, n) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
       ON CONFLICT (day, kind, platform, lang, country, region, club, test) DO UPDATE SET n = n + 1`,
      dayOf(), kind, cleanPlatform(fields.platform), fields.lang === 'en' ? 'en' : 'nl',
      cleanText(fields.country, 2), cleanText(fields.region), typeof fields.club === 'string' && fields.club ? fields.club.slice(0, TEXT_MAX) : '',
      fields.test ? 1 : 0);
  }

  /** One more of an app kind today (`app`, `app-first`, `app-coach`, ...). Unknown kinds are ignored. */
  async bumpApp(kind, fields = {}) {
    if (!APP_KINDS.includes(kind)) return;
    this.ctx.storage.sql.exec(
      `INSERT INTO app_days (day, kind, platform, version, lang, country, region, n) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
       ON CONFLICT (day, kind, platform, version, lang, country, region) DO UPDATE SET n = n + 1`,
      dayOf(), kind, cleanPlatform(fields.platform), cleanVersion(fields.version), fields.lang === 'en' ? 'en' : 'nl',
      cleanText(fields.country, 2), cleanText(fields.region));
  }

  /** The app rows of the days from..to (inclusive, YYYY-MM-DD; either may be missing), oldest first */
  async appRows(from, to) {
    const first = DAY_PATTERN.test(from || '') ? from : '0000-00-00';
    const last = DAY_PATTERN.test(to || '') ? to : '9999-99-99';
    return this.ctx.storage.sql.exec(
      `SELECT day, kind, platform, version, lang, country, region, n FROM app_days WHERE day >= ? AND day <= ?
       ORDER BY day, kind, platform, version, lang, country, region`, first, last).toArray();
  }

  /** The rows of the days from..to (inclusive, YYYY-MM-DD; either may be missing), oldest first */
  async rows(from, to) {
    const first = DAY_PATTERN.test(from || '') ? from : '0000-00-00';
    const last = DAY_PATTERN.test(to || '') ? to : '9999-99-99';
    return this.ctx.storage.sql.exec(
      `SELECT day, kind, platform, lang, country, region, club, test, n FROM counts WHERE day >= ? AND day <= ?
       ORDER BY day, kind, platform, lang, country, region, club, test`, first, last).toArray();
  }
}
