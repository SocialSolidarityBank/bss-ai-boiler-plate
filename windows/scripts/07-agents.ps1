# 07-agents.ps1 -- AI coding agents: gajae-code (gjc), codex, lazycodex (OmO),
# Claude Code (claude)

function Step-Agents {
  $installCodex = ($env:BSS_AI_INSTALL_CODEX -ne '0')
  $installClaude = ($env:BSS_AI_INSTALL_CLAUDE -ne '0')
  $installExtras = ($env:BSS_AI_INSTALL_EXTRAS -ne '0')
  $forcePreview = ($env:BSS_AI_HELPER_FORCE_INSTALL_PREVIEW -eq '1')
  $primaryFailed = $false
  $titleParts = @()
  if ($installExtras) { $titleParts += 'gajae-code' }
  if ($installCodex) { $titleParts += 'codex' }
  if ($installExtras -and $installCodex) { $titleParts += 'lazycodex' }
  if ($installClaude) { $titleParts += 'Claude Code' }
  $title = if ($titleParts.Count -gt 0) { $titleParts -join ' + ' } else { 'record selected AI services' }
  Write-Step "AI agents: $title"
  Update-SessionPath

  # --- gajae-code (gjc) via bun -----------------------------------------
  if (-not $installExtras) {
  } elseif (Test-HasCommand bun) {
    if (Test-HasCommand gjc) {
      Write-Ok "gajae-code present (gjc $(Invoke-NativeSilently 'gjc' @('--version') | Select-Object -First 1))"
    } else {
      Write-Info "Installing gajae-code (bun add -g gajae-code)..."
      Invoke-Run -Exe 'bun' -Arguments @('add', '-g', 'gajae-code') | Out-Null
      Update-SessionPath
    }
  } else {
    Write-Warn "bun not found -- skipping gajae-code (install bun via the 'packages' step)"
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
        Write-Warn "npm not found -- skipping codex + lazycodex (run the 'runtimes' step first)"
        if ($installCodex) { $primaryFailed = $true }
      }
    } else {
      if ($script:DryRun -and $forcePreview) {
        Write-Info "[dry-run] mise exec -- npm install -g @openai/codex; mise reshim"
      } elseif (Test-HasCommand codex) {
        Write-Ok "codex present ($(Invoke-NativeSilently 'codex' @('--version') | Select-Object -First 1))"
      } else {
        Write-Info "Installing @openai/codex (npm -g)..."
        if ($script:DryRun) {
          Write-Info "[dry-run] mise exec -- npm install -g @openai/codex; mise reshim"
        } else {
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
  } elseif ($script:DryRun -and $forcePreview) {
    Write-Info "[dry-run] irm https://claude.ai/install.ps1 | iex"
  } elseif (Test-HasCommand claude) {
    Write-Ok "Claude Code present ($(Invoke-NativeSilently 'claude' @('--version') | Select-Object -First 1))"
  } elseif ($script:DryRun) {
    Write-Info "[dry-run] irm https://claude.ai/install.ps1 | iex"
  } else {
    Write-Info "Installing Claude Code (irm https://claude.ai/install.ps1 | iex)..."
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
      if (Test-HasCommand claude) {
        Write-Ok "Claude Code installed ($(Invoke-NativeSilently 'claude' @('--version') | Select-Object -First 1))"
      } else {
        Write-Info "Claude Code installed -- open a new shell (or it's on ~/.local/bin) to use 'claude'."
      }
    } catch {
      Write-Warn "Claude Code install did not complete -- re-run later: irm https://claude.ai/install.ps1 | iex"
      $primaryFailed = $true
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
