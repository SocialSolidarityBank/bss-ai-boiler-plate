#!/usr/bin/env bash

bss_show_status() {
  local state py
  state="$(bss_state_path)"

  if [[ ! -f "$state" ]]; then
    printf 'ai-boiler-plate 진행 상태\n'
    printf '진행 상태가 아직 없습니다.\n'
    printf '처음 시작하려면 이 저장소에서 Codex를 열고 `ai-boiler-plate 실행해줘`라고 말하세요.\n'
    return 0
  fi

  if ! py="$(_state_python)"; then
    warn "python3 or python is required to read the status file: ${state/#$HOME/~}"
    printf '상태 파일: %s\n' "$state"
    return 1
  fi

  PYTHONIOENCODING=UTF-8 "$py" - "$state" <<'PY'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
order = [
    ("base-tools", "기본 설치 준비"),
    ("shell", "터미널 편의 설정"),
    ("github", "GitHub 연결"),
    ("ai-tools", "AI 도구 선택"),
    ("addons", "추가 도구 추천"),
    ("report", "마무리 리포트"),
]
symbols = {
    "complete": "● 완료",
    "completed": "● 완료",
    "skipped": "△ 건너뜀",
    "failed": "× 실패",
    "in_progress": "◐ 진행 중",
    "running": "◐ 진행 중",
    "pending": "○ 대기",
}

try:
    data = json.loads(state_path.read_text(encoding="utf-8"))
except Exception as exc:
    print("ai-boiler-plate 진행 상태")
    print(f"상태 파일을 읽을 수 없습니다: {state_path}")
    print(f"원인: malformed state.json ({exc})")
    print("파일은 지우지 않았습니다. `--reset-state`를 선택하기 전까지 그대로 둡니다.")
    raise SystemExit(0)

steps = data.get("steps") or {}
progressed = 0
failed = []
rows = []
for key, fallback_label in order:
    raw = steps.get(key) or {}
    status = str(raw.get("status", "pending"))
    if status in {"complete", "completed", "skipped"}:
        progressed += 1
    if status == "failed":
        failed.append((raw.get("label") or fallback_label, raw.get("reason") or "원인 미기록"))
    rows.append((symbols.get(status, "○ 대기"), raw.get("label") or fallback_label, raw.get("reason") or ""))

print("ai-boiler-plate 진행 상태")
print(f"{progressed}/{len(order)} 진행됨")
for symbol, label, reason in rows:
    if reason:
        print(f"{symbol}  {label} - {reason}")
    else:
        print(f"{symbol}  {label}")
if failed:
    print("")
    print("다음 행동")
    for label, reason in failed:
        print(f"- {label}: {reason}")
print("")
print("다시 시작 문구: ai-boiler-plate 실행해줘")
PY
}

bss_reset_state() {
  local state
  state="$(bss_state_path)"
  if [[ ! -f "$state" ]]; then
    info "삭제할 진행 상태가 없습니다."
    return 0
  fi
  if [[ "${AI_BOILER_PLATE_FORCE_RESET:-${BSS_AI_HELPER_FORCE_RESET:-0}}" != "1" ]]; then
    if ! confirm "저장된 진행 상태를 삭제할까요? 작업 기록과 리포트/HTML은 남깁니다."; then
      info "진행 상태를 그대로 둡니다."
      return 0
    fi
  fi
  rm -f "$state"
  ok "진행 상태를 삭제했습니다. history.jsonl, latest-report.md, manual/index.html은 남겨 두었습니다."
}

show_status() { bss_show_status; }
