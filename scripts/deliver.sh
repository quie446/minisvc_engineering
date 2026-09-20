#!/usr/bin/env bash
# One command from zero to smoke: down -> test -> image -> up -> smoke.
# Usage: scripts/deliver.sh [PORT]
set -euo pipefail

PORT="${1:-8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Same derivation as the Makefile; exported so compose build args resolve.
export VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo dev)}"
export COMMIT="${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
export BUILD_TIME="${BUILD_TIME:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

step() { printf '\n\033[36m== %s ==\033[0m\n' "$*"; }

on_error() {
  code=$?
  printf '\n\033[31mdeliver failed at step: %s (exit %d)\033[0m\n' "${STEP:-unknown}" "$code" >&2
  docker compose -f deploy/docker-compose.yml ps || true
  docker compose -f deploy/docker-compose.yml logs --tail=80 || true
  exit "$code"
}
trap on_error ERR

STEP="reset old stack"
step "reset old stack"
docker compose -f deploy/docker-compose.yml down --remove-orphans || true

STEP="test"
step "go test ./..."
go test ./... -race -count=1

STEP="image"
step "build release image"
make image

STEP="compose up"
step "start stack with docker compose"
docker compose -f deploy/docker-compose.yml up -d

STEP="smoke"
step "smoke test"
scripts/smoke.sh "$PORT" "$COMMIT"

step "deliver OK"
echo "stack is up on http://127.0.0.1:${PORT}  (stop with: make down)"
