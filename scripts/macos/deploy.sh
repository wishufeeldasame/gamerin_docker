#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

require_macos
require_docker_daemon
cd_docker_dir
require_env_file

docker compose --env-file .env build backend frontend
docker compose --env-file .env up -d
docker compose --env-file .env ps
