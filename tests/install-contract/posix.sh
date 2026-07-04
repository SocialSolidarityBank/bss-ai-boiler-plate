#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENFORCE_PENDING="${BSS_INSTALL_CONTRACT_ENFORCE_PENDING:-0}"
FAILURES=()
CLEANUPS=()
CLEANUP_LIST="$(mktemp "${TMPDIR:-/tmp}/bss-install-contract-posix-cleanup.XXXXXX")"

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
  printf '%s\n' "$root" >> "$CLEANUP_LIST"
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

add_logged_command() {
  local sandbox="$1" name="$2"
  cat > "$sandbox/bin/$name" <<'SH'
#!/usr/bin/env bash
name="$(basename "$0")"
printf '%s %s\n' "$name" "$*" >> "${BSS_CONTRACT_COMMAND_LOG:?}"
if [[ "$name" == "curl" ]]; then
  out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) out="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ -n "$out" ]]; then
    {
      printf '%s\n' '#!/usr/bin/env bash'
      printf '%s\n' '# do_install marker for installer contract tests'
      printf '%s\n' 'printf "%s\n" docker-script-ran >> "${BSS_CONTRACT_COMMAND_LOG:?}"'
    } > "$out"
    chmod +x "$out"
  fi
fi
exit "${BSS_FAKE_COMMAND_EXIT:-0}"
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
    BSS_AI_HELPER_TTY="${BSS_AI_HELPER_TTY:-}" \
    BSS_INSTALL_DOCKER="${BSS_INSTALL_DOCKER:-0}" \
    HERMES="${HERMES:-1}" \
    timeout 20s "$ROOT/linux/install.sh" "$@" >"$out" 2>&1
  local code=$?
  set -e
  printf '%s\n' "$code" > "$code_file"
  cat "$out"
  return 0
}

run_linux_lib_case() {
  local sandbox="$1"
  local out="$sandbox/output.txt"
  local code_file="$sandbox/code.txt"
  local script="$sandbox/case.sh"
  cat > "$script"
  set +e
  env \
    HOME="$sandbox/home" \
    BSS_AI_HELPER_HOME="$sandbox/helper" \
    BSS_CONTRACT_COMMAND_LOG="$sandbox/commands.log" \
    PATH="$sandbox/bin:/usr/bin:/bin" \
    ROOT="$ROOT" \
    timeout 20s bash "$script" >"$out" 2>&1
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
  if [[ -f "${CLEANUP_LIST:-}" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      case "$path" in
        "${TMPDIR:-/tmp}"/bss-install-contract-posix.*) rm -rf "$path" ;;
        *) printf 'WARN cleanup refused path outside contract temp root: %s\n' "$path" >&2 ;;
      esac
    done < "$CLEANUP_LIST"
    rm -f "$CLEANUP_LIST"
  fi
  for path in "${CLEANUPS[@]}"; do
    case "$path" in
      "${TMPDIR:-/tmp}"/bss-install-contract-posix.*) rm -rf "$path" ;;
    esac
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
printf '1\n' > "$wizard_box/tty"
BSS_AI_HELPER_TTY="$wizard_box/tty"
export BSS_AI_HELPER_TTY
wizard_output="$(run_installer "$wizard_box" "" --wizard)"
unset BSS_AI_HELPER_TTY
wizard_code="$(exit_code_of "$wizard_box")"
assert_contract "explicit wizard" "$([[ "$wizard_code" == "0" ]]; echo $?)" "exit 0 when redirected input chooses status" "$wizard_output"
assert_contains "explicit wizard" "$wizard_output" "BSS AI Helper" "wizard prompt title"
assert_contains "explicit wizard" "$wizard_output" "redirected.*wizard.*tty|tty.*wizard.*redirected" "explicit wizard reads from an available tty instead of piped stdin"
assert_contains "explicit wizard" "$wizard_output" "1\\)" "status menu choice"
assert_contains "explicit wizard" "$wizard_output" "4\\)" "classic/direct menu choice"
assert_contract "explicit wizard" "$([[ -f "$wizard_box/helper/state.json" ]]; echo $?)" "isolated helper state is created only under the sandbox" "$wizard_output"

pipe_box="$(new_sandbox)"
pipe_output="$(run_installer "$pipe_box" "" --dry-run)"
pipe_code="$(exit_code_of "$pipe_box")"
if is_linux_kernel; then
  assert_contract "redirected stdin no-flag explanation" "$([[ "$pipe_code" == "0" ]]; echo $?)" "exit 0 for redirected no-flag dry-run classic mode" "$pipe_output"
  assert_contains "redirected stdin no-flag explanation" "$pipe_output" "No interactive terminal|non-interactive.*classic|classic.*non-interactive" "explicit explanation before noninteractive classic fallback"
  assert_contains "redirected stdin no-flag explanation" "$pipe_output" "DRY-RUN" "dry-run notice"
else
  assert_contract "redirected stdin no-flag explanation" "$([[ "$pipe_code" != "0" ]]; echo $?)" "non-Linux Git Bash reports Linux-only preflight after explaining pipe behavior" "$pipe_output"
  assert_contains "redirected stdin no-flag explanation" "$pipe_output" "No interactive terminal|non-interactive.*classic|classic.*non-interactive" "explicit explanation before noninteractive classic fallback"
  assert_contains "redirected stdin no-flag explanation" "$pipe_output" "targets Linux only" "clear non-Linux preflight"
fi
assert_not_contains "redirected stdin no-flag explanation" "$pipe_output" "BSS AI Helper .*질문|BSS AI Helper .*wizard" "no implicit wizard prompt when stdin is redirected"

wizard_no_tty_box="$(new_sandbox)"
BSS_AI_HELPER_TTY="$wizard_no_tty_box/missing-tty"
export BSS_AI_HELPER_TTY
wizard_no_tty_output="$(run_installer "$wizard_no_tty_box" "" --wizard --dry-run --only agents)"
unset BSS_AI_HELPER_TTY
wizard_no_tty_code="$(exit_code_of "$wizard_no_tty_box")"
if is_linux_kernel; then
  assert_contract "explicit wizard without tty" "$([[ "$wizard_no_tty_code" == "0" ]]; echo $?)" "falls back to classic dry-run when explicit wizard has no tty" "$wizard_no_tty_output"
  assert_contains "explicit wizard without tty" "$wizard_no_tty_output" "wizard.*no interactive terminal|no interactive terminal.*wizard|--classic" "clear explicit wizard fallback message"
else
  assert_contract "explicit wizard without tty" "$([[ "$wizard_no_tty_code" != "0" ]]; echo $?)" "non-Linux Git Bash reports Linux-only preflight after explicit wizard fallback" "$wizard_no_tty_output"
  assert_contains "explicit wizard without tty" "$wizard_no_tty_output" "wizard.*no interactive terminal|no interactive terminal.*wizard|--classic" "clear explicit wizard fallback message"
  assert_contains "explicit wizard without tty" "$wizard_no_tty_output" "targets Linux only" "clear non-Linux preflight"
fi

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

no_sudo_box="$(new_sandbox)"
add_logged_command "$no_sudo_box" apt-get
no_sudo_output="$(run_linux_lib_case "$no_sudo_box" <<'SH'
set -euo pipefail
export DRY_RUN=0
export ASSUME_YES=0
source "$ROOT/linux/scripts/lib.sh"
pm_try curl git
SH
)"
no_sudo_code="$(exit_code_of "$no_sudo_box")"
no_sudo_log="$(command_log_of "$no_sudo_box")"
assert_contract "no-sudo rootless package skip" "$([[ "$no_sudo_code" == "0" ]]; echo $?)" "rootless no-sudo package helper exits successfully" "$no_sudo_output"
assert_contains "no-sudo rootless package skip" "$no_sudo_output" "not root.*cannot escalate|cannot escalate.*system packages|skipping.*system packages" "clear no-sudo/rootless warning"
assert_not_contains "no-sudo rootless package skip" "$no_sudo_log" "^apt-get " "package manager is not executed without root or sudo"

check_pm_dry_run() {
  local pm="$1" binary="$2" refresh_pattern="$3" install_pattern="$4"
  local pm_box pm_output pm_code pm_log
  pm_box="$(new_sandbox)"
  add_logged_command "$pm_box" "$binary"
  pm_output="$(run_linux_lib_case "$pm_box" <<'SH'
set -euo pipefail
export DRY_RUN=1
export ASSUME_YES=1
source "$ROOT/linux/scripts/lib.sh"
pm_install alpha beta
SH
)"
  pm_code="$(exit_code_of "$pm_box")"
  pm_log="$(command_log_of "$pm_box")"
  assert_contract "package manager dry-run $pm" "$([[ "$pm_code" == "0" ]]; echo $?)" "dry-run pm_install exits 0 for $pm" "$pm_output"
  assert_contains "package manager dry-run $pm" "$pm_output" "$refresh_pattern" "package-manager-specific refresh command"
  assert_contains "package manager dry-run $pm" "$pm_output" "$install_pattern" "package-manager-specific noninteractive install command"
  assert_contract "package manager dry-run $pm" "$([[ -z "$pm_log" ]]; echo $?)" "dry-run does not execute mocked $binary" "$pm_log"
}

check_pm_dry_run apt apt-get "apt-get update -y" "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends alpha beta"
check_pm_dry_run dnf dnf "dnf -y makecache" "dnf install -y alpha beta"
check_pm_dry_run yum yum "yum -y makecache" "yum install -y alpha beta"
check_pm_dry_run pacman pacman "pacman -Syu --noconfirm" "pacman -S --needed --noconfirm alpha beta"
check_pm_dry_run zypper zypper "zypper --non-interactive refresh" "zypper --non-interactive install --no-recommends alpha beta"
check_pm_dry_run apk apk "apk update" "apk add alpha beta"

bad_pm_box="$(new_sandbox)"
bad_pm_output="$(run_linux_lib_case "$bad_pm_box" <<'SH'
set -euo pipefail
export DRY_RUN=1
export ASSUME_YES=1
source "$ROOT/linux/scripts/lib.sh"
PM=bogus
pm_install alpha
SH
)"
bad_pm_code="$(exit_code_of "$bad_pm_box")"
assert_contract "malformed input invalid package manager" "$([[ "$bad_pm_code" != "0" ]]; echo $?)" "invalid package manager exits non-zero" "$bad_pm_output"
assert_contains "malformed input invalid package manager" "$bad_pm_output" "unknown package manager|cannot install" "clear invalid package manager message"

docker_yes_box="$(new_sandbox)"
for name in curl usermod systemctl; do
  add_logged_command "$docker_yes_box" "$name"
done
docker_yes_output="$(run_linux_lib_case "$docker_yes_box" <<'SH'
set -euo pipefail
export DRY_RUN=0
export ASSUME_YES=1
export BSS_INSTALL_DOCKER=0
source "$ROOT/linux/scripts/lib.sh"
source "$ROOT/linux/scripts/05-docker.sh"
step_docker
SH
)"
docker_yes_code="$(exit_code_of "$docker_yes_box")"
docker_yes_log="$(command_log_of "$docker_yes_box")"
assert_contract "docker yes requires opt-in" "$([[ "$docker_yes_code" == "0" ]]; echo $?)" "--yes docker step exits 0 without opt-in" "$docker_yes_output"
assert_contains "docker yes requires opt-in" "$docker_yes_output" "Docker.*opt-in|--with-docker|BSS_INSTALL_DOCKER" "Docker remains explicit opt-in under --yes"
assert_not_contains "docker yes requires opt-in" "$docker_yes_log" "curl |docker-script-ran|usermod " "Docker install commands are not executed under --yes alone"

docker_opt_in_box="$(new_sandbox)"
for name in curl usermod systemctl; do
  add_logged_command "$docker_opt_in_box" "$name"
done
docker_opt_in_output="$(run_linux_lib_case "$docker_opt_in_box" <<'SH'
set -euo pipefail
export DRY_RUN=1
export ASSUME_YES=1
export BSS_INSTALL_DOCKER=1
source "$ROOT/linux/scripts/lib.sh"
source "$ROOT/linux/scripts/05-docker.sh"
step_docker
SH
)"
docker_opt_in_code="$(exit_code_of "$docker_opt_in_box")"
docker_opt_in_log="$(command_log_of "$docker_opt_in_box")"
assert_contract "docker explicit opt-in dry-run" "$([[ "$docker_opt_in_code" == "0" ]]; echo $?)" "explicit Docker opt-in dry-run exits 0" "$docker_opt_in_output"
assert_contains "docker explicit opt-in dry-run" "$docker_opt_in_output" "get.docker.com|usermod -aG docker" "Docker opt-in dry-run previews Docker commands"
assert_contract "docker explicit opt-in dry-run" "$([[ -z "$docker_opt_in_log" ]]; echo $?)" "Docker opt-in dry-run does not execute mocked commands" "$docker_opt_in_log"

if [[ "${#FAILURES[@]}" -gt 0 ]]; then
  printf '%s\n' "${FAILURES[@]}" >&2
  exit 1
fi

printf 'PASS POSIX installer contract harness\n'
