---
name: skills-workbench
description: Use when managing local skill inventory and evolution in this repository, including list/check/delete/update workflows and post-session evolution persistence.
license: MIT
---

# Skills Workbench

Unified local entry for skill lifecycle + evolution workflows in this repo.
It replaces split top-level triggers from `skill-manager` and `skill-evolution-manager`.

## When to Use

- Need to list/scan/delete local skills under `E:/Travel/skills`
- Need to check GitHub-wrapped skills for upstream drift
- Need to persist session learnings to `evolution.json`
- Need to stitch persisted learnings back into `SKILL.md`
- Need to align all skills with existing `evolution.json`

## Trigger Phrases

- `/skills-workbench list`
- `/skills-workbench check`
- `/skills-workbench delete <skill_name>`
- `/skills-workbench update <skill_name_or_path>`
- `/skills-workbench evolve <skill_name_or_path> <json_payload>`
- `/skills-workbench align-all [skills_root]`
- "retrospective and persist skill learnings"
- "write this session learning back to skill"

## Workflow

1. Classify intent as `inventory`, `update`, or `evolve`.
2. Load only scripts required by that intent.
3. Return auditable evidence: command, target files, and concise result.
4. For evolution persistence, run `merge_evolution` and `smart_stitch` as a pair.

## Scripts

### Inventory / Lifecycle

- `scripts/manager/list_skills.py`
- `scripts/manager/scan_and_check.py`
- `scripts/manager/delete_skill.py`
- `scripts/manager/update_helper.py`

### Evolution

- `scripts/evolution/merge_evolution.py`
- `scripts/evolution/smart_stitch.py`
- `scripts/evolution/align_all.py`
- `scripts/evolution/clean_garbled_evolution.py`

### Unified Entrypoint

- `scripts/workbench.ps1`

## Quick Commands

```powershell
# list local skills
powershell -ExecutionPolicy Bypass -File E:\Travel\skills\skills-workbench\scripts\workbench.ps1 -Action list

# check GitHub-backed skills
powershell -ExecutionPolicy Bypass -File E:\Travel\skills\skills-workbench\scripts\workbench.ps1 -Action check

# backup a skill before manual update
powershell -ExecutionPolicy Bypass -File E:\Travel\skills\skills-workbench\scripts\workbench.ps1 -Action update -Target travel-domino-dev

# persist and stitch one evolution payload
powershell -ExecutionPolicy Bypass -File E:\Travel\skills\skills-workbench\scripts\workbench.ps1 -Action evolve -Target travel-domino-dev -Payload '{"preferences":["Keep responses concise in Chinese."]}'

# align all skills that have evolution.json
powershell -ExecutionPolicy Bypass -File E:\Travel\skills\skills-workbench\scripts\workbench.ps1 -Action align-all

# clean suspected garbled entries for one skill only
powershell -ExecutionPolicy Bypass -File E:\Travel\skills\skills-workbench\scripts\workbench.ps1 -Action clean-garbled -Target app-size-pruner
```

## Failure Handling Contract

- Missing required `-Target` or `-Payload`: fail fast with explicit error.
- Missing target skill directory: stop and report path; do not infer.
- Script returns non-zero exit code: propagate the same exit code.
- Garbled text detected in evolution payload: reject merge and keep files unchanged.
- Never hand-edit auto-stitched section in target `SKILL.md`; use `evolution.json` pipeline only.

## Constraints

- Keep top-level skill count minimal; low-frequency sub-scenarios should not be promoted.
- Prefer small, reversible changes.
- If any required file is missing, report and stop.

## User-Learned Best Practices & Constraints

> **Auto-Generated Section**: This section is maintained by `skills-workbench`. Do not edit manually.
