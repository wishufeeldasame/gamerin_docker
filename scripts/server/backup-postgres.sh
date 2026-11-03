#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-/srv/capstone}"
DOCKER_DIR="$BASE_DIR/docker"
BACKUP_DIR="$BASE_DIR/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/postgres-$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"
TMP_BACKUP_FILE="$(mktemp "$BACKUP_DIR/.postgres-$TIMESTAMP.XXXXXX.sql")"

cleanup_backup_tmp() {
  if [ -f "$TMP_BACKUP_FILE" ]; then
    rm -f "$TMP_BACKUP_FILE"
  fi
}

trap cleanup_backup_tmp EXIT

cd "$DOCKER_DIR"

docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$TMP_BACKUP_FILE"
mv "$TMP_BACKUP_FILE" "$BACKUP_FILE"
trap - EXIT

echo "Created backup: $BACKUP_FILE"
