# Travel Domino 非核心单测回归报告

- 报告日期: 2026-04-12
- 依据计划: `docs/quality/noncore-unit-test-backfill-plan.txt`（版本 2026-04-11）
- 报告范围: 非核心测试批次 N1/N2/N3/N4 收口结果

## 一、覆盖范围

### N1 聚合与基础工具
- 维护并持续可验收运行 `List.test.ets`、`WeatherP0Suite.test.ets`、`AutomatedTest.test.ets`。
- 补齐低风险 helper 类用例，统一为 6 类 case（normal/boundary/invalid/conflict/regression/combined）与 AAA 结构。

### N2 后端非核心基础设施
- 覆盖并通过 backend 非核心模块测试（`backend/test/*.spec.ts`，共 17 套件）。
- 验收命令 `npm test -- --runInBand` 已恢复并通过。

### N3 页面状态编排层（pages/index）
- 已补齐并接入 index 相关测试套件，包含状态切换、参数校验、事件冲突、组合触发路径。
- `List.test.ets` 中历史未接入的 index 测试已全部挂载，当前未接入项为 0。

### N4 UI 组件层（dialogs/views/companion）
- 已完成组件 helper 补测扩展与接入，覆盖 dialogs、views、companion 子模块的输入输出行为。
- 典型新增批次包括：
  - `GapResolutionDialogThresholds.test.ets`
  - `EventItemViewConflictGapEdge.test.ets`
  - `PlanItemViewTimeAndConflictEdge.test.ets`
  - `ArchivePageHelper.test.ets`
  - `TrashPageHelper.test.ets`

## 二、验收结果

### 结构规则验收
- 命令: `powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1`
- 结果: 通过（`checked 172 files`）

### 客户端单测验收
- 命令: `powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1`
- 结果: 通过（`BUILD SUCCESSFUL`）

### 后端单测验收（N2）
- 命令: `cd backend && npm test -- --runInBand`
- 结果: 通过（`17 passed, 17 total`；`104 passed, 104 total`）

## 三、失败项与修复

### 已修复失败项
- 问题: backend 测试阶段缺失 `typescript/lib/typescript.js`，导致 `ts-jest` 无法加载。
- 处理: 重装并校正 TypeScript 依赖，更新 `backend/package-lock.json` 后恢复。
- 结果: backend 全量测试恢复通过。

### 当前失败项
- 无阻断失败项。

## 四、修复建议

- 继续保持 `List.test.ets` 作为统一接入清单，新增 `*.test.ets` 时同步接入，避免“有文件未执行”。
- 保持 backend 依赖一致性，出现 `ts-jest/typescript` 异常时优先检查 `node_modules/typescript/lib/typescript.js` 与 lockfile。
- 新增 helper 测试时保持 6 类 case + AAA 结构，减少回归盲区。

## 五、剩余风险

- 构建日志仍存在第三方依赖告警（主要来自 `oh_modules`），当前不影响测试通过，但建议后续分批治理。
- 长期迭代下 `List.test.ets` 接入项较多，人工维护易漏，建议后续增加自动化接入校验脚本。

## 六、结论

- 本次非核心单测回填计划（N1/N2/N3/N4）已完成收口。
- 当前满足计划中的完成判定：
  1. 非核心测试结构规则通过。
  2. 分层验收通过（客户端与后端均可独立回归）。
  3. 已输出最终回归报告（本文件）。
