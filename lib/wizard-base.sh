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
  local platform="$1" package_step choice shell_choice
  case "$platform" in
    macos) is_macos || die "This kit targets macOS only." ;;
    linux) is_linux || die "This kit targets Linux only (macOS users: use the repo root install.sh)." ;;
  esac
  package_step="$(_wizard_base_package_step "$platform")"

  step "1단계 기본 설치 준비"
  info "오픈소스 프로그램을 실행하기 위한 기본 실행 환경을 준비합니다."
  info "포함: 기본 CLI 도구, Node.js, Python, Go, Rust"
  info "Docker는 기본 질문형 설치에서 제외합니다. 나중에 고급 단계에서 따로 선택합니다."
  printf '  1) 설치하기\n'
  printf '  2) 나중에 하기\n'
  printf '  3) 상태만 보기\n'
  choice="$(_wizard_choice '선택 [1]:' 1)"
  case "$choice" in
    1|"설치하기")
      state_set_step_status base-tools in_progress
      _wizard_run_step prereqs
      _wizard_run_step "$package_step"
      _wizard_run_step runtimes
      state_set_step_status base-tools complete "$platform dry-run=$DRY_RUN"
      state_append_history base-tools complete "$platform dry-run=$DRY_RUN"
      ;;
    2|"나중에"|"나중에 하기")
      state_set_step_status base-tools skipped "$platform"
      state_append_history base-tools skipped "$platform"
      show_status
      return 0
      ;;
    3|"상태"|"상태만 보기")
      show_status
      return 0
      ;;
    *) warn "알 수 없는 선택입니다. 상태만 표시합니다."; show_status; return 0 ;;
  esac

  step "셸 편의 설정"
  info "터미널 자동완성, 프롬프트, 런타임 경로를 설정합니다."
  info "처음 쓰는 분에게는 '설정하기'를 권장합니다."
  printf '  1) 설정하기\n'
  printf '  2) 나중에 하기\n'
  shell_choice="$(_wizard_choice '선택 [1]:' 1)"
  case "$shell_choice" in
    1|"설정하기")
      state_set_step_status shell in_progress
      _wizard_run_step shell
      state_set_step_status shell complete "$platform dry-run=$DRY_RUN"
      state_append_history shell complete "$platform dry-run=$DRY_RUN"
      ;;
    2|"나중에"|"나중에 하기")
      state_set_step_status shell skipped "$platform"
      state_append_history shell skipped "$platform"
      ;;
    *) warn "알 수 없는 선택입니다. 셸 설정은 건너뜀으로 기록합니다."; state_set_step_status shell skipped ;;
  esac
}
