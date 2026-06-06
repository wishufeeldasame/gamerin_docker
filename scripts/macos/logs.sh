#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

require_macos
require_docker_daemon
cd_docker_dir

SERVICE="${1:-backend}"
docker compose logs --tail=100 -f "$SERVICE"
