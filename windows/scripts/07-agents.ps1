# 07-agents.ps1 -- AI coding agents: codex, Matt Pocock Skills, lazycodex (OmO),
# Claude Code (claude)

function Get-AgentVersionLine {
  param([Parameter(Mandatory)][string]$Exe)
  try {
    $out = @(Invoke-NativeSilently $Exe @('--version'))
    if ($LASTEXITCODE -eq 0 -and $out.Count -gt 0) { return ($out | Select-Object -First 1) }
  } catch {
    return $null
  }
  return $null
}

function Step-Agents {
  $installCodex = ($env:BSS_AI_INSTALL_CODEX -ne '0')
  $installClaude = ($env:BSS_AI_INSTALL_CLAUDE -ne '0')
  $installMatt = ($env:BSS_AI_INSTALL_MATT -ne '0')
  $installExtras = ($env:BSS_AI_INSTALL_EXTRAS -eq '1')
  $primaryFailed = $false
  $titleParts = @()
  if ($installCodex) { $titleParts += 'codex' }
  if ($installMatt) { $titleParts += 'Matt Pocock Skills' }
  if ($installExtras -and $installCodex) { $titleParts += 'lazycodex' }
  if ($installClaude) { $titleParts += 'Claude Code' }
  $title = if ($titleParts.Count -gt 0) { $titleParts -join ' + ' } else { 'record selected AI services' }
  Write-Step "AI agents: $title"
  Update-SessionPath

  # --- Matt Pocock Skills (selected guided setup) -----------------------
  if (-not $installMatt) {
    Write-Info "Skipping Matt Pocock Skills (BSS_AI_INSTALL_MATT=0)"
  } elseif ($script:DryRun) {
    Write-Info "[dry-run] npx --yes skills@latest add mattpocock/skills"
    Write-Info "[dry-run] after install, tell your agent: /setup-matt-pocock-skills"
  } elseif (Test-HasCommand npx) {
    Write-Info "Installing Matt Pocock Skills (npx skills@latest add mattpocock/skills)..."
    if (Invoke-Run -Exe 'npx' -Arguments @('--yes', 'skills@latest', 'add', 'mattpocock/skills')) {
      Write-Info "Matt Pocock Skills: tell your agent /setup-matt-pocock-skills after install."
    } else {
      Write-Warn "Matt Pocock Skills setup did not complete -- re-run later: npx skills@latest add mattpocock/skills"
      $primaryFailed = $true
    }
  } elseif (Test-HasCommand mise) {
    Write-Info "Installing Matt Pocock Skills with mise (npx skills@latest add mattpocock/skills)..."
    & mise exec -- npx --yes skills@latest add mattpocock/skills
    if ($LASTEXITCODE -eq 0) {
      Write-Info "Matt Pocock Skills: tell your agent /setup-matt-pocock-skills after install."
    } else {
      Write-Warn "Matt Pocock Skills setup did not complete -- re-run later: npx skills@latest add mattpocock/skills"
      $primaryFailed = $true
    }
  } else {
    Write-Warn "npx not found -- selected Matt Pocock Skills setup is pending: npx skills@latest add mattpocock/skills"
    Write-Warn "After it installs, tell your agent: /setup-matt-pocock-skills"
    $primaryFailed = $true
  }

  # --- codex (base harness that lazycodex extends) ----------------------
  if ($installCodex) {
    $haveNpm = Test-HasCommand npm
    if (-not $haveNpm -and (Test-HasCommand mise)) {
      # npm may only be reachable through mise's node shim
      $haveNpm = $true
    }
    if (-not $haveNpm) {
      if ($script:DryRun) {
        Write-Info "[dry-run] mise exec -- npm install -g @openai/codex; mise reshim"
      } else {
        Write-Warn "npm not found -- skipping selected npm-based agents (run the 'runtimes' step first)"
        if ($installCodex) { $primaryFailed = $true }
      }
    } else {
      if ($script:DryRun) {
        Write-Info "[dry-run] mise exec -- npm install -g @openai/codex; mise reshim"
      } else {
        $codexVersion = $null
        if (Test-HasCommand codex) { $codexVersion = Get-AgentVersionLine -Exe 'codex' }
        if ($codexVersion) {
          Write-Ok "codex present ($codexVersion)"
        } else {
          if (Test-HasCommand codex) {
            Write-Warn "codex command exists but did not run -- installing Codex CLI via npm"
          } else {
            Write-Info "Installing @openai/codex (npm -g)..."
          }
          try {
            if (Test-HasCommand mise) {
              & mise exec -- npm install -g '@openai/codex'
              if ($LASTEXITCODE -ne 0) { throw "mise npm install failed with exit $LASTEXITCODE" }
              Invoke-NativeSilently 'mise' @('reshim')
            } else {
              & npm install -g '@openai/codex'
              if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit $LASTEXITCODE" }
            }
          } catch {
            Write-Warn "Codex CLI install did not complete -- re-run after Node/npm is available"
            $primaryFailed = $true
          }
        }
        Update-SessionPath
      }

      if ($installExtras) {
        if ($script:DryRun) {
          Write-Info "[dry-run] npx --yes lazycodex-ai install"
        } elseif (-not [Console]::IsInputRedirected) {
          Write-Info "Installing lazycodex (npx lazycodex-ai install)..."
          & npx --yes lazycodex-ai install
          if ($LASTEXITCODE -ne 0) { Write-Warn "lazycodex installer did not complete" }
        } else {
          Write-Info "Installing lazycodex (non-interactive, autonomous)..."
          & npx --yes lazycodex-ai install --no-tui --codex-autonomous
          if ($LASTEXITCODE -ne 0) { Write-Warn "lazycodex installer did not complete" }
        }
        Write-Info "lazycodex: on first 'codex' launch, APPROVE the omo hooks in the startup review."
      }
    }
  }

  # --- Claude Code (claude) via the official installer ------------------
  # https://claude.ai/install.ps1 is non-interactive, works on WinPS 5.1+/7,
  # installs to ~/.local/bin/claude.exe, and self-updates in the background.
  if (-not $installClaude) {
  } elseif ($script:DryRun) {
    Write-Info "[dry-run] irm https://claude.ai/install.ps1 | iex"
  } else {
    $claudeVersion = $null
    if (Test-HasCommand claude) { $claudeVersion = Get-AgentVersionLine -Exe 'claude' }
    if ($claudeVersion) {
      Write-Ok "Claude Code present ($claudeVersion)"
    } else {
      if (Test-HasCommand claude) {
        Write-Warn "Claude Code command exists but did not run -- reinstalling"
      } else {
        Write-Info "Installing Claude Code (irm https://claude.ai/install.ps1 | iex)..."
      }
      try {
        # Fetch the installer into a variable and sanity-check it before running,
        # rather than piping straight into `iex`. Executing a scriptblock built
        # from the text works on WinPS 5.1 too (no `| iex` of a raw string).
        $installer = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1'
        if ([string]::IsNullOrWhiteSpace($installer)) {
          throw "installer download was empty"
        }
        & ([scriptblock]::Create($installer))
        # Make claude.exe (~/.local/bin) visible to later steps this session.
        Update-SessionPath
        $claudeVersion = if (Test-HasCommand claude) { Get-AgentVersionLine -Exe 'claude' } else { $null }
        if ($claudeVersion) {
          Write-Ok "Claude Code installed ($claudeVersion)"
        } else {
          Write-Info "Claude Code installed -- open a new shell (or it's on ~/.local/bin) to use 'claude'."
        }
      } catch {
        Write-Warn "Claude Code install did not complete -- re-run later: irm https://claude.ai/install.ps1 | iex"
        $primaryFailed = $true
      }
    }
  }

  # --- Hermes Agent (Nous Research) -------------------------------------
  # The official installer is a bash/curl script with no native Windows build.
  # Run it inside WSL if you want Hermes on Windows.
  if ($installExtras) {
    Write-Info "Hermes Agent: no native Windows installer -- install it inside WSL2:"
    Write-Info "  wsl bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup'"
  }
  return (-not $primaryFailed)
}
