#!/usr/bin/env bash

bss_helper_home() {
  printf '%s\n' "${BSS_AI_HELPER_HOME:-$HOME/.bss-ai-helper}"
}

bss_state_path() {
  printf '%s/state.json\n' "$(bss_helper_home)"
}

bss_history_path() {
  printf '%s/history.jsonl\n' "$(bss_helper_home)"
}

bss_report_path() {
  printf '%s/latest-report.md\n' "$(bss_helper_home)"
}

bss_manual_dir() {
  printf '%s/manual\n' "$(bss_helper_home)"
}

bss_manual_path() {
  printf '%s/index.html\n' "$(bss_manual_dir)"
}

bss_ensure_home() {
  mkdir -p "$(bss_helper_home)" "$(bss_manual_dir)"
}

helper_home() { bss_helper_home; }
state_path() { bss_state_path; }
history_path() { bss_history_path; }
report_path() { bss_report_path; }
manual_path() { bss_manual_path; }
