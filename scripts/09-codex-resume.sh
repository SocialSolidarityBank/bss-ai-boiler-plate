#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"
# shellcheck source=lib/state.sh
source "$ROOT/lib/state.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/09-codex-resume.sh --install

Creates the ai-boiler-plate restart surface under AI_BOILER_PLATE_HOME.
Deprecated BSS_AI_HELPER_HOME is still read for existing installs.
USAGE
}

write_codex_restart_surface() {
  local helper_home bin wrapper codex_md repo_root
  helper_home="$(bss_helper_home)"
  bin="$helper_home/bin"
  wrapper="$bin/ai-boiler-plate"
  codex_md="$helper_home/CODEX.md"
  repo_root="$ROOT"
  mkdir -p "$bin"

  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
repo="\${AI_BOILER_PLATE_DIR:-\${BSS_BOILERPLATE_DIR:-\${STARTER_KIT_DIR:-$repo_root}}}"
case "\$repo" in
  http://*|https://*|git@*) repo="$repo_root" ;;
esac
if [[ ! -x "\$repo/install.sh" && -x "$repo_root/install.sh" ]]; then
  repo="$repo_root"
fi
if [[ ! -x "\$repo/install.sh" ]]; then
  echo "ai-boiler-plate repo not found: \$repo" >&2
  exit 1
fi
if [[ "\$#" -eq 0 ]]; then
  set -- --status
fi
exec "\$repo/install.sh" "\$@"
EOF
  chmod +x "$wrapper"
  for legacy in bss-ai-helper ai-helper bss-ai; do
    ln -sf "ai-boiler-plate" "$bin/$legacy" 2>/dev/null || cp "$wrapper" "$bin/$legacy"
  done

  cat > "$codex_md" <<'EOF'
# ai-boiler-plate 다시 시작하기

Codex에서 아래 문구 중 하나를 말하면 됩니다.

- `ai-boiler-plate 실행해줘`
- `AI 세팅 이어서 해줘`
- `개발환경 설치 도와줘`

Codex는 먼저 `이어서 진행`, `상태만 확인`, `설명만 보기` 중 하나를 확인해야 합니다.
비밀번호, 토큰, OAuth 코드는 저장하지 않습니다.

터미널에서는 다음 명령을 사용할 수 있습니다.

## Matt Pocock Skills (required)

Run the upstream installer command:

```sh
npx skills@latest add mattpocock/skills
```

Then ask the AI agent to finish setup:

```text
/setup-matt-pocock-skills
```

```sh
ai-boiler-plate --status
```

Deprecated compatibility commands for existing installs:

```sh
bss-ai-helper --status
ai-helper --status
bss-ai --status
```
EOF
}

install_codex_skill() {
  local src fallback
  src="$ROOT/resources/codex-skill/bss-ai-helper"
  fallback="$(bss_helper_home)/skill-install-fallback.md"

  if command -v skill-add >/dev/null 2>&1; then
    skill-add "$src" --mine
    printf 'codex-skill=complete\n' > "$(bss_helper_home)/codex-skill.status"
    return 0
  fi

  cat > "$fallback" <<'EOF'
# Codex 스킬 설치 보류

`skill-add` 명령을 찾지 못해 전역 Codex 스킬 설치는 보류했습니다.
런타임 스킬 폴더(`~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills`)에는 직접 쓰지 않았습니다.

나중에 `skill-add`가 준비되면 아래 명령으로 SSOT에 설치하세요.

Deprecated resource path retained until the skill directory is renamed:

```sh
skill-add resources/codex-skill/bss-ai-helper --mine
```

Matt Pocock Skills are required guided setup. Use the upstream installer command, then ask the AI agent to finish setup:

```sh
npx skills@latest add mattpocock/skills
```

```text
/setup-matt-pocock-skills
```
EOF
  printf 'codex-skill=skipped\n' > "$(bss_helper_home)/codex-skill.status"
}

main() {
  case "${1:-}" in
    --install)
      step_resume
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

step_resume() {
  bss_ensure_home
  write_codex_restart_surface
  install_codex_skill
  ok "ai-boiler-plate Codex restart surface ready: $(bss_helper_home)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
