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
assert_contains "$report" 'ai-boiler-plate'
assert_contains "$report" '보일러 플레이트 시작해줘'
assert_contains "$manual" 'ai-boiler-plate'
assert_contains "$manual" '보일러 플레이트 시작해줘'
assert_not_contains "$report" 'git clone https://github.com/socialsolidaritybank/bss-ai-helper'
assert_not_contains "$manual" 'git clone https://github.com/socialsolidaritybank/bss-ai-helper'
assert_not_contains "$report" 'git clone https://github.com/socialsolidaritybank/ai-boiler-plate.git ~/ai-boiler-plate'
assert_not_contains "$manual" 'git clone https://github.com/socialsolidaritybank/ai-boiler-plate.git ~/ai-boiler-plate'
assert_not_contains "$report" '^cd ~/ai-boiler-plate$'
assert_not_contains "$manual" '^cd ~/ai-boiler-plate$'
assert_not_contains "$report" '^codex$'
assert_not_contains "$manual" '^codex$'
assert_contains "$report" 'Deprecated compatibility'
assert_contains "$manual" 'Deprecated compatibility'
assert_contains "$report" 'Business judgment route'
assert_contains "$report" 'does not decide business viability'
assert_contains "$report" 'G-stack office-hours repo/link'
assert_contains "$report" 'npx skills@latest add mattpocock/skills'
assert_contains "$report" '/setup-matt-pocock-skills'
assert_contains "$report" 'Superpowers Debug/Verify Pack'
assert_contains "$report" 'systematic-debugging'
assert_contains "$report" 'verification-before-completion'
assert_contains "$manual" 'Business judgment route'
assert_contains "$manual" 'does not decide business viability'
assert_contains "$manual" 'G-stack office-hours repo/link'
assert_contains "$manual" 'npx skills@latest add mattpocock/skills'
assert_contains "$manual" '/setup-matt-pocock-skills'
assert_contains "$manual" 'Superpowers Debug/Verify Pack'
assert_contains "$manual" 'systematic-debugging'
assert_contains "$manual" 'verification-before-completion'

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
