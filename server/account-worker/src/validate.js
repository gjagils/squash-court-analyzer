// What the app may send. The match itself (summary and rallies) is the app's
// format and opaque here; the server only bounds its size and checks the
// fields it indexes on.

export const LIMITS = {
  name: 60,
  opponent: 60,
  sbnPath: 200,
  matchId: 64,
  teamKey: 80,
  summary: 4 * 1024,
  rallies: 32 * 1024,
  batch: 50,
  awards: 500,
  awardValue: 1024,
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
