# Branches 覆盖率真实现状与补齐计划

日期：2026-04-24

## 1. 本次统计方式

本次结论基于实际运行结果，不引用历史报告。

执行命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
cd backend
npm test -- --coverage --coverageReporters=json-summary --coverageReporters=text-summary
```

说明：
- 前端 `entry` 的 coverage 来自 `entry/.test/default/outputs/test/reports/index.html`
- 后端 `backend` 的 coverage 来自 `backend/coverage/coverage-summary.json`
- 两端测试体系不同，建议分开跟踪；若只看“项目可量化分支总和”，可做一个加权汇总作为参考

## 2. 当前真实 Branches 比例

### 2.1 前端 entry

- Branches：`4935/6401 = 77.10%`

目录级分布：

| 模块 | Branches |
|---|---:|
| `model` | `48/90 = 53.33%` |
| `entryability` | `20/32 = 62.50%` |
| `pages` | `1490/2105 = 70.78%` |
| `infrastructure` | `1160/1506 = 77.03%` |
| `viewmodel` | `447/554 = 80.69%` |
| `domain` | `1562/1866 = 83.71%` |
| `common` | `208/248 = 83.87%` |

### 2.2 后端 backend

- Branches：`200/223 = 89.68%`

后端低位文件：

| 文件 | Branches |
|---|---:|
| `src/config/pg.service.ts` | `3/4 = 75.00%` |
| `src/config/app-config.service.ts` | `15/18 = 83.33%` |
| `src/modules/auth/auth.service.ts` | `80/94 = 85.10%` |
| `src/modules/auth/auth.controller.ts` | `28/32 = 87.50%` |
| `src/common/filters/all-exceptions.filter.ts` | `15/16 = 93.75%` |

### 2.3 汇总参考

若把前后端两个测试体系按分支总数直接合并：

- Branches：`5135/6624 = 77.52%`

注意：这个数仅适合作为全项目粗略参考，不适合作为单一验收口径。实际推进应以前端 `entry` 为主，因为当前主要短板明显在前端。

## 3. 当前主要短板

### 3.1 前端短板一：`pages`

`pages` 目前是前端分支覆盖的主拖累项：`1490/2105 = 70.78%`

其中低位热点：

| 文件/目录 | Branches |
|---|---:|
| `pages/MyPage.ets` | `51/98 = 52.00%` |
| `pages/MapPickerPage.ets` | `56/104 = 53.80%` |
| `pages/components/dialogs` | `233/430 = 54.19%` |
| `pages/LoginPage.ets` | `41/62 = 66.10%` |
| `pages/PlanListPage.ets` | `53/72 = 73.60%` |

额外热点：

| 文件/目录 | Branches |
|---|---:|
| `pages/index/IndexCompanionOverlay.ets` | `1/2 = 50.00%` |
| `pages/index/IndexTimelineView.ets` | `5/10 = 50.00%` |
| `pages/index/IndexAddDialogHelper.ets` | `15/22 = 68.20%` |

### 3.2 前端短板二：`model`

`model` 当前只有 `53.33%`，但分支总量不大，属于“低成本高收益区”。

| 文件/目录 | Branches |
|---|---:|
| `model/acl` | `46/88 = 52.27%` |

这块适合用小批量纯逻辑测试快速抬升。

### 3.3 前端短板三：`infrastructure/services`

这块分支总量大，适合做第二梯队补齐。

| 文件 | Branches |
|---|---:|
| `AmapWeatherService.ets` | `59/96 = 61.50%` |
| `AiResponseParser.ets` | `76/118 = 64.40%` |
| `ArrivalReminderCoordinator.ets` | `30/46 = 65.20%` |
| `AmapService.ets` | `137/198 = 69.20%` |
| `TrafficEngine.ets` | `28/40 = 70.00%` |
| `AiService.ets` | `164/214 = 76.60%` |

### 3.4 后端现状判断

后端已经到 `89.68%`，继续补当然还能涨，但边际收益明显小于前端。

结论：
- 后端不应再作为主战场
- 后端仅保留“顺手补齐剩余纯逻辑分支”的次优先级

## 4. 补齐策略

### 原则

1. 先打前端 `pages`，因为分支总量最大、收益最高
2. 优先纯 helper / 纯函数 / fallback / 文案 / toggle / guard / trim / 空值分支
3. 尽量避免先碰重状态耦合、真渲染副作用、复杂异步链
4. 后端只补剩余低成本分支，不再投入大批量资源

## 5. 分阶段计划

## Phase A：高收益低风险批次

目标：先把前端主短板从 77.10% 往上拉，优先补最容易稳定落地的分支。

### A1. `pages/components/dialogs`

原因：
- 分支体量大：`430`
- 当前低：`54.19%`
- 多数是纯状态 / 纯文案 / fallback / confirm 分支，适合批量补

执行方式：
- 按对话框类型分批
- 每批 2 到 4 个 dialog
- 重点覆盖：
  - `show/hide`
  - 空值 / 默认值
  - `confirm/cancel`
  - 文案 fallback
  - loading / disabled
  - guard 分支

优先文件：
- `AddItemDialog.ets`
- `AdvanceAdjustDialog.ets`
- `AiInputDialog.ets`
- `AiReplanPreviewDialog.ets`
- `ConflictCompressDialog.ets`
- `DateConflictDialog.ets`
- `GapResolutionDialog.ets`
- `PlanImportDialog.ets`
- `PlanJsonImportDialog.ets`
- `PlanJsonExportDialog.ets`
- `PlanSettingsDialog.ets`
- `PlanShareDialog.ets`

### A2. `MyPage.ets`

原因：
- 单文件低位明显：`52/98 = 52.00%`
- 分支多，且大量是 username/avatar/hint/profile fallback

重点覆盖：
- username trim / 空白 / 超长 / 默认值
- light hint key 标准化
- hint 去重 / ready / bootstrap 状态
- remote avatar 优先级
- guest / session / profile fallback 组合

### A3. `MapPickerPage.ets`

原因：
- 单文件低位明显：`56/104 = 53.80%`
- 多为地址、坐标、center hint、storage key、distance fallback 这类纯逻辑分支

重点覆盖：
- unknown address / blank address
- center hint 可见性
- distance resolving
- resolving 状态与 fallback 文案
- storage key / cache key

### A4. `LoginPage.ets`

原因：
- `41/62 = 66.10%`
- 登录场景分支清晰，已有 helper，补边界收益高

重点覆盖：
- scene start / same-scene guard / override
- 协议勾选 guard
- error code 解析
- fallback toast
- provider 失败文案差异

## Phase B：中高收益批次

### B1. `PlanListPage.ets`

当前：`53/72 = 73.60%`

重点：
- share item builder
- start/end time fallback
- category/icon fallback
- reprompt cooldown
- duration/dayOffset 边界

### B2. `pages/index`

当前明显低位：
- `IndexCompanionOverlay.ets`：`1/2`
- `IndexTimelineView.ets`：`5/10`
- `IndexAddDialogHelper.ets`：`15/22`

重点：
- overlay show/hide 组合
- timeline empty/data/loading 三态
- add dialog 模式切换
- callback guard
- archived / readonly / companion 分支

### B3. `entryability/EntryAbility.ets`

当前：`20/32 = 62.50%`

重点：
- 启动来源
- want 参数空值 / 异常值
- 生命周期分支
- 路由初始化 fallback

这是一个值得单独开批次的点，因为分支总量不大，但提升很直接。

## Phase C：低成本抬升批次

### C1. `model/acl`

当前：`46/88 = 52.27%`

重点：
- 地图服务接口适配
- 参数边界
- null/undefined fallback
- 空数组 / 单元素 / 非法坐标

这块推荐尽快补，因为开发成本低、覆盖率提升效率高。

### C2. `domain/solver/TimeConstraintSolver.ets`

当前：`74/106 = 69.81%`

重点：
- 时间边界
- 冲突不可解
- 压缩后仍冲突
- 单元素 / 空输入 / 超时段

### C3. `infrastructure/persistence`

当前：
- `PlanRepositoryImpl.ets`：`73.70%`
- `EventRepositoryImpl.ets`：`75.50%`
- `UserProfileRepositoryImpl.ets`：`77.10%`

重点：
- 查询空结果
- 可选字段 fallback
- status 分支
- 排序 / 条件过滤

## Phase D：后端收尾批次

目标：仅在前端主干批次完成后，再决定是否投入。

优先文件：
- `src/config/pg.service.ts`
- `src/config/app-config.service.ts`
- `src/modules/auth/auth.service.ts`
- `src/modules/auth/auth.controller.ts`

重点：
- 空 env / 注释行 / 非法 key=value
- token/header 边界
- social login 失败 phase
- session inactive / expired / missing row

说明：
- 后端已接近 `90%`
- 不建议现在优先做

## 6. 建议执行顺序

建议按下面顺序推进：

1. `pages/components/dialogs`
2. `MyPage.ets`
3. `MapPickerPage.ets`
4. `LoginPage.ets`
5. `PlanListPage.ets`
6. `pages/index` 低位文件
7. `EntryAbility.ets`
8. `model/acl`
9. `domain/solver/TimeConstraintSolver.ets`
10. `infrastructure/services`
11. 后端剩余低位文件

## 7. 本轮目标建议

如果下一轮继续补，我建议先做这三组：

### 第一组
- `pages/components/dialogs`
- `MyPage.ets`

### 第二组
- `MapPickerPage.ets`
- `LoginPage.ets`

### 第三组
- `IndexCompanionOverlay.ets`
- `IndexTimelineView.ets`
- `EntryAbility.ets`

理由：
- 都是当前低位
- 分支密度高
- 多数可以用 helper / 纯逻辑测试稳定补齐
- 对前端总分支提升最直接

## 8. 当前结论

当前项目真实情况是：

- 前端 `entry` Branches：`77.10%`
- 后端 `backend` Branches：`89.68%`
- 若简单合并统计：`77.52%`

真正需要优先补的不是 backend，而是前端的：

- `pages`
- `model/acl`
- `entryability`
- `infrastructure/services`

其中第一优先级是：

- `pages/components/dialogs`
- `MyPage.ets`
- `MapPickerPage.ets`
- `LoginPage.ets`
