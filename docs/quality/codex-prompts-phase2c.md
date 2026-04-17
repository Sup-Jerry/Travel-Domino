# Codex 并行补测 Prompt 全集 — Phase 2C

## 目标
将 entry 函数覆盖率从 25% 提升到 >=75%，分支覆盖率从 55.7% 提升到 >=65%。

## 使用方式
1. 第一轮：同时开 3 个 Codex 窗口，分别粘贴 BC / BD / BE
2. 三个都完成后，回主窗口追加 List.test.ets，跑验收
3. 第二轮：BF / BG / BH
4. 第三轮：BI / BJ / BK
5. 第四轮：BL / BM / BN

---

## 第一轮

### Batch BC — viewmodel 深补（低覆盖核心）

```
项目路径：E:\Travel
任务：为 viewmodel 低覆盖文件深补单测

目标文件（当前覆盖率）：
- entry/src/main/ets/viewmodel/TimelineViewModel.ets（14.1%，142个函数）
- entry/src/main/ets/viewmodel/managers/TimelinePlanStateManager.ets（47.5%，40个函数）
- entry/src/main/ets/viewmodel/managers/TimelineEventMutationManager.ets（73%，37个函数）
- entry/src/main/ets/viewmodel/managers/TimelineCompanionManager.ets（50%，6个函数）

注意：TimelinePlanStateManager/TimelineEventMutationManager 已有 Phase2BatchAN 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，理解未覆盖方法和分支
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个未覆盖方法覆盖 normal / boundary / invalid 三类 case
4. 所有测试写入 entry/src/test/Phase2BatchBC.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BD — domain/timeline 深补（分支收口）

```
项目路径：E:\Travel
任务：为 domain/timeline/services 深补覆盖

目标文件（当前覆盖率）：
- entry/src/main/ets/domain/timeline/services/TimelineExecutionService.ets（44.2%，43个函数）
- entry/src/main/ets/domain/timeline/services/TimelineDistributionService.ets（61%，41个函数）
- entry/src/main/ets/domain/timeline/services/TimelineAiService.ets（61.4%，83个函数）
- entry/src/main/ets/domain/timeline/services/TimelineCompressionService.ets（67.9%，56个函数）
- entry/src/main/ets/domain/timeline/services/TimelineWeatherService.ets（74.1%，139个函数）

注意：这些文件已有 Phase2BatchAH/AT 测试，读取后只补缺失方法和分支。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖部分
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 重点覆盖 if/else、异常路径、边界值
4. 所有测试写入 entry/src/test/Phase2BatchBD.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BE — infrastructure 深补

```
项目路径：E:\Travel
任务：为 infrastructure 低覆盖文件深补单测

目标文件（当前覆盖率）：
- entry/src/main/ets/infrastructure/services/PlanImportExportService.ets（28.6%，21个函数）
- entry/src/main/ets/infrastructure/services/ArrivalReminderEngine.ets（34.5%，58个函数）
- entry/src/main/ets/infrastructure/avatar/AvatarUploadApi.ets（37.5%，16个函数）
- entry/src/main/ets/infrastructure/services/ArrivalReminderCoordinator.ets（48%，25个函数）
- entry/src/main/ets/infrastructure/services/AmapService.ets（50%，46个函数）
- entry/src/main/ets/infrastructure/auth/SessionManager.ets（50%，22个函数）

注意：ArrivalReminderEngine/AmapService 已有 Phase2BatchAQ 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，理解未覆盖方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. mock 所有外部 HTTP/网络/系统调用
4. 每个未覆盖方法覆盖 normal / boundary / invalid 三类 case
5. 所有测试写入 entry/src/test/Phase2BatchBE.test.ets
6. 不要修改 List.test.ets
7. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第一轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BC / BD / BE 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第二轮

### Batch BF — infrastructure 剩余 + domain 收口

```
项目路径：E:\Travel
任务：为 infrastructure 剩余文件和 domain 收口补充单测

目标文件（当前覆盖率）：
- entry/src/main/ets/infrastructure/avatar/AvatarService.ets（54.5%，22个函数）
- entry/src/main/ets/infrastructure/auth/AppStartupCoordinator.ets（57.1%，7个函数）
- entry/src/main/ets/infrastructure/services/AmapWeatherService.ets（59.1%，22个函数）
- entry/src/main/ets/infrastructure/services/WeatherReminderCoordinator.ets（66.7%，15个函数）
- entry/src/main/ets/infrastructure/persistence/UserProfileRepositoryImpl.ets（68.4%，19个函数）
- entry/src/main/ets/domain/statemachine/StateEventBus.ets（73.3%，15个函数）
- entry/src/main/ets/domain/services/QRCodeService.ets（50%，2个函数）

注意：部分文件已有 Phase2BatchAP/AQ/AU 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，理解未覆盖方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. mock 所有外部调用
4. 所有测试写入 entry/src/test/Phase2BatchBF.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BG — viewmodel 剩余收口

```
项目路径：E:\Travel
任务：为 viewmodel 剩余文件收口单测

目标文件（当前覆盖率）：
- entry/src/main/ets/viewmodel/PlanAppService.ets（57.1%，42个函数）
- entry/src/main/ets/viewmodel/internal/ReminderFacade.ets（66.7%，3个函数）
- entry/src/main/ets/viewmodel/ProfileViewModel.ets（70.6%，17个函数）
- entry/src/main/ets/viewmodel/TimelineInteractionHelper.ets（72.2%，18个函数）

注意：PlanAppService/TimelineInteractionHelper 已有 Phase2BatchAO/AX 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBG.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BH — pages/index 逻辑层深补

```
项目路径：E:\Travel
任务：为 pages/index 逻辑层深补单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/index/IndexConflictHelper.ets（30.7%，75个函数）
- entry/src/main/ets/pages/index/IndexSettingsFlowHelper.ets（42.4%，33个函数）
- entry/src/main/ets/pages/index/IndexEventHandlers.ets（51.4%，35个函数）
- entry/src/main/ets/pages/index/IndexDialogManager.ets（13.1%，84个函数）
- entry/src/main/ets/pages/index/IndexLifecycleHelper.ets（17.4%，23个函数）

注意：这些文件已有 Phase2BatchAW/BB 测试，读取后只补缺失方法。只测试纯逻辑方法，跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBH.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第二轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BF / BG / BH 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第三轮

### Batch BI — pages/index 剩余 + pages 独立页面

```
项目路径：E:\Travel
任务：为 pages/index 剩余和独立页面补充纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/index/IndexPageShowHelper.ets（30%，10个函数）
- entry/src/main/ets/pages/index/IndexTimelineActionHelper.ets（44.4%，9个函数）
- entry/src/main/ets/pages/index/IndexToolbar.ets（6.9%，58个函数）
- entry/src/main/ets/pages/LoginPage.ets（10.5%，38个函数）
- entry/src/main/ets/pages/AuthGatePage.ets（21.4%，14个函数）
- entry/src/main/ets/pages/TrashPage.ets（4.76%，42个函数）
- entry/src/main/ets/pages/ArchivePage.ets（8.16%，49个函数）

注意：只测试纯逻辑方法（数据过滤、状态判断、格式化），跳过 UI 渲染方法。
已有 Phase2BatchAW/BA/BB 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBI.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BJ — pages/components/dialogs 深补

```
项目路径：E:\Travel
任务：为 pages/components/dialogs 深补纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/dialogs/GapResolutionDialog.ets（2.34%，128个函数）
- entry/src/main/ets/pages/components/dialogs/AiInputDialog.ets（3.33%，120个函数）
- entry/src/main/ets/pages/components/dialogs/AddItemDialog.ets（4.17%，120个函数）
- entry/src/main/ets/pages/components/dialogs/ConflictCompressDialog.ets（6.98%，86个函数）
- entry/src/main/ets/pages/components/dialogs/PlanSettingsDialog.ets（4.11%，73个函数）
- entry/src/main/ets/pages/components/dialogs/ConflictSelectionDialog.ets（5%，40个函数）

注意：只测试纯逻辑方法，跳过 UI 渲染方法。已有 Phase2BatchAY 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBJ.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BK — pages/components/views 深补

```
项目路径：E:\Travel
任务：为 pages/components/views 深补纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/views/EventItemView.ets（1.27%，236个函数）
- entry/src/main/ets/pages/components/views/CompanionView.ets（0.735%，272个函数）
- entry/src/main/ets/pages/components/views/PlanItemView.ets（7.14%，42个函数）
- entry/src/main/ets/pages/components/views/BacklogView.ets（7.84%，51个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionFocusActionHelper.ets（17.6%，17个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionWeatherActionHelper.ets（70%，10个函数）

注意：只测试纯逻辑方法，跳过 @Component/@Builder UI 渲染方法。已有 Phase2BatchAZ 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法（数据处理、状态判断、格式化）
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBK.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第三轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BI / BJ / BK 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第四轮

### Batch BL — pages/index 大型 UI 文件逻辑提取

```
项目路径：E:\Travel
任务：为 pages/index 大型文件提取纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/index/IndexTopArea.ets（1.11%，90个函数）
- entry/src/main/ets/pages/index/IndexPageLayout.ets（1.39%，144个函数）
- entry/src/main/ets/pages/index/IndexScheduleArea.ets（3.77%，106个函数）
- entry/src/main/ets/pages/index/IndexTimelineView.ets（5%，120个函数）
- entry/src/main/ets/pages/index/IndexWeatherHintBar.ets（5.88%，68个函数）

注意：这些是大型 UI 文件，只测试纯逻辑方法（数据处理、条件判断、格式化），跳过所有 @Component/@Builder 方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBL.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BM — pages/components/views/companion 深补

```
项目路径：E:\Travel
任务：为 companion 视图组件深补纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/views/companion/CompanionControlPage.ets（2.23%，224个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionFocusedCardHost.ets（2.4%，125个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionHistoryPage.ets（2.78%，144个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionExecutionWeatherCard.ets（6.62%，151个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionTimelineSection.ets（4.94%，81个函数）

注意：只测试纯逻辑方法，跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBM.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BN — pages 剩余文件收口

```
项目路径：E:\Travel
任务：为 pages 剩余文件补充纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/PlanListPage.ets（4.1%，122个函数）
- entry/src/main/ets/pages/PlanSearchPage.ets（7.59%，79个函数）
- entry/src/main/ets/pages/MapPickerPage.ets（2.9%，138个函数）
- entry/src/main/ets/pages/MyPage.ets（4%，100个函数）
- entry/src/main/ets/pages/SettingsGeneralPage.ets（3.96%，101个函数）
- entry/src/main/ets/pages/SettingsPreferenceInsightsPage.ets（5.47%，128个函数）

注意：只测试纯逻辑方法（数据过滤、状态判断、格式化），跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBN.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第四轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BL / BM / BN 三个窗口输出的 import 行]

追加完成后运行最终验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1

验收通过后更新 docs/quality/full-coverage-roadmap.md 进度快照。
```

---

## 预期覆盖率提升

| 轮次 | 批次 | 重点模块 | 预期 Functions 提升 |
|------|------|----------|-------------------|
| 第一轮 | BC/BD/BE | viewmodel + domain/timeline + infrastructure | +15% |
| 第二轮 | BF/BG/BH | infrastructure收口 + viewmodel收口 + pages/index逻辑 | +10% |
| 第三轮 | BI/BJ/BK | pages独立页面 + dialogs + views | +15% |
| 第四轮 | BL/BM/BN | pages大型UI逻辑提取 | +10% |
| **合计** | | | **~50% → 达到 >=75%** |
