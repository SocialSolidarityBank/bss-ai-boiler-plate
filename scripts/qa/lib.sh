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
    grep -Eq -- "$pattern" "$path" || fail "missing pattern '$pattern' in $path"
  else
    printf '%s' "$path" | grep -Eq -- "$pattern" || fail "missing pattern '$pattern' in text"
  fi
}

assert_not_contains() {
  local path="$1" pattern="$2"
  if [[ -f "$path" ]]; then
    if grep -Eq -- "$pattern" "$path"; then
      fail "unexpected pattern '$pattern' in $path"
    fi
  else
    if printf '%s' "$path" | grep -Eq -- "$pattern"; then
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
  "restartPhrases": ["BSS AI Helper 실행해줘", "AI 세팅 이어서 해줘", "개발환경 설치 도와줘"]
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
  "restartPhrases": ["BSS AI Helper 실행해줘", "AI 세팅 이어서 해줘", "개발환경 설치 도와줘"]
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
