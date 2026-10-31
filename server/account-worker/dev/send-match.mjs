// Puts a sample match in a player's inbox on the local Worker, as a coach's
// phone would (a device key, no account). For trying the inbox in a 4.0 debug build:
//
//   node dev/send-match.mjs <spelerscode> [naam afzender]
//
// The player code is in the app under Instellingen → Mijn account.

const [code, sender = 'Coach Peter'] = process.argv.slice(2);
if (!code) {
  console.error('Gebruik: node dev/send-match.mjs <spelerscode> [naam afzender]');
  process.exit(1);
}
const base = process.env.ACCOUNT_URL || 'http://localhost:8787';

const device = await (await fetch(`${base}/api/v1/devices`, { method: 'POST' })).json();
if (!device.deviceId) {
  console.error('Geen apparaatsleutel:', device);
  process.exit(1);
}

// The app's compact format (AccountMatch.swift): one rally is winner|pointType|zone|shot|tenths|volley|server
const rally = (winner) => `${winner}|Winner|Achter Links|Drive|150||${winner}`;
/** An 11-n game: the loser's points spread between the winner's */
const game = (winner, against, duration) => {
  const list = [];
  for (let i = 0; i < 11; i++) {
    if (i < against) list.push(rally(3 - winner));
    list.push(rally(winner));
  }
  return { winner, duration, rallies: list };
};
const games = [game(1, 7, 540.0), game(2, 9, 610.0), game(1, 4, 580.0), game(1, 8, 600.0)];
const score = (g) => [g.rallies.filter((r) => r.startsWith('1')).length, g.rallies.filter((r) => r.startsWith('2')).length];
const playedAt = Date.now() - 2 * 60 * 60 * 1000;
const body = {
  matchId: crypto.randomUUID().toUpperCase(),
  playedAt,
  opponent: 'Mark',
  summary: {
    v: 1, kind: 'coach', me: 1, p1: 'Jij', p2: 'Mark', gamesToWin: 3,
    gamesBefore: [0, 0], gamesWon: [3, 1], winner: 1, scores: games.map(score),
    duration: 2330.0, recordsPointTypes: true, startedAt: playedAt,
  },
  rallies: games,
  to: { code: code.toUpperCase() },
  senderName: sender,
};
const answer = await fetch(`${base}/api/v1/submissions`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: `Device ${device.deviceId}.${device.deviceKey}` },
  body: JSON.stringify(body),
});
console.log(`${answer.status} ${await answer.text()}`);
console.log('Staat in het postvak als de code bestaat (de Worker zegt dat bewust niet).');
