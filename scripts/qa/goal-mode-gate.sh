#!/usr/bin/env bash
set -euo pipefail

qa_source() {
  local path="$1"
  source "$path"
}

qa_source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:---quick}"
case "$mode" in
  --quick|quick|"") mode="quick" ;;
  --full|full) mode="full" ;;
  --spec|spec) mode="spec" ;;
  --path-checks|path-checks) mode="path-checks" ;;
  -h|--help)
    printf 'Usage: scripts/qa/goal-mode-gate.sh [--quick|--full|--spec|--path-checks]\n'
    printf '  --quick  Spec contract + syntax + focused beginner workflow QA.\n'
    printf '  --full   Quick gate + full lane3-all QA.\n'
    printf '  --spec   Spec contract only.\n'
    printf '  --path-checks  Focused Windows path conversion + parser QA.\n'
    exit 0
    ;;
  *) fail "unknown mode: $mode" ;;
esac

goal_fail() {
  printf 'FAIL GOAL-GATE: %s\n' "$*" >&2
  printf 'Do not produce final/completion output. Fix the failing contract, then rerun this gate.\n' >&2
  exit 1
}

contains_file() {
  local file="$1" pattern="$2" label="$3"
  [[ -f "$file" ]] || goal_fail "missing required file: $file"
  grep -Eq -- "$pattern" "$file" || goal_fail "$label ($file)"
}

not_contains_file() {
  local file="$1" pattern="$2" label="$3"
  [[ -f "$file" ]] || goal_fail "missing required file: $file"
  if grep -Eq -- "$pattern" "$file"; then
    goal_fail "$label ($file)"
  fi
}

run_gate_cmd() {
  local label="$1" evidence="$2"
  shift 2
  if "$@" > "$evidence" 2>&1; then
    note "PASS GOAL-GATE ${label} ${evidence}"
  else
    sed -n '1,220p' "$evidence" >&2 || true
    goal_fail "$label failed; see $evidence"
  fi
}

is_wsl() {
  [[ -r /proc/sys/kernel/osrelease ]] && grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease
}

is_wsl_windows_drive_root() {
  is_wsl || return 1
  case "$ROOT" in
    /mnt/[A-Za-z]|/mnt/[A-Za-z]/*|/[A-Za-z]|/[A-Za-z]/*) ;;
    *) return 1 ;;
  esac
}

wsl_windows_root() {
  local win_root
  is_wsl_windows_drive_root || return 1
  command -v wslpath >/dev/null 2>&1 || return 1
  win_root="$(wslpath -w "$ROOT" 2>/dev/null)" || return 1
  case "$win_root" in
    [A-Za-z]:\\*|[A-Za-z]:/*)
      printf '%s\n' "$win_root"
      ;;
    *)
      return 1
      ;;
  esac
}

find_native_git_exe() {
  local path
  if command -v git.exe >/dev/null 2>&1; then
    command -v git.exe
    return
  fi

  for path in \
    "/mnt/c/Program Files/Git/cmd/git.exe" \
    "/mnt/c/Program Files/Git/bin/git.exe" \
    "/mnt/c/Program Files/Git/mingw64/bin/git.exe"; do
    if [[ -x "$path" ]]; then
      printf '%s\n' "$path"
      return
    fi
  done

  return 1
}

goal_git() {
  local native_git win_root
  if win_root="$(wsl_windows_root)" && native_git="$(find_native_git_exe)"; then
    "$native_git" -C "$win_root" "$@"
  elif git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" "$@"
  elif command -v git.exe >/dev/null 2>&1; then
    (cd "$ROOT" && git.exe "$@")
  else
    git -C "$ROOT" "$@"
  fi
}

goal_git_backend() {
  local native_git win_root
  if win_root="$(wsl_windows_root)" && native_git="$(find_native_git_exe)"; then
    printf 'native-windows-git: %s -C %s\n' "$native_git" "$win_root"
  elif git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'posix-git: git -C %s\n' "$ROOT"
  elif command -v git.exe >/dev/null 2>&1; then
    printf 'git-exe-cwd: git.exe in %s\n' "$ROOT"
  else
    printf 'fallback-git: git -C %s\n' "$ROOT"
  fi
}

check_executable_modes() {
  local expected=(
    ".githooks/pre-commit"
    ".githooks/pre-push"
    "scripts/install-goal-hooks.sh"
    "scripts/qa/goal-mode-gate.sh"
  )
  local file mode

  for file in "${expected[@]}"; do
    mode="$(goal_git ls-files -s -- "$file" | awk '{print $1}')"
    [[ "$mode" == "100755" ]] || goal_fail "expected executable git mode 100755 for $file, got ${mode:-missing}"
  done

  note "PASS GOAL-GATE executable-modes"
}

diff_has_changes() {
  goal_git diff --name-only "$@" | grep -q .
}

check_staged_diff() {
  if goal_git diff --cached --quiet --exit-code; then
    printf 'SKIP staged diff-check: no staged changes\n'
    return 0
  fi

  printf 'RUN git diff --cached --check\n'
  goal_git diff --cached --check
}

check_local_diff() {
  local checked=0
  local status=0

  if ! goal_git diff --quiet --exit-code; then
    printf 'RUN git diff --check\n'
    goal_git diff --check || status=1
    checked=1
  fi

  if ! goal_git diff --cached --quiet --exit-code; then
    printf 'RUN git diff --cached --check\n'
    goal_git diff --cached --check || status=1
    checked=1
  fi

  if [[ "$checked" -eq 0 ]]; then
    printf 'SKIP local diff-check: no working tree or staged changes\n'
  fi

  return "$status"
}

check_ci_diff() {
  local base="${GOAL_GATE_CI_BASE:-}"
  local head="${GOAL_GATE_CI_HEAD:-${GITHUB_SHA:-HEAD}}"

  if [[ -z "$base" && -n "${GITHUB_BASE_REF:-}" ]]; then
    base="origin/${GITHUB_BASE_REF}"
  fi

  if [[ -z "$base" && -n "${GITHUB_EVENT_BEFORE:-}" && ! "${GITHUB_EVENT_BEFORE}" =~ ^0+$ ]]; then
    base="$GITHUB_EVENT_BEFORE"
  fi

  if [[ -z "$base" ]]; then
    printf 'SKIP ci diff-check: no base ref available for this event\n'
    return 0
  fi

  goal_git rev-parse --verify "$base^{commit}" >/dev/null
  goal_git rev-parse --verify "$head^{commit}" >/dev/null

  if ! diff_has_changes "$base" "$head"; then
    goal_fail "CI diff range has no changed files: $base..$head"
  fi

  printf 'RUN git diff --check %s %s\n' "$base" "$head"
  goal_git diff --check "$base" "$head"
}

check_diff_whitespace() {
  case "${GOAL_GATE_DIFF_CONTEXT:-local}" in
    staged|pre-commit) check_staged_diff ;;
    local|pre-push) check_local_diff ;;
    ci) check_ci_diff ;;
    *) goal_fail "unknown GOAL_GATE_DIFF_CONTEXT: ${GOAL_GATE_DIFF_CONTEXT}" ;;
  esac
}

to_windows_path() {
  local path="$1"
  case "$path" in
    [A-Za-z]:/*|[A-Za-z]:\\*|\\\\*|//*)
      printf '%s\n' "$path"
      return
      ;;
  esac

  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
  elif command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

check_to_windows_path_contract() {
  local evidence="$EVIDENCE_DIR/goal-gate-to-windows-path.txt"
  local path actual
  local windows_paths=(
    "C:/Users/SSBAILAPTOP/.git/worktrees/example"
    "C:\\Users\\SSBAILAPTOP\\.git\\worktrees\\example"
    "//server/share/repo"
    "\\\\server\\share\\repo"
  )

  : > "$evidence"
  for path in "${windows_paths[@]}"; do
    actual="$(to_windows_path "$path")"
    printf 'IDEMPOTENT: %s -> %s\n' "$path" "$actual" >> "$evidence"
    [[ "$actual" == "$path" ]] || goal_fail "to_windows_path changed an already-Windows path: $path -> $actual"
  done

  if command -v wslpath >/dev/null 2>&1 && [[ -d /mnt/c ]]; then
    path="/mnt/c/Users"
    actual="$(to_windows_path "$path")"
    printf 'WSL_CONVERT: %s -> %s\n' "$path" "$actual" >> "$evidence"
    [[ "$actual" != "$path" ]] || goal_fail "to_windows_path did not convert WSL path: $path"
    case "$actual" in
      [A-Za-z]:\\*|[A-Za-z]:/*) ;;
      *) goal_fail "to_windows_path produced a non-Windows path for WSL input: $actual" ;;
    esac
  fi

  note "PASS GOAL-GATE to-windows-path $evidence"
}

check_goal_git_contract() {
  local evidence="$EVIDENCE_DIR/goal-gate-git-path.txt"
  local git_dir git_root
  git_dir="$(goal_git rev-parse --git-dir)" || goal_fail "goal_git could not read the worktree git dir"
  git_root="$(goal_git rev-parse --show-toplevel)" || goal_fail "goal_git could not read the worktree root"
  goal_git_backend > "$evidence"
  printf 'GIT_DIR: %s\n' "$git_dir" >> "$evidence"
  printf 'GIT_ROOT: %s\n' "$git_root" >> "$evidence"
  printf 'ROOT: %s\n' "$ROOT" >> "$evidence"
  case "$git_dir" in
    "$ROOT"/[A-Za-z]:*)
      goal_fail "goal_git returned mixed worktree/gitdir path: $git_dir"
      ;;
  esac
  if is_wsl_windows_drive_root; then
    if ! grep -Eq '^native-windows-git: .*git\.exe -C [A-Za-z]:' "$evidence"; then
      goal_fail "goal_git did not select native Windows git.exe for WSL Windows-drive root"
    fi
    case "$git_dir" in
      */[A-Za-z]:*|*\\[A-Za-z]:*)
        goal_fail "goal_git returned nested Windows gitdir path: $git_dir"
        ;;
    esac
    case "$git_root" in
      */[A-Za-z]:*|*\\[A-Za-z]:*)
        goal_fail "goal_git returned nested Windows root path: $git_root"
        ;;
    esac
  fi

  note "PASS GOAL-GATE git-path $evidence"
}

check_powershell_parser() {
  local evidence="$EVIDENCE_DIR/goal-gate-powershell-parser.txt"
  local win_root win_qa ps_root ps_qa ps_command
  win_root="$(to_windows_path "$ROOT/windows")"
  win_qa="$(to_windows_path "$ROOT/scripts/qa")"
  ps_root="${win_root//\'/\'\'}"
  ps_qa="${win_qa//\'/\'\'}"
  ps_command="\$ErrorActionPreference='Stop'; \$roots = @('$ps_root', '$ps_qa'); \$files = @(); foreach (\$root in \$roots) { if (Test-Path \$root) { \$files += @(Get-ChildItem -Path \$root -Recurse -Include *.ps1) } }; foreach (\$file in \$files) { \$tokens=\$null; \$errors=\$null; [System.Management.Automation.Language.Parser]::ParseFile(\$file.FullName, [ref]\$tokens, [ref]\$errors) | Out-Null; if (\$errors.Count -gt 0) { throw (\"{0}: {1}\" -f \$file.FullName, (\$errors | Select-Object -First 1).Message) } }; \"FILES_PARSED: \$([int]\$files.Count)\""
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command "$ps_command" > "$evidence" 2>&1
    note "PASS GOAL-GATE powershell-parser $evidence"
    return
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ps_command" > "$evidence" 2>&1
    note "PASS GOAL-GATE winpowershell-parser $evidence"
    return
  fi

  printf 'SKIP GOAL-GATE powershell-parser: PowerShell is not available.\n' > "$evidence"
  note "SKIP GOAL-GATE powershell-parser $evidence"
}

run_windows_approval_gate() {
  local mode="$1" script_path
  script_path="$(to_windows_path "$QA_DIR/beginner-approval-gate-windows.ps1")"
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -File "$script_path" -Mode "$mode"
    return
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script_path" -Mode "$mode"
    return
  fi

  fail "PowerShell is required for beginner approval Windows scenario"
}

check_spec_contract() {
  contains_file "$ROOT/AGENTS.md" 'Goal Gate\(목표 게이트\)' 'AGENTS.md must force the Goal Gate before final output'
  contains_file "$ROOT/AGENTS.md" 'scripts/qa/goal-mode-gate\.sh --quick' 'AGENTS.md must name the quick gate command'
  contains_file "$ROOT/AGENTS.md" 'Do not produce final/completion output|최종 완료 답변' 'AGENTS.md must block completion output on gate failure'
  contains_file "$ROOT/docs/goal-mode-quality-gate.md" '/goal' 'Goal mode documentation must describe /goal usage'
  contains_file "$ROOT/docs/goal-mode-quality-gate.md" 'scripts/qa/goal-mode-gate\.sh --full' 'Goal mode documentation must include the full gate'
  contains_file "$ROOT/.githooks/pre-commit" 'goal-mode-gate\.sh.*--quick' 'pre-commit must run the quick gate'
  contains_file "$ROOT/.githooks/pre-commit" 'GOAL_GATE_DIFF_CONTEXT=staged' 'pre-commit must check the staged diff'
  contains_file "$ROOT/.githooks/pre-push" 'goal-mode-gate\.sh.*--full' 'pre-push must run the full gate'
  contains_file "$ROOT/README.md" 'Goal Gate\(목표 게이트\)' 'README must link the Goal Gate'
  contains_file "$ROOT/.github/workflows/ci.yml" 'goal-mode-gate\.sh --quick' 'CI must run the Goal Gate'
  contains_file "$ROOT/.github/workflows/ci.yml" 'GOAL_GATE_DIFF_CONTEXT: ci' 'CI must run the Goal Gate with CI diff context'

  contains_file "$ROOT/docs/team-beginner-standard-install.md" '설치해줘' 'Beginner standard must accept short install prompts'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" '설치 시작해줘' 'Beginner standard must accept short start prompts'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" '1\) Windows' 'Beginner standard OS question must include Windows'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" '2\) Linux' 'Beginner standard OS question must include Linux'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" '기본 환경을 전체 설치할까요' 'Beginner basic environment question must be simplified'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" 'Codex CLI 설치' 'AI tools must ask about Codex CLI'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" 'Claude Code CLI 설치' 'AI tools must ask about Claude Code CLI'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" 'Final Installation Plan\(최종 설치 계획\)' 'Final Installation Plan must be required'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" '승인.*진행|진행.*승인' 'Approval words must be documented'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" 'latest-report\.md' 'Install completion report must be documented'
  contains_file "$ROOT/docs/team-beginner-standard-install.md" 'manual/index\.html' 'HTML manual must be documented'

  contains_file "$ROOT/install.sh" 'generate_completion_report' 'macOS/root installer must generate the completion report'
  contains_file "$ROOT/linux/install.sh" 'generate_completion_report' 'Linux installer must generate the completion report'
  contains_file "$ROOT/windows/install.ps1" 'Write-CompletionReport' 'Windows installer must generate the completion report'
  contains_file "$ROOT/lib/report.sh" 'Pretendard' 'Bash HTML manual must prefer Pretendard'
  contains_file "$ROOT/windows/scripts/report.ps1" 'Pretendard' 'Windows HTML manual must prefer Pretendard'
  contains_file "$ROOT/lib/report.sh" '--blue: #0057ff' 'Bash HTML manual must use the approved blue'
  contains_file "$ROOT/windows/scripts/report.ps1" '--blue: #0057ff' 'Windows HTML manual must use the approved blue'
  contains_file "$ROOT/lib/report.sh" 'border-radius: 16px' 'Bash HTML manual must use rounded surfaces'
  contains_file "$ROOT/windows/scripts/report.ps1" 'border-radius: 16px' 'Windows HTML manual must use rounded surfaces'

  contains_file "$ROOT/lib/recommendations.sh" 'Superpowers Planning Pack' 'Superpowers must be mapped as a planning pack'
  contains_file "$ROOT/windows/scripts/recommendations.ps1" 'Superpowers Planning Pack' 'Windows Superpowers must be mapped as a planning pack'
  not_contains_file "$ROOT/lib/recommendations.sh" 'Debug/Verify Pack|systematic-debugging|verification-before-completion' 'Bash recommendations must not use the retired Superpowers debug pack'
  not_contains_file "$ROOT/windows/scripts/recommendations.ps1" 'Debug/Verify Pack|systematic-debugging|verification-before-completion' 'Windows recommendations must not use the retired Superpowers debug pack'

  note "PASS GOAL-GATE spec-contract"
}

check_bash_syntax() {
  local file tmp status=0
  for file in \
    "$ROOT/install.sh" \
    "$ROOT/linux/install.sh" \
    "$ROOT/uninstall.sh" \
    "$ROOT/linux/uninstall.sh" \
    "$ROOT"/lib/*.sh \
    "$ROOT"/scripts/*.sh \
    "$ROOT"/scripts/qa/*.sh \
    "$ROOT"/linux/scripts/*.sh \
    "$ROOT/config/zshrc.block.sh" \
    "$ROOT/linux/config/zshrc.block.sh"; do
    tmp="$(mktemp)"
    tr -d '\r' < "$file" > "$tmp"
    bash -n "$tmp" || status=1
    rm -f "$tmp"
  done
  return "$status"
}

check_spec_contract

if [[ "$mode" == "spec" ]]; then
  note "PASS GOAL-GATE"
  exit 0
fi

if [[ "$mode" == "path-checks" ]]; then
  check_goal_git_contract
  check_to_windows_path_contract
  check_powershell_parser
  note "PASS GOAL-GATE"
  exit 0
fi

check_executable_modes
check_goal_git_contract
run_gate_cmd "diff-check" "$EVIDENCE_DIR/goal-gate-diff-check.txt" check_diff_whitespace
run_gate_cmd "bash-syntax" "$EVIDENCE_DIR/goal-gate-bash-syntax.txt" check_bash_syntax
check_to_windows_path_contract
check_powershell_parser
run_gate_cmd "beginner-state-contract-bash" "$EVIDENCE_DIR/goal-gate-beginner-state-contract-bash.txt" bash "$QA_DIR/beginner-approval-gate-bash.sh" --state-contract
run_gate_cmd "beginner-standard-bash" "$EVIDENCE_DIR/goal-gate-beginner-standard-bash.txt" bash "$QA_DIR/beginner-approval-gate-bash.sh" --standard
run_gate_cmd "beginner-approval-bash-adversarial" "$EVIDENCE_DIR/goal-gate-beginner-approval-bash-adversarial.txt" bash "$QA_DIR/beginner-approval-gate-bash.sh" --adversarial
run_gate_cmd "beginner-approval-windows-adversarial" "$EVIDENCE_DIR/goal-gate-beginner-approval-windows-adversarial.txt" run_windows_approval_gate Adversarial
run_gate_cmd "report-manual-completed" "$EVIDENCE_DIR/goal-gate-report-completed.txt" "$QA_DIR/lane3-report-manual.sh" completed
run_gate_cmd "report-manual-failed-addon" "$EVIDENCE_DIR/goal-gate-report-failed-addon.txt" "$QA_DIR/lane3-report-manual.sh" failed-addon
run_gate_cmd "report-manual-html" "$EVIDENCE_DIR/goal-gate-report-html.txt" "$QA_DIR/lane3-report-manual.sh" html-assert
run_gate_cmd "docs-first-run" "$EVIDENCE_DIR/goal-gate-docs-first-run.txt" "$QA_DIR/lane3-docs-content.sh" first-run
run_gate_cmd "windows-virtual-smoke" "$EVIDENCE_DIR/goal-gate-windows-virtual-smoke.txt" "$QA_DIR/lane3-windows-virtual-smoke.sh"

if [[ "$mode" == "full" ]]; then
  run_gate_cmd "lane3-all" "$EVIDENCE_DIR/goal-gate-lane3-all.txt" "$QA_DIR/lane3-all.sh"
fi

note "PASS GOAL-GATE"
