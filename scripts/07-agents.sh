#!/usr/bin/env bash
# 07-agents.sh -- AI coding agents: codex, Matt Pocock Skills, lazycodex (OmO), Claude Code

step_agents() {
  local install_codex="${BSS_AI_INSTALL_CODEX:-1}"
  local install_claude="${BSS_AI_INSTALL_CLAUDE:-1}"
  local install_extras="${BSS_AI_INSTALL_EXTRAS:-0}"
  local primary_failed=0
  local title_parts=""
  [[ "$install_codex" == "1" ]] && title_parts="${title_parts:+$title_parts + }codex"
  title_parts="${title_parts:+$title_parts + }Matt Pocock Skills"
  [[ "$install_extras" == "1" && "$install_codex" == "1" ]] && title_parts="${title_parts:+$title_parts + }lazycodex"
  [[ "$install_claude" == "1" ]] && title_parts="${title_parts:+$title_parts + }Claude Code"
  [[ -n "$title_parts" ]] || title_parts="record selected AI services"
  step "AI agents: $title_parts"
  load_brew
  load_mise
  export PATH="$HOME/.local/bin:$PATH"

  # --- Matt Pocock Skills (required guided setup) -----------------------
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] npx --yes skills@latest add mattpocock/skills"
    info "[dry-run] after install, tell your agent: /setup-matt-pocock-skills"
  elif have npx; then
    info "Installing Matt Pocock Skills (npx skills@latest add mattpocock/skills)..."
    if run npx --yes skills@latest add mattpocock/skills; then
      info "Matt Pocock Skills: tell your agent /setup-matt-pocock-skills after install."
    else
      warn "Matt Pocock Skills setup did not complete -- re-run later: npx skills@latest add mattpocock/skills"
      primary_failed=1
    fi
  elif have mise; then
    info "Installing Matt Pocock Skills with mise (npx skills@latest add mattpocock/skills)..."
    if mise exec -- npx --yes skills@latest add mattpocock/skills; then
      info "Matt Pocock Skills: tell your agent /setup-matt-pocock-skills after install."
    else
      warn "Matt Pocock Skills setup did not complete -- re-run later: npx skills@latest add mattpocock/skills"
      primary_failed=1
    fi
  else
    warn "npx not found -- required Matt Pocock Skills setup is pending: npx skills@latest add mattpocock/skills"
    warn "After it installs, tell your agent: /setup-matt-pocock-skills"
    primary_failed=1
  fi

  # --- Claude Code (Anthropic) ------------------------------------------
  if [[ "$install_claude" != "1" ]]; then
    :
  elif [[ "$DRY_RUN" == "1" && "${BSS_AI_HELPER_FORCE_INSTALL_PREVIEW:-0}" == "1" ]]; then
    info "[dry-run] curl -fsSL https://claude.ai/install.sh | bash"
  elif have claude; then
    ok "Claude Code present ($(claude --version 2>/dev/null | head -1))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://claude.ai/install.sh | bash"
  else
    info "Installing Claude Code (Anthropic)..."
    local cc_tmp
    cc_tmp="$(mktemp)"
    if curl -fsSL https://claude.ai/install.sh -o "$cc_tmp" \
       && [[ -s "$cc_tmp" ]] && head -1 "$cc_tmp" | grep -q '^#!'; then
      if ! bash "$cc_tmp"; then
        warn "Claude Code install did not complete -- re-run later: curl -fsSL https://claude.ai/install.sh | bash"
        primary_failed=1
      fi
    else
      warn "Claude Code install did not complete -- re-run later: curl -fsSL https://claude.ai/install.sh | bash"
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
      warn "npm not found -- skipping selected npm-based agents (run the 'runtimes' step first)"
      [[ "$install_codex" == "1" ]] && primary_failed=1
    fi
  elif [[ "$install_codex" != "1" ]]; then
    :
  elif [[ "$DRY_RUN" == "1" && "${BSS_AI_HELPER_FORCE_INSTALL_PREVIEW:-0}" == "1" ]]; then
    info "[dry-run] npm install -g @openai/codex"
  elif have codex; then
    ok "codex present ($(codex --version 2>/dev/null | head -1))"
  else
    info "Installing @openai/codex (npm -g)..."
    if run npm install -g @openai/codex; then
      have mise && run mise reshim
    else
      warn "Codex CLI install did not complete -- re-run after Node/npm is available"
      primary_failed=1
    fi
  fi

  # --- lazycodex (OmO agent harness for codex) --------------------------
  if [[ "$install_extras" != "1" || "$install_codex" != "1" ]]; then
    :
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] npx --yes lazycodex-ai install"
  elif is_tty && [[ "$ASSUME_YES" != "1" ]]; then
    info "Installing lazycodex (npx lazycodex-ai install)..."
    npx --yes lazycodex-ai install || warn "lazycodex installer did not complete"
  else
    info "Installing lazycodex (non-interactive, autonomous)..."
    npx --yes lazycodex-ai install --no-tui --codex-autonomous || \
      warn "lazycodex installer did not complete"
  fi
  [[ "$install_extras" == "1" && "$install_codex" == "1" ]] && info "lazycodex: on first 'codex' launch, APPROVE the omo hooks in the startup review."

  # --- Hermes Agent (Nous Research) -------------------------------------
  if [[ "$install_extras" != "1" ]]; then
    :
  elif [[ "${HERMES:-1}" != "1" ]]; then
    info "Skipping Hermes Agent (HERMES=0)"
  elif have hermes; then
    ok "Hermes Agent present ($(hermes --version 2>/dev/null | head -1 || echo installed))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup"
  else
    info "Installing Hermes Agent (Nous Research)..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup \
      || warn "Hermes installer did not complete (re-run later: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup)"
    info "Hermes: configure with 'hermes setup --portal', then start with 'hermes'."
  fi
  return "$primary_failed"
}
