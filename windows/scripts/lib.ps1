# lib.ps1 -- shared helpers for bss-ai-boilerplate
# dot-sourced by install.ps1 and every scripts/NN-*.ps1 step.
# Targets Windows PowerShell 5.1+ and PowerShell 7+.

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Global flags (set by install.ps1)
# ---------------------------------------------------------------------------
if (-not (Test-Path variable:script:DryRun))    { $script:DryRun = $false }
if (-not (Test-Path variable:script:AssumeYes)) { $script:AssumeYes = $false }
# $true when the top-level script runs from a real .ps1 file; $false when it was
# piped through `iex` (irm | iex), where `exit` would close the user's terminal.
# install.ps1 sets this before dot-sourcing us; default $true is right for a file
# run and for the uninstaller.
if (-not (Test-Path variable:script:RunFromFile)) { $script:RunFromFile = $true }

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Step { param([string]$Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Blue }
function Write-Info { param([string]$Message) Write-Host "  - $Message" -ForegroundColor DarkGray }
function Write-Ok   { param([string]$Message) Write-Host "  ok  $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Write-Err  { param([string]$Message) Write-Host "  x   $Message" -ForegroundColor Red }
function Stop-Kit {
  # Fail the run. Under `irm | iex` (not a file) `exit 1` would close the user's
  # terminal and take the error text with it, so throw a terminating error whose
  # message survives instead; keep the exit code intact for real file runs (CI).
  param([string]$Message)
  Write-Err $Message
  if ($script:RunFromFile) { exit 1 } else { throw $Message }
}

# Tracks winget packages that failed to install, for an end-of-step summary.
if (-not (Test-Path variable:script:WingetFailures)) { $script:WingetFailures = @() }

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------
function Test-HasCommand {
  param([Parameter(Mandatory)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-IsWindows {
  # $IsWindows exists on PS 7; on 5.1 it's undefined but the host is Windows.
  if (Test-Path variable:global:IsWindows) { return $global:IsWindows }
  return ($env:OS -eq 'Windows_NT')
}

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Get-WindowsAppsPath {
  if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps') }
  if ($env:USERPROFILE) { return (Join-Path $env:USERPROFILE 'AppData\Local\Microsoft\WindowsApps') }
  return ''
}

function ConvertTo-ComparablePath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  try {
    return ([System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))).TrimEnd('\').ToLowerInvariant()
  } catch {
    return $Path.TrimEnd('\').ToLowerInvariant()
  }
}

function Test-PathContainsEntry {
  param([string]$Needle)
  $normalizedNeedle = ConvertTo-ComparablePath $Needle
  if (-not $normalizedNeedle) { return $false }
  foreach ($entry in ($env:Path -split ';')) {
    if ((ConvertTo-ComparablePath $entry) -eq $normalizedNeedle) { return $true }
  }
  return $false
}

# ---------------------------------------------------------------------------
# Command execution -- run, or just print under -DryRun
# ---------------------------------------------------------------------------
function Invoke-Run {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [string[]]$Arguments = @()
  )
  if ($script:DryRun) {
    Write-Host ("  [dry-run] {0} {1}" -f $Exe, ($Arguments -join ' ')) -ForegroundColor DarkGray
    return $true
  }
  & $Exe @Arguments
  return ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
}

# ---------------------------------------------------------------------------
# Native-command invocation with stderr discarded.
# On Windows PowerShell 5.1 a native command's stderr lines become ErrorRecords,
# and $ErrorActionPreference='Stop' (which install.ps1 sets) promotes the first
# one into a TERMINATING error -- so a plain `git config ... 2>$null` kills the
# script the moment the tool writes to stderr (e.g. gh when unauthenticated).
# Fixed only in PS 7.2+. We flip EAP to 'Continue' for the call so stderr is
# harmless, discard it with 2>$null, and return stdout. $LASTEXITCODE is left
# set by the native command for the caller to inspect.
# ---------------------------------------------------------------------------
function Invoke-NativeSilently {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [string[]]$Arguments = @()
  )
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Exe @Arguments 2>$null
  } finally {
    $ErrorActionPreference = $prev
  }
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
function Read-Default {
  param([string]$Question, [string]$Default = '')
  if ($script:AssumeYes -or [Console]::IsInputRedirected) { return $Default }
  $ans = Read-Host $Question
  if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
  return $ans
}

function Confirm-Action {
  # -DefaultNo flips the gate to default-No: bare Enter declines, the prompt reads
  # [y/N], and -Yes / non-interactive returns $false (used for the licensing-gated
  # Docker Desktop install). Without it, behaviour is unchanged (default-Yes).
  param([string]$Question, [switch]$DefaultNo)
  if ($script:AssumeYes) { return (-not $DefaultNo) }
  if ([Console]::IsInputRedirected) { return $false }
  if ($DefaultNo) {
    $ans = Read-Host ("{0} [y/N]" -f $Question)
    return ($ans -match '^[Yy]')
  }
  $ans = Read-Host ("{0} [Y/n]" -f $Question)
  return ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^[Yy]')
}

# ---------------------------------------------------------------------------
# PATH refresh -- winget-installed tools land on the Machine/User PATH but the
# current process won't see them until we re-read the environment.
# ---------------------------------------------------------------------------
function Update-SessionPath {
  if ($env:BSS_AI_HELPER_DISABLE_PATH_REFRESH -eq '1') { return }
  # MERGE newly-installed tool dirs into the CURRENT process PATH -- do NOT rebuild
  # from Machine+User only. A rebuild drops process-level entries (VS dev shell,
  # portable git, dirs the profile prepended) and, with $ErrorActionPreference=
  # 'Stop', a later CommandNotFoundException would abort the whole run. We keep the
  # existing $env:Path entries in their original order and append Machine/User and
  # the known tool dirs that aren't already present (case-insensitive, and
  # trailing-backslash-insensitive so 'C:\x' and 'C:\x\' count as the same entry).
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')

  $extra = @()
  if ($env:BSS_AI_HELPER_SKIP_PERSISTENT_PATH -ne '1') {
    foreach ($p in @($machine, $user)) { if ($p) { $extra += ($p -split ';') } }
  }
  # user-local tool dirs (guard each base env var; may be unset off-Windows)
  if ($env:USERPROFILE) {
    $extra += (Join-Path $env:USERPROFILE '.cargo\bin')
    $extra += (Join-Path $env:USERPROFILE '.bun\bin')
    # Claude Code (claude.exe) installs here via https://claude.ai/install.ps1
    $extra += (Join-Path $env:USERPROFILE '.local\bin')
  }
  $windowsApps = Get-WindowsAppsPath
  if ($windowsApps) { $extra += $windowsApps }
  if ($env:LOCALAPPDATA) { $extra += (Join-Path $env:LOCALAPPDATA 'mise\shims') }
  if ($env:APPDATA)      { $extra += (Join-Path $env:APPDATA 'npm') }

  $seen   = @{}
  $merged = @()
  foreach ($p in @(($env:Path -split ';') + $extra)) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $norm = $p.TrimEnd('\').ToLowerInvariant()
    if ($seen.ContainsKey($norm)) { continue }
    $seen[$norm] = $true
    $merged += $p
  }
  if ($merged.Count -gt 0) { $env:Path = ($merged -join ';') }
}

# ---------------------------------------------------------------------------
# winget helpers
# ---------------------------------------------------------------------------
function Get-WingetStatus {
  Update-SessionPath
  $windowsApps = Get-WindowsAppsPath
  $status = New-Object psobject -Property ([ordered]@{
      Ready = $false
      Found = $false
      Source = ''
      Version = ''
      ExitCode = $null
      Reason = 'not-found'
      WindowsAppsPath = $windowsApps
      WindowsAppsOnPath = (Test-PathContainsEntry $windowsApps)
      AppInstallerState = 'unknown'
    })

  try {
    $appInstaller = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($appInstaller) {
      $status.AppInstallerState = "registered $($appInstaller.Version)"
    } else {
      $status.AppInstallerState = 'not registered for this user'
    }
  } catch {
    $status.AppInstallerState = "unknown ($($_.Exception.Message))"
  }

  $command = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $command) { return $status }

  $status.Found = $true
  $status.Source = if ($command.Source) { $command.Source } elseif ($command.Path) { $command.Path } else { 'winget' }
  $status.Reason = 'probe-failed'
  $versionLines = @(Invoke-NativeSilently $status.Source @('--version') | Out-String -Stream)
  $status.ExitCode = $LASTEXITCODE
  $version = ($versionLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
  if (($status.ExitCode -eq 0) -and $version) {
    $status.Ready = $true
    $status.Version = $version.Trim()
    $status.Reason = 'ready'
  }
  return $status
}

function Write-WingetDiagnostics {
  param([Parameter(Mandatory)]$Status)
  if ($Status.Found) {
    Write-Warn "winget command is present but not working."
    Write-Info "winget path: $($Status.Source)"
    if ($null -ne $Status.ExitCode) { Write-Info "winget --version exit code: $($Status.ExitCode)" }
  } else {
    Write-Warn "winget not found in this PowerShell session."
  }
  Write-Info "winget is delivered by App Installer (Microsoft.DesktopAppInstaller). Install or update App Installer from the Microsoft Store:"
  Write-Info "  ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
  Write-Info "App Installer registration: $($Status.AppInstallerState)"
  if ($Status.WindowsAppsPath) {
    Write-Info "WindowsApps PATH should include:"
    Write-Info "  $($Status.WindowsAppsPath)"
    if (-not $Status.WindowsAppsOnPath) {
      Write-Info "Current session PATH is missing WindowsApps; open a new PowerShell or re-run after PATH refresh."
    }
  }
}

function Assert-WingetReady {
  param([string]$Context = 'this step')
  $status = Get-WingetStatus
  if ($status.Ready) { return $status }
  Write-WingetDiagnostics -Status $status
  if (-not $script:DryRun) {
    Stop-Kit "winget is required for $Context -- repair App Installer or WindowsApps PATH, then re-run."
  }
  return $status
}

function Test-WingetPackage {
  param([Parameter(Mandatory)][string]$Id)
  $status = Get-WingetStatus
  if (-not $status.Ready) { return $false }
  # Confirm BOTH the exit code AND that the id actually appears in the output:
  # some winget versions exit 0 even when nothing matched, so the match guards it.
  $match = Invoke-NativeSilently $status.Source @('list', '--id', $Id, '-e', '--accept-source-agreements') | Out-String -Stream | Select-String -SimpleMatch $Id
  return (($LASTEXITCODE -eq 0) -and [bool]$match)
}

# Install-WingetPackage <Id> [<Friendly name>]  -- idempotent winget install
function Install-WingetPackage {
  param(
    [Parameter(Mandatory)][string]$Id,
    [string]$Name = $null
  )
  if (-not $Name) { $Name = $Id }
  if (-not $script:DryRun -and (Test-WingetPackage -Id $Id)) {
    Write-Ok "$Name present"
    return
  }
  Write-Info "Installing $Name (winget: $Id)..."
  $wingetArgs = @('install', '--id', $Id, '-e', '--accept-package-agreements',
                  '--accept-source-agreements', '--silent',
                  '--disable-interactivity')
  if ($script:DryRun) {
    Write-Host ("  [dry-run] winget {0} [--scope user, then default]" -f ($wingetArgs -join ' ')) -ForegroundColor DarkGray
    return
  }
  Assert-WingetReady -Context "installing $Name" | Out-Null
  # Prefer a per-user install (no admin/UAC). If the package has no user-scope
  # installer, retry at default scope (which may prompt for elevation).
  winget @wingetArgs --scope user
  if ($LASTEXITCODE -ne 0) { winget @wingetArgs }
  if ($LASTEXITCODE -ne 0) {
    Write-Warn "winget install for $Name exited with code $LASTEXITCODE (may need admin/UAC, a reboot, or be unavailable here)"
    $script:WingetFailures += $Name
  } else {
    Write-Ok "$Name installed"
  }
}

# Uninstall-WingetPackage <Id> [<Friendly name>]  -- used by the uninstaller
function Uninstall-WingetPackage {
  param([Parameter(Mandatory)][string]$Id, [string]$Name = $null)
  if (-not $Name) { $Name = $Id }
  if (-not $script:DryRun -and -not (Test-WingetPackage -Id $Id)) {
    Write-Info "$Name not installed"
    return
  }
  if ($script:DryRun) {
    Write-Host ("  [dry-run] winget uninstall --id {0} -e --silent" -f $Id) -ForegroundColor DarkGray
    return
  }
  Assert-WingetReady -Context "removing $Name" | Out-Null
  winget uninstall --id $Id -e --silent --disable-interactivity
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "$Name removed"
  } else {
    Write-Warn "could not remove $Name (winget exit $LASTEXITCODE) -- likely needs admin/UAC, or it isn't installed"
  }
}

. (Join-Path $PSScriptRoot 'profile.ps1')
