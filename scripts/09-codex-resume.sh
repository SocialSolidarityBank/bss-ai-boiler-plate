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

Creates the BSS AI Helper restart surface under BSS_AI_HELPER_HOME.
USAGE
}

write_codex_restart_surface() {
  local helper_home bin wrapper codex_md repo_root installer_rel
  helper_home="$(bss_helper_home)"
  bin="$helper_home/bin"
  wrapper="$bin/bss-ai-helper"
  codex_md="$helper_home/CODEX.md"
  repo_root="$ROOT"
  installer_rel="${BSS_AI_HELPER_INSTALLER_RELATIVE:-install.sh}"
  mkdir -p "$bin"

  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
repo="\${BSS_AI_HELPER_REPO:-$repo_root}"
installer_rel="\${BSS_AI_HELPER_INSTALLER_RELATIVE:-$installer_rel}"
installer="\$repo/\$installer_rel"
if [[ ! -f "\$installer" ]]; then
  echo "BSS AI Helper installer not found: \$installer" >&2
  exit 1
fi
if [[ "\$#" -eq 0 ]]; then
  set -- --status
fi
exec bash "\$installer" "\$@"
EOF
  chmod +x "$wrapper"

  cat > "$codex_md" <<'EOF'
# BSS AI Helper 다시 시작하기

Codex에서 아래 문구 중 하나를 말하면 됩니다.

- `BSS AI Helper 실행해줘`
- `AI 세팅 이어서 해줘`
- `개발환경 설치 도와줘`

Codex는 먼저 `이어서 진행`, `상태만 확인`, `설명만 보기` 중 하나를 확인해야 합니다.
비밀번호, 토큰, OAuth 코드는 저장하지 않습니다.

터미널에서는 다음 명령을 사용할 수 있습니다.

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

```sh
skill-add resources/codex-skill/bss-ai-helper --mine
```
EOF
  printf 'codex-skill=skipped\n' > "$(bss_helper_home)/codex-skill.status"
}

step_resume() {
  step "BSS AI Helper restart surface"
  bss_ensure_home
  state_init
  write_codex_restart_surface
  install_codex_skill
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    state_set_step_status resume complete "restart surface ready"
  else
    warn "python not found; restart surface was created but resume state was not updated."
  fi
  ok "BSS AI Helper Codex restart surface ready: $(bss_helper_home)"
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
