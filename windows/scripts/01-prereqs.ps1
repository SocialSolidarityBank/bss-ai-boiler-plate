# 01-prereqs.ps1 -- winget (App Installer) + TLS + execution policy

function Step-Prereqs {
  Write-Step "Prerequisites: winget + TLS + execution policy"

  if (Test-IsAdmin) {
    Write-Info "Running as administrator."
  } else {
    Write-Info "Running as a standard user (no admin) - installing per-user where possible."
  }

  # --- TLS 1.2 for any Invoke-WebRequest downloads (older PS defaults) ----
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

  # --- winget (Windows Package Manager, ships in App Installer) -----------
  $wingetStatus = Assert-WingetReady -Context 'the Windows installer'
  if ($wingetStatus.Ready) {
    Write-Ok "winget present ($($wingetStatus.Version))"
  } else {
    Write-Warn "dry-run continuing after winget diagnostics; install or repair App Installer before a real run."
  }

  # --- execution policy so the PowerShell profile can load ---------------
  try {
    $cur = Get-ExecutionPolicy -Scope CurrentUser
    if ($cur -in @('Restricted', 'Undefined')) {
      # Default/locked-down states -- safe to auto-relax so the profile can load.
      if ($script:DryRun) {
        Write-Info "[dry-run] Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
      } else {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Write-Ok "execution policy (CurrentUser) -> RemoteSigned"
      }
    } elseif ($cur -eq 'AllSigned') {
      # AllSigned is a STRICTER posture the user deliberately chose; downgrading it
      # to RemoteSigned weakens their security, so never do it silently -- ask, and
      # default to No.
      if ($script:DryRun) {
        Write-Info "[dry-run] would ask to relax AllSigned -> RemoteSigned (default No)"
      } elseif (Confirm-Action "Execution policy is AllSigned (a strict posture you chose). Relax it to RemoteSigned so this kit's .ps1 files can load?" -DefaultNo) {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Write-Ok "execution policy (CurrentUser) -> RemoteSigned"
      } else {
        Write-Warn "keeping AllSigned -- later steps that source unsigned .ps1 files may fail to load"
      }
    } else {
      Write-Ok "execution policy (CurrentUser): $cur"
    }
  } catch {
    Write-Warn "could not adjust execution policy: $($_.Exception.Message)"
  }

  Write-Ok "prerequisites ready"
}
