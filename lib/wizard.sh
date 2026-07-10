#!/usr/bin/env bash
_WIZARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_WIZARD_LIB_DIR/state.sh"
source "$_WIZARD_LIB_DIR/recommendations.sh"
source "$_WIZARD_LIB_DIR/wizard-common.sh"
source "$_WIZARD_LIB_DIR/wizard-base.sh"
source "$_WIZARD_LIB_DIR/wizard-github.sh"
source "$_WIZARD_LIB_DIR/wizard-ai.sh"
source "$_WIZARD_LIB_DIR/wizard-addons.sh"
source "$_WIZARD_LIB_DIR/wizard-plan.sh"

run_wizard() {
  local platform="${1:-macos}" choice
  if ! state_init; then
    warn "state.json을 읽을 수 없습니다. 파일은 삭제하지 않았습니다."
    show_status
    return 0
  fi
  step "ai-boiler-plate 질문형 설치"
  info "한 번에 전부 설치하지 않고 필요한 항목을 질문으로 확인합니다."
  printf '  1) 상태만 보기\n'
  printf '  2) Final Installation Plan(최종 설치 계획) 만들기\n'
  printf '  3) GitHub, AI 도구, 추가 도구 설정\n'
  printf '  4) 기존 설치 방식으로 실행\n'
  printf '  5) 종료\n'
  choice="$(_wizard_choice '선택 [1]:' 1)"
  case "$choice" in
    1|"상태"|"상태만 보기")
      show_status
      ;;
    2|"기본"|"설치")
      wizard_plan_collect_approve_execute "$platform"
      ok "질문형 설치를 마쳤습니다. 상태 파일: $(state_path)"
      ;;
    3|"AI"|"ai")
      wizard_step_github "$platform"
      wizard_step_ai_tools "$platform"
      wizard_step_addons "$platform"
      ok "질문형 설정을 마쳤습니다. 상태 파일: $(state_path)"
      ;;
    4|"기존"|"classic")
      return 2
      ;;
    5|"종료"|"끝")
      info "종료합니다."
      ;;
    *)
      warn "알 수 없는 선택입니다. 상태만 표시합니다."
      show_status
      ;;
  esac
}
