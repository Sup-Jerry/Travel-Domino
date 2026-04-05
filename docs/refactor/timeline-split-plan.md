# Timeline 模块拆分计划

## 📊 现状分析

### 当前问题
- **TimelineViewModel.ets**: 2605行，231个方法 - God Object反模式
- **TimelineWeatherService.ets**: 1495行，59个方法 - 职责过多
- 职责混杂：UI状态、业务逻辑、服务协调、数据持久化全部耦合在ViewModel中

### 依赖的服务（已拆分）
✅ 已有独立服务：
- TimelineCompressionService
- TimelineAiService
- TimelineExecutionService
- TimelineDistributionService
- TimelineWeatherService

## 🎯 拆分目标

1. **单一职责**：每个类只负责一个领域
2. **可测试性**：独立服务便于单元测试
3. **可维护性**：降低单文件复杂度到500行以内
4. **向后兼容**：保持现有API不变

---

## 📦 第一阶段：提取类型定义（优先级：高）

### 新文件：`viewmodel/types/TimelineTypes.ets`

**内容**：
```typescript
// 从 TimelineViewModel.ets 迁移所有 interface
export interface PlanDateShiftPreview { ... }
export interface HistoryTimelineItem { ... }
export interface HistoryTimelineSummary { ... }
export interface CompanionActions { ... }
export interface CompanionContext { ... }
export interface SolverCalculatedItem { ... }
export interface ApplyResultFlags { ... }
```

**影响范围**：
- TimelineViewModel 导入这些类型
- 其他引用这些类型的文件更新 import 路径

**预计行数**：~100行

---

## 📦 第二阶段：拆分历史记录管理（优先级：高）

### 新文件：`viewmodel/managers/TimelineHistoryManager.ets`

**职责**：
- 管理计划执行历史记录
- 计算历史统计数据
- 提供历史查询接口

**迁移方法**（约15个）：
```typescript
export class TimelineHistoryManager {
  getCurrentPlanHistorySummary(): HistoryTimelineSummary
  getCurrentPlanHistoryTimelineItems(abnormalThresholdMinutes): HistoryTimelineItem[]
  // ... 其他历史相关方法
}
```

**预计行数**：~300行

---

## 📦 第三阶段：拆分Companion管理（优先级：高）

### 新文件：`viewmodel/managers/TimelineCompanionManager.ets`

**职责**：
- 管理Companion上下文
- 处理Companion动作
- 协调Companion相关UI状态

**迁移方法**（约10个）：
```typescript
export class TimelineCompanionManager {
  getCompanionContext(nowTs: number): CompanionContext
  // ... 其他Companion相关方法
}
```

**预计行数**：~250行

---

## 📦 第四阶段：拆分天气协调器（优先级：中）

### 新文件：`viewmodel/coordinators/TimelineWeatherCoordinator.ets`

**职责**：
- 协调 TimelineWeatherService
- 管理天气用户偏好
- 处理天气建议应用
- 管理天气刷新调度

**迁移方法**（约20个）：
```typescript
export class TimelineWeatherCoordinator {
  async applyPlanningWeatherResult(result, forceRefresh): Promise<void>
  async applyWeatherStrategyAdjustment(adjustment): Promise<void>
  async applyWeatherSuggestion(suggestionId): Promise<SoftReplanApplyResult>
  getWeatherUserPreference(): WeatherUserPreference
  async setWeatherFeatureEnabled(enabled): Promise<void>
  // ... 其他天气协调方法
}
```

**预计行数**：~400行

---

## 📦 第五阶段：拆分压缩协调器（优先级：中）

### 新文件：`viewmodel/coordinators/TimelineCompressionCoordinator.ets`

**职责**：
- 协调 TimelineCompressionService
- 计算压缩计划
- 应用压缩方案

**迁移方法**（约8个）：
```typescript
export class TimelineCompressionCoordinator {
  calculateCompressionPlan(targetIndex, newTimeStr): CompressionPlan
  buildCompressionSelectionContext(targetIndex, targetTime): CompressionSelectionContext | null
  calculateCompressionPlanBySelection(targetIndex, targetTime, selectedIds, mode): CompressionPlan
  applyCompressionPlan(plan): void
  calculateDelayPlan(targetIndex): CompressionPlan
  calculateForceCompressPlan(targetIndex, newTimeStr): CompressionPlan
}
```

**预计行数**：~200行

---

## 📦 第六阶段：拆分分配协调器（优先级：中）

### 新文件：`viewmodel/coordinators/TimelineDistributionCoordinator.ets`

**职责**：
- 协调 TimelineDistributionService
- 处理时间分配逻辑
- 解决间隙问题

**迁移方法**（约5个）：
```typescript
export class TimelineDistributionCoordinator {
  async resolveGapByDistribution(targetItem): Promise<void>
  getDistributionCandidates(gapItem): EventEntity[]
  calculateDistributionPreview(gapItem, candidates, selectedIds, addMinutes): Map<number, number>
  async applyDistribution(distributionMap): Promise<void>
}
```

**预计行数**：~180行

---

## 📦 第七阶段：拆分执行协调器（优先级：中）

### 新文件：`viewmodel/coordinators/TimelineExecutionCoordinator.ets`

**职责**：
- 协调 TimelineExecutionService
- 管理执行状态
- 处理执行建议

**迁移方法**（约12个）：
```typescript
export class TimelineExecutionCoordinator {
  async applyExecutionSuggestionWithStrategy(suggestionId): Promise<void>
  getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN'
  // ... 执行相关方法
}
```

**预计行数**：~280行

---

## 📦 第八阶段：拆分策略管理器（优先级：低）

### 新文件：`viewmodel/managers/TimelineStrategyManager.ets`

**职责**：
- 管理旅行策略模式
- 处理策略切换
- 协调用户行为追踪

**迁移方法**（约8个）：
```typescript
export class TimelineStrategyManager {
  switchStrategyMode(mode: TravelStrategyMode): void
  getCurrentStrategy(): ComposableStrategy
  // ... 策略相关方法
}
```

**预计行数**：~200行

---

## 📦 第九阶段：重构核心ViewModel（优先级：高）

### 重构后：`viewmodel/TimelineViewModel.ets`

**保留职责**：
- 作为Facade协调各个Manager/Coordinator
- 管理核心状态（items, planId, filter等）
- 提供统一的公共API
- 处理生命周期

**核心结构**：
```typescript
export class TimelineViewModel {
  // 核心状态
  @State items: EventEntity[] = []
  @State planId: number = 0

  // 委托给各个管理器
  public readonly historyManager: TimelineHistoryManager
  public readonly companionManager: TimelineCompanionManager
  public readonly weatherCoordinator: TimelineWeatherCoordinator
  public readonly compressionCoordinator: TimelineCompressionCoordinator
  public readonly distributionCoordinator: TimelineDistributionCoordinator
  public readonly executionCoordinator: TimelineExecutionCoordinator
  public readonly strategyManager: TimelineStrategyManager

  // 保留的核心方法（约50个）
  public async loadPlan(planId: number): Promise<void>
  public async saveItems(): Promise<void>
  public addItem(item: EventEntity): void
  public deleteItem(id: number): void
  // ... 基础CRUD和协调方法
}
```

**预计行数**：~600行（从2605行减少到600行）

---

## 🔧 TimelineWeatherService 拆分（优先级：中）

### 当前问题
- **TimelineWeatherService.ets**: 1495行，职责过多

### 拆分方案

#### 新文件：`domain/timeline/services/weather/WeatherDataProvider.ets`
**职责**：天气数据获取和缓存
**预计行数**：~300行

#### 新文件：`domain/timeline/services/weather/WeatherContextBuilder.ets`
**职责**：构建天气上下文（可能已存在，需确认）
**预计行数**：~400行

#### 新文件：`domain/timeline/services/weather/WeatherSuggestionEngine.ets`
**职责**：生成天气建议
**预计行数**：~350行

#### 重构后：`domain/timeline/services/TimelineWeatherService.ets`
**职责**：协调上述三个服务
**预计行数**：~450行（从1495行减少）

---

## 📋 实施步骤

### Phase 1: 准备阶段（1-2天）
1. ✅ 创建 `docs/refactor/timeline-split-plan.md`
2. 创建目录结构：
   ```
   viewmodel/
   ├── types/
   ├── managers/
   └── coordinators/
   ```
3. 编写单元测试框架（如果不存在）

### Phase 2: 类型提取（0.5天）
1. 创建 `TimelineTypes.ets`
2. 迁移所有 interface
3. 更新 import 路径
4. 验证编译通过

### Phase 3: 提取Manager（2-3天）
1. 创建 `TimelineHistoryManager.ets`
   - 迁移历史相关方法
   - 在 TimelineViewModel 中集成
   - 测试历史功能
2. 创建 `TimelineCompanionManager.ets`
   - 迁移Companion相关方法
   - 集成并测试

### Phase 4: 提取Coordinator（3-4天）
1. 创建 `TimelineWeatherCoordinator.ets`
2. 创建 `TimelineCompressionCoordinator.ets`
3. 创建 `TimelineDistributionCoordinator.ets`
4. 创建 `TimelineExecutionCoordinator.ets`
5. 每个Coordinator独立测试

### Phase 5: 提取StrategyManager（1天）
1. 创建 `TimelineStrategyManager.ets`
2. 迁移策略相关逻辑

### Phase 6: 重构核心ViewModel（2天）
1. 清理 TimelineViewModel
2. 保留核心协调逻辑
3. 委托调用各个Manager/Coordinator
4. 全量回归测试

### Phase 7: WeatherService拆分（可选，2-3天）
1. 拆分 TimelineWeatherService
2. 独立测试各子服务

---

## ⚠️ 风险与注意事项

### 高风险点
1. **状态共享**：多个Manager可能需要访问相同状态
   - 解决：通过ViewModel传递或使用事件总线
2. **循环依赖**：Manager之间可能相互调用
   - 解决：明确依赖方向，使用接口解耦
3. **测试覆盖**：现有测试可能不足
   - 解决：边拆分边补充单元测试

### 兼容性保证
1. **保持公共API不变**：TimelineViewModel 的 public 方法签名不变
2. **渐进式迁移**：先委托调用，再逐步迁移
3. **向后兼容导出**：保留类型重导出

### 代码审查检查点
- [ ] 每个新文件职责单一清晰
- [ ] 无循环依赖
- [ ] 公共API保持兼容
- [ ] 单元测试覆盖核心逻辑
- [ ] 文件行数控制在500行以内

---

## 📊 预期收益

### 代码质量提升
- **TimelineViewModel**: 2605行 → 600行（减少77%）
- **TimelineWeatherService**: 1495行 → 450行（减少70%）
- **总文件数**: 2个 → 11个
- **平均文件行数**: 2050行 → 280行

### 可维护性提升
- ✅ 单一职责，易于理解
- ✅ 独立测试，提高覆盖率
- ✅ 减少耦合，降低修改风险
- ✅ 便于并行开发

### 性能影响
- ⚠️ 轻微增加对象创建开销（可忽略）
- ✅ 不影响运行时性能

---

## 🎯 优先级建议

### 立即执行（高优先级）
1. Phase 1-2: 类型提取（低风险，快速见效）
2. Phase 3: 提取 HistoryManager 和 CompanionManager
3. Phase 6: 重构核心 ViewModel

### 后续执行（中优先级）
4. Phase 4: 提取各个 Coordinator
5. Phase 5: 提取 StrategyManager

### 可选执行（低优先级）
6. Phase 7: WeatherService 拆分（如果该服务仍然难以维护）

---

## 📝 总结

本拆分计划将 TimelineViewModel 从一个2605行的巨型类，拆分为：
- 1个核心ViewModel（600行）
- 2个Manager（550行）
- 5个Coordinator（1260行）
- 1个类型文件（100行）

**总计**：从2605行拆分为8个文件共2510行，平均每个文件314行，符合单一职责原则。
