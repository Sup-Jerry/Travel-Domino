# Skill 体系审计报告

审计日期：2026-04-17

审计范围：
- 项目本地：`E:\Travel\skills\`
- 用户全局：`C:\Users\Reaper\.codex\skills\`
- 插件缓存：`C:\Users\Reaper\.codex\plugins\cache\openai-curated\github\...\skills\`
- 全局规则与边界文件：[AGENTS.md](/E:/Travel/AGENTS.md) 、[CLAUDE.md](/E:/Travel/CLAUDE.md)

客观样本：
- 共扫描 `107` 份 `SKILL.md`
- 去重后有 `96` 个 skill 名称
- 存在 `11` 组同名冲突：`bat`、`github-to-skills`、`high-bar-project-scoring`、`skill-evolution-manager`、`skill-manager`、`travel-domino-dev`、`gh-address-comments`、`gh-fix-ci`、`yeet`、`imagegen`、`openai-docs`
- 项目本地真实 skill 数量是 `9` 个，但 [CLAUDE.md](/E:/Travel/CLAUDE.md) 仍写 `6` 个，本地说明已漂移

## 1. 总体结论

结论很明确：当前 skill 库顶层数量明显偏多，且不是“能力丰富”，而是“分类层级失控”。

主要问题有 6 类：
- 顶层过细：同一大类被拆成多个平级 skill，最明显的是 `figma` 家族、`deepscientist` 家族、工程流程家族、Notion 家族、部署家族。
- 同名冲突：同一个 skill 名称在 `project/global/plugin` 出现多份定义，直接破坏触发稳定性。
- 文件类型重复建模：`doc/docx`、`pdf/anthropics-pdf`、`pptx/slides`、`spreadsheet/xlsx` 都在抢同一触发。
- 流程类 skill 过多：大量 skill 其实是“做事原则/子步骤”，更适合合并成总 skill 或下沉到 `AGENTS.md`。
- 边界漂移：项目规则、Git 流程、历史复盘、故障复盘、任务顺序等内容，混进了多个 skill 和 `CLAUDE.md`，维护成本高且易漂移。
- 无效或低信号 skill：`claude-mem`、`do`、`make-plan`、`pua`、`using-superpowers`、`web-access` 不适合作为当前体系里的独立顶层 skill。

总体判断：
- 当前 skill 总量：偏多，且超出“分类学”合理颗粒度
- 过度封装：明显存在
- 边界重叠：大面积存在
- 触发体系：目前不稳定，尤其是同名冲突和家族重叠
- 维护成本：明显偏高
- 是否建议收缩：是，建议把“可直接触发的顶层 skill”从当前 `96` 个概念收缩到约 `30-35` 个

最值得优先处理的不是“重写内容”，而是“先减实体”：
- 先消灭同名冲突
- 再合并明显的家族过拆
- 最后才做触发文案重写和内容瘦身

## 同名冲突清单

| 冲突名 | 当前情况 | 风险判断 | 建议 |
|---|---|---|---|
| `bat` | project + global | 中 | 只保留 1 份 canonical |
| `github-to-skills` | project + global | 高 | 并入同一个 skill authoring 入口 |
| `high-bar-project-scoring` | project + global | 高 | 不应双份存在；更建议降级为 rubric 文档 |
| `skill-evolution-manager` | project + global | 高 | 只能有 1 个 canonical；项目特化不要靠同名复制 |
| `skill-manager` | project + global | 高 | 只能有 1 个 canonical |
| `travel-domino-dev` | project + global | 高 | 项目专 skill 不应在全局同名再放一份 |
| `gh-address-comments` | global + plugin | 高 | 只保留插件版为真正实现 |
| `gh-fix-ci` | global + plugin | 高 | 只保留插件版为真正实现 |
| `yeet` | global + plugin | 高 | 只保留插件版或并入 `github` |
| `imagegen` | global + `.system` | 中 | 只保留 system canonical |
| `openai-docs` | global + `.system` | 中 | 只保留 system canonical |

## 2. 逐个 skill 审查表

说明：
- `边界清晰`：清晰 / 一般 / 差
- `是否高频`：高 / 中 / 低
- `重叠`：高 / 中 / 低
- `是否应独立存在`：是 / 否

### 2.1 技能系统与项目本地

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `app-size-pruner` | 安全清理可再生产物 | 瘦身、清缓存、清日志 | 清晰 | 中高 | 低 | 是 | 保留 | 目标单一、脚本化、误触发低 | - |
| `bat` | Windows 下高亮看文件 | 用户明确要 `bat` 或高亮查看 | 清晰 | 中 | 中 | 是 | 保留一份 | `project/global` 同名；能力单一但有效 | 保留 `global:bat` |
| `github-to-skills` | 从 GitHub 仓库生成 skill 包装 | 用户给 repo 并要求转 skill | 一般 | 低中 | 高 | 否 | 合并 | 属于 skill 生命周期的一个入口，不该单飞 | `skills-workbench` |
| `high-bar-project-scoring` | 严格项目打分 | 用户要求评分、评级、排序 | 清晰 | 低 | 高 | 否 | 降级到文档 | 更像 rubric，不像顶层能力；还存在 project/global 双份 | `review`/rubric 文档 |
| `large-file-split-migration` | 大文件保守拆分策略 | 拆巨型文件、保守迁移 | 一般 | 低 | 中高 | 否 | 合并 | 这是重构子策略，不是稳定顶层类别 | `travel-domino-dev` 或 `plan-driven-development` |
| `skill-evolution-manager` | 沉淀 skill 经验 | 复盘、迭代、把经验写回 skill | 清晰 | 中 | 高 | 否 | 合并并瘦身 | 能力有价值，但当前与 `skill-manager`/`writing-skills` 边界缠绕，且项目版过重 | `skills-workbench` |
| `skill-manager` | 盘点、升级、删除 skills | 列表、检查更新、删除 skill | 清晰 | 中 | 高 | 否 | 合并 | 当前只覆盖 lifecycle 一部分，适合作为总入口的一条分支 | `skills-workbench` |
| `travel-domino-dev` | Travel Domino 项目定向开发 | 本项目改代码、调 ArkTS/HarmonyOS | 清晰 | 高 | 中 | 是 | 保留，删除全局同名副本 | 项目域边界明确、频率高，但不应与全局同名共存 | - |
| `unit-test-case-generator` | 生成/补齐工程化单测 | 写、补、审查单测 | 清晰 | 中高 | 中 | 是 | 保留 | 测试任务边界稳定，和 TDD 不是一回事 | - |
| `plugin-creator` | 创建 Codex 插件骨架 | 用户明确要创建插件 | 清晰 | 低 | 高 | 否 | 合并 | 属于 skill/plugin authoring 体系，不必单列在顶层 | `skills-workbench` |
| `skill-creator` | 创建/更新 skill | 用户要创建新 skill | 清晰 | 中 | 高 | 否 | 合并 | 是 authoring 总类的一部分，和 installer/evolution/github import 重叠 | `skills-workbench` |
| `skill-installer` | 安装 skill | 列 installable skill、安装 skill | 清晰 | 中 | 高 | 否 | 合并 | 与 manager 边界天然连续，不需平级 | `skills-workbench` |
| `writing-skills` | 用 TDD 方法写/验 skill | 写 skill、改 skill、验 skill | 一般 | 低中 | 高 | 否 | 合并 | 更像 skill authoring 的内部方法论 | `skills-workbench` |
| `using-superpowers` | 强制先查 skill 再行动 | 任意对话一开始 | 差 | 高 | 高 | 否 | 降级到系统规则 | 它不是用户任务分类，而是元规则；放成 skill 会污染触发层 | `AGENTS.md` / 系统规则 |

### 2.2 工程流程与交付

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `brainstorming` | 需求澄清与设计前置 | 新功能、创意工作前 | 一般 | 中高 | 高 | 否 | 合并 | 与 `writing-plans` 是前后阶段，不是两类顶层任务 | `plan-driven-development` |
| `writing-plans` | 把 spec 转为实施计划 | 有 spec、准备开工 | 清晰 | 中高 | 高 | 否 | 合并 | 计划只是开发总流程的中间相位 | `plan-driven-development` |
| `executing-plans` | 按既定计划执行 | 已有 plan，准备实施 | 清晰 | 中 | 高 | 否 | 合并 | 与写计划、并行执行、收尾高度连续 | `plan-driven-development` |
| `dispatching-parallel-agents` | 并行派发独立子任务 | 多个独立问题并行处理 | 一般 | 中 | 高 | 否 | 合并 | 这是执行策略，不是用户意图类别 | `plan-driven-development` |
| `subagent-driven-development` | 用子代理执行计划 | 有 plan 且任务独立 | 一般 | 中 | 高 | 否 | 合并 | 也是执行策略；和 `executing-plans` 强重叠 | `plan-driven-development` |
| `using-git-worktrees` | 为特性开发建隔离工作区 | feature 开发前、执行计划前 | 一般 | 中 | 中高 | 否 | 合并 | 属于交付前置步骤，不该独立抢触发 | `plan-driven-development` |
| `finishing-a-development-branch` | 完成开发分支收尾 | 测试通过后收尾、合并、PR | 清晰 | 中 | 高 | 否 | 合并 | 是开发流程最后一步，不是独立类别 | `plan-driven-development` |
| `requesting-code-review` | 请求代码评审 | 大任务后、合并前 | 一般 | 中 | 高 | 否 | 合并 | 是交付流程子步骤 | `plan-driven-development` |
| `receiving-code-review` | 接收并处理评审意见 | 收到 review comment | 清晰 | 中 | 高 | 否 | 合并 | 和 GitHub review 处理、交付流程天然连续 | `plan-driven-development` |
| `test-driven-development` | 先写失败测试再写实现 | 任何 feature / bugfix | 差 | 高 | 高 | 否 | 降级到全局规则 | 触发过宽，几乎与所有实现类 skill 抢触发；更适合作为方法论规则 | `AGENTS.md` / `plan-driven-development` 内规 |
| `verification-before-completion` | 完成前强制验证 | 声称完成前 | 差 | 高 | 高 | 否 | 降级到全局规则 | 这是质量门禁，不是任务类别 | `AGENTS.md` / 交付门禁 |
| `systematic-debugging` | 根因优先的调试流程 | bug、构建失败、异常行为 | 清晰 | 高 | 中 | 是 | 保留 | “调试”是稳定高频任务类别，应该独立存在 | - |

### 2.3 设计、Figma 与前端

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `figma` | Figma MCP 读设计并转代码 | Figma URL、节点、设计转代码 | 一般 | 中高 | 高 | 是 | 保留并重写为总 skill | 适合作为 Figma 总入口，但不该和 7 个子 skill 并列抢触发 | - |
| `figma-use` | `use_figma` 写操作前置规则 | 写 Figma、调用 plugin API | 一般 | 中 | 高 | 否 | 下沉为内部前置分支 | 本质是 `figma` 的 mandatory protocol，不是用户意图 | `figma` |
| `figma-implement-design` | 从 Figma 实现产品代码 | 用户要从 Figma 落代码 | 一般 | 中 | 高 | 否 | 合并 | 这是 `figma` 内部的 “design-to-code” 路由 | `figma` |
| `figma-generate-design` | 从代码/描述写回 Figma screen | 写 Figma 页面/界面 | 一般 | 中 | 高 | 否 | 合并 | 是 `figma` 的 “code-to-figma” 路由 | `figma` |
| `figma-generate-library` | 在 Figma 建设计系统 | 建 tokens / library / variants | 清晰 | 低中 | 高 | 否 | 合并 | 是 `figma` 的 design-system 路由 | `figma` |
| `figma-code-connect-components` | 建 Code Connect 映射 | code connect / map component | 清晰 | 低中 | 中高 | 否 | 合并 | 路由很明确，但仍属于 Figma 体系子分支 | `figma` |
| `figma-create-design-system-rules` | 生成 Figma-to-code 规则 | create design system rules | 一般 | 低 | 高 | 否 | 合并 | 更像 design-system 产物生成步骤，不必平级 | `figma` |
| `figma-create-new-file` | 创建空白 Figma 文件 | 明确要新建 Figma/FigJam | 清晰 | 低 | 中高 | 否 | 合并 | 只是 Figma 写操作前置动作 | `figma` |
| `frontend-design` | 高质量前端设计与实现 | 做页面、组件、站点、UI | 清晰 | 高 | 高 | 是 | 保留 | 这是稳定高频类别；应作为唯一前端视觉类总入口 | - |
| `frontend-skill` | 强调视觉构图和节制 | landing page / strong UI | 差 | 中 | 高 | 否 | 合并 | 与 `frontend-design` 触发几乎同义，只是风格补充 | `frontend-design` |
| `develop-web-game` | Web game 开发与测试闭环 | 做/改 web game | 清晰 | 低中 | 中 | 是 | 保留 | 场景边界极清晰，且带独特验证 loop | - |
| `imagegen` | 生成/编辑位图图像 | 生成图片、改图 | 清晰 | 中 | 中 | 是 | 保留一份 canonical | 触发稳定，但 `global/.system` 双份无意义 | 保留 `.system:imagegen` |

### 2.4 文档、文件与媒体

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `doc` | 用 `python-docx` 处理 `.docx` | 读/写/改 DOCX | 差 | 中 | 高 | 否 | 合并 | 与 `docx` 触发几乎完全重叠 | `docx` |
| `docx` | Word 文档完整处理 | 提到 Word/.docx/报告/模板 | 清晰 | 中高 | 高 | 是 | 保留 | 文件类型边界稳定，适合作为唯一 DOCX skill | - |
| `pdf` | 布局敏感的 PDF 处理 | 读/写/审 PDF | 清晰 | 中高 | 高 | 是 | 保留 | 应作为唯一 PDF 总 skill | - |
| `anthropics-pdf` | 更广义的 PDF 处理 | 任何 PDF 相关任务 | 差 | 中 | 高 | 否 | 删除/合并 | 与 `pdf` 完全抢触发，没有独立价值 | `pdf` |
| `pptx` | 泛化的 PowerPoint 操作 | deck/slides/presentation/.pptx | 差 | 中 | 高 | 否 | 合并 | 与 `slides` 抢同一文件类型，且更宽更易误触发 | `slides` |
| `slides` | 用 PptxGenJS 创建/编辑演示文稿 | 新建/编辑 deck、复刻 slides | 清晰 | 中 | 高 | 是 | 保留 | 文件类型清晰，且方法更工程化 | - |
| `spreadsheet` | 表格创建/编辑/分析 | `.xlsx/.csv/.tsv` | 清晰 | 中高 | 高 | 是 | 保留 | 应作为唯一 spreadsheet 总 skill | - |
| `xlsx` | 更细的 Excel/表格处理 | 提到 xlsx/xlsm/csv/tsv | 差 | 中 | 高 | 否 | 合并 | 与 `spreadsheet` 几乎等价，只是展开更细 | `spreadsheet` |
| `playwright` | 浏览器自动化 | 导航、填表、抓图、调 UI 流 | 清晰 | 中高 | 中 | 是 | 保留 | 浏览器自动化是稳定任务类型 | - |
| `playwright-interactive` | 持久化交互式浏览器调试 | 持续浏览器/Electron 调试 | 一般 | 中 | 高 | 否 | 合并 | 是 `playwright` 的 interactive 模式，不必平级 | `playwright` |
| `screenshot` | 系统级截图 | 明确要桌面/窗口/区域截图 | 清晰 | 中 | 低 | 是 | 保留 | 目标单一，误触发低 | - |
| `speech` | 文本转语音 | narration、voiceover、batch TTS | 清晰 | 低中 | 低 | 是 | 保留 | 任务边界清晰 | - |
| `transcribe` | 音视频转录 | transcribe、label speakers | 清晰 | 中 | 低 | 是 | 保留 | 任务边界清晰 | - |
| `sora` | AI 视频生成/编辑 | 生成、编辑、延长 Sora 视频 | 清晰 | 低中 | 低 | 是 | 保留 | 明确依赖和产出类型 | - |
| `yt-dlp` | 下载在线视频/音频 | 给视频 URL 要下载 | 清晰 | 中 | 低 | 是 | 保留 | 触发稳定且低歧义 | - |
| `jupyter-notebook` | 新建/改 notebook | `.ipynb` 相关任务 | 清晰 | 中 | 低 | 是 | 保留 | 文件类型边界稳定 | - |

### 2.5 集成、GitHub、Notion 与部署

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `github` | GitHub 总入口与 triage | PR/issue/repo/GitHub help | 清晰 | 高 | 中 | 是 | 保留 | 它已经是合理 umbrella，应该吸收子 skill | - |
| `gh-address-comments` | 处理 PR review comments | review thread / requested changes | 清晰 | 中 | 高 | 否 | 合并 | 适合作为 `github` 内部 route；global/plugin 双份更糟 | `github` |
| `gh-fix-ci` | 调 GitHub Actions 失败 | PR checks/CI failed | 清晰 | 中 | 高 | 否 | 合并 | 适合作为 `github` 内部 route；global/plugin 双份更糟 | `github` |
| `yeet` | commit/push/开 PR | 明确要一条龙发布到 GitHub | 清晰 | 中 | 高 | 否 | 合并 | 适合作为 `github` 的 publish 分支；global/plugin 双份冲突 | `github` |
| `notion-knowledge-capture` | 把对话沉淀成 Notion 页面 | wiki/how-to/FAQ/decision | 一般 | 中 | 高 | 否 | 合并 | 4 个 Notion skill 共享同一连接与模板体系 | `notion-workflows` |
| `notion-meeting-intelligence` | 准备会议材料 | agenda/pre-read/meeting prep | 清晰 | 中 | 高 | 否 | 合并 | 仍是 Notion 内容工作流的一个分支 | `notion-workflows` |
| `notion-research-documentation` | 从 Notion 汇总成报告 | brief/comparison/report | 一般 | 中 | 高 | 否 | 合并 | 与 capture/spec 共享准备动作与模板 | `notion-workflows` |
| `notion-spec-to-implementation` | 把 Notion spec 变任务/计划 | 读 PRD，建 plan/tasks | 清晰 | 中 | 高 | 否 | 合并 | 仍是 Notion 工作流的一个子路由 | `notion-workflows` |
| `linear` | 读写 Linear ticket | 读、建、改 issue/project | 清晰 | 中 | 低 | 是 | 保留 | 集成边界清晰 | - |
| `sentry` | 读 Sentry issue/event | 查看生产错误与健康数据 | 清晰 | 中 | 低 | 是 | 保留 | 集成边界清晰 | - |
| `cloudflare-deploy` | 部署到 Cloudflare | deploy/publish on Cloudflare | 清晰 | 低中 | 高 | 否 | 合并 | 4 个 provider skill 共享“部署”主意图，应先路由 provider | `deploy-hosting` |
| `netlify-deploy` | 部署到 Netlify | deploy/publish on Netlify | 清晰 | 低中 | 高 | 否 | 合并 | 同上 | `deploy-hosting` |
| `render-deploy` | 部署到 Render | deploy/publish on Render | 清晰 | 低中 | 高 | 否 | 合并 | 同上 | `deploy-hosting` |
| `vercel-deploy` | 部署到 Vercel | deploy/publish on Vercel | 清晰 | 中 | 高 | 否 | 合并 | 同上 | `deploy-hosting` |
| `web-access` | 一切联网行为总管 | 搜索、抓取、登录后操作 | 差 | 高 | 高 | 否 | 删除/降级 | 触发过宽，且当前实现强绑定特定浏览器代理，不适合作为顶层 taxonomy | 工具文档 / 站点模式文档 |

### 2.6 平台、规划、安全与其他

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `app-preflight-planner` | 新应用预检与范围澄清 | 新建应用、先别写代码、需求梳理 | 清晰 | 中 | 高 | 否 | 合并 | 与架构规划、生命周期治理是同一上位流程 | `app-planning` |
| `travel-architecture-foresight` | 应用架构规划 | 架构设计、模块边界、DDD 等 | 清晰 | 中 | 高 | 否 | 合并 | 名称和描述已不一致，本质是 `app-planning` 第二阶段 | `app-planning` |
| `software-lifecycle-ops` | 生命周期门禁与治理 | 全流程、门禁、验收、回滚 | 一般 | 低中 | 高 | 否 | 合并/降级 | 更像流程门禁，不适合作为平级顶层 skill | `app-planning` 或 `AGENTS.md` |
| `aspnet-core` | ASP.NET Core 专项 | .NET Web 开发/评审/升级 | 清晰 | 中 | 低 | 是 | 保留 | 技术栈边界稳定 | - |
| `winui-app` | WinUI 3 专项 | 创建/维护 WinUI 应用 | 清晰 | 低中 | 低 | 是 | 保留 | 技术栈边界稳定 | - |
| `openai-docs` | OpenAI 官方文档检索 | OpenAI API/产品/模型 | 清晰 | 中高 | 中 | 是 | 保留一份 canonical | 触发稳定，但 `global/.system` 双份无意义 | 保留 `.system:openai-docs` |
| `chatgpt-apps` | ChatGPT Apps SDK 开发 | Apps SDK、MCP server + widget | 清晰 | 低中 | 中 | 是 | 保留 | 产品域边界清晰，且需要 docs-first | - |
| `security-best-practices` | 安全最佳实践审查 | 显式安全评审/secure-by-default | 清晰 | 中 | 低中 | 是 | 保留 | 任务边界明确，且触发收得够窄 | - |
| `security-ownership-map` | 安全所有权拓扑分析 | 敏感代码 ownership / bus factor | 清晰 | 低 | 低 | 是 | 保留 | 专门任务，边界清晰 | - |
| `security-threat-model` | 代码库威胁建模 | threat model / abuse path | 清晰 | 低中 | 低 | 是 | 保留 | 专门任务，边界清晰 | - |
| `pua` | 高压互动风格切换 | 用户抱怨、要求更高强度 | 差 | 低 | 高 | 否 | 删除/降级 | 这不是任务分类，而是交互风格，不应以 skill 暴露 | 交互策略说明 |

### 2.7 DeepScientist 家族

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `deepscientist-scout` | 研究问题 framing 与资料搜寻 | 任务不清、指标/数据集不清 | 一般 | 低中 | 高 | 否 | 合并 | 这是研究工作流早期阶段，不该平级暴露 | `deepscientist` |
| `deepscientist-intake-audit` | 盘点已有 baseline/草稿/材料 | 从非空状态接手研究 | 一般 | 低 | 高 | 否 | 合并 | 仍是早期 intake 阶段 | `deepscientist` |
| `deepscientist-baseline` | 建立/修复 baseline | attach/import/reproduce baseline | 清晰 | 低中 | 高 | 否 | 合并 | 研究执行阶段的一个路由 | `deepscientist` |
| `deepscientist-idea` | 产出 candidate idea | 需要假设、候选方向 | 一般 | 低中 | 高 | 否 | 合并 | 研究执行前期的内部路由 | `deepscientist` |
| `deepscientist-experiment` | 主实验执行 | main run / implementation pass | 清晰 | 低中 | 高 | 否 | 合并 | 研究执行核心阶段，不必单独顶层 | `deepscientist` |
| `deepscientist-analysis-campaign` | 补实验/稳健性/消融 | follow-up runs / ablations | 一般 | 低 | 高 | 否 | 合并 | 是 experiment 的后续分支 | `deepscientist` |
| `deepscientist-optimize` | 候选优化与 frontier 管理 | algorithm-first optimize | 一般 | 低 | 高 | 否 | 合并 | 仍是研究执行策略，不应单独顶层 | `deepscientist` |
| `deepscientist-figure-polish` | 研究图表打磨 | paper/milestone figure polish | 清晰 | 低 | 高 | 否 | 合并 | 是写作/报告的子步骤 | `deepscientist` |
| `deepscientist-write` | 研究写作 | paper/report/research summary | 清晰 | 低中 | 高 | 否 | 合并 | 是研究后期写作相位 | `deepscientist` |
| `deepscientist-review` | 内部研究审稿 | harsh review / audit draft | 清晰 | 低 | 高 | 否 | 合并 | 是写作后期的审查相位 | `deepscientist` |
| `deepscientist-rebuttal` | reviewer response / revision | review package / rebuttal | 清晰 | 低 | 高 | 否 | 合并 | 是研究后期 revision 相位 | `deepscientist` |
| `deepscientist-finalize` | 研究结案 | final claims / recommendations | 一般 | 低 | 高 | 否 | 合并 | 研究结束阶段，不必独立顶层 | `deepscientist` |
| `deepscientist-decision` | 研究流程决策节点 | go/stop/branch/write/finalize | 差 | 中 | 高 | 否 | 合并 | 这是跨阶段控制逻辑，不是用户任务分类 | `deepscientist` |

### 2.8 明显无效或信息不足

| Skill 名称 | 当前职责 | 主要触发场景 | 边界清晰 | 是否高频 | 是否重叠 | 是否应独立存在 | 建议动作 | 原因 | 可合并目标 |
|---|---|---|---|---|---|---|---|---|---|
| `claude-mem` | 实际是插件安装说明 | 无稳定触发 | 差 | 低 | 高 | 否 | 删除/隔离 | 不是正常 SKILL 元数据与触发文档；更像 README | 插件文档 |
| `do` | 占位空 skill | 不明 | 差 | 低 | 高 | 否 | 删除 | 只有 1 行，无触发、无职责 | - |
| `make-plan` | 占位空 skill | 不明 | 差 | 低 | 高 | 否 | 删除 | 只有 1 行，无触发、无职责 | - |

## 3. 合并建议

### 3.1 Skill authoring / lifecycle 家族

- 应合并的 skill：`skill-manager`、`skill-evolution-manager`、`skill-creator`、`skill-installer`、`writing-skills`、`github-to-skills`、`plugin-creator`
- 建议合并后的新 skill 名称：`skills-workbench`
- 合并原因：这 7 个 skill 都属于“管理/创建/导入/演进 skill 或 plugin”的同一上位类，目前是按子步骤拆成平级，顶层过细
- 合并后的职责边界：只负责“技能体系本身”的生命周期；内部再分为 `inventory`、`install`、`create`、`import-from-github`、`evolve`、`plugin-scaffold`
- 合并后的触发方式应该怎么写：当用户要盘点/安装/创建/升级/迁移/沉淀 skill 或 plugin 时触发
- 下沉为内部子场景的内容：GitHub 导入、插件脚手架、写作方法论、evolution 持久化

### 3.2 工程流程家族

- 应合并的 skill：`brainstorming`、`writing-plans`、`executing-plans`、`dispatching-parallel-agents`、`subagent-driven-development`、`using-git-worktrees`、`finishing-a-development-branch`、`requesting-code-review`、`receiving-code-review`
- 建议合并后的新 skill 名称：`plan-driven-development`
- 合并原因：它们不是不同“任务类型”，而是同一开发生命周期的不同步骤或执行策略
- 合并后的职责边界：负责从需求澄清、计划生成、执行策略、代码评审到分支收尾的完整流程编排
- 合并后的触发方式应该怎么写：当用户要按计划开发、从 spec 到实现、或需要多步骤开发编排时触发
- 下沉为内部子场景的内容：并行派发、worktree、code review、finish branch

### 3.3 Figma 家族

- 应合并的 skill：`figma`、`figma-use`、`figma-implement-design`、`figma-generate-design`、`figma-generate-library`、`figma-code-connect-components`、`figma-create-design-system-rules`、`figma-create-new-file`
- 建议合并后的新 skill 名称：`figma`
- 合并原因：它们共用同一 MCP、同一上下文、同一前置校验，当前拆分导致 Figma URL 类请求极易多 skill 争抢
- 合并后的职责边界：统一处理 Figma 读设计、写 Figma、设计系统、Code Connect、文件创建
- 合并后的触发方式应该怎么写：当任务涉及 Figma URL、节点、Figma 文件读写或 Figma-to-code / code-to-Figma 时触发
- 下沉为内部子场景的内容：`use_figma` 规则、screen generation、library generation、code connect、新建文件

### 3.4 文档文件类型家族

- 应合并的 skill：`doc` + `docx`
- 建议合并后的新 skill 名称：`docx`
- 合并原因：同一文件类型、同一触发、方法差异应是内部实现分支
- 合并后的职责边界：所有 Word 文档任务
- 合并后的触发方式应该怎么写：提到 Word / `.docx` / 报告 / 模板 / DOCX 编辑时触发
- 下沉为内部子场景的内容：结构化编辑、视觉检查、低层 XML 修复

- 应合并的 skill：`pdf` + `anthropics-pdf`
- 建议合并后的新 skill 名称：`pdf`
- 合并原因：完全同类，宽窄重复
- 合并后的职责边界：所有 PDF 读写、抽取、生成、表单、OCR、合并拆分
- 合并后的触发方式应该怎么写：提到 `.pdf` 或要求产出/修改 PDF 时触发
- 下沉为内部子场景的内容：布局校验、表单填充、OCR、文本抽取

- 应合并的 skill：`pptx` + `slides`
- 建议合并后的新 skill 名称：`slides`
- 合并原因：同一文件类型；`pptx` 更像总类，`slides` 是更工程化实现
- 合并后的职责边界：所有 PowerPoint deck 相关任务
- 合并后的触发方式应该怎么写：提到 deck/slides/presentation/.pptx 时触发
- 下沉为内部子场景的内容：模板编辑、PptxGenJS 生成、复刻、渲染检查

- 应合并的 skill：`spreadsheet` + `xlsx`
- 建议合并后的新 skill 名称：`spreadsheet`
- 合并原因：同一文件类型家族，触发几乎一致
- 合并后的职责边界：所有工作簿与表格文件任务
- 合并后的触发方式应该怎么写：提到 `.xlsx/.xlsm/.csv/.tsv` 或要求产出表格文件时触发
- 下沉为内部子场景的内容：分析、重算、可视化、格式修复

### 3.5 GitHub 家族

- 应合并的 skill：`github`、`gh-address-comments`、`gh-fix-ci`、`yeet`
- 建议合并后的新 skill 名称：`github`
- 合并原因：插件版 `github` 已经天然是 umbrella；其余三个只是内部路由
- 合并后的职责边界：GitHub triage、review 跟进、CI 排查、发布 PR
- 合并后的触发方式应该怎么写：当用户明确提 GitHub、PR、issue、review、checks、publish 时触发
- 下沉为内部子场景的内容：review-comments、fix-ci、publish

### 3.6 Notion 家族

- 应合并的 skill：`notion-knowledge-capture`、`notion-meeting-intelligence`、`notion-research-documentation`、`notion-spec-to-implementation`
- 建议合并后的新 skill 名称：`notion-workflows`
- 合并原因：都是同一 MCP、同一数据源、同一模板体系下的内容工作流
- 合并后的职责边界：Notion 中的沉淀、会议、研究、spec 落任务
- 合并后的触发方式应该怎么写：用户要在 Notion 里创建/更新文档、会议材料、研究摘要或实施任务时触发
- 下沉为内部子场景的内容：capture、meeting、research、spec-to-implementation

### 3.7 部署家族

- 应合并的 skill：`cloudflare-deploy`、`netlify-deploy`、`render-deploy`、`vercel-deploy`
- 建议合并后的新 skill 名称：`deploy-hosting`
- 合并原因：用户高层意图是“部署/上线”，provider 只是内部路由；当前 4 个 skill 会在泛化 deploy 请求上互抢
- 合并后的职责边界：统一处理托管部署，并先路由 provider
- 合并后的触发方式应该怎么写：当用户要部署/发布项目时触发；若已明确 provider，直接走对应子路由
- 下沉为内部子场景的内容：Cloudflare、Netlify、Render、Vercel

### 3.8 应用规划家族

- 应合并的 skill：`app-preflight-planner`、`travel-architecture-foresight`、`software-lifecycle-ops`
- 建议合并后的新 skill 名称：`app-planning`
- 合并原因：它们本质上是同一规划链路的 3 个阶段，不应顶层平级
- 合并后的职责边界：从需求澄清、架构决策到质量门禁的一体化规划
- 合并后的触发方式应该怎么写：当用户要做新应用规划、架构方案或全流程门禁设计时触发
- 下沉为内部子场景的内容：preflight、architecture、lifecycle-gates

### 3.9 DeepScientist 家族

- 应合并的 skill：全部 `deepscientist-*`
- 建议合并后的新 skill 名称：`deepscientist`
- 合并原因：当前是研究工作流 stage machine 直接暴露到顶层；这不是分类学，而是状态机
- 合并后的职责边界：只暴露一个研究总 skill，内部再路由到 discovery、baseline、execution、analysis、writing、review、rebuttal、finalize
- 合并后的触发方式应该怎么写：当任务属于研究型 quest、实验、论文写作或 rebuttal 时触发
- 下沉为内部子场景的内容：现在所有 stage skill 全部都应下沉

### 3.10 前端视觉家族

- 应合并的 skill：`frontend-design`、`frontend-skill`
- 建议合并后的新 skill 名称：`frontend-design`
- 合并原因：两者几乎都在处理“做出强视觉前端”，只是文风不同
- 合并后的职责边界：所有高视觉质量前端与页面设计任务
- 合并后的触发方式应该怎么写：当用户要做 web UI、页面、landing page、dashboard、prototype、demo 时触发
- 下沉为内部子场景的内容：landing page art direction、app UI restraint、imagery-first composition

## 4. 删除建议

建议删除或退出顶层触发集的 skill：

| Skill | 建议 | 删除原因 |
|---|---|---|
| `using-superpowers` | 删除顶层 skill 身份 | 它是系统级元规则，不是任务分类 |
| `pua` | 删除顶层 skill 身份 | 它是互动风格，不是任务分类 |
| `claude-mem` | 删除/隔离 | 实际是安装说明，不是正常 skill |
| `do` | 删除 | 占位空文档 |
| `make-plan` | 删除 | 占位空文档 |
| `web-access` | 降级到工具文档 | 触发面覆盖所有联网任务，过宽且与当前环境工具边界不一致 |
| `doc` | 删除顶层入口 | 已被 `docx` 覆盖 |
| `anthropics-pdf` | 删除顶层入口 | 已被 `pdf` 覆盖 |
| `pptx` | 删除顶层入口 | 已被 `slides` 覆盖 |
| `xlsx` | 删除顶层入口 | 已被 `spreadsheet` 覆盖 |
| `frontend-skill` | 删除顶层入口 | 已被 `frontend-design` 覆盖 |
| `large-file-split-migration` | 降级到内部文档 | 低频重构策略，不值得独立触发 |
| `high-bar-project-scoring` | 降级到 rubric 文档 | 低频、强模板化，更适合作为 `review`/`quality` 的评分附录 |
| `global:gh-address-comments` / `global:gh-fix-ci` / `global:yeet` | 删除全局副本 | 插件版已覆盖且更合适 |
| `global:imagegen` / `global:openai-docs` | 删除公开副本 | `.system` 版已足够，双份只制造歧义 |
| `global:travel-domino-dev` | 删除或改名为泛化版本 | 项目专 skill 不应全局同名悬挂 |

## 5. 重构后的推荐分类体系

目标：减少顶层 skill 数量，让顶层只表达“任务大类”，不表达“内部步骤”。

```text
skills/
├─ project-domain/
│  ├─ travel-domino-dev
│  ├─ app-size-pruner
│  └─ unit-test-case-generator
├─ engineering/
│  ├─ plan-driven-development
│  │  ├─ brainstorm
│  │  ├─ write-plan
│  │  ├─ execute-plan
│  │  ├─ parallelize
│  │  ├─ review-incoming
│  │  ├─ review-outgoing
│  │  ├─ finish-branch
│  │  └─ worktree
│  └─ systematic-debugging
├─ skill-system/
│  └─ skills-workbench
│     ├─ inventory
│     ├─ install
│     ├─ create
│     ├─ import-from-github
│     ├─ evolve
│     └─ plugin-scaffold
├─ design/
│  ├─ frontend-design
│  ├─ figma
│  │  ├─ read-to-code
│  │  ├─ write-to-figma
│  │  ├─ design-system
│  │  ├─ code-connect
│  │  └─ new-file
│  ├─ imagegen
│  └─ develop-web-game
├─ documents/
│  ├─ docx
│  ├─ pdf
│  ├─ slides
│  ├─ spreadsheet
│  └─ jupyter-notebook
├─ browser-and-media/
│  ├─ playwright
│  │  └─ interactive
│  ├─ screenshot
│  ├─ speech
│  ├─ transcribe
│  ├─ sora
│  └─ yt-dlp
├─ integrations/
│  ├─ github
│  │  ├─ triage
│  │  ├─ review-comments
│  │  ├─ fix-ci
│  │  └─ publish
│  ├─ notion-workflows
│  │  ├─ capture
│  │  ├─ meeting
│  │  ├─ research
│  │  └─ spec-to-implementation
│  ├─ linear
│  ├─ sentry
│  ├─ bat
│  └─ deploy-hosting
│     ├─ cloudflare
│     ├─ netlify
│     ├─ render
│     └─ vercel
├─ platform/
│  ├─ openai-docs
│  ├─ chatgpt-apps
│  ├─ aspnet-core
│  ├─ winui-app
│  └─ app-planning
│     ├─ preflight
│     ├─ architecture
│     └─ lifecycle-gates
├─ security/
│  ├─ security-best-practices
│  ├─ security-threat-model
│  └─ security-ownership-map
└─ research/
   └─ deepscientist
      ├─ discovery
      ├─ baseline
      ├─ execution
      ├─ analysis
      ├─ writing
      ├─ review
      ├─ rebuttal
      └─ finalize
```

不建议再作为顶层 skill 存在的内容：
- 元规则：`using-superpowers`
- 交互风格：`pua`
- 低频策略文档：`large-file-split-migration`
- 打分 rubric：`high-bar-project-scoring`
- provider/file-type 的重复壳：`doc`、`anthropics-pdf`、`pptx`、`xlsx`、`frontend-skill`
- 占位/无效项：`claude-mem`、`do`、`make-plan`

## 6. 优先级排序

### P0：马上该处理的

1. 解决同名冲突
- 为什么优先级高：这是触发稳定性的直接杀伤项；不先清掉，同一请求会在 `project/global/plugin` 多份定义之间摇摆

2. 清理无效或不应顶层存在的 skill
- 涉及：`claude-mem`、`do`、`make-plan`、`using-superpowers`、`pua`、`web-access`
- 为什么优先级高：这些条目会污染检索面，增加误触发与维护噪音

3. 合并 4 组文件类型重复 skill
- 涉及：`doc/docx`、`pdf/anthropics-pdf`、`pptx/slides`、`spreadsheet/xlsx`
- 为什么优先级高：它们是最典型、最客观、最容易收缩的重复分类

4. 统一项目规则单一真相源
- 涉及：[AGENTS.md](/E:/Travel/AGENTS.md) 与 [CLAUDE.md](/E:/Travel/CLAUDE.md)
- 为什么优先级高：本地 skill 数量、GitHub 流程、自动触发规则已经漂移，不先收束说明文档，后续重构还会继续漂

### P1：建议近期处理的

1. 把 Figma 家族压成 1 个总 skill
- 为什么优先级高：当前是最明显的“父 skill / 子场景被做成多个平级 skill”案例

2. 把 skill authoring 家族压成 `skills-workbench`
- 为什么优先级高：`skill-manager`、`skill-evolution-manager`、`skill-creator`、`github-to-skills` 等边界已经混成一团

3. 把工程流程家族压成 `plan-driven-development`
- 为什么优先级高：当前流程类 skill 太多，会长期与所有 domain skill 冲突

4. 瘦身 `travel-domino-dev` 与 `skill-evolution-manager`
- 为什么优先级高：这两个是项目实际高频 skill，但都已经吸进过多历史约束，继续膨胀会伤害可维护性

5. 合并 GitHub、Notion、Deploy 家族
- 为什么优先级高：这三组都已经天然存在 umbrella，只是没有真正收口

### P2：可以后续再做的

1. DeepScientist 家族整体折叠成一个总 skill
- 为什么优先级高：收益很大，但改动面广，适合在前面几轮收缩后做

2. 应用规划三件套并为 `app-planning`
- 为什么优先级高：当前阶段性拆分明显，但比同名冲突的危害小

3. 把低频策略 skill 全部降级成参考文档
- 涉及：`large-file-split-migration`、`high-bar-project-scoring`
- 为什么优先级高：这是体系精修项，不是立即阻断项

4. 校正命名一致性
- 涉及：`travel-architecture-foresight` 的目录名与描述不一致、project/global 同名 skill 的命名策略
- 为什么优先级高：对可读性和长期维护有帮助，但不如结构收缩更紧迫

## 最终建议

这套 skill 库不需要“补更多 skill”，而是需要做三件事：
- 把顶层从“步骤清单”收回到“任务分类”
- 把同名冲突和文件类型重复先消掉
- 把项目规则、历史经验、脚手架细节从顶层 skill 里往下沉

如果按保守路线执行，我建议分两轮：
- 第一轮只做收口，不改太多内容：去重、删无效项、合并明显重复项
- 第二轮再做瘦身：重写 `travel-domino-dev`、`skill-evolution-manager`、Figma 总 skill、工程流程总 skill

这会比“重写全部 skill”更稳，也更符合你要的目标：少而准、边界清晰、触发稳定、维护成本低。
