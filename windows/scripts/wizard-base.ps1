function Invoke-InstallerStep {
  param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Root)
  $files = @{
    prereqs = '01-prereqs.ps1'
    packages = '02-packages.ps1'
    runtimes = '03-runtimes.ps1'
    shell = '04-shell.ps1'
  }
  $funcs = @{
    prereqs = 'Step-Prereqs'
    packages = 'Step-Packages'
    runtimes = 'Step-Runtimes'
    shell = 'Step-Shell'
  }
  $file = Join-Path $Root ("scripts\" + $files[$Id])
  if (-not (Test-Path $file)) { Stop-Kit "missing step file: $file" }
  . $file
  & $funcs[$Id]
}

function Invoke-BaseStep {
  param([string]$Platform = 'Windows', [Parameter(Mandatory)][string]$Root)
  if (-not (Test-IsWindows)) { Stop-Kit 'This kit targets Windows only.' }
  Write-Step '1단계 기본 설치 준비'
  Write-Info '기본 환경은 개발 도구가 실행될 바탕 프로그램입니다.'
  Write-Info '패키지는 필요한 프로그램을 내려받아 설치하는 묶음입니다.'
  Write-Info '런타임은 Node.js나 Python처럼 개발 도구가 돌아가게 해주는 실행기입니다.'
  Write-Info '셸은 PowerShell이나 터미널처럼 명령을 입력하는 창입니다.'
  Write-Info 'Docker는 기본 질문형 설치에서 제외합니다. 나중에 고급 단계에서 따로 선택합니다.'
  Write-Output '기본 환경을 전체 설치할까요?'
  Write-Output '1) 네, 전체 설치할게요'
  Write-Output '2) 설치하지 않을게요'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '1'
  switch ($choice) {
    { $_ -in @('네', '네, 전체 설치할게요', '네 전체 설치할게요', '전체 설치') } {
      Set-StepStatus -Step 'base-tools' -Status 'in_progress'
      Invoke-InstallerStep -Id 'prereqs' -Root $Root
      Invoke-InstallerStep -Id 'packages' -Root $Root
      Invoke-InstallerStep -Id 'runtimes' -Root $Root
      Invoke-InstallerStep -Id 'shell' -Root $Root
      Set-StepStatus -Step 'base-tools' -Status 'complete' -Note "$Platform dry-run=$($script:DryRun)"
      Set-StepStatus -Step 'shell' -Status 'complete' -Note "$Platform dry-run=$($script:DryRun)"
    }
    '1' {
      Set-StepStatus -Step 'base-tools' -Status 'in_progress'
      Invoke-InstallerStep -Id 'prereqs' -Root $Root
      Invoke-InstallerStep -Id 'packages' -Root $Root
      Invoke-InstallerStep -Id 'runtimes' -Root $Root
      Invoke-InstallerStep -Id 'shell' -Root $Root
      Set-StepStatus -Step 'base-tools' -Status 'complete' -Note "$Platform dry-run=$($script:DryRun)"
      Set-StepStatus -Step 'shell' -Status 'complete' -Note "$Platform dry-run=$($script:DryRun)"
    }
    { $_ -in @('아니오', '설치하지 않을게요', '설치하지 않음') } {
      Set-StepStatus -Step 'base-tools' -Status 'skipped' -Note $Platform
      Set-StepStatus -Step 'shell' -Status 'skipped' -Note $Platform
      Show-Status
      return
    }
    '2' {
      Set-StepStatus -Step 'base-tools' -Status 'skipped' -Note $Platform
      Set-StepStatus -Step 'shell' -Status 'skipped' -Note $Platform
      Show-Status
      return
    }
    default {
      Write-Warn '알 수 없는 선택입니다. 상태만 표시합니다.'
      Show-Status
      return
    }
  }
}

function Invoke-GithubStep {
  while ($true) {
    Write-Step '2단계 GitHub 연결'
    Write-Output '1) 연결하기'
    Write-Output '2) 가입 링크 열기'
    Write-Output '3) 지금은 건너뛰기'
    Write-Output '4) 상태만 보기'
    $choice = Read-WizardChoice -Prompt '선택:' -Default '3'
    switch ($choice) {
      '1' {
        if ($env:BSS_AI_HELPER_QA_GH -eq 'missing') {
          Write-Warn 'gh CLI가 없습니다. 1단계 기본 설치에서 gh를 설치한 뒤 다시 시도할 수 있습니다.'
          Set-StepStatus -Step 'github' -Status 'failed' -Note 'gh CLI 없음'
          $decision = Invoke-WizardRecovery -Step 'github' -Title 'GitHub 연결'
          if ($decision -eq 'skip') { return }
          continue
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
          $decision = Invoke-WizardRecovery -Step 'github' -Title 'GitHub 연결'
          if ($decision -eq 'skip') { return }
          continue
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
        $decision = Invoke-WizardRecovery -Step 'github' -Title 'GitHub 연결'
        if ($decision -eq 'skip') { return }
      }
      '2' {
        if ($script:DryRun) { Write-Info '[dry-run] Start-Process https://github.com/signup' } else { Start-Process 'https://github.com/signup' }
        Write-Info '가입을 마쳤으면 다시 연결하기를 선택하세요.'
      }
      '4' { Show-Status }
      default {
        Write-Warn 'GitHub를 건너뛰면 나중에 오픈소스 설치나 저장소 작업이 덜 매끄러울 수 있습니다.'
        Set-StepStatus -Step 'github' -Status 'skipped' -Note '사용자가 지금은 건너뜀'
        return
      }
    }
  }
}
