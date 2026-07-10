#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

evidence="$EVIDENCE_DIR/task-14-aggregate-completion-state-green.txt"
: > "$evidence"
MAC_INSTALLER="${MAC_INSTALLER:-$ROOT/install.sh}"
LINUX_INSTALLER="${LINUX_INSTALLER:-$ROOT/linux/install.sh}"
WINDOWS_INSTALLER="${WINDOWS_INSTALLER:-$ROOT/windows/install.ps1}"

log() {
  printf '%s\n' "$*" | tee -a "$evidence"
}

extract_bash_function() {
  local script="$1" name="$2"
  awk -v name="$name" '
    $0 ~ "^" name "\\(\\) \\{" { printing=1 }
    printing { print }
    printing && $0 == "}" { exit }
  ' "$script"
}

select_python() {
  if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    printf 'python3\n'
  elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
    printf 'python\n'
  else
    fail "python is required for aggregate state QA"
  fi
}

PYTHON_BIN="$(select_python)"

json_status() {
  local state="$1" step="$2"
  "$PYTHON_BIN" - "$state" "$step" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8-sig") as f:
    data = json.load(f)
row = data.get("steps", {}).get(sys.argv[2], {})
print(row.get("status", "pending") if isinstance(row, dict) else row)
PY
}

assert_step_status() {
  local state="$1" step="$2" expected="$3" actual
  actual="$(json_status "$state" "$step")"
  [[ "$actual" == "$expected" ]] || fail "$step expected $expected, got $actual in $state"
}

run_bash_record_probe() {
  local label="$1" installer="$2" helper_home="$3"
  shift 3
  rm -rf "$helper_home"
  mkdir -p "$helper_home"
  (
    export AI_BOILER_PLATE_HOME="$helper_home" BSS_AI_HELPER_HOME="$helper_home"
    if ! python3 --version >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
      python3() { python "$@"; }
    fi
    source "$ROOT/lib/state.sh"
    eval "$(extract_bash_function "$installer" set_aggregate_step_status)"
    eval "$(extract_bash_function "$installer" record_completion_state)"
    SELECTED_STEPS=("$@")
    selected() { printf '%s\n' "${SELECTED_STEPS[@]}"; }
    printf 'misleading_success_output: base-tools complete\n'
    record_completion_state
    source "$ROOT/lib/report.sh"
    bss_generate_report
  ) >> "$evidence" 2>&1
  log "$label state=$helper_home/state.json report=$helper_home/latest-report.md manual=$helper_home/manual/index.html"
}

assert_report_manual_partial() {
  local helper_home="$1"
  assert_contains "$helper_home/latest-report.md" 'partial'
  assert_contains "$helper_home/manual/index.html" 'partial'
}

run_windows_probe() {
  local helper_home="$1" root_for_ps="$ROOT" helper_for_ps installer_for_ps="$WINDOWS_INSTALLER" ps_bin
  helper_for_ps="$helper_home"
  if command -v cygpath >/dev/null 2>&1; then
    root_for_ps="$(cygpath -w "$ROOT")"
    helper_for_ps="$(cygpath -w "$helper_home")"
    installer_for_ps="$(cygpath -w "$WINDOWS_INSTALLER")"
  fi
  if command -v pwsh >/dev/null 2>&1; then
    ps_bin="pwsh"
  elif command -v powershell.exe >/dev/null 2>&1; then
    ps_bin="powershell.exe"
  elif command -v powershell >/dev/null 2>&1; then
    ps_bin="powershell"
  else
    fail "PowerShell not found for Windows aggregate state probe"
  fi

  rm -rf "$helper_home"
  mkdir -p "$helper_home"
  local probe="$helper_home/windows-aggregate-probe.ps1"
  cat > "$probe" <<'PS1'
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter(Mandatory)][string]$HelperHome,
  [Parameter(Mandatory)][string]$Installer
)
$ErrorActionPreference = 'Stop'
$env:AI_BOILER_PLATE_HOME = $HelperHome
$env:BSS_AI_HELPER_HOME = $HelperHome

function Get-FunctionText {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name, [switch]$Optional)
  $text = Get-Content -Raw -LiteralPath $Path
  $start = $text.IndexOf("function $Name")
  if ($start -lt 0) {
    if ($Optional) { return '' }
    throw "missing function $Name in $Path"
  }
  $brace = $text.IndexOf('{', $start)
  if ($brace -lt 0) { throw "missing opening brace for $Name" }
  $depth = 0
  for ($i = $brace; $i -lt $text.Length; $i++) {
    if ($text[$i] -eq '{') { $depth++ }
    elseif ($text[$i] -eq '}') {
      $depth--
      if ($depth -eq 0) { return $text.Substring($start, $i - $start + 1) }
    }
  }
  throw "missing closing brace for $Name"
}

. (Join-Path $Root 'windows\scripts\lib.ps1')
. (Join-Path $Root 'windows\scripts\state.ps1')
. (Join-Path $Root 'windows\scripts\report.ps1')
$windowsRoot = Join-Path $Root 'windows'
$functionText = (Get-FunctionText -Path $Installer -Name 'Write-CompletionReport' -Optional) + "`n" + (Get-FunctionText -Path $Installer -Name 'Add-StepSummaryToLatestReport' -Optional) + "`n" + (Get-FunctionText -Path $Installer -Name 'Set-AggregateStepStatus' -Optional) + "`n" + (Get-FunctionText -Path $Installer -Name 'Record-CompletionState')
Invoke-Expression $functionText
$script:DryRun = $false
$script:selected = @('runtimes')
Write-Output 'misleading_success_output: base-tools complete'
Record-CompletionState
if (Get-Command Write-CompletionReport -ErrorAction SilentlyContinue) {
  $Root = $windowsRoot
  Write-CompletionReport
} else {
  New-HelperReport | ForEach-Object { Write-Output $_ }
}
PS1
  "$ps_bin" -NoProfile -ExecutionPolicy Bypass -File "$probe" -Root "$root_for_ps" -HelperHome "$helper_for_ps" -Installer "$installer_for_ps" >> "$evidence" 2>&1
  log "windows state=$helper_home/state.json report=$helper_home/latest-report.md manual=$helper_home/manual/index.html"
}

log "SCENARIO partial base selections do not complete aggregate state"
mac_partial_home="$(make_temp_home)"
run_bash_record_probe "macos_partial_runtimes" "$MAC_INSTALLER" "$mac_partial_home" runtimes
assert_step_status "$mac_partial_home/state.json" base-tools partial
assert_report_manual_partial "$mac_partial_home"

linux_partial_home="$(make_temp_home)"
run_bash_record_probe "linux_partial_runtimes" "$LINUX_INSTALLER" "$linux_partial_home" runtimes
assert_step_status "$linux_partial_home/state.json" base-tools partial
assert_report_manual_partial "$linux_partial_home"

windows_partial_home="$(make_temp_home)"
run_windows_probe "$windows_partial_home"
assert_step_status "$windows_partial_home/state.json" base-tools partial
assert_contains "$windows_partial_home/latest-report.md" 'partial'
assert_contains "$windows_partial_home/manual/index.html" 'partial'

log "SCENARIO full base selections complete aggregate state"
mac_full_home="$(make_temp_home)"
run_bash_record_probe "macos_full_base" "$MAC_INSTALLER" "$mac_full_home" prereqs brew runtimes
assert_step_status "$mac_full_home/state.json" base-tools complete

linux_full_home="$(make_temp_home)"
run_bash_record_probe "linux_full_base" "$LINUX_INSTALLER" "$linux_full_home" prereqs packages runtimes
assert_step_status "$linux_full_home/state.json" base-tools complete

log "SCENARIO skipped base selections are recorded as skipped"
mac_skipped_home="$(make_temp_home)"
run_bash_record_probe "macos_skipped_base" "$MAC_INSTALLER" "$mac_skipped_home" agents
assert_step_status "$mac_skipped_home/state.json" base-tools skipped

log "ADVERSARIAL stale_state"
stale_home="$(make_temp_home)"
mkdir -p "$stale_home"
printf '{"version":1,"steps":{"base-tools":{"status":"complete","label":"Basic Environment"}},"ai_services":[],"aiServices":[],"addons":{},"tools":[]}\n' > "$stale_home/state.json"
run_bash_record_probe "stale_state_overwritten" "$MAC_INSTALLER" "$stale_home" runtimes
assert_step_status "$stale_home/state.json" base-tools partial

log "ADVERSARIAL malformed_input"
malformed_home="$(make_temp_home)"
if env AI_BOILER_PLATE_HOME="$malformed_home" BSS_AI_HELPER_HOME="$malformed_home" "$ROOT/install.sh" --only definitely-not-a-step >> "$evidence" 2>&1; then
  fail "malformed --only input unexpectedly succeeded"
fi
assert_dir_absent "$malformed_home/state.json"

log "ADVERSARIAL dirty_worktree"
git -C "$ROOT" status --short >> "$evidence" 2>&1
[[ -n "$(git -C "$ROOT" status --short)" ]] || fail "dirty_worktree probe expected this task's uncommitted QA/edit state"

log "ADVERSARIAL misleading_success_output"
assert_step_status "$mac_partial_home/state.json" base-tools partial
assert_contains "$evidence" 'misleading_success_output: base-tools complete'

rm -rf "$mac_partial_home" "$linux_partial_home" "$windows_partial_home" "$mac_full_home" "$linux_full_home" "$mac_skipped_home" "$stale_home" "$malformed_home"
log "CLEANUP removed temp helper homes"
log "PASS aggregate-completion-state $evidence"
