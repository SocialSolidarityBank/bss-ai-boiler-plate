#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

run_case() {
  local kind="$1" choice="$2" helper_home evidence
  helper_home="$(make_temp_home)"
  evidence="$EVIDENCE_DIR/g005-primary-${kind}-failure-green.txt"
  {
    printf 'Scenario: primary %s installer failure must not be recorded as success\n' "$kind"
    printf 'Helper home: %s\n\n' "$helper_home"
    BSS_AI_HELPER_HOME="$helper_home" ROOT="$ROOT" AI_CHOICE="$choice" AI_KIND="$kind" bash <<'BASH'
set -euo pipefail
DRY_RUN=0
ASSUME_YES=0
source "$ROOT/lib/common.sh"
source "$ROOT/lib/state.sh"
source "$ROOT/lib/wizard-common.sh"
source "$ROOT/lib/wizard-ai.sh"
load_brew() { :; }
load_mise() { :; }
have() {
  case "$AI_KIND:$1" in
    codex:npm|codex:codex|claude:claude) return 1 ;;
    *) command -v "$1" >/dev/null 2>&1 ;;
  esac
}
curl() {
  if [[ "$AI_KIND" == "claude" ]]; then
    printf 'fake curl failure\n' >&2
    return 22
  fi
  command curl "$@"
}
printf '%s\n' "$AI_CHOICE" | wizard_step_ai_tools macos
printf '\nState JSON:\n'
cat "$BSS_AI_HELPER_HOME/state.json"
BASH
  } > "$evidence" 2>&1

  assert_contains "$evidence" 'AI 도구 설치가 끝나지 않았습니다'
  assert_contains "$evidence" '"ai-tools"'
  assert_contains "$evidence" '"status": "skipped"'
  assert_not_contains "$evidence" '"ai-tools"[[:space:][:print:]]*"status": "complete"'
  case "$kind" in
    codex)
      assert_contains "$evidence" 'npm not found'
      assert_contains "$evidence" '"name": "Codex CLI"'
      ;;
    claude)
      assert_contains "$evidence" 'Claude Code install did not complete'
      assert_contains "$evidence" '"name": "Claude Code"'
      ;;
  esac
  assert_contains "$evidence" '"status": "failed"'
  note "PASS G005-PRIMARY-$(printf '%s' "$kind" | tr '[:lower:]' '[:upper:]')-FAILURE $evidence"
}

run_case codex 1
run_case claude 2
