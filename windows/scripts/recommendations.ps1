function Get-RecommendationTitle {
  param([string]$Id)
  switch ($Id) {
    'matt-pocock-skills' { 'Matt Pocock Skills' }
    'lazy-codex' { 'Lazy-Codex' }
    'oh-my-claudecode' { 'oh-my-claudecode' }
    'gajae-code' { 'Gajae-Code' }
    'superpowers' { 'Superpowers' }
    default { $Id }
  }
}

function Get-RecommendationInstallCommand {
  param([string]$Id)
  switch ($Id) {
    'matt-pocock-skills' { 'skill-add https://github.com/mattpocock/skills' }
    'lazy-codex' { 'npx --yes lazycodex-ai install' }
    'oh-my-claudecode' { 'npm install -g oh-my-claude-sisyphus@latest' }
    'gajae-code' { 'bun add -g gajae-code' }
    'superpowers' { 'status-only' }
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
    'teacher' { & $add 'matt-pocock-skills' }
    'long-work' { if ($joined -like '*Codex*') { & $add 'lazy-codex' } }
    'advanced' { & $add 'gajae-code' }
  }
  if ($joined -like '*Codex*') { & $add 'lazy-codex' }
  if ($joined -like '*Claude*') { & $add 'oh-my-claudecode' }
  & $add 'matt-pocock-skills'
  if ($Preference -eq 'advanced') { & $add 'gajae-code' }
  return $out.ToArray()
}

function Get-RecommendationPick {
  param([string[]]$Services, [string]$Preference)
  $joined = ($Services -join ',')
  switch ($Preference) {
    'orchestration' { if ($joined -like '*Claude*') { return 'oh-my-claudecode' } }
    'teacher' { return 'matt-pocock-skills' }
    'long-work' { if ($joined -like '*Codex*') { return 'lazy-codex' } }
    'advanced' { return 'gajae-code' }
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
      Write-Output '좋은 경우: 질문 항목을 하나씩 설계해주는 선생님이 필요할 때'
      Write-Output '강점: TypeScript와 프롬프트 설계를 작게 나누어 배울 수 있습니다.'
      Write-Output '주의: 자동 설치 뒤에도 실제 사용법은 Codex나 Claude 안에서 확인해야 합니다.'
      if ($Details) { Write-Output '자세히 보기: Matt Pocock Skills는 학습용 skill 묶음입니다.' }
    }
    'oh-my-claudecode' {
      Write-Output '좋은 경우: Claude에서 강한 오케스트레이션, 멀티 서브 에이전트를 써보고 싶을 때'
      Write-Output '강점: 여러 작업자를 나누어 쓰는 흐름을 더 쉽게 시작할 수 있습니다.'
      Write-Output '주의: Claude Code 사용 경험이 없는 초보자에게는 먼저 기본 Claude 사용을 권합니다.'
      if ($Details) { Write-Output '자세히 보기: Claude Code 설정과 오케스트레이션을 보강하는 외부 도구입니다.' }
    }
    'lazy-codex' {
      Write-Output '좋은 경우: Codex로 긴 설치나 수정 작업을 이어서 맡기고 싶을 때'
      Write-Output '강점: 목표, 기준, 증거를 남기며 오래 걸리는 작업을 관리합니다.'
      Write-Output '주의: 터미널 사용이 어느 정도 필요합니다.'
      if ($Details) { Write-Output '자세히 보기: Lazy-Codex는 Codex CLI 위에서 작업 목표와 검증 기록을 더 엄격하게 관리하는 도구입니다.' }
    }
    'gajae-code' {
      Write-Output '좋은 경우: 고급 터미널 사용자가 빠른 코드 작업 도구를 추가하고 싶을 때'
      Write-Output '강점: 터미널에서 가볍게 실행할 수 있습니다.'
      Write-Output '주의: 비개발자 기본 추천은 아닙니다.'
      if ($Details) { Write-Output '자세히 보기: Gajae-Code는 터미널 중심 도구라 명령어 사용에 익숙할 때만 추천합니다.' }
    }
    'superpowers' {
      Write-Output '좋은 경우: 기본 품질/계획 플러그인 상태를 확인하고 싶을 때'
      Write-Output '강점: 작업 계획과 검증 습관을 보강합니다.'
      Write-Output '주의: 이 도우미에서는 추가 설치가 아니라 상태 확인 항목입니다.'
      if ($Details) { Write-Output '자세히 보기: Superpowers는 별도 add-on 설치가 아니라 기본 품질 확인 대상으로 둡니다.' }
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
