#requires -Version 5.1
<#
.SYNOPSIS
  ai-boiler-plate -- install the Windows development environment.

.DESCRIPTION
  From a fresh machine -> winget packages, runtimes, PowerShell profile, Docker,
  and AI coding agents.

  Steps (in order): prereqs packages runtimes shell docker git agents resume

.PARAMETER DryRun
  Show what would happen, change nothing.
.PARAMETER Yes
  Non-interactive: accept defaults, never prompt.
.PARAMETER Standard
  Beginner/team preset: non-interactive, skips Docker, and keeps the default AI agent setup.
.PARAMETER Only
  Comma-separated list of steps to run (e.g. -Only packages,shell).
.PARAMETER Skip
  Comma-separated list of steps to skip.
.PARAMETER NoAgents
  Shortcut for -Skip agents.
.PARAMETER List
  List step ids and exit.
.PARAMETER Version
  Print the kit version and exit.

.EXAMPLE
  $env:AI_BOILER_PLATE_REPO='<repo-url>'; .\install.ps1
  Deprecated compatibility envs are still read: BSS_BOILERPLATE_* and STARTER_KIT_*.

.EXAMPLE
  .\install.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Yes,
  [switch]$Standard,
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$NoAgents,
  [switch]$List,
  [switch]$Version,
  [switch]$Status,
  [switch]$ResetState,
  [switch]$Classic,
  [switch]$Wizard,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Are we running from a real .ps1 file, or piped through `iex` (irm | iex)? When
# iex'd the script shares the caller's session scope, so `exit` closes the user's
# terminal -- wiping the "Next steps" output on success and the error on failure.
# We `return`/`throw` instead in that mode, and keep exit codes for real file runs
# (CI relies on them). $PSCommandPath is the running file's path, empty under iex.
$script:RunFromFile = [bool]$PSCommandPath

$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$RepoUrl    = if ($env:AI_BOILER_PLATE_REPO)   { $env:AI_BOILER_PLATE_REPO }   elseif ($env:BSS_BOILERPLATE_REPO)   { $env:BSS_BOILERPLATE_REPO }   elseif ($env:STARTER_KIT_REPO)   { $env:STARTER_KIT_REPO }   else { 'https://github.com/socialsolidaritybank/ai-boiler-plate.git' }
$RepoBranch = if ($env:AI_BOILER_PLATE_BRANCH) { $env:AI_BOILER_PLATE_BRANCH } elseif ($env:BSS_BOILERPLATE_BRANCH) { $env:BSS_BOILERPLATE_BRANCH } elseif ($env:STARTER_KIT_BRANCH) { $env:STARTER_KIT_BRANCH } else { 'main' }
$DefaultCloneDir = if ($Standard) {
  Join-Path (Join-Path (Join-Path $HomeDir 'Documents') 'Codex') 'bss-ai-boiler-plate'
} else {
  Join-Path $HomeDir 'ai-boiler-plate'
}
$CloneDir   = if ($env:AI_BOILER_PLATE_DIR)    { $env:AI_BOILER_PLATE_DIR }    elseif ($env:BSS_BOILERPLATE_DIR)    { $env:BSS_BOILERPLATE_DIR }    elseif ($env:STARTER_KIT_DIR)    { $env:STARTER_KIT_DIR }    else { $DefaultCloneDir }

# ---------------------------------------------------------------------------
# Resolve the repo root (the windows\ dir), or bootstrap by cloning.
# ---------------------------------------------------------------------------
function Resolve-Root {
  $dir = $PSScriptRoot
  if (-not $dir) { try { $dir = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {} }
  if ($dir -and (Test-Path (Join-Path $dir 'scripts\lib.ps1'))) { return $dir }

  Write-Host "==> Bootstrapping ai-boiler-plate into $CloneDir" -ForegroundColor Blue
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    # A piped one-liner (irm | iex) needs git to clone the kit. On a fresh
    # machine, install it via winget, then refresh PATH for this session.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Host "==> git not found - installing via winget..." -ForegroundColor Blue
      winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
      $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                  [Environment]::GetEnvironmentVariable('Path','User') + ';C:\Program Files\Git\cmd'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host "==> git still not found. Either:" -ForegroundColor Red
      Write-Host "    1) install git:  winget install --id Git.Git   (then re-run), or" -ForegroundColor Red
      Write-Host "    2) download the ZIP from your BSS boilerplate repository" -ForegroundColor Red
      Write-Host "       extract it, then run  windows\install.ps1" -ForegroundColor Red
      if ($script:RunFromFile) { exit 1 } else { throw "git is required -- install it and re-run (see options above)." }
    }
  }
  if (Test-Path (Join-Path $CloneDir '.git')) {
    git -C $CloneDir pull --ff-only origin $RepoBranch | Out-Null
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CloneDir) | Out-Null
    git clone --branch $RepoBranch --depth 1 $RepoUrl $CloneDir | Out-Null
  }
  return (Join-Path $CloneDir 'windows')
}

$Root = Resolve-Root

# If we bootstrapped (cloned), hand off to the cloned copy with the same args.
$self = $null
try { $self = $MyInvocation.MyCommand.Path } catch {}
$target = Join-Path $Root 'install.ps1'
if ((-not $self) -or ($self -ne $target)) {
  if (Test-Path $target) {
    & $target @PSBoundParameters
    # Propagate the cloned copy's exit code when we're a file; under iex, `return`
    # so we don't close the caller's terminal.
    if ($script:RunFromFile) { exit $LASTEXITCODE } else { return }
  }
}

# ---------------------------------------------------------------------------
# Load shared helpers + set flags
# ---------------------------------------------------------------------------
. (Join-Path $Root 'scripts\lib.ps1')
$script:DryRun    = [bool]$DryRun
$script:AssumeYes = [bool]$Yes
. (Join-Path $Root 'scripts\state.ps1')

$versionFile = Join-Path $Root '..\VERSION'
$KitVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'dev' }

# ---------------------------------------------------------------------------
# Step registry
# ---------------------------------------------------------------------------
$Skip = @($Skip)
if ($Standard) {
  $Yes = $true
  $Classic = $true
  $Skip += 'docker'
  $env:BSS_AI_INSTALL_CODEX = '1'
  $env:BSS_AI_INSTALL_CLAUDE = '1'
  $env:BSS_AI_INSTALL_EXTRAS = '0'
  $env:HERMES = '0'
}

$StepIds = @('prereqs', 'packages', 'runtimes', 'shell', 'docker', 'git', 'agents', 'resume')
$StepFile = @{
  prereqs  = '01-prereqs.ps1'
  packages = '02-packages.ps1'
  runtimes = '03-runtimes.ps1'
  shell    = '04-shell.ps1'
  docker   = '05-docker.ps1'
  git      = '06-git.ps1'
  agents   = '07-agents.ps1'
  resume   = '09-codex-resume.ps1'
}
$StepFunc = @{
  prereqs  = 'Step-Prereqs'
  packages = 'Step-Packages'
  runtimes = 'Step-Runtimes'
  shell    = 'Step-Shell'
  docker   = 'Step-Docker'
  git      = 'Step-Git'
  agents   = 'Step-Agents'
  resume   = 'Step-Resume'
}

if ($Help)    { Get-Help $target -Detailed;                    if ($script:RunFromFile) { exit 0 } else { return } }
if ($List)    { $StepIds | ForEach-Object { Write-Output $_ }; if ($script:RunFromFile) { exit 0 } else { return } }
if ($Version) { Write-Output "ai-boiler-plate $KitVersion";    if ($script:RunFromFile) { exit 0 } else { return } }
if ($Status)  { Show-HelperStatus;                              if ($script:RunFromFile) { exit 0 } else { return } }
if ($ResetState) {
  $state = Get-StatePath
  if (-not (Test-Path $state)) {
    Write-Info "삭제할 진행 상태가 없습니다."
  } elseif (Confirm-Action "저장된 진행 상태를 삭제할까요? 작업 기록과 리포트/HTML은 남깁니다." -DefaultNo) {
    Remove-Item $state -Force
    Write-Info "진행 상태를 삭제했습니다. history.jsonl, latest-report.md, manual/index.html은 남겨 두었습니다."
  } else {
    Write-Info "진행 상태를 그대로 둡니다."
  }
  if ($script:RunFromFile) { exit 0 } else { return }
}
$directMode = [bool]($Classic -or $Yes -or $Only.Count -gt 0 -or $Skip.Count -gt 0 -or $NoAgents)
if (($Wizard -or ((-not $directMode) -and (-not [Console]::IsInputRedirected))) -and -not $Classic)  {
  if (-not (Test-IsWindows)) { Stop-Kit "This kit targets Windows only." }
  . (Join-Path $Root 'scripts\recommendations.ps1')
  . (Join-Path $Root 'scripts\wizard.ps1')
  Start-Wizard -Platform 'Windows' -Root $Root
  if ($script:RunFromFile) { exit 0 } else { return }
}

if ($NoAgents) { $Skip = @($Skip) + 'agents' }

# Validate every -Only/-Skip token against the known step ids -- a typo like
# `-Only pacakges` would otherwise silently select zero steps and exit 0.
foreach ($tok in (@(@($Only) + @($Skip)) | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  if ($StepIds -notcontains $tok) { Stop-Kit "unknown step id: '$tok' (valid: $($StepIds -join ' '))" }
}

function Get-SelectedSteps {
  $onlyList = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $skipList = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  foreach ($id in $StepIds) {
    if ($onlyList.Count -gt 0) {
      if ($onlyList -contains $id) { $id }
    } elseif ($skipList -notcontains $id) {
      $id
    }
  }
}

function Write-CompletionReport {
  if ($script:DryRun) { return }
  $reportScript = Join-Path $Root 'scripts\report.ps1'
  if (-not (Test-Path $reportScript)) {
    Write-Warn "설치 결과 리포트 생성기를 찾지 못했습니다: $reportScript"
    return
  }
  try {
    . $reportScript
    New-HelperReport | ForEach-Object { Write-Info $_ }
  } catch {
    Write-Warn "설치는 끝났지만 결과 리포트/HTML 매뉴얼 생성은 실패했습니다. state 파일과 PowerShell 권한을 확인해 주세요."
    Write-Warn $_.Exception.Message
  }
}

function Record-CompletionState {
  Initialize-HelperState
  $selectedSet = @{}
  foreach ($item in @($selected)) { $selectedSet[$item] = $true }

  if ($selectedSet.ContainsKey('prereqs') -or $selectedSet.ContainsKey('packages') -or $selectedSet.ContainsKey('runtimes')) {
    Set-StepStatus -Step 'base-tools' -Status 'complete' -Note 'Windows 기본 환경 설치 완료'
  }
  if ($selectedSet.ContainsKey('shell') -or $selectedSet.ContainsKey('resume')) {
    Set-StepStatus -Step 'shell' -Status 'complete' -Note 'PowerShell profile/restart 설정 완료'
  }
  if ($selectedSet.ContainsKey('git')) {
    Set-StepStatus -Step 'github' -Status 'complete' -Note 'Git/GitHub 기본 설정 완료'
  }
  if ($selectedSet.ContainsKey('agents')) {
    $services = @()
    if ($env:BSS_AI_INSTALL_CODEX -ne '0') { $services += 'Codex' }
    if ($env:BSS_AI_INSTALL_CLAUDE -ne '0') { $services += 'Claude' }
    if ($services.Count -gt 0) {
      Add-AiService -Services $services
      Set-StepStatus -Step 'ai-tools' -Status 'complete' -Note ($services -join ',')
    } else {
      Set-StepStatus -Step 'ai-tools' -Status 'skipped' -Note 'AI CLI 도구 설치하지 않음'
    }
  } else {
    Set-StepStatus -Step 'ai-tools' -Status 'skipped' -Note 'agents step skipped'
  }
  Set-StepStatus -Step 'addons' -Status 'skipped' -Note '추가 기능은 명시적으로 선택할 때만 설치'
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if (-not (Test-IsWindows)) { Stop-Kit "This kit targets Windows only." }
if ($script:DryRun) { Write-Warn "DRY-RUN: no changes will be made." }

Write-Host "== ai-boiler-plate v$KitVersion ==" -ForegroundColor White
$selected = @(Get-SelectedSteps)
Write-Info ("steps: " + ($selected -join ' '))

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
foreach ($id in $selected) {
  $file = Join-Path $Root ("scripts\" + $StepFile[$id])
  if (-not (Test-Path $file)) { Stop-Kit "missing step file: $file" }
  . $file
  if ($id -eq 'agents') {
    $agentResult = @(& $StepFunc[$id])
    if ($agentResult -contains $false) { Stop-Kit "AI agents step did not complete." }
  } else {
    & $StepFunc[$id]
  }
}

if (-not $script:DryRun) {
  Write-Step "Install result manual"
  Record-CompletionState
  Write-CompletionReport
}

Write-Step "Done."
if ($script:DryRun) {
  Write-Info "That was a dry run -- re-run without -DryRun to apply."
} else {
  Write-Step "Next steps"
  Write-Info "1) Open a NEW PowerShell window so the profile loads (autosuggestions, prompt)."
  if ((Test-HasCommand gh)) {
    Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Info "2) Sign in to GitHub:  gh auth login   (also sets your git identity)" }
  }
  Write-Info "3) Set your terminal font to 'JetBrainsMono Nerd Font' (Windows Terminal > Settings > Appearance)."
  Write-Info "Note: on Windows PowerShell 5.1, restart it once if PSReadLine was upgraded. PowerShell 7 is smoother."
}
if ($script:RunFromFile) { exit 0 } else { return }
