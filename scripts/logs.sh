#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-/srv/gamerin}"
SERVICE="${1:-backend}"

cd "$BASE_DIR/docker"
docker compose logs --tail=100 -f "$SERVICE"
