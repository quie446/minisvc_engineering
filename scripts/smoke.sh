#!/usr/bin/env bash
# Smoke test against the running compose stack.
# Any failed check exits non-zero — this script must never go "false green".
# Usage: scripts/smoke.sh [PORT] [EXPECTED_COMMIT]
set -euo pipefail

PORT="${1:-8080}"
EXPECTED_COMMIT="${2:-}"
COMPOSE_FILE="deploy/docker-compose.yml"
BASE="http://127.0.0.1:${PORT}"

log() { printf '\033[36m[smoke]\033[0m %s\n' "$*"; }
fail() {
  printf '\033[31m[smoke] FAIL: %s\033[0m\n' "$*" >&2
  docker compose -f "$COMPOSE_FILE" ps || true
  docker compose -f "$COMPOSE_FILE" logs --tail=50 || true
  exit 1
}

# 1) Container-level health must become healthy (or fail/exit → abort early).
deadline=$(( $(date +%s) + 60 ))
while :; do
  state="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' minisvc 2>/dev/null || echo missing)"
  case "$state" in
    healthy) log "container healthy"; break ;;
    missing|exited|dead) fail "container is '$state'" ;;
  esac
  [ "$(date +%s)" -ge "$deadline" ] && fail "health did not become healthy (last state: $state)"
  sleep 2
done

# 2) Host-side HTTP checks with their own retry window.
curl_retry() { # <path>
  local path="$1"
  curl --silent --show-error --fail --retry 10 --retry-delay 1 --retry-connrefused \
    --max-time 5 "${BASE}${path}"
}

health_body="$(curl_retry /healthz)" || fail "GET /healthz failed"
[[ "$health_body" == *"ok"* ]] || fail "/healthz unexpected body: $health_body"
log "/healthz ok"

ready_body="$(curl_retry /readyz)" || fail "GET /readyz failed (migrations not applied?)"
[[ "$ready_body" == *"ready"* ]] || fail "/readyz unexpected body: $ready_body"
log "/readyz ok"

version_body="$(curl_retry /version)" || fail "GET /version failed"
echo "$version_body"
grep -Eq '"version"[[:space:]]*:[[:space:]]*"[^"]+"' <<<"$version_body" \
  || fail "version metadata missing in: $version_body"
if [ -n "$EXPECTED_COMMIT" ]; then
  grep -Eq "\"commit\"[[:space:]]*:[[:space:]]*\"${EXPECTED_COMMIT}" <<<"$version_body" \
    || fail "commit mismatch: expected ${EXPECTED_COMMIT}, got: $version_body"
fi
log "/version carries stamped metadata"

ping_body="$(curl_retry /v1/ping)" || fail "GET /v1/ping failed"
grep -Eq '"pong"[[:space:]]*:[[:space:]]*true' <<<"$ping_body" \
  || fail "/v1/ping unexpected body: $ping_body"
log "/v1/ping ok"

log "all smoke checks passed"
