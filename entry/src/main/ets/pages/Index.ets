import { TimelineViewModel } from '../viewmodel/TimelineViewModel';
// 修改点：View 组件指向 views 目录
// 修改点：Dialog 组件指向 dialogs 目录
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { EventEntity } from '../model/entity/EventEntity';
// 修改点：批量更新 Dialog 路径
import { promptAction } from '@kit.ArkUI';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { NavigationHelper } from '../common/utils/NavigationHelper';
import { WeatherReminderCoordinator } from '../infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload } from '../common/utils/weather/WeatherReminderStore';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { DomainConstants } from '../common/constants/DomainConstants';
import { PlanRepositoryImpl } from '../infrastructure/persistence/PlanRepositoryImpl';
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { IndexPageLayout } from './index/IndexPageLayout';
import { IndexEventHandlers } from './index/IndexEventHandlers';
import { InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexLifecycleHelper } from './index/IndexLifecycleHelper';
import { IndexDialogManager } from './index/IndexDialogManager';
import { IndexAddDialogHelper } from './index/IndexAddDialogHelper';
import { IndexAddDialogFlowHelper } from './index/IndexAddDialogFlowHelper';
import { IndexDateConflictDialogFlowHelper } from './index/IndexDateConflictDialogFlowHelper';
import { ConflictFlowContext, IndexConflictFlowHelper } from './index/IndexConflictFlowHelper';
import { IndexPageBehaviorHelper, ReminderDialogContext, StrategyDialogContext } from './index/IndexPageBehaviorHelper';
import { IndexPageActionsHelper, MoveToScheduleItem } from './index/IndexPageActionsHelper';
import { IndexPageShowHelper } from './index/IndexPageShowHelper';
@Entry
@Component
struct Index {
  @State vm: TimelineViewModel = new TimelineViewModel();
  @State planTitle: string = '行程详情';
  @State editingItemId: number = -1;
  @State currentPlanId: number = -1;
  @State backlogExpanded: boolean = false;
  @State collapsedDayOffsets: number[] = [];
  @State pendingItem: PendingItemData | null = null;
  @State gapItem: EventEntity | null = null; // 用于传给弹窗
  @State isCompanionMode: boolean = false;
  @State companionBackRequestToken: number = 0;
  @State hasUnsavedChanges: boolean = false;
  @State strategyMode: number = 0;
  @State currentStrategyExplanation: string = '';
  @State showPlanningWeatherHintPopup: boolean = false;
  @State showPlanningWeatherScorePopup: boolean = false;
  @State hasManualPlanningWeatherRefresh: boolean = false;
  @State isPageRefreshing: boolean = false;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  @StorageLink('TrafficDataUpdated') @Watch('onTrafficSignal') trafficSignal: number = 0;
  private weatherReminderUnsubscribe: (() => void) | null = null;
  private arrivalReminderUnsubscribe: (() => void) | null = null;
  @State isWeatherDialogOpen: boolean = false;
  @State isArrivalDialogOpen: boolean = false;
  @State dayGroupRenderVersion: number = 0;
  private readonly planService: PlanAppService = PlanAppService.getInstance();
  private readonly weatherCoordinator: WeatherReminderCoordinator = WeatherReminderCoordinator.getInstance();
  private readonly arrivalCoordinator: ArrivalReminderCoordinator = ArrivalReminderCoordinator.getInstance();
  private strategyAdaptationCheckTimer: number = -1;
  dialogController: CustomDialogController | null = null;
  settingsDialogController: CustomDialogController | null = null;
  dateFilterController: CustomDialogController | null = null;
  conflictSelectionController: CustomDialogController | null = null;
  conflictCompressController: CustomDialogController | null = null;
  conflictAdvanceController: CustomDialogController | null = null;
  timeDialogController: CustomDialogController | null = null;
  suggestionDialogController: CustomDialogController | null = null;
  onTrafficSignal() {
    hilog.info(0x0000, 'Index', '收到高德数据更新信号，触发 UI 重算');
    // 路况异步回填到达后，强制重拉通勤并全量重排，确保跨天分组及时生效。
    this.vm.testAllCommute();
    this.collapsedDayOffsets = [];
    this.dayGroupRenderVersion += 1;
    if (this.vm.filterStart > 0 || this.vm.filterEnd > 0) {
      this.vm.clearFilter();
    }
  }
  private scopedStorageKey(base: string): string {
    return IndexStateManager.scopedStorageKey(base, this.currentPlanId);
  }
  private clearDialogDraftStorage(): void {
    IndexStateManager.clearDialogDraftStorage(
      this.currentPlanId,
      AppStorageKeys.TEMP_DIALOG_STATE,
      AppStorageKeys.PICKED_LOCATION_STR
    );
  }
  private readDraftStorageWithFallback(key: string): string {
    return IndexStateManager.readDraftStorageWithFallback(this.currentPlanId, key);
  }
  private sanitizeError(error: Object): string {
    if (error instanceof Error && typeof error.message === 'string' && error.message.length > 0) {
      return error.message;
    }
    return 'unknown_error';
  }
  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      hilog.warn(0x0000, 'Index', `[TOAST_FAIL] ${this.sanitizeError(error as Object)}`);
    }
  }
  private async resolveConflictPlanName(planId: number): Promise<string> {
    if (planId === this.currentPlanId) {
      const localTitle = (this.planTitle || '').trim();
      return localTitle.length > 0 ? localTitle : `计划 #${planId}`;
    }
    try {
      const plan = await PlanRepositoryImpl.getPlanById(planId);
      const title = (plan?.title || '').trim();
      return title.length > 0 ? title : `计划 #${planId}`;
    } catch (_error) {
      return `计划 #${planId}`;
    }
  }
  private async showActiveConflictDialog(conflictPlanId: number, conflictName: string): Promise<void> {
    const planName = await this.resolveConflictPlanName(conflictPlanId);
    const safeName = (conflictName || '').trim().length > 0 ? conflictName : '其他地点';
    this.getUIContext().showAlertDialog({
      title: '无法开始打卡',
      message: `当前已有进行中的计划【${planName}】地点【${safeName}】。\n请先结束该地点后再开始新的打卡。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '我知道了',
        action: () => {}
      }
    });
  }
  private async tryStartEventWithConflictPrompt(eventId: number): Promise<boolean> {
    const conflict = await this.vm.getStartConflictInfo(eventId);
    if (conflict) {
      await this.showActiveConflictDialog(conflict.planId, conflict.name);
      return false;
    }
    const started = await this.vm.updateActualTime(eventId, 'actual_start_time', Date.now());
    if (!started) {
      const retryConflict = await this.vm.getStartConflictInfo(eventId);
      if (retryConflict) {
        await this.showActiveConflictDialog(retryConflict.planId, retryConflict.name);
      } else {
        this.safeShowToast('开始打卡失败，请稍后重试');
      }
      return false;
    }
    return true;
  }
  private refreshUnsavedFlag(): void {
    this.hasUnsavedChanges = IndexStateManager.readUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE);
  }
  private setUnsavedFlag(value: boolean): void {
    this.hasUnsavedChanges = IndexStateManager.setUnsavedFlag(
      this.currentPlanId,
      AppStorageKeys.HAS_UNSAVED_POSTPONE,
      value
    );
  }
  private hasScopedUnsavedChanges(): boolean {
    return IndexStateManager.readUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE);
  }
  private startArrivalReminderEngine(): void {
    if (this.currentPlanId <= 0) {
      return;
    }
    try {
      const hostContext = this.getUIContext().getHostContext() as Context;
      this.planService.startArrivalEngine(this.currentPlanId, this.vm, hostContext);
    } catch (error) {
      hilog.warn(0x0000, 'Index', `[ARRIVAL][engine_start_failed] reason=${this.sanitizeError(error)}`);
    }
  }
  onBackPress(): boolean {
    if (this.isCompanionMode) {
      this.companionBackRequestToken += 1;
      return true;
    }
    return false;
  }
  private bindReminderSubscriptions(): void {
    this.unbindReminderSubscriptions();
    if (this.currentPlanId <= 0) {
      return;
    }
    this.weatherReminderUnsubscribe = this.weatherCoordinator.subscribePlan(this.currentPlanId, {
      isDialogOpen: (): boolean => this.isWeatherDialogOpen,
      onShow: (payload: WeatherReminderPayload): void => {
        if (!this.vm.isWeatherFeatureEnabled()) {
          return;
        }
        this.showWeatherReminderDialog(payload);
      },
      onClear: (): void => {
        this.isWeatherDialogOpen = false;
      }
    });
    this.arrivalReminderUnsubscribe = this.arrivalCoordinator.subscribePlan(this.currentPlanId, {
      isDialogOpen: (): boolean => this.isArrivalDialogOpen,
      resolveEvents: (): EventEntity[] => this.vm.events,
      onShowPlan: (payload: ArrivalReminderPayload): void => {
        this.showArrivalReminderDialog(payload);
      }
    });
  }
  private unbindReminderSubscriptions(): void {
    if (this.weatherReminderUnsubscribe) {
      this.weatherReminderUnsubscribe();
      this.weatherReminderUnsubscribe = null;
    }
    if (this.arrivalReminderUnsubscribe) {
      this.arrivalReminderUnsubscribe();
      this.arrivalReminderUnsubscribe = null;
    }
  }
  private async handlePagePullRefresh(): Promise<void> {
    if (this.isPageRefreshing || this.currentPlanId <= 0) {
      return;
    }
    this.isPageRefreshing = true;
    try {
      await this.vm.loadData(this.currentPlanId);
      await this.planService.requestArrivalCheckNow('plan_manual_refresh');
      this.arrivalCoordinator.consumeOnPlan({
        isDialogOpen: this.isArrivalDialogOpen,
        currentPlanId: this.currentPlanId,
        events: this.vm.events,
        onShow: (payload: ArrivalReminderPayload): void => {
          this.showArrivalReminderDialog(payload);
        }
      });
      if (this.vm.isWeatherFeatureEnabled()) {
        this.hasManualPlanningWeatherRefresh = true;
      }
    } finally {
      this.isPageRefreshing = false;
    }
  }
  private getReminderDialogContext(): ReminderDialogContext {
    const context: ReminderDialogContext = {
      vm: this.vm,
      currentPlanId: this.currentPlanId,
      getUIContext: (): UIContext => this.getUIContext(),
      weatherCoordinator: this.weatherCoordinator,
      arrivalCoordinator: this.arrivalCoordinator,
      tryStartEventWithConflictPrompt: async (eventId: number): Promise<boolean> => this.tryStartEventWithConflictPrompt(eventId),
      setWeatherDialogOpen: (value: boolean): void => {
        this.isWeatherDialogOpen = value;
      },
      setArrivalDialogOpen: (value: boolean): void => {
        this.isArrivalDialogOpen = value;
      },
      setCompanionMode: (value: boolean): void => {
        this.isCompanionMode = value;
      },
      safeShowToast: (message: string): void => {
        this.safeShowToast(message);
      }
    };
    return context;
  }
  private showWeatherReminderDialog(payload: WeatherReminderPayload): void {
    IndexPageBehaviorHelper.showWeatherReminderDialog(this.getReminderDialogContext(), payload);
  }
  private showArrivalReminderDialog(payload: ArrivalReminderPayload): void {
    IndexPageBehaviorHelper.showArrivalReminderDialog(this.getReminderDialogContext(), payload);
  }
  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }
  gapDialogController: CustomDialogController | null = IndexDialogManager.createGapResolutionController({
    vm: this.vm,
    currentGap: this.gapItem
  });
  conflictDialogController: CustomDialogController = this.createConflictDialogController();
  private createConflictDialogController(): CustomDialogController {
    return IndexDateConflictDialogFlowHelper.createController({
      vm: this.vm,
      getUIContext: (): UIContext => this.getUIContext(),
      getPendingItem: (): PendingItemData | null => this.pendingItem,
      setPendingItem: (item: PendingItemData | null): void => {
        this.pendingItem = item;
      },
      openDialog: (initData?: InitDialogData): void => {
        this.openDialog(initData);
      },
      reopenConflictDialog: (): void => {
        this.openConflictDialog();
      },
      safeShowToast: (message: string): void => {
        this.safeShowToast(message);
      }
    });
  }
  private openConflictDialog(): void {
    this.conflictDialogController = this.createConflictDialogController();
    this.conflictDialogController.open();
  }
  onPageShow() {
    IndexPageShowHelper.handlePageShow({
      vm: this.vm,
      onStartArrivalReminderEngine: (): void => {
        this.startArrivalReminderEngine();
      },
      onRefreshUnsavedFlag: (): void => {
        this.refreshUnsavedFlag();
      },
      onReadDraftStorage: (key: string): string => this.readDraftStorageWithFallback(key),
      onClearDraftStorage: (): void => {
        this.clearDialogDraftStorage();
      },
      onOpenDialog: (initData?: InitDialogData): void => {
        this.openDialog(initData);
      },
      onSafeToast: (message: string): void => {
        this.safeShowToast(message);
      },
      onSanitizeError: (error: Object): string => this.sanitizeError(error)
    });
  }
  private onGapFoundCallback = (item: EventEntity) => {}
  aiDialogController: CustomDialogController = IndexDialogManager.createAiDialogController({
    hasAiHistory: this.vm.hasAiHistory(),
    onConfirm: async (text: string, strategy: number, customStrategy?: ComposableStrategy): Promise<void> => {
      try {
        await this.vm.generateByAi(text, strategy, customStrategy);
        this.safeShowToast('AI 生成成功，已加入暂存池！');
        this.aiDialogController.close();
      } catch (error) {
        const msg = error instanceof Error ? error.message : '生成失败';
        this.safeShowToast(msg);
        this.aiDialogController.close();
      }
    },
    onRegenerate: async (): Promise<void> => {
      try {
        await this.vm.regenerateByCurrentStrategy();
        this.safeShowToast('重新生成成功');
        this.aiDialogController.close();
      } catch (error) {
        const msg = error instanceof Error ? error.message : '重新生成失败';
        console.error('[Index] AI重新规划失败:', JSON.stringify(error));
        this.safeShowToast(msg);
        this.aiDialogController.close();
      }
    }
  });
  private getConflictFlowContext(): ConflictFlowContext {
    const context: ConflictFlowContext = {
      vm: this.vm,
      getUIContext: (): UIContext => this.getUIContext(),
      safeShowToast: (message: string): void => this.safeShowToast(message),
      setConflictSelectionController: (controller: CustomDialogController | null): void => {
        this.conflictSelectionController = controller;
      },
      setConflictCompressController: (controller: CustomDialogController | null): void => {
        this.conflictCompressController = controller;
      },
      setConflictAdvanceController: (controller: CustomDialogController | null): void => {
        this.conflictAdvanceController = controller;
      },
      setSuggestionDialogController: (controller: CustomDialogController | null): void => {
        this.suggestionDialogController = controller;
      }
    };
    return context;
  }
  private handleEventConflictAction(item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number,
    onDone?: () => void): void {
    IndexConflictFlowHelper.handleEventConflictAction(this.getConflictFlowContext(), item, strategy, gapMinutes, onDone);
  }
  private requestPlanDateUpdate(newDateTimestamp: number): void {
    IndexConflictFlowHelper.requestPlanDateUpdate(this.getConflictFlowContext(), newDateTimestamp);
  }
  private async initBacklogExpandedState(planId: number, isNewPlan: boolean): Promise<void> {
    this.backlogExpanded = await IndexStateManager.initBacklogExpandedState(planId, isNewPlan);
  }
  private onToggleBacklogExpand(): void {
    this.backlogExpanded = !this.backlogExpanded;
    IndexStateManager.persistBacklogExpanded(this.currentPlanId, this.backlogExpanded);
  }
  private isDayCollapsed(dayOffset: number): boolean {
    return IndexStateManager.isDayCollapsed(this.collapsedDayOffsets, dayOffset);
  }
  private toggleDayCollapse(dayOffset: number): void {
    this.collapsedDayOffsets = IndexStateManager.toggleDayCollapse(this.collapsedDayOffsets, dayOffset);
  }
  openDialog(initData?: InitDialogData) {
    const prepared = IndexAddDialogFlowHelper.prepareDialogState(this.vm.events, this.editingItemId, initData);
    hilog.info(
      0x0000,
      'Index',
      `[MAP_TRACE][open_dialog] editId=${this.editingItemId}, createMode=${prepared.isCreateMode}, nameLen=${(initData?.name || '').length}, initCoordValid=${prepared.initCoordValid}, lat=${prepared.initLat}, lng=${prepared.initLng}`
    );
    this.dialogController = IndexDialogManager.createAddItemController({
      initName: initData?.name || '',
      initNote: initData?.note || '',
      initDuration: initData?.duration || 60,
      initIsAnchor: initData?.isAnchor || false,
      initFixedTime: initData?.fixedTime || '',
      initSuggestedTime: prepared.smartTime,
      initIsSchedule: initData ? true : false,
      initDayOffset: prepared.initDayOffset,
      initPreTravel: prepared.currentPreTravel,
      initPriority: prepared.currentPriority,
      storageScopePlanId: this.currentPlanId,
      planStartDate: this.vm.planStartDate,
      initLat: prepared.initLat,
      initLng: prepared.initLng,
      onDateChangedRecommendTime: (dayOffset: number, currentTime: string): string => {
        if (!prepared.isCreateMode) {
          return currentTime;
        }
        return IndexAddDialogHelper.recommendAddByDayOffset(this.vm.events, dayOffset);
      },
      onConfirm: async (name, duration, isSchedule, fixedTime, dayOffset, preTravel, isHardLock, note, isMustVisit, lat, lng) => {
        const result = await IndexAddDialogFlowHelper.handleDialogConfirm(
          {
            vm: this.vm,
            editingItemId: this.editingItemId,
            planStartDate: this.vm.planStartDate,
            collapsedDayOffsets: this.collapsedDayOffsets,
            hasActiveFilter: this.vm.filterStart > 0 || this.vm.filterEnd > 0,
            onGapFoundCallback: this.onGapFoundCallback
          },
          { name, duration, isSchedule, fixedTime, dayOffset, preTravel, isHardLock, note, isMustVisit, lat, lng }
        );
        this.collapsedDayOffsets = result.nextCollapsedDayOffsets;
        if (result.clearFilter) {
          this.vm.clearFilter();
          hilog.info(0x0000, 'IndexPage', '[ADD_UI][clear_filter_for_visibility] reason=new_schedule_item');
        }
        if (result.toastMessage) {
          this.safeShowToast(result.toastMessage);
        }
        if (result.pendingItem) {
          this.pendingItem = result.pendingItem;
        }
        if (result.openConflictDialog) {
          setTimeout(() => { this.openConflictDialog(); }, 100);
        }
        this.editingItemId = result.nextEditingItemId;
      }
    });
    this.dialogController.open();
  }
  // ✅ [修改] 打开高颜值筛选弹窗 (支持范围选择)
  openDateFilterDialog() {
    this.dateFilterController = IndexPageActionsHelper.openDateFilterDialog({
      vm: this.vm,
      getUIContext: (): UIContext => this.getUIContext()
    });
  }
  // [新增] 提取日期选择逻辑
  openDatePicker() {
    IndexPageActionsHelper.openDatePicker({
      vm: this.vm,
      getUIContext: (): UIContext => this.getUIContext(),
      requestPlanDateUpdate: (dateMs: number): void => {
        this.requestPlanDateUpdate(dateMs);
      }
    });
  }
  // ✅ [修复步骤 2] 修改打开菜单的方法
  openSettingsDialog() {
    this.settingsDialogController = IndexPageActionsHelper.openSettingsDialog({
      vm: this.vm,
      getUIContext: (): UIContext => this.getUIContext(),
      safeShowToast: (message: string): void => {
        this.safeShowToast(message);
      },
      openRenameDialog: (): void => {
        this.openRenameDialog();
      },
      openDatePicker: (): void => {
        this.openDatePicker();
      }
    });
    this.settingsDialogController.open();
  }
  // [Priority 2 新增] 打开重命名弹窗
  openRenameDialog() {
    this.dialogController = IndexPageActionsHelper.openRenameDialog({
      vm: this.vm,
      planTitle: this.planTitle,
      setPlanTitle: (title: string): void => {
        this.planTitle = title;
      }
    });
    this.dialogController.open();
  }
  aboutToAppear() {
    this.collapsedDayOffsets = [];
    this.vm.clearFilter();
    IndexLifecycleHelper.handleAboutToAppear({
      uiContext: this.getUIContext(),
      vm: this.vm,
      onSetCurrentPlanId: (planId: number): void => {
        this.currentPlanId = planId;
      },
      onSetManualWeatherRefresh: (value: boolean): void => {
        this.hasManualPlanningWeatherRefresh = value;
      },
      onRefreshUnsavedFlag: (): void => {
        this.refreshUnsavedFlag();
      },
      onSetPlanTitle: (title: string): void => {
        this.planTitle = title;
      },
      onBindReminderSubscriptions: (): void => {
        this.bindReminderSubscriptions();
      },
      onSetStrategyMode: (mode: number): void => {
        this.strategyMode = mode;
      },
      onLoadStrategyExplanation: (): void => {
        this.loadStrategyExplanation();
      },
      onSetCompanionMode: (value: boolean): void => {
        this.isCompanionMode = value;
      },
      onTryStartEvent: async (eventId: number): Promise<boolean> => this.tryStartEventWithConflictPrompt(eventId),
      onStartArrivalReminderEngine: (): void => {
        this.startArrivalReminderEngine();
      },
      onStartStrategyAdaptationCheck: (): void => {
        this.startStrategyAdaptationCheck();
      },
      onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean): Promise<void> => {
        await this.initBacklogExpandedState(planId, isNewPlan);
      },
      onLoadDataError: (reason: string): void => {
        hilog.error(0x0000, 'Index', `[ARRIVAL][load_data_failed] reason=${reason}`);
      }
    });
  }
  aboutToDisappear() {
    IndexLifecycleHelper.handleAboutToDisappear({
      strategyAdaptationCheckTimer: this.strategyAdaptationCheckTimer,
      onUnbindReminderSubscriptions: (): void => {
        this.unbindReminderSubscriptions();
      },
      onStopArrivalEngine: (): void => {
        this.planService.stopArrivalEngine();
      },
      onStopExecutionWeatherScheduler: (): void => {
        this.vm.stopExecutionWeatherScheduler();
      },
      onUnbindPlanState: (): void => {
        this.vm.unbindPlanState();
      },
      onClearDialogDraftStorage: (): void => {
        this.clearDialogDraftStorage();
      },
      onSetStrategyAdaptationCheckTimer: (timer: number): void => {
        this.strategyAdaptationCheckTimer = timer;
      }
    });
  }
  private getStrategyDialogContext(): StrategyDialogContext {
    const context: StrategyDialogContext = {
      vm: this.vm,
      strategyMode: this.strategyMode,
      getUIContext: (): UIContext => this.getUIContext(),
      regenerateByCurrentStrategy: async (): Promise<void> => this.vm.regenerateByCurrentStrategy()
    };
    return context;
  }
  private loadStrategyExplanation(): void {
    this.currentStrategyExplanation = IndexPageBehaviorHelper.loadStrategyExplanation(this.strategyMode);
  }
  private startStrategyAdaptationCheck(): void {
    this.strategyAdaptationCheckTimer = IndexPageBehaviorHelper.startStrategyAdaptationCheck(this.getStrategyDialogContext());
  }
  openEditDialog(item: EventEntity) {
    const prepared = IndexPageActionsHelper.prepareEditDialog(item);
    this.editingItemId = prepared.editingItemId;
    this.openDialog(prepared.initData);
  }
  build() {
    Column() {
      IndexPageLayout({
        vm: this.vm,
        planTitle: this.planTitle,
        strategyMode: this.strategyMode,
        currentStrategyExplanation: this.currentStrategyExplanation,
        isCompanionMode: this.isCompanionMode,
        hasManualPlanningWeatherRefresh: this.hasManualPlanningWeatherRefresh,
        showPlanningWeatherHintPopup: this.showPlanningWeatherHintPopup,
        showPlanningWeatherScorePopup: this.showPlanningWeatherScorePopup,
        backlogExpanded: this.backlogExpanded,
        isPageRefreshing: this.isPageRefreshing,
        hasUnsavedChanges: this.hasScopedUnsavedChanges(),
        themePalette: this.getThemePalette(),
        companionOverlayZIndex: DomainConstants.COMPANION_OVERLAY_Z_INDEX,
        companionBackRequestToken: this.companionBackRequestToken,
        onBack: (): void => {
          void NavigationHelper.backOrFallbackToPlanList(this.getUIContext());
        },
        onOpenSettings: (): void => {
          if (this.vm.isArchived) {
            return;
          }
          this.openSettingsDialog();
        },
        onEnterCompanion: (): void => {
          hilog.info(0x0000, 'Index', '[DUAL_MODE_ACCEPT][mode_switch][click_enter]');
          if (this.vm.isArchived) {
            this.safeShowToast('归档计划不可进入伴游');
            return;
          }
          this.isCompanionMode = true;
        },
        onRefreshWeather: (): void => {
          this.hasManualPlanningWeatherRefresh = true;
          void this.vm.refreshPlanningWeather(true).then((): void => {
            this.safeShowToast('天气已刷新');
          }).catch((_error: Object): void => {
            this.safeShowToast('天气刷新失败');
          });
        },
        onToggleHint: (): void => {
          this.showPlanningWeatherHintPopup = !this.showPlanningWeatherHintPopup;
        },
        onToggleScore: (): void => {
          this.showPlanningWeatherScorePopup = !this.showPlanningWeatherScorePopup;
        },
        onHintPopupVisibleChange: (visible: boolean): void => {
          this.showPlanningWeatherHintPopup = visible;
        },
        onScorePopupVisibleChange: (visible: boolean): void => {
          this.showPlanningWeatherScorePopup = visible;
        },
        onToggleBacklogExpand: (): void => {
          this.onToggleBacklogExpand();
        },
        onMoveToSchedule: (item: TravelPlanItem): void => {
          const moveItem: MoveToScheduleItem = {
            id: item.id,
            name: item.name,
            note: item.note,
            duration: item.duration
          };
          IndexPageActionsHelper.moveItemToSchedule({
            vm: this.vm,
            setEditingItemId: (id: number): void => {
              this.editingItemId = id;
            },
            openDialog: (initData?: InitDialogData): void => {
              this.openDialog(initData);
            }
          }, moveItem);
        },
        onMoveAllToSchedule: (): void => {
          IndexPageActionsHelper.handleMoveAllToSchedule({
            vm: this.vm,
            safeShowToast: (message: string): void => this.safeShowToast(message),
            getUIContext: (): UIContext => this.getUIContext()
          });
        },
        onIsDayCollapsed: (dayOffset: number): boolean => this.isDayCollapsed(dayOffset),
        onToggleDay: (dayOffset: number): void => this.toggleDayCollapse(dayOffset),
        onScheduleRefresh: (): void => {
          void this.handlePagePullRefresh();
        },
        onOpenEditDialog: (item: EventEntity): void => this.openEditDialog(item),
        onOpenTimeEditDialog: (_item: EventEntity): void => {},
        onGapFound: (item: EventEntity): void => this.onGapFoundCallback(item),
        onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number): void => {
          this.handleEventConflictAction(item, strategy, gapMinutes);
        },
        onConfirmMoveToBacklog: (item: EventEntity): void => {
          IndexPageActionsHelper.handleConfirmMoveToBacklog({
            vm: this.vm,
            safeShowToast: (message: string): void => this.safeShowToast(message),
            getUIContext: (): UIContext => this.getUIContext()
          }, item);
        },
        onConfirmDeleteEvent: (item: EventEntity): void => {
          IndexPageActionsHelper.handleConfirmDeleteEvent({
            vm: this.vm,
            safeShowToast: (message: string): void => this.safeShowToast(message),
            getUIContext: (): UIContext => this.getUIContext()
          }, item);
        },
        onOpenGapOptimize: (): void => {
          this.gapItem = null;
          this.gapDialogController?.open();
        },
        onFilter: (): void => {
          IndexEventHandlers.handleFilter((): void => this.openDateFilterDialog());
        },
        onAi: (): void => {
          IndexEventHandlers.handleAiSuggestion(
            this.vm.isArchived,
            (): void => this.safeShowToast('归档计划不可操作'),
            (): void => this.aiDialogController.open()
          );
        },
        onAdd: (): void => {
          IndexEventHandlers.handleAddItem(
            this.vm.isArchived,
            (): void => this.safeShowToast('归档计划不可操作'),
            (): void => {
              this.editingItemId = -1;
              this.openDialog();
            }
          );
        },
        onUndo: (): void => {
          void this.vm.loadData(this.vm.planId);
          this.setUnsavedFlag(false);
        },
        onSave: (): void => {
          this.vm.save();
          this.setUnsavedFlag(false);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
