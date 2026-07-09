#!/usr/bin/env bash

_bss_report_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
source "$_bss_report_dir/state.sh"

bss_generate_report() {
  bss_ensure_home
  local state report manual history repo_root py
  state="$(bss_state_path)"
  report="$(bss_report_path)"
  manual="$(bss_manual_path)"
  history="$(bss_history_path)"
  repo_root="$(cd "$_bss_report_dir/.." && pwd)"

  if [[ ! -f "$state" ]]; then
    printf 'state file not found: %s\n' "$state" >&2
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    py=python3
  elif command -v python >/dev/null 2>&1; then
    py=python
  else
    printf 'python3 or python is required to generate the report/manual.\n' >&2
    return 1
  fi

  state_set_step_status report complete "latest-report.md + manual/index.html" || true

  "$py" - "$state" "$report" "$manual" "$history" "$repo_root" <<'PY'
import datetime as dt
import html
import json
import sys
from pathlib import Path

state_path, report_path, manual_path, history_path, repo_root = sys.argv[1:]
state_path = Path(state_path)
report_path = Path(report_path)
manual_path = Path(manual_path)
history_path = Path(history_path)
repo_root = Path(repo_root)
data = json.loads(state_path.read_text(encoding="utf-8"))
tools = data.get("tools") or []
steps = data.get("steps") or {}
phrases = data.get("restartPhrases") or ["보일러 플레이트 시작해줘", "AI 세팅 이어서 해줘", "개발환경 설치 도와줘"]
helper_home = report_path.parent

SUCCESS = {"installed", "complete", "completed"}

def status_label(status):
    table = {
        "installed": "설치 완료",
        "complete": "완료",
        "completed": "완료",
        "skipped": "설치 안 함",
        "none": "설치 안 함",
        "declined": "설치 안 함",
        "pending": "대기",
        "recorded": "기록만 함",
        "failed": "실패",
        "in_progress": "진행 중",
    }
    return table.get(str(status or "unknown"), str(status or "unknown"))

def tool_purpose(tool):
    name = (tool.get("name") or "").lower()
    kind = (tool.get("kind") or "").lower()
    if "codex" in name:
        return "터미널에서 Codex에게 코드 작성, 수정, 검증을 요청하는 CLI(명령 도구)입니다."
    if "claude" in name and "oh-my" not in name:
        return "터미널에서 Claude Code에게 코드 작업을 요청하는 CLI(명령 도구)입니다."
    if "matt pocock" in name:
        return "무엇부터 해야 할지 막힐 때 작업을 체계적으로 설계하도록 돕는 skill(스킬)입니다."
    if "superpowers" in name:
        return "아이디어를 구체화하고 Final Plan(최종 계획)으로 정리하도록 돕는 skill(스킬) 묶음입니다."
    if "lazy-codex" in name:
        return "Codex로 코딩, 수정, 검증을 할 때 작업 흐름을 구조적으로 잡아주는 도구입니다."
    if "oh-my" in name or "claudecode" in name:
        return "Claude Code 사용을 쉽게 만드는 설정과 helper(도우미) 도구입니다."
    if "github" in name or kind == "account":
        return "GitHub 계정과 저장소를 연결해 코드를 내려받고 올릴 수 있게 합니다."
    if kind == "addon":
        return "선택한 AI workflow(작업 흐름)를 보강하는 추가 기능입니다."
    if kind == "ai":
        return "AI 코딩 도구를 터미널에서 사용할 수 있게 합니다."
    return "개발 환경을 구성하는 기본 도구 또는 설정입니다."

def tool_location(tool):
    name = (tool.get("name") or "").lower()
    kind = (tool.get("kind") or "").lower()
    if "codex" in name:
        return "터미널에서 `codex`를 실행합니다. 위치 확인은 `which codex` 또는 PowerShell의 `Get-Command codex`를 사용합니다."
    if "claude" in name and "oh-my" not in name:
        return "터미널에서 `claude`를 실행합니다. 위치 확인은 `which claude` 또는 PowerShell의 `Get-Command claude`를 사용합니다."
    if kind == "addon" or "skills" in name or "superpowers" in name or "lazy-codex" in name or "oh-my" in name:
        return "각 도구의 installer(설치 도구)가 정한 사용자 설정 위치에 설치됩니다. 선택 결과는 이 매뉴얼과 `state.json`에 기록됩니다."
    if "github" in name:
        return "Git/GitHub CLI 설정은 사용자 계정 설정에 저장됩니다. 상태 확인은 `gh auth status`를 사용합니다."
    return "OS(운영체제)의 기본 프로그램 위치에 설치됩니다. 정확한 위치는 `which <명령>` 또는 PowerShell의 `Get-Command <명령>`로 확인합니다."

def label_tool(tool):
    name = tool.get("name", "이름 없는 도구")
    status = tool.get("status", "unknown")
    reason = tool.get("reason") or ""
    next_action = tool.get("nextAction") or ""
    detail = " / ".join(x for x in [reason, next_action] if x)
    if detail:
        return f"- {name}: {status_label(status)} - {detail}"
    return f"- {name}: {status_label(status)}"

def step_line(key, row):
    label = row.get("label") or {
        "base-tools": "Basic Environment(기본 환경)",
        "shell": "Shell(셸)",
        "github": "GitHub Connection(GitHub 연결)",
        "ai-tools": "AI CLI Tools(AI CLI 도구)",
        "addons": "Add-ons(추가 기능)",
        "report": "Report and Manual(리포트와 매뉴얼)",
    }.get(key, key)
    note = row.get("reason") or row.get("note") or ""
    suffix = f" - {note}" if note else ""
    return f"- {label}: {status_label(row.get('status'))}{suffix}"

def html_tool_card(tool):
    name = tool.get("name", "이름 없는 도구")
    status = status_label(tool.get("status", "unknown"))
    reason = tool.get("reason") or ""
    next_action = tool.get("nextAction") or ""
    detail_parts = [part for part in [reason, next_action] if part]
    detail = " / ".join(detail_parts)
    return f"""
<article class="card">
  <div class="card-head">
    <span class="dot"></span>
    <h3>{html.escape(name)}</h3>
    <span class="badge">{html.escape(status)}</span>
  </div>
  <p><strong>Purpose(용도)</strong>: {html.escape(tool_purpose(tool))}</p>
  <p><strong>Where(위치)</strong>: {html.escape(tool_location(tool))}</p>
  {f'<p><strong>Note(메모)</strong>: {html.escape(detail)}</p>' if detail else ''}
</article>"""

installed = [t for t in tools if t.get("status") in SUCCESS]
not_installed = [t for t in tools if t.get("status") not in SUCCESS]
if not installed:
    installed = [{"name": "아직 설치 완료로 기록된 도구가 없습니다.", "status": "pending"}]
if not not_installed:
    not_installed = [{"name": "설치하지 않은 도구가 없습니다.", "status": "none"}]

now = dt.datetime.now().astimezone().isoformat(timespec="seconds")
report_lines = [
    "# ai-boiler-plate 설치 결과와 사용 매뉴얼",
    "",
    f"생성 시각: {now}",
    "",
    "## 무엇이 어디에 설치됐나요?",
    f"- Repo Folder(레포 폴더): `{repo_root}`",
    f"- State and Report Folder(상태/리포트 폴더): `{helper_home}`",
    f"- Restart Command Folder(다시 시작 명령 폴더): `{helper_home / 'bin'}`",
    f"- Latest Report(최신 리포트): `{report_path}`",
    f"- HTML Manual(HTML 사용 매뉴얼): `{manual_path}`",
    "",
    "도구별 실제 실행 파일 위치는 OS(운영체제)와 installer(설치 도구)에 따라 다를 수 있습니다.",
    "정확한 위치는 macOS/Linux에서 `which <명령>`, Windows PowerShell에서 `Get-Command <명령>`로 확인합니다.",
    "",
    "## 설치 결과",
    *[step_line(key, row) for key, row in steps.items() if isinstance(row, dict)],
    "",
    "## 설치한 도구",
    *[label_tool(t) for t in installed],
    "",
    "## 설치하지 않은 도구",
    *[label_tool(t) for t in not_installed],
    "",
    "## 어떻게 쓰나요?",
    "Codex나 Claude Code에서 아래 문구 중 하나를 말하면 이어서 진행할 수 있습니다.",
    "",
    *[f"- `{p}`" for p in phrases],
    "",
    "터미널에서는 상태 확인용으로 `ai-boiler-plate --status`를 사용할 수 있습니다.",
    "",
    "## 수정하거나 다시 설치하려면",
    "- 선택을 바꾸려면 Codex에 repo link(레포 링크)와 `설치 시작해줘`를 다시 말하고 Final Installation Plan(최종 설치 계획)을 새로 승인합니다.",
    "- 같은 설정으로 다시 실행하려면 repo folder(레포 폴더)에서 `./linux/install.sh --standard` 또는 Windows의 `./windows/install.ps1 -Standard`를 실행합니다.",
    "- 상태만 확인하려면 `ai-boiler-plate --status` 또는 OS별 installer의 `--status` / `-Status`를 사용합니다.",
    "",
    "Deprecated compatibility commands for existing installs: `bss-ai-helper`, `ai-helper`, `bss-ai`.",
]
report_lines.extend([
    "",
    "## Business judgment route",
    "The installer does not decide business viability or commercial judgment questions.",
    "If setup raises those questions, use a visible/configured G-stack office-hours repo/link first; if none is available, ask the user for that repo/link then.",
    "",
    "## Matt Pocock Skills (optional)",
    "If selected, run `npx skills@latest add mattpocock/skills`, then tell your AI agent `/setup-matt-pocock-skills`.",
    "Do not copy files directly into runtime skill folders; use the installer command or fallback instructions only.",
    "",
    "## Superpowers Planning Pack (optional)",
    "Install only after explicit opt-in: `npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/brainstorming` and `npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/writing-plans`.",
    "Use it when the user wants to turn an idea into a concrete work plan; list broader workflow skills in the final plan when useful.",
])
report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

def html_list(items):
    return "\n".join(f"<li>{html.escape(item)}</li>" for item in items)

step_cards = "\n".join(
    f"""<article class="mini-card"><span class="dot"></span><div><strong>{html.escape((row.get('label') or key) if isinstance(row, dict) else key)}</strong><br><span>{html.escape(status_label(row.get('status') if isinstance(row, dict) else row))}</span></div></article>"""
    for key, row in steps.items()
)
if not step_cards:
    step_cards = '<article class="mini-card"><span class="dot"></span><div><strong>설치 상태</strong><br><span>기록된 단계가 아직 없습니다.</span></div></article>'

manual_path.parent.mkdir(parents=True, exist_ok=True)
manual = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>ai-boiler-plate 설치 결과와 사용 매뉴얼</title>
<style>
:root {{
  --black: #111111;
  --grey-dark: #333333;
  --grey: #666666;
  --grey-line: #d9d9d9;
  --grey-soft: #f5f5f5;
  --white: #ffffff;
  --blue: #0057ff;
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--grey-soft);
  color: var(--black);
  font-family: "Pretendard", "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
  line-height: 1.68;
}}
a {{ color: var(--blue); }}
.page {{ max-width: 980px; margin: 0 auto; padding: 32px 20px 72px; }}
.hero, section {{ background: var(--white); border: 1px solid var(--grey-line); border-radius: 16px; padding: 24px; margin-top: 16px; }}
.eyebrow {{ display: flex; align-items: center; gap: 8px; color: var(--blue); font-weight: 700; }}
.dot {{ display: inline-block; width: 8px; height: 8px; border-radius: 4px; background: var(--blue); flex: 0 0 auto; }}
h1, h2, h3 {{ line-height: 1.28; margin: 0; }}
h1 {{ margin-top: 8px; font-size: 32px; }}
h2 {{ font-size: 22px; }}
h3 {{ font-size: 16px; }}
p {{ margin: 10px 0 0; }}
.muted {{ color: var(--grey); }}
.line {{ height: 1px; background: var(--grey-line); margin: 18px 0; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; margin-top: 14px; }}
.surface {{ background: var(--grey-soft); border: 1px solid var(--grey-line); border-radius: 12px; padding: 14px; }}
.card, .mini-card {{ background: var(--white); border: 1px solid var(--grey-line); border-radius: 12px; padding: 14px; }}
.card-head {{ display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }}
.badge {{ margin-left: auto; color: var(--blue); border: 1px solid var(--blue); border-radius: 8px; padding: 2px 8px; font-size: 13px; }}
.mini-card {{ display: flex; gap: 10px; align-items: flex-start; }}
details {{ background: var(--white); border: 1px solid var(--grey-line); border-radius: 12px; padding: 14px; margin-top: 12px; }}
summary {{ color: var(--blue); font-weight: 700; cursor: pointer; }}
ul {{ padding-left: 20px; margin: 10px 0 0; }}
li {{ margin: 6px 0; }}
code {{ background: var(--white); border: 1px solid var(--grey-line); border-radius: 4px; padding: 2px 5px; color: var(--black); }}
pre {{ margin: 12px 0 0; background: var(--black); color: var(--white); border-radius: 12px; padding: 16px; overflow-x: auto; }}
@media (max-width: 640px) {{
  .page {{ padding: 20px 12px 56px; }}
  .hero, section {{ padding: 18px; border-radius: 12px; }}
  h1 {{ font-size: 26px; }}
}}
</style>
</head>
<body>
<main class="page">
  <header class="hero">
    <div class="eyebrow"><span class="dot"></span> Installation Complete(설치 완료)</div>
    <h1>ai-boiler-plate 설치 결과와 사용 매뉴얼</h1>
    <p class="muted">이 문서는 설치가 끝나면 자동으로 만들어집니다. 무엇이 어디에 준비됐는지, 어떤 용도로 쓰는지, 수정하거나 다시 설치할 때 무엇을 하면 되는지 쉬운 말로 정리합니다.</p>
  </header>

  <section>
    <h2>Where Things Are(어디에 있나요)</h2>
    <div class="grid">
      <div class="surface"><strong>Repo Folder(레포 폴더)</strong><br><code>{html.escape(str(repo_root))}</code></div>
      <div class="surface"><strong>State and Report Folder(상태/리포트 폴더)</strong><br><code>{html.escape(str(helper_home))}</code></div>
      <div class="surface"><strong>Restart Command Folder(다시 시작 명령 폴더)</strong><br><code>{html.escape(str(helper_home / 'bin'))}</code></div>
      <div class="surface"><strong>HTML Manual(HTML 사용 매뉴얼)</strong><br><code>{html.escape(str(manual_path))}</code></div>
    </div>
    <p class="muted">도구별 실행 파일의 정확한 위치는 OS(운영체제)마다 다릅니다. macOS/Linux는 <code>which codex</code>, Windows PowerShell은 <code>Get-Command codex</code>처럼 확인합니다.</p>
  </section>

  <section>
    <h2>Install Result(설치 결과)</h2>
    <div class="grid">
      {step_cards}
    </div>
  </section>

  <section>
    <h2>Installed Tools(설치한 도구)</h2>
    <div class="grid">
      {''.join(html_tool_card(t) for t in installed)}
    </div>
  </section>

  <section>
    <h2>Not Installed(설치하지 않은 도구)</h2>
    <div class="grid">
      {''.join(html_tool_card(t) for t in not_installed)}
    </div>
  </section>

  <section>
    <h2>How To Use(사용 방법)</h2>
    <p><strong>처음 시작하기</strong>: Codex나 Claude Code를 열고 아래 문구 중 하나를 말하면 됩니다.</p>
    <p>Codex나 Claude Code에서 아래 문구 중 하나를 말하면 이어서 진행할 수 있습니다.</p>
    <ul>
      {''.join(f'<li><code>{html.escape(p)}</code></li>' for p in phrases)}
    </ul>
    <div class="line"></div>
    <p>터미널에서 상태만 확인하려면 아래처럼 실행합니다.</p>
    <pre><code>ai-boiler-plate --status</code></pre>
  </section>

  <section>
    <h2>Change Or Reinstall(수정하거나 다시 설치하기)</h2>
    <ul>
      <li>선택을 바꾸려면 Codex에 repo link(레포 링크)와 <code>설치 시작해줘</code>를 다시 말하고 Final Installation Plan(최종 설치 계획)을 새로 승인합니다.</li>
      <li>같은 설정으로 다시 설치하려면 repo folder(레포 폴더)에서 <code>./linux/install.sh --standard</code> 또는 <code>./windows/install.ps1 -Standard</code>를 실행합니다.</li>
      <li>기록만 확인하려면 <code>latest-report.md</code>, 자세히 보려면 이 <code>manual/index.html</code> 파일을 엽니다.</li>
    </ul>
    <details>
      <summary>Advanced Options(고급 옵션)</summary>
      <p>개발자와 CI는 <code>--classic</code>, <code>--status</code>, <code>--dry-run</code>, <code>--list</code>를 사용할 수 있습니다. HTML 설명서는 자동으로 브라우저를 열지 않습니다.</p>
    </details>
  </section>

  <section>
    <h2>Notes(참고)</h2>
    <div class="grid">
      <div class="surface">
        <strong>Business judgment route</strong>
        <p>The installer does not decide business viability or commercial judgment questions. Use a visible/configured G-stack office-hours repo/link first; if none is available, ask the user for that repo/link then.</p>
      </div>
      <div class="surface">
        <strong>Matt Pocock Skills (optional, 선택)</strong>
        <p>선택했다면 <code>npx skills@latest add mattpocock/skills</code> 실행 뒤 AI 에이전트에 <code>/setup-matt-pocock-skills</code>를 입력합니다.</p>
      </div>
      <div class="surface">
        <strong>Superpowers Planning Pack (optional, 선택)</strong>
        <p>명시적으로 선택했을 때만 <code>brainstorming</code>과 <code>writing-plans</code>를 설치합니다. 아이디어를 작업 계획으로 바꿀 때 사용합니다.</p>
      </div>
      <div class="surface">
        <strong>Deprecated compatibility</strong>
        <p>기존 설치는 한동안 <code>bss-ai-helper</code>, <code>ai-helper</code>, <code>bss-ai</code> 명령을 쓸 수 있지만 새 문서에서는 <code>ai-boiler-plate</code>를 우선 사용합니다.</p>
      </div>
    </div>
  </section>

  <section>
    <h2>Official Docs(공식 문서)</h2>
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
</main>
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
print("설치 결과를 쉬운 말로 정리했습니다.")
print("HTML 사용 매뉴얼에는 무엇이 어디에 설치됐는지, 용도, 수정/재설치 방법이 들어 있습니다.")
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
