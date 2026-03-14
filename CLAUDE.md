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

## Skills available for this repo (13 enabled, yt-dlp excluded)
When user explicitly names a skill, or task clearly matches its description, use that skill workflow.

1. Skill Evolution Manager  
   Path: `C:/Users/Reaper/.codex/skills/skill-evolution-manager-workspace/skill-snapshot-20260311_101857/SKILL.md`
2. app-architecture-planning  
   Path: `C:/Users/Reaper/.codex/skills/travel-architecture-foresight/SKILL.md`
3. app-preflight-planner  
   Path: `C:/Users/Reaper/.codex/skills/app-preflight-planner/SKILL.md`
4. bat  
   Path: `C:/Users/Reaper/.codex/skills/bat/SKILL.md`
5. github-to-skills  
   Path: `C:/Users/Reaper/.codex/skills/github-to-skills/SKILL.md`
6. requests  
   Path: `C:/Users/Reaper/.codex/skills/github-to-skills-workspace/smoke/requests/SKILL.md`
7. skill-evolution-manager  
   Path: `C:/Users/Reaper/.codex/skills/skill-evolution-manager/SKILL.md`
8. skill-manager  
   Path: `C:/Users/Reaper/.codex/skills/skill-manager/SKILL.md`
9. software-lifecycle-ops  
   Path: `C:/Users/Reaper/.codex/skills/software-lifecycle-ops/SKILL.md`
10. travel-domino-dev  
    Path: `C:/Users/Reaper/.codex/skills/travel-domino-dev/SKILL.md`
11. openai-docs  
    Path: `C:/Users/Reaper/.codex/skills/.system/openai-docs/SKILL.md`
12. skill-creator  
    Path: `C:/Users/Reaper/.codex/skills/.system/skill-creator/SKILL.md`
13. skill-installer  
    Path: `C:/Users/Reaper/.codex/skills/.system/skill-installer/SKILL.md`

## Skill usage rules
- Trigger: use named skill(s) first; if unnamed, select by semantic match.
- Multiple skills: choose minimal covering set and state execution order briefly.
- Progressive read: open `SKILL.md` first, then only load referenced files as needed.
- If a skill path is missing/unreadable, state it briefly and continue with best fallback.
- Explicitly disabled in this repo: `yt-dlp`.
