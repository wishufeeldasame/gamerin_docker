#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-${HOME:?HOME is not set}/capstone}"
POSTGRES_DATA_DIR="$BASE_DIR/data/postgres"

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
