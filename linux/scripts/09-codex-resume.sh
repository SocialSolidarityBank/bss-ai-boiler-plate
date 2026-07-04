#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BSS_AI_HELPER_INSTALLER_RELATIVE="${BSS_AI_HELPER_INSTALLER_RELATIVE:-linux/install.sh}" \
  exec "$ROOT/scripts/09-codex-resume.sh" "$@"
