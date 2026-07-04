#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:-target}"
evidence="$EVIDENCE_DIR/g013-publish-readiness-${mode}.txt"

secret_regex='(ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|oauth[_-]?code[=:][A-Za-z0-9_-]+|password[=:][^[:space:]]+)'

case "$mode" in
  target)
    before="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
    run_and_capture "$evidence" "$ROOT/scripts/11-publish-readiness.sh" --check || fail "publish readiness check failed; see $evidence"
    after="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
    [[ "$before" == "$after" ]] || fail "publish readiness mutated origin"
    assert_contains "$evidence" 'github.com/socialsolidaritybank/bss-ai-helper'
    assert_contains "$evidence" 'commit/push/create'
    note "PASS G013-TARGET $evidence"
    ;;
  no-secrets)
    helper_home="${BSS_AI_HELPER_HOME:-$(make_temp_home)}"
    mkdir -p "$helper_home"
    write_sample_state "$helper_home/state.json" failed-addon
    env BSS_AI_HELPER_HOME="$helper_home" "$ROOT/scripts/10-report.sh" --generate > "$evidence" 2>&1 || fail "could not generate sample report for no-secret scan"
    if grep -RIE "$secret_regex" "$helper_home" "$ROOT/README.md" "$ROOT/docs" "$ROOT/resources" >> "$evidence" 2>&1; then
      fail "secret-like value found; see $evidence"
    fi
    note "PASS G013-NO-SECRETS $evidence"
    ;;
  remote)
    current="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
    {
      printf 'current origin: %s\n' "$current"
      "$ROOT/scripts/11-publish-readiness.sh" --check
    } > "$evidence" 2>&1
    assert_contains "$evidence" 'foxion37/lazy-starter-kit|socialsolidaritybank/bss-ai-helper'
    assert_contains "$evidence" 'pending|보류|not changed|바꾸지 않았습니다'
    note "PASS G013-REMOTE $evidence"
    ;;
  *)
    fail "unknown mode: $mode"
    ;;
esac
