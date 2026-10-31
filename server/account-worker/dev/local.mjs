// The account on the Mac, for a 4.0 debug build on the simulator or emulator
// (docs: server/account-worker/README.md, "Lokaal testen"):
//
//   npm run local
//
// - a stand-in for Firebase Authentication on http://localhost:9099, with the
//   Firebase emulator's paths (identitytoolkit.googleapis.com/v1/…,
//   securetoken.googleapis.com/v1/token). It signs real RS256 ID tokens with a
//   key of its own, so the Worker checks them exactly as it checks Google's;
//   the Worker gets that key set through TEST_FIREBASE_JWKS in .dev.vars;
// - the Worker itself with `wrangler dev` on http://localhost:8787 and a local D1.
//
// Nothing here talks to Firebase or Cloudflare. Users, the key and the local
// database stay in dev/.local and .wrangler (both outside git). Mails are not
// sent: the links are printed here.

import { createServer } from 'node:http';
import { createPrivateKey, createPublicKey, createSign, generateKeyPairSync, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const store = join(here, '.local');
const AUTH_PORT = 9099;
const WORKER_PORT = 8787;
const PROJECT = /FIREBASE_PROJECT_ID\s*=\s*"([^"]+)"/.exec(readFileSync(join(root, 'wrangler.toml'), 'utf8'))[1];
const KID = 'local-dev';

mkdirSync(store, { recursive: true });

// MARK: - The signing key, kept so tokens stay valid over a restart

const keyFile = join(store, 'key.pem');
if (!existsSync(keyFile)) {
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  writeFileSync(keyFile, privateKey.export({ type: 'pkcs8', format: 'pem' }));
}
const privateKey = createPrivateKey(readFileSync(keyFile));
const jwk = { ...createPublicKey(privateKey).export({ format: 'jwk' }), kid: KID, alg: 'RS256', use: 'sig' };
writeFileSync(join(root, '.dev.vars'),
  `# Written by dev/local.mjs: the local stand-in's public key, not a secret\nTEST_FIREBASE_JWKS='${JSON.stringify({ keys: [jwk] })}'\n`);

// MARK: - Users

const usersFile = join(store, 'users.json');
const users = existsSync(usersFile) ? JSON.parse(readFileSync(usersFile, 'utf8')) : {};
const saveUsers = () => writeFileSync(usersFile, JSON.stringify(users, null, 2));
const refreshTokens = {};

const b64url = (data) => Buffer.from(data).toString('base64url');

function idToken(user, provider) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', kid: KID, typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    auth_time: now,
    user_id: user.uid,
    sub: user.uid,
    iat: now,
    exp: now + 3600,
    email: user.email,
    firebase: { identities: {}, sign_in_provider: provider },
  }));
  const signer = createSign('RSA-SHA256');
  signer.update(`${header}.${claims}`);
  return `${header}.${claims}.${signer.sign(privateKey, 'base64url')}`;
}

function signedIn(user, provider) {
  const refreshToken = randomBytes(24).toString('hex');
  refreshTokens[refreshToken] = user.uid;
  return { kind: 'identitytoolkit#VerifyPasswordResponse', localId: user.uid, email: user.email,
    idToken: idToken(user, provider), refreshToken, expiresIn: '3600', registered: true };
}

/** The uid in an ID token this stand-in signed (no signature check: it is local) */
function uidOf(token) {
  try {
    return JSON.parse(Buffer.from(String(token).split('.')[1], 'base64url').toString()).sub;
  } catch {
    return null;
  }
}

const userById = (uid) => Object.values(users).find((user) => user.uid === uid);

// MARK: - Firebase's REST API, the parts the app uses

function fail(message) {
  return [400, { error: { code: 400, message, errors: [{ message, domain: 'global', reason: 'invalid' }] } }];
}

const routes = {
  'POST /identitytoolkit.googleapis.com/v1/accounts:signUp': (body) => {
    const email = String(body.email || '').trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return fail('INVALID_EMAIL');
    if (users[email]) return fail('EMAIL_EXISTS');
    if (String(body.password || '').length < 6) return fail('WEAK_PASSWORD : Password should be at least 6 characters');
    users[email] = { uid: randomBytes(14).toString('hex'), email, password: body.password, verified: false };
    saveUsers();
    return [200, signedIn(users[email], 'password')];
  },
  'POST /identitytoolkit.googleapis.com/v1/accounts:signInWithPassword': (body) => {
    const user = users[String(body.email || '').trim().toLowerCase()];
    if (!user || user.password !== body.password) return fail('INVALID_LOGIN_CREDENTIALS');
    return [200, signedIn(user, 'password')];
  },
  'POST /identitytoolkit.googleapis.com/v1/accounts:signInWithIdp': (body) => {
    // Any Apple or Google token is taken at its word here: only for trying the flow
    const params = new URLSearchParams(body.postBody || '');
    const provider = params.get('providerId') || 'apple.com';
    let claims = {};
    try {
      claims = JSON.parse(Buffer.from(String(params.get('id_token')).split('.')[1], 'base64url').toString());
    } catch {
      return fail('INVALID_IDP_RESPONSE');
    }
    const email = String(claims.email || `${claims.sub}@${provider}`).toLowerCase();
    users[email] ||= { uid: randomBytes(14).toString('hex'), email, password: null, verified: true };
    saveUsers();
    return [200, signedIn(users[email], provider)];
  },
  'POST /identitytoolkit.googleapis.com/v1/accounts:sendOobCode': (body) => {
    if (body.requestType === 'PASSWORD_RESET') {
      console.log(`[auth] mail "nieuw wachtwoord" naar ${body.email} (niet verstuurd: lokaal)`);
      return [200, { email: body.email }];
    }
    const user = userById(uidOf(body.idToken));
    if (!user) return fail('INVALID_ID_TOKEN');
    console.log(`[auth] bevestigingsmail naar ${user.email} (niet verstuurd: lokaal)`);
    return [200, { email: user.email }];
  },
  'POST /identitytoolkit.googleapis.com/v1/accounts:delete': (body) => {
    const user = userById(uidOf(body.idToken));
    if (!user) return fail('USER_NOT_FOUND');
    delete users[user.email];
    saveUsers();
    console.log(`[auth] gebruiker ${user.email} verwijderd`);
    return [200, { kind: 'identitytoolkit#DeleteAccountResponse' }];
  },
  'POST /identitytoolkit.googleapis.com/v2/accounts:revokeToken': (body) => {
    console.log(`[auth] Apple-token ingetrokken (${body.tokenType})`);
    return [200, {}];
  },
  'POST /securetoken.googleapis.com/v1/token': (body) => {
    const uid = refreshTokens[body.refresh_token];
    const user = uid && userById(uid);
    if (!user) return fail('INVALID_REFRESH_TOKEN');
    delete refreshTokens[body.refresh_token];
    const fresh = signedIn(user, 'password');
    return [200, { id_token: fresh.idToken, refresh_token: fresh.refreshToken, expires_in: '3600', user_id: uid, token_type: 'Bearer' }];
  },
};

createServer((request, response) => {
  let raw = '';
  request.on('data', (chunk) => { raw += chunk; });
  request.on('end', () => {
    const path = new URL(request.url, 'http://localhost').pathname;
    const handler = routes[`${request.method} ${path}`];
    let body = {};
    try {
      body = raw ? JSON.parse(raw) : {};
    } catch {
      body = Object.fromEntries(new URLSearchParams(raw));
    }
    const [status, answer] = handler ? handler(body) : [404, { error: { code: 404, message: 'NOT_FOUND' } }];
    console.log(`[auth] ${request.method} ${path} → ${status}`);
    response.writeHead(status, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify(answer));
  });
}).listen(AUTH_PORT, '0.0.0.0', () => console.log(`[auth] Firebase-standin op http://localhost:${AUTH_PORT}`));

// MARK: - The Worker

if (!process.argv.includes('--auth-only')) {
  const wrangler = (args, options) => spawnSync('npx', ['wrangler', ...args], { cwd: root, stdio: 'inherit', ...options });
  wrangler(['d1', 'migrations', 'apply', 'squash-account', '--local']);
  const worker = spawn('npx', ['wrangler', 'dev', '--port', String(WORKER_PORT), '--ip', '0.0.0.0'], { cwd: root, stdio: 'inherit' });
  worker.on('exit', (code) => process.exit(code ?? 0));
  process.on('SIGINT', () => worker.kill('SIGINT'));
}
