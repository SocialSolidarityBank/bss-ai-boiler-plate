#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

evidence="$EVIDENCE_DIR/g012-windows-virtual-smoke.txt"

install="$ROOT/windows/install.ps1"
lib="$ROOT/windows/scripts/lib.ps1"
readme="$ROOT/windows/README.md"
docker_step="$ROOT/windows/scripts/05-docker.ps1"
profile_block="$ROOT/windows/config/profile.block.ps1"

assert_fixed() {
  local path="$1" needle="$2"
  grep -Fq -- "$needle" "$path" || fail "missing fixed text '$needle' in $path"
}

steps=(
  "01-prereqs.ps1:Step-Prereqs"
  "02-packages.ps1:Step-Packages"
  "03-runtimes.ps1:Step-Runtimes"
  "04-shell.ps1:Step-Shell"
  "05-docker.ps1:Step-Docker"
  "06-git.ps1:Step-Git"
  "07-agents.ps1:Step-Agents"
  "09-codex-resume.ps1:Step-Resume"
)

set +e
(
  set -euo pipefail

  assert_file "$install"
  assert_file "$lib"
  assert_file "$readme"
  assert_file "$docker_step"
  assert_file "$profile_block"

  assert_contains "$install" '\[switch\]\$DryRun'
  assert_contains "$install" '\[switch\]\$List'
  assert_contains "$install" '\[switch\]\$Status'
  assert_contains "$install" '\[switch\]\$Classic'
  assert_contains "$install" 'https://github.com/socialsolidaritybank/ai-boiler-plate.git'
  assert_fixed "$install" "\$StepIds = @('prereqs', 'packages', 'runtimes', 'shell', 'docker', 'git', 'agents', 'resume')"
  assert_fixed "$install" 'if ($List)'
  assert_fixed "$install" 'Write-Output $_'
  assert_fixed "$install" 'if ($Status)'
  assert_fixed "$install" 'Show-HelperStatus'
  assert_fixed "$install" 'if ($script:DryRun)'
  assert_fixed "$install" 'DRY-RUN: no changes will be made.'
  assert_fixed "$install" 'if (-not (Test-IsWindows))'

  assert_contains "$lib" 'function Test-IsWindows'
  assert_contains "$lib" 'function Invoke-Run'
  assert_contains "$lib" 'if \(\$script:DryRun\)'
  assert_contains "$lib" '\[dry-run\]'
  assert_contains "$lib" 'function Install-WingetPackage'
  assert_contains "$lib" '--scope user'

  assert_contains "$profile_block" "GetEnvironmentVariable\\('Path', 'Machine'\\)"
  assert_contains "$profile_block" "GetEnvironmentVariable\\('Path', 'User'\\)"
  assert_contains "$profile_block" 'MISE_PWSH_CHPWD_WARNING'
  assert_contains "$profile_block" 'Get-Command fzf'

  for spec in "${steps[@]}"; do
    file="${spec%%:*}"
    func="${spec##*:}"
    path="$ROOT/windows/scripts/$file"
    assert_file "$path"
    assert_contains "$path" "function $func"
  done

  assert_contains "$ROOT/windows/scripts/01-prereqs.ps1" 'winget is required'
  assert_contains "$ROOT/windows/scripts/01-prereqs.ps1" 'if \(-not \$script:DryRun\)'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'Git.Git'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'GitHub.cli'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'jqlang.jq'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'BurntSushi.ripgrep.MSVC'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'sharkdp.fd'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'sharkdp.bat'
  assert_contains "$ROOT/windows/scripts/02-packages.ps1" 'junegunn.fzf'
  assert_contains "$ROOT/windows/scripts/03-runtimes.ps1" 'node@lts'
  assert_contains "$ROOT/windows/scripts/03-runtimes.ps1" 'python@latest'
  assert_contains "$ROOT/windows/scripts/03-runtimes.ps1" 'go@latest'
  assert_contains "$ROOT/windows/scripts/03-runtimes.ps1" 'rustup'
  assert_contains "$ROOT/windows/scripts/04-shell.ps1" 'PSReadLine'
  assert_contains "$ROOT/windows/scripts/04-shell.ps1" 'CompletionPredictor'
  assert_contains "$ROOT/windows/scripts/04-shell.ps1" 'PSFzf'
  assert_contains "$ROOT/windows/scripts/06-git.ps1" '\[dry-run\] gh auth login'
  assert_contains "$ROOT/windows/scripts/07-agents.ps1" '\[dry-run\] mise exec -- npm install -g @openai/codex'
  assert_contains "$ROOT/windows/scripts/07-agents.ps1" '\[dry-run\] irm https://claude.ai/install.ps1 \| iex'
  assert_contains "$ROOT/windows/scripts/07-agents.ps1" 'npx skills@latest add mattpocock/skills'
  assert_contains "$ROOT/windows/scripts/07-agents.ps1" '/setup-matt-pocock-skills'
  assert_contains "$ROOT/windows/scripts/07-agents.ps1" '\[dry-run\] npx --yes lazycodex-ai install'
  assert_contains "$ROOT/windows/scripts/recommendations.ps1" '선택한 뒤에만 설치'
  assert_contains "$ROOT/windows/scripts/09-codex-resume.ps1" 'function Step-Resume'
  assert_contains "$ROOT/windows/scripts/09-codex-resume.ps1" 'RemainingArgs'
  assert_contains "$ROOT/windows/scripts/09-codex-resume.ps1" 'NoProfile'

  assert_contains "$docker_step" 'DefaultNo'
  assert_contains "$docker_step" 'NEVER install Docker'
  assert_contains "$docker_step" 'not installed non-interactively'

  assert_contains "$readme" 'irm https://raw.githubusercontent.com/socialsolidaritybank/ai-boiler-plate/main/windows/install.ps1 \| iex'
  assert_contains "$readme" 'PowerShell'
  assert_contains "$readme" 'winget'
  assert_contains "$readme" 'foxion37/lazy-starter-kit'
  retired_addon_pattern="gajae""-code|with-""gajae|(^|[^[:alnum:]_-])g""jc([^[:alnum:]_-]|$)"
  assert_not_contains "$ROOT/windows/scripts/07-agents.ps1" "$retired_addon_pattern"

  printf 'windows virtual smoke checks passed\n'
) > "$evidence" 2>&1
code=$?
set -e
if [[ "$code" -ne 0 ]]; then
  cat "$evidence" >&2
  exit "$code"
fi

note "PASS G012-WINDOWS-VIRTUAL-SMOKE $evidence"
