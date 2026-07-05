. (Join-Path $PSScriptRoot 'state.ps1')

function New-HelperReport {
  $home = Get-HelperHome
  $statePath = Get-StatePath
  if (-not (Test-Path $statePath)) { throw "state file not found: $statePath" }
  New-Item -ItemType Directory -Force -Path $home | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $home 'manual') | Out-Null
  $report = Join-Path $home 'latest-report.md'
  $manual = Join-Path $home 'manual\index.html'
  $history = Join-Path $home 'history.jsonl'
  $data = Get-Content $statePath -Raw | ConvertFrom-Json
  $phrases = @('보일러 플레이트 시작해줘', 'AI 세팅 이어서 해줘', '개발환경 설치 도와줘')
  if ($data.restartPhrases) { $phrases = @($data.restartPhrases) }
  $tools = @($data.tools)
  $installed = @($tools | Where-Object { $_.status -in @('installed','complete','completed') })
  $notInstalled = @($tools | Where-Object { $_.status -notin @('installed','complete','completed') })
  if ($installed.Count -eq 0) { $installed = @([pscustomobject]@{ name='아직 설치 완료로 기록된 도구가 없습니다.'; status='pending' }) }
  if ($notInstalled.Count -eq 0) { $notInstalled = @([pscustomobject]@{ name='설치하지 않은 도구가 없습니다.'; status='none' }) }
  $lines = @('# ai-boiler-plate 리포트', '', '## 처음 시작하기', 'Codex가 열리면 `보일러 플레이트 시작해줘`라고 말합니다.', '', '## Business judgment route', 'The installer does not decide business viability or commercial judgment questions.', 'If setup raises those questions, use a visible/configured G-stack office-hours repo/link first; if none is available, ask the user for that repo/link then.', '', '## Matt Pocock Skills (필수 설정)', '`npx skills@latest add mattpocock/skills` 실행 뒤 AI 에이전트에 `/setup-matt-pocock-skills`를 입력합니다. 런타임 skill 폴더에는 직접 쓰지 않습니다.', '', '## Superpowers Debug/Verify Pack (선택)', '명시적으로 선택했을 때만 `systematic-debugging`과 `verification-before-completion`을 설치합니다. 전체 Superpowers workflow/plugin은 고급 수동 옵션입니다.', '', '## Deprecated compatibility', 'Existing installs may still use `bss-ai-helper`, `ai-helper`, or `bss-ai` for one release; prefer `ai-boiler-plate`.', '', '## 설치한 도구')
  $lines += $installed | ForEach-Object { "- $($_.name): $($_.status)" }
  $lines += @('', '## 설치하지 않은 도구')
  $lines += $notInstalled | ForEach-Object { "- $($_.name): $($_.status)" }
  $lines | Set-Content -Encoding UTF8 $report
  @"
<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8" /><title>ai-boiler-plate 사용 설명서</title></head>
<body><h1>ai-boiler-plate 사용 설명서</h1><p>처음 시작하기: <code>보일러 플레이트 시작해줘</code></p>
<h2>Business judgment route</h2><p>The installer does not decide business viability or commercial judgment questions. Use a visible/configured G-stack office-hours repo/link first; if none is available, ask the user for that repo/link then.</p>
<h2>Matt Pocock Skills (필수 설정)</h2><p><code>npx skills@latest add mattpocock/skills</code> 실행 뒤 AI 에이전트에 <code>/setup-matt-pocock-skills</code>를 입력합니다. 런타임 skill 폴더에는 직접 쓰지 않습니다.</p>
<h2>Superpowers Debug/Verify Pack (선택)</h2><p>명시적으로 선택했을 때만 <code>systematic-debugging</code>과 <code>verification-before-completion</code>을 설치합니다. 전체 Superpowers workflow/plugin은 고급 수동 옵션입니다.</p>
<h2>Deprecated compatibility</h2><p>Existing installs may still use <code>bss-ai-helper</code>, <code>ai-helper</code>, or <code>bss-ai</code> for one release; prefer <code>ai-boiler-plate</code>.</p>
<h2>설치한 도구</h2><h2>설치하지 않은 도구</h2>
<details><summary>고급 보기</summary><p>HTML 설명서는 열기 전에 반드시 사용자에게 묻습니다.</p></details></body></html>
"@ | Set-Content -Encoding UTF8 $manual
  (@{ createdAt = (Get-Date).ToString('o'); reportPath = $report; manualPath = $manual } | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $history
}
