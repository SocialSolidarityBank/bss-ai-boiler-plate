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
    run_and_capture "$evidence" env AI_BOILER_PLATE_HOME="$helper_home" BSS_AI_HELPER_HOME="$helper_home" "$ROOT/install.sh" --status || fail "status command failed for malformed state; see $evidence"
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
    run_and_capture "$evidence" env AI_BOILER_PLATE_HOME="$helper_home" BSS_AI_HELPER_HOME="$helper_home" "$ROOT/install.sh" --status || fail "status command failed; see $evidence"
    after="$(cat "$state_path")"
    [[ "$before" == "$after" ]] || fail "--status modified state.json"
    assert_contains "$evidence" '3/6 진행됨'
    assert_contains "$evidence" '● 완료'
    assert_contains "$evidence" '△ 건너뜀'
    assert_contains "$evidence" '× 실패'
    assert_contains "$evidence" '○ 대기'
    note "PASS G008 $evidence"

    if command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
      shim_dir="$(mktemp -d "${TMPDIR:-/tmp}/bss-helper-python-shim.XXXXXX")"
      cat > "$shim_dir/python3" <<'SH'
#!/usr/bin/env bash
printf 'Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases.\n' >&2
exit 49
SH
      chmod +x "$shim_dir/python3"
      fallback_evidence="$EVIDENCE_DIR/g008-progress-status-python-fallback-green.txt"
      run_and_capture "$fallback_evidence" env PATH="$shim_dir:$PATH" AI_BOILER_PLATE_HOME="$helper_home" BSS_AI_HELPER_HOME="$helper_home" "$ROOT/install.sh" --status || fail "status command failed with python fallback; see $fallback_evidence"
      assert_contains "$fallback_evidence" '3/6'
      assert_not_contains "$fallback_evidence" 'Python was not found'
      rm -rf "$shim_dir"
      note "PASS G008-PYTHON-FALLBACK $fallback_evidence"
    fi
    ;;
esac
