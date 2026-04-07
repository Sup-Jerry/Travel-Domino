import { TimelineViewModel } from '../viewmodel/TimelineViewModel';
import { EventEntity } from '../model/entity/EventEntity';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { WeatherReminderCoordinator } from '../infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload } from '../common/utils/weather/WeatherReminderStore';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { DomainConstants } from '../common/constants/DomainConstants';
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { IndexPageLayout } from './index/IndexPageLayout';
import { InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexLifecycleHelper } from './index/IndexLifecycleHelper';
import { IndexDialogManager } from './index/IndexDialogManager';
import { IndexDateConflictDialogFlowHelper } from './index/IndexDateConflictDialogFlowHelper';
import { ConflictFlowContext } from './index/IndexConflictFlowHelper';
import { IndexPageBehaviorHelper, ReminderDialogContext, StrategyDialogContext } from './index/IndexPageBehaviorHelper';
import { IndexPageShowHelper } from './index/IndexPageShowHelper';
import { IndexPageContextFactory } from './index/IndexPageContextFactory';
import { IndexReminderSubscriptionHelper } from './index/IndexReminderSubscriptionHelper';
import { IndexStartEventGuardHelper } from './index/IndexStartEventGuardHelper';
import { IndexDialogBindingsHelper } from './index/IndexDialogBindingsHelper';
import { IndexLayoutCallbacksBuilder } from './index/IndexLayoutCallbacksBuilder';
import { IndexLayoutCallbacksContextFactory } from './index/IndexLayoutCallbacksContextFactory';
import { IndexLayoutPropsBuilder } from './index/IndexLayoutPropsBuilder';
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
  private async tryStartEventWithConflictPrompt(eventId: number): Promise<boolean> {
    return IndexStartEventGuardHelper.tryStartEventWithConflictPrompt({
      vm: this.vm,
      currentPlanId: this.currentPlanId,
      planTitle: this.planTitle,
      getUIContext: (): UIContext => this.getUIContext(),
      safeShowToast: (message: string): void => this.safeShowToast(message)
    }, eventId);
  }
  private refreshUnsavedChangesFlag(): void {
    this.hasUnsavedChanges = IndexStateManager.readUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE);
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
    const result = IndexReminderSubscriptionHelper.bind({
      currentPlanId: this.currentPlanId,
      vm: this.vm,
      weatherCoordinator: this.weatherCoordinator,
      arrivalCoordinator: this.arrivalCoordinator,
      isWeatherDialogOpen: (): boolean => this.isWeatherDialogOpen,
      isArrivalDialogOpen: (): boolean => this.isArrivalDialogOpen,
      onShowWeatherDialog: (payload: WeatherReminderPayload): void => {
        IndexPageBehaviorHelper.showWeatherReminderDialog(this.getReminderDialogContext(), payload);
      },
      onShowArrivalDialog: (payload: ArrivalReminderPayload): void => {
        IndexPageBehaviorHelper.showArrivalReminderDialog(this.getReminderDialogContext(), payload);
      },
      onClearWeatherDialog: (): void => {
        this.isWeatherDialogOpen = false;
      }
    });
    this.weatherReminderUnsubscribe = result.weatherUnsubscribe;
    this.arrivalReminderUnsubscribe = result.arrivalUnsubscribe;
  }
  private unbindReminderSubscriptions(): void {
    const result = IndexReminderSubscriptionHelper.unbind(this.weatherReminderUnsubscribe, this.arrivalReminderUnsubscribe);
    this.weatherReminderUnsubscribe = result.weatherUnsubscribe;
    this.arrivalReminderUnsubscribe = result.arrivalUnsubscribe;
  }
  private async handlePagePullRefresh(): Promise<void> {
    if (this.isPageRefreshing || this.currentPlanId <= 0) {
      return;
    }
    this.isPageRefreshing = true;
    try {
      await IndexReminderSubscriptionHelper.handlePagePullRefresh({
        currentPlanId: this.currentPlanId,
        vm: this.vm,
        planService: this.planService,
        arrivalCoordinator: this.arrivalCoordinator,
        isArrivalDialogOpen: this.isArrivalDialogOpen,
        onShowArrivalDialog: (payload: ArrivalReminderPayload): void => {
          IndexPageBehaviorHelper.showArrivalReminderDialog(this.getReminderDialogContext(), payload);
        },
        setManualWeatherRefreshed: (): void => {
          this.hasManualPlanningWeatherRefresh = true;
        }
      });
    } finally {
      this.isPageRefreshing = false;
    }
  }
  private getReminderDialogContext(): ReminderDialogContext {
    return IndexPageContextFactory.createReminderDialogContext({
      vm: this.vm,
      currentPlanId: this.currentPlanId,
      getUIContext: (): UIContext => this.getUIContext(),
      weatherCoordinator: this.weatherCoordinator,
      arrivalCoordinator: this.arrivalCoordinator,
      tryStartEventWithConflictPrompt: async (eventId: number): Promise<boolean> => {
        return this.tryStartEventWithConflictPrompt(eventId);
      },
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
    });
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
      onStartArrivalReminderEngine: (): void => { this.startArrivalReminderEngine(); },
      onRefreshUnsavedFlag: (): void => { this.refreshUnsavedChangesFlag(); },
      onReadDraftStorage: (key: string): string => this.readDraftStorageWithFallback(key),
      onClearDraftStorage: (): void => { this.clearDialogDraftStorage(); },
      onOpenDialog: (initData?: InitDialogData): void => { this.openDialog(initData); },
      onSafeToast: (message: string): void => { this.safeShowToast(message); },
      onSanitizeError: (error: Object): string => this.sanitizeError(error)
    });
  }
  private onGapFoundCallback = (item: EventEntity) => {}
  aiDialogController: CustomDialogController = IndexDialogBindingsHelper.createAiDialogController({
    vm: this.vm,
    safeShowToast: (message: string): void => this.safeShowToast(message),
    onCloseDialog: (): void => this.aiDialogController.close()
  });
  private getConflictFlowContext(): ConflictFlowContext {
    return IndexPageContextFactory.createConflictFlowContext({
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
    });
  }
  private async initBacklogExpandedState(planId: number, isNewPlan: boolean): Promise<void> {
    this.backlogExpanded = await IndexStateManager.initBacklogExpandedState(planId, isNewPlan);
  }
  openDialog(initData?: InitDialogData) {
    this.dialogController = IndexDialogBindingsHelper.createAddDialogController({
      vm: this.vm,
      editingItemId: this.editingItemId,
      currentPlanId: this.currentPlanId,
      collapsedDayOffsets: this.collapsedDayOffsets,
      setCollapsedDayOffsets: (offsets: number[]): void => {
        this.collapsedDayOffsets = offsets;
      },
      onGapFoundCallback: this.onGapFoundCallback,
      setPendingItem: (item: PendingItemData | null): void => {
        this.pendingItem = item;
      },
      openConflictDialog: (): void => {
        this.openConflictDialog();
      },
      setEditingItemId: (id: number): void => {
        this.editingItemId = id;
      },
      safeShowToast: (message: string): void => {
        this.safeShowToast(message);
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
      onSetCurrentPlanId: (planId: number): void => { this.currentPlanId = planId; },
      onSetManualWeatherRefresh: (value: boolean): void => { this.hasManualPlanningWeatherRefresh = value; },
      onRefreshUnsavedFlag: (): void => { this.refreshUnsavedChangesFlag(); },
      onSetPlanTitle: (title: string): void => { this.planTitle = title; },
      onBindReminderSubscriptions: (): void => { this.bindReminderSubscriptions(); },
      onSetStrategyMode: (mode: number): void => { this.strategyMode = mode; },
      onLoadStrategyExplanation: (): void => { this.loadStrategyExplanation(); },
      onSetCompanionMode: (value: boolean): void => { this.isCompanionMode = value; },
      onTryStartEvent: async (eventId: number): Promise<boolean> => this.tryStartEventWithConflictPrompt(eventId),
      onStartArrivalReminderEngine: (): void => { this.startArrivalReminderEngine(); },
      onStartStrategyAdaptationCheck: (): void => { this.startStrategyAdaptationCheck(); },
      onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean): Promise<void> =>
        this.initBacklogExpandedState(planId, isNewPlan),
      onLoadDataError: (reason: string): void => { hilog.error(0x0000, 'Index', `[ARRIVAL][load_data_failed] reason=${reason}`); }
    });
  }
  aboutToDisappear() {
    IndexLifecycleHelper.handleAboutToDisappear({
      strategyAdaptationCheckTimer: this.strategyAdaptationCheckTimer,
      onUnbindReminderSubscriptions: (): void => { this.unbindReminderSubscriptions(); },
      onStopArrivalEngine: (): void => { this.planService.stopArrivalEngine(); },
      onStopExecutionWeatherScheduler: (): void => { this.vm.stopExecutionWeatherScheduler(); },
      onUnbindPlanState: (): void => { this.vm.unbindPlanState(); },
      onClearDialogDraftStorage: (): void => { this.clearDialogDraftStorage(); },
      onSetStrategyAdaptationCheckTimer: (timer: number): void => { this.strategyAdaptationCheckTimer = timer; }
    });
  }
  private getStrategyDialogContext(): StrategyDialogContext {
    return IndexPageContextFactory.createStrategyDialogContext({
      vm: this.vm,
      strategyMode: this.strategyMode,
      getUIContext: (): UIContext => this.getUIContext(),
      regenerateByCurrentStrategy: async (): Promise<void> => this.vm.regenerateByCurrentStrategy()
    });
  }
  private loadStrategyExplanation(): void {
    this.currentStrategyExplanation = IndexPageBehaviorHelper.loadStrategyExplanation(this.strategyMode);
  }
  private startStrategyAdaptationCheck(): void {
    this.strategyAdaptationCheckTimer = IndexPageBehaviorHelper.startStrategyAdaptationCheck(this.getStrategyDialogContext());
  }
  build() {
    Column() {
      IndexPageLayout(IndexLayoutPropsBuilder.create({
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
        hasUnsavedChanges: IndexStateManager.readUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE),
        themePalette: ThemeCenter.getPalette(this.effectiveTheme),
        companionOverlayZIndex: DomainConstants.COMPANION_OVERLAY_Z_INDEX,
        companionBackRequestToken: this.companionBackRequestToken,
        callbacks: IndexLayoutCallbacksBuilder.create(IndexLayoutCallbacksContextFactory.create({
          vm: this.vm,
          planTitle: this.planTitle,
          currentPlanId: this.currentPlanId,
          collapsedDayOffsets: this.collapsedDayOffsets,
          backlogExpanded: this.backlogExpanded,
          getUIContext: (): UIContext => this.getUIContext(),
          safeShowToast: (message: string): void => this.safeShowToast(message),
          setCompanionMode: (value: boolean): void => { this.isCompanionMode = value; },
          setManualPlanningWeatherRefresh: (value: boolean): void => { this.hasManualPlanningWeatherRefresh = value; },
          setHintPopupVisible: (value: boolean): void => { this.showPlanningWeatherHintPopup = value; },
          setScorePopupVisible: (value: boolean): void => { this.showPlanningWeatherScorePopup = value; },
          toggleHintPopup: (): void => { this.showPlanningWeatherHintPopup = !this.showPlanningWeatherHintPopup; },
          toggleScorePopup: (): void => { this.showPlanningWeatherScorePopup = !this.showPlanningWeatherScorePopup; },
          setBacklogExpanded: (value: boolean): void => { this.backlogExpanded = value; },
          setCollapsedDayOffsets: (offsets: number[]): void => { this.collapsedDayOffsets = offsets; },
          setEditingItemId: (id: number): void => { this.editingItemId = id; },
          setHasUnsavedChanges: (value: boolean): void => { this.hasUnsavedChanges = value; },
          onScheduleRefresh: (): void => { void this.handlePagePullRefresh(); },
          onGapFound: (item: EventEntity): void => this.onGapFoundCallback(item),
          getConflictFlowContext: (): ConflictFlowContext => this.getConflictFlowContext(),
          setGapItem: (item: EventEntity | null): void => { this.gapItem = item; },
          openGapDialog: (): void => { this.gapDialogController?.open(); },
          setDateFilterController: (controller: CustomDialogController | null): void => { this.dateFilterController = controller; },
          openAiDialog: (): void => this.aiDialogController.open(),
          openDialog: (initData?: InitDialogData): void => { this.openDialog(initData); },
          setPlanTitle: (title: string): void => { this.planTitle = title; },
          setDialogController: (controller: CustomDialogController | null): void => { this.dialogController = controller; },
          setSettingsDialogController: (controller: CustomDialogController | null): void => { this.settingsDialogController = controller; }
        }))
      }))
    }.width('100%').height('100%')
  }
}
