#!/bin/bash
# The team match scenarios on two simulated phones, against the account
# Worker and the live Worker running on this Mac
# (Packages/SquashAnalyzerCore/Tests/SquashAnalyzerCoreTests/TeamScenarioTests.swift).
# Starts both Workers and the local stand-in for Firebase, runs the scenarios
# and stops what it started. Nothing touches Firebase, Cloudflare or production.
#
#   scripts/team-scenarios.sh
set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
LOGS="$(mktemp -d)"
STARTED=()

up() { [ "$(curl -s -o /dev/null -w '%{http_code}' "$1" 2>/dev/null)" != "000" ]; }

# Only what this script started: whatever listens on its ports goes
stop() {
  for port in "${STARTED[@]:-}"; do
    [ -n "$port" ] && lsof -ti "tcp:$port" 2>/dev/null | xargs kill 2>/dev/null
  done
}
trap stop EXIT

for dir in server/account-worker server/live-worker; do
  [ -d "$ROOT/$dir/node_modules" ] || (cd "$ROOT/$dir" && npm ci --silent)
done

# The account Worker (8787) with the stand-in for Firebase (9099)
if ! up http://localhost:8787/api/v1/me; then
  (cd "$ROOT/server/account-worker" && npm run local > "$LOGS/account.log" 2>&1) &
  STARTED+=(8787 9099)
fi
# The live Worker (8788); workerd has no jurisdictions, so that setting is emptied
if ! up http://localhost:8788/api/push; then
  (cd "$ROOT/server/live-worker" && npx wrangler dev --port 8788 --var LIVE_JURISDICTION: > "$LOGS/live.log" 2>&1) &
  STARTED+=(8788)
fi

for _ in $(seq 1 60); do
  if up http://localhost:8787/api/v1/me && [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8788/api/push)" = "200" ]; then break; fi
  sleep 1
done
if ! up http://localhost:8787/api/v1/me || [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8788/api/push)" != "200" ]; then
  echo "✗ The local Workers did not start; logs in $LOGS"
  exit 1
fi

echo "▸ Team match scenarios on two phones"
cd "$ROOT/Packages/SquashAnalyzerCore"
TEAM_SCENARIOS=1 swift test --filter TeamScenarioTests 2>&1 | grep -E "error:|Test Case .* (passed|failed)|Executed [0-9]+ tests" | sed -E 's#.*/Tests/SquashAnalyzerCoreTests/##'
exit "${PIPESTATUS[0]}"
