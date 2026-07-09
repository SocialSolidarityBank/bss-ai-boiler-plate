. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $PSScriptRoot 'state.ps1')

function ConvertTo-ManualHtml {
  param([AllowNull()][string]$Text)
  return [System.Net.WebUtility]::HtmlEncode([string]$Text)
}

function Get-ToolValue {
  param($Tool, [string]$Key, [string]$Default = '')
  if ($null -eq $Tool) { return $Default }
  if ($Tool -is [System.Collections.IDictionary] -and $Tool.ContainsKey($Key)) { return [string]$Tool[$Key] }
  $prop = $Tool.PSObject.Properties[$Key]
  if ($prop) { return [string]$prop.Value }
  return $Default
}

function Get-StatusLabel {
  param([string]$Status)
  switch ($Status) {
    'installed' { return '설치 완료' }
    'complete' { return '완료' }
    'completed' { return '완료' }
    'skipped' { return '설치 안 함' }
    'none' { return '설치 안 함' }
    'declined' { return '설치 안 함' }
    'pending' { return '대기' }
    'recorded' { return '기록만 함' }
    'failed' { return '실패' }
    'in_progress' { return '진행 중' }
    default { if ($Status) { return $Status } else { return 'unknown' } }
  }
}

function Get-ToolPurpose {
  param($Tool)
  $name = (Get-ToolValue -Tool $Tool -Key 'name').ToLowerInvariant()
  $kind = (Get-ToolValue -Tool $Tool -Key 'kind').ToLowerInvariant()
  if ($name -like '*codex*') { return '터미널에서 Codex에게 코드 작성, 수정, 검증을 요청하는 CLI(명령 도구)입니다.' }
  if (($name -like '*claude*') -and ($name -notlike '*oh-my*')) { return '터미널에서 Claude Code에게 코드 작업을 요청하는 CLI(명령 도구)입니다.' }
  if ($name -like '*matt pocock*') { return '무엇부터 해야 할지 막힐 때 작업을 체계적으로 설계하도록 돕는 skill(스킬)입니다.' }
  if ($name -like '*superpowers*') { return '아이디어를 구체화하고 Final Plan(최종 계획)으로 정리하도록 돕는 skill(스킬) 묶음입니다.' }
  if ($name -like '*lazy-codex*') { return 'Codex로 코딩, 수정, 검증을 할 때 작업 흐름을 구조적으로 잡아주는 도구입니다.' }
  if (($name -like '*oh-my*') -or ($name -like '*claudecode*')) { return 'Claude Code 사용을 쉽게 만드는 설정과 helper(도우미) 도구입니다.' }
  if (($name -like '*github*') -or ($kind -eq 'account')) { return 'GitHub 계정과 저장소를 연결해 코드를 내려받고 올릴 수 있게 합니다.' }
  if ($kind -eq 'addon') { return '선택한 AI workflow(작업 흐름)를 보강하는 추가 기능입니다.' }
  if ($kind -eq 'ai') { return 'AI 코딩 도구를 터미널에서 사용할 수 있게 합니다.' }
  return '개발 환경을 구성하는 기본 도구 또는 설정입니다.'
}

function Get-ToolLocation {
  param($Tool)
  $name = (Get-ToolValue -Tool $Tool -Key 'name').ToLowerInvariant()
  $kind = (Get-ToolValue -Tool $Tool -Key 'kind').ToLowerInvariant()
  if ($name -like '*codex*') { return '터미널에서 codex를 실행합니다. 위치 확인은 PowerShell의 Get-Command codex 또는 WSL/Linux의 which codex를 사용합니다.' }
  if (($name -like '*claude*') -and ($name -notlike '*oh-my*')) { return '터미널에서 claude를 실행합니다. 위치 확인은 PowerShell의 Get-Command claude 또는 WSL/Linux의 which claude를 사용합니다.' }
  if (($kind -eq 'addon') -or ($name -like '*skills*') -or ($name -like '*superpowers*') -or ($name -like '*lazy-codex*') -or ($name -like '*oh-my*')) {
    return '각 도구의 installer(설치 도구)가 정한 사용자 설정 위치에 설치됩니다. 선택 결과는 이 매뉴얼과 state.json에 기록됩니다.'
  }
  if ($name -like '*github*') { return 'Git/GitHub CLI 설정은 사용자 계정 설정에 저장됩니다. 상태 확인은 gh auth status를 사용합니다.' }
  return 'OS(운영체제)의 기본 프로그램 위치에 설치됩니다. 정확한 위치는 PowerShell의 Get-Command <명령>으로 확인합니다.'
}

function Format-ToolLine {
  param($Tool)
  $name = Get-ToolValue -Tool $Tool -Key 'name' -Default '이름 없는 도구'
  $status = Get-StatusLabel (Get-ToolValue -Tool $Tool -Key 'status' -Default 'unknown')
  $reason = Get-ToolValue -Tool $Tool -Key 'reason'
  $nextAction = Get-ToolValue -Tool $Tool -Key 'nextAction'
  $detail = @(@($reason, $nextAction) | Where-Object { $_ })
  if ($detail.Count -gt 0) { return "- $($name): $status - $($detail -join ' / ')" }
  return "- $($name): $status"
}

function New-ToolCard {
  param($Tool)
  $name = ConvertTo-ManualHtml (Get-ToolValue -Tool $Tool -Key 'name' -Default '이름 없는 도구')
  $status = ConvertTo-ManualHtml (Get-StatusLabel (Get-ToolValue -Tool $Tool -Key 'status' -Default 'unknown'))
  $purpose = ConvertTo-ManualHtml (Get-ToolPurpose -Tool $Tool)
  $location = ConvertTo-ManualHtml (Get-ToolLocation -Tool $Tool)
  $reason = Get-ToolValue -Tool $Tool -Key 'reason'
  $nextAction = Get-ToolValue -Tool $Tool -Key 'nextAction'
  $detail = @(@($reason, $nextAction) | Where-Object { $_ })
  $detailHtml = ''
  if ($detail.Count -gt 0) {
    $detailHtml = '<p><strong>Note(메모)</strong>: ' + (ConvertTo-ManualHtml ($detail -join ' / ')) + '</p>'
  }
  return @"
<article class="card">
  <div class="card-head">
    <span class="dot"></span>
    <h3>$name</h3>
    <span class="badge">$status</span>
  </div>
  <p><strong>Purpose(용도)</strong>: $purpose</p>
  <p><strong>Where(위치)</strong>: $location</p>
  $detailHtml
</article>
"@
}

function New-StepCard {
  param([string]$Key, $Row)
  $label = $Key
  $status = 'pending'
  if ($Row -is [System.Collections.IDictionary]) {
    if ($Row.ContainsKey('label') -and $Row['label']) { $label = [string]$Row['label'] }
    if ($Row.ContainsKey('status')) { $status = [string]$Row['status'] }
  }
  $labelHtml = ConvertTo-ManualHtml $label
  $statusHtml = ConvertTo-ManualHtml (Get-StatusLabel $status)
  return "<article class=""mini-card""><span class=""dot""></span><div><strong>$labelHtml</strong><br><span>$statusHtml</span></div></article>"
}

function New-HelperReport {
  $helperHome = Get-HelperHome
  $statePath = Get-StatePath
  if (-not (Test-Path $statePath)) { throw "state file not found: $statePath" }
  New-Item -ItemType Directory -Force -Path $helperHome | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $helperHome 'manual') | Out-Null
  $report = Get-ReportPath
  $manual = Get-ManualPath
  $history = Get-HistoryPath
  Set-StepStatus -Step 'report' -Status 'complete' -Note 'latest-report.md + manual/index.html'
  $data = Read-HelperState
  $phrases = @('보일러 플레이트 시작해줘', 'AI 세팅 이어서 해줘', '개발환경 설치 도와줘')
  if ($data.ContainsKey('restartPhrases') -and $data['restartPhrases']) { $phrases = @($data['restartPhrases']) }
  $tools = @($data['tools'])
  $installed = @($tools | Where-Object { (Get-ToolValue -Tool $_ -Key 'status') -in @('installed','complete','completed') })
  $notInstalled = @($tools | Where-Object { (Get-ToolValue -Tool $_ -Key 'status') -notin @('installed','complete','completed') })
  if ($installed.Count -eq 0) { $installed = @(@{ name='아직 설치 완료로 기록된 도구가 없습니다.'; status='pending' }) }
  if ($notInstalled.Count -eq 0) { $notInstalled = @(@{ name='설치하지 않은 도구가 없습니다.'; status='none' }) }
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $now = (Get-Date).ToString('o')
  $binDir = Join-Path $helperHome 'bin'

  $lines = @(
    '# ai-boiler-plate 설치 결과와 사용 매뉴얼',
    '',
    "생성 시각: $now",
    '',
    '## 무엇이 어디에 설치됐나요?',
    ('- Repo Folder(레포 폴더): `{0}`' -f $repoRoot),
    ('- State and Report Folder(상태/리포트 폴더): `{0}`' -f $helperHome),
    ('- Restart Command Folder(다시 시작 명령 폴더): `{0}`' -f $binDir),
    ('- Latest Report(최신 리포트): `{0}`' -f $report),
    ('- HTML Manual(HTML 사용 매뉴얼): `{0}`' -f $manual),
    '',
    '도구별 실제 실행 파일 위치는 OS(운영체제)와 installer(설치 도구)에 따라 다를 수 있습니다.',
    '정확한 위치는 Windows PowerShell에서 `Get-Command <명령>`, macOS/Linux에서 `which <명령>`로 확인합니다.',
    '',
    '## 설치한 도구'
  )
  $lines += $installed | ForEach-Object { Format-ToolLine -Tool $_ }
  $lines += @('', '## 설치하지 않은 도구')
  $lines += $notInstalled | ForEach-Object { Format-ToolLine -Tool $_ }
  $lines += @(
    '',
    '## 어떻게 쓰나요?',
    'Codex나 Claude Code에서 아래 문구 중 하나를 말하면 이어서 진행할 수 있습니다.'
  )
  $lines += $phrases | ForEach-Object { '- `{0}`' -f $_ }
  $lines += @(
    '',
    '터미널에서는 상태 확인용으로 `ai-boiler-plate --status`를 사용할 수 있습니다.',
    '',
    '## 수정하거나 다시 설치하려면',
    '- 선택을 바꾸려면 Codex에 repo link(레포 링크)와 `설치 시작해줘`를 다시 말하고 Final Installation Plan(최종 설치 계획)을 새로 승인합니다.',
    '- 같은 설정으로 다시 실행하려면 repo folder(레포 폴더)에서 `.\windows\install.ps1 -Standard` 또는 Linux의 `./linux/install.sh --standard`를 실행합니다.',
    '- 상태만 확인하려면 `ai-boiler-plate --status` 또는 OS별 installer의 `--status` / `-Status`를 사용합니다.',
    '',
    '## Business judgment route',
    'The installer does not decide business viability or commercial judgment questions.',
    'If setup raises those questions, use a visible/configured G-stack office-hours repo/link first; if none is available, ask the user for that repo/link then.',
    '',
    '## Matt Pocock Skills (optional)',
    'If selected, run `npx skills@latest add mattpocock/skills`, then tell your AI agent `/setup-matt-pocock-skills`.',
    'Do not copy files directly into runtime skill folders; use the installer command or fallback instructions only.',
    '',
    '## Superpowers Planning Pack (optional)',
    'Install only after explicit opt-in: `npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/brainstorming` and `npx skills@latest add https://github.com/obra/superpowers/tree/main/skills/writing-plans`.',
    'Use it when the user wants to turn an idea into a concrete work plan; list broader workflow skills in the final plan when useful.',
    '',
    'Deprecated compatibility commands for existing installs: `bss-ai-helper`, `ai-helper`, `bss-ai`.'
  )
  $lines | Set-Content -Encoding UTF8 $report

  $stepCards = ''
  if ($data.ContainsKey('steps') -and $data['steps']) {
    $stepCards = (($data['steps'].GetEnumerator() | ForEach-Object { New-StepCard -Key $_.Key -Row $_.Value }) -join "`n")
  }
  if (-not $stepCards) {
    $stepCards = '<article class="mini-card"><span class="dot"></span><div><strong>설치 상태</strong><br><span>기록된 단계가 아직 없습니다.</span></div></article>'
  }
  $installedCards = (($installed | ForEach-Object { New-ToolCard -Tool $_ }) -join "`n")
  $notInstalledCards = (($notInstalled | ForEach-Object { New-ToolCard -Tool $_ }) -join "`n")
  $phraseItems = (($phrases | ForEach-Object { '<li><code>' + (ConvertTo-ManualHtml $_) + '</code></li>' }) -join "`n")
  $repoRootHtml = ConvertTo-ManualHtml $repoRoot
  $helperHomeHtml = ConvertTo-ManualHtml $helperHome
  $binHtml = ConvertTo-ManualHtml $binDir
  $manualHtml = ConvertTo-ManualHtml $manual

  @"
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>ai-boiler-plate 설치 결과와 사용 매뉴얼</title>
<style>
:root {
  --black: #111111;
  --grey-dark: #333333;
  --grey: #666666;
  --grey-line: #d9d9d9;
  --grey-soft: #f5f5f5;
  --white: #ffffff;
  --blue: #0057ff;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--grey-soft);
  color: var(--black);
  font-family: "Pretendard", "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
  line-height: 1.68;
}
a { color: var(--blue); }
.page { max-width: 980px; margin: 0 auto; padding: 32px 20px 72px; }
.hero, section { background: var(--white); border: 1px solid var(--grey-line); border-radius: 16px; padding: 24px; margin-top: 16px; }
.eyebrow { display: flex; align-items: center; gap: 8px; color: var(--blue); font-weight: 700; }
.dot { display: inline-block; width: 8px; height: 8px; border-radius: 4px; background: var(--blue); flex: 0 0 auto; }
h1, h2, h3 { line-height: 1.28; margin: 0; }
h1 { margin-top: 8px; font-size: 32px; }
h2 { font-size: 22px; }
h3 { font-size: 16px; }
p { margin: 10px 0 0; }
.muted { color: var(--grey); }
.line { height: 1px; background: var(--grey-line); margin: 18px 0; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; margin-top: 14px; }
.surface { background: var(--grey-soft); border: 1px solid var(--grey-line); border-radius: 12px; padding: 14px; }
.card, .mini-card { background: var(--white); border: 1px solid var(--grey-line); border-radius: 12px; padding: 14px; }
.card-head { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.badge { margin-left: auto; color: var(--blue); border: 1px solid var(--blue); border-radius: 8px; padding: 2px 8px; font-size: 13px; }
.mini-card { display: flex; gap: 10px; align-items: flex-start; }
details { background: var(--white); border: 1px solid var(--grey-line); border-radius: 12px; padding: 14px; margin-top: 12px; }
summary { color: var(--blue); font-weight: 700; cursor: pointer; }
ul { padding-left: 20px; margin: 10px 0 0; }
li { margin: 6px 0; }
code { background: var(--white); border: 1px solid var(--grey-line); border-radius: 4px; padding: 2px 5px; color: var(--black); }
pre { margin: 12px 0 0; background: var(--black); color: var(--white); border-radius: 12px; padding: 16px; overflow-x: auto; }
@media (max-width: 640px) {
  .page { padding: 20px 12px 56px; }
  .hero, section { padding: 18px; border-radius: 12px; }
  h1 { font-size: 26px; }
}
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
      <div class="surface"><strong>Repo Folder(레포 폴더)</strong><br><code>$repoRootHtml</code></div>
      <div class="surface"><strong>State and Report Folder(상태/리포트 폴더)</strong><br><code>$helperHomeHtml</code></div>
      <div class="surface"><strong>Restart Command Folder(다시 시작 명령 폴더)</strong><br><code>$binHtml</code></div>
      <div class="surface"><strong>HTML Manual(HTML 사용 매뉴얼)</strong><br><code>$manualHtml</code></div>
    </div>
    <p class="muted">도구별 실행 파일의 정확한 위치는 OS(운영체제)마다 다릅니다. Windows PowerShell은 <code>Get-Command codex</code>, macOS/Linux는 <code>which codex</code>처럼 확인합니다.</p>
  </section>
  <section>
    <h2>Install Result(설치 결과)</h2>
    <div class="grid">$stepCards</div>
  </section>
  <section>
    <h2>Installed Tools(설치한 도구)</h2>
    <div class="grid">$installedCards</div>
  </section>
  <section>
    <h2>Not Installed(설치하지 않은 도구)</h2>
    <div class="grid">$notInstalledCards</div>
  </section>
  <section>
    <h2>How To Use(사용 방법)</h2>
    <p><strong>처음 시작하기</strong>: Codex나 Claude Code를 열고 아래 문구 중 하나를 말하면 됩니다.</p>
    <p>Codex나 Claude Code에서 아래 문구 중 하나를 말하면 이어서 진행할 수 있습니다.</p>
    <ul>$phraseItems</ul>
    <div class="line"></div>
    <p>터미널에서 상태만 확인하려면 아래처럼 실행합니다.</p>
    <pre><code>ai-boiler-plate --status</code></pre>
  </section>
  <section>
    <h2>Change Or Reinstall(수정하거나 다시 설치하기)</h2>
    <ul>
      <li>선택을 바꾸려면 Codex에 repo link(레포 링크)와 <code>설치 시작해줘</code>를 다시 말하고 Final Installation Plan(최종 설치 계획)을 새로 승인합니다.</li>
      <li>같은 설정으로 다시 설치하려면 repo folder(레포 폴더)에서 <code>.\windows\install.ps1 -Standard</code> 또는 <code>./linux/install.sh --standard</code>를 실행합니다.</li>
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
"@ | Set-Content -Encoding UTF8 $manual

  (@{ createdAt = (Get-Date).ToString('o'); reportPath = $report; manualPath = $manual } | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $history
  Write-Output "latest-report.md: $report"
  Write-Output "manual/index.html: $manual"
  Write-Output "history.jsonl: $history"
  Write-Output '설치 결과를 쉬운 말로 정리했습니다.'
  Write-Output 'HTML 사용 매뉴얼에는 무엇이 어디에 설치됐는지, 용도, 수정/재설치 방법이 들어 있습니다.'
}
