#!/usr/bin/env bash
_github_signup() {
  local platform="$1" url="https://github.com/signup"
  if [[ "$DRY_RUN" == "1" ]]; then
    case "$platform" in
      linux) info "[dry-run] xdg-open $url" ;;
      *) info "[dry-run] open $url" ;;
    esac
    return 0
  fi
  case "$platform" in
    linux)
      if have xdg-open; then run xdg-open "$url"; else info "$url"; fi ;;
    *)
      if have open; then run open "$url"; else info "$url"; fi ;;
  esac
}

wizard_step_github() {
  local platform="$1" choice
  while :; do
    step "2단계 GitHub 연결"
    printf 'GitHub를 연결하면 오픈소스 도구 설치와 저장소 작업이 더 매끄럽습니다.\n'
    printf '1) 연결하기\n2) 가입 링크 열기\n3) 지금은 건너뛰기\n4) 상태만 보기\n'
    choice="$(_wizard_choice '선택:' 3)"
    case "$choice" in
      1)
        if [[ "${BSS_AI_HELPER_QA_GH:-}" == "missing" ]]; then
          warn "gh CLI가 없습니다. 1단계 기본 설치에서 gh를 설치한 뒤 다시 시도할 수 있습니다."
          state_set_step_status github failed "gh CLI 없음"
          if _recovery_menu github "GitHub 연결"; then return 0; fi
          continue
        fi
        if [[ "$DRY_RUN" == "1" || "${BSS_AI_HELPER_QA_GH:-}" == "success" ]]; then
          info "[dry-run] gh auth login"
          info "[dry-run] gh auth status"
          state_set_step_status github complete "gh auth login 확인"
          ok "GitHub 연결 준비가 끝났습니다."
          return 0
        fi
        if ! have gh; then
          warn "gh CLI가 없습니다. 1단계 기본 설치를 먼저 실행하세요."
          state_set_step_status github failed "gh CLI 없음"
          if _recovery_menu github "GitHub 연결"; then return 0; fi
          continue
        fi
        if gh auth status >/dev/null 2>&1; then
          state_set_step_status github complete "이미 로그인됨"
          ok "GitHub에 이미 연결되어 있습니다."
          return 0
        fi
        if gh auth login && gh auth status >/dev/null 2>&1; then
          state_set_step_status github complete "gh auth login 완료"
          ok "GitHub 연결을 확인했습니다."
          return 0
        fi
        state_set_step_status github failed "gh auth login 실패"
        if _recovery_menu github "GitHub 연결"; then return 0; fi
        ;;
      2)
        _github_signup "$platform"
        info "가입을 마쳤으면 다시 연결하기를 선택하세요." ;;
      4)
        show_status ;;
      *)
        warn "GitHub를 건너뛰면 나중에 오픈소스 설치나 저장소 작업이 덜 매끄러울 수 있습니다."
        state_set_step_status github skipped "사용자가 지금은 건너뜀"
        return 0 ;;
    esac
  done
}
