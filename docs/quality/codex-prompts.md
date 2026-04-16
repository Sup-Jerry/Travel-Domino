# Codex 并行补测 Prompt 全集

## 使用方式
1. 第一轮：同时开 3 个 Codex 窗口，分别粘贴 AE / AG / AI
2. 三个都完成后，回主窗口追加 List.test.ets，跑验收
3. 第二轮：同时开 3 个窗口，粘贴 AF / AH / AK
4. 第三轮：AJ（依赖 AE+AG 完成）
5. 第四轮：AL + AM

---

## 第一轮

### Batch AE — domain/statemachine 核心

```
项目路径：E:\Travel
任务：为 domain/statemachine 核心文件补充单测

目标文件：
- entry/src/main/ets/domain/statemachine/PlanStateMachine.ets
- entry/src/main/ets/domain/statemachine/TransitionEngine.ets
- entry/src/main/ets/domain/statemachine/StateEvaluator.ets
- entry/src/main/ets/domain/statemachine/ReplanCoordinator.ets
- entry/src/main/ets/domain/statemachine/ExecutionContext.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAE.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AG — domain/timeline/services 核心

```
项目路径：E:\Travel
任务：为 domain/timeline/services 核心文件补充单测

目标文件：
- entry/src/main/ets/domain/timeline/services/TimelineCalculationService.ets
- entry/src/main/ets/domain/timeline/services/TimelineConflictResolver.ets
- entry/src/main/ets/domain/timeline/services/TimelineCompressionService.ets
- entry/src/main/ets/domain/timeline/services/TimelineDistributionService.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAG.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

### Batch AI — Weather 服务层

```
项目路径：E:\Travel
任务：为 Weather 服务层补充单测

目标文件：
- entry/src/main/ets/domain/services/WeatherContextBuilder.ets
- entry/src/main/ets/domain/services/WeatherDomainService.ets
- entry/src/main/ets/infrastructure/services/WeatherReminderCoordinator.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAI.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

## 第一轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
import phase2BatchAITest from './Phase2BatchAI.test';
import phase2BatchAGTest from './Phase2BatchAG.test';
import phase2BatchAETest from './Phase2BatchAE.test';


追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第二轮

### Batch AF — domain/statemachine 辅助

```
项目路径：E:\Travel
任务：为 domain/statemachine 辅助文件补充单测

目标文件：
- entry/src/main/ets/domain/statemachine/StateEventBus.ets
- entry/src/main/ets/domain/statemachine/PlanStateMetricsStore.ets
- entry/src/main/ets/domain/statemachine/NotificationBridge.ets
- entry/src/main/ets/domain/statemachine/WeatherRefreshScheduler.ets
- entry/src/main/ets/domain/statemachine/PlanStatus.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAF.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

### Batch AH — domain/timeline/services AI+执行

```
项目路径：E:\Travel
任务：为 domain/timeline/services AI 与执行相关文件补充单测

目标文件：
- entry/src/main/ets/domain/timeline/services/TimelineAiService.ets
- entry/src/main/ets/domain/timeline/services/TimelineExecutionService.ets
- entry/src/main/ets/domain/timeline/services/TimelineGroupingService.ets
- entry/src/main/ets/domain/timeline/services/TimelineWeatherService.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAH.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

### Batch AK — infrastructure/auth 补全

```
项目路径：E:\Travel
任务：为 auth 相关文件补充单测

目标文件：
- entry/src/main/ets/infrastructure/auth/AuthFacade.ets
- entry/src/main/ets/infrastructure/auth/SessionManager.ets
- entry/src/main/ets/domain/auth/AuthStateMachine.ets
- entry/src/main/ets/infrastructure/auth/AuthErrorCode.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AuthService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAK.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

## 第二轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AF / AH / AK 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第三轮（依赖第一轮完成）

### Batch AJ — viewmodel 层

```
项目路径：E:\Travel
任务：为 viewmodel 层补充单测

目标文件：
- entry/src/main/ets/viewmodel/TimelineViewModel.ets
- entry/src/main/ets/viewmodel/TimelineInteractionHelper.ets
- entry/src/main/ets/viewmodel/PlanAppService.ets
- entry/src/main/ets/viewmodel/internal/PlanPersistenceFacade.ets

注意：TimelineViewModel 依赖 domain/statemachine 和 domain/timeline/services，
测试时需要 mock 这些依赖，不要真实调用数据库或网络。

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAJ.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

## 第四轮

### Batch AL — domain/strategy 全补

```
项目路径：E:\Travel
任务：为 domain/strategy 目录下所有未测试文件补充单测

目标目录：entry/src/main/ets/domain/strategy/
（读取目录下所有 .ets 文件，跳过已有对应测试文件的）

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAL.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

### Batch AM — infrastructure 补漏

```
项目路径：E:\Travel
任务：为 infrastructure 层补漏单测

目标文件：
- entry/src/main/ets/infrastructure/services/AiResponseParser.ets
- entry/src/main/ets/infrastructure/services/PlanImportExportService.ets
- entry/src/main/ets/infrastructure/services/ArrivalReminderCoordinator.ets
- entry/src/main/ets/domain/serializers/CompactPlanSerializer.ets
- entry/src/main/ets/domain/serializers/PlanSerializer.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAM.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里

```

---

## 第四轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AJ / AL / AM 三个窗口输出的 import 行]

追加完成后运行最终验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1

验收通过后更新 docs/quality/full-coverage-roadmap.md 进度快照。
```
