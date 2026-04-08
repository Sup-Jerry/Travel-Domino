import { TimelineViewModel } from '../viewmodel/TimelineViewModel';
import { EventEntity } from '../model/entity/EventEntity';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { WeatherReminderCoordinator } from '../infrastructure/services/WeatherReminderCoordinator';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { DomainConstants } from '../common/constants/DomainConstants';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { IndexPageLayout } from './index/IndexPageLayout';
import { InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexLifecycleHelper } from './index/IndexLifecycleHelper';
import { IndexDialogManager } from './index/IndexDialogManager';
import { ConflictFlowContext } from './index/IndexConflictFlowHelper';
import { IndexPageShowHelper } from './index/IndexPageShowHelper';
import { IndexStartEventGuardHelper } from './index/IndexStartEventGuardHelper';
import { IndexDialogBindingsHelper } from './index/IndexDialogBindingsHelper';
import { IndexPageBindingsBuilder } from './index/IndexPageBindingsBuilder';
import { IndexPageLifecycleBindingsBuilder } from './index/IndexPageLifecycleBindingsBuilder';
import { IndexPageRuntimeOrchestrator, IndexPageRuntimeOrchestratorContext } from './index/IndexPageRuntimeOrchestrator';
import { IndexPageRuntimeContextFactory } from './index/IndexPageRuntimeContextFactory';
import { IndexPageDialogFlowHelper } from './index/IndexPageDialogFlowHelper';
@Entry
@Component
struct Index {
  @State vm: TimelineViewModel = new TimelineViewModel();
  @State planTitle: string = '�г�����';
  @State editingItemId: number = -1;
  @State currentPlanId: number = -1;
  @State backlogExpanded: boolean = false;
  @State collapsedDayOffsets: number[] = [];
  @State pendingItem: PendingItemData | null = null;
  @State gapItem: EventEntity | null = null; // 闁活潿鍔嬬花顒佸閻樼數鑸剁€殿喖婀遍悰?
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
    hilog.info(0x0000, 'Index', '�յ��ߵ����ݸ����źţ����� UI ����');
    // 閻犱警鍨伴崰灞筋嚕閸屾侗鍔勯柛銉у仜閿濈偤宕氶幏灞惧涧闁告艾鍑界槐婵嗩嚕閸濆嫬鐓戦梺鎻掔У婵椽鏌呭顒€鐝舵鐐舵硾閸欏繘鏌岃箛娑樻闁圭儤甯槐婵堟兜椤旇崵绠介悹鎭掑妼閵囧宕氶崱娆戠煁闁告瑥锕ュ鍌炴偨閻斿憡娅忛柕?
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
  onBackPress(): boolean {
    this.companionBackRequestToken += this.isCompanionMode ? 1 : 0;
    return this.isCompanionMode;
  }
  private createRuntimeOrchestratorContext(): IndexPageRuntimeOrchestratorContext {
    return IndexPageRuntimeContextFactory.create(
      this.currentPlanId,
      this.vm,
      this.planService,
      this.weatherCoordinator,
      this.arrivalCoordinator,
      this.strategyMode,
      this.isWeatherDialogOpen,
      this.isArrivalDialogOpen,
      this.weatherReminderUnsubscribe,
      this.arrivalReminderUnsubscribe,
      this.strategyAdaptationCheckTimer,
      (): UIContext => this.getUIContext(),
      (message: string): void => this.safeShowToast(message),
      async (eventId: number): Promise<boolean> => this.tryStartEventWithConflictPrompt(eventId),
      (value: boolean): void => { this.isWeatherDialogOpen = value; },
      (value: boolean): void => { this.isArrivalDialogOpen = value; },
      (value: boolean): void => { this.isCompanionMode = value; },
      (value: boolean): void => { this.hasManualPlanningWeatherRefresh = value; },
      (unsubscribe: (() => void) | null): void => { this.weatherReminderUnsubscribe = unsubscribe; },
      (unsubscribe: (() => void) | null): void => { this.arrivalReminderUnsubscribe = unsubscribe; },
      (controller: CustomDialogController | null): void => { this.conflictSelectionController = controller; },
      (controller: CustomDialogController | null): void => { this.conflictCompressController = controller; },
      (controller: CustomDialogController | null): void => { this.conflictAdvanceController = controller; },
      (controller: CustomDialogController | null): void => { this.suggestionDialogController = controller; },
      (explanation: string): void => { this.currentStrategyExplanation = explanation; },
      (timer: number): void => { this.strategyAdaptationCheckTimer = timer; }
    );
  }
  gapDialogController: CustomDialogController | null = IndexDialogManager.createGapResolutionController({
    vm: this.vm,
    currentGap: this.gapItem
  });
  conflictDialogController: CustomDialogController | null = null;
  private openConflictDialog(): void {
    this.conflictDialogController = IndexPageDialogFlowHelper.openConflictDialog(
      this.vm,
      (): UIContext => this.getUIContext(),
      (): PendingItemData | null => this.pendingItem,
      (item: PendingItemData | null): void => { this.pendingItem = item; },
      (initData?: InitDialogData): void => { this.openDialog(initData); },
      (): void => { this.openConflictDialog(); },
      (message: string): void => { this.safeShowToast(message); }
    );
  }
  onPageShow() {
    IndexPageShowHelper.handlePageShow(IndexPageLifecycleBindingsBuilder.createPageShowParams({
      vm: this.vm,
      onStartArrivalReminderEngine: (): void => { this.startArrivalReminderEngine(); },
      onRefreshUnsavedFlag: (): void => { this.hasUnsavedChanges = IndexStateManager.readUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE); },
      onReadDraftStorage: (key: string): string => this.readDraftStorageWithFallback(key),
      onClearDraftStorage: (): void => { this.clearDialogDraftStorage(); },
      onOpenDialog: (initData?: InitDialogData): void => { this.openDialog(initData); },
      onSafeToast: (message: string): void => { this.safeShowToast(message); },
      onSanitizeError: (error: Object): string => this.sanitizeError(error)
    }));
  }
  private onGapFoundCallback = (item: EventEntity) => {}
  aiDialogController: CustomDialogController = IndexDialogBindingsHelper.createAiDialogController({
    vm: this.vm,
    safeShowToast: (message: string): void => this.safeShowToast(message),
    onCloseDialog: (): void => this.aiDialogController.close()
  });
  openDialog(initData?: InitDialogData) {
    this.dialogController = IndexPageDialogFlowHelper.openAddDialog(
      this.vm,
      this.editingItemId,
      this.currentPlanId,
      this.collapsedDayOffsets,
      this.onGapFoundCallback,
      (offsets: number[]): void => { this.collapsedDayOffsets = offsets; },
      (item: PendingItemData | null): void => { this.pendingItem = item; },
      (): void => { this.openConflictDialog(); },
      (id: number): void => { this.editingItemId = id; },
      (message: string): void => { this.safeShowToast(message); },
      initData
    );
  }
  aboutToAppear() {
    this.collapsedDayOffsets = [];
    this.vm.clearFilter();
    IndexLifecycleHelper.handleAboutToAppear(IndexPageLifecycleBindingsBuilder.createAboutToAppearParams({
      uiContext: this.getUIContext(),
      vm: this.vm,
      onSetCurrentPlanId: (planId: number): void => { this.currentPlanId = planId; },
      onSetManualWeatherRefresh: (value: boolean): void => { this.hasManualPlanningWeatherRefresh = value; },
      onRefreshUnsavedFlag: (): void => {
        this.hasUnsavedChanges = IndexStateManager.readUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE);
      },
      onSetPlanTitle: (title: string): void => { this.planTitle = title; },
      onBindReminderSubscriptions: (): void => {
        IndexPageRuntimeOrchestrator.bindReminderSubscriptions(this.createRuntimeOrchestratorContext());
      },
      onSetStrategyMode: (mode: number): void => { this.strategyMode = mode; },
      onLoadStrategyExplanation: (): void => {
        IndexPageRuntimeOrchestrator.loadStrategyExplanation(this.createRuntimeOrchestratorContext());
      },
      onSetCompanionMode: (value: boolean): void => { this.isCompanionMode = value; },
      onTryStartEvent: async (eventId: number): Promise<boolean> => this.tryStartEventWithConflictPrompt(eventId),
      onStartArrivalReminderEngine: (): void => { this.startArrivalReminderEngine(); },
      onStartStrategyAdaptationCheck: (): void => {
        IndexPageRuntimeOrchestrator.startStrategyAdaptationCheck(this.createRuntimeOrchestratorContext());
      },
      onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean): Promise<void> => {
        this.backlogExpanded = await IndexStateManager.initBacklogExpandedState(planId, isNewPlan);
      },
      onLoadDataError: (reason: string): void => { hilog.error(0x0000, 'Index', '[ARRIVAL][load_data_failed] reason=' + reason); }
    }));
  }
  aboutToDisappear() {
    IndexLifecycleHelper.handleAboutToDisappear(IndexPageLifecycleBindingsBuilder.createAboutToDisappearParams({
      strategyAdaptationCheckTimer: this.strategyAdaptationCheckTimer,
      onUnbindReminderSubscriptions: (): void => {
        IndexPageRuntimeOrchestrator.unbindReminderSubscriptions(this.createRuntimeOrchestratorContext());
      },
      onStopArrivalEngine: (): void => { this.planService.stopArrivalEngine(); },
      onStopExecutionWeatherScheduler: (): void => { this.vm.stopExecutionWeatherScheduler(); },
      onUnbindPlanState: (): void => { this.vm.unbindPlanState(); },
      onClearDialogDraftStorage: (): void => { this.clearDialogDraftStorage(); },
      onSetStrategyAdaptationCheckTimer: (timer: number): void => { this.strategyAdaptationCheckTimer = timer; }
    }));
  }
  build() {
    Column() {
      IndexPageLayout(IndexPageBindingsBuilder.createLayoutProps({
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
        currentPlanId: this.currentPlanId,
        collapsedDayOffsets: this.collapsedDayOffsets,
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
        onScheduleRefresh: (): void => {
          if (this.isPageRefreshing || this.currentPlanId <= 0) {
            return;
          }
          this.isPageRefreshing = true;
          void IndexPageRuntimeOrchestrator.handlePagePullRefresh(this.createRuntimeOrchestratorContext())
            .finally((): void => {
              this.isPageRefreshing = false;
            });
        },
        onGapFound: (item: EventEntity): void => this.onGapFoundCallback(item),
        getConflictFlowContext: (): ConflictFlowContext =>
          IndexPageRuntimeOrchestrator.createConflictFlowContext(this.createRuntimeOrchestratorContext()),
        setGapItem: (item: EventEntity | null): void => { this.gapItem = item; },
        openGapDialog: (): void => { this.gapDialogController?.open(); },
        setDateFilterController: (controller: CustomDialogController | null): void => { this.dateFilterController = controller; },
        openAiDialog: (): void => this.aiDialogController.open(),
        openDialog: (initData?: InitDialogData): void => { this.openDialog(initData); },
        setPlanTitle: (title: string): void => { this.planTitle = title; },
        setDialogController: (controller: CustomDialogController | null): void => { this.dialogController = controller; },
        setSettingsDialogController: (controller: CustomDialogController | null): void => { this.settingsDialogController = controller; }
      }))
    }.width('100%').height('100%')
  }
}