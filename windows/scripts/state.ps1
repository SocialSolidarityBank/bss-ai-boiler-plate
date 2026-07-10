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
  return @{ version = 1; steps = @{}; ai_services = @(); aiServices = @(); addons = @{}; tools = @(); installationPlan = @{} }
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
    if (-not $state.ContainsKey('installationPlan')) { $state['installationPlan'] = @{} }
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

function Get-InstallationPlanAddonTitle {
  param([Parameter(Mandatory)][string]$Id)
  switch ($Id) {
    'matt-pocock-skills' { return 'Matt Pocock Skills' }
    'superpowers' { return 'Superpowers Planning Pack' }
    'lazy-codex' { return 'Lazy-Codex' }
    'oh-my-claudecode' { return 'oh-my-claudecode' }
    default { return $Id }
  }
}

function Set-InstallationPlan {
  param(
    [Parameter(Mandatory)][string]$SelectedOS,
    [Parameter(Mandatory)][string]$WorkspaceFolder,
    [Parameter(Mandatory)][string]$BaseEnvironment,
    [string[]]$AiCliTools = @(),
    [string[]]$SelectedAddons = @(),
    [Parameter(Mandatory)][string]$ExecutionCommand
  )
  $state = Read-HelperState
  $selected = @{}
  foreach ($id in @($SelectedAddons | Where-Object { $_ })) { $selected[$id] = $true }
  $addons = @{}
  foreach ($id in @('matt-pocock-skills', 'superpowers', 'lazy-codex', 'oh-my-claudecode')) {
    $isSelected = $selected.ContainsKey($id)
    $addons[$id] = @{
      title = Get-InstallationPlanAddonTitle -Id $id
      selected = $isSelected
      decision = if ($isSelected) { 'install' } else { 'skip' }
    }
  }
  $state['installationPlan'] = @{
    schemaVersion = 1
    selectedOS = $SelectedOS
    workspaceFolder = $WorkspaceFolder
    baseEnvironment = $BaseEnvironment
    aiCliTools = [object[]]@($AiCliTools | Where-Object { $_ })
    addons = $addons
    executionCommand = $ExecutionCommand
    approvalStatus = 'pending'
    approvedAt = ''
    secretPolicy = 'No tokens, OAuth codes, passwords, private keys, or device codes are stored.'
  }
  Write-HelperState -State $state
}

function Approve-InstallationPlan {
  $state = Read-HelperState
  if (-not $state.ContainsKey('installationPlan') -or $state['installationPlan'].Count -eq 0) {
    throw 'installation plan is missing'
  }
  $state['installationPlan']['approvalStatus'] = 'approved'
  $state['installationPlan']['approvedAt'] = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  Write-HelperState -State $state
}

function Get-InstallationPlanStatus {
  $state = Read-HelperState
  if (-not $state.ContainsKey('installationPlan')) { return 'missing' }
  $plan = $state['installationPlan']
  if ($null -eq $plan -or $plan.Count -eq 0) { return 'missing' }
  if ($plan.ContainsKey('approvalStatus') -and $plan['approvalStatus']) { return [string]$plan['approvalStatus'] }
  return 'missing'
}

function Get-InstallationPlanSchemaError {
  $state = Read-HelperState
  if (-not $state.ContainsKey('installationPlan')) { return 'installationPlan must be an object/map' }
  $plan = $state['installationPlan']
  if ($null -eq $plan -or -not ($plan -is [System.Collections.IDictionary])) { return 'installationPlan must be an object/map' }

  foreach ($field in @('selectedOS', 'workspaceFolder', 'baseEnvironment', 'executionCommand', 'approvalStatus', 'approvedAt', 'secretPolicy')) {
    if (-not $plan.ContainsKey($field) -or -not ($plan[$field] -is [string])) {
      return "installationPlan.$field must be a string"
    }
  }

  if (-not $plan.ContainsKey('schemaVersion') -or -not ($plan['schemaVersion'] -is [int] -or $plan['schemaVersion'] -is [long])) {
    return 'installationPlan.schemaVersion must be a number'
  }
  if (-not $plan.ContainsKey('aiCliTools') -or -not ($plan['aiCliTools'] -is [System.Array])) {
    return 'installationPlan.aiCliTools must be an array'
  }
  if (-not $plan.ContainsKey('addons') -or -not ($plan['addons'] -is [System.Collections.IDictionary])) {
    return 'installationPlan.addons must be an object/map'
  }

  foreach ($key in @($plan['addons'].Keys)) {
    $addon = $plan['addons'][$key]
    if ($null -eq $addon -or -not ($addon -is [System.Collections.IDictionary])) {
      return "installationPlan.addons.$key must be an object/map"
    }
    if (-not $addon.ContainsKey('title') -or -not ($addon['title'] -is [string])) {
      return "installationPlan.addons.$key.title must be a string"
    }
    if (-not $addon.ContainsKey('selected') -or -not ($addon['selected'] -is [bool])) {
      return "installationPlan.addons.$key.selected must be a boolean"
    }
    if (-not $addon.ContainsKey('decision') -or -not ($addon['decision'] -is [string])) {
      return "installationPlan.addons.$key.decision must be a string"
    }
  }

  return ''
}

function Get-InstallationPlanField {
  param([Parameter(Mandatory)][string]$Field)
  $state = Read-HelperState
  if (-not $state.ContainsKey('installationPlan')) { return '' }
  $plan = $state['installationPlan']
  if ($null -eq $plan -or -not $plan.ContainsKey($Field)) { return '' }
  $value = $plan[$Field]
  if ($value -is [System.Array]) { return (($value | ForEach-Object { [string]$_ }) -join ',') }
  if ($value -is [System.Collections.IDictionary]) { return ($value | ConvertTo-Json -Depth 8 -Compress) }
  return [string]$value
}

function Test-InstallationPlanHasAi {
  param([Parameter(Mandatory)][string]$Tool)
  $state = Read-HelperState
  if (-not $state.ContainsKey('installationPlan')) { return $false }
  $plan = $state['installationPlan']
  if ($null -eq $plan -or -not $plan.ContainsKey('aiCliTools')) { return $false }
  return (@($plan['aiCliTools']) -contains $Tool)
}

function Get-InstallationPlanSelectedAddons {
  $state = Read-HelperState
  if (-not $state.ContainsKey('installationPlan')) { return @() }
  $plan = $state['installationPlan']
  if ($null -eq $plan -or -not $plan.ContainsKey('addons')) { return @() }
  $selected = @()
  foreach ($key in @($plan['addons'].Keys)) {
    $row = $plan['addons'][$key]
    if ($row -and $row.ContainsKey('selected') -and $row['selected']) { $selected += $key }
  }
  return $selected
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
