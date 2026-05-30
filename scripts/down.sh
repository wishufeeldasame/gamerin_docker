#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-/srv/gamerin}"

cd "$BASE_DIR/docker"
docker compose down
