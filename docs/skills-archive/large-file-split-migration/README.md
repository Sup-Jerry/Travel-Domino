# large-file-split-migration

A Codex skill for safely splitting thousand-line files with a migration-first workflow.

## What it provides
- Responsibility-first decomposition (3-8 modules)
- One-block-per-round migration process
- Equivalence verification matrix
- Checklist template generator (`scripts/checklist.ps1`)

## Structure
- `SKILL.md`
- `agents/openai.yaml`
- `references/migration-template.md`
- `references/equivalence-matrix.md`
- `scripts/checklist.ps1`

## Quick usage
```powershell
pwsh ./scripts/checklist.ps1 -ModuleName TimelineSolver -SourceFile entry/src/.../Index.ets
```

## License
MIT
