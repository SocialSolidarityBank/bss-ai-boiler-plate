<div align="center">

### One command turns a fresh Linux box into a complete dev environment.

_Build tools · CLI · runtimes · shell · containers · and AI coding agents — installed and verified._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Windows kit](../windows/README.md)

</div>

---

## ai-boiler-plate로 시작하기

> 출처: 이 키트는 [`foxion37/lazy-starter-kit`](https://github.com/foxion37/lazy-starter-kit)을 포크해 시작했고, ai-boiler-plate용 질문형 설치 보일러플레이트로 다시 설계했습니다.

처음에는 터미널보다 Claude/Codex 스타일 코딩 에이전트 앱에서 시작합니다.

1. Claude, Codex, Cursor 같은 코딩 에이전트 앱을 엽니다.
2. 이 저장소 링크 `https://github.com/socialsolidaritybank/ai-boiler-plate`를 전달합니다.
3. `보일러 플레이트 시작해줘`라고 말합니다.

에이전트는 상태를 먼저 확인하고, 설치 방법만 안내하고 끝내지 않고, 승인하면 직접 설치를 시도합니다. 권한이 막히면 필요한 권한 설정 방법을 알려주고 다시 진행할 수 있습니다.

터미널 명령은 fallback, 고급 사용자, QA 확인용입니다. 개발자와 CI는 `--classic`, `--status`, `--dry-run`, `--list`를 계속 사용할 수 있습니다.

> **🇰🇷 한국어 fallback** — 코딩 에이전트 앱을 쓸 수 없을 때만 터미널에서 아래 한 줄을 붙여넣고 Enter:
> ```sh
> curl -fsSL https://raw.githubusercontent.com/socialsolidaritybank/ai-boiler-plate/main/linux/install.sh | bash
> ```
> apt·dnf·pacman·zypper를 자동 감지합니다 (glibc 배포판; Alpine/musl 미지원). (한국어 전체 안내: [저장소 메인 README](../README.md#-linux-설치))

## Terminal fallback / QA

```sh
curl -fsSL https://raw.githubusercontent.com/socialsolidaritybank/ai-boiler-plate/main/linux/install.sh | bash
```

Prefer to read before you run (recommended):

```sh
git clone https://github.com/socialsolidaritybank/ai-boiler-plate.git
cd ~/ai-boiler-plate/linux
./install.sh --dry-run     # see exactly what it would do
./install.sh               # apply
```

**Supported distros** (auto-detected package manager): Debian/Ubuntu (`apt`),
Fedora/RHEL (`dnf`/`yum`), Arch (`pacman`), openSUSE (`zypper`) — all **glibc**.
Alpine/musl (`apk`) is **not supported** (upstream node, ast-grep and bun ship
no musl builds). Ubuntu, Fedora, openSUSE and Arch are all verified
end-to-end (install → verify → uninstall) in CI on every change.

## What you get

| Layer | Tools |
|---|---|
| **Base** | compiler/build tools, `git`, `curl`, `wget`, `unzip`, `zsh` (via your distro's package manager) |
| **CLI** | ripgrep, fd, bat, fzf, jq, tree, **gh** (GitHub CLI) |
| **Shell** | zsh + oh-my-zsh (plugins: git, npm, node, autosuggestions, syntax-highlighting), **starship** prompt |
| **Runtimes** | **mise** → node (LTS), python, go, **ast-grep** · **rustup** → rust + rust-analyzer · **uv** · **bun** |
| **Containers** | **Docker Engine** + compose/buildx (official `get.docker.com`, opt-in) |
| **Git/GitHub** | identity (GitHub noreply email), HTTPS credential helper, sane defaults |
| **AI agents** | **Claude Code** (`claude`), **codex**, required Matt Pocock Skills, optional **lazycodex** (OmO), **Hermes Agent** (`hermes`, Nous Research) |

## Steps & flags

Steps run in this order:

```
prereqs  packages  runtimes  shell  docker  git  agents
```

```sh
./install.sh --status              # show saved helper progress
./install.sh --classic --dry-run   # run the classic installer preview
./install.sh --dry-run             # change nothing, just print
./install.sh --yes                 # non-interactive, accept defaults
./install.sh --only packages,shell # run a subset
./install.sh --skip agents         # run all but one
./install.sh --no-agents           # alias for --skip agents
./install.sh --list                # print step ids
```

Every step is **idempotent** — safe to re-run. `~/.zshrc` is edited via clearly
marked managed blocks (`# >>> ai-boiler-plate:* >>>`) that get replaced (never
duplicated) on re-runs. Existing files you own are preserved.

## Design notes

- **No Homebrew.** Plain CLI utilities come from your distro's package manager;
  the "moving target" developer tools (mise, starship, uv, bun, rustup) are
  installed from their **official user-space installers** into `$HOME`, so the
  kit works the same across every distro and needs **no root** for them.
- **sudo** is only used for system packages (`prereqs`, CLI utilities, Docker).
  On a rootless box without `sudo`, those installs are skipped with a warning;
  the user-space tools still install fine.
- **Debian/Ubuntu quirks**: `fd`/`bat` ship as `fdfind`/`batcat` — the shell
  block aliases them back to `fd`/`bat` automatically.
- **Runtimes shadow, never replace.** node/python/go from another source (system
  package, `nvm`, `asdf`) are left alone; mise installs its own and wins on PATH.
  Verify with `which -a node`.
- **Docker** is opt-in (confirm-gated): the official `get.docker.com` script
  installs docker-ce + compose + buildx and adds you to the `docker` group
  (effective after re-login).

## Uninstall

```sh
./uninstall.sh --dry-run     # preview the teardown
./uninstall.sh               # run it (destructive groups are confirm-gated)
./uninstall.sh --yes         # non-interactive, accept every removal
./uninstall.sh --only agents # remove just one group
```

Groups (reverse order): `agents shell docker runtimes packages`.

Safe by design:
- **Never auto-removed**: your **git identity**, and the compiler/build tools.
- Runtime/auth roots such as `~/.codex`, `~/.claude`, and token files are always
  preserved. `--keep-codex-home` is kept only as a deprecated no-op.
- Only the kit's own managed blocks are stripped from `~/.zshrc`.

## Troubleshooting

- **No `sudo` / not root** — system packages (build tools, CLI utils, Docker) are
  skipped with a warning, but the per-user tools (mise, starship, uv, bun, rustup)
  still install fine into `$HOME`.
- **`fd` / `bat` "command not found"** — on Debian/Ubuntu they're `fdfind`/`batcat`;
  the shell block aliases them back once you open a new shell.
- **Python install slow or failing** — the kit forces mise's **precompiled** Python
  (`MISE_PYTHON_COMPILE=0`), so no source build. If your CPU/arch has no prebuilt
  release, install dev headers (`build-essential libssl-dev zlib1g-dev libffi-dev`)
  and re-run `--only runtimes`.
- **`docker: permission denied`** — log out/in (or `newgrp docker`) so your new
  `docker` group membership applies.
- **`gh` not found** — a few distros lack it in default repos; the kit adds GitHub's
  apt repo on Debian/Ubuntu. Elsewhere install your distro's `gh`/`github-cli`.
- **Re-run anytime** — every step is idempotent (use `--only <step>` to redo one).

## License

MIT — see [../LICENSE](../LICENSE).
