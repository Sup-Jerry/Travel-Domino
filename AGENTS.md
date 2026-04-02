# AGENTS.md instructions for E:\T

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used in this project.

### Available skills
- bat: Windows batch/cmd automation helpers. (file: E:/T/.codex/skills/bat/SKILL.md)
- github-to-skills: Convert/install GitHub resources into reusable skills. (file: E:/T/.codex/skills/github-to-skills/SKILL.md)
- skill-evolution-manager: Review and evolve existing skills from usage feedback. (file: E:/T/.codex/skills/skill-evolution-manager/SKILL.md)
- skill-manager: Skill inventory and lifecycle management workflows. (file: E:/T/.codex/skills/skill-manager/SKILL.md)
- travel-domino-dev: Domain workflow for this travel timeline project. (file: E:/T/.codex/skills/travel-domino-dev/SKILL.md)

### How to use skills
- Discovery: The list above is the skills available in this session (name + description + file path).
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description, you must use that skill for that turn.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill:
  1. Open its `SKILL.md` and read only what is needed.
  2. Resolve relative paths from the skill directory first.
  3. Load only referenced files needed for the task.
  4. Reuse scripts/templates/assets provided by the skill whenever possible.

## User preferences
- GitHub submissions must go directly to `main`.
- Do not create or submit feature branches unless the user explicitly asks for it.

任何密码、密钥、签名信息，都不写进 Git 跟踪文件。
开发环境和构建环境都不用手填真实秘密到仓库文件中
