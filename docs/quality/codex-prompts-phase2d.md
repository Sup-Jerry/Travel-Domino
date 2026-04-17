# Codex 并行补测 Prompt 全集 — Phase 2D

## 目标
将 entry 函数覆盖率从 25.4% 提升到 >=50%，分支覆盖率从 56.6% 提升到 >=70%。

## 使用方式
1. 第一轮：同时开 3 个 Codex 窗口，分别粘贴 BO / BP / BQ
2. 三个都完成后，回主窗口追加 List.test.ets，跑验收
3. 第二轮：BR / BS / BT
4. 第三轮：BU / BV / BW
5. 第四轮：BX / BY / BZ

---

## 第一轮

### Batch BO — viewmodel 核心深补（最高优先级）

```
项目路径：E:\Travel
任务：为 viewmodel 低覆盖文件深补单测

目标文件（当前覆盖率）：
- entry/src/main/ets/viewmodel/TimelineViewModel.ets（19%，142个函数）
- entry/src/main/ets/viewmodel/managers/TimelinePlanStateManager.ets（47.5%，40个函数）
- entry/src/main/ets/viewmodel/managers/TimelineEventMutationManager.ets（73%，37个函数）
- entry/src/main/ets/viewmodel/managers/TimelineCompanionManager.ets（50%，6个函数）

注意：这些文件已有 Phase2BatchBC/AN 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖方法和分支
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 每个未覆盖方法覆盖 normal / boundary / invalid 三类 case
4. 重点覆盖 TimelineViewModel 中覆盖率最低的方法群
5. 所有测试写入 entry/src/test/Phase2BatchBO.test.ets
6. 不要修改 List.test.ets
7. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BP — domain/timeline services 深补

```
项目路径：E:\Travel
任务：为 domain/timeline/services 深补覆盖

目标文件（当前覆盖率）：
- entry/src/main/ets/domain/timeline/services/TimelineExecutionService.ets（44.2%，43个函数）
- entry/src/main/ets/domain/timeline/services/TimelineDistributionService.ets（61%，41个函数）
- entry/src/main/ets/domain/timeline/services/TimelineAiService.ets（61.4%，83个函数）
- entry/src/main/ets/domain/timeline/services/TimelineCompressionService.ets（67.9%，56个函数）
- entry/src/main/ets/domain/timeline/services/TimelineWeatherService.ets（74.1%，139个函数）

注意：这些文件已有 Phase2BatchBD/AH/AT 测试，读取后只补缺失方法和分支。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖部分
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 重点覆盖 if/else、异常路径、边界值
4. 所有测试写入 entry/src/test/Phase2BatchBP.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BQ — infrastructure 深补

```
项目路径：E:\Travel
任务：为 infrastructure 低覆盖文件深补单测

目标文件（当前覆盖率）：
- entry/src/main/ets/infrastructure/services/PlanImportExportService.ets（28.6%，21个函数）
- entry/src/main/ets/infrastructure/services/ArrivalReminderEngine.ets（34.5%，58个函数）
- entry/src/main/ets/infrastructure/avatar/AvatarUploadApi.ets（37.5%，16个函数）
- entry/src/main/ets/infrastructure/services/ArrivalReminderCoordinator.ets（48%，25个函数）
- entry/src/main/ets/infrastructure/services/AmapService.ets（50%，46个函数）
- entry/src/main/ets/infrastructure/auth/SessionManager.ets（54.5%，22个函数）

注意：这些文件已有 Phase2BatchBE/AQ 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. mock 所有外部 HTTP/网络/系统调用
4. 每个未覆盖方法覆盖 normal / boundary / invalid 三类 case
5. 所有测试写入 entry/src/test/Phase2BatchBQ.test.ets
6. 不要修改 List.test.ets
7. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第一轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BO / BP / BQ 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第二轮

### Batch BR — infrastructure 收口 + domain 收口

```
项目路径：E:\Travel
任务：为 infrastructure 剩余文件和 domain 收口补充单测

目标文件（当前覆盖率）：
- entry/src/main/ets/infrastructure/avatar/AvatarService.ets（54.5%，22个函数）
- entry/src/main/ets/infrastructure/auth/AppStartupCoordinator.ets（57.1%，7个函数）
- entry/src/main/ets/infrastructure/services/AmapWeatherService.ets（68.2%，22个函数）
- entry/src/main/ets/infrastructure/services/WeatherReminderCoordinator.ets（66.7%，15个函数）
- entry/src/main/ets/infrastructure/persistence/UserProfileRepositoryImpl.ets（68.4%，19个函数）
- entry/src/main/ets/domain/statemachine/StateEventBus.ets（73.3%，15个函数）

注意：部分文件已有 Phase2BatchBF/AP/AU 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. mock 所有外部调用
4. 所有测试写入 entry/src/test/Phase2BatchBR.test.ets
5. 不要修改 List.test.ets
6. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BS — pages/index 逻辑层深补

```
项目路径：E:\Travel
任务：为 pages/index 逻辑层深补单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/index/IndexConflictHelper.ets（34.7%，75个函数）
- entry/src/main/ets/pages/index/IndexSettingsFlowHelper.ets（42.4%，33个函数）
- entry/src/main/ets/pages/index/IndexEventHandlers.ets（51.4%，35个函数）
- entry/src/main/ets/pages/index/IndexDialogManager.ets（16.7%，84个函数）
- entry/src/main/ets/pages/index/IndexLifecycleHelper.ets（17.4%，23个函数）
- entry/src/main/ets/pages/index/IndexPageShowHelper.ets（30%，10个函数）

注意：这些文件已有 Phase2BatchBH/BB/AW 测试，读取后只补缺失方法。只测试纯逻辑方法，跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件及其现有测试，理解未覆盖纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBS.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BT — pages/components/dialogs 深补

```
项目路径：E:\Travel
任务：为 pages/components/dialogs 深补纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/dialogs/GapResolutionDialog.ets（2.3%，128个函数）
- entry/src/main/ets/pages/components/dialogs/AiInputDialog.ets（3.3%，120个函数）
- entry/src/main/ets/pages/components/dialogs/AddItemDialog.ets（4.2%，120个函数）
- entry/src/main/ets/pages/components/dialogs/ConflictCompressDialog.ets（7%，86个函数）
- entry/src/main/ets/pages/components/dialogs/PlanSettingsDialog.ets（4.1%，73个函数）
- entry/src/main/ets/pages/components/dialogs/ConflictSelectionDialog.ets（5%，40个函数）

注意：只测试纯逻辑方法，跳过 UI 渲染方法。已有 Phase2BatchBJ/AY 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBT.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第二轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BR / BS / BT 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第三轮

### Batch BU — pages/components/views 深补

```
项目路径：E:\Travel
任务：为 pages/components/views 深补纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/views/EventItemView.ets（1.3%，236个函数）
- entry/src/main/ets/pages/components/views/CompanionView.ets（0.7%，272个函数）
- entry/src/main/ets/pages/components/views/PlanItemView.ets（7.1%，42个函数）
- entry/src/main/ets/pages/components/views/BacklogView.ets（7.8%，51个函数）
- entry/src/main/ets/pages/components/views/SettingsItems.ets（3.3%，92个函数）
- entry/src/main/ets/pages/components/views/BottomNavBar.ets（4.2%，119个函数）

注意：只测试纯逻辑方法，跳过 @Component/@Builder UI 渲染方法。已有 Phase2BatchBK/AZ 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法（数据处理、状态判断、格式化）
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBU.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BV — pages/components/views/companion 深补

```
项目路径：E:\Travel
任务：为 companion 视图组件深补纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/views/companion/CompanionControlPage.ets（2.2%，224个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionFocusedCardHost.ets（2.4%，125个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionHistoryPage.ets（2.8%，144个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionExecutionWeatherCard.ets（6.6%，151个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionTimelineSection.ets（4.9%，81个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionOverlayPages.ets（3.8%，80个函数）

注意：只测试纯逻辑方法，跳过 UI 渲染方法。已有 Phase2BatchBM 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBV.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BW — pages 独立页面深补

```
项目路径：E:\Travel
任务：为 pages 独立页面补充纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/PlanListPage.ets（4.1%，122个函数）
- entry/src/main/ets/pages/PlanSearchPage.ets（7.6%，79个函数）
- entry/src/main/ets/pages/MapPickerPage.ets（2.9%，138个函数）
- entry/src/main/ets/pages/MyPage.ets（4%，100个函数）
- entry/src/main/ets/pages/SettingsGeneralPage.ets（4%，101个函数）
- entry/src/main/ets/pages/SettingsPreferenceInsightsPage.ets（5.5%，128个函数）

注意：只测试纯逻辑方法（数据过滤、状态判断、格式化），跳过 UI 渲染方法。已有 Phase2BatchBN 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBW.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第三轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BU / BV / BW 三个窗口输出的 import 行]

追加完成后运行验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1
```

---

## 第四轮

### Batch BX — pages/index 大型 UI 文件逻辑提取（二轮）

```
项目路径：E:\Travel
任务：为 pages/index 大型文件继续提取纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/index/IndexTopArea.ets（1.1%，90个函数）
- entry/src/main/ets/pages/index/IndexPageLayout.ets（1.4%，144个函数）
- entry/src/main/ets/pages/index/IndexScheduleArea.ets（3.8%，106个函数）
- entry/src/main/ets/pages/index/IndexTimelineView.ets（5%，120个函数）
- entry/src/main/ets/pages/index/IndexWeatherHintBar.ets（5.9%，68个函数）
- entry/src/main/ets/pages/index/IndexToolbar.ets（6.9%，58个函数）

注意：这些是大型 UI 文件，只测试纯逻辑方法，跳过所有 @Component/@Builder 方法。已有 Phase2BatchBL 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBX.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BY — pages 新增低覆盖文件

```
项目路径：E:\Travel
任务：为 pages 新发现低覆盖文件补充纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/views/AppSideBar.ets（8.3%，24个函数）
- entry/src/main/ets/pages/index/IndexUnsavedActionBar.ets（3.6%，28个函数）
- entry/src/main/ets/pages/index/IndexBacklogSection.ets（3.8%，26个函数）
- entry/src/main/ets/pages/index/IndexBacklogView.ets（3.8%，26个函数）
- entry/src/main/ets/pages/components/dialogs/AdvanceAdjustDialog.ets（4.8%，62个函数）
- entry/src/main/ets/pages/components/dialogs/DateFilterDialog.ets（4.8%，42个函数）
- entry/src/main/ets/pages/components/dialogs/AiReplanPreviewDialog.ets（4.9%，41个函数）
- entry/src/main/ets/pages/components/dialogs/SuggestionDialog.ets（5.3%，38个函数）

注意：只测试纯逻辑方法，跳过 UI 渲染方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBY.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

### Batch BZ — companion 剩余 + 小型 pages 收口

```
项目路径：E:\Travel
任务：为 companion 剩余文件和小型 pages 收口补充纯逻辑单测

目标文件（当前覆盖率）：
- entry/src/main/ets/pages/components/views/companion/CompanionSearchPage.ets（4.8%，62个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionImmersiveView.ets（5.2%，77个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionFilterPage.ets（8.2%，49个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionWeatherPopups.ets（10.7%，28个函数）
- entry/src/main/ets/pages/components/views/companion/CompanionFocusActionHelper.ets（17.6%，17个函数）
- entry/src/main/ets/pages/TrashPage.ets（4.8%，42个函数）
- entry/src/main/ets/pages/ArchivePage.ets（8.2%，49个函数）
- entry/src/main/ets/pages/LoginPage.ets（10.5%，38个函数）

注意：只测试纯逻辑方法，跳过 UI 渲染方法。已有 Phase2BatchBI/BN 测试，读取后只补缺失方法。

要求：
1. 逐个读取每个文件，识别可测试的纯逻辑方法
2. 参考 entry/src/test/AiService.test.ets 的测试风格
3. 所有测试写入 entry/src/test/Phase2BatchBZ.test.ets
4. 不要修改 List.test.ets
5. 完成后输出需要追加到 List.test.ets 的 import 行，直接告诉我，而不是你直接添加到文件里
```

---

## 第四轮完成后 — 主窗口操作

```
把以下 import 行追加到 entry/src/test/List.test.ets：
[粘贴 BX / BY / BZ 三个窗口输出的 import 行]

追加完成后运行最终验收：
powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1

验收通过后更新 docs/quality/full-coverage-roadmap.md 进度快照。
```

---

## 预期覆盖率提升

| 轮次 | 批次 | 重点模块 | 预期 Functions 提升 |
|------|------|----------|-------------------|
| 第一轮 | BO/BP/BQ | viewmodel核心 + domain/timeline + infrastructure | +8% |
| 第二轮 | BR/BS/BT | infrastructure收口 + pages/index逻辑 + dialogs | +7% |
| 第三轮 | BU/BV/BW | views深补 + companion + pages独立页面 | +6% |
| 第四轮 | BX/BY/BZ | pages/index大型UI + 新增低覆盖 + companion收口 | +4% |
| **合计** | | | **~25% → 达到 >=50%** |
