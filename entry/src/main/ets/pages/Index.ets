import { TimelineViewModel } from '../viewmodel/TimelineViewModel';
import { EventEntity } from '../model/entity/EventEntity';
import { TravelPlanItem } from '../model/interface/IStandardEvent';
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
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { IndexPageLayout } from './index/IndexPageLayout';
import { IndexEventHandlers } from './index/IndexEventHandlers';
import { InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexLifecycleHelper } from './index/IndexLifecycleHelper';
import { IndexDialogManager } from './index/IndexDialogManager';
import { IndexAddDialogControllerHelper } from './index/IndexAddDialogControllerHelper';
import { IndexDateConflictDialogFlowHelper } from './index/IndexDateConflictDialogFlowHelper';
import { ConflictFlowContext, IndexConflictFlowHelper } from './index/IndexConflictFlowHelper';
import { IndexPageBehaviorHelper, ReminderDialogContext, StrategyDialogContext } from './index/IndexPageBehaviorHelper';
import { IndexPageActionsHelper } from './index/IndexPageActionsHelper';
import { IndexPageShowHelper } from './index/IndexPageShowHelper';
import { IndexPageContextFactory } from './index/IndexPageContextFactory';
import { IndexReminderSubscriptionHelper } from './index/IndexReminderSubscriptionHelper';
import { IndexStartEventGuardHelper } from './index/IndexStartEventGuardHelper';
import { IndexSettingsDialogFlowHelper } from './index/IndexSettingsDialogFlowHelper';
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
    const result = IndexReminderSubscriptionHelper.bind({
      currentPlanId: this.currentPlanId,
      vm: this.vm,
      weatherCoordinator: this.weatherCoordinator,
      arrivalCoordinator: this.arrivalCoordinator,
      isWeatherDialogOpen: (): boolean => this.isWeatherDialogOpen,
      isArrivalDialogOpen: (): boolean => this.isArrivalDialogOpen,
      onShowWeatherDialog: (payload: WeatherReminderPayload): void => {
        this.showWeatherReminderDialog(payload);
      },
      onShowArrivalDialog: (payload: ArrivalReminderPayload): void => {
        this.showArrivalReminderDialog(payload);
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
          this.showArrivalReminderDialog(payload);
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
        return IndexStartEventGuardHelper.tryStartEventWithConflictPrompt({
          vm: this.vm,
          currentPlanId: this.currentPlanId,
          planTitle: this.planTitle,
          getUIContext: (): UIContext => this.getUIContext(),
          safeShowToast: (message: string): void => this.safeShowToast(message)
        }, eventId);
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
    this.dialogController = IndexAddDialogControllerHelper.create({
      vm: this.vm,
      editingItemId: this.editingItemId,
      currentPlanId: this.currentPlanId,
      collapsedDayOffsets: this.collapsedDayOffsets,
      setCollapsedDayOffsets: (offsets: number[]): void => {
        this.collapsedDayOffsets = offsets;
      },
      clearFilter: (): void => {
        this.vm.clearFilter();
      },
      hasActiveFilter: this.vm.filterStart > 0 || this.vm.filterEnd > 0,
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
      onTryStartEvent: async (eventId: number): Promise<boolean> => {
        return IndexStartEventGuardHelper.tryStartEventWithConflictPrompt({
          vm: this.vm,
          currentPlanId: this.currentPlanId,
          planTitle: this.planTitle,
          getUIContext: (): UIContext => this.getUIContext(),
          safeShowToast: (message: string): void => this.safeShowToast(message)
        }, eventId);
      },
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
          IndexSettingsDialogFlowHelper.open({
            vm: this.vm,
            planTitle: this.planTitle,
            getUIContext: (): UIContext => this.getUIContext(),
            safeShowToast: (message: string): void => this.safeShowToast(message),
            setPlanTitle: (title: string): void => {
              this.planTitle = title;
            },
            requestPlanDateUpdate: (dateMs: number): void => this.requestPlanDateUpdate(dateMs),
            setDialogController: (controller: CustomDialogController | null): void => {
              this.dialogController = controller;
            },
            setSettingsDialogController: (controller: CustomDialogController | null): void => {
              this.settingsDialogController = controller;
            }
          });
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
          IndexPageActionsHelper.moveTravelPlanItemToSchedule({
            vm: this.vm,
            setEditingItemId: (id: number): void => {
              this.editingItemId = id;
            },
            openDialog: (initData?: InitDialogData): void => {
              this.openDialog(initData);
            }
          }, item);
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
        onScheduleRefresh: (): void => { void this.handlePagePullRefresh(); },
        onOpenEditDialog: (item: EventEntity): void => {
          const prepared = IndexPageActionsHelper.prepareEditDialog(item);
          this.editingItemId = prepared.editingItemId;
          this.openDialog(prepared.initData);
        },
        onOpenTimeEditDialog: (_item: EventEntity): void => {},
        onGapFound: (item: EventEntity): void => this.onGapFoundCallback(item),
        onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number): void => { this.handleEventConflictAction(item, strategy, gapMinutes); },
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
          IndexEventHandlers.handleFilter((): void => {
            this.dateFilterController = IndexPageActionsHelper.openDateFilterDialog({
              vm: this.vm,
              getUIContext: (): UIContext => this.getUIContext()
            });
          });
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
        onUndo: (): void => { void this.vm.loadData(this.vm.planId); this.setUnsavedFlag(false); },
        onSave: (): void => { this.vm.save(); this.setUnsavedFlag(false); }
      })
    }
    .width('100%')
    .height('100%')
  }
}
