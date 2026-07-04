#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:-completed}"
helper_home="${BSS_AI_HELPER_HOME:-$(make_temp_home)}"
state_path="$helper_home/state.json"
mkdir -p "$helper_home"

case "$mode" in
  failed-addon) variant="failed-addon"; evidence="$EVIDENCE_DIR/g010-report-manual-failed-addon-green.txt" ;;
  html-assert) variant="mixed"; evidence="$EVIDENCE_DIR/g010-report-manual-html-green.txt" ;;
  *) variant="mixed"; evidence="$EVIDENCE_DIR/g010-report-manual-green.txt" ;;
esac

write_sample_state "$state_path" "$variant"
run_and_capture "$evidence" env BSS_AI_HELPER_HOME="$helper_home" "$ROOT/scripts/10-report.sh" --generate || fail "report/manual generation failed; see $evidence"

report="$helper_home/latest-report.md"
manual="$helper_home/manual/index.html"
history="$helper_home/history.jsonl"
assert_file "$report"
assert_file "$manual"
assert_file "$history"

case "$mode" in
  failed-addon)
    assert_contains "$report" '설치하지 않은 도구'
    assert_contains "$report" 'oh-my-claudecode'
    assert_contains "$manual" '설치하지 않은 도구'
    assert_contains "$manual" '권한을 확인한 뒤 다시 시도'
    note "PASS G010-FAILED-ADDON $evidence"
    ;;
  html-assert)
    assert_contains "$manual" '<details>'
    assert_contains "$manual" 'https://developers.openai.com/codex/cli'
    assert_contains "$manual" 'https://docs.anthropic.com/en/docs/claude-code/overview'
    assert_contains "$manual" 'https://cli.github.com/manual/'
    assert_not_contains "$evidence" 'open '
    assert_not_contains "$evidence" 'xdg-open'
    note "PASS G010-HTML $evidence"
    ;;
  *)
    assert_contains "$report" '설치한 도구'
    assert_contains "$manual" '처음 시작하기'
    assert_contains "$manual" '설치한 도구'
    assert_contains "$manual" '설치하지 않은 도구'
    note "PASS G010-COMPLETED $evidence"
    ;;
esac
