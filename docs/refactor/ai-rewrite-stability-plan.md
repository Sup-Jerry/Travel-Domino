# AI 重写稳定性实施计划（Travel Domino）

## 1. 目标与范围

### 1.1 本次目标
- 重写 AI 调用链路，提升请求稳定性与错误可控性。
- 重写 AI 返回 JSON 解析链路，确保结构校验与落库安全。
- 重写 AI 重新规划关键方法，保证 KEEP/OVERWRITE/UNDO 稳定可回滚。

### 1.2 明确范围（仅本次）
- 包含：AI 调用、响应解析、AI 重规划预览与应用流程。
- 不包含：天气、地图、认证、普通事件增删改、页面布局重构。

### 1.3 成功标准
- AI 请求失败不造成脏数据写入。
- JSON 异常（空、截断、字段错）可被拦截并给出可读错误。
- 重规划在失败场景下不污染原计划，UNDO 可恢复。

## 2. 外部规范对齐（DeepSeek 文档）

- JSON Output：请求携带 `response_format={"type":"json_object"}`，提示词明确 JSON 输出。
- 多轮会话：服务端无状态，每轮按需回传历史 messages。
- 思考模式：作为可选开关，不作为默认稳定路径。
- 错误码策略：
  - 不重试：400 / 401 / 402 / 422。
  - 可重试：429 / 500 / 503（指数退避 + 抖动）。

## 3. 目标文件与职责

### 3.1 AI 调用层
- `entry/src/main/ets/infrastructure/services/AiService.ets`
- 职责：请求构造、网络调用、错误映射、重试策略。

### 3.2 AI 响应解析层（新增）
- `entry/src/main/ets/infrastructure/services/AiResponseParser.ets`（新建）
- 职责：严格 JSON 解析、schema 校验、数据归一化、错误码统一。

### 3.3 AI 重规划编排层
- `entry/src/main/ets/domain/timeline/services/TimelineAiService.ets`
- 职责：预览生成、KEEP/OVERWRITE 应用、UNDO 恢复、并发锁与失败回滚。

### 3.4 兼容契约层（尽量不改）
- `entry/src/main/ets/viewmodel/TimelineViewModel.ets`
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/infrastructure/persistence/PlanRepositoryImpl.ets`
- `entry/src/main/ets/infrastructure/persistence/EventRepositoryImpl.ets`

## 4. 分阶段实施

### Phase A：调用链路重写（稳定基线）
- 重构 `AiService` 为三段式：
  - `buildRequest()`
  - `executeRequest()`
  - `mapErrorAndThrow()`
- 默认模型路径使用稳定模式（非思考模式）。
- 加入超时、重试、退避与日志埋点。

**交付物**
- 可独立测试的请求执行与错误映射逻辑。
- 统一错误消息（用户可读、日志可追踪）。

### Phase B：JSON 解析链路重写
- 新增 `AiResponseParser`，从 `AiService` 中剥离解析逻辑。
- 实现解析策略：
  - 严格 JSON 解析优先。
  - 结构校验（name/duration/type/ai_reasoning）。
  - 归一化（时长边界、type 合法性、空文本兜底）。
- 失败统一抛出明确错误码（避免静默失败）。

**交付物**
- 解析器单元测试通过。
- `AiService` 仅处理调用，不再承载复杂解析分支。

### Phase C：重规划方法重写
- 重写 `buildReplanPreview` / `applyReplanPreview` / `restoreFromUndoToken`。
- 原子化流程：
  - 先生成并校验 preview。
  - 再应用写入。
  - 失败立即回滚并恢复内存状态。
- 强化并发锁：生成中禁止重复进入关键路径。

**交付物**
- KEEP/OVERWRITE/UNDO 全链路稳定。
- 失败场景无半成功状态。

### Phase D：回归与门禁
- 补齐并更新测试：
  - `entry/src/test/AiService.test.ets`
  - `entry/src/test/TimelineStrategyManager.test.ets`
  - `entry/src/test/TimelineViewModelAiDistribution.test.ets`
- 执行门禁：
  - `./scripts/ci/validate-unit-test-cases.ps1`
  - `./scripts/ci/unit-all.ps1`

**交付物**
- 测试报告与问题清单。
- 无新增失败后才进入发布流程。

## 5. 稳定性策略（硬约束）

### 5.1 幂等与一致性
- 任何失败不得破坏原始行程。
- OVERWRITE 仅在新结果校验通过后执行删除与写入。

### 5.2 错误处理分层
- 用户层：可读提示。
- 日志层：机器可检索错误码（便于排障）。
- 调用层：区分可重试/不可重试错误。

### 5.3 兼容性要求
- 保持现有字段语义不变：`source`、`aiReasoning`、`lastAiPrompt`、`strategyMode`。
- 保持 VM 与页面调用签名不变，降低联动风险。

## 6. 风险与缓解

- 风险：解析严格化后通过率短期下降。
  - 缓解：提供清晰报错与最小安全兜底，不写入脏数据。
- 风险：重规划写路径改造导致状态错乱。
  - 缓解：先引入 undo token 快照，再执行写入。
- 风险：重试策略导致请求时延上升。
  - 缓解：限制重试次数与总超时上限。

## 7. 回滚方案

- 代码回滚：按 Phase 粒度提交，支持逐阶段回退。
- 运行回滚：保留旧调用开关（临时），异常时切回旧路径。
- 数据回滚：依赖 `UNDO` 快照与现有持久层恢复流程。

## 8. 完成定义（DoD）

- AI 调用、JSON 解析、重规划三块均完成重写并通过门禁。
- KEEP/OVERWRITE/UNDO 手工验证通过。
- 无新增核心回归缺陷。
- 文档与测试与实现保持一致。

## 9. 执行顺序（建议）

1. Phase A（调用层）
2. Phase B（解析层）
3. Phase C（重规划）
4. Phase D（回归门禁）

---

本计划为“稳定性优先”版本，默认以最小耦合变更完成 AI 核心重写。
