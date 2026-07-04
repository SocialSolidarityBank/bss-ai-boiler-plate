#!/usr/bin/env bash
_wizard_read() {
  local prompt="$1" def="${2:-}"
  printf '%s ' "$prompt" >&2
  if [[ "$ASSUME_YES" == "1" ]]; then
    printf '%s\n' "$def"
    return 0
  fi
  local ans
  if IFS= read -r ans; then
    printf '%s\n' "${ans:-$def}"
  else
    printf '%s\n' "$def"
  fi
}

_wizard_choice() {
  local prompt="$1" def="$2" ans
  ans="$(_wizard_read "$prompt" "$def")"
  printf '%s\n' "$ans"
}

_recovery_menu() {
  local step_id="$1" title="$2" choice
  printf '\n%s 문제를 해결할 방법을 고르세요.\n' "$title"
  printf '1) 다시 시도\n2) 건너뛰기\n3) 중단\n4) 상태만 보기\n'
  choice="$(_wizard_choice '선택:' 2)"
  case "$choice" in
    1) return 10 ;;
    2) state_set_step_status "$step_id" skipped "사용자가 실패 후 건너뜀"; return 0 ;;
    4) show_status; return 10 ;;
    *) die "$title 단계에서 중단했습니다." ;;
  esac
}
