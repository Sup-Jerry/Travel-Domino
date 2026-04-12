# Travel Domino 单测“真正全覆盖”总体规划

- 版本: v1
- 制定日期: 2026-04-12
- 适用范围: `entry`（Hypium）+ `backend`（Jest）

## 1. 当前基线（2026-04-12）

1. `entry` 基线（来自 `js_coverage.json`）  
   - 覆盖文件: `182`  
   - 有命中文件: `162`（`89.01%`）  
   - 函数命中: `895/6711`（`13.34%`）  
   - `0-hit` 文件: `20`
2. `backend` 基线（`npm test -- --coverage --runInBand`）  
   - Stmts `79.05%`  
   - Branch `53.95%`  
   - Funcs `76.36%`  
   - Lines `76.58%`

## 2. “真正全覆盖”定义

1. 覆盖对象: `entry/src/main/ets/**` 与 `backend/src/**` 的可执行业务代码。
2. 目标阈值: `Statements/Branches/Functions/Lines = 100%`。
3. 排除规则: 仅允许“不可执行声明类文件”进入显式排除清单，并要求逐条写明原因（禁止隐式排除）。
4. 质量前提: 用例必须继续满足现有规范（6 类 case + AAA + 回归 case）。

## 3. 三阶段路线图

### 第一阶段：先补齐 20 个 0-hit（清零阶段）

目标: 将 `0-hit` 文件从 `20 -> 0`，完成“全模块至少被执行一次”的底座建设。

#### 3.1 待清零文件（20个）

1. `entry/src/main/ets/domain/services/PlanShareImageService.ets`
2. `entry/src/main/ets/domain/strategy/UserProfileService.ets`
3. `entry/src/main/ets/infrastructure/services/ArrivalReminderCoordinator.ets`
4. `entry/src/main/ets/domain/serializers/CompactPlanSerializer.ets`
5. `entry/src/main/ets/viewmodel/TimelineInteractionHelper.ets`
6. `entry/src/main/ets/infrastructure/auth/AuthApiClient.ets`
7. `entry/src/main/ets/common/utils/NavigationHelper.ets`
8. `entry/src/main/ets/infrastructure/auth/AuthGateway.ets`
9. `entry/src/main/ets/domain/services/DeepLinkService.ets`
10. `entry/src/main/ets/domain/strategy/UserBehaviorTracker.ets`
11. `entry/src/main/ets/common/utils/arrival/ArrivalReminderStore.ets`
12. `entry/src/main/ets/infrastructure/adapters/HttpRequestHelper.ets`
13. `entry/src/main/ets/common/utils/ArrivalLiveActivityBridge.ets`
14. `entry/src/main/ets/domain/services/QRCodeService.ets`
15. `entry/src/main/ets/domain/timeline/ConflictDetector.ets`
16. `entry/src/main/ets/model/interface/IMapService.ets`
17. `entry/src/main/ets/domain/statemachine/PlanStatus.ets`
18. `entry/src/main/ets/domain/services/WeatherRefreshScheduler.ets`
19. `entry/src/main/ets/domain/strategy/TravelStrategyMode.ets`
20. `entry/src/main/ets/infrastructure/adapters/NotificationGateway.ets`

#### 3.2 执行策略

1. 按风险优先: `infrastructure/auth|service` > `domain/service|strategy` > `declaration/interface`。
2. 每个文件至少补 1 组“可执行路径命中”用例；复杂文件直接补 6 类完整 case。
3. 新增测试统一接入 `entry/src/test/List.test.ets`，防止“有文件不执行”。

#### 3.3 阶段验收

1. `0-hit` 文件数必须为 `0`。
2. `entry` 函数命中率从 `13.34%` 提升到 `>=35%`（阶段门槛）。
3. 全量命令通过（见第 5 节）。

### 第二阶段：低覆盖核心深补（提质阶段）

目标: 将“已命中但覆盖浅”的核心模块补到高覆盖，重点打穿分支和冲突路径。

#### 3.4 重点对象（示例）

1. `entry` 侧低覆盖核心：  
   - `domain/timeline/services/TimelineWeatherService.ets`  
   - `pages/components/views/CompanionView.ets`  
   - `pages/components/views/EventItemView.ets`  
   - `pages/index/IndexTopArea.ets`  
   - `infrastructure/auth/AuthFacade.ets`
2. `backend` 侧重点：  
   - `src/modules/auth/auth.service.ts`（当前短板）  
   - 以及分支覆盖偏低的认证相关流程。

#### 3.5 执行策略

1. 覆盖“主流程 + 异常 + 边界 + 状态冲突 + 回归”。
2. 优先补 `Branch` 缺口，不只追 `Statement`。
3. 每轮改动都跑最快相关测试，再跑全量回归。

#### 3.6 阶段验收

1. `entry` 函数命中率达到 `>=75%`，分支命中率达到 `>=65%`。
2. `backend` 分支覆盖率达到 `>=80%`。
3. 高风险模块（认证/提醒/时间线）无未覆盖核心分支。

### 第三阶段：收口到“真正全覆盖”（封板阶段）

目标: 达成并锁定 `100%` 覆盖（在定义范围内）。

#### 3.7 执行策略

1. 逐文件清尾到 `100%`，对无法执行代码先重构为可测，再决定是否进入显式排除清单。
2. 增加覆盖率门禁：  
   - `backend`: 设置 Jest 全局阈值 `100%`。  
   - `entry`: 新增覆盖检查脚本（基于 `js_coverage.json`），对纳入范围文件强制 `100%`。
3. PR 门禁: 任一覆盖指标回退即阻断合并。

#### 3.8 阶段验收

1. `entry` 与 `backend` 在定义范围内均达到 `100/100/100/100`。
2. 连续 `3` 次全量回归稳定通过（无随机失败）。
3. 形成最终覆盖报告与排除清单（含每条理由与责任人）。

## 4. 交付物清单

1. 分阶段补测 PR（按模块批次提交，保持小 diff）。
2. 覆盖率报告（每阶段一版）。
3. 覆盖率门禁脚本与 CI 配置。
4. 最终“全覆盖封板报告”。

## 5. 每阶段统一验收命令

1. `powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1`
2. `powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1`
3. `cd backend && npm test -- --coverage --runInBand`

## 6. 里程碑建议

1. M1（第1周）: 完成 20 个 `0-hit` 清零。
2. M2（第2-3周）: 完成低覆盖核心深补并达到阶段阈值。
3. M3（第4周）: 全覆盖收口 + CI 强门禁 + 封板报告。
