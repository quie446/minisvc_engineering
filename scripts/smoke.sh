#!/usr/bin/env bash
# Smoke test against a running minisvc. Exits non-zero on any failure.
#
# Env overrides:
#   BASE_URL          default http://127.0.0.1:8080
#   CONFIG_FILE       config the service runs with (to derive health_path)
#   EXPECTED_VERSION  if set, /version must report this version
#   EXPECTED_COMMIT   if set (and != unknown), /version must report this commit
#   TIMEOUT_SECONDS   total wait budget, default 30
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
CONFIG_FILE="${CONFIG_FILE:-deploy/app.prod.yaml}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

health_path="/healthz"
if [ -f "$CONFIG_FILE" ]; then
  cfg_path=$(grep -E '^health_path:' "$CONFIG_FILE" | head -1 \
    | sed -E 's/^health_path:[[:space:]]*//' | tr -d "\"'")
  [ -n "$cfg_path" ] && health_path="$cfg_path"
fi

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
wait_ok() { # url
  until curl -fsS "$1" >/dev/null 2>&1; do
    [ "$(date +%s)" -lt "$deadline" ] || return 1
    sleep 1
  done
}

echo "smoke: waiting for ${BASE_URL}${health_path}"
wait_ok "${BASE_URL}${health_path}" \
  || fail "health check ${health_path} did not pass within ${TIMEOUT_SECONDS}s"

wait_ok "${BASE_URL}/readyz" || fail "/readyz not ready"

version_body=$(curl -fsS "${BASE_URL}/version") || fail "/version unreachable"
echo "smoke: /version -> ${version_body}"
echo "$version_body" | grep -q '"version":"[^"]\+"' || fail "/version reports empty version"
echo "$version_body" | grep -q '"commit":"[^"]\+"'  || fail "/version reports empty commit"
if [ -n "$EXPECTED_VERSION" ]; then
  echo "$version_body" | grep -q "\"version\":\"${EXPECTED_VERSION}\"" \
    || fail "/version version mismatch, want ${EXPECTED_VERSION}"
fi
if [ -n "$EXPECTED_COMMIT" ] && [ "$EXPECTED_COMMIT" != "unknown" ]; then
  echo "$version_body" | grep -q "\"commit\":\"${EXPECTED_COMMIT}\"" \
    || fail "/version commit mismatch, want ${EXPECTED_COMMIT}"
fi

curl -fsS "${BASE_URL}/v1/ping" | grep -q '"pong":true' || fail "/v1/ping unexpected response"

echo "SMOKE OK"
