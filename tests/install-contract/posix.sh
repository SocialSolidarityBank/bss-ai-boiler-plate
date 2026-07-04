#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENFORCE_PENDING="${BSS_INSTALL_CONTRACT_ENFORCE_PENDING:-0}"
FAILURES=()
CLEANUPS=()

fail_contract() {
  local mode="$1" expected="$2" output="${3:-}"
  local snippet="${output//$'\r'/}"
  if [[ "${#snippet}" -gt 700 ]]; then
    snippet="${snippet:0:700}..."
  fi
  FAILURES+=("POSIX $mode: expected $expected. Output:
$snippet")
}

assert_contract() {
  local mode="$1" condition="$2" expected="$3" output="${4:-}"
  [[ "$condition" == "0" ]] || fail_contract "$mode" "$expected" "$output"
}

assert_contains() {
  local mode="$1" text="$2" pattern="$3" expected="$4"
  if ! grep -Eq -- "$pattern" <<<"$text"; then
    fail_contract "$mode" "$expected" "$text"
  fi
}

assert_not_contains() {
  local mode="$1" text="$2" pattern="$3" expected="$4"
  if grep -Eq -- "$pattern" <<<"$text"; then
    fail_contract "$mode" "$expected" "$text"
  fi
}

note_pending() {
  local mode="$1" condition="$2" expected="$3" output="${4:-}"
  if [[ "$condition" == "0" ]]; then
    printf 'PASS pending-ready POSIX %s: %s\n' "$mode" "$expected"
  elif [[ "$ENFORCE_PENDING" == "1" ]]; then
    fail_contract "$mode" "$expected" "$output"
  else
    printf 'PENDING POSIX %s: %s\n' "$mode" "$expected"
  fi
}

new_sandbox() {
  local root
  root="$(mktemp -d "${TMPDIR:-/tmp}/bss-install-contract-posix.XXXXXX")"
  mkdir -p "$root/home" "$root/helper" "$root/bin"
  CLEANUPS+=("$root")
  printf '%s\n' "$root"
}

add_fake_command() {
  local sandbox="$1" name="$2"
  cat > "$sandbox/bin/$name" <<'SH'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "${BSS_CONTRACT_COMMAND_LOG:?}"
case "${1:-}" in
  --version|-v|version) printf 'fake-version\n'; exit 0 ;;
esac
exit 99
SH
  chmod +x "$sandbox/bin/$name"
}

run_installer() {
  local sandbox="$1" input="$2"
  shift 2
  local out="$sandbox/output.txt"
  local code_file="$sandbox/code.txt"
  set +e
  printf '%s' "$input" | env \
    HOME="$sandbox/home" \
    BSS_AI_HELPER_HOME="$sandbox/helper" \
    BSS_CONTRACT_COMMAND_LOG="$sandbox/commands.log" \
    PATH="$sandbox/bin:/usr/bin:/bin" \
    BSS_AI_INSTALL_CODEX="${BSS_AI_INSTALL_CODEX:-1}" \
    BSS_AI_INSTALL_CLAUDE="${BSS_AI_INSTALL_CLAUDE:-1}" \
    BSS_AI_INSTALL_EXTRAS="${BSS_AI_INSTALL_EXTRAS:-1}" \
    BSS_AI_HELPER_FORCE_INSTALL_PREVIEW="${BSS_AI_HELPER_FORCE_INSTALL_PREVIEW:-1}" \
    HERMES="${HERMES:-1}" \
    timeout 20s "$ROOT/linux/install.sh" "$@" >"$out" 2>&1
  local code=$?
  set -e
  printf '%s\n' "$code" > "$code_file"
  cat "$out"
  return 0
}

exit_code_of() {
  local sandbox="$1"
  cat "$sandbox/code.txt"
}

command_log_of() {
  local sandbox="$1"
  if [[ -f "$sandbox/commands.log" ]]; then cat "$sandbox/commands.log"; fi
}

check_shell_syntax() {
  local files=(
    "$ROOT/install.sh"
    "$ROOT/uninstall.sh"
    "$ROOT/linux/install.sh"
    "$ROOT/linux/uninstall.sh"
    "$ROOT/tests/install-contract/posix.sh"
  )
  local file
  for file in "$ROOT"/scripts/*.sh "$ROOT"/linux/scripts/*.sh "$ROOT"/lib/*.sh; do
    [[ -e "$file" ]] && files+=("$file")
  done
  for file in "${files[@]}"; do
    if ! bash -n "$file"; then
      fail_contract "shell syntax" "bash -n parses $file" "syntax failure in $file"
    fi
  done
  printf 'PASS POSIX shell parser: %s files\n' "${#files[@]}"
}

is_linux_kernel() {
  [[ "$(uname -s)" == "Linux" ]]
}

cleanup() {
  local path
  for path in "${CLEANUPS[@]}"; do
    rm -rf "$path"
  done
}
trap cleanup EXIT

check_shell_syntax

status_box="$(new_sandbox)"
status_output="$(run_installer "$status_box" "" --status)"
status_code="$(exit_code_of "$status_box")"
assert_contract "status-only" "$([[ "$status_code" == "0" ]]; echo $?)" "exit 0 for read-only status" "$status_output"
assert_contains "status-only" "$status_output" "BSS AI Helper" "status output"
assert_not_contains "status-only" "$status_output" "bss-ai-boilerplate v" "no classic installer execution in status-only mode"
assert_contract "status-only" "$([[ ! -f "$status_box/helper/state.json" ]]; echo $?)" "no state file written by status-only mode" "$status_output"

wizard_box="$(new_sandbox)"
wizard_output="$(run_installer "$wizard_box" $'1\n' --wizard)"
wizard_code="$(exit_code_of "$wizard_box")"
assert_contract "explicit wizard" "$([[ "$wizard_code" == "0" ]]; echo $?)" "exit 0 when redirected input chooses status" "$wizard_output"
assert_contains "explicit wizard" "$wizard_output" "BSS AI Helper" "wizard prompt title"
assert_contains "explicit wizard" "$wizard_output" "1\\)" "status menu choice"
assert_contains "explicit wizard" "$wizard_output" "4\\)" "classic/direct menu choice"
assert_contract "explicit wizard" "$([[ -f "$wizard_box/helper/state.json" ]]; echo $?)" "isolated helper state is created only under the sandbox" "$wizard_output"

redirected_box="$(new_sandbox)"
redirected_output="$(run_installer "$redirected_box" $'\n' --dry-run --only agents)"
redirected_code="$(exit_code_of "$redirected_box")"
if is_linux_kernel; then
  assert_contract "redirected stdin direct dry-run" "$([[ "$redirected_code" == "0" ]]; echo $?)" "exit 0 for redirected dry-run direct mode" "$redirected_output"
  assert_contains "redirected stdin direct dry-run" "$redirected_output" "DRY-RUN" "dry-run notice"
  assert_contains "redirected stdin direct dry-run" "$redirected_output" "steps: agents" "classic/direct selected agents step"
else
  assert_contract "redirected stdin direct dry-run" "$([[ "$redirected_code" != "0" ]]; echo $?)" "non-Linux Git Bash reports Linux-only preflight instead of installing" "$redirected_output"
  assert_contains "redirected stdin direct dry-run" "$redirected_output" "targets Linux only" "clear non-Linux preflight"
fi
note_pending "redirected stdin no-flag explanation" "1" "no-flag redirected stdin should explain the noninteractive fallback before classic work starts" "$redirected_output"

agents_box="$(new_sandbox)"
for name in bun npm npx curl mise rustup gjc codex claude hermes gh git; do
  add_fake_command "$agents_box" "$name"
done
agents_output="$(run_installer "$agents_box" "" --classic --dry-run --only agents)"
agents_code="$(exit_code_of "$agents_box")"
agents_log="$(command_log_of "$agents_box")"
if is_linux_kernel; then
  assert_contract "classic/direct dry-run agents" "$([[ "$agents_code" == "0" ]]; echo $?)" "exit 0 for classic dry-run agents step" "$agents_output"
  assert_contains "classic/direct dry-run agents" "$agents_output" "steps: agents" "classic/direct selected agents step"
  assert_contains "classic/direct dry-run agents" "$agents_output" "\\[dry-run\\].*(npm install|Claude|npx|curl)" "observable dry-run agent install preview"
  if grep -Eq '^(bun|npm|npx|curl|mise|rustup) ' <<<"$agents_log"; then
    fail_contract "classic/direct dry-run agents" "mocked install/network commands are not executed in dry-run" "$agents_log"
  fi
  if grep -Eq '^(gjc|codex|claude|hermes) ' <<<"$agents_log"; then
    note_pending "strict dry-run agents" "1" "dry-run should avoid even agent version probes" "$agents_log"
  else
    note_pending "strict dry-run agents" "0" "dry-run should avoid even agent version probes" "$agents_log"
  fi
else
  assert_contract "classic/direct dry-run agents" "$([[ "$agents_code" != "0" ]]; echo $?)" "non-Linux Git Bash reports Linux-only preflight instead of installing" "$agents_output"
  assert_contains "classic/direct dry-run agents" "$agents_output" "targets Linux only" "clear non-Linux preflight"
  printf 'SKIP POSIX classic/direct dry-run agents: Linux kernel required after preflight; Git Bash covered the entrypoint safely.\n'
fi

wizard_classic_box="$(new_sandbox)"
wizard_classic_output="$(run_installer "$wizard_classic_box" $'4\n' --wizard --dry-run --only agents)"
wizard_classic_code="$(exit_code_of "$wizard_classic_box")"
if is_linux_kernel; then
  assert_contract "explicit wizard classic choice" "$([[ "$wizard_classic_code" == "0" ]]; echo $?)" "wizard classic choice falls through to classic dry-run" "$wizard_classic_output"
  assert_contains "explicit wizard classic choice" "$wizard_classic_output" "steps: agents|AI agents" "classic/direct outcome after wizard choice 4"
else
  assert_contract "explicit wizard classic choice" "$([[ "$wizard_classic_code" != "0" ]]; echo $?)" "non-Linux Git Bash reports Linux-only preflight after wizard classic choice" "$wizard_classic_output"
  assert_contains "explicit wizard classic choice" "$wizard_classic_output" "targets Linux only" "clear non-Linux preflight"
fi

bad_box="$(new_sandbox)"
bad_output="$(run_installer "$bad_box" "" --not-a-real-option)"
bad_code="$(exit_code_of "$bad_box")"
assert_contract "malformed input invalid flag" "$([[ "$bad_code" != "0" ]]; echo $?)" "non-zero exit for an invalid flag" "$bad_output"
assert_contains "malformed input invalid flag" "$bad_output" "unknown option: --not-a-real-option" "clear invalid flag message"

if [[ "${#FAILURES[@]}" -gt 0 ]]; then
  printf '%s\n' "${FAILURES[@]}" >&2
  exit 1
fi

printf 'PASS POSIX installer contract harness\n'
