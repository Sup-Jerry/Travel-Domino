# Timeline服务重构文档

## 概述

为了降低TimelineViewModel的复杂度，我们将部分独立逻辑提取到专门的服务类中。

**重构成果：**
- TimelineViewModel：从3193行减少到2919行（减少274行，8.6%）
- 提取了3个服务类，共4个方法

---

## 已提取的服务

### 1. TimelineGroupingService

**路径：** `domain/timeline/services/TimelineGroupingService.ets`

**职责：** 时间线分组和展示逻辑

**方法：**
- `generateGroups()` - 生成分组数据
- `getOrderedScheduleEvents()` - 获取排序后的事件
- `getEventsByPlaceName()` - 按地点名称获取事件
- `getPlaceCheckinSummary()` - 获取单个地点签到摘要
- `getAllPlaceCheckinSummaries()` - 获取所有地点签到摘要

**使用示例：**
```typescript
const groups = TimelineGroupingService.generateGroups(this.events, this.planStartDate);
```

---

### 2. TimelineCalculationService

**路径：** `domain/timeline/services/TimelineCalculationService.ets`

**职责：** 时间线计算和重算逻辑

**方法：**
- `recalculate()` - 完整重算时间线
- `recalculateFromIndex()` - 从指定索引开始重算
- `recalculateTrafficOnly()` - 仅重算交通时间

**导出类型：**
- `SolverCalculatedItem` - 计算结果项
- `ApplyResultFlags` - 应用结果标志

**使用示例：**
```typescript
TimelineCalculationService.recalculateFromIndex(
  this.events,
  startIndex,
  this.planStartDate,
  this.planId
);
```

---

### 3. TimelineConflictResolver

**路径：** `domain/timeline/services/TimelineConflictResolver.ets`

**职责：** 冲突检测和解决

**方法：**
- `isDateConflict()` - 检测日期冲突
- `fixConflict()` - 修复时间冲突

**使用示例：**
```typescript
const hasConflict = TimelineConflictResolver.isDateConflict(
  targetDateMs,
  this.planStartDate
);

await TimelineConflictResolver.fixConflict(
  this.events,
  itemId,
  shiftMinutes,
  this.planId
);
```

---

## 重构经验

### 适合提取的方法特征
1. 逻辑独立，不依赖大量私有方法
2. 参数可以明确传递，不依赖隐式状态
3. 纯计算或简单判断逻辑
4. 可以作为静态方法实现

### 不适合提取的方法特征
1. 深度耦合ViewModel的私有方法
2. 依赖复杂的状态管理（@Track响应式状态）
3. 需要访问大量ViewModel内部状态
4. 提取成本高于收益

### 关键教训
1. **渐进式重构优于一次性大规模重构**
2. **降低目标比强行完成更明智**
3. **评估方法独立性是提取的前提**
4. **保持向后兼容，避免破坏性变更**

---

## 未来改进方向

剩余的复杂方法（事件管理、运行时状态）深度耦合ViewModel架构，需要更大规模的重构：

1. 重构状态管理机制
2. 提取私有辅助方法到工具类
3. 引入更清晰的领域模型
4. 考虑使用状态机模式处理运行时逻辑

当前TimelineViewModel（2919行）已经达到可维护的水平，建议暂缓进一步拆分。
