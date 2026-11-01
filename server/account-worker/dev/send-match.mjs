// A pretend coach: sends a sample match the way a coach's phone does (a device
// key, no account), so a 4.0 test build has something to claim. Talks to the
// local Worker, or with --test to the test Worker (never to the real one).
//
//   node dev/send-match.mjs --test --team <SBN team link> --name "Gerd Lasso"
//   node dev/send-match.mjs --test --sbn <SBN player link>
//   node dev/send-match.mjs --test --link
//   node dev/send-match.mjs <player code>                 (older builds)
//
// Options: --coach "Peter" (the sender's name), --opponent "Mark",
// --new-phone (a fresh device key instead of this script's own one).
//
// The script keeps one device key per server in dev/.local, like one coach's
// phone: after a teammate claimed "Gerd Lasso", the next match for that name
// goes straight to their inbox, and `--links` shows what this phone learned.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const TEST_URL = 'https://test-account.squashanalyzer.com';
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const option = (name) => {
  const index = args.indexOf(`--${name}`);
  return index >= 0 ? args[index + 1] : undefined;
};
const usage = () => {
  console.error(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(0, 15).join('\n'));
  process.exit(1);
};

const base = process.env.ACCOUNT_URL || (flag('test') ? TEST_URL : 'http://localhost:8787');
if (/^https:\/\/account\.squashanalyzer\.com/.test(base)) {
  console.error('Niet naar de echte server: gebruik --test.');
  process.exit(1);
}

/** "https://sbn.toernooi.nl/league/<uuid>/team/<n>" → "<UUID>/<n>", as the app's team key */
function teamKey(link) {
  const found = /league\/([0-9a-fA-F-]{36})\/team\/(\d+)/.exec(link || '');
  if (!found) usage();
  return `${found[1].toUpperCase()}/${found[2]}`;
}

/** A player link or path → the path the app keeps ("/league/<uuid>/player/<n>") */
function playerPath(link) {
  const found = /(\/league\/[0-9a-fA-F-]{36}\/player\/\d+)/.exec(link || '');
  if (!found) usage();
  return found[1];
}

let to = null;
if (flag('links')) {
  // only the learned links, below
} else if (option('team')) {
  if (!option('name')) usage();
  to = { team: teamKey(option('team')), name: option('name') };
} else if (option('sbn')) {
  to = { sbnPath: playerPath(option('sbn')) };
} else if (flag('link')) {
  to = { link: true };
} else if (args[0] && !args[0].startsWith('--')) {
  to = { code: args[0].toUpperCase() };
} else {
  usage();
}

// One device key per server, like one coach's phone
const store = join(dirname(fileURLToPath(import.meta.url)), '.local');
const keyFile = join(store, `device-${new URL(base).host.replace(/[^a-z0-9.-]/gi, '_')}.json`);
let device = !flag('new-phone') && existsSync(keyFile) ? JSON.parse(readFileSync(keyFile, 'utf8')) : null;
if (!device) {
  device = await (await fetch(`${base}/api/v1/devices`, { method: 'POST' })).json();
  if (!device.deviceId) {
    console.error('Geen apparaatsleutel:', device);
    process.exit(1);
  }
  if (!flag('new-phone')) {
    mkdirSync(store, { recursive: true });
    writeFileSync(keyFile, JSON.stringify(device));
  }
}
const auth = `Device ${device.deviceId}.${device.deviceKey}`;

if (flag('links')) {
  console.log(JSON.stringify(await (await fetch(`${base}/api/v1/devices/links`, { headers: { Authorization: auth } })).json(), null, 2));
  process.exit(0);
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
const opponent = option('opponent') || 'Mark';
const playedAt = Date.now() - 2 * 60 * 60 * 1000;
const body = {
  matchId: crypto.randomUUID().toUpperCase(),
  playedAt,
  opponent,
  teamKey: to.team || null,
  summary: {
    v: 1, kind: 'coach', me: 1, p1: to.name || 'Jij', p2: opponent, gamesToWin: 3,
    gamesBefore: [0, 0], gamesWon: [3, 1], winner: 1, scores: games.map(score),
    duration: 2330.0, recordsPointTypes: true, startedAt: playedAt,
  },
  rallies: games,
  to,
  senderName: option('coach') || 'Coach Peter',
};
const answer = await fetch(`${base}/api/v1/submissions`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: auth },
  body: JSON.stringify(body),
});
const text = await answer.text();
console.log(`${answer.status} ${text}`);
const claimToken = (() => { try { return JSON.parse(text).claimToken; } catch { return null; } })();
if (claimToken) console.log(`Link: https://squashanalyzer.com/wedstrijd#${claimToken}  (in de app: squashanalyzer://wedstrijd#${claimToken})`);
console.log(`Naar ${base}. Staat klaar voor de speler (de server zegt bewust niet of die bestaat).`);
