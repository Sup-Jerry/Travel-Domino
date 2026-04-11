# 第六阶段实验操作手册（基于 `E:\Travel`）

## 1. 目的

本手册用于指导你在真机/模拟器上采集论文实验数据。  
本轮已在代码中加入统一实验日志前缀：`[PAPER_EXP]`。

你按本文步骤执行后，把日志文件和结果表给我，我会帮你整理成论文第 6 章可直接使用的图表与分析。

---

## 2. 已插入的日志点

已插桩文件：

1. `entry/src/main/ets/domain/solver/TimeConstraintSolver.ets`
2. `entry/src/main/ets/viewmodel/managers/TimelineRecalculationManager.ets`
3. `entry/src/main/ets/domain/timeline/services/TimelineCompressionService.ets`
4. `entry/src/main/ets/domain/timeline/services/TimelineDistributionService.ets`

核心日志类型：

1. `solver_summary`
2. `vm_summary`
3. `recalc_trigger`
4. `compression_plan`
5. `compression_apply`
6. `advance_apply`
7. `distribution_preview`
8. `distribution_apply`
9. `distribution_auto`

---

## 3. 字段释义（你会用到的）

### 3.1 汇总日志

`[PAPER_EXP][solver_summary]` / `[PAPER_EXP][vm_summary]` 主要字段：

1. `total`：排程事件总数
2. `conflict`：冲突事件数
3. `conflictMin`：冲突分钟总量
4. `gap`：空隙事件数
5. `gapMin`：空隙分钟总量
6. `overflow`：跨天溢出事件数（`dynamic_day_offset > day_offset`）
7. `durationMin`：事件停留时长总和
8. `travelMin`：通勤分钟总和
9. `spanMin`：从最早动态开始到最晚动态结束的总跨度
10. `utilPermille`：时间利用率（千分比，`750` 表示 `75.0%`）

### 3.2 机制日志

1. `compression_plan`：压缩方案计算结果（`COMPRESS_CONFIRM` / `OVERLOAD`）
2. `compression_apply`：压缩方案是否落地、总压缩分钟数
3. `advance_apply`：前移调整是否成功、剩余冲突分钟数
4. `distribution_preview`：空隙分配预览（策略、分配总量）
5. `distribution_apply` / `distribution_auto`：空隙分配实际落地

---

## 4. 实验前准备

### 4.1 编译与运行

在仓库根目录执行：

```powershell
cmd /c "entry\hvigorw.bat --no-daemon --mode module -p module=entry -p product=default -p buildMode=debug assembleHap"
```

然后在 DevEco Studio 安装并运行 App。

### 4.2 建议准备目录

```powershell
New-Item -ItemType Directory -Force -Path E:\Travel\.tmp\paper-exp | Out-Null
```

---

## 5. 日志采集操作（建议两终端）

### 终端 A：开始抓日志

先清空旧日志：

```powershell
hdc shell hilog -r
```

开始抓取并过滤：

```powershell
hdc shell hilog | findstr PAPER_EXP
```

如果你想直接写入文件：

```powershell
hdc shell hilog | findstr PAPER_EXP > E:\Travel\.tmp\paper-exp\E1_raw.log
```

执行实验后按 `Ctrl + C` 结束采集。

### 终端 B：执行实验动作

在 App 内按场景进行操作（见第 6 节）。

---

## 6. 实验执行步骤（可直接照做）

## 6.1 E1：冲突与利用率对比（基础组）

目标：采集 `total/conflict/conflictMin/gap/gapMin/utilPermille`。

步骤：

1. 创建或载入一个固定测试场景（建议 8-10 个事件，含 2-3 个固定锚点）。
2. 在同一场景下跑 3 种策略模式：
3. `DEFAULT`（`slackRatio=0`）
4. `SOLDIER`（`slackRatio=0.1`）
5. `LEISURE`（`slackRatio=0.4`）
6. 每切换一次模式，都触发一次重算（新增/编辑一个事件后保存即可）。
7. 记录每次对应的 `[PAPER_EXP][vm_summary]` 与 `[PAPER_EXP][solver_summary]`。

产出：

1. `E1_raw.log`
2. 一张对比表（模式 vs conflict/gap/util）

## 6.2 E2：`slackRatio` 敏感性

目标：观察缓冲增大对冲突率与利用率的变化。

步骤：

1. 使用同一场景，不改事件输入。
2. 分别切换到 `DEFAULT/SOLDIER/LEISURE` 并触发重算。
3. 从日志提取每轮 `utilPermille`、`conflict`、`conflictMin`。

产出：

1. `E2_raw.log`
2. 折线图（`x=slackRatio`, `y1=conflict`, `y2=utilPermille`）

## 6.3 E3：压缩修复效果

目标：统计压缩修复成功/失败与剩余冲突。

步骤：

1. 构造一个必然冲突场景（固定时间窗口内总时长超载）。
2. 触发冲突后进入压缩修复流程。
3. 分别尝试可修复与不可修复两类输入。
4. 提取：
5. `compression_plan`（看 `status`）
6. `compression_apply`（看 `affected/totalReducedMin`）
7. `advance_apply`（看 `success/remaining`）

产出：

1. `E3_raw.log`
2. 成功率表：`成功次数 / 总触发次数`
3. 失败原因记录（`OVERLOAD` 为主）

## 6.4 E4：空隙分配效果

目标：比较空隙分配策略效果与落地强度。

步骤：

1. 构造大空隙场景（例如固定事件前出现 120+ 分钟空隙）。
2. 在分配对话中分别用两种策略执行（`EQUAL`、`SMART`）。
3. 提取：
4. `distribution_preview`（看 `allocated/remain`）
5. `distribution_apply`（看 `affected/totalAdd`）

产出：

1. `E4_raw.log`
2. 策略对比表（策略 vs 分配总量/影响事件数）

---

## 7. 数据整理模板（发我这些就够）

每组实验给我下面 7 项：

1. 实验编号（如 `E1`）
2. 场景输入（事件列表：时长/固定时间/通勤/锁定状态）
3. 参数（策略模式、是否自动通勤、是否触发压缩/分配）
4. 原始日志文件（`*_raw.log`）
5. 你手工整理的指标表（Excel 或 Markdown）
6. 截图（关键前后对比）
7. 你观察到的现象说明（2-5 条即可）

---

## 8. 常见问题

### 8.1 日志太多看不清

只保留 `PAPER_EXP`：

```powershell
Get-Content E:\Travel\.tmp\paper-exp\E1_raw.log | Select-String "PAPER_EXP" | Set-Content E:\Travel\.tmp\paper-exp\E1_only.log
```

### 8.2 想看某类日志

```powershell
Get-Content E:\Travel\.tmp\paper-exp\E3_raw.log | Select-String "compression_plan|compression_apply|advance_apply"
```

### 8.3 利用率怎么换算百分比

`utilPermille / 10 = 百分比`。  
例如 `utilPermille=736`，即 `73.6%`。

---

## 9. 说明

本手册默认你先做可复现实验，不要求一次跑大量随机样本。  
建议每个实验先做 3-10 组高质量场景，再扩展。
