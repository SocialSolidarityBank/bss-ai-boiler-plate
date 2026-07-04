function Get-AllHostsProfilePaths {
  $docs = [Environment]::GetFolderPath('MyDocuments')
  if ([string]::IsNullOrWhiteSpace($docs)) {
    if ($env:USERPROFILE) { $docs = Join-Path $env:USERPROFILE 'Documents' } else { $docs = $HOME }
  }
  return @(
    (Join-Path $docs 'WindowsPowerShell\profile.ps1'),
    (Join-Path $docs 'PowerShell\profile.ps1')
  )
}

function Get-ProfileEncoding {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path $Path) -or ((Get-Item $Path).Length -eq 0)) {
    return (New-Object System.Text.UTF8Encoding($true))
  }
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    $fallback = New-Object System.Text.UTF8Encoding($false)
  } else {
    $fallback = [System.Text.Encoding]::Default
  }
  $reader = New-Object System.IO.StreamReader($Path, $fallback, $true)
  try {
    $null = $reader.ReadToEnd()
    return $reader.CurrentEncoding
  } finally {
    $reader.Dispose()
  }
}

function Update-ManagedBlock {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Tag,
    [Parameter(Mandatory)][string]$Content
  )
  $begin = "# >>> $Tag >>>"
  $end   = "# <<< $Tag <<<"
  $short = $Path.Replace($env:USERPROFILE, '~')
  $enc = Get-ProfileEncoding $Path

  if (Test-Path $Path) {
    $existing = [System.IO.File]::ReadAllLines($Path, $enc)
    $hasBegin = $existing -contains $begin
    $hasEnd   = $existing -contains $end
    if ($hasBegin -ne $hasEnd) {
      Write-Warn "$short has an unmatched managed '$Tag' marker; refusing to modify it. Fix or delete the stray marker line by hand."
      return
    }
  }

  if ($script:DryRun) {
    if ((Test-Path $Path) -and (Select-String -Path $Path -SimpleMatch $begin -Quiet)) {
      Write-Info "[dry-run] would update '$Tag' block in $short"
    } else {
      Write-Info "[dry-run] would add '$Tag' block to $short"
    }
    return
  }

  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bak = "$Path.bss-ai-boilerplate.bak"
  if ((Test-Path $Path) -and ((Get-Item $Path).Length -gt 0) -and -not (Test-Path $bak)) {
    Copy-Item $Path $bak
    Write-Info "backed up $short -> $($bak.Replace($env:USERPROFILE, '~')) (first change)"
  }

  $lines = @()
  if (Test-Path $Path) {
    $skip = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path, $enc)) {
      if ($line -eq $begin) { $skip = $true; continue }
      if ($skip -and $line -eq $end) { $skip = $false; continue }
      if (-not $skip) { $lines += $line }
    }
  }
  $lines += $begin
  foreach ($l in ($Content -split "`r?`n")) { $lines += $l }
  $lines += $end

  [System.IO.File]::WriteAllLines($Path, $lines, $enc)
  Write-Ok "wrote '$Tag' block -> $short"
}

function Remove-ManagedBlock {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Tag)
  $begin = "# >>> $Tag >>>"
  $end   = "# <<< $Tag <<<"
  $short = $Path.Replace($env:USERPROFILE, '~')
  if (-not (Test-Path $Path)) { Write-Info "no $short (skip '$Tag')"; return }
  $enc = Get-ProfileEncoding $Path
  $existing = [System.IO.File]::ReadAllLines($Path, $enc)
  $hasBegin = $existing -contains $begin
  $hasEnd   = $existing -contains $end
  if ($hasBegin -ne $hasEnd) {
    Write-Warn "$short has an unmatched managed '$Tag' marker; refusing to modify it. Fix or delete the stray marker line by hand."
    return
  }
  if (-not $hasBegin) { Write-Info "no '$Tag' block in $short"; return }
  if ($script:DryRun) { Write-Info "[dry-run] would remove '$Tag' block from $short"; return }

  $bak = "$Path.bss-ai-boilerplate.bak"
  if (((Get-Item $Path).Length -gt 0) -and -not (Test-Path $bak)) {
    Copy-Item $Path $bak
    Write-Info "backed up $short -> $($bak.Replace($env:USERPROFILE, '~')) (first change)"
  }

  $lines = @()
  $skip = $false
  foreach ($line in $existing) {
    if ($line -eq $begin) { $skip = $true; continue }
    if ($skip -and $line -eq $end) { $skip = $false; continue }
    if (-not $skip) { $lines += $line }
  }
  [System.IO.File]::WriteAllLines($Path, $lines, $enc)
  Write-Ok "removed '$Tag' block from $short"
}
