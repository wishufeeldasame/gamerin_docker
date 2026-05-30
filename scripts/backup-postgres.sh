#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-${HOME:?HOME is not set}/capstone}"
DOCKER_DIR="$BASE_DIR/docker"
BACKUP_DIR="$BASE_DIR/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/postgres-$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"
cd "$DOCKER_DIR"

docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$BACKUP_FILE"

echo "Created backup: $BACKUP_FILE"
