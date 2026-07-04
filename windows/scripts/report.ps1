. (Join-Path $PSScriptRoot 'state.ps1')

if (-not (Get-Command Write-Step -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'lib.ps1')
}

function ConvertTo-ReportSafeText {
  param($Value)
  $text = if ($null -eq $Value) { '' } else { [string]$Value }
  $patterns = @(
    '(?i)\bAuthorization\s*:\s*Bearer\s+["'']?[A-Za-z0-9._~+/\-=]+["'']?',
    '(?i)\bBearer\s+["'']?[A-Za-z0-9._~+/\-=]{4,}["'']?',
    '(?i)\b(password|passcode|secret|credential|api[_-]?key|access[_-]?key|auth[_-]?code|oauth[_-]?code|token)\s*[:=]\s*\S+',
    '\bsk-[A-Za-z0-9_-]{8,}',
    '\bgh[pousr]_[A-Za-z0-9_]{8,}'
  )
  foreach ($pattern in $patterns) {
    $text = [regex]::Replace($text, $pattern, '[redacted]')
  }
  return $text
}

function Get-ReportProperty {
  param($InputObject, [string]$Name)
  if ($null -eq $InputObject) { return $null }
  if ($InputObject -is [System.Collections.IDictionary]) {
    if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
    return $null
  }
  $property = $InputObject.PSObject.Properties[$Name]
  if ($property) { return $property.Value }
  return $null
}

function Format-ToolLine {
  param($Tool)
  $name = ConvertTo-ReportSafeText (Get-ReportProperty $Tool 'name')
  if (-not $name) { $name = '이름 없는 도구' }
  $status = ConvertTo-ReportSafeText (Get-ReportProperty $Tool 'status')
  if (-not $status) { $status = 'unknown' }
  $details = @()
  $reason = ConvertTo-ReportSafeText (Get-ReportProperty $Tool 'reason')
  $nextAction = ConvertTo-ReportSafeText (Get-ReportProperty $Tool 'nextAction')
  if ($reason) { $details += $reason }
  if ($nextAction) { $details += $nextAction }
  if ($details.Count -gt 0) { return "- ${name}: ${status} - $($details -join ' / ')" }
  return "- ${name}: ${status}"
}

function New-HelperReport {
  $helperHome = Get-HelperHome
  $statePath = Get-StatePath
  if (-not (Test-Path $statePath)) { throw "state file not found: $statePath" }
  New-Item -ItemType Directory -Force -Path $helperHome | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $helperHome 'manual') | Out-Null
  $report = Join-Path $helperHome 'latest-report.md'
  $manual = Join-Path $helperHome 'manual\index.html'
  $history = Join-Path $helperHome 'history.jsonl'
  $data = Read-HelperState
  $phrases = @('BSS AI Helper 실행해줘', 'AI 세팅 이어서 해줘', '개발환경 설치 도와줘')
  $statePhrases = Get-ReportProperty $data 'restartPhrases'
  if ($statePhrases) { $phrases = @($statePhrases) }
  $tools = @((Get-ReportProperty $data 'tools'))
  $installed = @($tools | Where-Object { (Get-ReportProperty $_ 'status') -in @('installed','complete','completed') })
  $notInstalled = @($tools | Where-Object { (Get-ReportProperty $_ 'status') -notin @('installed','complete','completed') })
  if ($installed.Count -eq 0) { $installed = @([pscustomobject]@{ name='아직 설치 완료로 기록된 도구가 없습니다.'; status='pending' }) }
  if ($notInstalled.Count -eq 0) { $notInstalled = @([pscustomobject]@{ name='설치하지 않은 도구가 없습니다.'; status='none' }) }
  $lines = @('# BSS AI Helper 리포트', '', '## 처음 시작하기', 'Codex가 열리면 `BSS AI Helper 실행해줘`라고 말합니다.', '', '## 설치한 도구')
  $lines += $installed | ForEach-Object { Format-ToolLine $_ }
  $lines += @('', '## 설치하지 않은 도구')
  $lines += $notInstalled | ForEach-Object { Format-ToolLine $_ }
  $lines | Set-Content -Encoding UTF8 $report
  @"
<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8" /><title>BSS AI Helper 사용 설명서</title></head>
<body><h1>BSS AI Helper 사용 설명서</h1><p>처음 시작하기: <code>BSS AI Helper 실행해줘</code></p>
<h2>설치한 도구</h2><h2>설치하지 않은 도구</h2>
<details><summary>고급 보기</summary><p>HTML 설명서는 열기 전에 반드시 사용자에게 묻습니다.</p></details></body></html>
"@ | Set-Content -Encoding UTF8 $manual
  (@{ createdAt = (Get-Date).ToString('o'); reportPath = $report; manualPath = $manual } | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $history
}

function Step-Report {
  Write-Step "BSS AI Helper report"
  Initialize-HelperState
  New-HelperReport
  Set-StepStatus -Step 'report' -Status 'complete' -Note 'latest-report.md generated'
  Write-Ok "BSS AI Helper report ready: $(Get-ReportPath)"
}

function Invoke-ReportScript {
  if ($args -contains '-Generate') {
    Step-Report
    return
  }
  if ($args -contains '-Open') {
    $manual = Get-ManualPath
    if (Test-Path $manual) {
      Write-Host $manual
      return
    }
    Write-Error "manual not found: $manual"
    exit 1
  }
  Write-Host 'Usage: windows/scripts/report.ps1 -Generate|-Open'
  exit 1
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-ReportScript @args
}
