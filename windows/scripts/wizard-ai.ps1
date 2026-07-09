function Convert-SafeAiServiceNames {
  param([string]$Raw)
  $safe = @()
  foreach ($item in ($Raw -split ',')) {
    $clean = (($item -replace '[\p{Cc}]', '').Trim())
    if ($clean.Length -gt 40) { $clean = $clean.Substring(0, 40) }
    if ([string]::IsNullOrWhiteSpace($clean)) { continue }
    if ($clean -match '(?i)(gh[pousr]_|sk-|oauth|token|password|비밀번호)') {
      Write-Warn '민감정보처럼 보이는 입력은 저장하지 않았습니다.'
      continue
    }
    $safe += $clean
  }
  return $safe
}

function Invoke-AiToolsStep {
  param([string]$Root)
  Write-Step '3단계 AI CLI 도구 선택'
  Write-Output 'Codex 앱은 이미 설치했다고 보고, 터미널에서 쓰는 CLI 명령만 확인합니다.'
  Write-Output '1) Codex CLI 설치'
  Write-Output '2) Claude Code CLI 설치'
  Write-Output '3) Codex CLI + Claude Code CLI 설치'
  Write-Output '4) CLI 도구는 설치하지 않음'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '1'
  $services = @()
  $env:BSS_AI_INSTALL_CODEX = '0'
  $env:BSS_AI_INSTALL_CLAUDE = '0'
  $env:BSS_AI_INSTALL_MATT = '0'
  $env:BSS_AI_INSTALL_EXTRAS = '0'
  $env:BSS_AI_HELPER_FORCE_INSTALL_PREVIEW = '1'
  switch ($choice) {
    '1' { $services = @('Codex CLI'); $env:BSS_AI_INSTALL_CODEX = '1' }
    '2' { $services = @('Claude Code CLI'); $env:BSS_AI_INSTALL_CLAUDE = '1' }
    '3' { $services = @('Codex CLI', 'Claude Code CLI'); $env:BSS_AI_INSTALL_CODEX = '1'; $env:BSS_AI_INSTALL_CLAUDE = '1' }
    default {
      Add-AiService -Services @()
      Set-StepStatus -Step 'ai-tools' -Status 'skipped' -Note 'CLI 도구 설치하지 않음'
      return
    }
  }
  Add-AiService -Services $services
  . (Join-Path $Root 'scripts\07-agents.ps1')
  while ($true) {
    $result = @(Step-Agents)
    $ok = if ($result.Count -gt 0) { [bool]$result[-1] } else { $true }
    if ($ok) {
      Set-AiServiceStatus -Services $services -Status 'complete'
      Set-StepStatus -Step 'ai-tools' -Status 'complete' -Note ($services -join ',')
      return
    }
    Write-Warn 'AI 도구 설치가 끝나지 않았습니다. 권한, 로그인 상태, Node/npm 설치 상태를 확인해야 합니다.'
    Set-AiServiceStatus -Services $services -Status 'failed' -Reason '설치 실패'
    Set-StepStatus -Step 'ai-tools' -Status 'failed' -Note "$($services -join ',') 설치 실패"
    $decision = Invoke-WizardRecovery -Step 'ai-tools' -Title 'AI 도구 설치'
    if ($decision -eq 'skip') { return }
  }
}

function Invoke-AddonsStep {
  Write-Step '4단계 추가 도구 추천'
  Write-Output '추가 기능은 하나씩 확인합니다. 각 항목은 설치 또는 설치하지 않음으로 기록합니다.'
  foreach ($id in @('matt-pocock-skills', 'superpowers', 'lazy-codex', 'oh-my-claudecode')) {
    Show-RecommendationCard -Id $id
    switch ($id) {
      'matt-pocock-skills' {
        Write-Output '질문: 무엇부터 해야 할지 잘 모를 때, 체계적으로 설계하고 작업할 수 있게 도와주는 스킬인 Matt Pocock Skills를 설치할까요?'
      }
      'superpowers' {
        Write-Output '질문: 아이디어가 있을 때 아이디어를 구체화해서 작업 계획까지 세워주는 스킬인 Superpowers를 설치할까요?'
      }
      'lazy-codex' {
        Write-Output '질문: Codex를 사용할 때 코딩, 수정, 검증 작업을 구조적으로 도와주는 도구인 Lazy-Codex를 설치할까요?'
      }
      'oh-my-claudecode' {
        Write-Output '질문: Claude Code 사용을 쉽게 도와주는 도구인 Oh-My-Claudecode를 설치할까요?'
      }
    }
    Write-Output '1) 네 설치할게요'
    Write-Output '2) 설치하지 않을게요'
    $decision = Read-WizardChoice -Prompt '선택:' -Default '2'
    $title = Get-RecommendationTitle -Id $id
    if ($decision -eq '1') {
      $status = Invoke-AddonInstall -Id $id -Title $title
      if ($status -eq 'complete') { Set-StepStatus -Step 'addons' -Status 'complete' -Note "$title 처리" }
      elseif ($status -eq 'skipped') { Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$title 건너뜀" }
      else { Set-StepStatus -Step 'addons' -Status 'failed' -Note "$title 실패" }
    } else {
      Set-AddonStatus -Id $id -Title $title -Status 'skipped' -Note '사용자가 설치하지 않음'
      Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$title 설치하지 않음"
    }
  }
  Write-Info 'Final Installation Plan(최종 설치 계획)에는 지금까지 선택한 기본 환경, AI 도구, 추가 기능 선택 결과를 포함해야 합니다.'
}

function Invoke-AddonInstall {
  param([string]$Id, [string]$Title)
  $commands = @(Get-RecommendationInstallCommand -Id $Id)
  while ($true) {
    if ($commands.Count -eq 1 -and $commands[0] -eq 'status-only') {
      Write-Info "$Title은 추가 설치가 아니라 상태 확인 항목입니다."
      Set-AddonStatus -Id $Id -Title $Title -Status 'skipped' -Note 'status-only'
      return 'skipped'
    }
    if ($env:BSS_AI_HELPER_QA_INSTALL_FAIL -eq 'permission') {
      Write-Warn "$Title 설치 권한이 부족합니다. 관리자 권한이나 도구별 로그인 상태를 확인해야 합니다."
      Set-AddonStatus -Id $Id -Title $Title -Status 'failed' -Note 'permission'
      $decision = Invoke-WizardRecovery -Step 'addons' -Title "$Title 설치"
      if ($decision -eq 'skip') {
        Set-AddonStatus -Id $Id -Title $Title -Status 'skipped' -Note 'permission 후 건너뜀'
        return 'skipped'
      }
      continue
    }
    if ($script:DryRun) {
      foreach ($cmd in $commands) { Write-Info "[dry-run] would run: $cmd" }
      Set-AddonStatus -Id $Id -Title $Title -Status 'complete' -Note 'dry-run install approved'
      return 'complete'
    }
    $ok = $true
    foreach ($cmd in $commands) {
      & cmd.exe /c $cmd
      if ($LASTEXITCODE -ne 0) {
        $ok = $false
        break
      }
    }
    if ($ok) {
      Set-AddonStatus -Id $Id -Title $Title -Status 'complete' -Note 'installed'
      return 'complete'
    }
    Write-Warn "$Title 설치가 끝나지 않았습니다."
    Set-AddonStatus -Id $Id -Title $Title -Status 'failed' -Note 'install failed'
    $decision = Invoke-WizardRecovery -Step 'addons' -Title "$Title 설치"
    if ($decision -eq 'skip') {
      Set-AddonStatus -Id $Id -Title $Title -Status 'skipped' -Note 'install failed 후 건너뜀'
      return 'skipped'
    }
  }
}
