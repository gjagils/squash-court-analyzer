// Limits from the Worker's vars (wrangler.toml); the same names as the Node
// version's environment variables.

export function readConfig(env) {
  const number = (name, fallback) => {
    const value = Number(env[name]);
    return Number.isFinite(value) && value > 0 ? value : fallback;
  };
  return {
    publicUrl: String(env.PUBLIC_URL || '').replace(/\/+$/, ''),
    maxSessions: number('MAX_SESSIONS', 200),
    // A session nobody updates for this long is removed (lost phone, no network)
    idleMs: number('IDLE_MINUTES', 120) * 60 * 1000,
    // Session creations per IP per minute, and in total
    createsPerMinute: number('CREATES_PER_MINUTE', 10),
    globalCreatesPerMinute: number('GLOBAL_CREATES_PER_MINUTE', 60),
    // Viewers (open SSE streams) per session
    maxViewersPerSession: number('MAX_VIEWERS_PER_SESSION', 200),
  };
}
