#!/usr/bin/env bash

_bss_report_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
source "$_bss_report_dir/state.sh"

bss_generate_report() {
  bss_ensure_home
  local state report manual history
  state="$(bss_state_path)"
  report="$(bss_report_path)"
  manual="$(bss_manual_path)"
  history="$(bss_history_path)"

  if [[ ! -f "$state" ]]; then
    printf 'state file not found: %s\n' "$state" >&2
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required to generate the report/manual.\n' >&2
    return 1
  fi

  python3 - "$state" "$report" "$manual" "$history" <<'PY'
import datetime as dt
import html
import json
import sys
from pathlib import Path

state_path, report_path, manual_path, history_path = map(Path, sys.argv[1:])
data = json.loads(state_path.read_text(encoding="utf-8"))
tools = data.get("tools") or []
steps = data.get("steps") or {}
phrases = data.get("restartPhrases") or ["BSS AI Helper 실행해줘", "AI 세팅 이어서 해줘", "개발환경 설치 도와줘"]

def label_tool(tool):
    name = tool.get("name", "이름 없는 도구")
    status = tool.get("status", "unknown")
    reason = tool.get("reason") or ""
    next_action = tool.get("nextAction") or ""
    detail = " / ".join(x for x in [reason, next_action] if x)
    if detail:
        return f"- {name}: {status} - {detail}"
    return f"- {name}: {status}"

installed = [t for t in tools if t.get("status") in {"installed", "complete", "completed"}]
not_installed = [t for t in tools if t.get("status") not in {"installed", "complete", "completed"}]
if not installed:
    installed = [{"name": "아직 설치 완료로 기록된 도구가 없습니다.", "status": "pending"}]
if not not_installed:
    not_installed = [{"name": "설치하지 않은 도구가 없습니다.", "status": "none"}]

now = dt.datetime.now().astimezone().isoformat(timespec="seconds")
report_lines = [
    "# BSS AI Helper 리포트",
    "",
    f"생성 시각: {now}",
    "",
    "## 처음 시작하기",
    "먼저 GitHub 레포를 clone하고, 정해진 폴더에서 Codex를 실행합니다.",
    "",
    "```sh",
    "git clone https://github.com/socialsolidaritybank/bss-ai-helper.git ~/bss-ai-helper",
    "cd ~/bss-ai-helper",
    "codex",
    "```",
    "",
    "Codex가 열리면 `BSS AI Helper 실행해줘`라고 말합니다.",
    "",
    "## 설치한 도구",
    *[label_tool(t) for t in installed],
    "",
    "## 설치하지 않은 도구",
    *[label_tool(t) for t in not_installed],
    "",
    "## 다시 시작하기",
    *[f"- `{p}`" for p in phrases],
    "",
    "터미널에서는 `bss-ai-helper`, `ai-helper`, `bss-ai`를 사용할 수 있습니다.",
]
report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

def li(items):
    return "\n".join(f"<li>{html.escape(label_tool(t)[2:])}</li>" for t in items)

manual_path.parent.mkdir(parents=True, exist_ok=True)
manual = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>BSS AI Helper 사용 설명서</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; line-height: 1.6; max-width: 860px; margin: 0 auto; padding: 32px 20px 72px; color: #17202a; background: #fafafa; }}
h1, h2 {{ line-height: 1.25; }}
code {{ background: #eef1f5; padding: 2px 5px; border-radius: 4px; }}
pre {{ background: #101820; color: #eef6ff; padding: 16px; overflow-x: auto; border-radius: 8px; }}
section {{ border-top: 1px solid #d8dde6; padding-top: 20px; margin-top: 24px; }}
details {{ border: 1px solid #d8dde6; border-radius: 8px; padding: 12px 14px; background: #fff; }}
</style>
</head>
<body>
<h1>BSS AI Helper 사용 설명서</h1>
<p>처음 시작하기: 먼저 GitHub 레포를 clone하고, 정해진 폴더에서 Codex를 실행합니다.</p>
<pre><code>git clone https://github.com/socialsolidaritybank/bss-ai-helper.git ~/bss-ai-helper
cd ~/bss-ai-helper
codex</code></pre>
<p>Codex가 열리면 <code>BSS AI Helper 실행해줘</code>라고 말합니다. 설치 방법만 안내하고 끝내지 않고, 승인하면 직접 설치를 시도합니다.</p>
<section>
<h2>설치한 도구</h2>
<ul>
{li(installed)}
</ul>
</section>
<section>
<h2>설치하지 않은 도구</h2>
<ul>
{li(not_installed)}
</ul>
</section>
<section>
<h2>다시 시작하기</h2>
<ul>
{''.join(f'<li><code>{html.escape(p)}</code></li>' for p in phrases)}
</ul>
</section>
<section>
<h2>공식 문서</h2>
<ul>
<li><a href="https://developers.openai.com/codex/cli">Codex CLI</a></li>
<li><a href="https://developers.openai.com/codex/ide">Codex IDE</a></li>
<li><a href="https://docs.anthropic.com/en/docs/claude-code/overview">Claude Code overview</a></li>
<li><a href="https://docs.anthropic.com/en/docs/claude-code/ide-integrations">Claude Code IDE integrations</a></li>
<li><a href="https://github.com/signup">GitHub signup</a></li>
<li><a href="https://cli.github.com/manual/">GitHub CLI manual</a></li>
<li><a href="https://github.com/yeachan-heo/oh-my-claudecode">oh-my-claudecode</a></li>
<li><a href="https://github.com/obra/superpowers">Superpowers</a></li>
<li><a href="https://github.com/mattpocock/skills">Matt Pocock Skills</a></li>
</ul>
</section>
<details>
<summary>고급 보기</summary>
<p>개발자와 CI는 <code>--classic</code>, <code>--status</code>, <code>--dry-run</code>, <code>--list</code>를 사용할 수 있습니다. HTML 설명서는 자동으로 열지 않습니다. 열기 전에 반드시 사용자에게 묻습니다.</p>
</details>
</body>
</html>
"""
manual_path.write_text(manual, encoding="utf-8")

history_path.parent.mkdir(parents=True, exist_ok=True)
history = {
    "createdAt": now,
    "reportPath": str(report_path),
    "manualPath": str(manual_path),
    "installedCount": len(installed),
    "notInstalledCount": len(not_installed),
}
with history_path.open("a", encoding="utf-8") as f:
    f.write(json.dumps(history, ensure_ascii=False) + "\n")

print(f"latest-report.md: {report_path}")
print(f"manual/index.html: {manual_path}")
print(f"history.jsonl: {history_path}")
PY
}

bss_open_manual_if_confirmed() {
  local manual
  manual="$(bss_manual_path)"
  [[ -f "$manual" ]] || { warn "HTML 설명서가 아직 없습니다: ${manual/#$HOME/~}"; return 1; }
  if ! confirm "HTML 설명서를 브라우저로 열까요?"; then
    info "브라우저를 열지 않았습니다. 파일 위치: ${manual/#$HOME/~}"
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open "$manual"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$manual"
  else
    info "브라우저 열기 명령을 찾지 못했습니다. 파일 위치: ${manual/#$HOME/~}"
  fi
}
