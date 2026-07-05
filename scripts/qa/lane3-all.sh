#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

mode="${1:-all}"

check_powershell() {
  local evidence="$EVIDENCE_DIR/g012-powershell-parser.txt"
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command "\$ErrorActionPreference='Stop'; Get-ChildItem '$ROOT/windows' -Recurse -Include *.ps1 | ForEach-Object { \$tokens=\$null; \$errors=\$null; [System.Management.Automation.Language.Parser]::ParseFile(\$_.FullName, [ref]\$tokens, [ref]\$errors) | Out-Null; if (\$errors.Count -gt 0) { throw (\$errors | Select-Object -First 1).Message } }" > "$evidence" 2>&1
    note "PASS G012-POWERSHELL $evidence"
  else
    printf 'SKIP G012-POWERSHELL: pwsh is not available on this machine.\n' > "$evidence"
    note "SKIP G012-POWERSHELL $evidence"
  fi

  local winps_evidence="$EVIDENCE_DIR/g012-windows-powershell-parser.txt"
  if command -v powershell.exe >/dev/null 2>&1; then
    WIN_WINDOWS_DIR="$(cygpath -w "$ROOT/windows")" powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '$ErrorActionPreference="Stop"; $files = @(Get-ChildItem $env:WIN_WINDOWS_DIR -Recurse -Include *.ps1); $files | ForEach-Object { $tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { throw ($errors | Select-Object -First 1).Message } }; "PASS native Windows PowerShell parser"; "FILES_PARSED: $($files.Count)"' > "$winps_evidence" 2>&1
    note "PASS G012-WINPS $winps_evidence"
  else
    printf 'SKIP G012-WINPS: Windows PowerShell is not available on this machine.\n' > "$winps_evidence"
    note "SKIP G012-WINPS $winps_evidence"
  fi
}

check_ci() {
  local evidence="$EVIDENCE_DIR/g012-ci-content.txt"
  if [[ ! -f "$ROOT/.github/workflows/ci.yml" ]]; then
    printf 'SKIP G012-CI: .github/workflows/ci.yml is not present in this checkout.\n' > "$evidence"
    note "SKIP G012-CI $evidence"
    return
  fi
  {
    grep -n "lane3-all.sh" "$ROOT/.github/workflows/ci.yml"
    grep -n "AI_BOILER_PLATE_HOME" "$ROOT/.github/workflows/ci.yml"
    grep -n "ai-boiler-plate:main" "$ROOT/.github/workflows/ci.yml"
  } > "$evidence" 2>&1
  if grep -n "gh auth login\\|codex login\\|claude login" "$ROOT/.github/workflows/ci.yml" >> "$evidence" 2>&1; then
    fail "CI lane 3 requires external auth; see $evidence"
  fi
  note "PASS G012-CI $evidence"
}

case "$mode" in
  windows-virtual-smoke)
    "$QA_DIR/lane3-windows-virtual-smoke.sh"
    ;;
  powershell)
    check_powershell
    ;;
  ci)
    check_ci
    ;;
  all)
    "$QA_DIR/primary-ai-failure.sh"
    "$QA_DIR/lane3-progress-status.sh"
    "$QA_DIR/lane3-progress-status.sh" malformed
    "$QA_DIR/lane3-progress-status.sh" classic
    "$QA_DIR/lane3-codex-surface.sh" skill-add
    "$QA_DIR/lane3-codex-surface.sh" fallback
    "$QA_DIR/lane3-codex-surface.sh" aliases
    "$QA_DIR/lane3-codex-surface.sh" windows
    "$QA_DIR/lane3-report-manual.sh" completed
    "$QA_DIR/lane3-report-manual.sh" failed-addon
    "$QA_DIR/lane3-report-manual.sh" html-assert
    "$QA_DIR/lane3-docs-content.sh" first-run
    "$QA_DIR/lane3-docs-content.sh" nondev
    "$QA_DIR/lane3-docs-content.sh" advanced
    "$QA_DIR/lane3-publish-readiness.sh" target
    "$QA_DIR/lane3-publish-readiness.sh" no-secrets
    "$QA_DIR/lane3-publish-readiness.sh" remote
    "$QA_DIR/lane3-windows-virtual-smoke.sh"
    bash -n "$ROOT/install.sh" "$ROOT/linux/install.sh" "$ROOT/uninstall.sh" "$ROOT/linux/uninstall.sh" "$ROOT"/lib/*.sh "$ROOT"/scripts/*.sh "$ROOT"/scripts/qa/*.sh "$ROOT/config/zshrc.block.sh" "$ROOT/linux/config/zshrc.block.sh"
    check_powershell
    check_ci
    git -C "$ROOT" diff --check
    note "PASS G012"
    ;;
  *)
    fail "unknown mode: $mode"
    ;;
esac
