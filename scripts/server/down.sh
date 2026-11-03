#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-/srv/capstone}"

cd "$BASE_DIR/docker"
docker compose down
