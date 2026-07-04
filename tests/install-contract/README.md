# Installer Contract Harness

These smoke tests characterize the installer mode contract without installing
packages, Docker, GitHub auth, Codex, Claude, Gajae, or writing user profiles.

The current contract is:

- interactive terminal runs the question wizard unless a direct/classic mode is
  requested;
- redirected stdin without explicit wizard falls back to the documented classic
  installer with a clear message;
- Linux `--wizard` may read answers from `/dev/tty` when stdin is piped;
- Windows `-Wizard` reads from console or redirected input when available;
- Docker stays opt-in under non-interactive Linux and Windows runs.

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/install-contract/windows.ps1
```

```powershell
& 'C:\Program Files\Git\bin\bash.exe' tests/install-contract/posix.sh
```

Pending cases are reported but do not fail default runs. To let later installer
repair work promote them to hard assertions, set:

```text
BSS_INSTALL_CONTRACT_ENFORCE_PENDING=1
```

The harness uses temp helper homes and fake command PATHs, asserts exit codes
and output snippets, and bounds subprocesses with timeouts so it does not wait
on interactive prompts.

CI runs these as separate gating jobs: Windows PowerShell 5.1 parse plus
`windows.ps1` on `windows-latest`, and POSIX syntax plus `posix.sh` on
`ubuntu-latest`. Dry-run/classic and resume/report smoke checks stay separate
from the heavyweight real install jobs so cache or package-manager drift is
easier to diagnose.
