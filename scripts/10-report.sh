#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"
# shellcheck source=lib/report.sh
source "$ROOT/lib/report.sh"

step_report() {
  step "BSS AI Helper report"
  state_init
  bss_generate_report
  state_set_step_status report complete "latest-report.md generated"
}

main() {
  case "${1:-}" in
    --generate)
      state_init
      bss_generate_report
      ;;
    --open)
      bss_open_manual_if_confirmed
      ;;
    -h|--help)
      printf 'Usage: scripts/10-report.sh --generate|--open\n'
      ;;
    *)
      printf 'Usage: scripts/10-report.sh --generate|--open\n' >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
