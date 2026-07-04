function Read-WizardChoice {
  param([string]$Prompt, [string]$Default = '')
  if ($script:AssumeYes) { return $Default }
  if ([Console]::IsInputRedirected) {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) {
      Write-Warn 'No redirected wizard input was available; using the safe default choice.'
      return $Default
    }
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

function Start-Wizard {
  param([string]$Platform = 'Windows', [string]$Root)
  $script:WizardRequestedClassic = $false
  Initialize-HelperState
  Write-Step 'BSS AI Helper 질문형 설치'
  Write-Info '한 번에 전부 설치하지 않고 필요한 항목을 질문으로 확인합니다.'
  Write-Output '1) 상태만 보기'
  Write-Output '2) 1단계 기본 설치 준비'
  Write-Output '3) GitHub, AI 도구, 추가 도구 설정'
  Write-Output '4) 기존 설치 방식으로 실행 (classic)'
  Write-Output '5) 종료'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '1'
  if ($choice -eq '1') {
    Show-Status
  } elseif ($choice -eq '2') {
    Invoke-BaseStep -Platform $Platform -Root $Root
    Invoke-GithubStep
    Invoke-AiToolsStep -Root $Root
    Invoke-AddonsStep
    Write-Ok "질문형 설치를 마쳤습니다. 상태 파일: $(Get-StatePath)"
  } elseif ($choice -eq '3') {
    Invoke-GithubStep
    Invoke-AiToolsStep -Root $Root
    Invoke-AddonsStep
    Write-Ok "질문형 설정을 마쳤습니다. 상태 파일: $(Get-StatePath)"
  } elseif (@('4', 'classic', '기존') -contains $choice) {
    $script:WizardRequestedClassic = $true
    Write-Info '기존 단계형 설치로 전환합니다.'
  } elseif ($choice -eq '5') {
    Write-Info '종료합니다.'
  } else {
    Write-Warn '알 수 없는 선택입니다. 상태만 표시합니다.'
    Show-Status
  }
}
