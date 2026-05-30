#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p \
  "$BASE_DIR/data/postgres" \
  "$BASE_DIR/data/uploads" \
  "$BASE_DIR/data/tmp" \
  "$BASE_DIR/backups"

sudo chown -R 10001:10001 \
  "$BASE_DIR/data/uploads" \
  "$BASE_DIR/data/tmp"

echo "Initialized local data directories under $BASE_DIR/data"
