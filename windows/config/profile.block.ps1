# managed by ai-boiler-plate -- edits between the markers are overwritten on re-run.

# Refresh PATH from persisted Machine/User values. Installers such as winget can
# update the persistent PATH while the parent app process still has an old copy.
$PathParts = New-Object System.Collections.Generic.List[string]
foreach ($sourcePath in @(
  $env:Path,
  [Environment]::GetEnvironmentVariable('Path', 'Machine'),
  [Environment]::GetEnvironmentVariable('Path', 'User')
)) {
  if ([string]::IsNullOrWhiteSpace($sourcePath)) { continue }
  foreach ($pathPart in ($sourcePath -split ';')) {
    if (-not [string]::IsNullOrWhiteSpace($pathPart)) { $PathParts.Add($pathPart) }
  }
}
$SeenPathParts = @{}
$MergedPathParts = @()
foreach ($pathPart in $PathParts) {
  $normalizedPathPart = $pathPart.TrimEnd('\').ToLowerInvariant()
  if ($SeenPathParts.ContainsKey($normalizedPathPart)) { continue }
  $SeenPathParts[$normalizedPathPart] = $true
  $MergedPathParts += $pathPart
}
if ($MergedPathParts.Count -gt 0) { $env:Path = $MergedPathParts -join ';' }

# mise: node / python / go version manager
if (Get-Command mise -ErrorAction SilentlyContinue) {
  if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $env:MISE_PWSH_CHPWD_WARNING) {
    $env:MISE_PWSH_CHPWD_WARNING = '0'
  }
  (& mise activate pwsh) -join "`n" | Invoke-Expression
}

# bun: global packages live in ~/.bun/bin
$env:BUN_INSTALL = Join-Path $env:USERPROFILE '.bun'
if (Test-Path (Join-Path $env:BUN_INSTALL 'bin')) {
  $env:Path = (Join-Path $env:BUN_INSTALL 'bin') + ';' + $env:Path
}

# rust (rustup / cargo)
if (Test-Path (Join-Path $env:USERPROFILE '.cargo\bin')) {
  $env:Path = (Join-Path $env:USERPROFILE '.cargo\bin') + ';' + $env:Path
}

# Claude Code (claude.exe) installs to ~/.local/bin. The installer also adds a
# User-scope PATH entry of its own, so this may be redundant -- but it's a cheap,
# idempotent guarantee that `claude` resolves in every new shell.
if (Test-Path (Join-Path $env:USERPROFILE '.local\bin')) {
  $env:Path = (Join-Path $env:USERPROFILE '.local\bin') + ';' + $env:Path
}

$AiBoilerPlateHome = if ($env:AI_BOILER_PLATE_HOME) {
  $env:AI_BOILER_PLATE_HOME
} elseif ($env:BSS_AI_HELPER_HOME) {
  $env:BSS_AI_HELPER_HOME
} else {
  Join-Path $env:USERPROFILE '.ai-boiler-plate'
}
$LegacyBssAiHelperHome = if ($env:BSS_AI_HELPER_HOME) { $env:BSS_AI_HELPER_HOME } else { Join-Path $env:USERPROFILE '.bss-ai-helper' }
if (-not (Test-Path (Join-Path $AiBoilerPlateHome 'bin')) -and (Test-Path (Join-Path $LegacyBssAiHelperHome 'bin'))) {
  $AiBoilerPlateHome = $LegacyBssAiHelperHome
}
$AiBoilerPlateBin = Join-Path $AiBoilerPlateHome 'bin'
if (Test-Path $AiBoilerPlateBin) {
  $env:Path = $AiBoilerPlateBin + ';' + $env:Path
}
function ai-boiler-plate {
  $preferred = Join-Path $AiBoilerPlateHome 'bin\ai-boiler-plate.ps1'
  $legacy = Join-Path $AiBoilerPlateHome 'bin\bss-ai-helper.ps1'
  if (Test-Path $preferred) { & $preferred @args }
  elseif (Test-Path $legacy) { & $legacy @args }
  else { Write-Error "ai-boiler-plate command not installed under $AiBoilerPlateBin" }
}
# Deprecated compatibility aliases for installed users; prefer ai-boiler-plate.
function bss-ai-helper { ai-boiler-plate @args }
function ai-helper { ai-boiler-plate @args }
function bss-ai { ai-boiler-plate @args }

# PSReadLine: zsh-autosuggestions-style inline prediction + completion menu.
# (Syntax highlighting as you type is built into PSReadLine -- no config needed.)
if (Get-Module -ListAvailable -Name PSReadLine) {
  Import-Module PSReadLine -ErrorAction SilentlyContinue
  # command-based predictions (needs PSReadLine 2.2+); enables HistoryAndPlugin
  Import-Module CompletionPredictor -ErrorAction SilentlyContinue
  # inline gray suggestion from history (+ plugins) -- the zsh-autosuggestions feel
  try { Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Stop }
  catch { try { Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue } catch {} }
  # dropdown list of suggestions (PSReadLine 2.2+); harmless if unsupported
  try { Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue } catch {}
  try { Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue } catch {}
  # Tab -> completion menu (like zsh completions)
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
  # Up/Down = search history by what you've already typed (zsh history-substring-search)
  Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward -ErrorAction SilentlyContinue
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward  -ErrorAction SilentlyContinue
}

# PSFzf: fuzzy finder keybindings (Ctrl-T files, Ctrl-R history) when installed.
# The module throws during import when fzf.exe is not reachable, so check both.
if ((Get-Module -ListAvailable -Name PSFzf) -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
  Import-Module PSFzf -ErrorAction SilentlyContinue
  try { Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue } catch {}
}

# bat: nicer cat. 'cat' is a built-in ALIAS for Get-Content and PowerShell resolves
# Alias > Function, so a plain `function cat` would be dead code -- remove the alias
# first. The process/end blocks let it work both with file args (`cat file`) and as
# a pipeline target (`git diff | cat`): piped input is collected and forwarded.
if (Get-Command bat -ErrorAction SilentlyContinue) {
  Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
  function cat {
    begin { $piped = @() }
    # A process block runs ONCE with $_ = $null when the function is called
    # standalone (`cat file`), so filter nulls or that phantom item would make us
    # pipe a blank line to bat instead of passing the file argument through.
    process { if ($null -ne $_) { $piped += $_ } }
    end {
      if ($piped.Count -gt 0) { $piped | bat --paging=never @args }
      else { bat --paging=never @args }
    }
  }
}

# starship prompt -- keep LAST so it owns the prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (& starship init powershell)
}
