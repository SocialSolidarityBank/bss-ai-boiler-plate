param([switch]$Install)

. (Join-Path $PSScriptRoot 'state.ps1')
if (-not (Get-Command Write-Step -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'lib.ps1')
}

function Write-CodexRestartSurface {
  $helper = Get-HelperHome
  $bin = Join-Path $helper 'bin'
  New-Item -ItemType Directory -Force -Path $bin | Out-Null

  $wrapper = Join-Path $bin 'bss-ai-helper.ps1'
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  @"
param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$RemainingArgs)
`$repo = if (`$env:BSS_AI_HELPER_REPO) { `$env:BSS_AI_HELPER_REPO } else { '$repoRoot' }
`$installer = Join-Path `$repo 'windows\install.ps1'
if (-not (Test-Path `$installer)) {
  Write-Error "BSS AI Helper installer not found: `$installer"
  exit 1
}
if (`$RemainingArgs.Count -eq 0) { `$RemainingArgs = @('-Status') }
[string[]]`$normalizedArgs = @(foreach (`$arg in `$RemainingArgs) {
  switch (`$arg) {
    '--status' { '-Status' }
    '--help' { '-Help' }
    '--list' { '-List' }
    '--version' { '-Version' }
    '--classic' { '-Classic' }
    '--wizard' { '-Wizard' }
    '--dry-run' { '-DryRun' }
    '--yes' { '-Yes' }
    '--reset-state' { '-ResetState' }
    '--no-agents' { '-NoAgents' }
    '--only' { '-Only' }
    '--skip' { '-Skip' }
    default { `$arg }
  }
})
`$powerShell = (Get-Process -Id `$PID).Path
& `$powerShell -NoProfile -ExecutionPolicy Bypass -File `$installer @normalizedArgs
if (`$LASTEXITCODE -is [int]) { exit `$LASTEXITCODE }
"@ | Set-Content -Encoding UTF8 $wrapper

  @'
# BSS AI Helper 다시 시작하기

- `BSS AI Helper 실행해줘`
- `AI 세팅 이어서 해줘`
- `개발환경 설치 도와줘`

Codex는 먼저 `이어갈 진행`, `상태만 확인`, `설명만 보기` 중 하나를 확인해야 합니다.

PowerShell에서는 다음 명령을 사용할 수 있습니다.

```powershell
bss-ai-helper --status
bss-ai-helper -Status
ai-helper -Status
bss-ai -Status
```
'@ | Set-Content -Encoding UTF8 (Join-Path $helper 'CODEX.md')
}

function Install-CodexSkill {
  $helper = Get-HelperHome
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $src = Join-Path $repoRoot 'resources\codex-skill\bss-ai-helper'
  $fallback = Join-Path $helper 'skill-install-fallback.md'
  $skillAdd = Get-Command skill-add -ErrorAction SilentlyContinue

  if ($skillAdd) {
    & $skillAdd.Source $src --mine
    'codex-skill=complete' | Set-Content -Encoding UTF8 (Join-Path $helper 'codex-skill.status')
    return
  }

  @"
# Codex skill install deferred

The `skill-add` command was not found, so the Codex skill was not installed automatically.
This installer does not write directly to `.codex\skills`, `.claude\skills`, or `.agents\skills`.

When `skill-add` is available, run this from the repository root:

````powershell
skill-add resources\codex-skill\bss-ai-helper --mine
````
"@ | Set-Content -Encoding UTF8 $fallback
  'codex-skill=skipped' | Set-Content -Encoding UTF8 (Join-Path $helper 'codex-skill.status')
}

function Step-Resume {
  Write-Step "BSS AI Helper restart surface"
  Initialize-HelperState
  Write-CodexRestartSurface
  Install-CodexSkill
  Set-StepStatus -Step 'resume' -Status 'complete' -Note 'restart surface ready'
  Write-Ok "BSS AI Helper Codex restart surface ready: $(Get-HelperHome)"
}

function Invoke-CodexResumeScript {
  if (-not $Install) {
    Write-Host 'Usage: windows/scripts/09-codex-resume.ps1 -Install'
    exit 1
  }
  Step-Resume
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-CodexResumeScript
}
