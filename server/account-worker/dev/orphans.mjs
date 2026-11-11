// Accounts whose Firebase user is gone (deleted in the Firebase console instead
// of with Account verwijderen in the app). Their player, SBN link ("Dit ben ik")
// and matches stay in D1 and block that SBN player for a new account.
// Lists them; with --wissen removes them the way DELETE /api/v1/me does.
//
//   node dev/orphans.mjs            # de echte database (squash-account), alleen kijken
//   node dev/orphans.mjs --test     # squash-account-test
//   node dev/orphans.mjs --wissen   # weesaccounts wissen (vraagt eerst)
//
// Needs the Firebase service account in ~/.android-keys/firebase-service-account.json.

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';
import { homedir } from 'node:os';
import { createInterface } from 'node:readline/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const test = process.argv.includes('--test');
const wipe = process.argv.includes('--wissen');
const db = test ? ['squash-account-test', '--env', 'test'] : ['squash-account'];

function d1(sql) {
  const run = spawnSync('npx', ['wrangler', 'd1', 'execute', db[0], ...db.slice(1), '--remote', '--json', '--command', sql],
    { cwd: root, encoding: 'utf8' });
  if (run.status !== 0) throw new Error(run.stderr || run.stdout);
  return JSON.parse(run.stdout)[0].results;
}

async function googleToken(account) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/identitytoolkit',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 600,
  })}`;
  const signature = createSign('RSA-SHA256').update(unsigned).sign(account.private_key, 'base64url');
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${unsigned}.${signature}`,
  });
  return (await res.json()).access_token;
}

const account = JSON.parse(readFileSync(join(homedir(), '.android-keys', 'firebase-service-account.json'), 'utf8'));
const rows = d1('SELECT a.uid, p.id AS player_id, p.name, p.sbn_path FROM accounts a JOIN players p ON p.id = a.player_id');
const token = await googleToken(account);
const existing = new Set();
for (let i = 0; i < rows.length; i += 100) {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${account.project_id}/accounts:lookup`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify({ localId: rows.slice(i, i + 100).map((row) => row.uid) }),
  });
  for (const user of (await res.json()).users || []) existing.add(user.localId);
}
const orphans = rows.filter((row) => !existing.has(row.uid));
console.log(`${rows.length} accounts in ${db[0]}, ${orphans.length} zonder Firebase-gebruiker:`);
for (const row of orphans) console.log(`  ${row.name}${row.sbn_path ? `  (SBN: ${row.sbn_path})` : ''}`);
if (!wipe || orphans.length === 0) process.exit(0);

const prompt = createInterface({ input: process.stdin, output: process.stdout });
const answer = await prompt.question(`Deze ${orphans.length} accounts met hun wedstrijden wissen? Typ "wissen": `);
prompt.close();
if (answer.trim() !== 'wissen') {
  console.log('Niets gewist.');
  process.exit(0);
}
const q = (value) => `'${String(value).replace(/'/g, "''")}'`;
const sql = orphans.flatMap(({ uid, player_id: id }) => [
  `DELETE FROM matches WHERE player_id = ${q(id)}`,
  `DELETE FROM awards WHERE player_id = ${q(id)}`,
  `DELETE FROM blocks WHERE player_id = ${q(id)}`,
  `DELETE FROM avatars WHERE player_id = ${q(id)}`,
  `DELETE FROM avatar_reports WHERE player_id = ${q(id)}`,
  `DELETE FROM team_lives WHERE starter_id = ${q(id)}`,
  `DELETE FROM learned_links WHERE sbn_path = (SELECT sbn_path FROM players WHERE id = ${q(id)})`,
  `DELETE FROM players WHERE id = ${q(id)}`,
  `DELETE FROM accounts WHERE uid = ${q(uid)}`,
  `DELETE FROM email_changes WHERE uid = ${q(uid)}`,
]).join('; ');
d1(sql);
console.log(`${orphans.length} weesaccounts gewist.`);
