#!/usr/bin/env bash
#
# ai-boiler-plate — install the Linux development environment.
# From a fresh box → build tools, CLI, runtimes, shell, Docker, AI agents.
#
# Usage:
#   ./install.sh [options]
#   AI_BOILER_PLATE_REPO=<repo-url> ./install.sh
#   BSS_BOILERPLATE_* and STARTER_KIT_* remain deprecated compatibility envs.
#
# Options:
#   --dry-run        Show what would happen, change nothing.
#   --yes, -y        Non-interactive: accept defaults, never prompt.
#   --standard       Run an approved Final Installation Plan.
#   --only  a,b,c    Run only these steps.
#   --skip  a,b,c    Run all steps except these.
#   --no-agents      Shortcut for --skip agents.
#   --status         Show saved ai-boiler-plate progress and exit.
#   --reset-state    Ask before deleting saved resume state.
#   --classic        Run the classic step installer.
#   --wizard         Reserved for the question wizard lanes.
#   --list           List step ids and exit.
#   --version, -V    Print the kit version and exit.
#   --help, -h       Show this help.
#
# Steps (in order): prereqs packages runtimes shell docker git agents
#
# Supported package managers: apt · dnf/yum · pacman · zypper (glibc distros).
# Alpine/musl (apk) is not supported (upstream node/ast-grep/bun lack musl builds).
#
set -euo pipefail

REPO_URL="${AI_BOILER_PLATE_REPO:-${BSS_BOILERPLATE_REPO:-${STARTER_KIT_REPO:-https://github.com/socialsolidaritybank/ai-boiler-plate.git}}}"
REPO_BRANCH="${AI_BOILER_PLATE_BRANCH:-${BSS_BOILERPLATE_BRANCH:-${STARTER_KIT_BRANCH:-main}}}"
STANDARD_REQUESTED=0
for arg in "$@"; do
  [[ "$arg" == "--standard" ]] && STANDARD_REQUESTED=1
done
DEFAULT_CLONE_DIR="$HOME/ai-boiler-plate"
[[ "$STANDARD_REQUESTED" == "1" ]] && DEFAULT_CLONE_DIR="$HOME/Documents/Codex/bss-ai-boiler-plate"
CLONE_DIR="${AI_BOILER_PLATE_DIR:-${BSS_BOILERPLATE_DIR:-${STARTER_KIT_DIR:-$DEFAULT_CLONE_DIR}}}"

# ---------------------------------------------------------------------------
# Resolve the repo root (the linux/ dir), or bootstrap by cloning (curl | bash).
# ---------------------------------------------------------------------------
resolve_root() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" ]]; then
    local dir; dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd || true)"
    if [[ -n "$dir" && -f "$dir/scripts/lib.sh" ]]; then
      echo "$dir"; return 0
    fi
  fi
  # Running piped from curl: clone (or update) and hand off to linux/install.sh.
  echo "==> Bootstrapping ai-boiler-plate into $CLONE_DIR" >&2
  if ! command -v git >/dev/null 2>&1; then
    echo "==> git not found. Install git first (e.g. sudo apt-get install -y git), then re-run." >&2
    exit 1
  fi
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only origin "$REPO_BRANCH" >&2 || true
  else
    mkdir -p "$(dirname "$CLONE_DIR")"
    git clone --branch "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >&2
  fi
  echo "$CLONE_DIR/linux"
}

ROOT="$(resolve_root)"
LINUX_ROOT="$ROOT"
KIT_ROOT="$(cd "$LINUX_ROOT/.." && pwd)"
# Resolve this script's own absolute path (empty when piped from curl).
SELF=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)/$(basename "${BASH_SOURCE[0]}")"
fi
# If we bootstrapped (cloned), hand off to the cloned copy with the original args.
if [[ "$SELF" != "$ROOT/install.sh" && -f "$ROOT/install.sh" ]]; then
  exec bash "$ROOT/install.sh" "$@"
fi

# shellcheck source=scripts/lib.sh
source "$LINUX_ROOT/scripts/lib.sh"
source "$KIT_ROOT/lib/wizard.sh"
source "$KIT_ROOT/lib/state.sh"

KIT_VERSION="$(cat "$KIT_ROOT/VERSION" 2>/dev/null || echo dev)"

# ---------------------------------------------------------------------------
# Step registry
# ---------------------------------------------------------------------------
STEP_IDS=(prereqs packages runtimes shell docker git agents resume)

# step_file <id> -> the scripts/NN-*.sh filename for that step
step_file() {
  case "$1" in
    prereqs)  echo 01-prereqs.sh ;;
    packages) echo 02-packages.sh ;;
    runtimes) echo 03-runtimes.sh ;;
    shell)    echo 04-shell.sh ;;
    docker)   echo 05-docker.sh ;;
    git)      echo 06-git.sh ;;
    agents)   echo 07-agents.sh ;;
    resume)   echo 09-codex-resume.sh ;;
    *) return 1 ;;
  esac
}

# usage — print the leading comment block (skip the shebang, stop at the first
# non-comment line) so --help never leaks code that follows the header.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$LINUX_ROOT/install.sh"; }

_append_skip() {
  local id="$1"
  [[ ",$SKIP," == *",$id,"* ]] && return 0
  SKIP="${SKIP:+$SKIP,}$id"
}

configure_standard_plan() {
  local expected_os="$1" package_step="$2" status plan_os base ai_tools
  state_init || die "state.json을 읽을 수 없어 --standard를 실행하지 않았습니다."
  status="$(state_installation_plan_status)"
  if [[ "$status" != "approved" ]]; then
    info "--standard is the Standard Execution Preset for an approved Final Installation Plan."
    info "승인된 Final Installation Plan(최종 설치 계획)이 없어 설치를 시작하지 않았습니다."
    info "먼저 --wizard로 계획을 만들고 마지막에 '승인' 또는 '진행'을 입력하세요."
    exit 2
  fi

  plan_os="$(state_installation_plan_field selectedOS)"
  if [[ "$plan_os" != "$expected_os" ]]; then
    info "승인된 plan은 $plan_os 용입니다. 이 installer는 $expected_os 용이라 실행하지 않습니다."
    info "Plan의 실행 command: $(state_installation_plan_field executionCommand)"
    exit 2
  fi

  CLASSIC=1
  DIRECT_MODE=1
  export ASSUME_YES=1
  _append_skip docker

  base="$(state_installation_plan_field baseEnvironment)"
  if [[ "$base" != "install" ]]; then
    _append_skip prereqs
    _append_skip "$package_step"
    _append_skip runtimes
    _append_skip shell
    _append_skip git
    _append_skip resume
  fi

  export BSS_AI_INSTALL_CODEX=0 BSS_AI_INSTALL_CLAUDE=0 BSS_AI_INSTALL_MATT=0 BSS_AI_INSTALL_EXTRAS=0 HERMES=0
  if state_installation_plan_has_ai "Codex CLI"; then
    export BSS_AI_INSTALL_CODEX=1
  fi
  if state_installation_plan_has_ai "Claude Code CLI"; then
    export BSS_AI_INSTALL_CLAUDE=1
  fi
  ai_tools="$(state_installation_plan_field aiCliTools)"
  if [[ -z "$ai_tools" ]]; then
    _append_skip agents
  fi
  info "Using approved Final Installation Plan: $(state_installation_plan_field executionCommand)"
}

run_standard_plan_addons() {
  local id found=0
  [[ "$STANDARD" == "1" ]] || return 0
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    found=1
    _install_addon "$id"
  done < <(state_installation_plan_selected_addons)
  [[ "$found" == "1" ]] || state_set_step_status addons skipped "추가 기능 설치하지 않음" || true
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ONLY=""; SKIP=""; STATUS=0; RESET_STATE=0; WIZARD=0; CLASSIC=0; DIRECT_MODE=0; STANDARD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   export DRY_RUN=1 ;;
    -y|--yes)    export ASSUME_YES=1; DIRECT_MODE=1 ;;
    --standard)
      STANDARD=1
      ;;
    --status)    STATUS=1 ;;
    --reset-state) RESET_STATE=1 ;;
    --classic)   CLASSIC=1; DIRECT_MODE=1 ;;
    --wizard)    WIZARD=1 ;;
    --only)      ONLY="${2:-}"; shift; DIRECT_MODE=1 ;;
    --only=*)    ONLY="${1#*=}"; DIRECT_MODE=1 ;;
    --skip)      SKIP="${2:-}"; shift; DIRECT_MODE=1 ;;
    --skip=*)    SKIP="${1#*=}"; DIRECT_MODE=1 ;;
    --no-agents) SKIP="${SKIP:+$SKIP,}agents"; DIRECT_MODE=1 ;;
    --list)      printf '%s\n' "${STEP_IDS[@]}"; exit 0 ;;
    -V|--version) echo "ai-boiler-plate $KIT_VERSION"; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# Normalize --only/--skip (strip spaces so `--only "brew, shell"` works), then
# reject any unknown token up front instead of silently selecting nothing.
ONLY="${ONLY// /}"; SKIP="${SKIP// /}"
_validate_ids() {
  local list="$1" tok id found valid="${STEP_IDS[*]}"
  while [[ -n "$list" ]]; do
    tok="${list%%,*}"
    if [[ "$list" == *,* ]]; then list="${list#*,}"; else list=""; fi
    [[ -z "$tok" ]] && continue
    found=0
    for id in "${STEP_IDS[@]}"; do [[ "$id" == "$tok" ]] && found=1; done
    [[ "$found" == 1 ]] || die "unknown step id: '$tok' (valid: $valid)"
  done
}
if [[ "$STATUS" == "1" ]]; then
  bss_show_status
  exit 0
fi
if [[ "$RESET_STATE" == "1" ]]; then
  bss_reset_state
  exit 0
fi
if [[ "$STANDARD" == "1" ]]; then
  configure_standard_plan "Linux" "packages"
fi
[[ -n "$ONLY" ]] && _validate_ids "$ONLY"
[[ -n "$SKIP" ]] && _validate_ids "$SKIP"
if [[ "$WIZARD" == "1" || ( "$CLASSIC" != "1" && "$DIRECT_MODE" != "1" && -t 0 ) ]]; then
  if run_wizard linux; then
    exit 0
  else
    wizard_code=$?
    [[ "$wizard_code" == 2 ]] || exit "$wizard_code"
  fi
fi

# Build the active step list honouring --only / --skip
selected() {
  local id keep
  for id in "${STEP_IDS[@]}"; do
    if [[ -n "$ONLY" ]]; then
      [[ ",$ONLY," == *",$id,"* ]] && echo "$id"
    else
      keep=1
      [[ -n "$SKIP" && ",$SKIP," == *",$id,"* ]] && keep=0
      [[ "$keep" == 1 ]] && echo "$id"
    fi
  done
}

generate_completion_report() {
  local report_lib="$KIT_ROOT/lib/report.sh"
  if [[ ! -f "$report_lib" ]]; then
    warn "설치 결과 리포트 생성기를 찾지 못했습니다: $report_lib"
    return 0
  fi
  # shellcheck source=/dev/null
  source "$report_lib"
  if bss_generate_report; then
    info "결과 리포트: $(bss_report_path)"
    info "HTML 사용 매뉴얼: $(bss_manual_path)"
  else
    warn "설치는 끝났지만 결과 리포트/HTML 매뉴얼 생성은 실패했습니다. python3와 state 파일을 확인해 주세요."
  fi
}

set_aggregate_step_status() {
  local selected_steps="$1" step_id="$2" complete_note="$3" skipped_note="$4"
  shift 4
  local required_count=0 selected_count=0 id selected_names=()
  for id in "$@"; do
    required_count=$((required_count + 1))
    if [[ "$selected_steps" == *" $id "* ]]; then
      selected_count=$((selected_count + 1))
      selected_names+=("$id")
    fi
  done

  if [[ "$selected_count" -eq "$required_count" ]]; then
    state_set_step_status "$step_id" complete "$complete_note" || true
  elif [[ "$selected_count" -gt 0 ]]; then
    state_set_step_status "$step_id" partial "partial: ${selected_names[*]}" || true
  else
    state_set_step_status "$step_id" skipped "$skipped_note" || true
  fi
}

record_completion_state() {
  local selected_steps service_list
  selected_steps=" $(selected | tr '\n' ' ') "
  state_init || true

  set_aggregate_step_status "$selected_steps" base-tools "Linux base environment complete" "Linux base environment not selected" prereqs packages runtimes
  set_aggregate_step_status "$selected_steps" shell "zsh/profile/restart setup complete" "shell setup not selected" shell resume
  if [[ "$selected_steps" == *" prereqs "* && "$selected_steps" == *" packages "* && "$selected_steps" == *" runtimes "* ]]; then
    state_set_step_status base-tools complete "Linux 기본 환경 설치 완료" || true
  fi
  if [[ "$selected_steps" == *" shell "* && "$selected_steps" == *" resume "* ]]; then
    state_set_step_status shell complete "zsh/profile/restart 설정 완료" || true
  fi
  if [[ "$selected_steps" == *" git "* ]]; then
    state_set_step_status github complete "Git/GitHub 기본 설정 완료" || true
  fi
  if [[ "$selected_steps" == *" agents "* ]]; then
    service_list=()
    [[ "${BSS_AI_INSTALL_CODEX:-1}" != "0" ]] && service_list+=("Codex")
    [[ "${BSS_AI_INSTALL_CLAUDE:-1}" != "0" ]] && service_list+=("Claude")
    if [[ "${#service_list[@]}" -gt 0 ]]; then
      state_record_ai_services "${service_list[@]}" || true
      state_set_step_status ai-tools complete "${service_list[*]}" || true
    else
      state_set_step_status ai-tools skipped "AI CLI 도구 설치하지 않음" || true
    fi
  else
    state_set_step_status ai-tools skipped "agents step skipped" || true
  fi
  state_set_step_status addons skipped "추가 기능은 명시적으로 선택할 때만 설치" || true
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
is_linux || die "This kit targets Linux only (macOS users: use the repo root install.sh)."
[[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN: no changes will be made."

printf '%s\n' "$_C_BOLD== ai-boiler-plate v$KIT_VERSION ==$_C_RESET"
info "steps: $(selected | tr '\n' ' ')"

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
for id in $(selected); do
  file="$LINUX_ROOT/scripts/$(step_file "$id")"
  fn="step_$id"
  [[ -f "$file" ]] || die "missing step file: $file"
  # shellcheck disable=SC1090
  source "$file"
  "$fn"
done

run_standard_plan_addons

if [[ "${DRY_RUN:-0}" != "1" ]]; then
  step "Install result manual"
  record_completion_state
  generate_completion_report
fi

step "Done."
if [[ "$DRY_RUN" == "1" ]]; then
  info "That was a dry run — re-run without --dry-run to apply."
else
  step "Next steps"
  info "1) Open a NEW terminal (or: source ~/.zshrc) so PATH + prompt load."
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    info "2) Sign in to GitHub:  gh auth login   (also sets your git identity)"
  fi
  if command -v docker >/dev/null 2>&1 && ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    info "3) Docker: log out/in (or run 'newgrp docker') so group access applies."
  fi
  info "Set your terminal font to 'JetBrainsMono Nerd Font' for prompt icons."
fi
exit 0
