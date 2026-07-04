function Get-HelperHome {
  if ($env:BSS_AI_HELPER_HOME) { return $env:BSS_AI_HELPER_HOME }
  return (Join-Path $HOME '.bss-ai-helper')
}

function Get-StatePath { Join-Path (Get-HelperHome) 'state.json' }
function Get-HistoryPath { Join-Path (Get-HelperHome) 'history.jsonl' }
function Get-ReportPath { Join-Path (Get-HelperHome) 'latest-report.md' }
function Get-ManualPath { Join-Path (Join-Path (Get-HelperHome) 'manual') 'index.html' }

function New-HelperState {
  return @{ version = 1; steps = @{}; ai_services = @(); aiServices = @(); addons = @{}; tools = @() }
}

function ConvertTo-StatusSafeText {
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

function ConvertTo-PlainObject {
  param($Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [string]) { return $Value }
  if ($Value -is [System.Collections.IDictionary]) {
    $hash = @{}
    foreach ($key in $Value.Keys) { $hash[$key] = ConvertTo-PlainObject -Value $Value[$key] }
    return $hash
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    return @($Value | ForEach-Object { ConvertTo-PlainObject -Value $_ })
  }
  $properties = @($Value.PSObject.Properties | ForEach-Object { $_ })
  if ($Value -is [pscustomobject]) {
    $hash = @{}
    foreach ($prop in $properties) { $hash[$prop.Name] = ConvertTo-PlainObject -Value $prop.Value }
    return $hash
  }
  if ($properties.Count -gt 0) {
    $hash = @{}
    foreach ($prop in $properties) { $hash[$prop.Name] = ConvertTo-PlainObject -Value $prop.Value }
    return $hash
  }
  return $Value
}

function Read-HelperState {
  $path = Get-StatePath
  if (-not (Test-Path $path)) {
    return (New-HelperState)
  }
  try {
    $parsed = Get-Content $path -Raw | ConvertFrom-Json
    $state = ConvertTo-PlainObject -Value $parsed
    if (-not $state.ContainsKey('version')) { $state['version'] = 1 }
    if (-not $state.ContainsKey('steps') -or $null -eq $state['steps']) { $state['steps'] = @{} }
    if (-not $state.ContainsKey('ai_services') -or $null -eq $state['ai_services']) { $state['ai_services'] = @() }
    if (-not $state.ContainsKey('aiServices') -or $null -eq $state['aiServices']) { $state['aiServices'] = @($state['ai_services']) }
    if (-not $state.ContainsKey('addons') -or $null -eq $state['addons']) { $state['addons'] = @{} }
    if (-not $state.ContainsKey('tools') -or $null -eq $state['tools']) { $state['tools'] = @() }
    return $state
  } catch {
    Write-Warn "진행 상태 파일을 읽을 수 없습니다. 파일은 지우지 않았습니다."
    return (New-HelperState)
  }
}

function Write-HelperState {
  param([Parameter(Mandatory)]$State)
  $homeDir = Get-HelperHome
  New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
  $State['updated_at'] = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  $State | ConvertTo-Json -Depth 8 | Set-Content -Path (Get-StatePath) -Encoding UTF8
}

function Initialize-HelperState {
  $path = Get-StatePath
  if (-not (Test-Path $path)) { Write-HelperState -State (Read-HelperState) }
}

function Set-StepStatus {
  param([string]$Step, [string]$Status, [string]$Note = '')
  $state = Read-HelperState
  if (-not $state.ContainsKey('steps')) { $state['steps'] = @{} }
  $state['steps'][$Step] = @{ status = $Status; note = $Note }
  Write-HelperState -State $state
}

function Add-AiService {
  param([string[]]$Services)
  $state = Read-HelperState
  $state['ai_services'] = @($Services | Where-Object { $_ })
  $state['aiServices'] = @($Services | Where-Object { $_ })
  foreach ($service in $state['ai_services']) {
    if ($service -eq 'Codex') {
      Set-ToolInState -State $state -Name 'Codex CLI' -Status 'complete' -Kind 'ai'
    } elseif ($service -eq 'Claude') {
      Set-ToolInState -State $state -Name 'Claude Code' -Status 'complete' -Kind 'ai'
    } else {
      Set-ToolInState -State $state -Name $service -Status 'recorded' -Kind 'ai' -Reason '자동 설치 없음'
    }
  }
  Write-HelperState -State $state
}

function Set-ToolInState {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Status,
    [Parameter(Mandatory)][string]$Kind,
    [string]$Reason = ''
  )
  if (-not $State.ContainsKey('tools')) { $State['tools'] = @() }
  $tools = @($State['tools'])
  $found = $false
  for ($i = 0; $i -lt $tools.Count; $i++) {
    if ($tools[$i]['name'] -eq $Name) {
      $tools[$i]['status'] = $Status
      $tools[$i]['kind'] = $Kind
      if ($Reason) { $tools[$i]['reason'] = $Reason }
      $found = $true
    }
  }
  if (-not $found) {
    $row = @{ name = $Name; status = $Status; kind = $Kind }
    if ($Reason) { $row['reason'] = $Reason }
    $tools += $row
  }
  $State['tools'] = $tools
}

function Set-AiServiceStatus {
  param([string[]]$Services, [string]$Status, [string]$Reason = '')
  $state = Read-HelperState
  foreach ($service in @($Services | Where-Object { $_ })) {
    if ($service -eq 'Codex') {
      Set-ToolInState -State $state -Name 'Codex CLI' -Status $Status -Kind 'ai' -Reason $Reason
    } elseif ($service -eq 'Claude') {
      Set-ToolInState -State $state -Name 'Claude Code' -Status $Status -Kind 'ai' -Reason $Reason
    } else {
      Set-ToolInState -State $state -Name $service -Status $Status -Kind 'ai' -Reason $Reason
    }
  }
  Write-HelperState -State $state
}

function Set-AddonStatus {
  param([string]$Id, [string]$Title, [string]$Status, [string]$Note = '')
  $state = Read-HelperState
  if (-not $state.ContainsKey('addons')) { $state['addons'] = @{} }
  $state['addons'][$Id] = @{ title = $Title; status = $Status; seen = $true; note = $Note }
  Write-HelperState -State $state
}

function Append-History {
  param([string]$Line)
  New-Item -ItemType Directory -Path (Get-HelperHome) -Force | Out-Null
  Add-Content -Path (Get-HistoryPath) -Value $Line -Encoding UTF8
}

function Clear-ResumeState {
  Write-HelperState -State (New-HelperState)
}

function Show-Status {
  $path = Get-StatePath
  if (-not (Test-Path $path)) { Write-Info "진행 상태가 아직 없습니다."; return }
  $state = Read-HelperState
  $labels = @(
    @{ key = 'base-tools'; label = '기본 설치 준비' },
    @{ key = 'shell'; label = '터미널 편의 설정' },
    @{ key = 'github'; label = 'GitHub 연결' },
    @{ key = 'ai-tools'; label = 'AI 도구 선택' },
    @{ key = 'addons'; label = '추가 도구 추천' },
    @{ key = 'resume'; label = '다시 시작 표면' },
    @{ key = 'report'; label = '마무리 리포트' }
  )
  $icons = @{
    complete = '● 완료'
    skipped = '△ 건너뜀'
    failed = '× 실패'
    pending = '○ 대기'
  }
  $progressed = 0
  foreach ($item in $labels) {
    $key = $item.key
    $row = $null
    if ($state['steps']) { $row = $state['steps'][$key] }
    if ($row -and @('complete', 'skipped') -contains $row['status']) { $progressed += 1 }
  }
  Write-Output "진행 상태: $progressed/$($labels.Count)"
  foreach ($item in $labels) {
    $key = $item.key
    $row = $null
    if ($state['steps']) { $row = $state['steps'][$key] }
    $status = if ($row) { ConvertTo-StatusSafeText $row['status'] } else { 'pending' }
    $note = if ($row) { ConvertTo-StatusSafeText $row['note'] } else { '' }
    $suffix = if ($note) { " - $note" } else { '' }
    $icon = if ($icons.ContainsKey($status)) { $icons[$status] } else { $status }
    Write-Output "$icon $($item.label)$suffix"
  }
}

function Show-HelperStatus {
  Show-Status
}
