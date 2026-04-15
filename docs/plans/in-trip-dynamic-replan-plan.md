# 在途动态重排实施计划

## 1. 痛点定义

**当前状态**：用户在旅途中遇到延误、排队、天气变化、闭园、拥堵时，系统只能提示"风险"，无法给出可执行的修复动作。

**目标状态**：系统在检测到行程偏差时，自动生成 A/B 处置方案，用户一键确认即可落地到下一步动作。产品从"规划器"升级为"旅行调度器"。

---

## 2. 成功标准

- 触发条件可配置（延误阈值、排队时长、天气等级）
- 每次触发输出至少 2 个处置方案，含代价说明
- 用户一键执行后，时间轴立即更新，无需手动调整
- 不破坏已锁定事件（lock_status=1）
- 全链路有日志可追踪（前缀 `REPLAN_TRIGGER_TRACE`）

---

## 3. 核心概念

| 概念 | 说明 |
|------|------|
| 触发器 | 检测偏差的条件（延误/排队/天气/闭园） |
| 处置方案 | 顺延 / 删点 / 换序 / 改交通方式 |
| 代价说明 | 保住了什么，牺牲了什么 |
| 一键执行 | 方案确认后直接写入时间轴 |

---

## 4. 范围

**包含**：
- 延误触发检测逻辑
- 方案生成（顺延、删点、换序）
- 代价计算与展示
- 一键执行写入时间轴
- 触发历史记录

**不包含**：
- 改交通方式（依赖地图 API，后续迭代）
- 多人协作下的方案冲突处理
- 推送通知

---

## 5. 目标文件与职责

### 5.1 新增文件

| 文件 | 职责 |
|------|------|
| `domain/timeline/services/ReplanTriggerService.ets` | 偏差检测，输出触发事件 |
| `domain/timeline/services/ReplanCandidateBuilder.ets` | 生成处置方案列表 |
| `domain/timeline/models/ReplanModels.ets` | 数据结构定义 |

### 5.2 修改文件

| 文件 | 改动 |
|------|------|
| `domain/timeline/services/TimelineAiService.ets` | 新增 `applyReplanCandidate()` 方法 |
| `viewmodel/TimelineViewModel.ets` | 暴露触发状态与方案列表给页面 |
| `pages/Index.ets` | 展示方案卡片与一键执行入口 |

---

## 6. 数据结构

```typescript
// ReplanModels.ets

export type ReplanTriggerType = 'DELAY' | 'QUEUE' | 'WEATHER' | 'CLOSED';

export interface ReplanTrigger {
  type: ReplanTriggerType;
  affectedEventId: number;
  delayMinutes: number;       // 实际偏差分钟数
  detectedAt: number;         // 时间戳
}

export type ReplanActionType = 'PUSH_DOWN' | 'DROP' | 'REORDER';

export interface ReplanCandidate {
  id: string;                 // 唯一标识，用于执行
  actionType: ReplanActionType;
  label: string;              // 展示文案，如"顺延所有后续事件"
  kept: string[];             // 保住的点位名称
  sacrificed: string[];       // 牺牲的点位名称
  previewEvents: TravelPlanItem[];  // 执行后的时间轴快照
}

export interface ReplanSession {
  trigger: ReplanTrigger;
  candidates: ReplanCandidate[];
  createdAt: number;
}
```

---

## 7. 分阶段实施

### Phase A：触发检测（基线）

**目标**：能检测到延误偏差并生成 `ReplanTrigger`。

**实现**：
- `ReplanTriggerService.detect(events, currentTime)` → `ReplanTrigger | null`
- 检测逻辑：当前时间 > 当前事件预计结束时间 + 阈值（默认 15 分钟）
- 阈值可通过 `PreferenceManager` 配置

**交付物**：
- `ReplanTriggerService` 可独立单测
- 单测覆盖：无偏差、轻微偏差（不触发）、超阈值触发

---

### Phase B：方案生成

**目标**：给定触发事件，生成 2-3 个处置方案。

**实现**：`ReplanCandidateBuilder.build(trigger, events)` → `ReplanCandidate[]`

三种方案：

1. **PUSH_DOWN**：将受影响事件及其后续全部顺延 N 分钟
   - 代价：当天结束时间推迟
   - 保住：所有点位

2. **DROP**：删除当前延误事件，后续不变
   - 代价：损失当前点位
   - 保住：后续所有点位按原时间执行

3. **REORDER**：将当前事件移到当天末尾，后续前移
   - 代价：当前点位体验可能打折（时间晚）
   - 保住：后续点位时间不变

**约束**：
- 不修改 `lock_status=1` 的事件
- 不生成空时间轴方案

**交付物**：
- `ReplanCandidateBuilder` 单测通过
- 覆盖：锁定事件不被修改、空事件列表边界

---

### Phase C：一键执行

**目标**：用户选择方案后，直接写入时间轴。

**实现**：
- `TimelineAiService.applyReplanCandidate(candidate, undoToken)` → `Promise<void>`
- 执行前先生成 `undoToken` 快照
- 执行后调用 `recalculateFromIndex(0)` 重算时间
- 失败自动回滚（复用现有 `restoreUndoSnapshotUnsafe`）

**交付物**：
- PUSH_DOWN / DROP / REORDER 三种方案均可执行
- 失败场景无半成功状态

---

### Phase D：ViewModel 与页面集成

**目标**：页面展示方案卡片，用户可选择并一键执行。

**ViewModel 新增**：
```typescript
replanSession: ReplanSession | null       // 当前触发会话
triggerReplanDetection(): void            // 手动触发检测（调试用）
selectReplanCandidate(id: string): Promise<void>  // 执行选中方案
dismissReplan(): void                     // 忽略本次触发
```

**页面**：
- 检测到触发时，底部弹出方案卡片
- 每张卡片展示：动作类型、保住/牺牲说明
- 操作：选择执行 / 忽略

---

### Phase E：测试与门禁

**测试文件**：
- `entry/src/test/ReplanTriggerService.test.ets`
- `entry/src/test/ReplanCandidateBuilder.test.ets`
- `entry/src/test/TimelineAiServiceReplan.test.ets`

**门禁**：
- `./scripts/ci/unit-all.ps1` 全量通过
- 无新增核心回归缺陷

---

## 8. 稳定性约束

- 任何方案执行失败不得破坏原始行程（undoToken 保护）
- 锁定事件（`lock_status=1`）不参与任何方案的修改
- 触发检测为只读操作，不写入任何数据
- 日志前缀：`REPLAN_TRIGGER_TRACE`

---

## 9. 执行顺序

1. Phase A — 触发检测
2. Phase B — 方案生成
3. Phase C — 一键执行
4. Phase D — 页面集成
5. Phase E — 测试门禁

---

## 10. 完成定义（DoD）

- [ ] 三种处置方案（PUSH_DOWN / DROP / REORDER）均可生成并执行
- [ ] 锁定事件不被任何方案修改
- [ ] 执行失败可回滚，无脏数据
- [ ] 单测覆盖触发、生成、执行三层
- [ ] 页面方案卡片可正常展示与操作
- [ ] 日志可追踪完整触发→执行链路
