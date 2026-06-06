#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

require_macos
require_docker_daemon

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$GAMERIN_BACKUP_DIR/postgres-$TIMESTAMP.sql"

mkdir -p "$GAMERIN_BACKUP_DIR"
TMP_BACKUP_FILE="$(mktemp "$GAMERIN_BACKUP_DIR/.postgres-$TIMESTAMP.XXXXXX.sql")"

cleanup_backup_tmp() {
  if [ -f "$TMP_BACKUP_FILE" ]; then
    rm -f "$TMP_BACKUP_FILE"
  fi
}

trap cleanup_backup_tmp EXIT

cd_docker_dir

docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$TMP_BACKUP_FILE"
mv "$TMP_BACKUP_FILE" "$BACKUP_FILE"
trap - EXIT

echo "Created backup: $BACKUP_FILE"
