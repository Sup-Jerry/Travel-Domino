# 天气 P0 测试基线状态（豁免清单）

## 1. 当前状态
- `assembleHap` 可通过。
- `hvigor test` 失败原因主要是历史测试基线问题，不属于本次天气 P0 改动引入。

## 2. 已确认环境问题
- 现象：历史出现过 `.hvigor/dependencyMap` 权限错误（EPERM）。
- 处理步骤：
  - `attrib -R .hvigor\\dependencyMap`
  - 再执行 `./hvigorw.bat -p product=default test`

## 3. 历史基线失败（非本次新增）
- 类型 A：旧测试 `any/unknown` 触发 ArkTS 规则失败（`arkts-no-any-unknown`）。
- 类型 B：旧测试 import 路径失效（`Cannot find module ...`）。
- 代表文件：
  - `entry/src/test/LocalUnit.test.ets`
  - `entry/src/test/TimeConstraintSolver.test.ets`
  - `entry/src/test/AiService.test.ets`
  - `entry/src/test/ArrivalReminderEngine.test.ets`
  - `entry/src/test/ScheduleOrchestrator.test.ets`
  - `entry/src/test/TimelineDatePolicy.test.ets`

## 4. 本次天气 P0 相关测试（应重点观察）
- `entry/src/test/PreferenceManager.test.ets`
- `entry/src/test/WeatherRiskEvaluator.test.ets`
- `entry/src/test/WeatherExecution.test.ets`
- `entry/src/test/WeatherP0Suite.test.ets`（天气 P0 组合入口）

## 5. 门禁建议
- 门禁 1（必过）：`assembleHap`
- 门禁 2（准入）：天气 P0 验收清单 + 关键日志核对
- 门禁 3（持续治理）：逐步清理历史测试基线后恢复全量 `hvigor test`
