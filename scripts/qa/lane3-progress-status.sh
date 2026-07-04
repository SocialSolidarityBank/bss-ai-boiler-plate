#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:-default}"
helper_home="${BSS_AI_HELPER_HOME:-$(make_temp_home)}"
state_path="$helper_home/state.json"
mkdir -p "$helper_home"

case "$mode" in
  malformed)
    evidence="$EVIDENCE_DIR/g008-progress-status-malformed-green.txt"
    printf '{ this is not valid json\n' > "$state_path"
    before="$(cat "$state_path")"
    run_and_capture "$evidence" env BSS_AI_HELPER_HOME="$helper_home" "$ROOT/install.sh" --status || fail "status command failed for malformed state; see $evidence"
    after="$(cat "$state_path")"
    [[ "$before" == "$after" ]] || fail "malformed state was modified"
    assert_contains "$evidence" '상태 파일을 읽을 수 없습니다|malformed|invalid'
    note "PASS G008-MALFORMED $evidence"
    ;;
  classic)
    evidence="$EVIDENCE_DIR/g008-classic-list-green.txt"
    {
      "$ROOT/install.sh" --list
      "$ROOT/linux/install.sh" --list
    } > "$evidence" 2>&1
    assert_contains "$evidence" 'prereqs'
    assert_not_contains "$evidence" 'state.json'
    note "PASS G008-CLASSIC $evidence"
    ;;
  *)
    evidence="$EVIDENCE_DIR/g008-progress-status-green.txt"
    write_sample_state "$state_path" mixed
    before="$(cat "$state_path")"
    run_and_capture "$evidence" env BSS_AI_HELPER_HOME="$helper_home" "$ROOT/install.sh" --status || fail "status command failed; see $evidence"
    after="$(cat "$state_path")"
    [[ "$before" == "$after" ]] || fail "--status modified state.json"
    assert_contains "$evidence" '3/6 진행됨'
    assert_contains "$evidence" '● 완료'
    assert_contains "$evidence" '△ 건너뜀'
    assert_contains "$evidence" '× 실패'
    assert_contains "$evidence" '○ 대기'
    note "PASS G008 $evidence"
    ;;
esac
