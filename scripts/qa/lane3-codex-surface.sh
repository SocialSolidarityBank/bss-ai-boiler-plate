#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:-skill-add}"
work="$(make_temp_home)"
helper_home="${BSS_AI_HELPER_HOME:-$work/helper}"
fake_home="$work/home"
mkdir -p "$helper_home" "$fake_home"

case "$mode" in
  skill-add)
    evidence="$EVIDENCE_DIR/g009-codex-surface-skilladd-green.txt"
    fake_bin="$work/bin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/skill-add" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BSS_QA_SKILL_ADD_LOG:?}"
exit 0
SH
    chmod +x "$fake_bin/skill-add"
    BSS_QA_SKILL_ADD_LOG="$work/skill-add.log" run_and_capture "$evidence" env \
      HOME="$fake_home" \
      BSS_AI_HELPER_HOME="$helper_home" \
      BSS_QA_SKILL_ADD_LOG="$work/skill-add.log" \
      PATH="$fake_bin:$PATH" \
      "$ROOT/scripts/09-codex-resume.sh" --install || fail "codex surface install failed; see $evidence"
    assert_file "$helper_home/CODEX.md"
    assert_file "$helper_home/bin/bss-ai-helper"
    assert_contains "$work/skill-add.log" 'resources/codex-skill/bss-ai-helper --mine'
    assert_contains "$helper_home/CODEX.md" 'BSS AI Helper 실행해줘'
    note "PASS G009-SKILLADD $evidence"
    ;;
  fallback)
    evidence="$EVIDENCE_DIR/g009-codex-surface-fallback-green.txt"
    run_and_capture "$evidence" env \
      HOME="$fake_home" \
      BSS_AI_HELPER_HOME="$helper_home" \
      PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
      "$ROOT/scripts/09-codex-resume.sh" --install || fail "codex fallback failed; see $evidence"
    assert_file "$helper_home/CODEX.md"
    assert_file "$helper_home/skill-install-fallback.md"
    assert_dir_absent "$fake_home/.codex/skills/bss-ai-helper"
    assert_dir_absent "$fake_home/.claude/skills/bss-ai-helper"
    assert_dir_absent "$fake_home/.agents/skills/bss-ai-helper"
    assert_contains "$helper_home/skill-install-fallback.md" 'skill-add'
    note "PASS G009-FALLBACK $evidence"
    ;;
  aliases)
    evidence="$EVIDENCE_DIR/g009-codex-surface-aliases-green.txt"
    {
      grep -n "alias bss-ai-helper=" "$ROOT/config/zshrc.block.sh"
      grep -n "alias ai-helper=" "$ROOT/config/zshrc.block.sh"
      grep -n "alias bss-ai=" "$ROOT/config/zshrc.block.sh"
      grep -n "function bss-ai-helper" "$ROOT/windows/config/profile.block.ps1"
    } > "$evidence" 2>&1
    [[ "$(grep -c "alias bss-ai-helper=" "$ROOT/config/zshrc.block.sh")" -eq 1 ]] || fail "macOS bss-ai-helper alias count is not 1"
    [[ "$(grep -c "alias ai-helper=" "$ROOT/config/zshrc.block.sh")" -eq 1 ]] || fail "macOS ai-helper alias count is not 1"
    [[ "$(grep -c "alias bss-ai=" "$ROOT/config/zshrc.block.sh")" -eq 1 ]] || fail "macOS bss-ai alias count is not 1"
    note "PASS G009-ALIASES $evidence"
    ;;
  windows)
    evidence="$EVIDENCE_DIR/g009-codex-surface-windows-green.txt"
    {
      grep -n "Confirm-Action .*DefaultNo" "$ROOT/windows/install.ps1"
      grep -n "Resolve-Path .*\\.\\.\\\\\\.\\." "$ROOT/windows/scripts/09-codex-resume.ps1"
      grep -n -- "-Status" "$ROOT/windows/scripts/09-codex-resume.ps1"
    } > "$evidence" 2>&1
    assert_contains "$ROOT/windows/install.ps1" 'Confirm-Action .*DefaultNo'
    assert_contains "$ROOT/windows/scripts/09-codex-resume.ps1" 'Resolve-Path'
    assert_contains "$ROOT/windows/scripts/09-codex-resume.ps1" '-Status'
    note "PASS G009-WINDOWS $evidence"
    ;;
  *)
    fail "unknown mode: $mode"
    ;;
esac
