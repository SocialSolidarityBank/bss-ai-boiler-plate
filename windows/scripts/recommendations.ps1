function Get-RecommendationTitle {
  param([string]$Id)
  switch ($Id) {
    'matt-pocock-skills' { 'Matt Pocock Skills' }
    'lazy-codex' { 'Lazy-Codex' }
    'oh-my-claudecode' { 'oh-my-claudecode' }
    'superpowers' { 'Superpowers Debug/Verify Pack' }
    default { $Id }
  }
}

function Get-RecommendationInstallCommand {
  param([string]$Id)
  switch ($Id) {
    'matt-pocock-skills' { 'npx skills@latest add mattpocock/skills' }
    'lazy-codex' { 'npx --yes lazycodex-ai install' }
    'oh-my-claudecode' { 'npm install -g oh-my-claude-sisyphus@latest' }
    'superpowers' {
      @(
        'npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/systematic-debugging',
        'npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/verification-before-completion'
      )
    }
    default { $null }
  }
}

function Get-RecommendationCandidates {
  param([string[]]$Services, [string]$Preference)
  if ($Preference -eq 'none') { return @() }
  $joined = ($Services -join ',')
  $out = New-Object System.Collections.Generic.List[string]
  $add = {
    param([string]$Id)
    if (-not $out.Contains($Id)) { $out.Add($Id) | Out-Null }
  }
  switch ($Preference) {
    'orchestration' { if ($joined -like '*Claude*') { & $add 'oh-my-claudecode' } }
    'long-work' { if ($joined -like '*Codex*') { & $add 'lazy-codex' } }
    { $_ -in @('teacher', 'quality', 'advanced') } { & $add 'superpowers' }
  }
  if ($joined -like '*Codex*') { & $add 'lazy-codex' }
  if ($joined -like '*Claude*') { & $add 'oh-my-claudecode' }
  return $out.ToArray()
}

function Get-RecommendationPick {
  param([string[]]$Services, [string]$Preference)
  $joined = ($Services -join ',')
  switch ($Preference) {
    'orchestration' { if ($joined -like '*Claude*') { return 'oh-my-claudecode' } }
    'long-work' { if ($joined -like '*Codex*') { return 'lazy-codex' } }
    { $_ -in @('teacher', 'quality', 'advanced') } { return 'superpowers' }
  }
  return $null
}

function Show-RecommendationCard {
  param([string]$Id, [switch]$Details)
  $title = Get-RecommendationTitle -Id $Id
  Write-Output ""
  Write-Output "추천 카드: $title"
  switch ($Id) {
    'matt-pocock-skills' {
      Write-Output '필수 설정: Matt Pocock Skills는 기본 안내 단계에서 설치합니다.'
      Write-Output '설치 명령: npx skills@latest add mattpocock/skills'
      Write-Output '설치 뒤 AI 에이전트에 입력: /setup-matt-pocock-skills'
      if ($Details) { Write-Output '자세히 보기: 런타임 skill 폴더에 직접 쓰지 않고 공식 설치 명령만 안내합니다.' }
    }
    'oh-my-claudecode' {
      Write-Output '좋은 경우: Claude에서 강한 오케스트레이션, 멀티 서브 에이전트를 써보고 싶을 때'
      Write-Output '강점: 여러 작업자를 나누어 쓰는 흐름을 더 쉽게 시작할 수 있습니다.'
      Write-Output '주의: 선택한 뒤에만 설치하는 선택 add-on입니다.'
      if ($Details) { Write-Output '자세히 보기: Claude Code 설정과 오케스트레이션을 보강하는 외부 도구입니다.' }
    }
    'lazy-codex' {
      Write-Output '좋은 경우: Codex로 긴 설치나 수정 작업을 이어서 맡기고 싶을 때'
      Write-Output '강점: 목표, 기준, 증거를 남기며 오래 걸리는 작업을 관리합니다.'
      Write-Output '주의: 선택한 뒤에만 설치하는 선택 add-on입니다.'
      if ($Details) { Write-Output '자세히 보기: Lazy-Codex는 Codex CLI 위에서 작업 목표와 검증 기록을 더 엄격하게 관리하는 도구입니다.' }
    }
    'superpowers' {
      Write-Output 'Good for: stricter bug fixing and completion checks.'
      Write-Output 'Strength: installs systematic-debugging and verification-before-completion only.'
      Write-Output 'Note: optional add-on, installed only after explicit opt-in. Full Superpowers workflow/plugin stays advanced and manual.'
      Write-Output 'Install command 1: npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/systematic-debugging'
      Write-Output 'Install command 2: npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/verification-before-completion'
      if ($Details) { Write-Output 'Details: install the full plugin manually with /plugin install superpowers@claude-plugins-official in Claude Code, or search Superpowers in the Codex plugin marketplace. Set SUPERPOWERS_DISABLE_TELEMETRY=true if needed.' }
    }
    default {
      Write-Output '좋은 경우: 선택한 AI 도구를 더 깊게 써보고 싶을 때'
      Write-Output '강점: 반복 작업을 줄입니다.'
      Write-Output '주의: 기본 설치가 끝난 뒤에 권합니다.'
      if ($Details) { Write-Output '자세히 보기: 이 도구는 선택한 목적에 맞춰 추가로 확인합니다.' }
    }
  }
  Write-Output '직접 설치해드릴까요?'
}
