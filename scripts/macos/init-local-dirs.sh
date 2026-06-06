#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

require_macos

mkdir -p \
  "$GAMERIN_DATA_DIR/postgres" \
  "$GAMERIN_DATA_DIR/uploads" \
  "$GAMERIN_DATA_DIR/tmp" \
  "$GAMERIN_BACKUP_DIR"

chmod -R u+rwX \
  "$GAMERIN_DATA_DIR/uploads" \
  "$GAMERIN_DATA_DIR/tmp"

echo "Initialized macOS local data directories under $GAMERIN_DATA_DIR"
echo "Skipped Linux UID/GID chown. Docker Desktop handles bind mount ownership through macOS file sharing."
