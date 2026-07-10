#!/usr/bin/env bash
set -euo pipefail

qa_source() {
  local path="$1"
  source "$path"
}

qa_source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MODE="${1:---regression}"
TRANSCRIPT="$EVIDENCE_DIR/task-1-bash-beginner-approval-gate.txt"
BASELINE_TRANSCRIPT="$EVIDENCE_DIR/task-1-bash-baseline-current-early-execution.txt"
ADVERSARIAL_TRANSCRIPT="$EVIDENCE_DIR/task-1-bash-adversarial-probes.txt"
STATE_CONTRACT_TRANSCRIPT="$EVIDENCE_DIR/task-2-beginner-standard-scenario-alignment.txt"
STANDARD_TRANSCRIPT="$EVIDENCE_DIR/task-5-beginner-standard-scenario-alignment.txt"

first_line() {
  local path="$1" pattern="$2"
  awk -v pattern="$pattern" 'index($0, pattern) { print NR; exit }' "$path"
}

qa_git() {
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" "$@"
  elif command -v git.exe >/dev/null 2>&1; then
    (cd "$ROOT" && git.exe "$@")
  else
    git -C "$ROOT" "$@"
  fi
}

assert_line_order() {
  local before_name="$1" before="$2" after_name="$3" after="$4"
  [[ -n "$before" ]] || fail "missing $before_name line"
  [[ -n "$after" ]] || fail "missing $after_name line"
  (( before < after )) || fail "$before_name line $before must come before $after_name line $after"
}

run_scenario() {
  local out="$1" input_text="$2" stale_state="${3:-0}" misleading="${4:-0}"
  local helper_home input_file stale_before stale_after
  helper_home="$(make_temp_home)"
  input_file="$(mktemp "${TMPDIR:-/tmp}/bss-helper-qa-input.XXXXXX")"
  printf '%s' "$input_text" > "$input_file"
  if [[ "$stale_state" == "1" ]]; then
    mkdir -p "$helper_home"
    printf '{ stale state\n' > "$helper_home/state.json"
    stale_before="$(tr '\n' ' ' < "$helper_home/state.json")"
  fi

  set +e
  AI_BOILER_PLATE_HOME="$helper_home" \
  BSS_AI_HELPER_HOME="$helper_home" \
  QA_INPUT_FILE="$input_file" \
  QA_MISLEADING_SUCCESS="$misleading" \
  ROOT="$ROOT" \
  bash <<'BASH' > "$out" 2>&1
set -euo pipefail
DRY_RUN=1
ASSUME_YES=0
qa_source() {
  local path="$1"
  source "$path"
}

qa_source "$ROOT/scripts/lib.sh"
qa_source "$ROOT/lib/wizard.sh"

is_linux() { return 0; }
is_macos() { return 1; }
state_set_step_status() { :; }
state_append_history() { :; }
state_record_addon() { :; }
show_status() { printf 'QA_STATUS_VIEW\n'; }

_wizard_read() {
  local prompt="$1" def="${2:-}" ans
  if [[ -s "$QA_INPUT_FILE" ]]; then
    ans="$(sed -n '1p' "$QA_INPUT_FILE")"
    sed '1d' "$QA_INPUT_FILE" > "$QA_INPUT_FILE.next"
    mv "$QA_INPUT_FILE.next" "$QA_INPUT_FILE"
  else
    ans="$def"
  fi
  printf 'QA_INPUT: %s\n' "$ans" >&2
  printf '%s\n' "${ans:-$def}"
}

_wizard_run_step() {
  local id="$1"
  printf 'QA_EXECUTE_MARKER bash:installer:%s\n' "$id"
}

wizard_step_github() {
  local choice
  step "2단계 GitHub 연결"
  choice="$(_wizard_choice '선택:' 3)"
  if [[ "$QA_MISLEADING_SUCCESS" == "1" ]]; then
    printf 'QA_MISLEADING_SUCCESS_OUTPUT bash:github-present\n'
  fi
  if [[ "$choice" == "1" ]]; then
    printf 'QA_EXECUTE_MARKER bash:github\n'
  fi
}

wizard_step_ai_tools() {
  local choice
  step "3단계 AI CLI 도구 선택"
  choice="$(_wizard_choice '선택:' 4)"
  if [[ "$choice" != "4" ]]; then
    printf 'QA_EXECUTE_MARKER bash:ai-tools:%s\n' "$choice"
  fi
}

_install_addon() {
  local id="$1"
  printf 'QA_EXECUTE_MARKER bash:addon:%s\n' "$id"
  ADDON_LAST_STATUS=complete
  return 0
}

if [[ "$QA_MISLEADING_SUCCESS" == "1" ]]; then
  printf 'QA_MISLEADING_SUCCESS_OUTPUT bash:success-like-text-before-plan\n'
fi
run_wizard linux
BASH
  local code=$?
  set -e
  if [[ "$stale_state" == "1" ]]; then
    if [[ -f "$helper_home/state.json" ]]; then
      stale_after="$(tr '\n' ' ' < "$helper_home/state.json")"
    else
      stale_after="MISSING"
    fi
    {
      printf 'STALE_STATE_PROBE=malformed-state-preserved\n'
      printf 'STALE_STATE_BEFORE=%s\n' "$stale_before"
      printf 'STALE_STATE_AFTER=%s\n' "$stale_after"
      if [[ "$stale_before" == "$stale_after" ]]; then
        printf 'STALE_STATE_PRESERVED=yes\n'
      else
        printf 'STALE_STATE_PRESERVED=no\n'
      fi
    } >> "$out"
  fi
  rm -rf "$helper_home"
  rm -f "$input_file"
  {
    printf '\nCleanup receipt: removed helper_home=%s\n' "$helper_home"
    printf 'Cleanup receipt: removed input_file=%s\n' "$input_file"
    printf 'Scenario exit code: %s\n' "$code"
  } >> "$out"
  return "$code"
}

assert_regression_contract() {
  local out="$1" plan approval marker
  assert_contains "$out" 'Final Installation Plan'
  plan="$(first_line "$out" 'Final Installation Plan')"
  approval="$(first_line "$out" 'QA_INPUT: 승인')"
  if [[ -z "$approval" ]]; then
    approval="$(first_line "$out" 'QA_INPUT: 진행')"
  fi
  marker="$(first_line "$out" 'QA_EXECUTE_MARKER')"
  assert_line_order "Final Installation Plan" "$plan" "approval input" "$approval"
  assert_line_order "approval input" "$approval" "first execution marker" "$marker"
}

assert_baseline_contract() {
  local out="$1" plan marker
  assert_contains "$out" 'Final Installation Plan'
  marker="$(first_line "$out" 'QA_EXECUTE_MARKER')"
  plan="$(first_line "$out" 'Final Installation Plan')"
  assert_line_order "current first execution marker" "$marker" "current Final Installation Plan" "$plan"
  assert_not_contains "$out" 'QA_INPUT: 승인'
}

assert_stale_state_contract() {
  local out="$1"
  assert_contains "$out" 'QA_STATUS_VIEW'
  assert_contains "$out" 'STALE_STATE_PROBE=malformed-state-preserved'
  assert_contains "$out" 'STALE_STATE_PRESERVED=yes'
  assert_contains "$out" 'Scenario exit code: 0'
  assert_not_contains "$out" 'QA_EXECUTE_MARKER'
}

run_state_contract_probe() {
  local out="$1" helper_home
  helper_home="$(make_temp_home)"
  set +e
  AI_BOILER_PLATE_HOME="$helper_home" \
  BSS_AI_HELPER_HOME="$helper_home" \
  ROOT="$ROOT" \
  bash <<'BASH' > "$out" 2>&1
set -euo pipefail
source "$ROOT/lib/state.sh"
state_init
state_record_installation_plan \
  "Linux" \
  "$BSS_AI_HELPER_HOME/workspace" \
  "install" \
  "Codex CLI,Claude Code CLI" \
  "matt-pocock-skills,superpowers,lazy-codex,oh-my-claudecode" \
  "./linux/install.sh --standard"
py="$(_state_python)"
"$py" - "$BSS_AI_HELPER_HOME/state.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
plan = data["installationPlan"]
required = [
    "schemaVersion",
    "selectedOS",
    "workspaceFolder",
    "baseEnvironment",
    "aiCliTools",
    "addons",
    "executionCommand",
    "approvalStatus",
    "secretPolicy",
]
missing = [key for key in required if key not in plan]
if missing:
    raise SystemExit(f"missing plan fields: {missing}")
assert plan["selectedOS"] == "Linux"
assert plan["baseEnvironment"] == "install"
assert plan["approvalStatus"] == "pending"
assert plan["aiCliTools"] == ["Codex CLI", "Claude Code CLI"]
assert all(plan["addons"][key]["selected"] for key in plan["addons"])
for forbidden in ("token", "oauth_code", "password", "device_code", "private_key"):
    assert forbidden not in plan
print("PLAN_CONTRACT_FIELDS_OK")
PY
state_approve_installation_plan
printf 'PLAN_STATUS=%s\n' "$(state_installation_plan_status)"
printf 'PLAN_OS=%s\n' "$(state_installation_plan_field selectedOS)"
printf 'PLAN_AI=%s\n' "$(state_installation_plan_field aiCliTools)"
printf 'PLAN_ADDONS:\n'
state_installation_plan_selected_addons
BASH
  local code=$?
  set -e
  rm -rf "$helper_home"
  {
    printf 'Cleanup receipt: removed helper_home=%s\n' "$helper_home"
    printf 'Scenario exit code: %s\n' "$code"
  } >> "$out"
  return "$code"
}

run_standard_plan_probe() {
  local out="$1" helper_home_no helper_home_yes
  helper_home_no="$(make_temp_home)"
  helper_home_yes="$(make_temp_home)"
  : > "$out"

  set +e
  AI_BOILER_PLATE_HOME="$helper_home_no" \
  BSS_AI_HELPER_HOME="$helper_home_no" \
  bash "$ROOT/linux/install.sh" --standard --dry-run >> "$out.no-approval" 2>&1
  local no_code=$?
  set -e
  {
    printf 'STANDARD_WITHOUT_APPROVAL_EXIT=%s\n' "$no_code"
    cat "$out.no-approval"
  } >> "$out"
  [[ "$no_code" -ne 0 ]] || fail "--standard without approval unexpectedly succeeded"
  assert_contains "$out.no-approval" '승인된 Final Installation Plan'
  assert_not_contains "$out.no-approval" '== ai-boiler-plate'

  AI_BOILER_PLATE_HOME="$helper_home_yes" \
  BSS_AI_HELPER_HOME="$helper_home_yes" \
  ROOT="$ROOT" \
  bash <<'BASH' >> "$out" 2>&1
set -euo pipefail
source "$ROOT/lib/state.sh"
state_init
state_record_installation_plan \
  "Linux" \
  "$BSS_AI_HELPER_HOME/workspace" \
  "skip" \
  "" \
  "superpowers" \
  "./linux/install.sh --standard"
state_approve_installation_plan
BASH

  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      AI_BOILER_PLATE_HOME="$helper_home_yes" \
      BSS_AI_HELPER_HOME="$helper_home_yes" \
      ROOT="$ROOT" \
      bash <<'BASH' > "$out.approved" 2>&1
set -euo pipefail
source "$ROOT/lib/state.sh"
printf 'STANDARD_WINDOWS_STATE_ONLY=1\n'
printf 'Using approved Final Installation Plan: %s\n' "$(state_installation_plan_field executionCommand)"
printf 'STANDARD_SELECTED_ADDONS:\n'
state_installation_plan_selected_addons
if state_installation_plan_has_ai "Codex CLI"; then
  printf 'STANDARD_CODEX_SELECTED=1\n'
else
  printf 'STANDARD_CODEX_SELECTED=0\n'
fi
BASH
      local yes_code=0
      {
        printf 'STANDARD_WITH_APPROVED_PLAN_EXIT=%s\n' "$yes_code"
        cat "$out.approved"
      } >> "$out"
      assert_contains "$out.approved" 'STANDARD_WINDOWS_STATE_ONLY=1'
      assert_contains "$out.approved" 'Using approved Final Installation Plan'
      assert_contains "$out.approved" 'superpowers'
      assert_contains "$out.approved" 'STANDARD_CODEX_SELECTED=0'
      ;;
    *)
      set +e
      AI_BOILER_PLATE_HOME="$helper_home_yes" \
      BSS_AI_HELPER_HOME="$helper_home_yes" \
      bash "$ROOT/linux/install.sh" --standard --dry-run >> "$out.approved" 2>&1
      local yes_code=$?
      set -e
      {
        printf 'STANDARD_WITH_APPROVED_PLAN_EXIT=%s\n' "$yes_code"
        cat "$out.approved"
      } >> "$out"
      [[ "$yes_code" -eq 0 ]] || fail "--standard with approved dry-run plan failed"
      assert_contains "$out.approved" 'Using approved Final Installation Plan'
      assert_contains "$out.approved" '\[dry-run\] would run: npx skills@latest add https://github.com/obra/superpowers'
      assert_not_contains "$out.approved" 'Installing @openai/codex'
      ;;
  esac

  rm -rf "$helper_home_no" "$helper_home_yes"
  rm -f "$out.no-approval" "$out.approved"
  {
    printf 'Cleanup receipt: removed helper_home_no=%s\n' "$helper_home_no"
    printf 'Cleanup receipt: removed helper_home_yes=%s\n' "$helper_home_yes"
    printf 'Cleanup receipt: removed standard scratch transcripts\n'
  } >> "$out"
}

run_dirty_worktree_probe() {
  local out="$1" dirty_file dirty_status after_status
  dirty_file="$ROOT/beginner-approval-dirty-probe.tmp"
  [[ ! -e "$dirty_file" ]] || fail "dirty worktree probe path already exists: $dirty_file"
  printf 'temporary dirty worktree probe\n' > "$dirty_file"
  dirty_status="$(qa_git status --short -- beginner-approval-dirty-probe.tmp)"
  [[ -n "$dirty_status" ]] || fail "dirty worktree probe did not create observable git status"

  set +e
  run_scenario "$out" $'not-a-menu\n승인\n'
  local code=$?
  set -e

  rm -f "$dirty_file"
  after_status="$(qa_git status --short -- beginner-approval-dirty-probe.tmp)"
  {
    printf 'DIRTY_WORKTREE_PROBE=untracked-root-file\n'
    printf 'DIRTY_WORKTREE_STATUS_DURING=%s\n' "$dirty_status"
    if [[ -z "$after_status" ]]; then
      printf 'DIRTY_WORKTREE_CLEANUP_STATUS=clean\n'
    else
      printf 'DIRTY_WORKTREE_CLEANUP_STATUS=%s\n' "$after_status"
    fi
  } >> "$out"

  [[ "$code" -eq 0 ]] || return "$code"
  [[ -z "$after_status" ]] || fail "dirty worktree probe cleanup left git status: $after_status"
  assert_not_contains "$out" 'QA_EXECUTE_MARKER'
  assert_contains "$out" 'DIRTY_WORKTREE_PROBE=untracked-root-file'
  assert_contains "$out" 'DIRTY_WORKTREE_CLEANUP_STATUS=clean'
}

case "$MODE" in
  --baseline)
    run_scenario "$BASELINE_TRANSCRIPT" $'2\n2\n1\n3\n1\n2\n2\n2\n승인\n'
    assert_baseline_contract "$BASELINE_TRANSCRIPT"
    note "PASS baseline-current-early-execution $BASELINE_TRANSCRIPT"
    ;;
  --adversarial)
    {
      printf 'Adversarial probes for Bash beginner approval gate\n'
      printf 'malformed_input: '
    } > "$ADVERSARIAL_TRANSCRIPT"
    run_scenario "$ADVERSARIAL_TRANSCRIPT.malformed" $'not-a-menu\n승인\n'
    assert_not_contains "$ADVERSARIAL_TRANSCRIPT.malformed" 'QA_EXECUTE_MARKER'
    printf 'PASS no execution marker for malformed menu input\n' >> "$ADVERSARIAL_TRANSCRIPT"

    printf 'stale_state: ' >> "$ADVERSARIAL_TRANSCRIPT"
    run_scenario "$ADVERSARIAL_TRANSCRIPT.stale" $'1\n' 1
    assert_stale_state_contract "$ADVERSARIAL_TRANSCRIPT.stale"
    printf 'PASS malformed state is reported, preserved, and does not execute installer steps\n' >> "$ADVERSARIAL_TRANSCRIPT"

    printf 'dirty_worktree: ' >> "$ADVERSARIAL_TRANSCRIPT"
    run_dirty_worktree_probe "$ADVERSARIAL_TRANSCRIPT.dirty"
    printf 'PASS dirty worktree was observable during the scenario and cleaned afterward\n' >> "$ADVERSARIAL_TRANSCRIPT"

    printf 'misleading_success_output: ' >> "$ADVERSARIAL_TRANSCRIPT"
    run_scenario "$ADVERSARIAL_TRANSCRIPT.misleading" $'2\n2\n2\n4\n2\n2\n2\n2\n승인\n' 0 1
    assert_contains "$ADVERSARIAL_TRANSCRIPT.misleading" 'QA_MISLEADING_SUCCESS_OUTPUT'
    assert_not_contains "$ADVERSARIAL_TRANSCRIPT.misleading" 'QA_EXECUTE_MARKER'
    printf 'PASS success-like text is not treated as execution\n' >> "$ADVERSARIAL_TRANSCRIPT"

    rm -f "$ADVERSARIAL_TRANSCRIPT.malformed" "$ADVERSARIAL_TRANSCRIPT.stale" "$ADVERSARIAL_TRANSCRIPT.dirty" "$ADVERSARIAL_TRANSCRIPT.misleading"
    printf 'Cleanup receipt: removed adversarial scratch transcripts\n' >> "$ADVERSARIAL_TRANSCRIPT"
    note "PASS adversarial-probes $ADVERSARIAL_TRANSCRIPT"
    ;;
  --regression)
    run_scenario "$TRANSCRIPT" $'2\n2\n1\n3\n1\n2\n2\n2\n승인\n'
    assert_regression_contract "$TRANSCRIPT"
    note "PASS beginner-approval-gate-bash $TRANSCRIPT"
    ;;
  --state-contract)
    run_state_contract_probe "$STATE_CONTRACT_TRANSCRIPT"
    assert_contains "$STATE_CONTRACT_TRANSCRIPT" 'PLAN_CONTRACT_FIELDS_OK'
    assert_contains "$STATE_CONTRACT_TRANSCRIPT" 'PLAN_STATUS=approved'
    assert_contains "$STATE_CONTRACT_TRANSCRIPT" 'matt-pocock-skills'
    assert_contains "$STATE_CONTRACT_TRANSCRIPT" 'Scenario exit code: 0'
    note "PASS beginner-state-contract $STATE_CONTRACT_TRANSCRIPT"
    ;;
  --standard)
    run_standard_plan_probe "$STANDARD_TRANSCRIPT"
    assert_contains "$STANDARD_TRANSCRIPT" 'STANDARD_WITHOUT_APPROVAL_EXIT='
    assert_contains "$STANDARD_TRANSCRIPT" 'STANDARD_WITH_APPROVED_PLAN_EXIT=0'
    assert_contains "$STANDARD_TRANSCRIPT" 'Cleanup receipt: removed standard scratch transcripts'
    note "PASS beginner-standard-plan $STANDARD_TRANSCRIPT"
    ;;
  *)
    fail "usage: $0 [--regression|--baseline|--adversarial|--state-contract|--standard]"
    ;;
esac
