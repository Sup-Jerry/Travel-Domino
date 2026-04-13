---
name: travel-domino-dev
description: 用于 Travel Domino（HarmonyOS 行程规划项目）的定向开发与修改。对任何可能改动 repo-tracked 代码的请求（Bug 修复、功能实现、重构、接口调整、UI/时间逻辑联动）默认触发“改码前强制对齐门禁”。默认中文输出；若关键上下文、API/数据契约或环境约束缺失，必须阻断实现并先收齐信息。
---

# Travel Domino 项目开发 Skill

你正在处理 Travel Domino 项目，一个基于 HarmonyOS 的时间约束驱动型智能旅游规划与旅行陪伴系统。

## 输出语言与触发约束
- 默认使用中文输出分析、方案、验证和实现说明。
- 仅当任务涉及代码/配置/接口变更时，强制执行本 Skill 的 `Pre-Code Alignment Gate`。
- 纯解释、纯答疑、纯概念讨论可跳过门禁，但仍遵守“禁止假设未知实现”。
- 当任务涉及“最新 API/规范/版本兼容要求”时，必须先查询华为官方文档再给出结论。

## 全项目永久规则（来自 AGENTS.md）

### 项目是什么
- HarmonyOS / ArkTS 项目
- 业务域：旅游规划、时间约束调度、旅行陪伴

### 分层结构是什么
- `common/utils`：通用工具层（配置、HTTP、地图、日期、导航、偏好、数据库辅助）
- `model/entity`：实体层与 DAO
- `model/interface`：接口定义与标准结构
- `model/logic`：时间约束、调度、压缩、分配等核心逻辑
- `viewmodel`：页面/视图状态编排与业务联动
- `ui/view`：界面展示层
- `entryability`：应用入口能力

### 命名规则
- 保持现有命名风格、工程结构与调用链
- 领域对象按既有语义使用：`Day X`、`day_offset`、`DateGroup`、`EventEntity`、`PlanEntity`
- 不在未确认的情况下改动核心实体语义与字段命名

### 不允许做什么
- 禁止假设任何未给出的代码存在
- 禁止虚构函数、字段、枚举、组件、工具类
- 禁止将示例代码伪装成可直接运行代码
- 未确认前，禁止新增数据库字段或持久化结构
- 未确认前，禁止大规模重构或擅自扩展未知结构

## Pre-Code Alignment Gate（改码前强制对齐门禁）

在任何代码落地前，严格按以下五阶段执行。未通过门禁，不得给出实现补丁。

### 阶段 1：技术意图澄清
必须对齐：
- 问题定义：当前现象、触发条件、影响对象
- 目标与成功标准：如何判定“修好/做完”
- 边界与非目标：本次不改什么
- 业务/性能/兼容性/可维护性动机

提问节奏：
- 每轮最多 3 个高价值问题
- 优先问会改变方案走向的问题
- 能从代码库验证的事实，不问用户，先自行核验

### 阶段 2：代码与契约核验
必须核验：
- 相关代码上下文：关键文件、函数、调用链、状态源
- API/数据契约：endpoint、参数、成功/失败响应、鉴权
- 环境约束：HarmonyOS API/SDK 版本、依赖限制、构建限制
- 官方文档锚点：为关键 API/规范提供华为官方文档链接与版本信息（发布日期或版本号）
- 若涉及通知/系统 API（如 `@ohos.notification*`、`@ohos.wantAgent`、`@kit.*` 系统能力）：
  1. 先在本机 SDK `*.d.ts` 中定位真实签名（参数、返回值、类型导出名）
  2. 再编码；禁止先写后猜
  3. 输出中必须给出已核验的 d.ts 路径与关键类型名（例如 `NotificationRequest.wantAgent`、`WantAgentInfo`）

阻断条件（任一满足即停止实现）：
- 缺关键文件或关键函数上下文
- 缺 API/数据契约关键字段
- 缺运行环境关键约束且无法从仓库推断
- 涉及最新规范但未完成官方文档核验
- 涉及通知/系统 API 但未完成本机 SDK d.ts 签名核验

### 阶段 3：实现决策收敛
在编码前必须产出可执行规范：
- 技术方案摘要（1 句话）
- Functional Spec：Input / Processing Logic / Output
- 异常与边界：空数据、权限失败、超时、并发冲突、重入等
- 修改影响范围：直接改动与可能联动区域

### 阶段 4：系统副作用扫描（A-F）
必须按以下结构输出：
- A. 直接影响范围
- B. 间接影响范围
- C. 潜在副作用清单（数据/逻辑/UI/性能/可维护性）
- D. 高风险边界场景
- E. 回归测试优先级
- F. 风险缓解建议

并对每个风险给出等级（高/中/低）与原因。

### 阶段 5：技术对齐包完成后再编码
只有在以下条件同时满足时，才进入代码实现：
- 关键上下文完整
- Functional Spec 完整
- A-F 扫描完整
- 验证计划明确

否则继续澄清，不输出修改代码。

## 遇到某类任务时怎么干

### 修 Bug 的步骤
1. 对齐需求与复现路径
2. 定位最小影响范围（状态、逻辑、UI、数据层）
3. 检查上下文充分性；不足则停止并列出缺失代码
4. 做最小必要修改，避免无关重构
5. 按主流程与边界场景验证

### 改 UI 的检查顺序
1. 状态变量是否正确驱动
2. 布局层级与条件渲染是否一致
3. 交互触发点与事件分发是否闭环
4. 是否误把业务判断硬编码到 UI 层

### 改 day_offset 的核对规则
1. 同时核对 `PlanEntity` 起始日期语义
2. 同时核对 `EventEntity` 与分组映射字段
3. 同时核对 `TimelineViewModel` 分组与排序逻辑
4. 同时核对 `TimeConstraintSolver` 的输入输出映射
5. 确认 `Day X` 展示与自然日/偏移日关系一致

### 输出模板
按 `resources/output-template.md` 输出，必须区分：
- 需求理解
- 影响范围
- 当前上下文是否足够
- 技术方案摘要（1 句话）
- Functional Spec（Input/Processing Logic/Output）
- 副作用扫描 A-F
- 风险等级与回归优先级
- 文档来源与版本锚点（华为官方链接 + 版本/日期）
- 日志与真机验证方式
- 修改方案
- 实际代码（仅在通过门禁后）
- 验证方式

### 缺代码时的停止机制
- 发现关键上下文不足时，立即停止输出修改代码
- 明确列出缺失的文件/函数/类型定义
- 不提供伪代码，不提供基于猜测的补丁

## 执行流程
1. 判断任务是否会改动代码；若会，先进入 `Pre-Code Alignment Gate`
2. 先完成技术意图澄清，再做代码充分性检查
3. 涉及 API/数据流时先核验契约，再讨论实现细节
4. 涉及数据库时同步核对实体、DAO、调用层
5. 涉及 UI 时同步核对状态、布局、交互触发点
6. 涉及时间逻辑时同步核对 ViewModel、logic、entity 映射
7. 对齐包完整后才编码；否则阻断并列缺失项
8. 除非用户明确要求，不新增抽象层或中间服务
9. 每新增一个功能，必须按 `unit-test-case-generator` 补齐对应单列测试；未补齐单测不得判定该功能完成

## 参考资源
- `resources/architecture.md`
- `resources/domain-glossary.md`
- `resources/coding-rules.md`
- `resources/output-template.md`
- `resources/deep-alignment-playbook.md`（深度对齐规则、提问模板、A-F 扫描模板、日志验证模板）

<!-- skill-evolution:start -->

## User-Learned Best Practices & Constraints

> **Auto-Generated Section**: This section is maintained by `skill-evolution-manager`. Do not edit manually.

### User Preferences
- Retrospective output should follow: issues-root causes-improvements-next constraints.
- When user reports Day/date mismatch, first check mixed usage of dynamic_day_offset vs day_offset.
- When user asks retrospective/iteration, persist conversation learnings into skill memory and stitch into SKILL.md in the same turn.
- For multi-file UI/navigation refactors, provide concise Chinese progress updates with concrete verification checkpoints.
- For ambiguous UI copy requests (for example 顶部按钮里的英文介绍), first locate all candidate files and confirm exact target scope before editing.
- When the user provides an explicit implementation plan after prior alignment, execute against that plan directly and keep discussion compressed to code-context verification plus concrete edits.
- When user requests a change plan with risk consideration, output impacted files + 3-6 step plan + A-F risk scan before coding.
- When requirements change mid-turn, immediately drop previous optimization assumptions and implement the latest explicit business rule.
- When user explicitly asks to switch map POI search to SDK, prioritize local d.ets signature verification before coding and then migrate service call chain end-to-end.
- For geofence reminder debugging, prioritize log-led triage and explain trigger conditions with exact field names (eligible, direct, geofence, merged, trigger).
- When user asks to keep data before reinstall, provide a minimal export/import path first to unblock verification loops.
- For HarmonyOS notification/system API changes, always verify local SDK d.ts signatures first and cite verified type names before coding.
- When user explicitly asks to ignore previous errors and focus current issue, narrow implementation scope immediately and avoid reopening unrelated threads.
- When external course/repo pages are JS-rendered or login-gated and正文抓取为空, immediately switch to local-copy/screenshot path instead of repeated remote fetch.
- For dark-mode follow-up requests, prioritize component-level residual fixes (for example BacklogView) with minimal diff before touching parent pages.
- When user questions whether a compile error is caused by current changes, verify with a fresh build first and state causality only after confirmation.
- When user gives a severity-ranked architecture issue list and asks to keep going until all fixed, close the loop by returning per-issue status (fixed/partially fixed/deferred) with concrete file mapping.
- For multi-phase refactors, keep diffs incremental and run build verification after each major phase instead of one final check only.
- When user provides a P0/P1 multi-risk list and asks to fix issues, execute in priority order and report closure by risk item.
- When user repeatedly asks to continue until closure, keep autonomous execution and report a strict closure matrix (done/in-progress/remaining) each cycle.
- For architecture debt batches, keep responses concise Chinese and map each fixed item to concrete files/functions before claiming closure.
- After retrospective requests, always verify persistence by checking evolution.json timestamp and SKILL.md stitched section in the same turn.
- When user provides a severity/risk checklist with exact files and asks to fix, implement directly in risk order and close each item with explicit status mapping.
- For reliability hardening tasks, keep minimal-diff targeted patches across service/UI/engine layers and keep final Chinese closure concise and itemized.
- When user provides a severity-ranked security checklist with exact file+line references, execute fixes directly in risk order and close each item with explicit status.
- For security hardening requests, keep output concise Chinese and prioritize closure evidence over long theory.
- When user repeatedly requests continue, continue autonomous implementation and prioritize batching multiple fixes in one iteration.
- When user asks if all tasks are done, provide explicit closure status first, then continue next action.
- When map capability fails after key input, first verify the runtime config source file path and detect shadow config files with similar names.
- For bug-fix rounds with immediate implementation requests, keep response in Chinese and provide closure matrix before retrospective lessons.
- After feature toggles are relaxed (e.g., allow save without coordinates), explicitly re-check downstream SDK initialization gates to avoid hidden hard dependency assumptions.
- 在 HarmonyOS 项目里执行门禁时，避免并行跑 clean 与 test，统一使用串行 full-gate。
- 告警治理优先把三方固定告警放入独立忽略清单文件，再把 warn baseline 收敛到 0。
- ?????????????????????????????????
- ??????????????????????????????
- ?????"????"????????????ForEach key?@Track ?????????????????????
- ?"?????????"????????? ArkUI ?? diff ???????????
- 用户要求复盘+迭代+推送时，按顺序执行：经验沉淀->瘦身->提交推送
- 当用户做 UI 细节调整（颜色/层级）时，先确认目标元素是圆点、卡片背景还是文本，再动代码。
- 时间线配色默认控制在低饱和 4 色，优先保证可读性，避免一地点被误判成多地点。
- 当用户报告编译报错时，先对齐真实报错文件内容，再决定最小修复点，避免按旧上下文误改。
- 当用户强调某个视觉元素时（如长方形卡片而非圆点），先复述目标元素后再改。
- 当用户反馈回归时，先修复功能可用性，再补交互提示，不要只加约束门禁。
- 涉及全局唯一进行中规则时，所有开始入口都要给出可见弹窗，而不是静默失败。
- 冲突提示文案至少包含计划名+地点名。
- 时间计算优先使用Solver计算结果（computed_time）而非动态时间戳
- 数据替换操作必须先生成后删除，保证事务性
- 异步操作必须添加请求锁防止并发
- 长时间操作必须提供进度提示和预计时间
- 对比蓝图与实现时，先读蓝图文档再读代码，避免盲目搜索
- 补充数据库字段时，先验证Entity定义再检查Repository实现
- Edit工具失败时立即切换为sed或精确行编辑，不重试
- 对于多文件策略重构，实施前先验证计划中的类型名称与实际代码一致性
- 当用户直接提供错误日志时，先基于错误码做根因归类，再决定最小修复路径。
- 地图搜索故障排查默认先区分 SDK 鉴权失败 与 搜索链路/解析问题，避免误判为关键词问题。
- For auth flows, treat accountId(OpenID/UnionID) as primary identity and use userId only as fallback.
- When login succeeds but page does not navigate, verify session expireAt format compatibility before routing.
- For logout acceptance, validate both memory and persisted silent-login block markers.
- 遇到登录卡在Gate页时，先按provider->facade->gate顺序对齐LOGIN_TRACE时序，再决定修复点。
- 启动静默登录的context默认由EntryAbility绑定，页面层不要重复覆盖AuthFacade上下文。
- 离线重进失败时优先验证session_cache恢复链路，而不是先怀疑华为账号SDK。
- 当分支与main差异过大且冲突扩散时，优先在main做最小补丁并直接提交，不强行整分支合并。
- 用户明确要求“以最新为主”时，直接清理旧分支并以origin/main作为唯一基线。
- 当用户要求"复盘+上传GitHub+瘦身"时，固定执行顺序：复盘沉淀 -> Git同步状态确认 -> 瘦身执行 -> 提交推送。
- 瘦身默认先处理可验证安全项：先删无引用的 tracked 冗余文件，再清理本地可再生产物。
- When user specifies scripts/git-flow.ps1 and hook gates, validate gate files exist before executing push flow.
- 当用户连续要求"继续"时，默认每轮尽量批量完成多项可独立压缩项，而不是单点微改。
- 在Index.ets瘦身任务中，优先删除只调用一次的包装方法，并把分发逻辑下沉到index子模块。
- 每轮压缩后都要回报行数变化（前后对比）并给出是否进入目标区间。
- 当用户要求上传到GitHub时，优先走scripts/git-auto-publish.ps1并显式用-Files限制提交范围。
- 在脏工作区发布时，先汇报未提交文件清单，再按用户确认只提交目标文件。
- 默认中文输出，先给结果再给关键证据。
- ???????????? liveGap + is_conflict ???????????? forcedGap ???
- ??????????????????????????????X???????????
- ?????????????????????? toast ?????????????
- 当用户反馈设置页统计不准时，先核对数据链路是否覆盖重规划/二次入口，而不只检查首次生成入口
- 用户要求"复盘迭代 + 瘦身 + 上传GitHub"时，执行顺序固定为：经验沉淀 -> 瘦身 -> 发布
- 当用户要求先给规划文档再继续实施时，先产出可验收的txt规划，再进入实现。
- 执行C1/C2分批补测时，优先服务层单测再做module元数据装配测试，减少无效断言。
- 在Windows环境出现并发命令失败(CreateProcessWithLogonW 1056)时，切换串行读取与单进程命令。
- 执行C4整批补测时，先补最稳定可测的manager/coordinator/persistence链路，再补auth链路，降低回归波动。
- 当用户要求一次性完成批次时，采用‘边修编译规则边扩覆盖’的方式，避免最后集中爆雷。
- ??????????/???? + ?? + ??GitHub????????????? -> ?? -> ???
- ??????????????????????????????????
- ???????GitHub?????? scripts/git-auto-publish.ps1????? git push?

### Known Fixes & Workarounds
- For cross-day domino shifts, user-facing date and writeback inputs must prefer dynamic_day_offset; do not mix with day_offset in one flow.
- After group logic changes, run global search for day_offset usages in UI/edit/conflict/time/helper paths and align them.
- Use single-source date basis first (group key, header date, writeback params), then fix secondary display issues.
- HarmonyOS media resources cannot share the same basename across formats at runtime; keep one runtime name (PNG), archive SVG with _vec suffix.
- ArkTS @Builder blocks only allow UI component syntax; do not declare local variables inside builder bodies.
- For hotfixes, avoid broad rewrite; use scoped patch and run a quick syntax sanity check around edited blocks.
- Main-page search must include trash plans when requirement says global search; merge active+trash results and dedupe by id.
- For arkts-no-untyped-obj-literals on router navigation options, define an explicit interface/type and assign properties on a typed object instead of ternary object literals.
- If rg.exe is unavailable or access-denied in Windows shell, immediately fallback to Select-String and continue with line-numbered scans.
- When Chinese appears garbled in terminal output, re-read with Get-Content -Encoding UTF8 before treating it as source corruption.
- For PowerShell regex containing quote/backtick-heavy patterns, prefer staged scans or simpler patterns to avoid parser errors.
- If the workspace is not a git worktree or lacks hvigorw/hvigor build entry, fall back to targeted line-number scans/manual sanity checks and state clearly that full build verification was not run.
- For map picker behavior, enforce explicit create-vs-edit mode policy instead of mixed geocode/current heuristics when product rule is mode-driven.
- In AMap map picker, myLocationType(1) can override manual moveCamera; use mode-based location type (create=1, edit=0) to prevent camera snapping back to current location.
- ArkTS forbids unknown casts, inline object-literal type assertions, and indexed signatures in strict mode; prefer named interfaces and explicit concrete casts.
- Do not cast ArrayList<T> directly to T[] in ArkTS. Read collection via forEach/get/size-compatible adapter logic to satisfy compiler checks.
- ArkTS disallows using this inside stand-alone functions; replace with module-level state, class static methods, or closure-captured objects.
- If arrival logs show eligible=0, first verify schedule count, pending count, and coordinate completeness before tuning geofence thresholds.
- Global arrival monitoring must be started from home lifecycle as well, not only inside plan detail page, otherwise home won't emit arrival logs or reminders.
- To reduce hard-to-trigger arrival reminders, combine geofence enter with direct-distance fallback, increase radius when needed (for example 220m), and shorten cooldown/switch-lock conservatively.
- When popups stop in plan page after a home trigger, inspect de-dup and cooldown ownership (event-level vs page-level) before changing location logic.
- Treat "d.ts-first" as a hard gate for ArkTS system APIs (notification/wantAgent/kit imports): if local signature is unverified, block implementation.
- For persistent system notifications in HarmonyOS, configure all three explicitly: isOngoing=true, isUnremovable=true, tapDismissed=false, and keep stable notification id for updates.
- Companion 'next place' must use a single ordered schedule source (day offset + sort_order) shared by context, focus selection, and next-event lookup to avoid jumping back to earlier items.
- If arrival logs repeatedly show eligible=0, treat it as candidate-set empty and debug eligibility filters before tuning geofence runtime thresholds.
- For immersive+cutout adaptation in HarmonyOS pages, prefer minimal pattern: ignoreLayoutSafeArea + avoid-area insets(TYPE_SYSTEM/TYPE_NAVIGATION_INDICATOR/TYPE_CUTOUT) + lifecycle system-bar hide/show.
- For ArkUI runtime crash "Illegal usage of not @Track'ed property", first follow stack lines from UI render chain to ViewModel fields and convert the accessed fields to @Track with minimal scope.
- If hvigor reports 'Unexpected string/identifier' without file-line location, run a full --debug build to file and judge by final BUILD status before rolling back feature patches.
- When writing ArkTS files via shell on Windows, enforce UTF-8 without BOM to avoid parser/toolchain instability during CompileArkTS.
- If hvigor reports task not found, run hvigorw tasks first and switch to the nearest available build task (for this project: assembleApp) as the compile gate.
- When apply_patch fails repeatedly on Windows files, re-read exact content and switch to precise line-based replacement to avoid mismatch caused by encoding/line-ending drift.
- For arrival reminder consistency, use a single store abstraction for payload/seq keys shared by engine and coordinator to prevent parse/clear divergence.
- For conflict-resolution save flows, await updateEventInfo before subsequent plan-date updates to prevent mid-state dirty writes.
- For single-active-event constraints, perform active-event precheck before mutation and use an in-flight lock to block concurrent start writes.
- For import/export semantic fidelity, preserve sentinel values such as preTravelMinutes=-1 and travelMode=0; avoid fallback coercion via truthy checks.
- For hard delete and trash purge, cascade-delete events by plan_id to avoid orphan rows.
- For large state-consistency fixes in Travel Domino, prioritize sequence: single-source state model -> DAO atomic writes -> precheck before mutation -> UI refresh from persisted state.
- For reorder consistency issues, apply compute-new-order -> transactional DAO writeback of full sort fields -> one-shot UI refresh; avoid delayed async partial writebacks.
- For cross-plan UI residue, scope AppStorage keys by planId and clear scoped keys in page lifecycle to prevent stale dialog/reminder payload leakage.
- For JSON import reliability, enforce strict schema/range/size validation before writes and combine cancel-token checks with transaction rollback plus compensation delete to avoid half-import dirty plans.
- For cross-page draft recovery, safe-parse AppStorage JSON with try/catch, clear corrupted keys before reopen, and avoid consuming global fallback keys that can leak across plan scopes.
- For geocode-dependent save flows, block persistence when geocode fails and validate coordinate range again in map service responses.
- When geofence refresh fails, clear monitored candidates and all event-plan mapping snapshots to prevent stale reminder triggers.
- For AppStorage draft recovery, enforce safe JSON parse with try/catch, whitelist field reconstruction, default fallbacks, and immediate cache cleanup on parse failure.
- For privacy-sensitive logs, do not print raw coordinates, place names, user inputs, or full error objects; log only masked values and minimal diagnostics.
- When hvigor build command fails with task-not-found under module-scoped args, run `hvigorw tasks` first and then switch to the root-level available task (for this repo: `hvigorw assembleApp`).
- For arrival reminder scalability, maintain active plan snapshot with dirty-plan incremental updates and keep periodic full-resync as safety net.
- For timeline performance, thread startFromEventId through ViewModel to TimeConstraintSolver and preserve dynamicStartTime/dynamicEndTime in interface mapping for partial recompute.
- In this project, map SDK reads entry/src/main/ets/common/utils/AppConfig.ets; editing a.ets or template files will not take effect.
- For add-item UX consistency, make save chain await VM async write methods end-to-end (dialog callback -> helper -> VM) to avoid stale plan-page rendering.
- Persist solver-returned auto commute time to DB, and invalidate (pre_travel_min=-1,is_travel_manual=0) only when place identity or travel mode changes.
- PowerShell 调用 hvigorw.bat 时优先使用 cmd /c 包装，避免 NativeCommandError 噪音影响门禁日志判断。
- 若出现 entry/.test/testability/TestAbility.ets 间歇缺失，先排查是否有并行 clean 清理临时目录导致竞争。
- ???? index.lock ?????????????
- ? hvigor ??? test ????? hvigorw tasks???? assembleApp ???????
- ??/??????????? List/ForEach ???? key?? key + ? key????????????????
- ?????????? push?????? nextGroups ?????? groupedEvents
- 地图选点崩溃需先区分 key 配置问题与 native so 加载问题，再决定修复层级
- 当报错为 nativeSetAMapXComponentCallback of undefined 时，优先在业务入口加运行时可用性门禁，阻断页面跳转避免崩溃
- 针对时间线卡片配色：支持按可见序列 4 色循环与按地点一致两种策略，收到新指令后立即切换到最新规则。
- 针对 hvigor test 场景，覆盖率报告 00507008 不等于单测失败，应以 BUILD SUCCESSFUL 与退出码联合判定。
- 全局进行中检查必须忽略已删除/已归档计划，并在计划软删/归档时清理进行中事件状态。
- 通知点击路由需携带 planId/eventId 并落到伴游模式入口。
- 当开始打卡失败时，入口应根据冲突态回退到 open_page 而非 start 确认。
- When solver-calculated dynamic times are not syncing to entities, check if SolverCalculatedItem interface includes all necessary fields (dynamicStartTime, dynamicEndTime)
- When computed_time contains date prefix (e.g., '03-17 09:00'), extract time-only portion before syncing to fixed_start_time to avoid dialog parsing errors
- When backlog items show hardcoded suggestion times, calculate dynamically from last schedule item's dynamic_end_time or computed_time + duration
- For time display inconsistencies between UI and detail dialog, verify field synchronization in applyCalculatedResult method
- When debugging multi-field time representation, add diagnostic logs at sync points to trace value flow
- 暂存池建议时间：调换computed_time和dynamic_end_time优先级
- AI重新生成：添加isRegenerating锁，先生成新数据再删除旧数据
- 进度提示：根据策略模式显示不同预计时间（特种兵30-60秒，休闲20-40秒）
- grep搜索字段时同时搜索定义和使用位置，避免遗漏
- ArkTS静态方法中必须使用类名调用而非this（如StrategyService.method()而非this.method()）
- Windows环境编译验证优先使用后台运行或简化命令格式
- 当 AMap POI SDK 返回 errorCode=1008（MD5安全码未通过）时，保持 SDK 为主链路但自动降级到 Web POI API（around/text）保障可用性。
- 修复后必须跑一次 hvigorw assembleApp，并在结论中明确区分“新增问题”与“仓库既有问题”。
- Fix /auth/social/login 500 by keeping user_account/auth_identity/user_session writes in one DB transaction.
- Normalize session expireAt parsing for ISO/seconds/milliseconds and add fallback TTL to avoid immediate expiry.
- Skip provider silent login when UI context is unavailable in early bootstrap stage.
- Add in-flight dedup in startup silent login to avoid duplicate exchange races.
- 修复silentLogin因context类型不兼容导致auth_provider_error：在EntryAbility.bootstrapUserContext先bindContext(this.context)，并移除AuthGatePage覆盖绑定。
- 修复ArkTS no-structural-typing：AuthSessionStore对外load/loadSessionPersisted统一返回AuthSessionPayload。
- 认证链路改动后先跑unit-all做最小回归，再做真机登录验收。
- merge --ff-only失败且冲突文件明显超出本次需求范围时，先merge --abort，再执行最小补丁策略。
- Windows PowerShell不支持&&，命令链需要拆分执行避免脚本中断。
- Docker Compose v2 场景下移除 compose 文件中的 version 字段，避免持续 warning 干扰排查。
- 执行瘦身前先做引用扫描（rg）和 tracked 校验（git ls-files），防止误删运行时资源。
- Before rollback/force-push operations, stash local uncommitted changes and restore after rollback to avoid loss.
- 页面编排层瘦身优先策略：先删单次转发方法，再收口弹窗/日期选择链路，可稳定降低行数且不改行为。
- 功能等效验收要绑定编译门禁：每轮执行assembleApp并确认仅历史错误，无新增错误后再继续。
- 定位时间轴异常时，优先检查solver中的slackRatio是否引入隐式时间漂移（例如默认+15min）。
- 修复发布脚本时需要兼容PowerShell不支持&&的限制，命令链改为分号或分步执行。
- 自动发布流程中PR创建失败应降级为告警，不能影响提交与推送主链路。
- ?????? OVERLOAD ???????????????? affectedItems???????????????
- ?? gap ??? is_conflict=false ????0??? fallbackGap ???????????
- AI策略统计异常优先检查 AiInputDialog -> Index -> ViewModel 的 onRegenerate 参数透传，避免 strategy/customStrategy 在重规划链路丢失
- TimelineViewModel.loadData 需先重置再回填 currentStrategyMode（来自 plan.strategyMode），避免跨计划沿用旧模式导致统计偏差
- 当当前策略为自定义(-1)且用户未在弹窗触碰策略控件时，重规划应保持当前模式，不应回退到默认模式
- unit-test-case门禁脚本的AAA检测不应仅看前8行，需覆盖完整测试块或足够窗口。
- 当apply_patch出现系统级写入异常时，改用稳定文件写入方式继续交付，之后再回归验证。
- 为避免污染提交范围，发布到GitHub时优先通过git-auto-publish的-Files显式控制提交文件。
- ArkTS测试代码禁止stand-alone this和结构化类型推断，测试替身统一改为显式class + implements接口。
- C4补测完成后必须串行执行validate-unit-test-cases与unit-all双验收，并以unit-all脚本结论为准。
- PowerShell ? JSON ? merge_evolution ????? Python ???/??????????????????
- ?? skill ?????????? smart_stitch ??? SKILL.md ????????

### Custom Instruction Injection

???????????+??+??????????merge_evolution/smart_stitch -> prune_large_app preview/apply -> git-auto-publish??????????
