#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:-first-run}"
evidence="$EVIDENCE_DIR/g011-docs-content-${mode}.txt"
docs=("$ROOT/README.md" "$ROOT/linux/README.md" "$ROOT/windows/README.md" "$ROOT/docs/index.html" "$ROOT/docs/publish-readiness.md")
combined="$(cat "${docs[@]}")"

case "$mode" in
  first-run)
    {
      assert_contains "$combined" 'socialsolidaritybank/bss-ai-boiler-plate'
      assert_contains "$combined" 'BSS AI Helper 실행해줘'
      assert_contains "$combined" 'codex'
      assert_contains "$combined" '~/bss-ai-boiler-plate'
      assert_contains "$combined" 'bss-ai-helper'
      printf 'docs first-run content present\n'
    } > "$evidence" 2>&1 || { cat "$evidence" >&2; exit 1; }
    note "PASS G011-FIRST-RUN $evidence"
    ;;
  nondev)
    {
      assert_contains "$combined" '승인하면 직접 설치'
      assert_contains "$combined" '권한'
      assert_contains "$combined" 'bss-ai-boilerplate:*'
      printf 'docs non-developer content present\n'
    } > "$evidence" 2>&1 || { cat "$evidence" >&2; exit 1; }
    if grep -R "Docker.*기본.*설치" "${docs[@]}" >> "$evidence" 2>&1; then
      fail "docs imply Docker is part of the non-developer default; see $evidence"
    fi
    assert_contains "$combined" 'github.com/Heoooooon/lazy-starter-kit'
    if grep -RIE "foxion37/lazy-starter-kit" "${docs[@]}" >> "$evidence" 2>&1; then
      fail "docs contain stale upstream attribution; see $evidence"
    fi
    note "PASS G011-NONDEV $evidence"
    ;;
  advanced)
    {
      assert_contains "$combined" '--classic'
      assert_contains "$combined" '--status'
      assert_contains "$combined" '--wizard'
      assert_contains "$combined" '-Wizard'
      assert_contains "$combined" '--with-docker'
      assert_contains "$combined" '--dry-run'
      assert_contains "$combined" '--list'
      assert_contains "$combined" 'resume'
      assert_contains "$combined" 'report'
      assert_contains "$combined" 'windows/install.ps1'
      printf 'docs advanced content present\n'
    } > "$evidence" 2>&1 || { cat "$evidence" >&2; exit 1; }
    note "PASS G011-ADVANCED $evidence"
    ;;
  *)
    fail "unknown mode: $mode"
    ;;
esac
