# Git Governance

This repository enforces commit/push quality gates and a Git Flow branch model.

## 1. One-time setup

Run once in the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-git-governance.ps1
```

This sets:

- `core.hooksPath=.githooks`
- `commit.template=.gitmessage.txt`

## 2. Commit message format

Required subject format:

```text
<type>[optional scope]: <description>
```

Valid examples:

- `feat(auth): add guest login fallback`
- `fix: handle empty trip title`
- `docs(git): describe release workflow`

Optional body/footer are still allowed below the first line.

## 3. Push guard checks

Before each `git push`, hook `scripts/git-hooks/pre-push.ps1` blocks pushes when:

1. Added lines include `console.log(...)`
2. Added lines include `TODO`
3. Any added/modified file in push diff is larger than `1 MB`

## 4. Branch model

Use these long-lived branches:

- `main`: stable production-ready code
- `develop`: integration branch for daily feature merge

Use short-lived branches:

- `feature/*`: created from `develop`, merged back to `develop`
- `release/vX.Y.Z`: created from `develop`, merged to `main` and `develop`
- `hotfix/vX.Y.Z`: created from `main`, merged to `main` and `develop`

## 5. Branch creation commands

Initialize `develop` once:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\git-flow.ps1 init
```

Create branches:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\git-flow.ps1 feature user-profile
powershell -ExecutionPolicy Bypass -File .\scripts\git-flow.ps1 release v1.3.0
powershell -ExecutionPolicy Bypass -File .\scripts\git-flow.ps1 hotfix v1.3.1
```

## 6. Scheduled auto-merge to main

Workflow: `.github/workflows/auto-merge-develop.yml`

- Trigger time: every Monday at 09:00 (Asia/Shanghai)
- Rule: only when `develop` has commits ahead of `main` and latest commit on `develop` is at least 72 hours old
- Action: create (or reuse) PR `develop -> main` and enable auto-merge

Adjust schedule by changing the workflow `cron` and stability threshold.

## 7. Release/hotfix auto-tag

Workflow: `.github/workflows/tag-on-release.yml`

When a pull request into `main` is merged and head branch is:

- `release/vX.Y.Z`, or
- `hotfix/vX.Y.Z`

the workflow creates an annotated Git tag with the same version (`vX.Y.Z`).
