. (Join-Path $PSScriptRoot 'state.ps1')

function New-HelperReport {
  $helperHome = Get-HelperHome
  $statePath = Get-StatePath
  if (-not (Test-Path $statePath)) { throw "state file not found: $statePath" }
  New-Item -ItemType Directory -Force -Path $helperHome | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $helperHome 'manual') | Out-Null
  $report = Join-Path $helperHome 'latest-report.md'
  $manual = Join-Path $helperHome 'manual\index.html'
  $history = Join-Path $helperHome 'history.jsonl'
  $data = Get-Content $statePath -Raw | ConvertFrom-Json
  $phrases = @('BSS AI Helper 실행해줘', 'AI 세팅 이어서 해줘', '개발환경 설치 도와줘')
  if ($data.restartPhrases) { $phrases = @($data.restartPhrases) }
  $tools = @($data.tools)
  $installed = @($tools | Where-Object { $_.status -in @('installed','complete','completed') })
  $notInstalled = @($tools | Where-Object { $_.status -notin @('installed','complete','completed') })
  if ($installed.Count -eq 0) { $installed = @([pscustomobject]@{ name='아직 설치 완료로 기록된 도구가 없습니다.'; status='pending' }) }
  if ($notInstalled.Count -eq 0) { $notInstalled = @([pscustomobject]@{ name='설치하지 않은 도구가 없습니다.'; status='none' }) }
  $lines = @('# BSS AI Helper 리포트', '', '## 처음 시작하기', 'Codex가 열리면 `BSS AI Helper 실행해줘`라고 말합니다.', '', '## 설치한 도구')
  $lines += $installed | ForEach-Object { "- $($_.name): $($_.status)" }
  $lines += @('', '## 설치하지 않은 도구')
  $lines += $notInstalled | ForEach-Object { "- $($_.name): $($_.status)" }
  $lines | Set-Content -Encoding UTF8 $report
  @"
<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8" /><title>BSS AI Helper 사용 설명서</title></head>
<body><h1>BSS AI Helper 사용 설명서</h1><p>처음 시작하기: <code>BSS AI Helper 실행해줘</code></p>
<h2>설치한 도구</h2><h2>설치하지 않은 도구</h2>
<details><summary>고급 보기</summary><p>HTML 설명서는 열기 전에 반드시 사용자에게 묻습니다.</p></details></body></html>
"@ | Set-Content -Encoding UTF8 $manual
  (@{ createdAt = (Get-Date).ToString('o'); reportPath = $report; manualPath = $manual } | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $history
}
