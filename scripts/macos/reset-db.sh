#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

require_macos

POSTGRES_DATA_DIR="$GAMERIN_DATA_DIR/postgres"

if [ -z "$GAMERIN_BASE_DIR" ] || [ "$GAMERIN_BASE_DIR" = "/" ] || [ ! -d "$GAMERIN_BASE_DIR" ]; then
  echo "Refusing to reset DB because GAMERIN_BASE_DIR is unsafe: $GAMERIN_BASE_DIR" >&2
  exit 1
fi

BASE_DIR_ABS="$(cd "$GAMERIN_BASE_DIR" && pwd)"
EXPECTED_POSTGRES_DATA_DIR="$BASE_DIR_ABS/data/postgres"

if [ -d "$POSTGRES_DATA_DIR" ]; then
  POSTGRES_PARENT_DIR="$(cd "$(dirname "$POSTGRES_DATA_DIR")" && pwd)"
  POSTGRES_DATA_DIR="$POSTGRES_PARENT_DIR/$(basename "$POSTGRES_DATA_DIR")"
else
  POSTGRES_DATA_DIR="$EXPECTED_POSTGRES_DATA_DIR"
fi

if [ "$POSTGRES_DATA_DIR" != "$EXPECTED_POSTGRES_DATA_DIR" ]; then
  echo "Refusing to reset DB outside the expected data directory." >&2
  echo "Expected: $EXPECTED_POSTGRES_DATA_DIR" >&2
  echo "Target:   $POSTGRES_DATA_DIR" >&2
  exit 1
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  cd_docker_dir
  if docker compose ps --services --filter status=running | grep -qx "postgres"; then
    echo "PostgreSQL container is still running. Run scripts/macos/down.sh first." >&2
    exit 1
  fi
fi

cat <<EOF
This will delete the PostgreSQL database files for this macOS workspace.

Target database data:
  $POSTGRES_DATA_DIR

Stop the postgres container before continuing.

EOF

if [ "${1:-}" != "--yes" ]; then
  read -r -p "Delete database files? Type y to continue: " CONFIRM
  if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 0
  fi
fi

if [ -d "$POSTGRES_DATA_DIR" ]; then
  echo "Deleting old PostgreSQL data directory: $POSTGRES_DATA_DIR"
  rm -rf -- "$POSTGRES_DATA_DIR"
else
  echo "No existing PostgreSQL data directory found."
fi

echo "Database files deleted."
