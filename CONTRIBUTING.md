# Contributing

Thanks for your interest! This kit has a deliberately tight scope. Reading this
first saves everyone time.

## Scope: platform base vs. optional

The kit is split into two tiers, and **where a tool goes is the first question
for any addition**:

- **Base** — the default platform installs:
  `install.sh` for macOS, `linux/install.sh` for Linux, and
  `windows/install.ps1` for Windows. This is the **current, frozen, lean set**:
  prerequisites, core dev CLI, runtimes (mise/rustup), shell/profile, optional
  containers, Git/GitHub, and AI coding agents. The base stays focused on
  **"a fresh supported OS → a working dev environment."** It should grow slowly
  and only for tools nearly everyone setting up that platform needs.

- **Optional** — opt-in extras in [`Brewfile.optional`](./Brewfile.optional),
  installed only on purpose (`brew bundle --file Brewfile.optional`). **New
  additions that aren't core dev tooling go here**. For Linux and Windows, put
  organization-specific additions in `linux/config/bss-packages.sh` or
  `windows/config/bss-packages.ps1`. This keeps the base from drifting into a
  "recommended apps" dump.

Rule of thumb:

| Is it... | Goes in |
|---|---|
| A tool ~every supported platform needs (compiler, runtime, shell/profile, VCS, agent) | **Base** |
| A nice-to-have / GUI / daily-use / opinionated pick | **Optional** |

PRs that add non-core tools to the base will be asked to move them to
`Brewfile.optional`.

## Ground rules for changes

- **bash 3.2 compatible for shared/macOS shell code** — macOS ships bash 3.2; no
  associative arrays, `mapfile`, `${x,,}`, etc. (`bash -n` must pass under
  `/bin/bash`). Linux-only scripts may use Linux bash features only when tests
  cover the path.
- **Idempotent & non-destructive** — re-running must be safe; never clobber a
  user's existing config. Use the current `bss-ai-boilerplate:*` managed-block
  markers for compatibility; do not rename installed markers just for product
  naming cleanup.
- **shellcheck clean** — `shellcheck -x -S warning -e SC2154 install.sh uninstall.sh lib/common.sh scripts/*.sh` and the matching Linux command for `linux/*.sh`.
- **Shared helpers live in `lib/common.sh`** — the OS-agnostic bash helpers
  (colors, `run`, `ask`/`confirm`, `inject_block`, …) are shared by the macOS
  (`scripts/lib.sh`) and Linux (`linux/scripts/lib.sh`) kits, which source it and
  add only their OS-specific bits. Fix shared behavior in `lib/common.sh` so it
  can't land in only one tree.
- **Preview first** — verify with the matching platform dry run:
  `./install.sh --dry-run`, `./linux/install.sh --dry-run`, or
  `.\windows\install.ps1 -DryRun`.
- **CI must pass** — lint plus the platform contract tests and install lanes.
- **Versioning** — user-visible changes bump [`VERSION`](./VERSION) and get a
  note in [`CHANGELOG.md`](./CHANGELOG.md) (SemVer).

## Proposing an addition

Open an issue describing the tool, why it belongs in **base** vs **optional**,
and its license (prefer free/open-source). Small, well-scoped PRs welcome.
