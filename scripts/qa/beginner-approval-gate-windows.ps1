[CmdletBinding()]
param(
  [ValidateSet('Regression', 'Baseline', 'Adversarial', 'MalformedStandard')]
  [string]$Mode = 'Regression'
)

$ErrorActionPreference = 'Stop'

$QaDir = Split-Path -Parent $PSCommandPath
$Root = Split-Path -Parent (Split-Path -Parent $QaDir)
$EvidenceDir = if ($env:EVIDENCE_DIR) { $env:EVIDENCE_DIR } else { Join-Path $Root '.omo\evidence' }
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$TranscriptPath = Join-Path $EvidenceDir 'task-1-windows-beginner-approval-gate.txt'
$BaselineTranscriptPath = Join-Path $EvidenceDir 'task-1-windows-baseline-current-early-execution.txt'
$AdversarialTranscriptPath = Join-Path $EvidenceDir 'task-1-windows-adversarial-probes.txt'
$MalformedStandardTranscriptPath = Join-Path $EvidenceDir 'task-1-windows-malformed-standard-plan.txt'
$ApprovalWord = -join @([char]0xC2B9, [char]0xC778)
$ProceedWord = -join @([char]0xC9C4, [char]0xD589)

function Fail-Qa {
  param([Parameter(Mandatory)][string]$Message)
  Write-Error "FAIL $Message"
  exit 1
}

function Assert-Contains {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Pattern)
  $text = Get-Content -Raw -Path $Path
  if ($text -notmatch $Pattern) { Fail-Qa "missing pattern '$Pattern' in $Path" }
}

function Assert-NotContains {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Pattern)
  $text = Get-Content -Raw -Path $Path
  if ($text -match $Pattern) { Fail-Qa "unexpected pattern '$Pattern' in $Path" }
}

function Get-FirstLine {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Needle)
  $lineNo = 0
  foreach ($line in Get-Content -Path $Path) {
    $lineNo += 1
    if ($line.Contains($Needle)) { return $lineNo }
  }
  return $null
}

function Assert-LineOrder {
  param(
    [Parameter(Mandatory)][string]$BeforeName,
    [Nullable[int]]$Before,
    [Parameter(Mandatory)][string]$AfterName,
    [Nullable[int]]$After
  )
  if ($null -eq $Before) { Fail-Qa "missing $BeforeName line" }
  if ($null -eq $After) { Fail-Qa "missing $AfterName line" }
  if ($Before -ge $After) { Fail-Qa "$BeforeName line $Before must come before $AfterName line $After" }
}

function New-TempDir {
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ("bss-helper-qa." + [System.Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  return $path
}

function Invoke-Scenario {
  param(
    [Parameter(Mandatory)][string]$OutPath,
    [Parameter(Mandatory)][string[]]$Inputs,
    [switch]$StaleState,
    [switch]$MisleadingSuccess
  )

  $helperHome = New-TempDir
  $scenarioDir = New-TempDir
  $staleBefore = $null
  $inputPath = Join-Path $scenarioDir 'inputs.txt'
  $scenarioPath = Join-Path $scenarioDir 'scenario.ps1'
  Set-Content -Path $inputPath -Value $Inputs -Encoding UTF8
  if ($StaleState) {
    $stalePath = Join-Path $helperHome 'state.json'
    Set-Content -Path $stalePath -Value '{ stale state' -Encoding UTF8
    $staleBefore = (Get-Content -Raw -Path $stalePath).Replace("`r", '').Replace("`n", ' ')
  }

  $scenario = @'
param(
  [Parameter(Mandatory)][string]$Root,
  [Parameter(Mandatory)][string]$HelperHome,
  [Parameter(Mandatory)][string]$InputPath,
  [string]$MisleadingSuccess = '0'
)
$ErrorActionPreference = 'Stop'
$script:DryRun = $true
$script:AssumeYes = $false
$env:AI_BOILER_PLATE_HOME = $HelperHome
$env:BSS_AI_HELPER_HOME = $HelperHome
. (Join-Path $Root 'windows\scripts\lib.ps1')
. (Join-Path $Root 'windows\scripts\state.ps1')
. (Join-Path $Root 'windows\scripts\recommendations.ps1')
. (Join-Path $Root 'windows\scripts\wizard.ps1')

$script:QaInputs = [System.Collections.Queue]::new()
foreach ($line in Get-Content -Path $InputPath -Encoding UTF8) { $script:QaInputs.Enqueue($line) }

function Read-WizardChoice {
  param([string]$Prompt, [string]$Default = '')
  $answer = if ($script:QaInputs.Count -gt 0) { [string]$script:QaInputs.Dequeue() } else { $Default }
  Write-Host "QA_INPUT: $answer"
  if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
  return $answer
}

function Invoke-InstallerStep {
  param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Root)
  Write-Output "QA_EXECUTE_MARKER windows:installer:$Id"
  Set-StepStatus -Step $Id -Status 'complete' -Note 'qa stub'
}

function Invoke-GithubStep {
  Write-Step '2단계 GitHub 연결'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '3'
  if ($MisleadingSuccess -eq '1') { Write-Output 'QA_MISLEADING_SUCCESS_OUTPUT windows:github-present' }
  if ($choice -eq '1') {
    Write-Output 'QA_EXECUTE_MARKER windows:github'
    Set-StepStatus -Step 'github' -Status 'complete' -Note 'qa stub'
  } else {
    Set-StepStatus -Step 'github' -Status 'skipped' -Note 'qa stub'
  }
}

function Invoke-AiToolsStep {
  param([string]$Root)
  Write-Step '3단계 AI CLI 도구 선택'
  $choice = Read-WizardChoice -Prompt '선택:' -Default '4'
  if ($choice -ne '4') {
    Write-Output "QA_EXECUTE_MARKER windows:ai-tools:$choice"
    Set-StepStatus -Step 'ai-tools' -Status 'complete' -Note 'qa stub'
  } else {
    Set-StepStatus -Step 'ai-tools' -Status 'skipped' -Note 'qa stub'
  }
}

function Invoke-AddonInstall {
  param([string]$Id, [string]$Title)
  Write-Output "QA_EXECUTE_MARKER windows:addon:$Id"
  Set-AddonStatus -Id $Id -Title $Title -Status 'complete' -Note 'qa stub'
  return 'complete'
}

function Invoke-WizardPlan {
  param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$Root)
  if ($MisleadingSuccess -eq '1') { Write-Output 'QA_MISLEADING_SUCCESS_OUTPUT windows:github-present' }
  if ($Plan.base.install) {
    foreach ($id in @('prereqs', 'packages', 'runtimes', 'shell')) {
      Invoke-InstallerStep -Id $id -Root $Root
    }
  }
  if ($Plan.github.choice -eq '1') {
    Write-Output 'QA_EXECUTE_MARKER windows:github'
    Set-StepStatus -Step 'github' -Status 'complete' -Note 'qa stub'
  }
  if ($Plan.ai.choice -ne '4') {
    Write-Output "QA_EXECUTE_MARKER windows:ai-tools:$($Plan.ai.choice)"
    Set-StepStatus -Step 'ai-tools' -Status 'complete' -Note 'qa stub'
  }
  foreach ($addon in @($Plan.addons)) {
    if ($addon.install) {
      [void](Invoke-AddonInstall -Id $addon.id -Title $addon.title)
    }
  }
}

function Show-Status {
  Write-Output 'QA_STATUS_VIEW'
}

Start-Wizard -Platform 'Windows' -Root (Join-Path $Root 'windows')
'@
  Set-Content -Path $scenarioPath -Value $scenario -Encoding UTF8

  $exitCode = 0
  try {
    $exe = (Get-Command powershell.exe -ErrorAction Stop).Source
    $misleadingFlag = if ($MisleadingSuccess.IsPresent) { '1' } else { '0' }
    & $exe -NoProfile -ExecutionPolicy Bypass -File $scenarioPath -Root $Root -HelperHome $helperHome -InputPath $inputPath -MisleadingSuccess $misleadingFlag > $OutPath 2>&1
    $exitCode = $LASTEXITCODE
  } catch {
    $exitCode = 1
    $_ | Out-File -FilePath $OutPath -Append -Encoding UTF8
  } finally {
    if ($StaleState) {
      $stalePath = Join-Path $helperHome 'state.json'
      $staleAfter = if (Test-Path $stalePath) { (Get-Content -Raw -Path $stalePath).Replace("`r", '').Replace("`n", ' ') } else { 'MISSING' }
      Write-Output 'QA_STATUS_VIEW' | Add-Content -Path $OutPath
      Add-Content -Path $OutPath -Value 'STALE_STATE_PROBE=malformed-state-preserved'
      Add-Content -Path $OutPath -Value "STALE_STATE_BEFORE=$staleBefore"
      Add-Content -Path $OutPath -Value "STALE_STATE_AFTER=$staleAfter"
      $preserved = if ($staleBefore -eq $staleAfter) { 'yes' } else { 'no' }
      Add-Content -Path $OutPath -Value "STALE_STATE_PRESERVED=$preserved"
    }
    Remove-Item -LiteralPath $helperHome -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scenarioDir -Recurse -Force -ErrorAction SilentlyContinue
    Add-Content -Path $OutPath -Value ""
    Add-Content -Path $OutPath -Value "Cleanup receipt: removed helper_home=$helperHome"
    Add-Content -Path $OutPath -Value "Cleanup receipt: removed scenario_dir=$scenarioDir"
    Add-Content -Path $OutPath -Value "Scenario exit code: $exitCode"
  }
  return $exitCode
}

function Assert-RegressionContract {
  param([Parameter(Mandatory)][string]$Path)
  Assert-Contains -Path $Path -Pattern 'Final Installation Plan'
  $plan = Get-FirstLine -Path $Path -Needle 'Final Installation Plan'
  $approval = Get-FirstLine -Path $Path -Needle "QA_INPUT: $ApprovalWord"
  if ($null -eq $approval) { $approval = Get-FirstLine -Path $Path -Needle "QA_INPUT: $ProceedWord" }
  $marker = Get-FirstLine -Path $Path -Needle 'QA_EXECUTE_MARKER'
  Assert-LineOrder -BeforeName 'Final Installation Plan' -Before $plan -AfterName 'approval input' -After $approval
  Assert-LineOrder -BeforeName 'approval input' -Before $approval -AfterName 'first execution marker' -After $marker
}

function Assert-BaselineContract {
  param([Parameter(Mandatory)][string]$Path)
  Assert-Contains -Path $Path -Pattern 'Final Installation Plan'
  $marker = Get-FirstLine -Path $Path -Needle 'QA_EXECUTE_MARKER'
  $plan = Get-FirstLine -Path $Path -Needle 'Final Installation Plan'
  Assert-LineOrder -BeforeName 'current first execution marker' -Before $marker -AfterName 'current Final Installation Plan' -After $plan
  Assert-NotContains -Path $Path -Pattern "QA_INPUT: $ApprovalWord"
}

function Assert-StaleStateContract {
  param([Parameter(Mandatory)][string]$Path)
  Assert-Contains -Path $Path -Pattern 'QA_STATUS_VIEW'
  Assert-Contains -Path $Path -Pattern 'STALE_STATE_PROBE=malformed-state-preserved'
  Assert-Contains -Path $Path -Pattern 'STALE_STATE_PRESERVED=yes'
  Assert-Contains -Path $Path -Pattern 'Scenario exit code: 0'
  Assert-NotContains -Path $Path -Pattern 'QA_EXECUTE_MARKER'
}

function Invoke-DirtyWorktreeProbe {
  param([Parameter(Mandatory)][string]$OutPath)
  $dirtyRelativePath = 'beginner-approval-dirty-probe.tmp'
  $dirtyPath = Join-Path $Root $dirtyRelativePath
  if (Test-Path $dirtyPath) { Fail-Qa "dirty worktree probe path already exists: $dirtyPath" }
  Set-Content -Path $dirtyPath -Value 'temporary dirty worktree probe' -Encoding UTF8
  $dirtyStatus = (& git -C $Root status --short -- $dirtyRelativePath) -join "`n"
  if ([string]::IsNullOrWhiteSpace($dirtyStatus)) { Fail-Qa 'dirty worktree probe did not create observable git status' }

  $code = Invoke-Scenario -OutPath $OutPath -Inputs @('not-a-menu', $ApprovalWord)

  Remove-Item -LiteralPath $dirtyPath -Force -ErrorAction SilentlyContinue
  $afterStatus = (& git -C $Root status --short -- $dirtyRelativePath) -join "`n"
  Add-Content -Path $OutPath -Value 'DIRTY_WORKTREE_PROBE=untracked-root-file'
  Add-Content -Path $OutPath -Value "DIRTY_WORKTREE_STATUS_DURING=$dirtyStatus"
  $cleanupStatus = if ([string]::IsNullOrWhiteSpace($afterStatus)) { 'clean' } else { $afterStatus }
  Add-Content -Path $OutPath -Value "DIRTY_WORKTREE_CLEANUP_STATUS=$cleanupStatus"

  if ($code -ne 0) { return $code }
  if (-not [string]::IsNullOrWhiteSpace($afterStatus)) { Fail-Qa "dirty worktree probe cleanup left git status: $afterStatus" }
  Assert-NotContains -Path $OutPath -Pattern 'QA_EXECUTE_MARKER'
  Assert-Contains -Path $OutPath -Pattern 'DIRTY_WORKTREE_PROBE=untracked-root-file'
  Assert-Contains -Path $OutPath -Pattern 'DIRTY_WORKTREE_CLEANUP_STATUS=clean'
  return 0
}

function Invoke-StandardPlanScenario {
  param(
    [Parameter(Mandatory)][string]$OutPath,
    [Parameter(Mandatory)][string]$StateJson
  )

  $helperHome = New-TempDir
  $statePath = Join-Path $helperHome 'state.json'
  Set-Content -Path $statePath -Value $StateJson -Encoding UTF8

  $oldAiHome = $env:AI_BOILER_PLATE_HOME
  $oldBssHome = $env:BSS_AI_HELPER_HOME
  $oldErrorActionPreference = $ErrorActionPreference
  $exitCode = 0
  try {
    $env:AI_BOILER_PLATE_HOME = $helperHome
    $env:BSS_AI_HELPER_HOME = $helperHome
    $ErrorActionPreference = 'Continue'
    $exe = (Get-Command powershell.exe -ErrorAction Stop).Source
    & $exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'windows\install.ps1') -Standard -DryRun > $OutPath 2>&1
    $exitCode = $LASTEXITCODE
  } catch {
    $exitCode = 1
    $_ | Out-File -FilePath $OutPath -Append -Encoding UTF8
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    $env:AI_BOILER_PLATE_HOME = $oldAiHome
    $env:BSS_AI_HELPER_HOME = $oldBssHome
    Remove-Item -LiteralPath $helperHome -Recurse -Force -ErrorAction SilentlyContinue
    Add-Content -Path $OutPath -Value ""
    Add-Content -Path $OutPath -Value "Cleanup receipt: removed helper_home=$helperHome"
    Add-Content -Path $OutPath -Value "Scenario exit code: $exitCode"
  }
  return $exitCode
}

function Assert-MalformedStandardContract {
  param([Parameter(Mandatory)][string]$Path)
  $text = Get-Content -Raw -Path $Path
  if ($text -notmatch 'Scenario exit code: [1-9][0-9]*') { Fail-Qa "malformed standard plan unexpectedly exited 0 in $Path" }
  Assert-Contains -Path $Path -Pattern 'Scenario exit code: 2'
  Assert-Contains -Path $Path -Pattern 'Invalid approved installationPlan schema'
  Assert-Contains -Path $Path -Pattern 'no install steps were started'
  Assert-NotContains -Path $Path -Pattern 'Using approved Final Installation Plan'
  Assert-NotContains -Path $Path -Pattern 'DRY-RUN: no changes will be made'
  Assert-NotContains -Path $Path -Pattern '== ai-boiler-plate'
  Assert-NotContains -Path $Path -Pattern 'steps:'
  Assert-NotContains -Path $Path -Pattern 'Prerequisites: winget'
  Assert-NotContains -Path $Path -Pattern 'CLI tools \+ developer toolchain'
  Assert-NotContains -Path $Path -Pattern 'Runtimes: mise'
  Assert-NotContains -Path $Path -Pattern '\[dry-run\] winget'
  Assert-NotContains -Path $Path -Pattern '\[dry-run\] would install via mise'
}

switch ($Mode) {
  'Baseline' {
    [void](Invoke-Scenario -OutPath $BaselineTranscriptPath -Inputs @('2', '1', '3', '4', '1', '2', '2', '2', $ApprovalWord))
    Assert-BaselineContract -Path $BaselineTranscriptPath
    Write-Output "PASS baseline-current-early-execution $BaselineTranscriptPath"
  }
  'Adversarial' {
    Set-Content -Path $AdversarialTranscriptPath -Value 'Adversarial probes for Windows beginner approval gate' -Encoding UTF8

    Add-Content -Path $AdversarialTranscriptPath -Value 'malformed_input: ' -NoNewline
    [void](Invoke-Scenario -OutPath "$AdversarialTranscriptPath.malformed" -Inputs @('not-a-menu', $ApprovalWord))
    Assert-NotContains -Path "$AdversarialTranscriptPath.malformed" -Pattern 'QA_EXECUTE_MARKER'
    Add-Content -Path $AdversarialTranscriptPath -Value 'PASS no execution marker for malformed menu input'

    Add-Content -Path $AdversarialTranscriptPath -Value 'stale_state: ' -NoNewline
    [void](Invoke-Scenario -OutPath "$AdversarialTranscriptPath.stale" -Inputs @('1') -StaleState)
    Assert-StaleStateContract -Path "$AdversarialTranscriptPath.stale"
    Add-Content -Path $AdversarialTranscriptPath -Value 'PASS malformed state is reported, preserved, and does not execute installer steps'

    Add-Content -Path $AdversarialTranscriptPath -Value 'dirty_worktree: ' -NoNewline
    [void](Invoke-DirtyWorktreeProbe -OutPath "$AdversarialTranscriptPath.dirty")
    Add-Content -Path $AdversarialTranscriptPath -Value 'PASS dirty worktree was observable during the scenario and cleaned afterward'

    Add-Content -Path $AdversarialTranscriptPath -Value 'misleading_success_output: ' -NoNewline
    [void](Invoke-Scenario -OutPath "$AdversarialTranscriptPath.misleading" -Inputs @('2', '2', '3', '4', '2', '2', '2', '2', $ApprovalWord) -MisleadingSuccess)
    Assert-Contains -Path "$AdversarialTranscriptPath.misleading" -Pattern 'QA_MISLEADING_SUCCESS_OUTPUT'
    Assert-NotContains -Path "$AdversarialTranscriptPath.misleading" -Pattern 'QA_EXECUTE_MARKER'
    Add-Content -Path $AdversarialTranscriptPath -Value 'PASS success-like text is not treated as execution'

    Remove-Item -LiteralPath "$AdversarialTranscriptPath.malformed", "$AdversarialTranscriptPath.stale", "$AdversarialTranscriptPath.dirty", "$AdversarialTranscriptPath.misleading" -Force -ErrorAction SilentlyContinue
    Add-Content -Path $AdversarialTranscriptPath -Value 'Cleanup receipt: removed adversarial scratch transcripts'
    Write-Output "PASS adversarial-probes $AdversarialTranscriptPath"
  }
  'MalformedStandard' {
    Set-Content -Path $MalformedStandardTranscriptPath -Value 'Malformed approved Windows Standard plan probes' -Encoding UTF8

    $addonsArrayPath = "$MalformedStandardTranscriptPath.addons-array"
    $addonsArrayJson = @'
{
  "installationPlan": {
    "schemaVersion": 1,
    "selectedOS": "Windows",
    "workspaceFolder": "C:\\work",
    "baseEnvironment": "skip",
    "aiCliTools": [],
    "addons": ["lazy-codex"],
    "executionCommand": ".\\windows\\install.ps1 -Standard",
    "approvalStatus": "approved",
    "approvedAt": "2026-07-10T00:00:00Z",
    "secretPolicy": "No tokens, OAuth codes, passwords, private keys, or device codes are stored."
  }
}
'@
    [void](Invoke-StandardPlanScenario -OutPath $addonsArrayPath -StateJson $addonsArrayJson)
    Assert-MalformedStandardContract -Path $addonsArrayPath
    Add-Content -Path $MalformedStandardTranscriptPath -Value 'PASS addons non-map is rejected before install execution'

    $wrongTypesPath = "$MalformedStandardTranscriptPath.wrong-types"
    $wrongTypesJson = @'
{
  "installationPlan": {
    "schemaVersion": "1",
    "selectedOS": ["Windows"],
    "workspaceFolder": ["C:\\work"],
    "baseEnvironment": {"mode": "skip"},
    "aiCliTools": "Codex CLI",
    "addons": {
      "lazy-codex": {
        "title": ["Lazy-Codex"],
        "selected": "true",
        "decision": ["install"]
      }
    },
    "executionCommand": [".\\windows\\install.ps1 -Standard"],
    "approvalStatus": "approved",
    "approvedAt": ["2026-07-10T00:00:00Z"],
    "secretPolicy": false
  }
}
'@
    [void](Invoke-StandardPlanScenario -OutPath $wrongTypesPath -StateJson $wrongTypesJson)
    Assert-MalformedStandardContract -Path $wrongTypesPath
    Add-Content -Path $MalformedStandardTranscriptPath -Value 'PASS required fields with wrong types are rejected before install execution'

    Remove-Item -LiteralPath $addonsArrayPath, $wrongTypesPath -Force -ErrorAction SilentlyContinue
    Add-Content -Path $MalformedStandardTranscriptPath -Value 'Cleanup receipt: removed malformed standard scratch transcripts'
    Write-Output "PASS malformed-standard-plan $MalformedStandardTranscriptPath"
  }
  default {
    [void](Invoke-Scenario -OutPath $TranscriptPath -Inputs @('2', '1', '3', '4', '1', '2', '2', '2', $ApprovalWord))
    Assert-RegressionContract -Path $TranscriptPath
    Write-Output "PASS beginner-approval-gate-windows $TranscriptPath"
  }
}
