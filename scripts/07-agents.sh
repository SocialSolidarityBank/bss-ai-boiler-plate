#!/usr/bin/env bash
# 07-agents.sh — AI coding agents: gajae-code (gjc), codex, lazycodex (OmO), Claude Code

step_agents() {
  local install_codex="${BSS_AI_INSTALL_CODEX:-1}"
  local install_claude="${BSS_AI_INSTALL_CLAUDE:-1}"
  local install_extras="${BSS_AI_INSTALL_EXTRAS:-1}"
  local primary_failed=0
  local title_parts=""
  [[ "$install_extras" == "1" ]] && title_parts="${title_parts:+$title_parts + }gajae-code"
  [[ "$install_codex" == "1" ]] && title_parts="${title_parts:+$title_parts + }codex"
  [[ "$install_extras" == "1" && "$install_codex" == "1" ]] && title_parts="${title_parts:+$title_parts + }lazycodex"
  [[ "$install_claude" == "1" ]] && title_parts="${title_parts:+$title_parts + }Claude Code"
  [[ -n "$title_parts" ]] || title_parts="record selected AI services"
  step "AI agents: $title_parts"
  load_brew
  load_mise
  export PATH="$HOME/.bun/bin:$PATH"   # bun global bins (gjc) live here
  # ~/.local/bin hosts claude (Claude Code) and hermes; exporting it up front
  # also makes the Hermes installer detect PATH and skip editing ~/.zshrc
  # (the kit's managed block owns that PATH entry instead).
  export PATH="$HOME/.local/bin:$PATH"

  # --- gajae-code (gjc) via bun -----------------------------------------
  if [[ "$install_extras" != "1" ]]; then
    :
  elif have bun; then
    if have gjc; then
      ok "gajae-code present (gjc $(gjc --version 2>/dev/null | head -1))"
    else
      info "Installing gajae-code (bun add -g gajae-code)…"
      run bun add -g gajae-code
    fi
  else
    warn "bun not found — skipping gajae-code (install bun via the 'brew' step)"
  fi

  # --- Claude Code (Anthropic) ------------------------------------------
  # Official installer drops the `claude` binary into ~/.local/bin and then
  # self-updates in the background. Installs by default everywhere (incl. CI).
  # Kept ahead of the npm-dependent agents so a box without node still gets it.
  if [[ "$install_claude" != "1" ]]; then
    :
  elif [[ "$DRY_RUN" == "1" && "${BSS_AI_HELPER_FORCE_INSTALL_PREVIEW:-0}" == "1" ]]; then
    info "[dry-run] curl -fsSL https://claude.ai/install.sh | bash"
  elif have claude; then
    ok "Claude Code present ($(claude --version 2>/dev/null | head -1))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://claude.ai/install.sh | bash"
  else
    info "Installing Claude Code (Anthropic)…"
    # Download first, then verify it's a real script (non-empty + shebang)
    # before executing — a truncated/failed download must not run as bash.
    local cc_tmp; cc_tmp="$(mktemp)"
    if curl -fsSL https://claude.ai/install.sh -o "$cc_tmp" \
       && [[ -s "$cc_tmp" ]] && head -1 "$cc_tmp" | grep -q '^#!'; then
      if ! bash "$cc_tmp"; then
        warn "Claude Code install did not complete — re-run later: curl -fsSL https://claude.ai/install.sh | bash"
        primary_failed=1
      fi
    else
      warn "Claude Code install did not complete — re-run later: curl -fsSL https://claude.ai/install.sh | bash"
      primary_failed=1
    fi
    rm -f "$cc_tmp"
  fi

  # --- codex (base harness that lazycodex extends) ----------------------
  if [[ "$install_codex" != "1" && "$install_extras" != "1" ]]; then
    return "$primary_failed"
  fi
  if ! have npm; then
    if [[ "$DRY_RUN" == "1" ]]; then
      [[ "$install_codex" == "1" ]] && info "[dry-run] npm install -g @openai/codex"
      [[ "$install_extras" == "1" && "$install_codex" == "1" ]] && info "[dry-run] npx --yes lazycodex-ai install"
    else
      warn "npm not found — skipping codex + lazycodex (run the 'runtimes' step first)"
      [[ "$install_codex" == "1" ]] && primary_failed=1
    fi
  elif [[ "$install_codex" != "1" ]]; then
    :
  elif [[ "$DRY_RUN" == "1" && "${BSS_AI_HELPER_FORCE_INSTALL_PREVIEW:-0}" == "1" ]]; then
    info "[dry-run] npm install -g @openai/codex"
  elif have codex; then
    ok "codex present ($(codex --version 2>/dev/null | head -1))"
  else
    info "Installing @openai/codex (npm -g)…"
    if run npm install -g @openai/codex; then
      # mise-managed node needs a reshim so the `codex` shim appears on PATH
      have mise && run mise reshim
    else
      warn "Codex CLI install did not complete — re-run after Node/npm is available"
      primary_failed=1
    fi
  fi

  # --- lazycodex (OmO agent harness for codex) --------------------------
  # No global install by design — always run via npx.
  if [[ "$install_extras" != "1" || "$install_codex" != "1" ]]; then
    :
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] npx --yes lazycodex-ai install"
  elif is_tty && [[ "$ASSUME_YES" != "1" ]]; then
    info "Installing lazycodex (npx lazycodex-ai install)…"
    npx --yes lazycodex-ai install || warn "lazycodex installer did not complete"
  else
    info "Installing lazycodex (non-interactive, autonomous)…"
    npx --yes lazycodex-ai install --no-tui --codex-autonomous || \
      warn "lazycodex installer did not complete"
  fi
  [[ "$install_extras" == "1" && "$install_codex" == "1" ]] && info "lazycodex: on first 'codex' launch, APPROVE the omo hooks in the startup review."

  # --- Hermes Agent (Nous Research) -------------------------------------
  # Official installer: clones NousResearch/hermes-agent, self-manages Python/
  # Node/Chromium, links `hermes` into ~/.local/bin (already on PATH, exported
  # at the top of this step). Heavy + external, so it's non-fatal and
  # toggleable with HERMES=0 (CI sets HERMES=0 to stay lean).
  if [[ "$install_extras" != "1" ]]; then
    :
  elif [[ "${HERMES:-1}" != "1" ]]; then
    info "Skipping Hermes Agent (HERMES=0)"
  elif have hermes; then
    ok "Hermes Agent present ($(hermes --version 2>/dev/null | head -1 || echo installed))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup"
  else
    info "Installing Hermes Agent (Nous Research)…"
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup \
      || warn "Hermes installer did not complete (re-run later: curl … | bash)"
    info "Hermes: configure with 'hermes setup --portal', then start with 'hermes'."
  fi
  return "$primary_failed"
}
