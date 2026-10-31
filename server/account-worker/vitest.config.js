import { createPublicKey, generateKeyPairSync } from 'node:crypto';
import { defineConfig } from 'vitest/config';
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-pool-workers';

// The Worker with a local D1 (the migrations applied in test/setup.js) and a
// throwaway Firebase signing key made here: the tests sign their own ID tokens,
// the Worker checks them against this key set instead of Google's.
const key = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});
const jwk = { ...createPublicKey(key.publicKey).export({ format: 'jwk' }), kid: 'test-kid', alg: 'RS256', use: 'sig' };

export default defineConfig(async () => {
  const migrations = await readD1Migrations('./migrations');
  return {
    plugins: [cloudflareTest({
      wrangler: { configPath: './wrangler.toml' },
      miniflare: {
        bindings: {
          TEST_MIGRATIONS: migrations,
          TEST_FIREBASE_JWKS: JSON.stringify({ keys: [jwk] }),
          TEST_FIREBASE_PRIVATE_KEY: key.privateKey,
          SUBMISSIONS_PER_DAY: '3',
          DEVICES_PER_HOUR: '2',
        },
      },
    })],
    test: { setupFiles: ['./test/setup.js'] },
  };
});
