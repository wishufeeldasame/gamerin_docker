#!/usr/bin/env bash

MACOS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_GAMERIN_BASE_DIR="$(cd "$MACOS_SCRIPT_DIR/../../.." && pwd)"

GAMERIN_BASE_DIR="${GAMERIN_BASE_DIR:-$DEFAULT_GAMERIN_BASE_DIR}"
GAMERIN_DOCKER_DIR="${GAMERIN_DOCKER_DIR:-$GAMERIN_BASE_DIR/docker}"
GAMERIN_DATA_DIR="${GAMERIN_DATA_DIR:-$GAMERIN_BASE_DIR/data}"
GAMERIN_BACKUP_DIR="${GAMERIN_BACKUP_DIR:-$GAMERIN_BASE_DIR/backups}"

require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script is intended for macOS. Use scripts/*.sh on Linux." >&2
    exit 1
  fi
}

require_docker_cli() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker CLI was not found. Install Docker Desktop for macOS first." >&2
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose was not found. Update Docker Desktop for macOS first." >&2
    exit 1
  fi
}

require_docker_daemon() {
  require_docker_cli

  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is unavailable. Start Docker Desktop and try again." >&2
    exit 1
  fi
}

cd_docker_dir() {
  if [ ! -d "$GAMERIN_DOCKER_DIR" ]; then
    echo "Docker directory not found: $GAMERIN_DOCKER_DIR" >&2
    exit 1
  fi

  cd "$GAMERIN_DOCKER_DIR"
}

require_env_file() {
  if [ ! -f "$GAMERIN_DOCKER_DIR/.env" ]; then
    echo "Missing $GAMERIN_DOCKER_DIR/.env. Copy .env.example to .env and fill real values first." >&2
    exit 1
  fi
}
