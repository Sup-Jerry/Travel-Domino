# Skill Audit Status (2026-04-18)

This file tracks execution status against `/E:/Travel/docs/skill-audit-2026-04-17.md`.

## Overall

- Direction: **shrink top-level skills**, prefer archive/offline over hard delete.
- Current cross-scope scan: `total=34`, `unique=34`, `dups=0`.
- Duplicate-name trigger conflicts: **cleared**.
- Usage counter coverage: `30` active skills now require a counter increment before work begins.

## Status by Priority

### P0

- Done: clear same-name conflicts across project/global/plugin scopes.
- Done: remove or offline invalid/low-signal top-level skills.
- Done: merge duplicate file-type entries (`doc/docx`, `pdf/anthropics-pdf`, `pptx/slides`, `xlsx/spreadsheet`) by keeping canonical entries.
- Done: project-local canonical set reduced and documented in `AGENTS.md` / `CLAUDE.md`.

### P1

- Done: merged local `skill-manager` + `skill-evolution-manager` into `skills-workbench`.
- Done: repaired and hardened `skills-workbench` scripts; unified entrypoint available.
- Done: offlined Figma split children, kept `figma` + `figma-use`.
- Done: offlined engineering-flow split family.
- Done: offlined Notion split family and deploy split family.
- Done: offlined app-planning split family and `github-to-skills` global entry.

### P2

- Done: evolution hygiene guardrails (UTF-8 output, garble gate, targeted clean, backups).
- Done: verified no real corruption in `app-size-pruner` and `travel-domino-dev` evolution data.

## Remaining Optional Work (Not Blocking)

- Optional: create explicit umbrella replacements (`notion-workflows`, `deploy-hosting`, `app-planning`) if these capabilities need to stay triggerable at top level.
- Optional: further reduce global set by folding niche single-purpose skills into documentation-only guidance.
- Optional: run a 1-2 week trigger telemetry review and restore only skills with clear repeated demand.

## Usage Counter

- Counter script:
  - `C:/Users/Reaper/.codex/scripts/skill_usage_counter.py`
- Default usage DB:
  - `C:/Users/Reaper/.codex/skill-usage/usage.json`
- Excluded from counter by request:
  - `app-size-pruner`
  - `skills-workbench`
  - `travel-domino-dev`
  - `unit-test-case-generator`

## Execution Evidence

- Detailed chronological log: `/E:/Travel/docs/skill-prune-execution-2026-04-18.md`
- Archived/offlined globals: `C:/Users/Reaper/.codex/skills-archive-disabled/*`
