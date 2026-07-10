#!/usr/bin/env bash

_wizard_plan_default_workspace() {
  case "$1" in
    Windows) printf 'C:\\Users\\<사용자>\\Documents\\Codex\\bss-ai-boiler-plate\n' ;;
    *) printf '%s/Documents/Codex/bss-ai-boiler-plate\n' "$HOME" ;;
  esac
}

_wizard_plan_command() {
  case "$1" in
    Windows) printf '.\\windows\\install.ps1 -Standard\n' ;;
    Linux) printf './linux/install.sh --standard\n' ;;
    *) printf './install.sh --standard\n' ;;
  esac
}

_wizard_plan_collect_os() {
  local platform="$1" choice def=2
  step "1단계 OS(운영체제) 선택"
  info "Windows는 대부분의 개인용 PC에서 쓰는 운영체제입니다."
  info "Linux는 서버나 개발용 컴퓨터에서 자주 쓰는 운영체제입니다."
  [[ "$platform" == "macos" ]] && def=2
  printf '1) Windows\n2) Linux\n'
  choice="$(_wizard_choice '선택 [2]:' "$def")"
  case "$choice" in
    1|Windows|windows) WIZARD_PLAN_OS="Windows" ;;
    *) WIZARD_PLAN_OS="Linux" ;;
  esac
}

_wizard_plan_collect_base() {
  local choice
  step "2단계 Basic Environment(기본 환경)"
  info "기본 환경은 개발 도구가 실행될 바탕 프로그램입니다."
  info "패키지는 필요한 프로그램을 내려받아 설치하는 묶음입니다."
  info "런타임은 Node.js나 Python처럼 개발 도구가 돌아가게 해주는 실행기입니다."
  info "셸은 PowerShell이나 터미널처럼 명령을 입력하는 창입니다."
  printf '기본 환경을 전체 설치할까요?\n'
  printf '1) 네, 전체 설치할게요\n'
  printf '2) 설치하지 않을게요\n'
  choice="$(_wizard_choice '선택 [1]:' 1)"
  case "$choice" in
    1|"네"|"네, 전체 설치할게요"|"전체 설치") WIZARD_PLAN_BASE="install" ;;
    *) WIZARD_PLAN_BASE="skip" ;;
  esac
}

_wizard_plan_collect_ai() {
  local choice
  WIZARD_PLAN_AI_SERVICES=""
  WIZARD_PLAN_CODEX=0
  WIZARD_PLAN_CLAUDE=0
  step "3단계 AI CLI tools(AI CLI 도구)"
  printf 'Codex 앱은 이미 설치했다고 보고, 터미널에서 쓰는 CLI 명령만 확인합니다.\n'
  printf '1) Codex CLI 설치\n2) Claude Code CLI 설치\n3) Codex CLI + Claude Code CLI 설치\n4) CLI 도구는 설치하지 않음\n'
  choice="$(_wizard_choice '선택 [1]:' 1)"
  case "$choice" in
    1) WIZARD_PLAN_AI_SERVICES="Codex CLI"; WIZARD_PLAN_CODEX=1 ;;
    2) WIZARD_PLAN_AI_SERVICES="Claude Code CLI"; WIZARD_PLAN_CLAUDE=1 ;;
    3) WIZARD_PLAN_AI_SERVICES="Codex CLI,Claude Code CLI"; WIZARD_PLAN_CODEX=1; WIZARD_PLAN_CLAUDE=1 ;;
    *) WIZARD_PLAN_AI_SERVICES="" ;;
  esac
}

_wizard_plan_collect_addons() {
  local id choice title
  WIZARD_PLAN_ADDONS=""
  step "4단계 Add-ons(추가 기능)"
  for id in matt-pocock-skills superpowers lazy-codex oh-my-claudecode; do
    title="$(recommendation_title "$id")"
    case "$id" in
      matt-pocock-skills)
        printf '질문: 무엇부터 해야 할지 잘 모를 때, 체계적으로 설계하고 작업할 수 있게 도와주는 스킬인 Matt Pocock Skills를 설치할까요?\n' ;;
      superpowers)
        printf '질문: 아이디어가 있을 때 아이디어를 구체화해서 작업 계획까지 세워주는 스킬인 Superpowers를 설치할까요?\n' ;;
      lazy-codex)
        printf '질문: Codex를 사용할 때 코딩, 수정, 검증 작업을 구조적으로 도와주는 도구인 Lazy-Codex를 설치할까요?\n' ;;
      oh-my-claudecode)
        printf '질문: Claude Code 사용을 쉽게 도와주는 도구인 Oh-My-Claudecode를 설치할까요?\n' ;;
    esac
    printf '1) 네 설치할게요\n2) 설치하지 않을게요\n'
    choice="$(_wizard_choice '선택 [2]:' 2)"
    if [[ "$choice" == "1" || "$choice" == "네" || "$choice" == "네 설치할게요" ]]; then
      WIZARD_PLAN_ADDONS="${WIZARD_PLAN_ADDONS:+$WIZARD_PLAN_ADDONS,}$id"
      info "$title: 설치로 계획에 추가했습니다."
    else
      info "$title: 설치하지 않음으로 계획에 기록합니다."
    fi
  done
}

_wizard_plan_render() {
  local ai_label addons_label command workspace id title decision
  ai_label="${WIZARD_PLAN_AI_SERVICES:-설치하지 않음}"
  addons_label="${WIZARD_PLAN_ADDONS:-}"
  command="$(_wizard_plan_command "$WIZARD_PLAN_OS")"
  workspace="$(_wizard_plan_default_workspace "$WIZARD_PLAN_OS")"

  state_record_installation_plan \
    "$WIZARD_PLAN_OS" \
    "$workspace" \
    "$WIZARD_PLAN_BASE" \
    "$WIZARD_PLAN_AI_SERVICES" \
    "$WIZARD_PLAN_ADDONS" \
    "$command"

  printf '\n설치 전 계획부터 확인할게요.\n'
  printf 'Final Installation Plan(최종 설치 계획)\n'
  printf -- '- 선택한 OS(운영체제): %s\n' "$WIZARD_PLAN_OS"
  printf -- '- 생성할 workspace folder(작업 폴더): %s\n' "$workspace"
  if [[ "$WIZARD_PLAN_BASE" == "install" ]]; then
    printf -- '- Basic Environment(기본 환경): 전체 설치\n'
  else
    printf -- '- Basic Environment(기본 환경): 설치하지 않음\n'
  fi
  printf -- '- AI CLI tools(AI CLI 도구): %s\n' "$ai_label"
  printf -- '- Add-ons(추가 기능):\n'
  for id in matt-pocock-skills superpowers lazy-codex oh-my-claudecode; do
    title="$(recommendation_title "$id")"
    decision="설치하지 않음"
    [[ ",$addons_label," == *",$id,"* ]] && decision="설치"
    printf '  - %s: %s\n' "$title" "$decision"
  done
  printf -- '- 실행 command(명령): %s\n' "$command"
  printf -- '- 확인 사항: 승인 전에는 mkdir, git clone, install.sh, add-on install 명령을 실행하지 않습니다.\n'
  printf '시작하려면 "승인" 또는 "진행"이라고 입력해주세요.\n'
}

_wizard_plan_execute_base() {
  local platform="$1" package_step
  if [[ "$WIZARD_PLAN_BASE" != "install" ]]; then
    state_set_step_status base-tools skipped "$platform"
    state_append_history base-tools skipped "$platform"
    state_set_step_status shell skipped "$platform"
    state_append_history shell skipped "$platform"
    return 0
  fi
  package_step="$(_wizard_base_package_step "$platform")"
  state_set_step_status base-tools in_progress
  _wizard_run_step prereqs
  _wizard_run_step "$package_step"
  _wizard_run_step runtimes
  _wizard_run_step shell
  state_set_step_status base-tools complete "$platform dry-run=$DRY_RUN"
  state_append_history base-tools complete "$platform dry-run=$DRY_RUN"
  state_set_step_status shell complete "$platform dry-run=$DRY_RUN"
  state_append_history shell complete "$platform dry-run=$DRY_RUN"
}

_wizard_plan_execute_ai() {
  local platform="$1" old_ifs
  if [[ -z "$WIZARD_PLAN_AI_SERVICES" ]]; then
    state_record_ai_services
    state_set_step_status ai-tools skipped "CLI 도구 설치하지 않음"
    return 0
  fi
  old_ifs="$IFS"
  IFS=','
  state_record_ai_services $WIZARD_PLAN_AI_SERVICES
  IFS="$old_ifs"
  _run_primary_ai_install_with_recovery "$platform" "$WIZARD_PLAN_CODEX" "$WIZARD_PLAN_CLAUDE" "$WIZARD_PLAN_AI_SERVICES"
}

_wizard_plan_execute_addons() {
  local id title selected_any=0
  for id in matt-pocock-skills superpowers lazy-codex oh-my-claudecode; do
    title="$(recommendation_title "$id")"
    if [[ ",$WIZARD_PLAN_ADDONS," == *",$id,"* ]]; then
      selected_any=1
      _install_addon "$id"
      case "${ADDON_LAST_STATUS:-failed}" in
        complete) state_set_step_status addons complete "$title 처리" ;;
        skipped) state_set_step_status addons skipped "$title 건너뜀" ;;
        *) state_set_step_status addons failed "$title 실패" ;;
      esac
    else
      state_record_addon "$id" "$title" skipped "사용자가 설치하지 않음"
    fi
  done
  [[ "$selected_any" == "1" ]] || state_set_step_status addons skipped "추가 기능 설치하지 않음"
}

_wizard_plan_execute() {
  local platform="$1"
  if [[ "$WIZARD_PLAN_OS" == "Windows" ]]; then
    info "Windows 계획이 승인되었습니다. Windows PowerShell에서 .\\windows\\install.ps1 -Standard 를 실행하세요."
    return 0
  fi
  _wizard_plan_execute_base "$platform"
  _wizard_plan_execute_ai "$platform"
  _wizard_plan_execute_addons
}

wizard_plan_collect_approve_execute() {
  local platform="$1" approval
  _wizard_plan_collect_os "$platform"
  _wizard_plan_collect_base
  _wizard_plan_collect_ai
  _wizard_plan_collect_addons
  _wizard_plan_render
  approval="$(_wizard_choice '승인 입력:' '')"
  case "$approval" in
    "승인"|"진행")
      state_approve_installation_plan
      ok "Final Installation Plan(최종 설치 계획)을 승인했습니다."
      _wizard_plan_execute "$platform"
      ;;
    *)
      warn "승인되지 않아 설치를 시작하지 않았습니다."
      return 0
      ;;
  esac
}
