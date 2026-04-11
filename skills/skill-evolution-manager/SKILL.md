---
name: Skill Evolution Manager
description: 专门用于在对话结束时，根据用户反馈和对话内容总结优化并迭代现有 Skills 的核心工具。它通过吸取对话中的“精华”（如成功的解决方案、失败的教训、特定的代码规范）来持续演进 Skills 库。
license: MIT
---

# Skill Evolution Manager

这是整个 AI 技能系统的“进化中枢”。它不仅负责优化单个 Skill，还负责跨 Skill 的经验复盘和沉淀。

## 核心职责

1.  **复盘诊断 (Session Review)**：在对话结束时，分析所有被调用的 Skill 的表现。
2.  **经验提取 (Experience Extraction)**：将非结构化的用户反馈转化为结构化的 JSON 数据（`evolution.json`）。
3.  **智能缝合 (Smart Stitching)**：将沉淀的经验自动写入 `SKILL.md`，确保持久化且不被版本更新覆盖。

## 使用场景

**Trigger**: 
- `/evolve`
- "复盘一下刚才的对话"
- "我觉得刚才那个工具不太好用，记录一下"
- "把这个经验保存到 Skill 里"

## 工作流 (The Evolution Workflow)

### 1. 经验复盘 (Review & Extract)
当用户触发复盘时，Agent 必须执行：
1.  **扫描上下文**：找出用户不满意的点（报错、风格不对、参数错误）或满意的点（特定 Prompt 效果好）。
2.  **定位 Skill**：确定是哪个 Skill 需要进化（例如 `yt-dlp` 或 `baoyu-comic`）。
3.  **生成 JSON**：在内存中构建如下 JSON 结构：
    ```json
    {
      "preferences": ["用户希望下载默认静音"],
      "fixes": ["Windows 下 ffmpeg 路径需转义"],
      "custom_prompts": "在执行前总是先打印预估耗时"
    }
    ```

### 2. 经验持久化 (Persist)
Agent 调用 `scripts/merge_evolution.py`，将上述 JSON 增量写入目标 Skill 的 `evolution.json` 文件中。
- **命令**: `python scripts/merge_evolution.py <skill_path> <json_string>`

### 3. 文档缝合 (Stitch)
Agent 调用 `scripts/smart_stitch.py`，将 `evolution.json` 的内容转化为 Markdown 并追加到 `SKILL.md` 末尾。
- **命令**: `python scripts/smart_stitch.py <skill_path>`

### 4. 跨版本对齐 (Align)
当 `skill-manager` 更新了某个 Skill 后，Agent 应主动运行 `smart_stitch.py`，将之前保存的经验“重新缝合”到新版文档中。

## 核心脚本

- `scripts/merge_evolution.py`: **增量合并工具**。负责读取旧 JSON，去重合并新 List，保存。
- `scripts/smart_stitch.py`: **文档生成工具**。负责读取 JSON，在 `SKILL.md` 末尾生成或更新 `## User-Learned Best Practices & Constraints` 章节。
- `scripts/align_all.py`: **全量对齐工具**。一键遍历所有 Skill 文件夹，将存在的 `evolution.json` 经验重新缝合回对应的 `SKILL.md`。常用于 `skill-manager` 批量更新后的经验还原。

## 最佳实践

- **不要直接修改 SKILL.md 的正文**：除非是明显的拼写错误。所有的经验修正应通过 `evolution.json` 通道进行，这样可以保证在 Skill 升级时经验不丢失。
- **多 Skill 协同**：如果一次对话涉及多个 Skill，请依次为每个 Skill 执行上述流程。

## User-Learned Best Practices & Constraints

> **Auto-Generated Section**: This section is maintained by `skill-evolution-manager`. Do not edit manually.

### User Preferences
- If user says no code changes, stop code edits and switch to retrospective output.
- Default retrospective language is Chinese with fixed structure: issues-root causes-improvements-next steps.
- In multi-turn threads, confirm current intent as implement/fix/retrospective before acting.
- For HarmonyOS integrations, verify package existence in ohpm registry before adding dependency entries.
- If registry package is unavailable, prefer local vendoring with stable local import paths over repeated install retries.
- When user has no media resources, default to emoji/text fallback and remove hard resource references.
- When user explicitly says to ignore previous feature direction, immediately drop the previous plan and execute only the latest instruction.
- When two pages use the same shared component (e.g., FloatingWindow), align integration style first by diffing the working page before custom tuning.
- For draggable overlay components, prefer root-origin placement (.position({x:0,y:0})) and move default start location into component state instead of external layout offsets.
- When user asks for compile-error hotfix, freeze feature work and execute error-first triage.
- Default retrospective output must use: issues -> root causes -> improvements -> next constraints (not next steps).
- When user asks to retrospective and iterate, explicitly persist learnings via merge_evolution + smart_stitch in the same turn and report completion.
- 默认在 Windows 构建指导中明确区分 CMD 与 PowerShell 语法，不混用变量赋值写法
- 遇到 SDK 单行压缩 JS 补丁时，优先使用脚本文件或正则替换，不给用户多层转义命令
- 出现多轮补丁失败后，先停止扩散改动并回滚到备份再单点修复
- When user asks retrospective+iteration, execute merge_evolution and smart_stitch in the same turn and report concrete verification evidence.
- Default retrospective output in Chinese should stay compact and action-oriented for engineering sessions.
- In long multi-turn fix sessions, preserve momentum by continuing implementation unless user explicitly switches to analysis-only mode.
- When retrospective is requested right after a completed fix session, evolve both the active domain skill and skill-evolution-manager in the same turn.
- Retrospective outputs should include executed evolution scripts, target skills, and persistence evidence (updated timestamp + stitched marker).
- When user asks all-solved status followed by retrospective iteration, answer closure status first, then run dual-skill persistence workflow in the same turn.
- Retrospective responses should include a compact closure matrix before the issues-root causes-improvements-next constraints section.
- When user requests retrospective iteration after closure, execute dual-skill evolution immediately without extra clarification round.
- Retrospective should explicitly report whether all requested implementation tasks are completed before listing lessons.
- When map capability fails after key input, first verify the runtime config source file path and detect shadow config files with similar names.
- For bug-fix rounds with immediate implementation requests, keep response in Chinese and provide closure matrix before retrospective lessons.
- After feature toggles are relaxed (e.g., allow save without coordinates), explicitly re-check downstream SDK initialization gates to avoid hidden hard dependency assumptions.
- 用户要求复盘迭代并同步代码时，按顺序执行：复盘沉淀 -> 清理瘦身 -> 提交推送。
- ?????????????????????????????????
- ??????????????????????????????
- ?????"????"????????????ForEach key?@Track ?????????????????????
- ?"?????????"????????? ArkUI ?? diff ???????????
- 复盘输出保持中文、紧凑、先给闭环状态再给经验总结
- 用户要求复盘并迭代且同时要继续开发时，先完成代码目标，再在同轮执行技能沉淀与验证。
- 当用户要求复盘+迭代+推送+瘦身时，执行顺序固定：代码迭代 -> 验证 -> 经验沉淀 -> 瘦身 -> 提交推送。
- 用户要求复盘+迭代+推送+瘦身时，固定顺序为：复盘沉淀 -> 瘦身 -> Git 同步。
- 复盘输出保持中文、紧凑，先给闭环状态再给经验。
- When user asks retrospective iteration, persist lessons in the same turn and provide concrete evidence including commands and updated files.
- AWS Code无法通过Skill工具调用未注册的本地skills
- 解决方案：在CLAUDE.md中添加自动加载规则，通过Read工具读取skill内容
- 本地skills路径：E:\Travel12.19\skills\
- When user asks for code slimming/pruning (代码瘦身), they mean removing large unused files and build artifacts from the project, NOT cleaning up code comments or logs
- 实施前先完整梳理数据流，避免Phase 5大量补充
- Windows环境下Edit工具不稳定时立即切换sed
- 大型多Phase实施应每2-3个Phase编译验证一次
- When user explicitly names required skills, execute those skill workflows first and provide script-level evidence.
- For retrospective and iteration requests, keep output concise in Chinese and include persistence proof.
- 当用户明确要求“复盘+推main+瘦身”时，执行顺序固定为：经验沉淀 -> GitHub同步 -> 瘦身扫描与执行。
- 执行skill-evolution脚本时优先使用环境变量传递JSON，避免PowerShell参数去引号导致解析失败。
- 用户请求“复盘迭代+瘦身”时，顺序固定为：经验沉淀->瘦身执行->结果证据回报。
- 当用户要求"复盘+上传GitHub+瘦身"时，固定执行顺序：复盘沉淀 -> Git同步状态确认 -> 瘦身执行 -> 提交推送。
- 瘦身默认先处理可验证安全项：先删无引用的 tracked 冗余文件，再清理本地可再生产物。
- When merge_evolution CLI argument parsing fails on PowerShell, call merge_evolution via python import with file-loaded JSON to avoid quoting issues.
- 当用户明确指定多个skill和执行顺序时，先按顺序完成skill流程，再进入代码或Git操作。
- 复盘沉淀输出应附带可验证证据：merge/stitch命令执行结果与last_updated时间。
- 用户要求复盘迭代时，必须在同一轮执行merge_evolution和smart_stitch并回传证据。
- 当用户有顺序要求（先复盘再瘦身）时，严格按顺序执行并分段汇报。
- ???????????????skill-evolution????app-size-pruner?????GitHub???
- ??????????????????????????
- 当用户反馈设置页统计不准时，先核对数据链路是否覆盖重规划/二次入口，而不只检查首次生成入口
- 用户要求"复盘迭代 + 瘦身 + 上传GitHub"时，执行顺序固定为：经验沉淀 -> 瘦身 -> 发布
- 当用户要求按固定顺序执行多任务（复盘->瘦身->发布）时，严格按顺序并在每阶段给可验证结果。
- 复盘输出保持中文、简洁，先给闭环状态再给经验沉淀证据。
- 用户要求‘回顾+瘦身+上传’时，严格按顺序执行并在每个阶段给可验证证据。
- 复盘结论默认中文、紧凑，先回答任务是否完成，再给经验沉淀结果。
- 当用户要求‘复盘+瘦身+发布’时，严格按顺序执行并在每阶段提供可验证证据。
- 复盘沉淀后必须回读last_updated与SKILL.md自动区块，确认持久化。
- 当用户明确要求按顺序执行复盘+瘦身+发布时，固定顺序为：经验沉淀 -> 瘦身执行 -> GitHub 发布。
- 执行复盘迭代时，默认同时沉淀流程技能（skill-evolution-manager）与本轮执行技能（如 app-size-pruner）。
- 复盘回报保持中文、精简，并附脚本执行证据与落盘文件。
- 当用户明确指定顺序为复盘->瘦身->发布时，严格按该顺序执行并分阶段回报。
- 多轮 N4 补测场景中，继续迭代默认先落地当前批次并保持 unit-all 绿色，再进入复盘沉淀。

### Known Fixes & Workarounds
- Before any edit, restate user intent and explicitly state whether code will be changed.
- For state terms (IDLE/READY/ACTIVE/GAP), define decision rules and concrete time-bound examples before UI changes.
- For gesture interactions, always include threshold + damping + destination confirmation to avoid accidental cross-mode exits.
- ArkTS @Builder blocks should avoid local variable declarations in UI syntax regions; use inline casts or helper methods.
- Add explicit lambda return types (e.g., (): void => ...) when passing callbacks into custom class constructors to satisfy arkts-no-implicit-return-types.
- For FloatingWindow-like components, keep wrapper size close to float-ball size and avoid fixed position offsets that interfere with drag boundary math.
- For hvigor compile errors, perform minimal scoped patches first and avoid mixing with ongoing feature refactors.
- ArkTS null narrowing may fail inside closure callbacks; capture nullable values into local constants before property access in lambdas.
- For touch/gesture issues, isolate container size, initial position, and internal boundary math as three separate checks to avoid mixed regressions.
- When a behavior works in one page but fails in another, use parity patching (copy known-good integration parameters) before deeper refactors.
- After fixing one ArkTS syntax error, run a repo-wide scan for the same anti-pattern (for example local const declarations inside @Builder/build).
- If hvigor points to a UI line, inspect nearby list/brace closures as potential cascading parse roots before deeper refactor.
- For shell-heavy sessions on Windows, include a fallback strategy (Select-String/UTF8 read) when regex quoting or rg execution fails.
- 对 SDK JS 文件补丁后必须立即做语法校验（node --check 或实际加载）再跑 hvigor
- 所有构建命令统一给出 cmd /c 版本，避免 PowerShell 直接调用 bat 的兼容噪音
- 当 hvigor 吞掉子进程报错时，改为独立执行 webpack 同参复现，先拿真实首个异常
- On Windows PowerShell, avoid passing raw inline JSON literals directly to Python argv for merge scripts; write JSON to temp file and pass raw content to prevent decode errors.
- After merge, always run smart_stitch for each touched skill and then re-read both evolution.json and SKILL.md markers to confirm persistence.
- When skills docs appear garbled in terminal, trust UTF-8 file content via explicit encoding reads before deciding files are corrupted.
- When workspace has no git metadata, use rg/line-level evidence instead of git diff in the retrospective verification section.
- For post-fix retrospective in non-git workspaces, verify persistence using evolution.json timestamp + stitched marker lines instead of git diff evidence.
- After successful code fix sessions, include executed commands and build result summary before starting skill evolution scripts.
- Use merge_evolution plus smart_stitch for each target skill in same turn, then verify by reading evolution timestamp and stitched marker lines.
- In this project, map SDK reads entry/src/main/ets/common/utils/AppConfig.ets; editing a.ets or template files will not take effect.
- For add-item UX consistency, make save chain await VM async write methods end-to-end (dialog callback -> helper -> VM) to avoid stale plan-page rendering.
- Persist solver-returned auto commute time to DB, and invalidate (pre_travel_min=-1,is_travel_manual=0) only when place identity or travel mode changes.
- 复盘迭代回写需在同一轮对 active domain skill 与 skill-evolution-manager 同步执行 merge_evolution 与 smart_stitch，并给出时间戳证据。
- ???? index.lock ?????????????
- ? hvigor ??? test ????? hvigorw tasks???? assembleApp ???????
- ??/??????????? List/ForEach ???? key?? key + ? key????????????????
- ?????????? push?????? nextGroups ?????? groupedEvents
- 用户明确要求复盘迭代时，同轮完成 merge_evolution 与 smart_stitch，并给出持久化证据
- 用户要求同步 GitHub 时，提交应仅包含本轮代码变更，避免把本地技能和缓存目录一起推送
- Windows 下传 JSON 给 merge_evolution 时优先用无 BOM 文件读取，避免解析失败。
- skill-evolution 的 JSON 写入必须使用无 BOM UTF-8，避免 merge_evolution 解析失败。
- 执行 merge_evolution 后必须在同轮执行 smart_stitch 并给出时间戳证据。
- 当仓库无 tracked 变更时，GitHub 同步要明确说明为 up-to-date，避免误报已推送代码。
- Retrospective should include direct linkage from observed user confusion to actionable skill constraints, not generic summaries.
- 在CLAUDE.md添加Local Skills Auto-Loading section
- 定义4个主要skills的触发条件（travel-domino-dev、skill-evolution-manager、skill-manager、app-size-pruner）
- 使用Read工具绕过Skill工具限制
- For HarmonyOS projects, entry/build/ directory is the largest space consumer (build output, can be regenerated)
- Safe to delete: entry/build/, .hvigor/, oh_modules/ (reinstall with ohpm install), .tmp/, archive/, external project folders, showcase/demo projects, old version backups, build logs, .idea/
- Check project size with: du -sh . and analyze directories with: du -sh * .* | sort -hr
- ComposableStrategy数据流需要从UI->Index->ViewModel->AiService完整打通
- 自定义策略需要同时修改接口签名和调用方
- Run merge_evolution plus smart_stitch for both active domain skill and skill-evolution-manager in the same turn.
- On PowerShell, replace unsupported command chaining with ';' to avoid parser interruption during workflow execution.
- merge_evolution在PowerShell直接传JSON参数会丢失引号；改为EV_PAYLOAD环境变量传递可稳定执行。
- 复盘完成后需要给出可验证证据：last_updated时间戳、SKILL.md自动缝合区存在。
- 经验沉淀完成后必须同轮回读evolution.json的last_updated和SKILL.md自动区块作为持久化证据。
- 当用户追加流程约束（如“以后以最新main为主”）时，应立即沉淀为可执行规则而非口头备注。
- Docker Compose v2 场景下移除 compose 文件中的 version 字段，避免持续 warning 干扰排查。
- 执行瘦身前先做引用扫描（rg）和 tracked 校验（git ls-files），防止误删运行时资源。
- If user requires commit-msg gate but hook file is missing, create the gate first before push workflow.
- PowerShell下merge_evolution优先使用Python文件读取调用，避免JSON argv转义失败。
- PowerShell环境下merge_evolution参数优先走文件读取传参，避免JSON引号转义失败。
- 在自动发布脚本链路中，外部命令失败（如gh pr create）要可控降级，不应让整条流程误报失败。
- PowerShell ? evolution payload ???BOM UTF-8 ?? + Python????? JSON argv/?????? merge ???
- ???????????? -Files ???????????????????
- AI策略统计异常优先检查 AiInputDialog -> Index -> ViewModel 的 onRegenerate 参数透传，避免 strategy/customStrategy 在重规划链路丢失
- TimelineViewModel.loadData 需先重置再回填 currentStrategyMode（来自 plan.strategyMode），避免跨计划沿用旧模式导致统计偏差
- 当当前策略为自定义(-1)且用户未在弹窗触碰策略控件时，重规划应保持当前模式，不应回退到默认模式
- PowerShell下复杂正则和引号易失败，优先采用更稳的解析方案或脚本化处理。
- 技能沉淀后必须回读evolution.json的last_updated与SKILL.md缝合区，作为落地证据。
- 多轮继续执行场景下，先确认当前阶段（如C3）闭环状态，再进入skill沉淀与发布步骤。
- 执行沉淀后必须回传 merge_evolution 与 smart_stitch 的执行证据（命令和结果）。
- PowerShell下merge_evolution传JSON参数不稳定时，改用Python文件读取并直接调用merge函数。
- 在同轮复盘中可同时沉淀多个技能（领域skill+流程skill+工具skill），再统一回报证据。
- 在 PowerShell 传递 JSON 给 merge_evolution 时，优先走文件读取方式，避免命令行引号转义导致解析失败。
- 发布到 GitHub 在本仓库必须优先使用 scripts/git-auto-publish.ps1，不使用裸 git push 作为默认流程。
- CompanionDisplayHelper 的分值分档断言需避免字符串全等误判，优先按分档边界语义断言。
- 执行发布脚本时，-Files 参数在 PowerShell 中应通过数组变量传递，避免被拼成单字符串。

### Custom Instruction Injection

固定流程：先执行 skill-evolution-manager 沉淀，再执行 app-size-pruner（preview->apply），最后使用 scripts/git-auto-publish.ps1 发布并回传证据。