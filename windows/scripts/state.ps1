function Get-HelperHome {
  if ($env:AI_BOILER_PLATE_HOME) { return $env:AI_BOILER_PLATE_HOME }
  if ($env:BSS_AI_HELPER_HOME) { return $env:BSS_AI_HELPER_HOME }
  $preferred = Join-Path $HOME '.ai-boiler-plate'
  $legacy = Join-Path $HOME '.bss-ai-helper'
  if ((Test-Path $legacy) -and (-not (Test-Path $preferred))) { return $legacy }
  return $preferred
}

function Get-StatePath { Join-Path (Get-HelperHome) 'state.json' }
function Get-HistoryPath { Join-Path (Get-HelperHome) 'history.jsonl' }
function Get-ReportPath { Join-Path (Get-HelperHome) 'latest-report.md' }
function Get-ManualPath { Join-Path (Join-Path (Get-HelperHome) 'manual') 'index.html' }

function New-HelperState {
  return @{ version = 1; steps = @{}; ai_services = @(); aiServices = @(); addons = @{}; tools = @() }
}

function ConvertTo-PlainObject {
  param($Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [System.Collections.IDictionary]) {
    $hash = @{}
    foreach ($key in $Value.Keys) { $hash[$key] = ConvertTo-PlainObject -Value $Value[$key] }
    return $hash
  }
  if ($Value -is [System.Array]) {
    $items = New-Object System.Collections.ArrayList
    foreach ($item in $Value) {
      [void]$items.Add((ConvertTo-PlainObject -Value $item))
    }
    return ,($items.ToArray())
  }
  if ($Value -is [pscustomobject]) {
    $hash = @{}
    foreach ($prop in @($Value.PSObject.Properties)) { $hash[$prop.Name] = ConvertTo-PlainObject -Value $prop.Value }
    return $hash
  }
  return $Value
}

function Set-StateArrayValue {
  param([Parameter(Mandatory)]$State, [Parameter(Mandatory)][string]$Key)
  if (-not $State.ContainsKey($Key) -or $null -eq $State[$Key]) {
    $State[$Key] = [object[]]@()
  } elseif ($State[$Key] -is [System.Array]) {
    $State[$Key] = [object[]]$State[$Key]
  } else {
    $State[$Key] = [object[]]@($State[$Key])
  }
}

function Normalize-HelperStateArrays {
  param([Parameter(Mandatory)]$State)
  foreach ($key in @('ai_services', 'aiServices', 'tools')) {
    Set-StateArrayValue -State $State -Key $key
  }
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
    if (-not $state.ContainsKey('steps')) { $state['steps'] = @{} }
    if (-not $state.ContainsKey('ai_services')) { $state['ai_services'] = @() }
    if (-not $state.ContainsKey('aiServices')) { $state['aiServices'] = @($state['ai_services']) }
    if (-not $state.ContainsKey('addons')) { $state['addons'] = @{} }
    if (-not $state.ContainsKey('tools')) { $state['tools'] = @() }
    Normalize-HelperStateArrays -State $state
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
  Normalize-HelperStateArrays -State $State
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
  $serviceList = [object[]]@($Services | Where-Object { $_ })
  $state['ai_services'] = $serviceList
  $state['aiServices'] = $serviceList
  foreach ($service in $state['ai_services']) {
    if ($service -in @('Codex', 'Codex CLI')) {
      Set-ToolInState -State $state -Name 'Codex CLI' -Status 'complete' -Kind 'ai'
    } elseif ($service -in @('Claude', 'Claude Code CLI')) {
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
    if ($service -in @('Codex', 'Codex CLI')) {
      Set-ToolInState -State $state -Name 'Codex CLI' -Status $Status -Kind 'ai' -Reason $Reason
    } elseif ($service -in @('Claude', 'Claude Code CLI')) {
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
  Set-ToolInState -State $state -Name $Title -Status $Status -Kind 'addon' -Reason $Note
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
    @{ key = 'addons'; label = '추가 도구 추천' }
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
    $status = if ($row) { $row['status'] } else { 'pending' }
    $note = if ($row) { $row['note'] } else { '' }
    $suffix = if ($note) { " - $note" } else { '' }
    $icon = if ($icons.ContainsKey($status)) { $icons[$status] } else { $status }
    Write-Output "$icon $($item.label)$suffix"
  }
}

function Show-HelperStatus {
  Show-Status
}
