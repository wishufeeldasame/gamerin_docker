#!/usr/bin/env bash
set -euo pipefail

# 기존 init-server-dirs.sh의 블록 스토리지용 버전. 데이터 복사·백업은 하지 않는다.
BASE_DIR="${GAMERIN_BASE_DIR:-/srv/capstone}"
APP_UID="${GAMERIN_APP_UID:-10001}"
APP_GID="${GAMERIN_APP_GID:-10001}"
DATA="$BASE_DIR/data"

fail() { echo "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail "Run this script with sudo."
[[ "$BASE_DIR" = /* && "$BASE_DIR" != / && "$BASE_DIR" != *[[:space:]]* ]] || fail "Use an absolute base path without whitespace."
[[ "$(realpath -m "$BASE_DIR")" = "$BASE_DIR" ]] || fail "Use a canonical base path without symlinks or trailing slashes."
[[ "$APP_UID" =~ ^[0-9]+$ && "$APP_GID" =~ ^[0-9]+$ ]] || fail "App UID/GID must be numeric."
# 마운트 누락 시 부트 디스크에 DB를 생성하지 않도록 먼저 확인한다.
mountpoint -q "$DATA" || fail "Block storage must be mounted at $DATA first."
[[ "$(findmnt -n -o FSTYPE --mountpoint "$DATA")" = ext4 ]] || fail "Mounted storage must use ext4."
RUNNING="$(docker ps -q)"
[[ -z "$RUNNING" ]] || fail "Stop all running containers before initializing directories."
for name in postgres uploads tmp; do
  [[ ! -L "$DATA/$name" ]] || fail "Data directory must not be a symlink: $DATA/$name"
done

mkdir -p \
  "$BASE_DIR/backend" \
  "$BASE_DIR/frontend" \
  "$BASE_DIR/docker" \
  "$DATA/postgres" \
  "$DATA/uploads" \
  "$DATA/tmp" \
  "$BASE_DIR/backups"

chown -R "$APP_UID:$APP_GID" "$DATA/uploads" "$DATA/tmp"
echo "Initialized directories under $BASE_DIR; data uses mounted block storage."
echo "Uploads/tmp owner: $APP_UID:$APP_GID"
echo "No existing data was copied or backed up. Backups directory remains on the boot disk."
