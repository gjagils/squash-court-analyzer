import { defineConfig } from 'vitest/config';
import { cloudflareTest } from '@cloudflare/vitest-pool-workers';

// Two projects against the same Worker: the API with the real limits, and
// the limits themselves with small numbers the tests can reach. The limiter
// counts across tests, so the limit scenarios sit in one sequence.
const worker = (bindings) => cloudflareTest({ wrangler: { configPath: './wrangler.toml' }, miniflare: { bindings } });

export default defineConfig({
  test: {
    projects: [
      {
        plugins: [worker({ PUBLIC_URL: '' })],
        test: { name: 'api', include: ['test/api.test.js'] },
      },
      {
        plugins: [worker({
          PUBLIC_URL: '', IDLE_MINUTES: '60', MAX_SESSIONS: '3', CREATES_PER_MINUTE: '2',
          GLOBAL_CREATES_PER_MINUTE: '6', MAX_VIEWERS_PER_SESSION: '1',
        })],
        test: { name: 'limits', include: ['test/limits.test.js'] },
      },
    ],
  },
});
