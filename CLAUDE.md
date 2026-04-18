# CLAUDE.md

## Project-level instructions
- Default response language: Chinese.
- Prefer concise explanations, concrete steps, and copy-pastable commands.
- Prefer small, reviewable diffs; avoid broad refactors unless explicitly requested.
- Before editing, identify target files and propose a short 3-6 bullet plan.
- Never invent APIs/config/paths; search the repo first when uncertain.
- Keep style and architecture consistent with existing code.
- Add or update tests for behavior changes when tests exist.
- Prefer type safety and explicit error handling.
- Never expose secrets/tokens/credentials in output.

## Skills available for this repo (5 local skills, canonical trigger set)
When user explicitly names a skill, or task clearly matches its description, use that skill workflow.

1. travel-domino-dev
   Path: `E:\Travel\skills\travel-domino-dev\SKILL.md`
2. skills-workbench
   Path: `E:\Travel\skills\skills-workbench\SKILL.md`
3. app-size-pruner
   Path: `E:\Travel\skills\app-size-pruner\SKILL.md`
4. bat
   Path: `E:\Travel\skills\bat\SKILL.md`
5. unit-test-case-generator
   Path: `E:\Travel\skills\unit-test-case-generator\SKILL.md`

## Archived local skills (not top-level trigger targets)
- `E:\Travel\docs\skills-archive\github-to-skills\`
- `E:\Travel\docs\skills-archive\large-file-split-migration\`
- `E:\Travel\docs\skills-archive\high-bar-project-scoring\`
- `E:\Travel\docs\skills-archive\skill-manager\`
- `E:\Travel\docs\skills-archive\skill-evolution-manager\`

## Skill usage rules
- Trigger: use named skill(s) first; if unnamed, select by semantic match.
- Multiple skills: choose minimal covering set and state execution order briefly.
- Progressive read: open `SKILL.md` first, then only load referenced files as needed.
- If a skill path is missing/unreadable, state it briefly and continue with best fallback.
- Explicitly disabled in this repo: `yt-dlp`.

## Local Skills Auto-Loading (AWS Code Compatible)
Since AWS Code cannot invoke skills via Skill tool, use Read tool to load and follow skill instructions:

**Project Local Skills Path**: `E:\Travel\skills\`

**Auto-loading triggers**:
1. **travel-domino-dev** - MUST read `E:\Travel\skills\travel-domino-dev\SKILL.md` when:
   - Any code modification task (bug fix, feature, refactor, UI change)
   - Follow Pre-Code Alignment Gate strictly before coding

2. **skills-workbench** - MUST read `E:\Travel\skills\skills-workbench\SKILL.md` when:
   - User requests retrospective/review ("复盘", "总结", "回顾")
   - User asks to manage/update/list skills
   - After completing complex multi-step tasks and needing evolution persistence

3. **app-size-pruner** - Read `E:\Travel\skills\app-size-pruner\SKILL.md` when:
   - User asks to optimize app size or analyze HAP size

**Execution**: After reading skill file, strictly follow all rules and workflows defined within.
