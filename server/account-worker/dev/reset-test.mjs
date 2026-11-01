// Empties the test Worker's database (squash-account-test), never the real one.
// The Firebase test logins stay; delete those in the app (Account verwijderen)
// or in the Firebase console. Asks before it wipes.
//
//   npm run reset-test

import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const tables = ['matches', 'open_matches', 'learned_links', 'awards', 'blocks', 'accounts', 'players', 'devices'];

const prompt = createInterface({ input: process.stdin, output: process.stdout });
const answer = await prompt.question('Alle testdata in squash-account-test wissen? Typ "wissen": ');
prompt.close();
if (answer.trim() !== 'wissen') {
  console.log('Niets gewist.');
  process.exit(0);
}
const command = tables.map((table) => `DELETE FROM ${table};`).join(' ');
const result = spawnSync('npx', ['wrangler', 'd1', 'execute', 'squash-account-test', '--env', 'test', '--remote', '--command', command],
  { cwd: root, stdio: 'inherit' });
process.exit(result.status ?? 1);
