<div align="center">

### One command turns a fresh Windows PC into a complete dev environment.

_winget packages · runtimes · PowerShell profile · containers · and AI coding agents — installed and verified._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Linux kit](../linux/README.md)

</div>

---

## ai-boiler-plate로 시작하기

> 출처: 이 키트는 [`foxion37/lazy-starter-kit`](https://github.com/foxion37/lazy-starter-kit)을 포크해 시작했고, ai-boiler-plate용 질문형 설치 보일러플레이트로 다시 설계했습니다.

처음에는 PowerShell보다 Claude/Codex 스타일 코딩 에이전트 앱에서 시작합니다.

1. Claude, Codex, Cursor 같은 코딩 에이전트 앱을 엽니다.
2. 이 저장소 링크 `https://github.com/socialsolidaritybank/ai-boiler-plate`를 전달합니다.
3. `보일러 플레이트 시작해줘`라고 말합니다.

에이전트는 상태를 먼저 확인하고, 설치 방법만 안내하고 끝내지 않고, 승인하면 직접 설치를 시도합니다. 권한이 막히면 필요한 권한 설정 방법을 알려주고 다시 진행할 수 있습니다.

팀에서 같은 결과를 맞춰야 하는 초보자 설치는 [팀 초보자 표준 설치](../docs/team-beginner-standard-install.md)를 먼저 따르세요.
에이전트는 Plan Mode(계획 모드)에서 질문을 모두 마치고 Final Installation Plan(최종 설치 계획)을 발행한 뒤에만 실행합니다.
표준 프리셋은 승인된 계획을 실행할 때 쓰는 `-Standard`입니다.

PowerShell 명령은 fallback, 고급 사용자, QA 확인용입니다. 개발자와 CI는 `-Status`, `-DryRun`, `-List`를 계속 사용할 수 있습니다.

> **🇰🇷 한국어 fallback** — 코딩 에이전트 앱을 쓸 수 없을 때만 PowerShell에서 아래 한 줄을 붙여넣고 Enter:
> ```powershell
> irm https://raw.githubusercontent.com/socialsolidaritybank/ai-boiler-plate/main/windows/install.ps1 | iex
> ```
> 끝나면 PowerShell을 새로 여세요. 막히면 앞에 `powershell -ExecutionPolicy Bypass -Command "..."`로 감싸 실행. (한국어 전체 안내: [저장소 메인 README](../README.md#-windows-설치-제일-자세히))

## Terminal fallback / QA

Open **PowerShell** (Windows PowerShell 5.1 or PowerShell 7) only when you need a manual fallback or QA run:

```powershell
irm https://raw.githubusercontent.com/socialsolidaritybank/ai-boiler-plate/main/windows/install.ps1 | iex
```

Prefer to read before you run (recommended):

```powershell
git clone https://github.com/socialsolidaritybank/ai-boiler-plate.git
cd ~/ai-boiler-plate/windows
.\install.ps1 -DryRun     # see exactly what it would do
.\install.ps1             # apply
```

> If scripts are blocked, the installer sets `RemoteSigned` for the current user
> itself. To run the local copy before that, start it with:
> `powershell -ExecutionPolicy Bypass -File .\install.ps1`

**Requirements**: Windows 10 (1809+) or Windows 11 with **winget** (App Installer).
If `winget` is missing, install *App Installer* from the Microsoft Store first.

## What you get

| Layer | Tools |
|---|---|
| **Base** | winget (App Installer), TLS 1.2, `RemoteSigned` execution policy (CurrentUser) |
| **CLI** | git, gh, jq, ripgrep, fd, bat, fzf (`tree`/`curl` are built into Windows) |
| **Shell** | PowerShell profile with **starship** prompt · **PSReadLine 2.2+** inline autosuggestions + list predictions (the `zsh-autosuggestions` equivalent) · **CompletionPredictor** (command-based predictions) · Tab completion menu + history-substring search on ↑/↓ · **PSFzf** (Ctrl-T/Ctrl-R) · JetBrainsMono Nerd Font |
| **Runtimes** | **mise** → node (LTS), python, go, **ast-grep** · **rustup** → rust + rust-analyzer · **uv** · **bun** |
| **Containers** | **Docker Desktop** (optional; needs WSL2/virtualization) |
| **Git/GitHub** | identity (GitHub noreply email), HTTPS credential helper, `core.autocrlf`, sane defaults |
| **AI agents** | **Claude Code** (`claude`), **codex**, optional Matt Pocock Skills, optional **lazycodex** (OmO), optional Superpowers Planning Pack (`brainstorming` + `writing-plans`). Hermes Agent runs inside WSL2. |

## Steps & flags

Steps run in this order:

```
prereqs  packages  runtimes  shell  docker  git  agents  resume
```

```powershell
.\install.ps1 -Status               # show saved helper progress
.\install.ps1 -DryRun               # change nothing, just print
.\install.ps1 -Yes                  # non-interactive, accept defaults
.\install.ps1 -Only packages,shell  # run a subset
.\install.ps1 -Skip agents          # run all but one
.\install.ps1 -NoAgents             # alias for -Skip agents
.\install.ps1 -List                 # print step ids
.\install.ps1 -Version              # print the kit version
```

Every step is **idempotent** — safe to re-run. Your PowerShell profile
(`$PROFILE.CurrentUserAllHosts`) is edited via a clearly marked managed block
(`# >>> ai-boiler-plate:main >>>`) that gets replaced (never duplicated) on
re-runs. Existing files you own are preserved.

## Design notes

- **winget-first.** Plain tools come from winget; the runtimes are managed by
  **mise** (node/python/go/ast-grep) and **rustup** (rust) so versions are easy
  to switch. `ast-grep` is installed via mise's `ubi` backend to match the
  macOS/Linux kits.
- **No admin required** for the default flow — everything installs per-user.
  Docker Desktop is the exception (needs virtualization + a reboot) and is
  strictly opt-in: it defaults to **No**, is **never** installed under `-Yes` or
  non-interactively (licensing), and must be confirmed with an explicit `y` in an
  interactive run (e.g. `.\install.ps1 -Only docker`).
- **PATH refresh.** winget puts new tools on the persistent PATH; the installer
  re-reads the environment mid-run so later steps see them without a restart.
  Still, **open a new PowerShell window** afterwards to load the profile.
- **Runtimes shadow, never replace.** node/python/go from another source
  (system MSI, nvm-windows, scoop) are left alone; mise's win on PATH. Verify
  with `Get-Command node -All`.
- **Hermes Agent** has no native Windows build — install it inside a WSL2 distro:
  `wsl bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup'`
- **Superpowers Planning Pack** is optional and installs only when selected:
  `npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/brainstorming`
  then
  `npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/writing-plans`.

## Uninstall

```powershell
.\uninstall.ps1 -DryRun     # preview the teardown
.\uninstall.ps1             # run it (destructive groups are confirm-gated)
.\uninstall.ps1 -Yes        # non-interactive, accept every removal
.\uninstall.ps1 -Only agents
```

Groups (reverse order): `agents shell docker runtimes packages`.

Safe by design:
- **Never auto-removed**: your **git identity**, `git` itself, and the Nerd Font.
- Runtime/auth roots such as `~/.codex`, `~/.claude`, and token files are always
  preserved. `-KeepCodexHome` is kept only as a deprecated no-op.
- Only the kit's own managed block is stripped from your PowerShell profile.

## Troubleshooting

- **`winget` not recognized** — install *App Installer* from the Microsoft Store
  ([link](https://apps.microsoft.com/detail/9nblggh4nns1)), then reopen PowerShell.
- **"running scripts is disabled on this system"** — run the local copy with
  `powershell -ExecutionPolicy Bypass -File .\install.ps1` (the installer then sets
  `RemoteSigned` for your user so it won't recur).
- **Autosuggestions don't appear** — you're likely on Windows PowerShell 5.1 with
  the old PSReadLine still loaded. Restart PowerShell once, or use **PowerShell 7**
  (`winget install Microsoft.PowerShell`) + **Windows Terminal**.
- **Behind a corporate proxy** — set `$env:HTTP_PROXY`/`$env:HTTPS_PROXY` before
  running; winget honors them. Some networks block winget's CDN — then install the
  few tools from your internal software portal instead.
- **Docker** — Docker Desktop is paid for larger orgs; prefer Docker/Podman inside
  WSL2 (see the Containers row). `wsl --install` needs virtualization enabled in BIOS.
- **Re-run anytime** — every step is idempotent; safe to run again after fixing a
  blocker (or use `-Only <step>` to redo just one).

## License

MIT — see [../LICENSE](../LICENSE).
