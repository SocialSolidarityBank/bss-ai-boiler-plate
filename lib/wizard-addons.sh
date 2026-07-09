#!/usr/bin/env bash
_install_addon() {
  local id="$1" title cmd
  ADDON_LAST_STATUS=failed
  title="$(recommendation_title "$id")"
  cmd="$(recommendation_install_command "$id")" || return 1
  while :; do
    if [[ "$cmd" == "status-only" ]]; then
      info "$title은 추가 설치가 아니라 상태 확인 항목입니다."
      state_record_addon "$id" "$title" skipped "status-only"
      ADDON_LAST_STATUS=skipped
      return 0
    fi
    if [[ "${BSS_AI_HELPER_QA_INSTALL_FAIL:-}" == "permission" ]]; then
      warn "$title 설치 권한이 부족합니다. 관리자 권한이나 도구별 로그인 상태를 확인해야 합니다."
      state_record_addon "$id" "$title" failed "permission"
      if _recovery_menu "addons" "$title 설치"; then
        state_record_addon "$id" "$title" skipped "permission 후 건너뜀"
        ADDON_LAST_STATUS=skipped
        return 0
      fi
      continue
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] would run: $cmd"
      state_record_addon "$id" "$title" complete "dry-run install approved"
      ADDON_LAST_STATUS=complete
      return 0
    fi
    if eval "$cmd"; then
      state_record_addon "$id" "$title" complete "installed"
      ADDON_LAST_STATUS=complete
      return 0
    fi
    warn "$title 설치가 끝나지 않았습니다."
    state_record_addon "$id" "$title" failed "install failed"
    ADDON_LAST_STATUS=failed
    if _recovery_menu "addons" "$title 설치"; then
      state_record_addon "$id" "$title" skipped "install failed 후 건너뜀"
      ADDON_LAST_STATUS=skipped
      return 0
    fi
  done
}

wizard_step_addons() {
  local id choice title
  step "4단계 추가 도구 추천"
  printf '추가 기능은 하나씩 확인합니다. 각 항목은 설치 또는 설치하지 않음으로 기록합니다.\n'
  for id in matt-pocock-skills superpowers lazy-codex oh-my-claudecode; do
    title="$(recommendation_title "$id")"
    recommendation_show_card "$id" 0
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
    choice="$(_wizard_choice '선택:' 2)"
    case "$choice" in
      1)
        _install_addon "$id"
        case "${ADDON_LAST_STATUS:-failed}" in
          complete) state_set_step_status addons complete "$title 처리" ;;
          skipped) state_set_step_status addons skipped "$title 건너뜀" ;;
          *) state_set_step_status addons failed "$title 실패" ;;
        esac ;;
      *)
        state_record_addon "$id" "$title" skipped "사용자가 설치하지 않음"
        state_set_step_status addons skipped "$title 설치하지 않음" ;;
    esac
  done
  info "Final Installation Plan(최종 설치 계획)에는 지금까지 선택한 기본 환경, AI 도구, 추가 기능 선택 결과를 포함해야 합니다."
}
