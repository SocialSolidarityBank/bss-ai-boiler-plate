#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  printf 'Not a git checkout: %s\n' "$ROOT" >&2
  exit 1
fi

chmod +x "$ROOT/scripts/qa/goal-mode-gate.sh" "$ROOT/.githooks/pre-commit" "$ROOT/.githooks/pre-push"
git -C "$ROOT" config core.hooksPath .githooks

printf 'Goal Gate hooks installed.\n'
printf 'pre-commit: scripts/qa/goal-mode-gate.sh --quick\n'
printf 'pre-push:   scripts/qa/goal-mode-gate.sh --full\n'
