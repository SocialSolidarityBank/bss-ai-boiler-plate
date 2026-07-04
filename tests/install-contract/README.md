# Installer Contract Harness

These smoke tests characterize the installer mode contract without installing
packages, Docker, GitHub auth, Codex, Claude, Gajae, or writing user profiles.

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/install-contract/windows.ps1
```

```bash
/c/Program\ Files/Git/bin/bash.exe tests/install-contract/posix.sh
```

Pending cases are reported but do not fail default runs. To let later installer
repair work promote them to hard assertions, set:

```text
BSS_INSTALL_CONTRACT_ENFORCE_PENDING=1
```

The harness uses temp helper homes and fake command PATHs, asserts exit codes
and output snippets, and bounds subprocesses with timeouts so it does not wait
on interactive prompts.
