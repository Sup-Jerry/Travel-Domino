# AGENTS.md instructions for E:\Travel

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used in this project.

### Available skills
- bat: Windows batch/cmd automation helpers. (file: E:/Travel/skills/bat/SKILL.md)
- github-to-skills: Convert/install GitHub resources into reusable skills. (file: E:/Travel/skills/github-to-skills/SKILL.md)
- high-bar-project-scoring: Strict project scoring workflow with very high quality bar and evidence-first deductions. (file: E:/Travel/skills/high-bar-project-scoring/SKILL.md)
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
- GitHub submissions must go directly to `main`.
- Do not create or submit feature branches unless the user explicitly asks for it.

任何密码、密钥、签名信息，都不写进 Git 跟踪文件。
开发环境和构建环境都不用手填真实秘密到仓库文件中

## AMap 集成强约束（长期规则）
- 天气与路程计算必须使用 HarmonyOS NEXT AMap SDK 方法（`@amap/amap_lbs_search` / `@amap/amap_lbs_map3d`），实现方式对齐官方文档。
- 禁止将 Web REST 作为主路径；仅在用户明确批准时才允许临时兜底，并且要在日志中标记。
- 关键入口文件：
  - `entry/src/main/ets/infrastructure/services/AmapWeatherService.ets`
  - `entry/src/main/ets/model/acl/MapServiceImpl.ets`
  - `entry/src/main/ets/infrastructure/services/AmapService.ets`
- 新增或重构地图相关逻辑时，必须先核对以下官方文档方法后再改：
  - 驾车/步行/公交/骑行路线规划
  - 地理编码与逆地理编码
  - 天气查询

## AMap SDK Integration Rules (Readable)
- Always use HarmonyOS NEXT AMap SDK methods for weather and route duration.
- Do not use AMap Web REST as the primary implementation.
- Keep weather in `entry/src/main/ets/infrastructure/services/AmapWeatherService.ets` via `WeatherSearch`.
- Keep route duration in `entry/src/main/ets/model/acl/MapServiceImpl.ets` via `RouteSearchV2` and `DriveRouteQueryV2`.
- Run `powershell -ExecutionPolicy Bypass -File scripts/guard-amap-sdk-only.ps1` before release.
