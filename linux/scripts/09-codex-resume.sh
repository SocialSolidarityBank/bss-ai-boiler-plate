#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  exec "$ROOT/scripts/09-codex-resume.sh" "$@"
fi

# shellcheck source=../../scripts/09-codex-resume.sh
source "$ROOT/scripts/09-codex-resume.sh"
