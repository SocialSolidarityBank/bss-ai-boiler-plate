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
  $script:WizardAiServices = @()
  Write-Step '3단계 AI 도구 선택'
  Write-Output '1) Codex'
  Write-Output '2) Claude'
  Write-Output '3) 둘 다'
  Write-Output '4) 아직 정하지 않음'
  Write-Output '5) 직접 입력'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '4'
  $services = @()
  $env:BSS_AI_INSTALL_CODEX = '0'
  $env:BSS_AI_INSTALL_CLAUDE = '0'
  $env:BSS_AI_INSTALL_EXTRAS = '0'
  $env:BSS_AI_HELPER_FORCE_INSTALL_PREVIEW = '1'
  switch ($choice) {
    '1' { $services = @('Codex'); $env:BSS_AI_INSTALL_CODEX = '1' }
    '2' { $services = @('Claude'); $env:BSS_AI_INSTALL_CLAUDE = '1' }
    '3' { $services = @('Codex', 'Claude'); $env:BSS_AI_INSTALL_CODEX = '1'; $env:BSS_AI_INSTALL_CLAUDE = '1' }
    '5' {
      $raw = Read-WizardChoice -Prompt '서비스 이름:' -Default ''
      $services = @(Convert-SafeAiServiceNames -Raw $raw)
      if ($services.Count -eq 0) { $services = @('직접 입력') }
      Write-Info "지원하지 않는 서비스는 기록만 하고 자동 설치하지 않습니다: $($services -join ', ')"
    }
    default {
      $script:WizardAiServices = @()
      Add-AiService -Services @()
      Set-StepStatus -Step 'ai-tools' -Status 'skipped' -Note '아직 정하지 않음'
      return
    }
  }
  $script:WizardAiServices = @($services)
  Add-AiService -Services $services
  if ($env:BSS_AI_INSTALL_CODEX -ne '1' -and $env:BSS_AI_INSTALL_CLAUDE -ne '1') {
    Set-StepStatus -Step 'ai-tools' -Status 'complete' -Note ($services -join ',')
    return
  }
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
  $state = Read-HelperState
  $services = @($state['ai_services'])
  if ($script:WizardAiServices -and $script:WizardAiServices.Count -gt 0) {
    $services = @($script:WizardAiServices)
  }
  Write-Output '1) 강한 오케스트레이션, 멀티 서브 에이전트'
  Write-Output '2) 질문 항목을 하나씩 설계해주는 선생님'
  Write-Output '3) Codex로 긴 자동 설치/수정 작업'
  Write-Output '4) 고급 에이전트 도구'
  Write-Output '5) 추천 없이 마치기'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '5'
  $preference = if ($choice -eq '1') { 'orchestration' } elseif ($choice -eq '2') { 'teacher' } elseif ($choice -eq '3') { 'long-work' } elseif ($choice -eq '4') { 'advanced' } else { 'none' }
  $candidates = @(Get-RecommendationCandidates -Services $services -Preference $preference)
  $id = Get-RecommendationPick -Services $services -Preference $preference
  if (-not $id -and $candidates.Count -gt 0) { $id = $candidates[0] }
  if (-not $id) {
    Write-Info '현재 선택으로는 자동 설치할 수 있는 추가 도구가 없습니다.'
    Set-StepStatus -Step 'addons' -Status 'skipped' -Note '자동 설치 가능한 추천 없음'
    return
  }
  $seen = @()
  while ($id) {
    $seen += $id
    Show-RecommendationCard -Id $id
    Write-Output '1) 설치'
    Write-Output '2) 나중에'
    Write-Output '3) 설치하지 않음'
    Write-Output '4) 자세히 보기'
    Write-Output '5) 상태만 보기'
    $decision = Read-WizardChoice -Prompt '선택:' -Default '2'
    $title = Get-RecommendationTitle -Id $id
    if ($decision -eq '1') {
      $status = Invoke-AddonInstall -Id $id -Title $title
      if ($status -eq 'complete') { Set-StepStatus -Step 'addons' -Status 'complete' -Note "$title 처리" }
      elseif ($status -eq 'skipped') { Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$title 건너뜀" }
      else { Set-StepStatus -Step 'addons' -Status 'failed' -Note "$title 실패" }
    } elseif ($decision -eq '3') {
      Set-AddonStatus -Id $id -Title $title -Status 'skipped' -Note '사용자가 설치하지 않음'
      Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$title 설치하지 않음"
    } elseif ($decision -eq '4') {
      Show-RecommendationCard -Id $id -Details
      continue
    } elseif ($decision -eq '5') {
      Show-Status
      continue
    } else {
      Set-AddonStatus -Id $id -Title $title -Status 'pending' -Note '나중에'
      Set-StepStatus -Step 'addons' -Status 'skipped' -Note "$title 나중에"
    }
    Write-Output '다른 추천도 볼까요?'
    Write-Output '1) 네'
    Write-Output '2) 아니요'
    $another = Read-WizardChoice -Prompt '선택:' -Default '2'
    if ($another -ne '1') { return }
    $id = $null
    foreach ($candidate in $candidates) {
      if ($seen -notcontains $candidate) { $id = $candidate; break }
    }
    if (-not $id) {
      Write-Info '지금 조건에서 더 보여드릴 추천은 없습니다.'
      return
    }
  }
}

function Invoke-AddonInstall {
  param([string]$Id, [string]$Title)
  $cmd = Get-RecommendationInstallCommand -Id $Id
  while ($true) {
    if ($cmd -eq 'status-only') {
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
      Write-Info "[dry-run] would run: $cmd"
      Set-AddonStatus -Id $Id -Title $Title -Status 'complete' -Note 'dry-run install approved'
      return 'complete'
    }
    & cmd.exe /c $cmd
    if ($LASTEXITCODE -eq 0) {
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
