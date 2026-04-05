import { CompressionMode, TimelineViewModel } from '../viewmodel/TimelineViewModel';
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { EventEntity } from '../model/entity/EventEntity';
import { router } from '@kit.ArkUI';
import { DateUtil } from '../common/utils/DateUtil';
import { promptAction } from '@kit.ArkUI';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';
import { StrategyService } from '../domain/strategy/StrategyService';

import { TimelineInteractionHelper } from '../viewmodel/TimelineInteractionHelper';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { NavigationHelper } from '../common/utils/NavigationHelper';
import { WeatherReminderCoordinator } from '../infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload } from '../common/utils/weather/WeatherReminderStore';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { TimelineDatePolicy } from '../domain/policy/TimelineDatePolicy';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { DomainConstants } from '../common/constants/DomainConstants';
import { PlanRepositoryImpl } from '../infrastructure/persistence/PlanRepositoryImpl';
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { AddDialogDefaults, InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexEventHandlers } from './index/IndexEventHandlers';
import { IndexDialogManager } from './index/IndexDialogManager';
import { IndexAddDialogHelper } from './index/IndexAddDialogHelper';
import { IndexConflictHelper } from './index/IndexConflictHelper';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexPageLayout } from './index/IndexPageLayout';
import { IndexHelpers } from './index/IndexHelpers';
import { IndexSettingsFlowHelper } from './index/IndexSettingsFlowHelper';
import { IndexLifecycleHelper } from './index/IndexLifecycleHelper';
import { IndexPageShowHelper } from './index/IndexPageShowHelper';
import { IndexTimelineActionHelper } from './index/IndexTimelineActionHelper';

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
  shareDialogController: CustomDialogController | null = null;

  onTrafficSignal() {
    hilog.info(0x0000, 'Index', '收到高德数据更新信号，触发 UI 重算');
    this.vm.recalculateTrafficOnly(); // 路况回填走轻量重算，避免全量重算风暴
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
    this.hasUnsavedChanges = IndexStateManager.setUnsavedFlag(this.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE, value);
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

  private showWeatherReminderDialog(payload: WeatherReminderPayload): void {
    this.isWeatherDialogOpen = true;
    const dialogTitle = payload.suggestionId ? `天气建议（可选）· ${payload.title}` : `天气提醒（可选）· ${payload.title}`;
    const affectedText = payload.affectedNodes && payload.affectedNodes.length > 0
      ? `\n受影响节点：${payload.affectedNodes.join('、')}`
      : '';
    const reasonText = payload.reason ? `\n原因：${payload.reason}` : '';
    const benefitText = payload.expectedBenefit ? `\n收益：${payload.expectedBenefit}` : '';
    const durationText = Number.isFinite(payload.suggestedDurationMin)
      ? `\n建议停留：约 ${payload.suggestedDurationMin} 分钟`
      : '';
    const strategyAdjustText = payload.strategyAdjustment
      ? `\n策略调整预览：密度${payload.strategyAdjustment.density ?? 0}，节奏${payload.strategyAdjustment.pace ?? 0}，体力${payload.strategyAdjustment.energy ?? 0}`
      : '';
    const dialogMessage = payload.suggestionId
      ? `${payload.message}${reasonText}${benefitText}${affectedText}${durationText}${payload.strategyHint ? `\n策略建议：${payload.strategyHint}` : ''}${strategyAdjustText}\n\n此建议基于多日/多城天气协同，属可选动作，不会自动执行。`
      : `${payload.message}\n\n你可以选择刷新天气，不影响主流程。`;
    this.getUIContext().showAlertDialog({
      title: dialogTitle,
      message: dialogMessage,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: payload.suggestionId ? '稍后处理' : '知道了',
        action: () => {
          this.isWeatherDialogOpen = false;
          this.weatherCoordinator.clear(this.currentPlanId);
        }
      },
      secondaryButton: {
        value: payload.suggestionId ? '去伴游' : '刷新天气',
        action: () => {
          this.isWeatherDialogOpen = false;
          this.weatherCoordinator.clear(this.currentPlanId);
          if (payload.suggestionId) {
            hilog.info(
              0x0000,
              'Index',
              `[WEATHER_REPLAN][dialog_view_only] planId=${this.currentPlanId}, suggestionId=${payload.suggestionId}, actionType=${payload.actionType ?? 'NONE'}`
            );
            this.isCompanionMode = true;
            this.safeShowToast('已进入伴游，请先查看建议，确认后再应用');
          } else {
            void this.vm.refreshExecutionWeather(true, 'MANUAL');
          }
        }
      }
    });
  }

  private showArrivalReminderDialog(payload: ArrivalReminderPayload): void {
    this.isArrivalDialogOpen = true;
    this.getUIContext().showAlertDialog({
      title: '到达提醒',
      message: `你已到达【${payload.placeName}】附近（约${Math.max(1, payload.distanceMeters)}米）`,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '稍后',
        action: () => {
          this.isArrivalDialogOpen = false;
          this.arrivalCoordinator.acknowledge(payload.eventId, 'dismiss');
        }
      },
      secondaryButton: {
        value: '开始打卡',
        action: () => {
          this.isArrivalDialogOpen = false;
          void this.tryStartEventWithConflictPrompt(payload.eventId).then((started: boolean) => {
            this.arrivalCoordinator.acknowledge(payload.eventId, started ? 'start' : 'dismiss');
          }).catch(() => {
            this.arrivalCoordinator.acknowledge(payload.eventId, 'dismiss');
          });
        }
      }
    });
  }

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  gapDialogController: CustomDialogController | null = IndexDialogManager.createGapResolutionController({
    vm: this.vm,
    currentGap: this.gapItem
  });


  conflictDialogController: CustomDialogController = IndexDialogManager.createDateConflictController({
    conflictDateStr: this.pendingItem ? DateUtil.formatDate(new Date(this.pendingItem.targetDateMs), 'MM月dd日') : '',
    planStartDateStr: DateUtil.formatDate(new Date(this.vm.planStartDate), 'MM月dd日'),
    planStartDate: this.vm.planStartDate,
    onChangeItemDate: () => {
      if (this.pendingItem) {
        setTimeout(() => {
          this.getUIContext().showDatePickerDialog({
            start: new Date(this.vm.planStartDate),
            end: new Date("2100-12-31"),
            selected: new Date(this.vm.planStartDate),
            onAccept: (value: DatePickerResult) => {
              const newSelectedDate = new Date();
              newSelectedDate.setFullYear(value.year, value.month, value.day);
              const newOffset = TimelineDatePolicy.timestampToDayOffset(this.vm.planStartDate, newSelectedDate.getTime());

              if (this.pendingItem) {
                if (this.pendingItem.id !== -1) {
                  this.vm.updateEventInfo(
                    this.pendingItem.id,
                    this.pendingItem.name,
                    this.pendingItem.duration,
                    this.pendingItem.fixedTime,
                    newOffset,
                    false,
                    this.pendingItem.note
                  );
                } else {
                  this.vm.addNewItem(this.pendingItem.name, this.pendingItem.duration, true, this.pendingItem.fixedTime, newOffset, -1, false,
                    this.pendingItem.note);
                }
                this.pendingItem = null;
                this.safeShowToast("已更新日期并移至日程");
              }
            },
            onCancel: () => {
              console.info("DatePicker cancelled, returning to ConflictDialog");
              this.conflictDialogController.open();
            }
          })
        }, 200);
      }
    },
    onMoveToBacklog: () => {
      if (this.pendingItem) {
        this.vm.resolveConflictByBacklog(
          this.pendingItem.id,
          this.pendingItem.name,
          this.pendingItem.duration,
          this.pendingItem.note
        );
        this.pendingItem = null;
        this.safeShowToast("已移至暂存池");
      }
    },
    onChangePlanStartDate: () => {
      if (this.pendingItem) {
        this.vm.resolveConflictByMovingPlan(
          this.pendingItem.id,
          this.pendingItem.targetDateMs,
          this.pendingItem.name,
          this.pendingItem.duration,
          this.pendingItem.isSchedule,
          this.pendingItem.fixedTime,
          this.pendingItem.note
        );
        this.pendingItem = null;
        this.safeShowToast("计划出发日期已更新");
      }
    },
    onCancel: () => {
      if (this.pendingItem) {
        console.info("Conflict handling cancelled, returning to AddItemDialog");
        const data = this.pendingItem;
        this.openDialog({
          name: data.name,
          note: data.note,
          duration: data.duration,
          isAnchor: false,
          fixedTime: data.fixedTime || '',
          dayOffset: data.dayOffset,
          isSchedule: data.isSchedule
        });
        this.pendingItem = null;
      }
    }
  })

  onPageShow() {
    IndexPageShowHelper.handlePageShow({
      vm: this.vm,
      onStartArrivalReminderEngine: () => {
        this.startArrivalReminderEngine();
      },
      onRefreshUnsavedFlag: () => {
        this.refreshUnsavedFlag();
      },
      onReadDraftStorage: (key: string) => {
        return this.readDraftStorageWithFallback(key);
      },
      onClearDraftStorage: () => {
        this.clearDialogDraftStorage();
      },
      onOpenDialog: (initData?: InitDialogData) => {
        this.openDialog(initData);
      },
      onSafeToast: (message: string) => {
        this.safeShowToast(message);
      },
      onSanitizeError: (error: Object) => {
        return this.sanitizeError(error);
      }
    });
  }


  private onGapFoundCallback = (item: EventEntity) => {}

  aiDialogController: CustomDialogController = IndexDialogManager.createAiDialogController({
    hasAiHistory: this.vm.hasAiHistory(),
    onConfirm: async (text: string, strategy: number, customStrategy?: ComposableStrategy) => {
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
    onRegenerate: async () => {
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
  openTimeEditDialog(item: EventEntity) {
    let targetDateTs = new Date().getTime();
    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    if (this.vm.planStartDate > 0) {
      targetDateTs = TimelineDatePolicy.dayOffsetToDayStartMs(this.vm.planStartDate, effectiveDayOffset);
    }

    let smartTime = '09:00';
    const currentIndex = this.vm.events.findIndex(e => e.id === item.id);

    let prevEndTime = '09:00';
    if (currentIndex > 0) {
      const prevItem = this.vm.events[currentIndex - 1];
      const prevStart = prevItem.computed_time || prevItem.fixed_start_time || '09:00';
      prevEndTime = DateUtil.calculateEndTime(prevStart, prevItem.duration);
    } else {
      prevEndTime = '09:00';
    }
    smartTime = DateUtil.calculateEndTime(prevEndTime, item.pre_travel_min || 0);

  }

  private handleEventConflictAction(item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number,
    onDone?: () => void) {
    IndexConflictHelper.handleEventConflictAction(
      this.vm,
      item,
      strategy,
      gapMinutes,
      onDone,
      (index: number, target: EventEntity, targetTime: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        saveCallback: (t?: string) => void, onBack: () => void) => {
        this.openPreview(index, target, targetTime, plan, saveCallback, onBack);
      },
      (index: number, target: EventEntity, targetTime: string, saveCallback: (t?: string) => void) => {
        this.openAdvanceAdjustDialog(index, target, targetTime, saveCallback);
      },
      (index: number, target: EventEntity, targetTime: string, saveCallback: (t?: string) => void, onBack: () => void) => {
        this.openCompressSelectionDialog(index, target, targetTime, saveCallback, onBack);
      },
      (index: number, target: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void) => {
        this.openConflictMenu(index, target, targetTime, gap, saveCallback);
      }
    );
  }

  private openAdvanceAdjustDialog(index: number, item: EventEntity, targetTime: string, saveCallback: (t?: string) => void): void {
    this.conflictAdvanceController = IndexConflictHelper.openAdvanceAdjustDialog(
      this.vm,
      index,
      item,
      targetTime,
      saveCallback,
      (message: string) => {
        this.safeShowToast(message);
      },
      () => {
        this.openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      },
      (gap: number) => {
        this.openConflictMenu(index, item, targetTime, gap, saveCallback);
      }
    );
  }

  private showCompressionBlockedDialog(index: number, item: EventEntity, targetTime: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
    selectedIds: number[], mode: CompressionMode, saveCallback: (t?: string) => void, onBack: () => void) {
    IndexConflictHelper.showCompressionBlockedDialog(
      this.getUIContext(),
      index,
      item,
      targetTime,
      plan,
      selectedIds,
      mode,
      saveCallback,
      onBack,
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void, backFn: () => void,
        ids: number[], nextMode: CompressionMode) => {
        this.openCompressSelectionDialog(indexVal, itemVal, targetTimeVal, saveFn, backFn, ids, nextMode);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, nextPlan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void) => {
        this.openPreview(indexVal, itemVal, targetTimeVal, nextPlan, saveFn, backFn);
      },
      this.vm
    );
  }

  private openCompressSelectionDialog(index: number, item: EventEntity, targetTime: string, saveCallback: (t?: string) => void,
    onBack: () => void, presetSelectedIds: number[] = [], presetMode: CompressionMode = 'RATIO') {
    this.conflictCompressController = IndexConflictHelper.openCompressSelectionDialog(
      this.vm,
      index,
      item,
      targetTime,
      saveCallback,
      onBack,
      (message: string) => {
        this.safeShowToast(message);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void) => {
        this.openPreview(indexVal, itemVal, targetTimeVal, plan, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        ids: number[], modeVal: CompressionMode, saveFn: (t?: string) => void, backFn: () => void) => {
        this.showCompressionBlockedDialog(indexVal, itemVal, targetTimeVal, plan, ids, modeVal, saveFn, backFn);
      },
      presetSelectedIds,
      presetMode
    );
  }

  private requestPlanDateUpdate(newDateTimestamp: number): void {
    IndexConflictHelper.requestPlanDateUpdate(this.vm, newDateTimestamp, (index: number, item: EventEntity, targetTime: string,
      gap: number, saveCallback: (t?: string) => void) => {
      this.openConflictMenu(index, item, targetTime, gap, saveCallback);
    });
  }

  openConflictMenu(index: number, item: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void) {
    this.conflictSelectionController = IndexConflictHelper.openConflictMenu(
      this.vm,
      index,
      item,
      targetTime,
      gap,
      saveCallback,
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void) => {
        this.openPreview(indexVal, itemVal, targetTimeVal, plan, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void, backFn: () => void) => {
        this.openCompressSelectionDialog(indexVal, itemVal, targetTimeVal, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void) => {
        this.openAdvanceAdjustDialog(indexVal, itemVal, targetTimeVal, saveFn);
      }
    );
  }

  private async initBacklogExpandedState(planId: number, isNewPlan: boolean): Promise<void> {
    this.backlogExpanded = await IndexStateManager.initBacklogExpandedState(planId, isNewPlan);
  }

  openPreview(index: number, item: EventEntity, targetTime: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan, saveCallback: (t?: string) => void, onBack: () => void) {
    let detailMsg = '';
    if (plan.affectedItems.length === 0) {
      detailMsg = '• 没有前序行程受到压缩，仅调整当前开始时间。';
    } else {
      plan.affectedItems.forEach(aff => {
        detailMsg += `• ${aff.name}: ${aff.oldVal}m ➔ ${aff.newVal}m\n`;
      });
    }

    const prevItem = index > 0 ? this.vm.events[index - 1] : null;
    const conflictName = prevItem ? prevItem.name : '前序行程';

    this.suggestionDialogController = IndexDialogManager.createSuggestionController({
      itemName: item.name,
      conflictName: conflictName,
      targetTime: targetTime,
      suggestedTime: plan.suggestedTime || targetTime,
      detailMsg: detailMsg,
      onConfirm: () => {
        if (plan.suggestedTime) {
          if (plan.affectedItems.length > 0) {
            this.vm.applyCompressionPlan(plan);
          }
          saveCallback(plan.suggestedTime);
        }
      },
      onBack: onBack
    });
    this.suggestionDialogController.open();
  }

  openDialog(initData?: InitDialogData) {
    const isCreateMode = this.editingItemId === -1;
    const createDefaults = new AddDialogDefaults();
    if (isCreateMode) {
      const computed = IndexAddDialogHelper.resolveAddDialogDefaults(this.vm.events);
      createDefaults.dayOffset = computed.dayOffset;
      createDefaults.suggestedTime = computed.suggestedTime;
    } else {
      createDefaults.dayOffset = 0;
      createDefaults.suggestedTime = '';
    }
    const smartTime = initData?.suggestedTime ||
      (isCreateMode ? createDefaults.suggestedTime : IndexAddDialogHelper.calculateSmartTime(this.vm.events, this.editingItemId));
    const initDayOffset = initData?.dayOffset !== undefined
      ? initData.dayOffset
      : (isCreateMode ? createDefaults.dayOffset : 0);
    const initLat = initData?.lat || 0;
    const initLng = initData?.lng || 0;
    const initCoordValid = Number.isFinite(initLat) && Number.isFinite(initLng) &&
      Math.abs(initLat) <= 90 && Math.abs(initLng) <= 180 &&
      !(initLat === 0 && initLng === 0);
    hilog.info(
      0x0000,
      'Index',
      `[MAP_TRACE][open_dialog] editId=${this.editingItemId}, createMode=${isCreateMode}, nameLen=${(initData?.name || '').length}, initCoordValid=${initCoordValid}, lat=${initLat}, lng=${initLng}`
    );
    let currentPreTravel = 0;

    let currentPriority = 0;

    if (this.editingItemId !== -1) {
      const item = this.vm.events.find(e => e.id === this.editingItemId);
      if (item) {
        if (item.pre_travel_min > 0) {
          currentPreTravel = item.pre_travel_min;
        }
        currentPriority = item.priority; // ✅ 获取现有优先级
      }
    }

    this.dialogController = IndexDialogManager.createAddItemController({
      initName: initData?.name || '',
      initNote: initData?.note || '',
      initDuration: initData?.duration || 60,
      initIsAnchor: initData?.isAnchor || false,
      initFixedTime: initData?.fixedTime || '',
      initSuggestedTime: smartTime,
      initIsSchedule: initData ? true : false,
      initDayOffset: initDayOffset,
      initPreTravel: currentPreTravel,
      initPriority: currentPriority,
      storageScopePlanId: this.currentPlanId,
      planStartDate: this.vm.planStartDate,
      initLat: initLat,
      initLng: initLng,
      onDateChangedRecommendTime: (dayOffset: number, currentTime: string): string => {
        if (!isCreateMode) {
          return currentTime;
        }
        return IndexAddDialogHelper.recommendAddByDayOffset(this.vm.events, dayOffset);
      },
      onConfirm: async (name, duration, isSchedule, fixedTime, dayOffset, preTravel, isHardLock, note, isMustVisit, lat, lng) => {
        const hasCoordinate = Number.isFinite(lat) && Number.isFinite(lng) && lat !== 0 && lng !== 0;
        hilog.info(0x0000, 'IndexPage', `[DIALOG_SAVE] has_coordinate=${hasCoordinate}`);
        if (this.editingItemId !== -1 && !this.vm.events.find(e => e.id === this.editingItemId)) {
          hilog.warn(0x0000, 'IndexPage', `[DIALOG_SAVE_SKIP] reason=item_not_found, itemId=${this.editingItemId}`);
          this.safeShowToast('该地点已不存在，请刷新后重试');
          this.editingItemId = -1;
          return;
        }
        if (this.vm.planStartDate <= 0 || (dayOffset !== undefined && dayOffset >= 0)) {
          await TimelineInteractionHelper.handleSaveItem(
            this.vm, this.editingItemId, name, duration, isSchedule,
            fixedTime, dayOffset, preTravel, this.onGapFoundCallback,
            isHardLock, note, isMustVisit,
            lat, lng
          );

          this.editingItemId = -1;
          return;
        }

        const targetMs = TimelineDatePolicy.dayOffsetToDayStartMs(this.vm.planStartDate, dayOffset!);

        this.pendingItem = {
          id: this.editingItemId,
          name, duration, isSchedule, fixedTime,
          dayOffset: dayOffset!,
          targetDateMs: targetMs,
          note: note || '',
          lat: lat,
          lng: lng
        };

        setTimeout(() => { this.conflictDialogController.open(); }, 100);
      }
    });
    this.dialogController.open();
  }

  openSettingsDialog() {
    this.settingsDialogController = IndexSettingsFlowHelper.openSettingsDialog({
      uiContext: this.getUIContext(),
      vm: this.vm,
      onRename: () => {
        this.openRenameDialog();
      },
      onReschedule: (dateMs: number) => {
        this.requestPlanDateUpdate(dateMs);
      },
      onShare: async () => {
        await this.openShareDialog();
      },
      onWeatherPreferenceError: () => {
        this.safeShowToast('天气偏好保存失败');
      }
    });
  }

  private async openShareDialog(): Promise<void> {
    if (this.currentPlanId <= 0) {
      this.safeShowToast('当前计划无效，无法分享');
      return;
    }
    try {
      this.shareDialogController = await IndexSettingsFlowHelper.openShareDialog({
        planId: this.currentPlanId,
        planTitle: this.planTitle,
        planStartDate: this.vm.planStartDate,
        events: this.vm.events
      });
      if (!this.shareDialogController) {
        this.safeShowToast('当前计划无效，无法分享');
      }
    } catch (_error) {
      this.safeShowToast('分享数据生成失败，请稍后重试');
    }
  }

  openRenameDialog() {
    this.dialogController = IndexSettingsFlowHelper.openRenameDialog(this.planTitle, (newName: string) => {
      this.planTitle = newName;
      this.vm.renamePlan(newName);
    });
  }

  aboutToAppear() {
    IndexLifecycleHelper.handleAboutToAppear({
      uiContext: this.getUIContext(),
      vm: this.vm,
      onSetCurrentPlanId: (planId: number) => {
        this.currentPlanId = planId;
      },
      onSetManualWeatherRefresh: (value: boolean) => {
        this.hasManualPlanningWeatherRefresh = value;
      },
      onRefreshUnsavedFlag: () => {
        this.refreshUnsavedFlag();
      },
      onSetPlanTitle: (title: string) => {
        this.planTitle = title;
      },
      onBindReminderSubscriptions: () => {
        this.bindReminderSubscriptions();
      },
      onSetStrategyMode: (mode: number) => {
        this.strategyMode = mode;
      },
      onLoadStrategyExplanation: () => {
        this.loadStrategyExplanation();
      },
      onSetCompanionMode: (value: boolean) => {
        this.isCompanionMode = value;
      },
      onTryStartEvent: async (eventId: number) => {
        return this.tryStartEventWithConflictPrompt(eventId);
      },
      onStartArrivalReminderEngine: () => {
        this.startArrivalReminderEngine();
      },
      onStartStrategyAdaptationCheck: () => {
        this.startStrategyAdaptationCheck();
      },
      onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean) => {
        await this.initBacklogExpandedState(planId, isNewPlan);
      },
      onLoadDataError: (reason: string) => {
        hilog.error(0x0000, 'Index', `[ARRIVAL][load_data_failed] reason=${reason}`);
      }
    });
  }

  aboutToDisappear() {
    IndexLifecycleHelper.handleAboutToDisappear({
      strategyAdaptationCheckTimer: this.strategyAdaptationCheckTimer,
      onUnbindReminderSubscriptions: () => {
        this.unbindReminderSubscriptions();
      },
      onStopArrivalEngine: () => {
        this.planService.stopArrivalEngine();
      },
      onStopExecutionWeatherScheduler: () => {
        this.vm.stopExecutionWeatherScheduler();
      },
      onUnbindPlanState: () => {
        this.vm.unbindPlanState();
      },
      onClearDialogDraftStorage: () => {
        this.clearDialogDraftStorage();
      },
      onSetStrategyAdaptationCheckTimer: (timer: number) => {
        this.strategyAdaptationCheckTimer = timer;
      }
    });
  }

  private loadStrategyExplanation() {
    this.currentStrategyExplanation = StrategyService.buildStrategyExplanation(this.strategyMode);
  }

  private startStrategyAdaptationCheck(): void {
    this.strategyAdaptationCheckTimer = setInterval(() => {
      if (this.vm.strategyAdaptationPrompt) {
        this.showStrategyAdaptationDialog();
      }
    }, 1000);
  }

  private showStrategyAdaptationDialog(): void {
    const prompt = this.vm.strategyAdaptationPrompt;
    if (!prompt) return;

    this.vm.strategyAdaptationPrompt = null;

    const strategyLabels = ['低', '中', '高'];
    const message = `${prompt.message}\n\n` +
      `密度：${strategyLabels[prompt.oldStrategy.density]} → ${strategyLabels[prompt.newStrategy.density]}\n` +
      `节奏：${strategyLabels[prompt.oldStrategy.pace]} → ${strategyLabels[prompt.newStrategy.pace]}\n` +
      `体力：${strategyLabels[prompt.oldStrategy.energy]} → ${strategyLabels[prompt.newStrategy.energy]}`;

    this.getUIContext().showAlertDialog({
      title: '✨ 策略已自动调整',
      message: message,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '立即生成',
        action: () => {
          void this.vm.regenerateByCurrentStrategy();
        }
      },
      secondaryButton: {
        value: '稍后',
        action: () => {}
      }
    });
  }

  build() {
    Stack() {
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
        onBack: () => {
          void NavigationHelper.backOrFallbackToPlanList(this.getUIContext());
        },
        onOpenSettings: () => {
          this.openSettingsDialog();
        },
        onEnterCompanion: () => {
          hilog.info(0x0000, 'Index', '[DUAL_MODE_ACCEPT][mode_switch][click_enter]');
          if (this.vm.isArchived) {
            this.safeShowToast('归档计划不可进入伴游');
            return;
          }
          this.isCompanionMode = true;
        },
        onRefreshWeather: () => {
          this.hasManualPlanningWeatherRefresh = true;
          void this.vm.refreshPlanningWeather(true).then(() => {
            this.safeShowToast('天气已刷新');
          }).catch((_error: Object) => {
            this.safeShowToast('天气刷新失败');
          });
        },
        onToggleHint: () => {
          this.showPlanningWeatherHintPopup = !this.showPlanningWeatherHintPopup;
        },
        onToggleScore: () => {
          this.showPlanningWeatherScorePopup = !this.showPlanningWeatherScorePopup;
        },
        onHintPopupVisibleChange: (visible: boolean) => {
          this.showPlanningWeatherHintPopup = visible;
        },
        onScorePopupVisibleChange: (visible: boolean) => {
          this.showPlanningWeatherScorePopup = visible;
        },
        onToggleBacklogExpand: () => {
          this.backlogExpanded = !this.backlogExpanded;
          IndexStateManager.persistBacklogExpanded(this.currentPlanId, this.backlogExpanded);
        },
        onMoveToSchedule: (item: TravelPlanItem) => {
          let suggestedDay = 0;
          let minCount = Number.MAX_SAFE_INTEGER;
          this.vm.groupedEvents.forEach(group => {
            if (group.events.length > 0 && group.events.length < minCount) {
              minCount = group.events.length;
              suggestedDay = group.dayOffset;
            }
          });
          const smartTime = IndexHelpers.resolveBacklogSuggestedTime(this.vm.events);
          this.editingItemId = item.id ?? -1;
          this.openDialog({
            name: item.name,
            note: item.note ?? '',
            duration: item.duration ?? 60,
            isAnchor: false,
            fixedTime: smartTime,
            dayOffset: suggestedDay,
            isSchedule: true
          });
        },
        onMoveAllToSchedule: () => {
          const movedCount = this.vm.moveAllBacklogToSchedule();
          if (movedCount > 0) {
            this.safeShowToast(`已加入日程 ${movedCount} 个地点`);
          } else {
            this.safeShowToast('暂存池暂无可加入地点');
          }
        },
        onIsDayCollapsed: (dayOffset: number) => IndexStateManager.isDayCollapsed(this.collapsedDayOffsets, dayOffset),
        onToggleDay: (dayOffset: number) => {
          this.collapsedDayOffsets = IndexStateManager.toggleDayCollapse(this.collapsedDayOffsets, dayOffset);
        },
        onScheduleRefresh: () => {
          void this.handlePagePullRefresh();
        },
        onOpenEditDialog: (item: EventEntity) => {
          this.editingItemId = item.id;
          const initData = IndexTimelineActionHelper.buildEditDialogData(item);
          this.openDialog(initData);
        },
        onOpenTimeEditDialog: (item: EventEntity) => {
          this.openTimeEditDialog(item);
        },
        onGapFound: (item: EventEntity) => {
          this.onGapFoundCallback(item);
        },
        onResolveConflictAction: (targetItem: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => {
          this.handleEventConflictAction(targetItem, strategy, gapMinutes);
        },
        onConfirmMoveToBacklog: (item: EventEntity) => {
          IndexTimelineActionHelper.handleMoveToBacklog(this.vm, item, (message: string) => {
            this.safeShowToast(message);
          });
        },
        onConfirmDeleteEvent: (item: EventEntity) => {
          IndexTimelineActionHelper.confirmDeleteTimelineEvent(this.getUIContext(), this.vm, item);
        },
        onOpenGapOptimize: () => {
          this.gapItem = null;
          this.gapDialogController?.open();
        },
        onFilter: () => {
          IndexEventHandlers.handleFilter(() => {
            this.dateFilterController = IndexDialogManager.openDateFilterDialog(
              this.getUIContext(),
              this.vm.planStartDate,
              {
                onShowAll: () => {
                  this.vm.clearFilter();
                },
                onSelectDate: (dateMs: number) => {
                  this.vm.setFilter(dateMs, dateMs);
                },
                onSelectRange: (startMs: number, endMs: number) => {
                  this.vm.setFilter(startMs, endMs);
                }
              }
            );
          });
        },
        onAi: () => {
          IndexEventHandlers.handleAiSuggestion(
            this.vm.isArchived,
            () => {
              this.safeShowToast('归档计划不可操作');
            },
            () => {
              this.aiDialogController.open();
            }
          );
        },
        onAdd: () => {
          IndexEventHandlers.handleAddItem(
            this.vm.isArchived,
            () => {
              this.safeShowToast('归档计划不可操作');
            },
            () => {
              this.editingItemId = -1;
              this.openDialog();
            }
          );
        },
        onUndo: () => {
          this.vm.loadData(this.vm.planId);
          this.setUnsavedFlag(false);
        },
        onSave: () => {
          this.vm.save();
          this.setUnsavedFlag(false);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
