#!/usr/bin/env bash
set -euo pipefail
# "works on my machine" — no version stamping
mkdir -p bin
go test ./...
go build -o bin/minisvc ./cmd/minisvc
echo "built bin/minisvc"
