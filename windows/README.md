<div align="center">

### One command turns a fresh Windows PC into a complete dev environment.

_winget packages · runtimes · PowerShell profile · containers · and AI coding agents — installed and verified._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Linux kit](../linux/README.md)

</div>

---

## BSS AI Helper로 시작하기

> 이 문서는 Windows에서 BSS AI Helper가 어떻게 설치되는지 설명합니다. 원본 출처와 보관된 upstream README는 [`../NOTICE`](../NOTICE)와 저장소 루트의 upstream README 스냅샷에서 확인할 수 있습니다.

먼저 GitHub 저장소를 내려받고, 그 폴더에서 Codex를 실행합니다.

```powershell
git clone https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git ~/bss-ai-boiler-plate
cd ~/bss-ai-boiler-plate
codex
```

Codex가 열리면 `BSS AI Helper 실행해줘`라고 말합니다. Codex는 설치 방법만 안내하고 끝내지 않습니다. 사용자가 승인하면 직접 설치를 진행하고, 권한 문제로 막히면 어떤 설정이 필요한지 알려준 뒤 다시 진행합니다.

설치가 끝나면 터미널에서 `bss-ai-helper`, `ai-helper`, `bss-ai`를 사용할 수 있습니다. 개발자와 CI는 `-Status`, `-Classic`, `-DryRun`, `-List`를 계속 사용할 수 있습니다.

> **한국어 빠른 시작** — 시작 버튼에서 `PowerShell`을 찾아 열고, 아래 한 줄을 붙여넣은 뒤 Enter를 누르세요.
> ```powershell
> irm https://raw.githubusercontent.com/socialsolidaritybank/bss-ai-boiler-plate/main/windows/install.ps1 | iex
> ```
> 끝나면 PowerShell을 새로 여세요. 실행이 막히면 앞에 `powershell -ExecutionPolicy Bypass -Command "..."`로 감싸 실행하면 됩니다. 한국어 전체 안내는 [저장소 메인 README](../README.md#처음-쓰는-분을-위한-안내)를 참고하세요.

## Quick start

Open **PowerShell** (Windows PowerShell 5.1 or PowerShell 7) and run:

```powershell
irm https://raw.githubusercontent.com/socialsolidaritybank/bss-ai-boiler-plate/main/windows/install.ps1 | iex
```

Prefer to read before you run (recommended):

```powershell
git clone https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git
cd ~/bss-ai-boiler-plate/windows
.\install.ps1 -DryRun     # see exactly what it would do
.\install.ps1             # apply
```

In an interactive console, the installer opens the question wizard unless you
choose a direct mode such as `-Classic`, `-Yes`, `-Only`, or `-Skip`. If input is
redirected and `-Wizard` is not requested, it prints a warning and runs the
classic step installer instead of silently choosing answers.

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
| **AI agents** | **Claude Code** (`claude`), **gajae-code** (`gjc`), **codex**, **lazycodex** (OmO). Hermes Agent runs inside WSL2. |

## Steps & flags

Steps run in this order:

```
prereqs  packages  runtimes  shell  docker  git  agents  resume  report
```

```powershell
.\install.ps1 -Status               # show saved helper progress
.\install.ps1 -Classic              # run the classic step installer
.\install.ps1 -Wizard               # run the question wizard when input is available
.\install.ps1 -DryRun               # change nothing, just print
.\install.ps1 -Yes                  # non-interactive, accept defaults
.\install.ps1 -Only packages,shell  # run a subset
.\install.ps1 -Skip agents          # run all but one
.\install.ps1 -NoAgents             # alias for -Skip agents
.\install.ps1 -List                 # print step ids
.\install.ps1 -Version              # print the kit version
```

`resume` installs the `bss-ai-helper` command you can use to continue later.
`report` writes the latest helper report and manual files. They appear in
`-List` and normal step selection, but `-Status` remains read-only.

Every step is **idempotent** — safe to re-run. Your PowerShell profile
(`$PROFILE.CurrentUserAllHosts`) is edited only inside a clearly marked managed
block (`# >>> bss-ai-boilerplate:main >>>`). On re-runs, that block is replaced,
not duplicated. Existing files you own are preserved.

`bss-ai-boilerplate:*` is the current internal marker for compatibility with
installed profiles. The product name is BSS AI Helper, but this installer does
not rename existing profile blocks just for naming cleanup.

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
- **gajae-code (`gjc`) is kept** unless you pass `-WithGajae` (refused while running).
- Removing codex backs up `~/.codex/auth.json` first; `-KeepCodexHome` leaves it intact.
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
