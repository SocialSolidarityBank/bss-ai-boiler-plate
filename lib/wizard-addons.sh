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
  local services preference id choice another title candidates seen candidate old_ifs
  services="$(_current_services_csv)"
  step "4단계 추가 도구 추천"
  printf '원하는 도움에 가까운 항목을 고르세요.\n'
  printf '1) 강한 오케스트레이션, 멀티 서브 에이전트\n'
  printf '2) 버그 수정/완료 검증 습관 보강\n'
  printf '3) Codex로 긴 자동 설치/수정 작업\n'
  printf '4) 고급 품질 워크플로우\n'
  printf '5) 추천 없이 마치기\n'
  choice="$(_wizard_choice '선택:' 5)"
  case "$choice" in
    1) preference="orchestration" ;;
    2) preference="teacher" ;;
    3) preference="long-work" ;;
    4) preference="quality" ;;
    *) preference="none" ;;
  esac
  candidates="$(recommendation_candidates "$services" "$preference")"
  id="$(recommendation_pick "$services" "$preference")"
  [[ -n "$id" ]] || id="${candidates%%,*}"
  if [[ -z "$id" ]]; then
    info "현재 선택으로는 자동 설치할 수 있는 추가 도구가 없습니다. 기록된 서비스는 나중에 직접 확인하세요."
    state_set_step_status addons skipped "자동 설치 가능한 추천 없음"
    return 0
  fi
  seen=""
  title="$(recommendation_title "$id")"
  while :; do
    seen="${seen:+$seen,}$id"
    recommendation_show_card "$id" 0
    printf '1) 설치\n2) 나중에\n3) 설치하지 않음\n4) 자세히 보기\n5) 상태만 보기\n'
    choice="$(_wizard_choice '선택:' 2)"
    case "$choice" in
      1)
        _install_addon "$id"
        case "${ADDON_LAST_STATUS:-failed}" in
          complete) state_set_step_status addons complete "$title 처리" ;;
          skipped) state_set_step_status addons skipped "$title 건너뜀" ;;
          *) state_set_step_status addons failed "$title 실패" ;;
        esac ;;
      3)
        state_record_addon "$id" "$title" skipped "사용자가 설치하지 않음"
        state_set_step_status addons skipped "$title 설치하지 않음" ;;
      4)
        recommendation_show_details "$id"
        continue ;;
      5)
        show_status
        continue ;;
      *)
        state_record_addon "$id" "$title" pending "나중에"
        state_set_step_status addons skipped "$title 나중에" ;;
    esac
    printf '다른 추천도 볼까요?\n1) 네\n2) 아니요\n'
    another="$(_wizard_choice '선택:' 2)"
    [[ "$another" == "1" ]] || return 0
    candidate=""
    old_ifs="$IFS"
    IFS=','
    for candidate in $candidates; do
      case ",$seen," in *",$candidate,"*) candidate="" ;; esac
      [[ -n "$candidate" ]] && break
    done
    IFS="$old_ifs"
    if [[ -z "$candidate" ]]; then
      info "지금 조건에서 더 보여드릴 추천은 없습니다."
      return 0
    fi
    id="$candidate"
    title="$(recommendation_title "$id")"
  done
}
