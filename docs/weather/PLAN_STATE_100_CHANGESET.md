# PlanStateMachine 100% 变更清单

日期：2026-03-20

## 1. 本次收口目标
- 文档包（`E:\Travel12.19\待更新\状态机1`）100% 闭环
- 交付三件套：完成矩阵、回归报告、变更清单
- 白名单提交：仅状态机收口相关改动

## 2. 关键改动
- 状态机核心：计划级状态机、迁移引擎、评估器、事件总线、通知桥、天气策略、重排协调器
- 持久化：`ExecutionContextStore`（上下文与迁移日志）
- VM/UI：`TimelineViewModel`、`CompanionView`、`SettingsPage`
- 软重排：结构化 `changeSummary` 全链路落地
- 监控：本地指标仓 + 诊断快照导出 + 核对脚本
- 测试：核心链路、联动、异常、恢复、诊断导出

## 3. 白名单文件（收口范围）
- `entry/src/main/ets/domain/statemachine/*`
- `entry/src/main/ets/infrastructure/persistence/ExecutionContextStore.ets`
- `entry/src/main/ets/domain/services/WeatherModels.ets`
- `entry/src/main/ets/viewmodel/TimelineViewModel.ets`
- `entry/src/main/ets/pages/SettingsPage.ets`
- `entry/src/main/ets/pages/components/views/CompanionView.ets`
- `entry/src/main/ets/common/constants/AppStorageKeys.ets`
- `entry/src/test/PlanStateMachineCore.test.ets`
- `entry/src/test/PlanStateMachineLink.test.ets`
- `entry/src/test/PlanStateMachineTCSuite.test.ets`
- `entry/src/test/WeatherPolicyResolver.test.ets`
- `scripts/ci/verify_plan_state_snapshot.ps1`
- `docs/weather/PLAN_STATE_100_CLOSURE_MATRIX.md`
- `docs/weather/PLAN_STATE_100_REGRESSION_REPORT.md`
- `docs/weather/PLAN_STATE_100_CHANGESET.md`

## 4. 风险与处置
- 历史 warning 未在本次收口内处理，不影响状态机验收结论。
- 历史非状态机测试日志噪声保留（门禁退出码正常），已在回归报告标注。
- 未纳入白名单的无关未跟踪文件禁止进入最终提交。
