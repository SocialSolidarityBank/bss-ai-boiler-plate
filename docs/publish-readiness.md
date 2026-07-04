# GitHub Publish Readiness

Target repository: `https://github.com/socialsolidaritybank/bss-ai-helper`

Upstream source: this repository was forked from `https://github.com/foxion37/lazy-starter-kit` and adapted into `BSS AI Helper`.

This lane prepares the repository for publication but does not commit, push, create a GitHub repository, edit visibility, or change `origin`.

Run this read-only check:

```sh
./scripts/11-publish-readiness.sh --check
```

When the parent or user explicitly approves publishing, use the prepared sequence below after QA is green:

```sh
gh repo view socialsolidaritybank/bss-ai-helper --json nameWithOwner,url,visibility,defaultBranchRef
git remote set-url origin https://github.com/socialsolidaritybank/bss-ai-helper.git
git push -u origin main
```

If `gh repo view` fails because of organization access, stop and report that GitHub organization write access is required. Do not create a repo as a fallback without approval.
