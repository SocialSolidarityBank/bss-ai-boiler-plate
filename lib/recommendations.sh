#!/usr/bin/env bash
recommendation_title() {
  case "$1" in
    superpowers) echo "Superpowers" ;;
    matt-pocock-skills) echo "Matt Pocock Skills" ;;
    lazy-codex) echo "Lazy-Codex" ;;
    oh-my-claudecode) echo "oh-my-claudecode" ;;
    *) echo "$1" ;;
  esac
}

recommendation_install_command() {
  case "$1" in
    matt-pocock-skills) echo "npx skills@latest add mattpocock/skills" ;;
    lazy-codex) echo "npx --yes lazycodex-ai install" ;;
    oh-my-claudecode) echo "npm install -g oh-my-claude-sisyphus@latest" ;;
    superpowers) echo "status-only" ;;
    *) return 1 ;;
  esac
}

recommendation_pick() {
  local services="$1" preference="$2"
  case "$preference" in
    orchestration)
      [[ "$services" == *Claude* ]] && { echo "oh-my-claudecode"; return 0; }
      ;;
    long-work)
      [[ "$services" == *Codex* ]] && { echo "lazy-codex"; return 0; }
      ;;
    teacher|quality|advanced)
      echo "superpowers"; return 0 ;;
  esac
  echo ""
}

recommendation_candidates() {
  local services="$1" preference="$2" out=""
  [[ "$preference" == "none" ]] && { echo ""; return 0; }
  _rec_add() {
    case ",$out," in *",$1,"*) return 0 ;; esac
    out="${out:+$out,}$1"
  }
  case "$preference" in
    orchestration) [[ "$services" == *Claude* ]] && _rec_add "oh-my-claudecode" ;;
    long-work) [[ "$services" == *Codex* ]] && _rec_add "lazy-codex" ;;
    teacher|quality|advanced) _rec_add "superpowers" ;;
  esac
  [[ "$services" == *Codex* ]] && _rec_add "lazy-codex"
  [[ "$services" == *Claude* ]] && _rec_add "oh-my-claudecode"
  printf '%s\n' "$out"
}

recommendation_show_card() {
  local id="$1" details="${2:-0}" title
  title="$(recommendation_title "$id")"
  printf '\n추천 카드: %s\n' "$title"
  case "$id" in
    matt-pocock-skills)
      printf '필수 설정: Matt Pocock Skills는 기본 안내 단계에서 설치합니다.\n'
      printf '설치 명령: npx skills@latest add mattpocock/skills\n'
      printf '설치 뒤 AI 에이전트에 입력: /setup-matt-pocock-skills\n'
      [[ "$details" == "1" ]] && printf '자세히 보기: 런타임 skill 폴더에 직접 쓰지 않고 공식 설치 명령만 안내합니다.\n'
      ;;
    lazy-codex)
      printf '좋은 경우: Codex로 긴 설치나 수정 작업을 이어서 맡기고 싶을 때\n'
      printf '강점: 목표, 기준, 증거를 남기며 오래 걸리는 작업을 관리합니다.\n'
      printf '주의: 선택한 뒤에만 설치하는 선택 add-on입니다.\n'
      [[ "$details" == "1" ]] && printf '자세히 보기: Lazy-Codex는 Codex CLI 위에서 작업 목표와 검증 기록을 더 엄격하게 관리하는 도구입니다.\n'
      ;;
    oh-my-claudecode)
      printf '좋은 경우: Claude에서 강한 오케스트레이션, 멀티 서브 에이전트를 써보고 싶을 때\n'
      printf '강점: 여러 작업자를 나누어 쓰는 흐름을 더 쉽게 시작할 수 있습니다.\n'
      printf '주의: 선택한 뒤에만 설치하는 선택 add-on입니다.\n'
      [[ "$details" == "1" ]] && printf '자세히 보기: oh-my-claudecode는 Claude Code 설정과 오케스트레이션을 보강하는 외부 도구입니다.\n'
      ;;
    superpowers)
      printf '좋은 경우: 기본 품질/계획 플러그인 상태를 확인하고 싶을 때\n'
      printf '강점: 작업 계획과 검증 습관을 보강합니다.\n'
      printf '주의: 이 도우미에서는 추가 설치가 아니라 상태 확인 항목입니다.\n'
      [[ "$details" == "1" ]] && printf '자세히 보기: Superpowers는 별도 add-on 설치가 아니라 기본 품질 확인 대상으로 둡니다.\n'
      ;;
  esac
  printf '직접 설치해드릴까요?\n'
}

recommendation_show_details() {
  case "$1" in
    matt-pocock-skills)
      printf '자세히 보기: npx skills@latest add mattpocock/skills 실행 뒤 /setup-matt-pocock-skills를 AI 에이전트에 입력합니다.\n'
      ;;
    lazy-codex)
      printf '자세히 보기: Lazy-Codex는 Codex CLI 위에서 작업 목표와 검증 기록을 더 엄격하게 관리하는 도구입니다.\n'
      ;;
    oh-my-claudecode)
      printf '자세히 보기: oh-my-claudecode는 Claude Code 설정과 오케스트레이션을 보강하는 외부 도구입니다.\n'
      ;;
    superpowers)
      printf '자세히 보기: Superpowers는 별도 add-on 설치가 아니라 기본 품질 확인 대상으로 둡니다.\n'
      ;;
  esac
}
