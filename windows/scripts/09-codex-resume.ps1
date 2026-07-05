param([switch]$Install)

. (Join-Path $PSScriptRoot 'state.ps1')

function Write-ResumeStep {
  param([Parameter(Mandatory)][string]$Message)
  if (Get-Command Write-Step -ErrorAction SilentlyContinue) {
    Write-Step $Message
  } else {
    Write-Host ""
    Write-Host "==> $Message"
  }
}

function Write-ResumeInfo {
  param([Parameter(Mandatory)][string]$Message)
  if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
    Write-Info $Message
  } else {
    Write-Host "  - $Message"
  }
}

function Install-CodexResumeSurface {
  $helper = Get-HelperHome
  $bin = Join-Path $helper 'bin'
  if ((Test-Path variable:script:DryRun) -and $script:DryRun) {
    Write-ResumeInfo "[dry-run] create ai-boiler-plate restart command under $bin"
    return
  }
  New-Item -ItemType Directory -Force -Path $bin | Out-Null

  $wrapper = Join-Path $bin 'ai-boiler-plate.ps1'
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  @"
param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$RemainingArgs)
`$repoCandidate = if (`$env:AI_BOILER_PLATE_DIR) { `$env:AI_BOILER_PLATE_DIR } elseif (`$env:BSS_BOILERPLATE_DIR) { `$env:BSS_BOILERPLATE_DIR } elseif (`$env:STARTER_KIT_DIR) { `$env:STARTER_KIT_DIR } else { '$repoRoot' }
`$repo = if (`$repoCandidate -match '^(https?://|git@)') { '$repoRoot' } else { `$repoCandidate }
`$installer = Join-Path `$repo 'windows\install.ps1'
if (-not (Test-Path `$installer)) {
  `$fallbackInstaller = Join-Path '$repoRoot' 'windows\install.ps1'
  if (Test-Path `$fallbackInstaller) {
    `$repo = '$repoRoot'
    `$installer = `$fallbackInstaller
  }
}
if (-not (Test-Path `$installer)) {
  Write-Error "ai-boiler-plate installer not found: `$installer"
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
  foreach ($legacyName in @('bss-ai-helper.ps1', 'ai-helper.ps1', 'bss-ai.ps1')) {
    Copy-Item -LiteralPath $wrapper -Destination (Join-Path $bin $legacyName) -Force
  }

  $codexMarkdownBase64 = 'IyBhaS1ib2lsZXItcGxhdGUg64uk7IucIOyLnOyeke2VmOq4sAoKQ29kZXjsl5DshJwg7JWE656YIOusuOq1rCDspJEg7ZWY64KY66W8IOunkO2VmOuptCDrkKnri4jri6QuCgotIGBhaS1ib2lsZXItcGxhdGUg7Iuk7ZaJ7ZW07KSYYAotIGBBSSDshLjtjIUg7J207Ja07IScIO2VtOykmGAKLSBg6rCc67Cc7ZmY6rK9IOyEpOy5mCDrj4TsmYDspJhgCgpDb2RleOuKlCDrqLzsoIAgYOydtOyWtOqwiOyngGAsIGDsg4Htg5zrp4wg7ZmV7J247ZWg7KeAYCwgYOyEpOuqheunjCDrs7zsp4BgIOykkSDtlZjrgpjrpbwg7ZmV7J247ZW07JW8IO2VqeuLiOuLpC4KClBvd2VyU2hlbGzsl5DshJzripQg64uk7J2MIOuqheugueydhCDsgqzsmqntlaAg7IiYIOyeiOyKteuLiOuLpC4KCmBgYHBvd2Vyc2hlbGwKYWktYm9pbGVyLXBsYXRlIC0tc3RhdHVzCmFpLWJvaWxlci1wbGF0ZSAtU3RhdHVzCmBgYAoKRGVwcmVjYXRlZCBjb21wYXRpYmlsaXR5IGNvbW1hbmRzIGZvciBleGlzdGluZyBpbnN0YWxsczoKCmBgYHBvd2Vyc2hlbGwKYnNzLWFpLWhlbHBlciAtLXN0YXR1cwpic3MtYWktaGVscGVyIC1TdGF0dXMKYWktaGVscGVyIC1TdGF0dXMKYnNzLWFpIC1TdGF0dXMKYGBg'
  $codexMarkdown = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($codexMarkdownBase64))
  Set-Content -Encoding UTF8 -Path (Join-Path $helper 'CODEX.md') -Value $codexMarkdown

  Write-Host "ai-boiler-plate Codex restart surface ready: $helper"
}

function Step-Resume {
  Write-ResumeStep 'ai-boiler-plate restart command'
  Install-CodexResumeSurface
}

if ($Install) {
  Step-Resume
} elseif ($MyInvocation.InvocationName -ne '.') {
  Write-Host 'Usage: windows/scripts/09-codex-resume.ps1 -Install'
  exit 1
}
