# AGENTS.md instructions for E:\Travel

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used in this project.

### Available skills
- bat: Windows batch/cmd automation helpers. (file: E:/Travel/skills/bat/SKILL.md)
- github-to-skills: Convert/install GitHub resources into reusable skills. (file: E:/Travel/skills/github-to-skills/SKILL.md)
- large-file-split-migration: 将数千行大文件按“保守迁移”方式拆分为 3-8 个职责模块，强调分批迁移、等价性验证与可回滚提交。 (file: E:/Travel/skills/large-file-split-migration/SKILL.md)
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
- 日志排查：默认不要提供 PowerShell 抓取命令，只提供日志关键词，由用户自行抓取。
- 日志前缀策略：根据实际排查链路决定，不强制固定单一前缀；给用户时仅提供本次实际使用的关键词（例如 `AI_REPLAN_TRACE`、`AI_BACKEND_TRACE`、`AUTH_TRACE`）。

## 上传到 GitHub 标准流程
1. 先确认当前分支不是 `main`（除非用户当次明确授权直推 `main`）。
2. 默认使用：
   `./scripts/git-auto-publish.ps1 -Message "<提交信息>"`
3. 只提交指定文件时，必须显式传 `-Files`，避免把未完成改动一起提交：
   `./scripts/git-auto-publish.ps1 -Message "<提交信息>" -Files "path/a","path/b"`
4. 用户说“只本地提交/不推送”时：
   `./scripts/git-auto-publish.ps1 -Message "<提交信息>" -NoPush`
5. 用户说“不要 PR”时：
   `./scripts/git-auto-publish.ps1 -Message "<提交信息>" -NoPR`
6. 若 `git-auto-publish.ps1` 不可用或异常，回退：
   `./scripts/git-flow.ps1 -Message "<提交信息>" [-Files ...] [-NoPush]`
7. 禁止直接手工裸 `git push` 作为默认流程；必须经过上述脚本入口。

任何密码、密钥、签名信息，都不写进 Git 跟踪文件。
开发环境和构建环境都不用手填真实秘密到仓库文件中。

## 本次登录故障复盘（2026-04-14）

### 现象
- 华为登录授权成功后，`/auth/social/login` 持续返回 `500`。
- 客户端日志出现 `social_login_internal_init`。
- 后端日志显示：`user "travel" password authentication failed`。
- 局部还出现 `EADDRINUSE: 3000`，导致排查过程被端口冲突干扰。

### 根因
- 非华为 SDK 问题，真实根因是 **后端连接到了错误的 PostgreSQL 实例或错误配置源**。
- Windows 本机 `postgresql-x64-16` 与 Docker PostgreSQL 并存，`localhost:5432` 指向不稳定。
- 启动流程中 env 来源不一致（会话变量 / 外部 env 文件 / 项目内 env 文件），重启后易漂移。

### 排查路径（本次实际执行）
1. 增加登录链路日志：`button -> provider -> facade -> api -> backend service`。
2. 确认华为 credential 可获取（排除 SDK 授权失败）。
3. 客户端确认请求稳定到 `/auth/social/login`，收到服务端 `requestId`。
4. 后端细化错误阶段，定位 `phase=init` 即数据库认证失败。
5. 检查端口占用，确认 `3000` 被旧 node 占用；检查 `5432` 由本机 postgres 监听而非 docker。
6. 对齐 env 与数据库密码后恢复。

### 解决动作（已验证）
- 后端错误可观测性增强：返回 `social_login_internal_<phase>` 便于定位。
- 认证链路日志前缀从 AI 语义拆分为 `AUTH_TRACE`，避免误导。
- 修复桌面启动脚本 `start-dev.ps1` 的环境加载与回退逻辑，避免使用失效路径。
- 修复脚本动态写 env 的 PowerShell 语法错误（`$env:$name` -> `Set-Item Env:`）。
- 明确规则：同一时刻仅保留一套 5432 数据库入口（本机或 docker 二选一）。

### 后续硬约束（防复发）
- 启动后端前，必须输出并核对：
  - `EnvFile` 实际路径
  - `DATABASE_URL` 的 host/port
- 日志排查优先关键词：
  - 客户端：`[LOGIN_TRACE][api] response`
  - 后端：`[AUTH_TRACE][auth_social_service_fail]`
- 若出现 `social_login_internal_init`，优先检查数据库连通与密码一致性，不先改华为登录代码。

