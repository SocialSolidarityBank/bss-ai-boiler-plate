#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Installer = Join-Path $RepoRoot 'windows\install.ps1'
$EnforcePending = ($env:BSS_INSTALL_CONTRACT_ENFORCE_PENDING -eq '1')
$Failures = New-Object System.Collections.Generic.List[string]
$Cleanups = New-Object System.Collections.Generic.List[string]

function New-Sandbox {
  $root = Join-Path ([IO.Path]::GetTempPath()) ("bss-install-contract-win-" + [guid]::NewGuid().ToString('N'))
  $paths = @{
    Root = $root
    Home = Join-Path $root 'home'
    Helper = Join-Path $root 'helper'
    Bin = Join-Path $root 'bin'
    LocalAppData = Join-Path $root 'home\AppData\Local'
    WindowsApps = Join-Path $root 'home\AppData\Local\Microsoft\WindowsApps'
    CommandLog = Join-Path $root 'commands.log'
  }
  New-Item -ItemType Directory -Force -Path $paths.Home, $paths.Helper, $paths.Bin, $paths.WindowsApps | Out-Null
  $Cleanups.Add($root) | Out-Null
  return $paths
}

function Add-FakeCommand {
  param([hashtable]$Sandbox, [string]$Name, [string]$Directory = $null)
  if (-not $Directory) { $Directory = $Sandbox.Bin }
  if (-not (Test-Path $Directory)) { New-Item -ItemType Directory -Force -Path $Directory | Out-Null }
  $path = Join-Path $Directory "$Name.cmd"
  @(
    '@echo off',
    'echo %~n0 %*>>"%BSS_CONTRACT_COMMAND_LOG%"',
    'if "%~1"=="--version" (echo fake-version& exit /b 0)',
    'if "%~1"=="-v" (echo fake-version& exit /b 0)',
    'if "%~1"=="version" (echo fake-version& exit /b 0)',
    'exit /b 99'
  ) | Set-Content -Path $path -Encoding ASCII
}

function Add-BrokenCommand {
  param([hashtable]$Sandbox, [string]$Name)
  $path = Join-Path $Sandbox.Bin "$Name.cmd"
  @(
    '@echo off',
    'echo %~n0 %*>>"%BSS_CONTRACT_COMMAND_LOG%"',
    'echo simulated broken command 1>&2',
    'exit /b 42'
  ) | Set-Content -Path $path -Encoding ASCII
}

function Get-PowerShellExe {
  $current = (Get-Process -Id $PID).Path
  if ($current -and (Test-Path $current)) { return $current }
  $winPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if (Test-Path $winPs) { return $winPs }
  throw 'could not resolve a PowerShell executable for child installer tests'
}

function Invoke-Installer {
  param(
    [string[]]$Arguments,
    [string]$InputText = '',
    [hashtable]$Sandbox,
    [hashtable]$ExtraEnv = @{},
    [int]$TimeoutSeconds = 20
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Get-PowerShellExe
  $argList = New-Object System.Collections.Generic.List[string]
  $argList.Add('-NoProfile') | Out-Null
  $argList.Add('-ExecutionPolicy') | Out-Null
  $argList.Add('Bypass') | Out-Null
  $argList.Add('-File') | Out-Null
  $argList.Add($Installer) | Out-Null
  foreach ($arg in $Arguments) { $argList.Add($arg) | Out-Null }
  $psi.Arguments = ($argList | ForEach-Object {
      if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
  $psi.EnvironmentVariables['BSS_AI_HELPER_HOME'] = $Sandbox.Helper
  $psi.EnvironmentVariables['USERPROFILE'] = $Sandbox.Home
  $psi.EnvironmentVariables['HOME'] = $Sandbox.Home
  $psi.EnvironmentVariables['LOCALAPPDATA'] = $Sandbox.LocalAppData
  $psi.EnvironmentVariables['BSS_CONTRACT_COMMAND_LOG'] = $Sandbox.CommandLog
  $psi.EnvironmentVariables['Path'] = $Sandbox.Bin
  foreach ($key in $ExtraEnv.Keys) {
    $psi.EnvironmentVariables[$key] = [string]$ExtraEnv[$key]
  }

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi
  [void]$process.Start()
  if ($InputText.Length -gt 0) { $process.StandardInput.Write($InputText) }
  $process.StandardInput.Close()

  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try { $process.Kill() } catch {}
    return @{
      ExitCode = 124
      Output = "TIMEOUT after ${TimeoutSeconds}s"
      TimedOut = $true
    }
  }

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  return @{
    ExitCode = $process.ExitCode
    Output = ($stdout + $stderr)
    TimedOut = $false
  }
}

function Invoke-GeneratedHelper {
  param(
    [string[]]$Arguments,
    [hashtable]$Sandbox,
    [int]$TimeoutSeconds = 20
  )

  $probe = Join-Path $Sandbox.Root 'invoke-generated-helper.ps1'
  @'
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$RemainingArgs)
& bss-ai-helper @RemainingArgs
if ($LASTEXITCODE -is [int]) { exit $LASTEXITCODE }
'@ | Set-Content -Encoding UTF8 $probe

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Get-PowerShellExe
  $argList = New-Object System.Collections.Generic.List[string]
  $argList.Add('-NoProfile') | Out-Null
  $argList.Add('-ExecutionPolicy') | Out-Null
  $argList.Add('Bypass') | Out-Null
  $argList.Add('-File') | Out-Null
  $argList.Add($probe) | Out-Null
  foreach ($arg in $Arguments) { $argList.Add($arg) | Out-Null }
  $psi.Arguments = ($argList | ForEach-Object {
      if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
  $psi.EnvironmentVariables['BSS_AI_HELPER_HOME'] = $Sandbox.Helper
  $psi.EnvironmentVariables['USERPROFILE'] = $Sandbox.Home
  $psi.EnvironmentVariables['HOME'] = $Sandbox.Home
  $psi.EnvironmentVariables['LOCALAPPDATA'] = $Sandbox.LocalAppData
  $psi.EnvironmentVariables['BSS_CONTRACT_COMMAND_LOG'] = $Sandbox.CommandLog
  $psi.EnvironmentVariables['Path'] = (Join-Path $Sandbox.Helper 'bin') + ';' + $Sandbox.Bin

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi
  [void]$process.Start()
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try { $process.Kill() } catch {}
    return @{
      ExitCode = 124
      Output = "TIMEOUT after ${TimeoutSeconds}s"
      TimedOut = $true
    }
  }

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  return @{
    ExitCode = $process.ExitCode
    Output = ($stdout + $stderr)
    TimedOut = $false
  }
}

function Assert-Contract {
  param([string]$Mode, [bool]$Condition, [string]$Expected, [string]$Output = '')
  if ($Condition) { return }
  $snippet = ($Output -replace "`r", '')
  if ($snippet.Length -gt 700) { $snippet = $snippet.Substring(0, 700) + '...' }
  $Failures.Add("Windows ${Mode}: expected ${Expected}. Output:`n${snippet}") | Out-Null
}

function Assert-Contains {
  param([string]$Mode, [string]$Text, [string]$Pattern, [string]$Expected)
  Assert-Contract -Mode $Mode -Condition ([regex]::IsMatch($Text, $Pattern)) -Expected $Expected -Output $Text
}

function Assert-NotContains {
  param([string]$Mode, [string]$Text, [string]$Pattern, [string]$Expected)
  Assert-Contract -Mode $Mode -Condition (-not [regex]::IsMatch($Text, $Pattern)) -Expected $Expected -Output $Text
}

function Note-Pending {
  param([string]$Mode, [bool]$Condition, [string]$Expected, [string]$Output = '')
  if ($Condition) {
    Write-Output "PASS pending-ready Windows ${Mode}: ${Expected}"
    return
  }
  if ($EnforcePending) {
    Assert-Contract -Mode $Mode -Condition $false -Expected $Expected -Output $Output
  } else {
    Write-Output "PENDING Windows ${Mode}: ${Expected}"
  }
}

function Read-CommandLog {
  param([hashtable]$Sandbox)
  if (Test-Path $Sandbox.CommandLog) { return (Get-Content $Sandbox.CommandLog -Raw) }
  return ''
}

function Test-PowerShellParser {
  $files = @()
  $files += Get-ChildItem -Path (Join-Path $RepoRoot 'windows') -Recurse -Filter '*.ps1' -File
  $files += Get-Item -LiteralPath $PSCommandPath
  $parserFailed = $false
  foreach ($file in $files) {
    $parseErrors = $null
    [void][System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $file.FullName -Raw), [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
      $parserFailed = $true
      $Failures.Add("Windows parser: $($file.FullName) failed to parse: $($parseErrors[0].Message)") | Out-Null
    }
  }
  if (-not $parserFailed) {
    Write-Output "PASS Windows PowerShell parser: $($files.Count) files"
  }
}

try {
  Test-PowerShellParser

  $list = New-Sandbox
  $listResult = Invoke-Installer -Arguments @('-List') -Sandbox $list
  Assert-Contract 'step list' ($listResult.ExitCode -eq 0) 'exit 0 for -List' $listResult.Output
  Assert-Contains 'step list' $listResult.Output '\bresume\b' 'Windows installer exposes the resume step'
  Assert-Contains 'step list' $listResult.Output '\breport\b' 'Windows installer exposes the report step'

  $status = New-Sandbox
  $statusResult = Invoke-Installer -Arguments @('-Status') -Sandbox $status
  Assert-Contract 'status-only' ($statusResult.ExitCode -eq 0) 'exit 0 for read-only status' $statusResult.Output
  Assert-Contract 'status-only' ($statusResult.Output.Trim().Length -gt 0) 'non-empty status output instead of a silent exit' $statusResult.Output
  Assert-NotContains 'status-only' $statusResult.Output 'bss-ai-boilerplate v' 'no classic installer execution in status-only mode'
  Assert-Contract 'status-only' (-not (Test-Path (Join-Path $status.Helper 'state.json'))) 'no state file written by status-only mode' $statusResult.Output

  $wizard = New-Sandbox
  $wizardResult = Invoke-Installer -Arguments @('-Wizard') -InputText "1`n" -Sandbox $wizard
  Assert-Contract 'explicit wizard' ($wizardResult.ExitCode -eq 0) 'exit 0 when redirected input chooses status' $wizardResult.Output
  Assert-Contains 'explicit wizard' $wizardResult.Output 'BSS AI Helper' 'wizard prompt title'
  Assert-Contains 'explicit wizard' $wizardResult.Output '1\)' 'status menu choice'
  Assert-Contains 'explicit wizard' $wizardResult.Output '4\).*\(classic\)' 'classic/direct menu choice'
  Assert-Contains 'explicit wizard' $wizardResult.Output '5\)' 'exit menu choice'
  Assert-NotContains 'explicit wizard' $wizardResult.Output 'bss-ai-boilerplate v' 'wizard should not enter classic installer for status choice'
  Assert-Contract 'explicit wizard' (Test-Path (Join-Path $wizard.Helper 'state.json')) 'isolated helper state is created only under the sandbox' $wizardResult.Output

  $resume = New-Sandbox
  $resumeResult = Invoke-Installer -Arguments @('-Classic', '-Only', 'resume') -Sandbox $resume
  $resumeWrapper = Join-Path $resume.Helper 'bin\bss-ai-helper.ps1'
  $resumeFallback = Join-Path $resume.Helper 'skill-install-fallback.md'
  $resumeWrapperText = if (Test-Path $resumeWrapper) { Get-Content $resumeWrapper -Raw } else { '' }
  Assert-Contract 'resume surface' ($resumeResult.ExitCode -eq 0) 'resume step exits 0' $resumeResult.Output
  Assert-Contract 'resume surface' (Test-Path $resumeWrapper) 'PowerShell helper wrapper is created' $resumeResult.Output
  Assert-Contains 'resume surface' $resumeWrapperText 'windows\\install\.ps1' 'Windows wrapper targets the Windows installer'
  $resumeStatusResult = Invoke-GeneratedHelper -Arguments @('--status') -Sandbox $resume
  Assert-Contract 'resume status wrapper' ($resumeStatusResult.ExitCode -eq 0) 'bss-ai-helper --status exits 0' $resumeStatusResult.Output
  Assert-Contract 'resume status wrapper' ($resumeStatusResult.Output.Trim().Length -gt 0) 'bss-ai-helper --status shows helper status'
  Assert-NotContains 'resume status wrapper' $resumeStatusResult.Output 'unknown step id|bss-ai-boilerplate v' 'bss-ai-helper --status does not enter classic installer or reject GNU-style status'
  Assert-Contract 'skill-add fallback' (Test-Path $resumeFallback) 'missing skill-add writes fallback instructions' $resumeResult.Output
  Assert-Contract 'skill-add fallback' (-not (Test-Path (Join-Path $resume.Home '.codex\skills\bss-ai-helper'))) 'fallback does not write directly to .codex skills' $resumeResult.Output
  Assert-Contract 'skill-add fallback' (-not (Test-Path (Join-Path $resume.Home '.claude\skills\bss-ai-helper'))) 'fallback does not write directly to .claude skills' $resumeResult.Output
  Assert-Contract 'skill-add fallback' (-not (Test-Path (Join-Path $resume.Home '.agents\skills\bss-ai-helper'))) 'fallback does not write directly to .agents skills' $resumeResult.Output

  $wizardDryRun = New-Sandbox
  $wizardDryRunResult = Invoke-Installer -Arguments @('-Wizard', '-DryRun') -InputText "1`n" -Sandbox $wizardDryRun
  $wizardDryRunState = Test-Path (Join-Path $wizardDryRun.Helper 'state.json')
  Assert-Contract 'explicit wizard dry-run' ($wizardDryRunResult.ExitCode -eq 0) 'exit 0 when -Wizard -DryRun receives redirected status choice' $wizardDryRunResult.Output
  Assert-Contains 'explicit wizard dry-run' $wizardDryRunResult.Output 'BSS AI Helper' 'wizard prompt title'
  Write-Output "CHARACTERIZE Windows explicit wizard dry-run: state_exists=$wizardDryRunState"
  Note-Pending 'explicit wizard dry-run state policy' (-not $wizardDryRunState) 'dry-run wizard avoids persistent state writes outside the sandbox' $wizardDryRunResult.Output

  $wizardClassic = New-Sandbox
  foreach ($name in @('bun', 'npm', 'npx', 'curl', 'mise', 'rustup', 'gjc', 'codex', 'claude')) {
    Add-FakeCommand $wizardClassic $name
  }
  $wizardClassicEnv = @{
    BSS_AI_INSTALL_CODEX = '1'
    BSS_AI_INSTALL_CLAUDE = '1'
    BSS_AI_INSTALL_EXTRAS = '1'
    BSS_AI_HELPER_FORCE_INSTALL_PREVIEW = '1'
  }
  $wizardClassicResult = Invoke-Installer -Arguments @('-Wizard', '-DryRun', '-Only', 'agents') -InputText "4`n" -Sandbox $wizardClassic -ExtraEnv $wizardClassicEnv
  Assert-Contract 'explicit wizard classic choice' ($wizardClassicResult.ExitCode -eq 0) 'exit 0 when wizard choice 4 falls through to classic mode' $wizardClassicResult.Output
  Assert-Contains 'explicit wizard classic choice' $wizardClassicResult.Output 'steps: agents' 'classic/direct selected agents step after wizard choice 4'
  Assert-Contains 'explicit wizard classic choice' $wizardClassicResult.Output 'DRY-RUN' 'classic dry-run notice after wizard choice 4'

  $wizardInvalid = New-Sandbox
  $wizardInvalidResult = Invoke-Installer -Arguments @('-Wizard') -InputText "not-a-choice`n" -Sandbox $wizardInvalid
  Assert-Contract 'malformed wizard menu choice' ($wizardInvalidResult.ExitCode -eq 0) 'exit 0 and show status for an invalid wizard menu choice' $wizardInvalidResult.Output
  Assert-Contains 'malformed wizard menu choice' $wizardInvalidResult.Output '0/[0-9]+' 'status output after invalid wizard choice'
  Assert-NotContains 'malformed wizard menu choice' $wizardInvalidResult.Output 'bss-ai-boilerplate v' 'invalid wizard choice should not enter classic installer'

  $addonLongWork = New-Sandbox
  $addonLongWorkResult = Invoke-Installer -Arguments @('-Wizard', '-DryRun') -InputText "3`n3`n1`n3`n2`n2`n" -Sandbox $addonLongWork
  Assert-Contract 'addon long-work preference' ($addonLongWorkResult.ExitCode -eq 0) 'exit 0 when addon preference 3 is selected' $addonLongWorkResult.Output
  Assert-Contains 'addon long-work preference' $addonLongWorkResult.Output 'Lazy-Codex' 'Codex long-work addon recommendation'

  $addonAdvanced = New-Sandbox
  $addonAdvancedResult = Invoke-Installer -Arguments @('-Wizard', '-DryRun') -InputText "3`n3`n4`n4`n2`n2`n" -Sandbox $addonAdvanced
  Assert-Contract 'addon advanced preference' ($addonAdvancedResult.ExitCode -eq 0) 'exit 0 when addon preference 4 is selected' $addonAdvancedResult.Output
  Assert-Contains 'addon advanced preference' $addonAdvancedResult.Output 'Gajae-Code' 'advanced addon recommendation'

  $redirected = New-Sandbox
  Add-FakeCommand $redirected 'winget'
  Add-FakeCommand $redirected 'git'
  Add-FakeCommand $redirected 'gh'
  $redirectedResult = Invoke-Installer -Arguments @('-DryRun', '-Only', 'prereqs') -InputText "`n" -Sandbox $redirected
  Assert-Contract 'redirected stdin direct dry-run' ($redirectedResult.ExitCode -eq 0) 'exit 0 for redirected dry-run direct mode' $redirectedResult.Output
  Assert-Contains 'redirected stdin direct dry-run' $redirectedResult.Output 'DRY-RUN' 'dry-run notice'
  Assert-Contains 'redirected stdin direct dry-run' $redirectedResult.Output 'steps: prereqs' 'classic/direct selected step list'
  Assert-NotContains 'redirected stdin direct dry-run' $redirectedResult.Output 'BSS AI Helper' 'no implicit wizard prompt when stdin is redirected in direct mode'
  Assert-Contains 'redirected stdin direct dry-run' $redirectedResult.Output 'Input is redirected.*classic installer' 'clear noninteractive fallback explanation before classic work starts'

  $wingetViaWindowsApps = New-Sandbox
  Add-FakeCommand $wingetViaWindowsApps 'winget' $wingetViaWindowsApps.WindowsApps
  $wingetViaWindowsAppsResult = Invoke-Installer -Arguments @('-Classic', '-DryRun', '-Only', 'prereqs') -Sandbox $wingetViaWindowsApps -ExtraEnv @{ BSS_AI_HELPER_SKIP_PERSISTENT_PATH = '1' }
  Assert-Contract 'WindowsApps PATH refresh winget' ($wingetViaWindowsAppsResult.ExitCode -eq 0) 'exit 0 when winget is only in the user WindowsApps directory during dry-run' $wingetViaWindowsAppsResult.Output
  Assert-Contains 'WindowsApps PATH refresh winget' $wingetViaWindowsAppsResult.Output 'winget present \(fake-version\)' 'current-session PATH refresh finds winget in WindowsApps'

  $missingWinget = New-Sandbox
  $missingWingetResult = Invoke-Installer -Arguments @('-Classic', '-DryRun', '-Only', 'prereqs') -Sandbox $missingWinget -ExtraEnv @{ BSS_AI_HELPER_DISABLE_PATH_REFRESH = '1' }
  Assert-Contract 'missing winget diagnostics' ($missingWingetResult.ExitCode -eq 0) 'dry-run reports missing winget without failing' $missingWingetResult.Output
  Assert-Contains 'missing winget diagnostics' $missingWingetResult.Output 'App Installer' 'actionable App Installer guidance'
  Assert-Contains 'missing winget diagnostics' $missingWingetResult.Output 'WindowsApps' 'actionable WindowsApps PATH guidance'
  Assert-NotContains 'missing winget diagnostics' $missingWingetResult.Output 'CommandNotFoundException|The term ''winget''' 'no raw command-not-found crash'

  $brokenWinget = New-Sandbox
  Add-BrokenCommand $brokenWinget 'winget'
  $brokenWingetResult = Invoke-Installer -Arguments @('-Classic', '-Only', 'prereqs') -Sandbox $brokenWinget
  $brokenWingetLog = Read-CommandLog $brokenWinget
  Assert-Contract 'broken winget diagnostics' ($brokenWingetResult.ExitCode -ne 0) 'non-zero exit when winget exists but cannot run' $brokenWingetResult.Output
  Assert-Contains 'broken winget diagnostics' $brokenWingetResult.Output 'winget.*not working|App Installer' 'actionable broken winget/App Installer diagnostic'
  Assert-Contains 'broken winget diagnostics' $brokenWingetResult.Output 'WindowsApps' 'WindowsApps PATH recovery hint'
  Assert-Contract 'broken winget diagnostics' ([regex]::IsMatch($brokenWingetLog, '(?m)^winget --version')) 'only a bounded winget readiness probe executes' $brokenWingetLog
  Assert-NotContains 'broken winget diagnostics' $brokenWingetResult.Output 'winget install' 'no package operation starts after a broken winget probe'

  $agents = New-Sandbox
  foreach ($name in @('bun', 'npm', 'npx', 'curl', 'mise', 'rustup', 'gjc', 'codex', 'claude')) {
    Add-FakeCommand $agents $name
  }
  $agentEnv = @{
    BSS_AI_INSTALL_CODEX = '1'
    BSS_AI_INSTALL_CLAUDE = '1'
    BSS_AI_INSTALL_EXTRAS = '1'
    BSS_AI_HELPER_FORCE_INSTALL_PREVIEW = '1'
  }
  $agentsResult = Invoke-Installer -Arguments @('-Classic', '-DryRun', '-Only', 'agents') -Sandbox $agents -ExtraEnv $agentEnv
  $agentLog = Read-CommandLog $agents
  Assert-Contract 'classic/direct dry-run agents' ($agentsResult.ExitCode -eq 0) 'exit 0 for classic dry-run agents step' $agentsResult.Output
  Assert-Contains 'classic/direct dry-run agents' $agentsResult.Output 'steps: agents' 'classic/direct selected agents step'
  Assert-Contains 'classic/direct dry-run agents' $agentsResult.Output '\[dry-run\].*(npm install|Claude|npx)' 'observable dry-run agent install preview'
  Assert-Contract 'classic/direct dry-run agents' (-not [regex]::IsMatch($agentLog, '(?m)^(bun|npm|npx|curl|mise|rustup) ')) 'mocked install/network commands are not executed in dry-run' $agentLog
  Assert-Contract 'strict dry-run agents' (-not [regex]::IsMatch($agentLog, '(?m)^(gjc|codex|claude) ')) 'dry-run avoids even shadowed agent version probes' $agentLog

  $badStep = New-Sandbox
  $badResult = Invoke-Installer -Arguments @('-DryRun', '-Only', 'definitely-not-a-step') -Sandbox $badStep
  Assert-Contract 'malformed input invalid step' ($badResult.ExitCode -ne 0) 'non-zero exit for an invalid step id' $badResult.Output
  Assert-Contains 'malformed input invalid step' $badResult.Output "unknown step id: 'definitely-not-a-step'" 'clear invalid step message'

  if ($Failures.Count -gt 0) {
    foreach ($failure in $Failures) { Write-Error $failure -ErrorAction Continue }
    exit 1
  }
  Write-Output 'PASS Windows installer contract harness'
} finally {
  foreach ($path in $Cleanups) {
    if (Test-Path $path) { Remove-Item -Recurse -Force $path -ErrorAction SilentlyContinue }
  }
}
