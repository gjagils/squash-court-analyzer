// Squash Analyzer — live meekijken on Cloudflare Workers: the link preview of
// a shared single match (/l/<id>), with the stand in it.
//
// WhatsApp and iMessage fetch the preview once, when the link is shared, and
// keep it: the stand in the preview is the one of that moment and does not
// follow the match. That is fine (it invites people to open the page, which
// is live), but nobody should expect the preview itself to change.
//
// Only what the page shows anyway goes in: the first names and the score.

const WORDS = {
  nl: {
    live: '🔴 Live', result: 'Uitslag', warmup: 'Inspelen', final: 'Eindstand',
    follow: 'volg live in SquashAnalyzer', ended: 'Deze livewedstrijd is afgelopen.',
  },
  en: {
    live: '🔴 Live', result: 'Result', warmup: 'Warm-up', final: 'Final score',
    follow: 'follow live', ended: 'This live match has ended.',
  },
};

/**
 * The title and description of the link preview of a single match:
 * `🔴 Live: Jansen 2 – 1 Vries` and `Game 4 · 7–5 · volg live in SquashAnalyzer`.
 * Between games the next game is shown at 0–0 (the score the app sends then);
 * a finished match shows the game scores. `snapshot` null: the match is over
 * and gone from the server.
 */
export function previewLines(snapshot, lang = 'nl') {
  const words = WORDS[lang] || WORDS.nl;
  if (!snapshot) return { title: 'SquashAnalyzer · live', description: words.ended };
  const [won1, won2] = snapshot.gamesWon;
  const finished = snapshot.status === 'finished';
  const title = `${finished ? words.result : words.live}: ${snapshot.p1} ${won1} – ${won2} ${snapshot.p2}`;
  let stand;
  if (finished) {
    const games = snapshot.games.map((g) => `${g[0]}–${g[1]}`).join(', ');
    stand = games ? `${words.final} · ${games}` : words.final;
  } else if (snapshot.status === 'warmup') {
    stand = words.warmup;
  } else {
    stand = `Game ${won1 + won2 + 1} · ${snapshot.score[0]}–${snapshot.score[1]}`;
  }
  return { title, description: finished ? stand : `${stand} · ${words.follow}` };
}
