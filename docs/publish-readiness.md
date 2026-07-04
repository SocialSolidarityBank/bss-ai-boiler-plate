# GitHub Publish Readiness

Target repository: `https://github.com/socialsolidaritybank/bss-ai-boiler-plate`

Target clone URL: `https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git`

Installer default clone URL: `https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git`

The requested delivery target is `bss-ai-boiler-plate`. The target repository
has been confirmed accessible, made public, and approved as the installer
default clone source.

This lane prepares the repository for publication but does not commit, push, create a GitHub repository, edit visibility, or change `origin`.

Release-readiness docs should describe the current BSS AI Helper behavior:

- macOS root installer: `./install.sh --status`, `--classic`, `--wizard`, `--dry-run`, `--list`; an interactive run opens the question wizard unless a direct/classic mode is selected, while redirected stdin without `--wizard` runs the classic step installer.
- Linux installer: `./linux/install.sh --status`, `--classic`, `--wizard`, `--with-docker`; `curl .../linux/install.sh | bash` bootstraps and then runs classic mode when no terminal input is available.
- Windows installer: `.\windows\install.ps1 -Status`, `-Classic`, `-Wizard`, `-DryRun`, `-List`.
- `--list`/`-List` includes the platform install steps plus `resume` and `report`.
- Docker is explicit opt-in: macOS asks before starting Colima, Linux skips Docker under `--yes` unless `--with-docker` or a Docker opt-in env var is set, and Windows Docker Desktop is never installed under `-Yes` or redirected input.
- `bss-ai-boilerplate:*` remains the current profile marker for compatibility. Do not rename installed markers as part of release cleanup.

Run this read-only check:

```sh
./scripts/11-publish-readiness.sh --check
```

To perform the optional bounded read-only target check, run:

```sh
BSS_PUBLISH_READINESS_REMOTE_CHECK=1 ./scripts/11-publish-readiness.sh --check
```

If the check reports the target as blocked or inaccessible, stop and report that
`https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git` cannot be used
yet. Do not mutate `origin` or change installer defaults as a fallback.

When the parent or user explicitly approves publishing, use the prepared sequence below after QA is green:

```sh
gh repo view socialsolidaritybank/bss-ai-boiler-plate --json nameWithOwner,url,visibility,defaultBranchRef
git remote set-url origin https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git
git push -u origin main
```

If `gh repo view` fails because of organization access, stop and report that GitHub organization write access is required. Do not create a repo as a fallback without approval.

Before publishing, also run the stale-reference sweep in the readiness script and confirm it reports no stale public release references.
