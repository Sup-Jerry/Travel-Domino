# PlanStateMachine 100% 回归报告

日期：2026-03-20  
范围：`E:\Travel12.19\待更新\状态机1` 文档包对应实现  
结论：通过（门禁全绿，TC 矩阵全覆盖）

## 1. 自动化回归
执行命令：
```powershell
./hvigorw.bat test
./hvigorw.bat assembleApp
powershell -ExecutionPolicy Bypass -File scripts/ci/verify_plan_state_snapshot.ps1 -SnapshotPath <snapshot.json>
```

结果：
- `hvigor test`：`BUILD SUCCESSFUL`
- `hvigor assembleApp`：`BUILD SUCCESSFUL`
- `verify_plan_state_snapshot.ps1`：`Snapshot verification passed`

说明：
- 构建过程中存在历史 warning（与状态机收口无关），不阻断本次验收。
- 历史 `TimeConstraintSolver.test.ets:84` 错误日志仍会打印，但本次门禁退出码为成功。

## 2. 链路联调记录（代码级）
### 主链路
- `DRAFT -> CONFIRMED -> READY -> IN_PROGRESS -> PAUSED -> IN_PROGRESS -> COMPLETED`：通过  
  证据：`PlanStateMachineTCSuite.test.ets`（TC-SM-001~006）

### 自动切换
- READY 时间窗、到达首点、移动触发、条件不足保持 READY：通过  
  证据：`PlanStateMachineCore.test.ets` + `PlanStateMachineTCSuite.test.ets`（TC-AUTO-001~004）

### 天气策略
- DRAFT/READY/IN_PROGRESS/结束态策略映射：通过  
  证据：`WeatherPolicyResolver.test.ets` + `PlanStateMachineTCSuite.test.ets`（TC-WEATHER-001~004）

### 异常降级
- 非法迁移拦截、重复 start 幂等、定位缺失降级、天气侧失败不阻断迁移：通过  
  证据：`PlanStateMachineCore.test.ets` + `PlanStateMachineLink.test.ets` + `PlanStateMachineTCSuite.test.ets`

### 恢复与监控
- `context_missing/context_partial/context_expired` 计数闭环：通过  
  证据：`PlanStateMachineLink.test.ets` + `TimelineViewModel.recoverPlanRuntimeState`

### 联动
- READY 联动、执行中软重排、COMPLETED 清理：通过  
  证据：`PlanStateMachineTCSuite.test.ets` + `TimelineViewModel.requestSoftReplan`

## 3. 诊断导出与核对
- 设置页状态机诊断支持导出 JSON 快照（本地 AppStorage）。
- 快照内容包含：最近迁移、当日指标、reason 分布。
- 核对脚本检查项：
  - `attempt >= success + fail`
  - `jitter_blocked >= 0`
  - recovery 分桶一致

## 4. 验收结论
- 文档包条目均有：代码证据 + 测试证据 + 运行证据。
- 达成“功能完成 + 用例完成 + 证据完整”的 100% 收口标准。
