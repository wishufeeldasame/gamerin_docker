#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-${HOME:?HOME is not set}/capstone}"
POSTGRES_DATA_DIR="$BASE_DIR/data/postgres"

if [ -z "$BASE_DIR" ] || [ "$BASE_DIR" = "/" ] || [ ! -d "$BASE_DIR" ]; then
  echo "Refusing to reset DB because GAMERIN_BASE_DIR is unsafe: $BASE_DIR" >&2
  exit 1
fi

BASE_DIR_ABS="$(cd "$BASE_DIR" && pwd)"
EXPECTED_POSTGRES_DATA_DIR="$BASE_DIR_ABS/data/postgres"
DOCKER_DIR="$BASE_DIR_ABS/docker"

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

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI was not found. Cannot verify PostgreSQL is stopped." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is unavailable. Cannot verify PostgreSQL is stopped." >&2
  exit 1
fi

if [ ! -d "$DOCKER_DIR" ]; then
  echo "Docker directory not found: $DOCKER_DIR" >&2
  exit 1
fi

cd "$DOCKER_DIR"

if ! RUNNING_SERVICES="$(docker compose ps --services --filter status=running 2>/dev/null)"; then
  echo "Could not verify PostgreSQL container status. Refusing to delete database files." >&2
  exit 1
fi

if printf '%s\n' "$RUNNING_SERVICES" | grep -qx "postgres"; then
  echo "PostgreSQL container is still running. Run scripts/down.sh first." >&2
  exit 1
fi

cat <<EOF
This will delete the PostgreSQL database files for this server.

Target database data:
  $POSTGRES_DATA_DIR

The current database directory will be deleted.

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
  sudo rm -rf -- "$POSTGRES_DATA_DIR"
else
  echo "No existing PostgreSQL data directory found."
fi

echo "Database files deleted."
