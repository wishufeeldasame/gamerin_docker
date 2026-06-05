#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-${HOME:?HOME is not set}/capstone}"
DOCKER_DIR="$BASE_DIR/docker"

cd "$DOCKER_DIR"

if [ ! -f .env ]; then
  echo "Missing $DOCKER_DIR/.env. Copy .env.example to .env and fill real values first." >&2
  exit 1
fi

docker compose --env-file .env build backend frontend
docker compose --env-file .env up -d
docker compose --env-file .env exec -T nginx nginx -s reload
docker compose --env-file .env ps
