#!/usr/bin/env bash
set -euo pipefail

# OCI에서 연결과 ext4 포맷을 완료한 장치만 사용한다. 이 스크립트는 포맷하지 않는다.
DEVICE="${1:?Usage: sudo $0 /dev/oracleoci/oraclevdb [/srv/capstone/data]}"
MOUNT_DIR="${2:-${GAMERIN_BASE_DIR:-/srv/capstone}/data}"

fail() { echo "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail "Run this script with sudo."
[[ -b "$DEVICE" ]] || fail "Not a block device: $DEVICE"
[[ "$MOUNT_DIR" = /* && "$MOUNT_DIR" != / && "$MOUNT_DIR" != *[[:space:]]* ]] || fail "Use an absolute mount path without whitespace."
[[ "$(realpath -m "$MOUNT_DIR")" = "$MOUNT_DIR" ]] || fail "Use a canonical mount path without symlinks or trailing slashes."
[[ "$(blkid -s TYPE -o value "$DEVICE")" = ext4 ]] || fail "Device must already contain an ext4 filesystem."
UUID="$(blkid -s UUID -o value "$DEVICE")"
[[ "$UUID" =~ ^[[:xdigit:]-]+$ ]] || fail "Missing or invalid filesystem UUID."

if mountpoint -q "$MOUNT_DIR"; then
  [[ "$(findmnt -n -o UUID --mountpoint "$MOUNT_DIR")" = "$UUID" ]] || fail "Another filesystem is mounted at $MOUNT_DIR."
else
  if findmnt -rn -S "UUID=$UUID" >/dev/null; then
    fail "Device is already mounted elsewhere."
  fi
  [[ ! -e "$MOUNT_DIR" || -d "$MOUNT_DIR" ]] || fail "Mount path is not a directory."
  command -v docker >/dev/null || fail "Docker is required to check running containers."
  RUNNING="$(docker ps -q)"
  [[ -z "$RUNNING" ]] || fail "Stop all running containers before mounting storage."
  if [[ -d "$MOUNT_DIR" && -n "$(find "$MOUNT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Existing files under $MOUNT_DIR will be hidden, not copied or deleted."
    echo "Their boot disk space will remain occupied."
  fi
fi

ENTRY="UUID=$UUID $MOUNT_DIR ext4 defaults,_netdev 0 2"
EXISTING="$(awk -v source="UUID=$UUID" -v target="$MOUNT_DIR" '$0 !~ /^[[:space:]]*#/ && ($1 == source || $2 == target)' /etc/fstab)"
[[ -z "$EXISTING" || "$EXISTING" = "$ENTRY" ]] || fail "Conflicting fstab entry; review /etc/fstab manually."
DROPIN=/etc/systemd/system/docker.service.d/gamerin-storage.conf
CONTENT="[Unit]
RequiresMountsFor=$MOUNT_DIR
After=remote-fs.target"
[[ ! -e "$DROPIN" || "$(cat "$DROPIN")" = "$CONTENT" ]] || fail "Conflicting Docker storage dependency: $DROPIN"

mkdir -p "$MOUNT_DIR" "$(dirname "$DROPIN")"
if [[ -z "$EXISTING" ]]; then
  cp -a /etc/fstab "/etc/fstab.gamerin-$(date +%Y%m%d-%H%M%S)-$$.bak"
  printf '\n%s\n' "$ENTRY" >> /etc/fstab
fi
# 마운트 실패 시 Docker가 부트 디스크에 빈 DB를 만드는 것을 막는다.
printf '%s\n' "$CONTENT" > "$DROPIN"
systemctl daemon-reload
mountpoint -q "$MOUNT_DIR" || mount "$MOUNT_DIR"
[[ "$(findmnt -n -o UUID --mountpoint "$MOUNT_DIR")" = "$UUID" ]] || fail "Mounted UUID does not match."
findmnt --mountpoint "$MOUNT_DIR"
echo "Mounted $DEVICE at $MOUNT_DIR. Docker was not restarted."
