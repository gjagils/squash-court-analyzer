// What the app may send. The match itself (summary and rallies) is the app's
// format and opaque here; the server only bounds its size and checks the
// fields it indexes on.

export const LIMITS = {
  name: 60,
  opponent: 60,
  sbnPath: 200,
  matchId: 64,
  teamKey: 80,
  teamName: 40,
  fixtures: 20,
  summary: 4 * 1024,
  rallies: 32 * 1024,
  batch: 50,
  awards: 500,
  awardValue: 1024,
  avatarBytes: 300 * 1024,
  avatarPaths: 50,
};

/** Trimmed text up to `max` characters, without control characters; '' for anything else */
export function cleanText(value, max) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, max);
}

/** The oldest birth year that may make an account this year (16 or older: AVG without parental consent) */
export function latestBirthYear(now) {
  return new Date(now).getUTCFullYear() - 16;
}

/**
 * A match as sent by the app, or an error text. `summary` and `rallies` are
 * JSON values; they are stored as text.
 */
export function readMatch(body) {
  if (!body || typeof body !== 'object') return { error: 'body' };
  const id = cleanText(body.matchId, LIMITS.matchId);
  if (!/^[A-Za-z0-9-]{8,64}$/.test(id)) return { error: 'matchId' };
  if (typeof body.playedAt !== 'number' || !Number.isFinite(body.playedAt) || body.playedAt <= 0) return { error: 'playedAt' };
  if (body.summary === undefined || body.rallies === undefined) return { error: 'match' };
  const summary = JSON.stringify(body.summary);
  const rallies = JSON.stringify(body.rallies);
  if (summary.length > LIMITS.summary || rallies.length > LIMITS.rallies) return { error: 'size' };
  const teamKey = cleanText(body.teamKey, LIMITS.teamKey);
  return {
    match: {
      id,
      playedAt: Math.floor(body.playedAt),
      opponent: cleanText(body.opponent, LIMITS.opponent),
      teamKey: teamKey || null,
      summary,
      rallies,
    },
  };
}

/**
 * An SBN match as the app has it (`LeagueFixture.id`, the link on the team
 * page): "/league/<uuid>/team-match/<n>", with the uuid in capitals like the
 * team key. '' for anything else.
 */
export function cleanFixture(value) {
  if (typeof value !== 'string') return '';
  const match = /^\/league\/([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\/team-match\/(\d{1,10})$/
    .exec(value.trim());
  return match ? `/league/${match[1].toUpperCase()}/team-match/${match[2]}` : '';
}

/** The league of a fixture or a team key, in capitals ('' when there is none) */
export function leagueOf(value) {
  const match = /([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})/i.exec(value || '');
  return match ? match[1].toUpperCase() : '';
}

/** A live team match id (the live Worker's ID_PATTERN) */
export const LIVE_ID_PATTERN = /^[a-z0-9]{12}$/;
/** A key of the live Worker: 32 bytes as base64url */
export const LIVE_KEY_PATTERN = /^[A-Za-z0-9_-]{43}$/;
