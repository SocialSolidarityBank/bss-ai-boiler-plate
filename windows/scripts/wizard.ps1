function Read-WizardChoice {
  param([string]$Prompt, [string]$Default = '')
  if ($script:AssumeYes) { return $Default }
  if ([Console]::IsInputRedirected) {
    $line = [Console]::In.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) { return $Default }
    return $line
  }
  $answer = Read-Host $Prompt
  if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
  return $answer
}

function Invoke-WizardRecovery {
  param([string]$Step, [string]$Title)
  Write-Output ""
  Write-Output "$Title 문제를 해결할 방법을 고르세요."
  Write-Output '1) 다시 시도'
  Write-Output '2) 건너뛰기'
  Write-Output '3) 중단'
  Write-Output '4) 상태만 보기'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '2'
  switch ($choice) {
    '1' { return 'retry' }
    '2' { Set-StepStatus -Step $Step -Status 'skipped' -Note '사용자가 실패 후 건너뜀'; return 'skip' }
    '4' { Show-Status; return 'retry' }
    default { Stop-Kit "$Title 단계에서 중단했습니다." }
  }
}

. (Join-Path $PSScriptRoot 'wizard-base.ps1')
. (Join-Path $PSScriptRoot 'wizard-ai.ps1')

function Test-WizardYesChoice {
  param([string]$Choice)
  return ($Choice -in @('1', '네', '네, 전체 설치할게요', '네 전체 설치할게요', '전체 설치', '네 설치할게요'))
}

function Test-WizardNoChoice {
  param([string]$Choice)
  return ($Choice -in @('2', '아니오', '설치하지 않을게요', '설치하지 않음'))
}

function Test-WizardApproval {
  param([string]$Choice)
  $clean = ([string]$Choice).Trim()
  return ($clean -in @('승인', '진행'))
}

function New-WizardPlan {
  param(
    [string]$Platform = 'Windows',
    [Parameter(Mandatory)][string]$Root,
    [switch]$IncludeBase
  )
  $plan = @{
    platform = $Platform
    root = $Root
    includeBase = [bool]$IncludeBase
    base = @{ install = $false; valid = $true; summary = '설치하지 않음' }
    github = @{ choice = '3'; summary = '지금은 건너뛰기' }
    ai = @{ choice = '4'; services = @(); codex = '0'; claude = '0'; summary = 'CLI 도구는 설치하지 않음' }
    addons = @()
    valid = $true
  }

  if ($IncludeBase) {
    Write-Step '1단계 기본 설치 준비'
    Write-Info '기본 환경은 개발 도구가 실행될 바탕 프로그램입니다.'
    Write-Info '패키지는 필요한 프로그램을 내려받아 설치하는 묶음입니다.'
    Write-Info '런타임은 Node.js나 Python처럼 개발 도구가 돌아가게 해주는 실행기입니다.'
    Write-Info '셸은 PowerShell이나 터미널처럼 명령을 입력하는 창입니다.'
    Write-Info 'Docker는 기본 질문형 설치에서 제외합니다. 나중에 고급 단계에서 따로 선택합니다.'
    Write-Host '기본 환경을 전체 설치할까요?'
    Write-Host '1) 네, 전체 설치할게요'
    Write-Host '2) 설치하지 않을게요'
    $baseChoice = Read-WizardChoice -Prompt '선택:' -Default '1'
    if (Test-WizardYesChoice -Choice $baseChoice) {
      $plan.base = @{ install = $true; valid = $true; summary = 'prereqs, packages, runtimes, shell 설치' }
    } elseif (Test-WizardNoChoice -Choice $baseChoice) {
      $plan.base = @{ install = $false; valid = $true; summary = '설치하지 않음' }
    } else {
      Write-Warn '알 수 없는 선택입니다. 실행하지 않고 상태만 표시합니다.'
      $plan.valid = $false
      return ,$plan
    }
  }

  Write-Step '2단계 GitHub 연결'
  Write-Host 'GitHub를 연결하면 오픈소스 도구 설치와 저장소 작업이 더 매끄럽습니다.'
  Write-Host '1) 연결하기'
  Write-Host '2) 가입 링크 열기'
  Write-Host '3) 지금은 건너뛰기'
  Write-Host '4) 상태만 보기'
  $githubChoice = Read-WizardChoice -Prompt '선택:' -Default '3'
  switch ($githubChoice) {
    '1' { $plan.github = @{ choice = '1'; summary = 'gh auth login 실행' } }
    '2' { $plan.github = @{ choice = '2'; summary = 'GitHub 가입 링크 열기' } }
    '4' { $plan.github = @{ choice = '4'; summary = '상태만 보기' } }
    default { $plan.github = @{ choice = '3'; summary = '지금은 건너뛰기' } }
  }

  Write-Step '3단계 AI CLI 도구 선택'
  Write-Host 'Codex 앱은 이미 설치했다고 보고, 터미널에서 쓰는 CLI 명령만 확인합니다.'
  Write-Host '1) Codex CLI 설치'
  Write-Host '2) Claude Code CLI 설치'
  Write-Host '3) Codex CLI + Claude Code CLI 설치'
  Write-Host '4) CLI 도구는 설치하지 않음'
  $aiChoice = Read-WizardChoice -Prompt '선택:' -Default '1'
  switch ($aiChoice) {
    '1' { $plan.ai = @{ choice = '1'; services = @('Codex CLI'); codex = '1'; claude = '0'; summary = 'Codex CLI 설치' } }
    '2' { $plan.ai = @{ choice = '2'; services = @('Claude Code CLI'); codex = '0'; claude = '1'; summary = 'Claude Code CLI 설치' } }
    '3' { $plan.ai = @{ choice = '3'; services = @('Codex CLI', 'Claude Code CLI'); codex = '1'; claude = '1'; summary = 'Codex CLI + Claude Code CLI 설치' } }
    default { $plan.ai = @{ choice = '4'; services = @(); codex = '0'; claude = '0'; summary = 'CLI 도구는 설치하지 않음' } }
  }

  Write-Step '4단계 추가 도구 추천'
  Write-Host '추가 기능은 하나씩 확인합니다. 각 항목은 설치 또는 설치하지 않음으로 기록합니다.'
  foreach ($id in @('matt-pocock-skills', 'superpowers', 'lazy-codex', 'oh-my-claudecode')) {
    Show-RecommendationCard -Id $id | ForEach-Object { Write-Host $_ }
    switch ($id) {
      'matt-pocock-skills' {
        Write-Host '질문: 무엇부터 해야 할지 잘 모를 때, 체계적으로 설계하고 작업할 수 있게 도와주는 스킬인 Matt Pocock Skills를 설치할까요?'
      }
      'superpowers' {
        Write-Host '질문: 아이디어가 있을 때 아이디어를 구체화해서 작업 계획까지 세워주는 스킬인 Superpowers를 설치할까요?'
      }
      'lazy-codex' {
        Write-Host '질문: Codex를 사용할 때 코딩, 수정, 검증 작업을 구조적으로 도와주는 도구인 Lazy-Codex를 설치할까요?'
      }
      'oh-my-claudecode' {
        Write-Host '질문: Claude Code 사용을 쉽게 도와주는 도구인 Oh-My-Claudecode를 설치할까요?'
      }
    }
    Write-Host '1) 네 설치할게요'
    Write-Host '2) 설치하지 않을게요'
    $decision = Read-WizardChoice -Prompt '선택:' -Default '2'
    $title = Get-RecommendationTitle -Id $id
    $plan.addons += @{ id = $id; title = $title; install = (Test-WizardYesChoice -Choice $decision) }
  }

  return ,$plan
}

function Show-WizardFinalPlan {
  param([Parameter(Mandatory)]$Plan)
  $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
  $targetDir = Join-Path (Join-Path (Join-Path $homeDir 'Documents') 'Codex') 'bss-ai-boiler-plate'
  $selectedAddons = @($Plan.addons | Where-Object { $_.install } | ForEach-Object { $_.title })
  $skippedAddons = @($Plan.addons | Where-Object { -not $_.install } | ForEach-Object { $_.title })

  Write-Output ''
  Write-Output 'Final Installation Plan(최종 설치 계획)'
  Write-Output "- OS(운영체제): $($Plan.platform)"
  Write-Output "- 표준 작업 폴더: $targetDir"
  if ($Plan.includeBase) {
    Write-Output "- 기본 환경: $($Plan.base.summary)"
  } else {
    Write-Output '- 기본 환경: 이번 흐름에서는 변경하지 않음'
  }
  Write-Output "- GitHub: $($Plan.github.summary)"
  Write-Output "- AI CLI 도구: $($Plan.ai.summary)"
  if ($selectedAddons.Count -gt 0) {
    Write-Output "- 추가 기능 설치: $($selectedAddons -join ', ')"
  } else {
    Write-Output '- 추가 기능 설치: 없음'
  }
  if ($skippedAddons.Count -gt 0) {
    Write-Output "- 추가 기능 미설치: $($skippedAddons -join ', ')"
  }
  Write-Output '- 실행 프리셋: .\windows\install.ps1 -Standard 흐름과 같은 Windows 초보자 표준 선택'
  Write-Output ''
  Write-Output '시작하려면 "승인" 또는 "진행"이라고 입력하세요.'
}

function Invoke-WizardBasePlan {
  param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$Root)
  if (-not $Plan.base.install) {
    Set-StepStatus -Step 'base-tools' -Status 'skipped' -Note $Plan.platform
    Set-StepStatus -Step 'shell' -Status 'skipped' -Note $Plan.platform
    return
  }
  Set-StepStatus -Step 'base-tools' -Status 'in_progress'
  Invoke-InstallerStep -Id 'prereqs' -Root $Root
  Invoke-InstallerStep -Id 'packages' -Root $Root
  Invoke-InstallerStep -Id 'runtimes' -Root $Root
  Invoke-InstallerStep -Id 'shell' -Root $Root
  Set-StepStatus -Step 'base-tools' -Status 'complete' -Note "$($Plan.platform) dry-run=$($script:DryRun)"
  Set-StepStatus -Step 'shell' -Status 'complete' -Note "$($Plan.platform) dry-run=$($script:DryRun)"
}

function Invoke-WizardGithubPlan {
  param([Parameter(Mandatory)]$Plan)
  switch ($Plan.github.choice) {
    '1' {
      if ($env:BSS_AI_HELPER_QA_GH -eq 'missing') {
        Write-Warn 'gh CLI가 없습니다. 1단계 기본 설치에서 gh를 설치한 뒤 다시 시도할 수 있습니다.'
        Set-StepStatus -Step 'github' -Status 'failed' -Note 'gh CLI 없음'
        return
      }
      if ($script:DryRun -or $env:BSS_AI_HELPER_QA_GH -eq 'success') {
        Write-Info '[dry-run] gh auth login'
        Write-Info '[dry-run] gh auth status'
        Set-StepStatus -Step 'github' -Status 'complete' -Note 'gh auth login 확인'
        return
      }
      if (-not (Test-HasCommand gh)) {
        Write-Warn 'gh CLI가 없습니다. 1단계 기본 설치를 먼저 실행하세요.'
        Set-StepStatus -Step 'github' -Status 'failed' -Note 'gh CLI 없음'
        return
      }
      Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
      if ($LASTEXITCODE -eq 0) {
        Set-StepStatus -Step 'github' -Status 'complete' -Note '이미 로그인됨'
        return
      }
      & gh auth login
      $loginExit = $LASTEXITCODE
      Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
      if ($loginExit -eq 0 -and $LASTEXITCODE -eq 0) {
        Set-StepStatus -Step 'github' -Status 'complete' -Note 'gh auth login 완료'
        return
      }
      Set-StepStatus -Step 'github' -Status 'failed' -Note 'gh auth login 실패'
    }
    '2' {
      if ($script:DryRun) { Write-Info '[dry-run] Start-Process https://github.com/signup' } else { Start-Process 'https://github.com/signup' }
      Set-StepStatus -Step 'github' -Status 'skipped' -Note '가입 링크 열기'
    }
    '4' { Show-Status }
    default {
      Set-StepStatus -Step 'github' -Status 'skipped' -Note '사용자가 지금은 건너뜀'
    }
  }
}

function Invoke-WizardAiPlan {
  param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$Root)
  $services = @($Plan.ai.services)
  $env:BSS_AI_INSTALL_CODEX = $Plan.ai.codex
  $env:BSS_AI_INSTALL_CLAUDE = $Plan.ai.claude
  $env:BSS_AI_INSTALL_MATT = '0'
  $env:BSS_AI_INSTALL_EXTRAS = '0'
  $env:BSS_AI_HELPER_FORCE_INSTALL_PREVIEW = '1'
  if ($services.Count -eq 0) {
    Add-AiService -Services @()
    Set-StepStatus -Step 'ai-tools' -Status 'skipped' -Note 'CLI 도구 설치하지 않음'
    return
  }
  Add-AiService -Services $services
  . (Join-Path $Root 'scripts\07-agents.ps1')
  $result = @(Step-Agents)
  $ok = if ($result.Count -gt 0) { [bool]$result[-1] } else { $true }
  if ($ok) {
    Set-AiServiceStatus -Services $services -Status 'complete'
    Set-StepStatus -Step 'ai-tools' -Status 'complete' -Note ($services -join ',')
    return
  }
  Set-AiServiceStatus -Services $services -Status 'failed' -Reason '설치 실패'
  Set-StepStatus -Step 'ai-tools' -Status 'failed' -Note "$($services -join ',') 설치 실패"
}

function Invoke-WizardAddonsPlan {
  param([Parameter(Mandatory)]$Plan)
  foreach ($addon in @($Plan.addons)) {
    if ($addon.install) {
      $status = Invoke-AddonInstall -Id $addon.id -Title $addon.title
      if ($status -eq 'complete') { Set-StepStatus -Step 'addons' -Status 'complete' -Note "$($addon.title) 처리" }
      elseif ($status -eq 'skipped') { Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$($addon.title) 건너뜀" }
      else { Set-StepStatus -Step 'addons' -Status 'failed' -Note "$($addon.title) 실패" }
    } else {
      Set-AddonStatus -Id $addon.id -Title $addon.title -Status 'skipped' -Note '사용자가 설치하지 않음'
      $state = Read-HelperState
      if (-not $state['steps'].ContainsKey('addons')) {
        Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$($addon.title) 설치하지 않음"
      }
    }
  }
}

function Invoke-WizardPlan {
  param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$Root)
  if ($Plan.includeBase) { Invoke-WizardBasePlan -Plan $Plan -Root $Root }
  Invoke-WizardGithubPlan -Plan $Plan
  Invoke-WizardAiPlan -Plan $Plan -Root $Root
  Invoke-WizardAddonsPlan -Plan $Plan
}

function Start-WizardPlanFlow {
  param(
    [string]$Platform = 'Windows',
    [Parameter(Mandatory)][string]$Root,
    [switch]$IncludeBase
  )
  $plan = New-WizardPlan -Platform $Platform -Root $Root -IncludeBase:$IncludeBase
  if (-not $plan.valid) {
    Show-Status
    return
  }
  Show-WizardFinalPlan -Plan $plan
  $approval = Read-WizardChoice -Prompt '승인 입력:' -Default ''
  if (-not (Test-WizardApproval -Choice $approval)) {
    Write-Warn '승인 또는 진행이 아니어서 설치를 시작하지 않습니다.'
    return
  }
  Invoke-WizardPlan -Plan $plan -Root $Root
  Write-Ok "질문형 설치를 마쳤습니다. 상태 파일: $(Get-StatePath)"
}

function Start-Wizard {
  param([string]$Platform = 'Windows', [string]$Root)
  Initialize-HelperState
  Write-Step 'ai-boiler-plate 질문형 설치'
  Write-Info '한 번에 전부 설치하지 않고 필요한 항목을 질문으로 확인합니다.'
  Write-Output '1) 상태만 보기'
  Write-Output '2) 1단계 기본 설치 준비'
  Write-Output '3) GitHub, AI 도구, 추가 도구 설정'
  Write-Output '4) 기존 설치 방식으로 실행'
  Write-Output '5) 종료'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '1'
  switch ($choice) {
    '1' { Show-Status }
    '2' {
      Start-WizardPlanFlow -Platform $Platform -Root $Root -IncludeBase
    }
    '3' {
      Start-WizardPlanFlow -Platform $Platform -Root $Root
    }
    '4' { $script:WizardClassicRequested = $true; return }
    default { Write-Info '종료합니다.' }
  }
}
