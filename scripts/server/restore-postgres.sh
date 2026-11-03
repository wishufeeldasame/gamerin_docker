#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 /path/to/postgres-backup.sql [--yes]" >&2
  exit 1
fi

BASE_DIR="${GAMERIN_BASE_DIR:-/srv/capstone}"
BACKUP_FILE="$1"
ASSUME_YES="${2:-}"

if [ "$ASSUME_YES" != "" ] && [ "$ASSUME_YES" != "--yes" ]; then
  echo "Usage: $0 /path/to/postgres-backup.sql [--yes]" >&2
  exit 1
fi

if [ ! -r "$BACKUP_FILE" ]; then
  echo "Backup file is not readable: $BACKUP_FILE" >&2
  exit 1
fi

BACKUP_DIR="$(cd "$(dirname "$BACKUP_FILE")" && pwd)"
BACKUP_FILE="$BACKUP_DIR/$(basename "$BACKUP_FILE")"

cat <<EOF
This will restore SQL into the current PostgreSQL database.

Backup file:
  $BACKUP_FILE

Take a fresh backup before continuing if the current DB must be preserved.

EOF

if [ "$ASSUME_YES" != "--yes" ]; then
  read -r -p "Restore this backup? Type y to continue: " CONFIRM
  if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 0
  fi
fi

cd "$BASE_DIR/docker"

docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 --single-transaction -U "$POSTGRES_USER" "$POSTGRES_DB"' < "$BACKUP_FILE"

echo "Restored backup: $BACKUP_FILE"
