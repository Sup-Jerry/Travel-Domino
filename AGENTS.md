# AGENTS.md instructions for E:\Travel12.19

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used in this project.

### Available skills
- bat: Windows batch/cmd automation helpers. (file: E:/Travel12.19/.codex/skills/bat/SKILL.md)
- github-to-skills: Convert/install GitHub resources into reusable skills. (file: E:/Travel12.19/.codex/skills/github-to-skills/SKILL.md)
- skill-evolution-manager: Review and evolve existing skills from usage feedback. (file: E:/Travel12.19/.codex/skills/skill-evolution-manager/SKILL.md)
- skill-manager: Skill inventory and lifecycle management workflows. (file: E:/Travel12.19/.codex/skills/skill-manager/SKILL.md)
- travel-domino-dev: Domain workflow for this travel timeline project. (file: E:/Travel12.19/.codex/skills/travel-domino-dev/SKILL.md)

### How to use skills
- Discovery: The list above is the skills available in this session (name + description + file path).
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description, you must use that skill for that turn.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill:
  1. Open its `SKILL.md` and read only what is needed.
  2. Resolve relative paths from the skill directory first.
  3. Load only referenced files needed for the task.
  4. Reuse scripts/templates/assets provided by the skill whenever possible.
