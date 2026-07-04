#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="socialsolidaritybank/bss-ai-helper"
TARGET_URL="https://github.com/${TARGET_REPO}"
TARGET_GIT="${TARGET_URL}.git"

usage() {
  printf 'Usage: scripts/11-publish-readiness.sh --check\n'
}

check_readiness() {
  local current
  current="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  cat <<EOF
BSS AI Helper publish readiness

Target repository: ${TARGET_URL}
Target clone URL: ${TARGET_GIT}
Current origin: ${current:-none}

Read-only status:
- commit/push/create commands were not run.
- gh repo create, gh repo edit, git remote set-url, and git push are intentionally out of scope for this lane.
- If current origin is not ${TARGET_GIT}, publish remains pending and must be approved by the parent/user.

Prepared commands for the approved publish step:
1. gh repo view ${TARGET_REPO} --json nameWithOwner,url,visibility,defaultBranchRef
2. git remote set-url origin ${TARGET_GIT}
3. git push -u origin main

Do not run the publish commands until implementation QA is green and the parent/user explicitly asks.
EOF
  if [[ "$current" != "$TARGET_GIT" ]]; then
    printf '\nStatus: pending - origin was not changed.\n'
  else
    printf '\nStatus: target remote already configured.\n'
  fi
}

case "${1:-}" in
  --check)
    check_readiness
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
