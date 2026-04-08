# AGENTS.md instructions for E:\Travel

## Hard Rules (Highest Priority)
- ArkUI/ArkTS 中 @Prop **禁止承载函数类型**。事件回调必须使用普通字段（非装饰器）或通过回调对象传递。
- 修改组件属性定义时，提交前必须自检装饰器类型约束（@Prop/@State/@Link/@StorageLink），禁止再次引入函数型 @Prop。

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used in this project.

### Available skills
- bat: Windows batch/cmd automation helpers. (file: E:/Travel/skills/bat/SKILL.md)
- github-to-skills: Convert/install GitHub resources into reusable skills. (file: E:/Travel/skills/github-to-skills/SKILL.md)
- skill-evolution-manager: Review and evolve existing skills from usage feedback. (file: E:/Travel/skills/skill-evolution-manager/SKILL.md)
- skill-manager: Skill inventory and lifecycle management workflows. (file: E:/Travel/skills/skill-manager/SKILL.md)
- travel-domino-dev: Domain workflow for this travel timeline project. (file: E:/Travel/skills/travel-domino-dev/SKILL.md)

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
- 改代码：使用 `travel-domino-dev`，并结合 `skill-evolution-manager` 的迭代经验。
- 代码瘦身：使用 `app-size-pruner`。
- 上传到 GitHub：使用当前仓库已落地的 Git 治理流程（commit-msg / pre-push hooks、`scripts/git-flow.ps1`、相关 workflows）。
- Git 上传策略：默认禁止直推 `main`。必须走 `develop / feature/* / release/* / hotfix/*`，除非用户当次明确授权直推 `main`。
- Git 上传执行入口：必须优先使用 `scripts/git-auto-publish.ps1`，不要直接手工 `git push`。
- 口令触发：当用户说“上传到github / 推到github / 发布到github”（大小写、空格、中文表述近似均算）时，默认直接执行 `./scripts/git-auto-publish.ps1`。
- 口令默认参数：未额外说明时，保持自动推送并自动创建 Draft PR 到 `develop`（不加 `-NoPR`）。
- 口令例外：若用户明确说“只本地提交 / 不推送 / 不要PR”，按用户指令覆盖默认行为。
- 迭代进化：使用 `skill-evolution-manager`。

任何密码、密钥、签名信息，都不写进 Git 跟踪文件。
开发环境和构建环境都不用手填真实秘密到仓库文件中。

