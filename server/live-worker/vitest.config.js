import { generateKeyPairSync } from 'node:crypto';
import { defineConfig } from 'vitest/config';
import { cloudflareTest } from '@cloudflare/vitest-pool-workers';

// Three projects against the same Worker: the API with the real limits (and
// no push secrets), the limits themselves with small numbers the tests can
// reach, and the lock screen pushes with throwaway keys made here (nothing
// real is ever in the repo). The limiter counts across tests, so the limit
// scenarios sit in one sequence.
const worker = (bindings) => cloudflareTest({ wrangler: { configPath: './wrangler.toml' }, miniflare: { bindings } });

const pem = { type: 'pkcs8', format: 'pem' };
const publicPem = { type: 'spki', format: 'pem' };
const apnsKey = generateKeyPairSync('ec', { namedCurve: 'P-256', privateKeyEncoding: pem, publicKeyEncoding: publicPem });
const fcmKey = generateKeyPairSync('rsa', { modulusLength: 2048, privateKeyEncoding: pem, publicKeyEncoding: publicPem });

export default defineConfig({
  test: {
    projects: [
      {
        plugins: [worker({ PUBLIC_URL: '', LIVE_JURISDICTION: '' })],
        test: { name: 'api', include: ['test/api.test.js', 'test/team.test.js'] },
      },
      {
        plugins: [worker({
          PUBLIC_URL: '', LIVE_JURISDICTION: '', IDLE_MINUTES: '60', MAX_SESSIONS: '3', CREATES_PER_MINUTE: '2',
          GLOBAL_CREATES_PER_MINUTE: '6', MAX_VIEWERS_PER_SESSION: '1',
        })],
        test: { name: 'limits', include: ['test/limits.test.js'] },
      },
      {
        plugins: [worker({
          PUBLIC_URL: '', LIVE_JURISDICTION: '', MAX_FOLLOWERS_PER_SESSION: '3',
          APNS_KEY: apnsKey.privateKey, APNS_KEY_ID: 'TESTKEY123', APNS_TEAM_ID: 'TEAM456789',
          FCM_SERVICE_ACCOUNT: JSON.stringify({
            type: 'service_account', project_id: 'squash-test', client_email: 'push@squash-test.iam.gserviceaccount.com',
            private_key: fcmKey.privateKey,
          }),
          TEST_APNS_PUBLIC_KEY: apnsKey.publicKey, TEST_FCM_PUBLIC_KEY: fcmKey.publicKey,
        })],
        test: { name: 'push', include: ['test/push.test.js', 'test/team-push.test.js'] },
      },
    ],
  },
});
