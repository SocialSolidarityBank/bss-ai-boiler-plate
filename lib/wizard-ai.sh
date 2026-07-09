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
    info "CLI 도구 설치는 건너뛰고, 선택 결과만 기록합니다."
  fi
  case "$platform" in
    linux) step_file="$ROOT/scripts/07-agents.sh" ;;
    *) step_file="$ROOT/scripts/07-agents.sh" ;;
  esac
  [[ -f "$step_file" ]] || die "missing agents step: $step_file"
  source "$step_file"
  BSS_AI_INSTALL_CODEX="$codex" \
  BSS_AI_INSTALL_CLAUDE="$claude" \
  BSS_AI_INSTALL_MATT=0 \
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
  local platform="$1" choice services codex=0 claude=0
  step "3단계 AI CLI 도구 선택"
  printf 'Codex 앱은 이미 설치했다고 보고, 터미널에서 쓰는 CLI 명령만 확인합니다.\n'
  printf '1) Codex CLI 설치\n2) Claude Code CLI 설치\n3) Codex CLI + Claude Code CLI 설치\n4) CLI 도구는 설치하지 않음\n'
  choice="$(_wizard_choice '선택:' 1)"
  case "$choice" in
    1) services="Codex CLI"; codex=1 ;;
    2) services="Claude Code CLI"; claude=1 ;;
    3) services="Codex CLI,Claude Code CLI"; codex=1; claude=1 ;;
    *)
      state_record_ai_services
      state_set_step_status ai-tools skipped "CLI 도구 설치하지 않음"
      info "AI CLI 도구 설치를 건너뜁니다."
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
