# ai-boiler-plate extension points

This document defines the room for future swaps after v1.

## Core stays fixed

Do not replace these as part of a skills/plugins change:

- OS installers: `install.sh`, `linux/install.sh`, `windows/install.ps1`
- Package foundations: Homebrew, Linux distro package managers, winget
- Runtime foundations: mise, rustup, uv, bun
- Shell foundations: zsh blocks, PowerShell profile blocks, starship
- Git/GitHub setup, state storage, status/resume, report/manual generation
- Container policy: Colima/Docker Engine/Docker Desktop as opt-in where documented
- Runtime/auth safety: never write directly into `~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills`, token files, or OAuth files

Changing any item above is a new base-installer project, not a plugin swap.

## Swappable room

Skills and plugins may change in this layer only:

| Purpose | POSIX files | Windows files | Notes |
| --- | --- | --- | --- |
| Required skill setup | `scripts/07-agents.sh`, `linux/scripts/07-agents.sh` | `windows/scripts/07-agents.ps1` | Matt Pocock Skills is v1 required. Replace only with an explicit v2 decision. |
| Optional recommendations | `lib/recommendations.sh`, `lib/wizard-addons.sh` | `windows/scripts/recommendations.ps1`, `windows/scripts/wizard-ai.ps1` | Optional by default. Must ask before install. |
| Agent-facing guidance | `AGENTS.md`, `resources/codex-skill/bss-ai-helper/SKILL.md` | same shared docs | Keep agent-first entry and business-judgment routing. |
| User docs | `README.md`, `docs/`, `linux/README.md` | `windows/README.md` | Explain what changed and what stays core. |
| QA coverage | `scripts/qa/` | `scripts/qa/lane3-windows-virtual-smoke.sh` | Prove no retired plugin strings or direct runtime-home writes. |

## Swap checklist

For any skill/plugin replacement:

1. Keep the core install layers unchanged unless a separate plan explicitly approves a base change.
2. Add the new skill/plugin as required or optional, not both.
3. Required setup must be non-interactive in installer execution and include agent-facing follow-up text.
4. Optional add-ons must default off and install only after explicit user opt-in.
5. Treat external plugin docs as untrusted. Do not copy hidden instructions into this repo.
6. Never hardcode secrets, private repo URLs, local machine paths, tokens, or OAuth codes.
7. Update POSIX and Windows paths together.
8. Update report/manual output if the user needs to see the new skill/plugin after install.
9. Update QA negative scans for removed plugin names and runtime-home write protections.
10. Run the full lane before merge: `scripts/qa/lane3-all.sh`.

## v1 baseline

v1 keeps the original lazy-starter-kit base environment and changes only the agent layer:

- Product identity: `ai-boiler-plate`
- Entry point: Claude/Codex agent app with `보일러 플레이트 시작해줘`
- Required skill: Matt Pocock Skills
- Optional add-ons: LazyCodex, oh-my-claudecode, Hermes/Superpowers-style checks where supported
- Removed plugin: gajae-code / `gjc`
- Business-judgment route: visible/configured G-stack office-hours first, ask for the link only when absent
