#!/usr/bin/env bash

bss_helper_home() {
  if [[ -n "${AI_BOILER_PLATE_HOME:-}" ]]; then
    printf '%s\n' "$AI_BOILER_PLATE_HOME"
  elif [[ -n "${BSS_AI_HELPER_HOME:-}" ]]; then
    printf '%s\n' "$BSS_AI_HELPER_HOME"
  elif [[ -d "$HOME/.bss-ai-helper" && ! -e "$HOME/.ai-boiler-plate" ]]; then
    printf '%s\n' "$HOME/.bss-ai-helper"
  else
    printf '%s\n' "$HOME/.ai-boiler-plate"
  fi
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
ai_boiler_plate_home() { bss_helper_home; }
state_path() { bss_state_path; }
history_path() { bss_history_path; }
report_path() { bss_report_path; }
manual_path() { bss_manual_path; }
