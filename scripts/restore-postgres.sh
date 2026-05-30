#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/postgres-backup.sql" >&2
  exit 1
fi

BASE_DIR="${GAMERIN_BASE_DIR:-${HOME:?HOME is not set}/capstone}"
BACKUP_FILE="$1"

cd "$BASE_DIR/docker"

docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"' < "$BACKUP_FILE"

echo "Restored backup: $BACKUP_FILE"
