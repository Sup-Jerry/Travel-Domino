# 天气 P0 测试基线说明（豁免清单）

## 1. 目标
- 说明哪些失败属于历史基线问题，不归因于本次天气 P0 改动。
- 固化本机环境阻断处理步骤，确保可复跑。

## 2. 环境问题固定步骤（`.hvigor/dependencyMap`）
1. 在项目根目录执行：`attrib -R .hvigor\\dependencyMap`
2. 如仍失败，执行：`del /F /Q .hvigor\\dependencyMap`
3. 重新执行：`./hvigorw.bat -p product=default test`

## 3. 历史基线候选文件
- `entry/src/test/LocalUnit.test.ets`
- `entry/src/test/TimeConstraintSolver.test.ets`
- `entry/src/test/AiService.test.ets`
- `entry/src/test/ArrivalReminderEngine.test.ets`
- `entry/src/test/ScheduleOrchestrator.test.ets`
- `entry/src/test/TimelineDatePolicy.test.ets`

## 4. 天气最小回归组
- `entry/src/test/PreferenceManager.test.ets`
- `entry/src/test/WeatherRiskEvaluator.test.ets`
- `entry/src/test/WeatherExecution.test.ets`
- `entry/src/test/WeatherP0Suite.test.ets`

## 5. 门禁策略
- 门禁1（强门禁）：`assembleHap` 必须通过。
- 门禁2（强门禁）：天气最小回归组必须通过。
- 门禁3（准门禁）：全量 `hvigor test` 产出分离报告，允许历史失败存在。
