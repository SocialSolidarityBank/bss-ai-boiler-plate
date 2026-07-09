#!/usr/bin/env bash

_wizard_status_label() {
  case "$1" in
    complete|completed) printf '● 완료' ;;
    in_progress|running) printf '◐ 진행 중' ;;
    skipped) printf '△ 건너뜀' ;;
    failed) printf '× 실패' ;;
    *) printf '○ 대기' ;;
  esac
}

_wizard_source_step() {
  local id="$1" file="$ROOT/scripts/$(step_file "$id")"
  [[ -f "$file" ]] || die "missing step file: $file"
  source "$file"
}

_wizard_run_step() {
  local id="$1" fn="step_$1"
  _wizard_source_step "$id"
  "$fn"
}

_wizard_base_package_step() {
  case "$1" in
    macos) printf 'brew\n' ;;
    linux) printf 'packages\n' ;;
    *) return 1 ;;
  esac
}

wizard_step_base() {
  local platform="$1" package_step choice
  case "$platform" in
    macos) is_macos || die "This kit targets macOS only." ;;
    linux) is_linux || die "This kit targets Linux only (macOS users: use the repo root install.sh)." ;;
  esac
  package_step="$(_wizard_base_package_step "$platform")"

  step "1단계 기본 설치 준비"
  info "기본 환경은 개발 도구가 실행될 바탕 프로그램입니다."
  info "패키지는 필요한 프로그램을 내려받아 설치하는 묶음입니다."
  info "런타임은 Node.js나 Python처럼 개발 도구가 돌아가게 해주는 실행기입니다."
  info "셸은 PowerShell이나 터미널처럼 명령을 입력하는 창입니다."
  info "Docker는 기본 질문형 설치에서 제외합니다. 나중에 고급 단계에서 따로 선택합니다."
  printf '기본 환경을 전체 설치할까요?\n'
  printf '  1) 네, 전체 설치할게요\n'
  printf '  2) 설치하지 않을게요\n'
  choice="$(_wizard_choice '선택 [1]:' 1)"
  case "$choice" in
    1|"네"|"네, 전체 설치할게요"|"전체 설치")
      state_set_step_status base-tools in_progress
      _wizard_run_step prereqs
      _wizard_run_step "$package_step"
      _wizard_run_step runtimes
      _wizard_run_step shell
      state_set_step_status base-tools complete "$platform dry-run=$DRY_RUN"
      state_append_history base-tools complete "$platform dry-run=$DRY_RUN"
      state_set_step_status shell complete "$platform dry-run=$DRY_RUN"
      state_append_history shell complete "$platform dry-run=$DRY_RUN"
      ;;
    2|"아니오"|"설치하지 않을게요"|"설치하지 않음")
      state_set_step_status base-tools skipped "$platform"
      state_append_history base-tools skipped "$platform"
      state_set_step_status shell skipped "$platform"
      state_append_history shell skipped "$platform"
      show_status
      return 0
      ;;
    *) warn "알 수 없는 선택입니다. 상태만 표시합니다."; show_status; return 0 ;;
  esac
}
