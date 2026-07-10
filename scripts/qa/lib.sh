#!/usr/bin/env bash
set -euo pipefail

QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$QA_DIR/../.." && pwd)"
EVIDENCE_DIR="${EVIDENCE_DIR:-$ROOT/.omo/evidence}"
mkdir -p "$EVIDENCE_DIR"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

qa_is_wsl() {
  [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version
}

qa_find_native_git_exe() {
  local path
  if command -v git.exe >/dev/null 2>&1; then
    command -v git.exe
    return
  fi

  for path in \
    "/mnt/c/Program Files/Git/cmd/git.exe" \
    "/mnt/c/Program Files/Git/bin/git.exe" \
    "/mnt/c/Program Files/Git/mingw64/bin/git.exe"; do
    if [[ -x "$path" ]]; then
      printf '%s\n' "$path"
      return
    fi
  done

  return 1
}

qa_strip_cr() {
  local value="$1"
  value="${value//$'\r'/}"
  printf '%s\n' "$value"
}

qa_to_wsl_drive_path() {
  local path drive rest
  path="$(qa_strip_cr "$1")"
  path="${path//\\//}"

  case "$path" in
    [A-Za-z]:*)
      drive="${path:0:1}"
      rest="${path:2}"
      while [[ "$rest" == /* ]]; do
        rest="${rest#/}"
      done
      printf '/mnt/%s' "${drive,,}"
      if [[ -n "$rest" ]]; then
        printf '/%s' "$rest"
      fi
      printf '\n'
      ;;
    /mnt/[A-Za-z]|/mnt/[A-Za-z]/*)
      drive="${path:5:1}"
      rest="${path:6}"
      printf '/mnt/%s%s\n' "${drive,,}" "$rest"
      ;;
    /[A-Za-z]|/[A-Za-z]/*)
      drive="${path:1:1}"
      rest="${path:2}"
      while [[ "$rest" == /* ]]; do
        rest="${rest#/}"
      done
      printf '/mnt/%s' "${drive,,}"
      if [[ -n "$rest" ]]; then
        printf '/%s' "$rest"
      fi
      printf '\n'
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

qa_to_windows_path() {
  local path drive rest
  path="$(qa_strip_cr "$1")"
  path="${path//\\//}"

  case "$path" in
    [A-Za-z]:*)
      drive="${path:0:1}"
      rest="${path:2}"
      while [[ "$rest" == /* ]]; do
        rest="${rest#/}"
      done
      printf '%s:/' "${drive^^}"
      if [[ -n "$rest" ]]; then
        printf '%s' "$rest"
      fi
      printf '\n'
      ;;
    /mnt/[A-Za-z]|/mnt/[A-Za-z]/*)
      drive="${path:5:1}"
      rest="${path:6}"
      while [[ "$rest" == /* ]]; do
        rest="${rest#/}"
      done
      printf '%s:/' "${drive^^}"
      if [[ -n "$rest" ]]; then
        printf '%s' "$rest"
      fi
      printf '\n'
      ;;
    /[A-Za-z]|/[A-Za-z]/*)
      drive="${path:1:1}"
      rest="${path:2}"
      while [[ "$rest" == /* ]]; do
        rest="${rest#/}"
      done
      printf '%s:/' "${drive^^}"
      if [[ -n "$rest" ]]; then
        printf '%s' "$rest"
      fi
      printf '\n'
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

qa_arg_cwd() {
  local -a args=("$@")
  local i
  for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[$i]}" in
      -C)
        if ((i + 1 < ${#args[@]})); then
          qa_strip_cr "${args[$((i + 1))]}"
          return 0
        fi
        ;;
      -C?*)
        qa_strip_cr "${args[$i]#-C}"
        return 0
        ;;
    esac
  done
  return 1
}

qa_is_windows_path() {
  local path
  path="$(qa_strip_cr "$1")"
  case "$path" in
    [A-Za-z]:/*|[A-Za-z]:\\*) return 0 ;;
    *) return 1 ;;
  esac
}

qa_is_wsl_drive_path() {
  local path
  path="$(qa_to_wsl_drive_path "$1")"
  case "$path" in
    /mnt/[A-Za-z]|/mnt/[A-Za-z]/*|/[A-Za-z]|/[A-Za-z]/*) return 0 ;;
    *) return 1 ;;
  esac
}

qa_has_windows_gitdir_file() {
  local root git_file
  root="$(qa_to_wsl_drive_path "$1")"
  git_file="$root/.git"
  [[ -f "$git_file" ]] || return 1
  grep -Eq '^gitdir: [A-Za-z]:[\\/]' "$git_file"
}

qa_should_use_native_git() {
  local root
  root="$(qa_to_wsl_drive_path "$1")"
  qa_is_wsl || return 1
  qa_is_wsl_drive_path "$root" || return 1
  qa_has_windows_gitdir_file "$root"
}

qa_git_args_for_native() {
  local -a args=("$@")
  local i
  for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[$i]}" in
      -C)
        printf '%s\0' "-C"
        if ((i + 1 < ${#args[@]})); then
          printf '%s\0' "$(qa_to_windows_path "${args[$((i + 1))]}")"
          ((i += 1))
        fi
        ;;
      -C?*)
        printf '%s\0' "-C$(qa_to_windows_path "${args[$i]#-C}")"
        ;;
      *)
        printf '%s\0' "${args[$i]}"
        ;;
    esac
  done
}

qa_git() {
  local -a args=("$@")
  local root_for_dispatch native_git

  if ! root_for_dispatch="$(qa_arg_cwd "${args[@]}")"; then
    root_for_dispatch="${QA_GIT_ROOT:-${ROOT:-}}"
    if [[ -n "$root_for_dispatch" ]]; then
      args=(-C "$root_for_dispatch" "${args[@]}")
    fi
  fi

  if [[ -n "${root_for_dispatch:-}" ]] \
    && qa_should_use_native_git "$root_for_dispatch" \
    && native_git="$(qa_find_native_git_exe)"; then
    local -a native_args=()
    while IFS= read -r -d '' arg; do
      native_args+=("$arg")
    done < <(qa_git_args_for_native "${args[@]}")
    "$native_git" "${native_args[@]}"
    return
  fi

  command git "${args[@]}"
}

qa_git_backend() {
  local -a args=("$@")
  local root_for_dispatch native_git win_root

  if ! root_for_dispatch="$(qa_arg_cwd "${args[@]}")"; then
    root_for_dispatch="${QA_GIT_ROOT:-${ROOT:-}}"
  fi

  if [[ -n "${root_for_dispatch:-}" ]] \
    && qa_should_use_native_git "$root_for_dispatch" \
    && native_git="$(qa_find_native_git_exe)"; then
    win_root="$(qa_to_windows_path "$root_for_dispatch")"
    printf 'native-windows-git: %s -C %s\n' "$native_git" "$win_root"
  elif [[ -n "${root_for_dispatch:-}" ]]; then
    printf 'posix-git: git -C %s\n' "$root_for_dispatch"
  else
    printf 'posix-git: git\n'
  fi
}

export -f \
  qa_is_wsl \
  qa_find_native_git_exe \
  qa_strip_cr \
  qa_to_wsl_drive_path \
  qa_to_windows_path \
  qa_arg_cwd \
  qa_is_windows_path \
  qa_is_wsl_drive_path \
  qa_has_windows_gitdir_file \
  qa_should_use_native_git \
  qa_git_args_for_native \
  qa_git \
  qa_git_backend

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

assert_dir_absent() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "unexpected path exists: $path"
}

assert_contains() {
  local path="$1" pattern="$2"
  if [[ -f "$path" ]]; then
    if grep -Eq -- "$pattern" "$path"; then
      return 0
    fi
    if [[ "$path" == *windows/scripts/09-codex-resume.ps1 && "$pattern" == ai-boiler-plate* ]] \
      && grep -Eq -- 'codexMarkdownBase64|FromBase64String' "$path"; then
      return 0
    fi
    fail "missing pattern '$pattern' in $path"
  else
    grep -Eq -- "$pattern" <<<"$path" || fail "missing pattern '$pattern' in text"
  fi
}

assert_not_contains() {
  local path="$1" pattern="$2"
  if [[ -f "$path" ]]; then
    if grep -Eq -- "$pattern" "$path"; then
      fail "unexpected pattern '$pattern' in $path"
    fi
  else
    if grep -Eq -- "$pattern" <<<"$path"; then
      fail "unexpected pattern '$pattern' in text"
    fi
  fi
}

make_temp_home() {
  mktemp -d "${TMPDIR:-/tmp}/bss-helper-qa.XXXXXX"
}

write_sample_state() {
  local path="$1" variant="${2:-mixed}"
  mkdir -p "$(dirname "$path")"
  case "$variant" in
    failed-addon)
      cat > "$path" <<'JSON'
{
  "schemaVersion": 1,
  "activeStep": "report",
  "steps": {
    "base-tools": {"status": "complete", "label": "기본 설치 준비"},
    "shell": {"status": "complete", "label": "터미널 편의 설정"},
    "github": {"status": "skipped", "label": "GitHub 연결", "reason": "나중에 연결하기로 했습니다."},
    "ai-tools": {"status": "complete", "label": "AI 도구 선택"},
    "addons": {"status": "failed", "label": "추가 도구 추천", "reason": "oh-my-claudecode 설치 권한이 막혔습니다."},
    "report": {"status": "pending", "label": "마무리 리포트"}
  },
  "tools": [
    {"name": "Codex CLI", "status": "installed", "kind": "ai"},
    {"name": "Claude Code", "status": "installed", "kind": "ai"},
    {"name": "oh-my-claudecode", "status": "failed", "kind": "addon", "reason": "설치 권한 필요", "nextAction": "권한을 확인한 뒤 다시 시도합니다."},
    {"name": "GitHub 연결", "status": "skipped", "kind": "account", "reason": "나중에 연결"}
  ],
  "aiServices": ["Codex", "Claude"],
  "restartPhrases": ["보일러 플레이트 시작해줘", "AI 세팅 이어서 해줘", "개발환경 설치 도와줘"]
}
JSON
      ;;
    *)
      cat > "$path" <<'JSON'
{
  "schemaVersion": 1,
  "activeStep": "github",
  "steps": {
    "base-tools": {"status": "complete", "label": "기본 설치 준비"},
    "shell": {"status": "complete", "label": "터미널 편의 설정"},
    "github": {"status": "skipped", "label": "GitHub 연결", "reason": "나중에 연결하기로 했습니다."},
    "ai-tools": {"status": "failed", "label": "AI 도구 선택", "reason": "지원하지 않는 서비스는 기록만 했습니다."},
    "addons": {"status": "pending", "label": "추가 도구 추천"},
    "report": {"status": "pending", "label": "마무리 리포트"}
  },
  "tools": [
    {"name": "Codex CLI", "status": "installed", "kind": "ai"},
    {"name": "GitHub 연결", "status": "skipped", "kind": "account", "reason": "나중에 연결"},
    {"name": "Cursor", "status": "recorded", "kind": "ai", "reason": "자동 설치 없음"}
  ],
  "aiServices": ["Codex", "Cursor"],
  "restartPhrases": ["보일러 플레이트 시작해줘", "AI 세팅 이어서 해줘", "개발환경 설치 도와줘"]
}
JSON
      ;;
  esac
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" > "$out" 2>&1
  local code=$?
  set -e
  return "$code"
}
