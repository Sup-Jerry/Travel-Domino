# AI 重写分阶段交付说明（Phase A-D）

## 0. 范围说明
本说明仅覆盖 AI 重写稳定性计划内改动：调用层、解析层、重规划编排层及回归门禁。

## 1. Phase A（调用链路稳定基线）

### 1.1 目标
- 统一错误映射与重试策略，避免无效重试。
- 与 DeepSeek 错误码策略对齐（401/400/402/422 不重试；429/500/503 可重试）。

### 1.2 已实现
- `AiService` 增加显式 HTTP 错误封装与状态解析。
- `shouldRetryError` 收敛到超时 + 429/500/503。
- 重试前加入指数退避 + 抖动等待。

### 1.3 对应文件
- `entry/src/main/ets/infrastructure/services/AiService.ets`

### 1.4 回归证据
- `invalid: generate_with_strategy_should_not_retry_on_401`
- `normal: generate_with_strategy_should_retry_on_503`
- 文件：`entry/src/test/AiService.test.ets`

## 2. Phase B（JSON 解析链路重写）

### 2.1 目标
- 解析逻辑与调用逻辑解耦。
- 对 AI 返回 JSON 做结构校验与归一化，避免脏数据进入后续链路。

### 2.2 已实现
- 新增 `AiResponseParser` 作为独立解析器。
- 支持：
  - markdown fence 去除
  - 宽松 JSON-like 归一化
  - 多层 content/choices 提取
  - 行文本兜底解析
- 保留并统一错误语义：
  - 顶层 JSON 非法
  - 响应为空
  - 内容为空
  - 内容非合法 JSON

### 2.3 对应文件
- `entry/src/main/ets/infrastructure/services/AiResponseParser.ets`
- `entry/src/main/ets/infrastructure/services/AiService.ets`（已接入解析器）

## 3. Phase C（重规划编排稳定化）

### 3.1 目标
- KEEP/OVERWRITE 失败不污染原计划。
- UNDO 恢复与 apply 失败回滚复用同一恢复路径。
- 并发锁在成功/失败后均可释放。

### 3.2 已实现
- `TimelineAiService` 增加内部恢复方法：`restoreUndoSnapshotUnsafe`。
- `applyReplanPreview` 失败后自动回滚快照。
- 新增回滚一致性校验：
  - 策略模式一致
  - 事件总数一致
  - AI 来源事件数一致
- 增加测试注入点：`setInsertAiEventHookForTest`，用于稳定覆盖失败场景。
- 增强日志：记录失败前后关键计数（beforeTotal/beforeAi/removedAi/inserted/currentTotal）。

### 3.3 对应文件
- `entry/src/main/ets/domain/timeline/services/TimelineAiService.ets`
- `entry/src/test/TimelineAiServiceReplan.test.ets`
- `entry/src/test/List.test.ets`（注册测试套）

### 3.4 核心测试覆盖
- `normal`: `restore_from_undo_token_should_restore_events_and_mode`
- `regression`: 失败后 `isRegenerating` 释放
- `combined`: KEEP 插入失败回滚
- `combined`: OVERWRITE 删除旧 AI 后插入失败也能恢复

## 4. Phase D（门禁与结论）

### 4.1 门禁命令
- `./scripts/ci/validate-unit-test-cases.ps1`
- `./scripts/ci/unit-all.ps1`

### 4.2 本次结果
- `validate-unit-test-cases`: 通过
- `unit-all`: 通过（存在仓库既有 ArkTS warn，但无新增 compile error）

### 4.3 当前结论
- 计划内 A/B/C 关键稳定性目标已落地并通过门禁验证。
- AI 重规划关键失败路径具备可回滚保障，且可通过单测稳定复现。

## 5. 发布前检查清单
- AI key 仍不入仓库明文（后续切换 env）。
- 真机联调重点关注：
  - `AI_REPLAN_TRACE[service_apply_fail]`
  - `AI_REPLAN_TRACE[service_apply_rollback_ok]`
  - `AI_REPLAN_TRACE[service_apply_rollback_fail]`
- 手工验收建议：
  - KEEP 正常路径
  - OVERWRITE 正常路径
  - OVERWRITE 人工注入失败路径（验证 UI 与数据恢复）

## 6. 计划与实现一致性
- 计划文档：`docs/refactor/ai-rewrite-stability-plan.md`
- 本交付说明与计划保持一一对应（A/B/C/D）。
