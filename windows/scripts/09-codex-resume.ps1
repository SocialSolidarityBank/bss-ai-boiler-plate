param([switch]$Install)

. (Join-Path $PSScriptRoot 'state.ps1')

if (-not $Install) {
  Write-Host 'Usage: windows/scripts/09-codex-resume.ps1 -Install'
  exit 1
}

$helper = Get-HelperHome
$bin = Join-Path $helper 'bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null

$wrapper = Join-Path $bin 'bss-ai-helper.ps1'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
@"
param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args)
`$repo = if (`$env:BSS_AI_HELPER_REPO) { `$env:BSS_AI_HELPER_REPO } else { '$repoRoot' }
if (`$Args.Count -eq 0) { `$Args = @('-Status') }
& (Join-Path `$repo 'windows\install.ps1') @Args
"@ | Set-Content -Encoding UTF8 $wrapper

@'
# BSS AI Helper 다시 시작하기

- `BSS AI Helper 실행해줘`
- `AI 세팅 이어서 해줘`
- `개발환경 설치 도와줘`

Codex는 먼저 `이어서 진행`, `상태만 확인`, `설명만 보기` 중 하나를 확인해야 합니다.
'@ | Set-Content -Encoding UTF8 (Join-Path $helper 'CODEX.md')

Write-Host "BSS AI Helper Codex restart surface ready: $helper"
