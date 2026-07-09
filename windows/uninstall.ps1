#requires -Version 5.1
<#
.SYNOPSIS
  ai-boiler-plate -- uninstaller. Reverses install.ps1 in reverse order.

.DESCRIPTION
  Destructive groups are confirm-gated. Never auto-removes your git identity.

  Groups (reverse order): agents shell docker runtimes packages

.PARAMETER DryRun         Show what would happen, change nothing.
.PARAMETER Yes            Non-interactive: accept every removal prompt.
.PARAMETER Only           Comma-separated groups to run.
.PARAMETER Skip           Comma-separated groups to skip.
.PARAMETER KeepCodexHome  Deprecated no-op; runtime/auth roots are always preserved.
.PARAMETER List           List group ids and exit.
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Yes,
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$KeepCodexHome,
  [switch]$List
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $Root 'scripts\lib.ps1')
$script:DryRun    = [bool]$DryRun
$script:AssumeYes = [bool]$Yes
if ($KeepCodexHome) { Write-Warn "-KeepCodexHome is deprecated: runtime/auth roots are always preserved." }

$versionFile = Join-Path $Root '..\VERSION'
$KitVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'dev' }

$GroupIds = @('agents', 'shell', 'docker', 'runtimes', 'packages')

# ---------------------------------------------------------------------------
# agents
# ---------------------------------------------------------------------------
function Undo-Agents {
  Write-Step "Remove AI agents (codex + lazycodex + Claude Code)"
  Update-SessionPath

  # codex is installed either through mise's npm shim OR plain global npm --
  # 07-agents falls back to `npm install -g '@openai/codex'` when mise is absent,
  # so uninstall must cover both or it silently leaves codex behind.
  if (Test-HasCommand mise) {
    $installed = (Invoke-NativeSilently 'mise' @('exec', '--', 'npm', 'ls', '-g', '--depth=0') | Out-String)
    if ($installed -match '@openai/codex') {
      Write-Info "Uninstalling @openai/codex (mise npm)..."
      if (-not $script:DryRun) { & mise exec -- npm uninstall -g '@openai/codex'; Invoke-NativeSilently 'mise' @('reshim') }
      else { Write-Info "[dry-run] mise exec -- npm uninstall -g @openai/codex" }
    } else { Write-Info "codex npm package not installed (mise)" }
  }
  if (Test-HasCommand npm) {
    $installedNpm = (Invoke-NativeSilently 'npm' @('ls', '-g', '--depth=0') | Out-String)
    if ($installedNpm -match '@openai/codex') {
      Write-Info "Uninstalling @openai/codex (npm -g)..."
      if (-not $script:DryRun) { Invoke-NativeSilently 'npm' @('uninstall', '-g', '@openai/codex') | Out-Null; Write-Ok "removed @openai/codex (npm)" }
      else { Write-Info "[dry-run] npm uninstall -g @openai/codex" }
    } else { Write-Info "codex npm package not installed (npm)" }
  }

  # lazycodex npx cache
  $npxRoots = @(
    (Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'),
    (Join-Path $env:APPDATA 'npm-cache\_npx')
  )
  $cleared = $false
  foreach ($root in $npxRoots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($dir in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
      if (Test-Path (Join-Path $dir.FullName 'node_modules\lazycodex-ai')) {
        if (-not $script:DryRun) { Remove-Item $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        $cleared = $true
      }
    }
  }
  if ($cleared) { Write-Ok "cleared lazycodex npx cache" } else { Write-Info "no lazycodex npx cache" }

  Write-Info "Preserving runtime/auth roots: ~/.codex, ~/.claude, ~/.claude.json, ~/.agents, and auth/token/OAuth files"

  $claudeBin  = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
  $claudeData = Join-Path $env:USERPROFILE '.local\share\claude'
  if ((Test-Path $claudeBin) -or (Test-Path $claudeData)) {
    if ($script:DryRun) {
      if (Test-Path $claudeBin)  { Write-Info "[dry-run] would remove ~/.local/bin/claude.exe" }
      if (Test-Path $claudeData) { Write-Info "[dry-run] would preserve ~/.local/share/claude runtime data" }
    } else {
      if (Test-Path $claudeBin)  { Remove-Item $claudeBin -Force -ErrorAction SilentlyContinue }
      if (Test-Path $claudeData) { Write-Info "kept ~/.local/share/claude runtime data" }
      Write-Ok "removed Claude Code command; runtime data preserved"
    }
  } else {
    Write-Info "Claude Code not installed"
  }

}

# ---------------------------------------------------------------------------
# shell
# ---------------------------------------------------------------------------
function Undo-Shell {
  Write-Step "Revert shell configuration"
  # Strip the block from BOTH host profiles (5.1 WindowsPowerShell\ and 7
  # PowerShell\); the installer writes both.
  foreach ($profilePath in (Get-AllHostsProfilePaths)) {
    Remove-ManagedBlock -Path $profilePath -Tag 'ai-boiler-plate:main'
    Remove-ManagedBlock -Path $profilePath -Tag 'bss-ai-boilerplate:main'
    Remove-ManagedBlock -Path $profilePath -Tag 'lazy-starter-kit:main'
  }

  $starshipToml = Join-Path $env:USERPROFILE '.config\starship.toml'
  if (Test-Path $starshipToml) {
    if (Confirm-Action "Remove ~/.config/starship.toml?") {
      if (-not $script:DryRun) { Remove-Item $starshipToml -Force }
    } else { Write-Info "kept starship.toml" }
  }
}

# ---------------------------------------------------------------------------
# docker
# ---------------------------------------------------------------------------
function Undo-Docker {
  Write-Step "Remove Docker Desktop"
  if (Test-WingetPackage -Id 'Docker.DockerDesktop') {
    if (Confirm-Action "Uninstall Docker Desktop (containers & images lost)?") {
      Uninstall-WingetPackage -Id 'Docker.DockerDesktop' -Name 'Docker Desktop'
    } else { Write-Info "kept Docker Desktop" }
  } else { Write-Info "Docker Desktop not installed" }
}

# ---------------------------------------------------------------------------
# runtimes
# ---------------------------------------------------------------------------
function Undo-Runtimes {
  Write-Step "Remove language runtimes (mise node/python/go + rustup)"
  Update-SessionPath
  if (Test-HasCommand mise) {
    if (Confirm-Action "Remove mise-managed node/python/go/ast-grep (versions + global config)?") {
      if ($script:DryRun) {
        Write-Info "[dry-run] mise uninstall node python go; mise rm -g node python go ast-grep"
      } else {
        Invoke-NativeSilently 'mise' @('uninstall', 'node', 'python', 'go')
        foreach ($t in @('node','python','go','ubi:ast-grep/ast-grep')) { Invoke-NativeSilently 'mise' @('rm', '-g', $t) }
        Write-Ok "removed mise runtimes"
      }
    } else { Write-Info "kept mise runtimes" }
  }
  if (Test-HasCommand rustup) {
    if (Confirm-Action "Uninstall Rust (rustup self uninstall)?") {
      if ($script:DryRun) { Write-Info "[dry-run] rustup self uninstall -y" }
      else { & rustup self uninstall -y; Write-Ok "rust uninstalled" }
    } else { Write-Info "kept rust/rustup" }
  }
}

# ---------------------------------------------------------------------------
# packages
# ---------------------------------------------------------------------------
function Undo-Packages {
  Write-Step "Uninstall winget packages"
  if (-not (Confirm-Action "Uninstall the winget CLI/dev packages? (git & Nerd Font are kept)")) {
    Write-Info "kept winget packages"; return
  }
  $ids = [ordered]@{
    'GitHub.cli'              = 'gh'
    'jqlang.jq'               = 'jq'
    'BurntSushi.ripgrep.MSVC' = 'ripgrep'
    'sharkdp.fd'              = 'fd'
    'sharkdp.bat'             = 'bat'
    'junegunn.fzf'            = 'fzf'
    'Starship.Starship'      = 'starship'
    'jdx.mise'                = 'mise'
    'astral-sh.uv'            = 'uv'
    'Rustlang.Rustup'         = 'rustup'
    'Oven-sh.Bun'             = 'bun'
  }
  foreach ($id in $ids.Keys) { Uninstall-WingetPackage -Id $id -Name $ids[$id] }
  Write-Info "git and the Nerd Font are intentionally kept (remove manually if desired)."
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
$GroupFunc = @{
  agents = 'Undo-Agents'; shell = 'Undo-Shell'; docker = 'Undo-Docker'
  runtimes = 'Undo-Runtimes'; packages = 'Undo-Packages'
}

if ($List) { $GroupIds | ForEach-Object { Write-Output $_ }; exit 0 }

function Get-SelectedGroups {
  $onlyList = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $skipList = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  foreach ($id in $GroupIds) {
    if ($onlyList.Count -gt 0) { if ($onlyList -contains $id) { $id } }
    elseif ($skipList -notcontains $id) { $id }
  }
}

# Validate every -Only/-Skip token against the known group ids -- a typo would
# otherwise silently select zero groups and exit 0.
foreach ($tok in (@(@($Only) + @($Skip)) | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  if ($GroupIds -notcontains $tok) { Stop-Kit "unknown step id: '$tok' (valid: $($GroupIds -join ' '))" }
}

if (-not (Test-IsWindows)) { Stop-Kit "Windows only." }
if ($script:DryRun) { Write-Warn "DRY-RUN: no changes will be made." }

Write-Host "== ai-boiler-plate v$KitVersion - uninstall ==" -ForegroundColor White
$selected = @(Get-SelectedGroups)
Write-Info ("groups: " + ($selected -join ' '))
Write-Warn "Your git identity is left untouched (remove manually if desired)."

foreach ($id in $selected) { & $GroupFunc[$id] }

Write-Step "Uninstall complete."
Write-Ok "Restart PowerShell to load a clean environment."
if ($script:DryRun) { Write-Info "That was a dry run -- re-run without -DryRun to apply." }
[Environment]::Exit(0)
