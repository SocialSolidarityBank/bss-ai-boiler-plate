#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="socialsolidaritybank/bss-ai-boiler-plate"
TARGET_URL="https://github.com/${TARGET_REPO}"
TARGET_GIT="${TARGET_URL}.git"
INSTALLER_DEFAULT_GIT="https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git"
PUBLIC_RELEASE_DOCS=(
  README.md
  linux/README.md
  windows/README.md
  docs/index.html
  docs/publish-readiness.md
  CONTRIBUTING.md
  CHANGELOG.md
  SECURITY.md
)

usage() {
  printf 'Usage: scripts/11-publish-readiness.sh --check\n'
}

check_readiness() {
  local current
  current="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  local stale_status="not checked"
  local marker_status="not checked"
  local remote_status="not checked - blocked until BSS_PUBLISH_READINESS_REMOTE_CHECK=1 confirms read-only access"
  if grep -RIE 'foxion37/lazy-starter-kit|github\.com/foxion37/lazy-starter-kit' "${PUBLIC_RELEASE_DOCS[@]/#/$ROOT/}" >/dev/null 2>&1; then
    stale_status="found stale public release references"
  else
    stale_status="none"
  fi
  if grep -RIE 'bss-ai-boilerplate:\*|bss-ai-boilerplate:main' "${PUBLIC_RELEASE_DOCS[@]/#/$ROOT/}" >/dev/null 2>&1; then
    marker_status="documented"
  else
    marker_status="missing"
  fi
  if [[ "${BSS_PUBLISH_READINESS_REMOTE_CHECK:-0}" == "1" ]]; then
    if command -v gh >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
      if GH_PROMPT_DISABLED=1 timeout 8s gh repo view "$TARGET_REPO" --json nameWithOwner,url,visibility,defaultBranchRef >/dev/null 2>&1; then
        remote_status="accessible via gh repo view"
      else
        remote_status="blocked or inaccessible via gh repo view"
      fi
    elif command -v git >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
      if GIT_TERMINAL_PROMPT=0 timeout 8s git ls-remote --exit-code "$TARGET_GIT" HEAD >/dev/null 2>&1; then
        remote_status="accessible via git ls-remote"
      else
        remote_status="blocked or inaccessible via git ls-remote"
      fi
    else
      remote_status="skipped - gh/git timeout support unavailable"
    fi
  fi
  cat <<EOF
BSS AI Helper publish readiness

Target repository: ${TARGET_URL}
Target clone URL: ${TARGET_GIT}
Installer default clone URL: ${INSTALLER_DEFAULT_GIT}
Current origin: ${current:-none}
Target remote accessibility: ${remote_status}
Stale public release references: ${stale_status}
Profile marker compatibility: ${marker_status} (current marker remains bss-ai-boilerplate:*)

Read-only status:
- commit/push/create commands were not run.
- gh repo create, gh repo edit, git remote set-url, and git push are intentionally out of scope for this lane.
- If current origin is not ${TARGET_GIT}, publish remains pending and must be approved by the parent/user.
- If target remote accessibility is blocked, stop and report the requested ${TARGET_GIT} target as inaccessible before changing any other release setting.
- This check does not migrate installed profile markers.

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
