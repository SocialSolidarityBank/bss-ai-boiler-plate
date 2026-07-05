#!/usr/bin/env bash
_sanitize_services() {
  local raw="$1" item clean out=""
  local old_ifs="$IFS"
  IFS=','
  for item in $raw; do
    clean="$(printf '%s' "$item" | tr -cd '[:print:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    clean="${clean:0:40}"
    [[ -z "$clean" ]] && continue
    if printf '%s' "$clean" | grep -Eiq '(gh[pousr]_|sk-|oauth|token|password|비밀번호)'; then
      warn "민감정보처럼 보이는 입력은 저장하지 않았습니다."
      continue
    fi
    out="${out:+$out,}$clean"
  done
  IFS="$old_ifs"
  printf '%s\n' "$out"
}

_run_primary_ai_install() {
  local platform="$1" codex="$2" claude="$3" step_file
  if [[ "$codex" != "1" && "$claude" != "1" ]]; then
    info "기본 AI 도구는 기록만 하고, 필수 Matt Pocock Skills 설정은 진행합니다."
  fi
  case "$platform" in
    linux) step_file="$ROOT/scripts/07-agents.sh" ;;
    *) step_file="$ROOT/scripts/07-agents.sh" ;;
  esac
  [[ -f "$step_file" ]] || die "missing agents step: $step_file"
  source "$step_file"
  BSS_AI_INSTALL_CODEX="$codex" \
  BSS_AI_INSTALL_CLAUDE="$claude" \
  BSS_AI_INSTALL_EXTRAS=0 \
  BSS_AI_HELPER_FORCE_INSTALL_PREVIEW=1 \
  step_agents
}

_run_primary_ai_install_with_recovery() {
  local platform="$1" codex="$2" claude="$3" services="$4" old_ifs
  while :; do
    if _run_primary_ai_install "$platform" "$codex" "$claude"; then
      old_ifs="$IFS"; IFS=','
      state_set_ai_services_status complete "" $services
      IFS="$old_ifs"
      state_set_step_status ai-tools complete "$services"
      return 0
    fi
    warn "AI 도구 설치가 끝나지 않았습니다. 권한, 로그인 상태, Node/npm 설치 상태를 확인해야 합니다."
    old_ifs="$IFS"; IFS=','
    state_set_ai_services_status failed "설치 실패" $services
    IFS="$old_ifs"
    state_set_step_status ai-tools failed "$services 설치 실패"
    if _recovery_menu "ai-tools" "AI 도구 설치"; then
      return 0
    fi
  done
}

wizard_step_ai_tools() {
  local platform="$1" choice raw services codex=0 claude=0
  step "3단계 AI 도구 선택"
  printf '사용할 AI 도구를 고르세요.\n'
  printf '1) Codex\n2) Claude\n3) 둘 다\n4) 아직 정하지 않음\n5) 직접 입력\n'
  choice="$(_wizard_choice '선택:' 4)"
  case "$choice" in
    1) services="Codex"; codex=1 ;;
    2) services="Claude"; claude=1 ;;
    3) services="Codex,Claude"; codex=1; claude=1 ;;
    5)
      raw="$(_wizard_read '서비스 이름을 쉼표로 적어주세요. 예: Cursor, Gemini, GLM, Kimi:' '')"
      services="$(_sanitize_services "$raw")"
      [[ -n "$services" ]] || services="직접 입력"
      info "지원하지 않는 서비스는 기록만 하고 자동 설치하지 않습니다: $services" ;;
    *)
      state_record_ai_services
      state_set_step_status ai-tools skipped "아직 정하지 않음"
      info "AI 도구는 나중에 다시 고를 수 있습니다."
      return 0 ;;
  esac
  local old_ifs="$IFS"
  IFS=','
  state_record_ai_services $services
  IFS="$old_ifs"
  _run_primary_ai_install_with_recovery "$platform" "$codex" "$claude" "$services"
}

_current_services_csv() {
  local path py
  path="$(state_path)"
  py="$(_state_python)" || return 0
  "$py" - "$path" <<'PY'
import json, sys
try:
    data=json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    data={}
print(",".join(data.get("ai_services") or []))
PY
}
