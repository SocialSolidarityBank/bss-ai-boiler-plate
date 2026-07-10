#!/usr/bin/env bash

_STATE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$_STATE_LIB_DIR/state-paths.sh"
source "$_STATE_LIB_DIR/state-status.sh"

_state_python() {
  if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    printf 'python3\n'
  elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
    printf 'python\n'
  else
    return 1
  fi
}

state_validate() {
  local path="${1:-$(state_path)}" py
  [[ -f "$path" ]] || return 2
  py="$(_state_python)" || return 0
  "$py" - "$path" <<'PY' >/dev/null 2>&1
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, dict):
    raise SystemExit(1)
PY
}

state_init() {
  local path py
  bss_ensure_home
  path="$(state_path)"
  if [[ ! -f "$path" ]]; then
    printf '{"version":1,"steps":{},"ai_services":[],"aiServices":[],"addons":{},"tools":[]}\n' > "$path"
    return 0
  fi
  state_validate "$path" || return 1
  py="$(_state_python)" || return 0
  "$py" - "$path" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
changed = False
for key, default in [
    ("version", 1),
    ("steps", {}),
    ("ai_services", []),
    ("aiServices", []),
    ("addons", {}),
    ("tools", []),
    ("installationPlan", {}),
]:
    if key not in data:
        data[key] = default
        changed = True
if changed:
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)
PY
}

_state_update() {
  local action="$1" path py
  shift
  state_init
  path="$(state_path)"
  py="$(_state_python)" || die "python is required to update ${path/#$HOME/~}"
  "$py" - "$path" "$action" "$@" <<'PY'
import json
import os
import sys
import time

path, action, args = sys.argv[1], sys.argv[2], sys.argv[3:]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

data.setdefault("version", 1)
data.setdefault("steps", {})
data.setdefault("ai_services", [])
data.setdefault("aiServices", data.get("ai_services") or [])
data.setdefault("addons", {})
data.setdefault("tools", [])
data.setdefault("installationPlan", {})
data["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

labels = {
    "base-tools": "기본 설치 준비",
    "shell": "터미널 편의 설정",
    "github": "GitHub 연결",
    "ai-tools": "AI 도구 선택",
    "addons": "추가 도구 추천",
    "report": "마무리 리포트",
}

def upsert_tool(name, status, kind, reason="", next_action=""):
    tools = data.setdefault("tools", [])
    for tool in tools:
        if tool.get("name") == name:
            tool.update({"status": status, "kind": kind})
            if reason:
                tool["reason"] = reason
            if next_action:
                tool["nextAction"] = next_action
            return
    row = {"name": name, "status": status, "kind": kind}
    if reason:
        row["reason"] = reason
    if next_action:
        row["nextAction"] = next_action
    tools.append(row)

if action == "step":
    step, status = args[0], args[1]
    note = args[2] if len(args) > 2 else ""
    data["steps"][step] = {
        "status": status,
        "label": labels.get(step, step),
        "note": note,
        "reason": note,
    }
elif action == "ai_services":
    services = [x for x in args if x]
    data["ai_services"] = services
    data["aiServices"] = services
    for service in services:
        if service in ("Codex", "Codex CLI"):
            upsert_tool("Codex CLI", "complete", "ai")
        elif service in ("Claude", "Claude Code CLI"):
            upsert_tool("Claude Code", "complete", "ai")
        else:
            upsert_tool(service, "recorded", "ai", "자동 설치 없음")
elif action == "ai_service_status":
    status = args[0]
    note = args[1] if len(args) > 1 else ""
    services = [x for x in args[2:] if x]
    for service in services:
        if service in ("Codex", "Codex CLI"):
            upsert_tool("Codex CLI", status, "ai", note)
        elif service in ("Claude", "Claude Code CLI"):
            upsert_tool("Claude Code", status, "ai", note)
        else:
            upsert_tool(service, status, "ai", note)
elif action == "addon":
    addon_id, title, status = args[0], args[1], args[2]
    note = args[3] if len(args) > 3 else ""
    row = data["addons"].setdefault(addon_id, {})
    row.update({"title": title, "status": status, "seen": True})
    if note:
        row["note"] = note
    upsert_tool(title, status, "addon", note)
elif action == "installation_plan":
    selected_os, workspace, base_environment, ai_csv, addon_csv, command = args[:6]
    ai_tools = [x for x in ai_csv.split(",") if x]
    selected_addons = set(x for x in addon_csv.split(",") if x)
    addon_rows = {}
    addon_titles = {
        "matt-pocock-skills": "Matt Pocock Skills",
        "superpowers": "Superpowers Planning Pack",
        "lazy-codex": "Lazy-Codex",
        "oh-my-claudecode": "oh-my-claudecode",
    }
    for addon_id, title in addon_titles.items():
        addon_rows[addon_id] = {
            "title": title,
            "selected": addon_id in selected_addons,
            "decision": "install" if addon_id in selected_addons else "skip",
        }
    data["installationPlan"] = {
        "schemaVersion": 1,
        "selectedOS": selected_os,
        "workspaceFolder": workspace,
        "baseEnvironment": base_environment,
        "aiCliTools": ai_tools,
        "addons": addon_rows,
        "executionCommand": command,
        "approvalStatus": "pending",
        "approvedAt": "",
        "secretPolicy": "No tokens, OAuth codes, passwords, private keys, or device codes are stored.",
    }
elif action == "installation_plan_approve":
    plan = data.setdefault("installationPlan", {})
    if not plan:
        raise SystemExit("installation plan is missing")
    plan["approvalStatus"] = "approved"
    plan["approvedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
elif action == "clear":
    data = {
        "version": 1,
        "steps": {},
        "ai_services": [],
        "aiServices": [],
        "addons": {},
        "tools": [],
        "installationPlan": {},
        "updated_at": data["updated_at"],
    }
else:
    raise SystemExit(f"unknown state action: {action}")

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
}

state_get() {
  local key="$1" path
  path="$(state_path)"
  case "$key" in
    helper_home) helper_home ;;
    state_path) state_path ;;
    history_path) history_path ;;
    report_path) report_path ;;
    manual_path) manual_path ;;
    steps.*|step:*)
      local step_id="${key#steps.}"
      step_id="${step_id#step:}"
      if [[ -f "$path" ]] && command -v python3 >/dev/null 2>&1; then
        python3 - "$path" "$step_id" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("pending")
    raise SystemExit(0)
step = data.get("steps", {}).get(sys.argv[2], {})
print(step.get("status", "pending") if isinstance(step, dict) else str(step or "pending"))
PY
      else
        printf 'pending\n'
      fi
      ;;
    *) return 1 ;;
  esac
}

state_set_step_status() {
  _state_update step "$1" "$2" "${3:-}"
}

state_record_ai_services() {
  _state_update ai_services "$@"
}

state_set_ai_services_status() {
  _state_update ai_service_status "$@"
}

state_record_ai_service() {
  state_record_ai_services "$@"
}

state_record_addon() {
  _state_update addon "$1" "$2" "$3" "${4:-}"
}

state_record_installation_plan() {
  _state_update installation_plan "$1" "$2" "$3" "$4" "$5" "$6"
}

state_approve_installation_plan() {
  _state_update installation_plan_approve
}

state_installation_plan_status() {
  local path py
  path="$(state_path)"
  py="$(_state_python)" || { printf 'missing\n'; return 0; }
  "$py" - "$path" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("missing")
    raise SystemExit(0)
plan = data.get("installationPlan") or {}
print(plan.get("approvalStatus") or "missing")
PY
}

state_installation_plan_field() {
  local field="$1" path py
  path="$(state_path)"
  py="$(_state_python)" || return 1
  "$py" - "$path" "$field" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
plan = data.get("installationPlan") or {}
value = plan.get(sys.argv[2], "")
if isinstance(value, list):
    print(",".join(str(x) for x in value))
elif isinstance(value, dict):
    print(json.dumps(value, ensure_ascii=False, sort_keys=True))
else:
    print(value)
PY
}

state_installation_plan_has_ai() {
  local tool="$1" path py
  path="$(state_path)"
  py="$(_state_python)" || return 1
  "$py" - "$path" "$tool" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
tools = data.get("installationPlan", {}).get("aiCliTools") or []
raise SystemExit(0 if sys.argv[2] in tools else 1)
PY
}

state_installation_plan_selected_addons() {
  local path py
  path="$(state_path)"
  py="$(_state_python)" || return 1
  "$py" - "$path" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
addons = data.get("installationPlan", {}).get("addons") or {}
for addon_id, row in addons.items():
    if isinstance(row, dict) and row.get("selected"):
        print(addon_id)
PY
}

state_clear_resume() {
  _state_update clear
}

state_append_history() {
  local event="${1:-event}" status="${2:-ok}" detail="${3:-}" history
  history="$(history_path)"
  mkdir -p "$(dirname "$history")"
  event="${event//\"/\'}"
  status="${status//\"/\'}"
  detail="${detail//\"/\'}"
  printf '{"timestamp":"%s","event":"%s","status":"%s","detail":"%s"}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$event" "$status" "$detail" >> "$history"
}

state_read() {
  [[ -f "$(state_path)" ]] && cat "$(state_path)"
}
