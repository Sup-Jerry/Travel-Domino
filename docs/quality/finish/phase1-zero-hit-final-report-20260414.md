# 阶段1收口留档（0-hit 清零核验）

- 生成时间：2026-04-14
- 数据来源：`entry/.test/default/outputs/test/reports/coverageReport.json`
- 路线图：`docs/quality/full-coverage-roadmap.md`

## 1. 执行证据

1. `powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1`
   - 结果：`success: checked 197 files`
2. `powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1`
   - 结果：`BUILD SUCCESSFUL`
   - 备注：存在既有 ArkTS WARN（不阻塞门禁）

## 2. 最新覆盖统计（entry/src/main/ets/**）

- 覆盖文件数：`183`
- 有命中文件数：`182`
- 原始 0-hit 文件数：`1`
- 行覆盖：`8155/27907`（`29.22%`）
- 函数覆盖：`1094/6737`（`16.24%`）
- 分支覆盖：`1889/6209`（`30.42%`）

## 3. 0-hit 结果判定

### 3.1 原始口径（严格按覆盖工具输出）

- `0-hit = 1`
- 文件：`entry/src/main/ets/model/interface/IMapService.ets`

### 3.2 有效口径（按路线图允许的显式排除）

- `0-hit = 0`
- 显式排除清单：
  1. `entry/src/main/ets/model/interface/IMapService.ets`
     - 原因：接口声明文件，覆盖工具将接口签名记为可统计行，但无可执行路径，无法通过运行时命中。
     - 处理：作为“声明类不可执行文件”纳入显式排除项（满足路线图“仅允许显式排除且逐条给原因”的要求）。

## 4. 阶段1结论

- 若按**原始工具口径**：阶段1尚差 `1` 个 0-hit（声明文件）。
- 若按**项目有效口径（显式排除声明文件）**：阶段1达到 `0-hit=0`，可判定完成并进入阶段2。

---

# 阶段2 Batch E 持续推进（本轮）

## 1. 本轮新增/更新

- 更新测试文件：`entry/src/test/Phase2CoreCoverageBatchE.test.ets`
- 新增覆盖点：
  1. `TimelineWeatherService` 风险解释文案分支（高/中/低风险 + 无效分值）
  2. `TimelineWeatherService` 自动刷新窗口分支（新鲜数据/过期数据/无计划ID）
  3. `TimelineWeatherService` 软重排目标与不可变节点判定分支

## 2. Batch E 相关模块最新覆盖

1. `TimelineWeatherService.ets`
   - Lines: `425/1054`（`40.32%`）
   - Functions: `56/139`（`40.29%`）
   - Branches: `111/314`（`35.35%`）
2. `AuthFacade.ets`
   - Lines: `180/335`（`53.73%`）
   - Functions: `17/23`（`73.91%`）
   - Branches: `41/96`（`42.71%`）

## 3. 下一步（Batch E继续）

- 继续优先补 `TimelineWeatherService` 的执行态重规划主链分支（`requestSoftReplan/applySuggestionAction` 失败与回滚路径）。
- 然后转入阶段2剩余低覆盖核心：`CompanionView/EventItemView/IndexTopArea`。
