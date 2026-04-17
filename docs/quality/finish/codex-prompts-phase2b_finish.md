# Codex 并行补测 Prompt 全集 — Phase 2B

## 目标
将 entry 函数覆盖率从 20.8% 提升到 >=75%，分支覆盖率从 44.2% 提升到 >=65%。

## 使用方式
1. 第一轮：同时开 3 个 Codex 窗口，分别粘贴 AN / AO / AP
2. 三个都完成后，回主窗口追加 List.test.ets，跑验收
3. 第二轮：同时开 3 个窗口，粘贴 AQ / AR / AS
4. 第三轮：AT / AU / AV
5. 第四轮：AW / AX / AY
6. 第五轮：AZ / BA / BB

---

## 第一轮

### Batch AN — viewmodel 核心管理器

```
项目路径：E:\Travel
任务：为 viewmodel 核心管理器补充单测

目标文件：
- entry/src/main/ets/viewmodel/managers/TimelinePlanStateManager.ets
- entry/src/main/ets/viewmodel/managers/TimelineEventMutationManager.ets
- entry/src/main/ets/viewmodel/managers/TimelineRecalculationManager.ets
- entry/src/main/ets/viewmodel/managers/TimelineStrategyManager.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAN.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AO — viewmodel coordinators + PlanAppService

```
项目路径：E:\Travel
任务：为 viewmodel coordinators 和 PlanAppService 补充单测

目标文件：
- entry/src/main/ets/viewmodel/coordinators/TimelineWeatherCoordinator.ets
- entry/src/main/ets/viewmodel/coordinators/TimelineDistributionCoordinator.ets
- entry/src/main/ets/viewmodel/coordinators/TimelineCompressionCoordinator.ets
- entry/src/main/ets/viewmodel/PlanAppService.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAO.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AP — infrastructure/auth 深补

```
项目路径：E:\Travel
任务：为 infrastructure/auth 层深补单测

目标文件：
- entry/src/main/ets/infrastructure/auth/AuthSessionStore.ets
- entry/src/main/ets/infrastructure/auth/AppStartupCoordinator.ets
- entry/src/main/ets/infrastructure/auth/HuaweiAccountProvider.ets
- entry/src/main/ets/infrastructure/avatar/AvatarService.ets
- entry/src/main/ets/infrastructure/avatar/AvatarUploadApi.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AuthService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAP.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第一轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AN / AO / AP 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第二轮

### Batch AQ — infrastructure/services 核心

```
项目路径：E:\Travel
任务：为 infrastructure/services 核心补充单测

目标文件：
- entry/src/main/ets/infrastructure/services/ArrivalReminderEngine.ets
- entry/src/main/ets/infrastructure/services/AmapService.ets
- entry/src/main/ets/infrastructure/services/AmapWeatherService.ets
- entry/src/main/ets/infrastructure/services/TrafficEngine.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. mock 所有外部 HTTP/网络调用，不发真实请求
5. 所有测试写入 entry/src/test/Phase2BatchAQ.test.ets
6. 不要修改 List.test.ets
7. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AR — infrastructure/persistence

```
项目路径：E:\Travel
任务：为 infrastructure/persistence 层补充单测

目标文件：
- entry/src/main/ets/infrastructure/persistence/EventRepositoryImpl.ets
- entry/src/main/ets/infrastructure/persistence/UserProfileRepositoryImpl.ets
- entry/src/main/ets/infrastructure/cache/ProfileCacheManager.ets
- entry/src/main/ets/infrastructure/services/WeatherCache.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. mock 数据库/RDB 调用
5. 所有测试写入 entry/src/test/Phase2BatchAR.test.ets
6. 不要修改 List.test.ets
7. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AS — common/utils 深补

```
项目路径：E:\Travel
任务：为 common/utils 工具类深补单测

目标文件：
- entry/src/main/ets/common/utils/PreferenceManager.ets
- entry/src/main/ets/common/utils/DateUtil.ets
- entry/src/main/ets/common/utils/RdbHelper.ets
- entry/src/main/ets/common/utils/ThemeCenter.ets
- entry/src/main/ets/common/utils/AppConfig.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAS.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第二轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AQ / AR / AS 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第三轮

### Batch AT — domain/timeline 深补（分支收口）

```
项目路径：E:\Travel
任务：为 domain/timeline/services 深补分支覆盖

目标文件：
- entry/src/main/ets/domain/timeline/services/TimelineAiService.ets
- entry/src/main/ets/domain/timeline/services/TimelineExecutionService.ets
- entry/src/main/ets/domain/timeline/services/TimelineDistributionService.ets
- entry/src/main/ets/domain/timeline/services/TimelineCompressionService.ets

注意：这些文件已有部分测试（Phase2BatchAH），本次重点补分支缺口（branch coverage 当前 0%）。
读取现有测试文件 entry/src/test/Phase2BatchAH.test.ets 了解已覆盖内容，只补缺失分支。

要求：
1. 逐个读取每个文件，理解未覆盖分支
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 重点覆盖 if/else、switch、异常路径
4. 所有测试写入 entry/src/test/Phase2BatchAT.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AU — domain/statemachine 分支收口

```
项目路径：E:\Travel
任务：为 domain/statemachine 深补分支覆盖

目标文件：
- entry/src/main/ets/domain/statemachine/PlanStateMachine.ets
- entry/src/main/ets/domain/statemachine/StateEventBus.ets
- entry/src/main/ets/domain/statemachine/TransitionEngine.ets
- entry/src/main/ets/domain/statemachine/StateEvaluator.ets

注意：已有 Phase2BatchAE/AF，本次重点补分支缺口（branch coverage 当前 0%）。
读取现有测试了解已覆盖内容，只补缺失分支。

要求：
1. 逐个读取每个文件，理解未覆盖分支
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 重点覆盖 if/else、状态转换边界、异常路径
4. 所有测试写入 entry/src/test/Phase2BatchAU.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AV — model/acl + WeatherService 收口

```
项目路径：E:\Travel
任务：为 model/acl 和 Weather 服务收口单测

目标文件：
- entry/src/main/ets/model/acl/MapServiceImpl.ets
- entry/src/main/ets/domain/services/WeatherFacade.ets
- entry/src/main/ets/domain/services/WeatherRefreshScheduler.ets
- entry/src/main/ets/infrastructure/services/WeatherReminderCoordinator.ets

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAV.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第三轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AT / AU / AV 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第四轮

### Batch AW — pages/index 核心逻辑

```
项目路径：E:\Travel
任务：为 pages/index 核心逻辑层补充单测

目标文件：
- entry/src/main/ets/pages/index/IndexEventHandlers.ets
- entry/src/main/ets/pages/index/IndexConflictHelper.ets
- entry/src/main/ets/pages/index/IndexSettingsFlowHelper.ets
- entry/src/main/ets/pages/index/IndexLifecycleHelper.ets
- entry/src/main/ets/pages/index/IndexStateManager.ets

注意：只测试纯逻辑方法，跳过 @Component/@Builder 等 UI 渲染方法（无法在单测中执行）。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个可测方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAW.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AX — viewmodel 剩余 + ProfileViewModel

```
项目路径：E:\Travel
任务：为 viewmodel 剩余文件补充单测

目标文件：
- entry/src/main/ets/viewmodel/ProfileViewModel.ets
- entry/src/main/ets/viewmodel/managers/TimelineCompanionManager.ets
- entry/src/main/ets/viewmodel/internal/ReminderFacade.ets
- entry/src/main/ets/viewmodel/TimelineInteractionHelper.ets

注意：TimelineInteractionHelper 已有部分测试（Phase2BatchAJ），读取后只补缺失方法。

要求：
1. 逐个读取每个文件，理解公开方法和分支逻辑
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAX.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch AY — pages/components/dialogs 逻辑层

```
项目路径：E:\Travel
任务：为 pages/components/dialogs 补充纯逻辑单测

目标文件：
- entry/src/main/ets/pages/components/dialogs/GapResolutionDialog.ets
- entry/src/main/ets/pages/components/dialogs/AiInputDialog.ets
- entry/src/main/ets/pages/components/dialogs/ConflictSelectionDialog.ets
- entry/src/main/ets/pages/components/dialogs/ConflictCompressDialog.ets
- entry/src/main/ets/pages/components/dialogs/AddItemDialog.ets

注意：只测试纯逻辑方法（数据处理、状态判断），跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个可测方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAY.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第四轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AW / AX / AY 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第五轮

### Batch AZ — pages/components/views 逻辑层

```
项目路径：E:\Travel
任务：为 pages/components/views 补充纯逻辑单测

目标文件：
- entry/src/main/ets/pages/components/views/companion/CompanionWeatherActionHelper.ets
- entry/src/main/ets/pages/components/views/companion/CompanionFocusActionHelper.ets
- entry/src/main/ets/pages/components/views/PlanItemView.ets
- entry/src/main/ets/pages/components/views/BacklogView.ets

注意：只测试纯逻辑方法，跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个可测方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchAZ.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BA — pages 独立页面逻辑

```
项目路径：E:\Travel
任务：为独立页面补充纯逻辑单测

目标文件：
- entry/src/main/ets/pages/LoginPage.ets
- entry/src/main/ets/pages/AuthGatePage.ets
- entry/src/main/ets/pages/TrashPage.ets
- entry/src/main/ets/pages/ArchivePage.ets
- entry/src/main/ets/pages/PlanListPage.ets

注意：只测试纯逻辑方法（数据过滤、状态判断、格式化），跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个可测方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchBA.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BB — pages/index 视图层逻辑

```
项目路径：E:\Travel
任务：为 pages/index 视图层补充纯逻辑单测

目标文件：
- entry/src/main/ets/pages/index/IndexDialogManager.ets
- entry/src/main/ets/pages/index/IndexTimelineActionHelper.ets
- entry/src/main/ets/pages/index/IndexPageShowHelper.ets
- entry/src/main/ets/pages/index/IndexToolbar.ets

注意：只测试纯逻辑方法，跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个可测方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchBB.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第五轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 AZ / BA / BB 三个窗口输出的 import 行]

追加完成后运行最终验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1

验收通过后更新 docs/quality/full-coverage-roadmap.md 进度快照。
```

---

## 预期覆盖率提升

| 轮次 | 批次 | 重点模块 | 预期 Functions 提升 |
|------|------|----------|-------------------|
| 第一轮 | AN/AO/AP | viewmodel managers + auth | +5% |
| 第二轮 | AQ/AR/AS | infrastructure services + utils | +8% |
| 第三轮 | AT/AU/AV | domain 分支收口 | +4% (branch +15%) |
| 第四轮 | AW/AX/AY | pages 逻辑层 | +10% |
| 第五轮 | AZ/BA/BB | pages 视图逻辑 | +8% |
| **合计** | | | **~35% → 达到 >=75%** |
