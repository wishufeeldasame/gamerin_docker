#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${GAMERIN_BASE_DIR:-${HOME:?HOME is not set}/capstone}"
APP_UID="${GAMERIN_APP_UID:-10001}"
APP_GID="${GAMERIN_APP_GID:-10001}"

if [ -z "$BASE_DIR" ] || [ "$BASE_DIR" = "/" ]; then
  echo "Refusing to initialize directories because GAMERIN_BASE_DIR is unsafe: $BASE_DIR" >&2
  exit 1
fi

case "$BASE_DIR" in
  /*) ;;
  *)
    echo "GAMERIN_BASE_DIR must be an absolute path: $BASE_DIR" >&2
    exit 1
    ;;
esac

mkdir -p \
  "$BASE_DIR/backend" \
  "$BASE_DIR/frontend" \
  "$BASE_DIR/docker" \
  "$BASE_DIR/data/postgres" \
  "$BASE_DIR/data/uploads" \
  "$BASE_DIR/data/tmp" \
  "$BASE_DIR/backups"

sudo chown -R "$APP_UID:$APP_GID" \
  "$BASE_DIR/data/uploads" \
  "$BASE_DIR/data/tmp"

echo "Initialized directories under $BASE_DIR"
echo "Uploads/tmp owner: $APP_UID:$APP_GID"
