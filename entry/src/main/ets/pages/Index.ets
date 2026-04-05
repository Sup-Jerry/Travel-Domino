import { CompressionMode, TimelineViewModel } from '../viewmodel/TimelineViewModel';
import { TravelPlanItem } from '../model/interface/IStandardEvent';
// 修改点：View 组件指向 views 目录
// 修改点：Dialog 组件指向 dialogs 目录
import { EventEntity } from '../model/entity/EventEntity';
import { router } from '@kit.ArkUI';
// 修改点：批量更新 Dialog 路径
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
import { PageDraftRecovery } from '../common/utils/PageDraftRecovery';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { DomainConstants } from '../common/constants/DomainConstants';
import { PlanRepositoryImpl } from '../infrastructure/persistence/PlanRepositoryImpl';
import { WeatherUserPreference } from '../domain/services/WeatherModels';
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { PlanImportExportService } from '../infrastructure/services/PlanImportExportService';
import { AddDialogDefaults, InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexEventHandlers } from './index/IndexEventHandlers';
import { IndexDialogManager } from './index/IndexDialogManager';
import { IndexAddDialogHelper } from './index/IndexAddDialogHelper';
import { IndexConflictHelper } from './index/IndexConflictHelper';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexPageLayout } from './index/IndexPageLayout';
import { IndexHelpers } from './index/IndexHelpers';

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

  // ✅ 新增：监听页面重新显示（从地图选点返回时会触发）
  onPageShow() {
    this.startArrivalReminderEngine();
    this.vm.reloadMinEventDurationLimit().catch((error: Error) => {
      const reason: string = this.sanitizeError(error);
      hilog.warn(0x0000, 'Index', `[SETTING_UI][min_duration_reload_failed] reason=${reason}`);
    });
    this.vm.reloadRouteSwitches().catch((error: Error) => {
      const reason: string = this.sanitizeError(error);
      hilog.warn(0x0000, 'Index', `[SETTING_UI][route_switch_reload_failed] reason=${reason}`);
    });

    this.refreshUnsavedFlag();
    const tempStateStr = this.readDraftStorageWithFallback(AppStorageKeys.TEMP_DIALOG_STATE);
    const pickedLocStr = this.readDraftStorageWithFallback(AppStorageKeys.PICKED_LOCATION_STR);
    const recovery = PageDraftRecovery.recover(tempStateStr, pickedLocStr);
    if (recovery.shouldClear) {
      this.clearDialogDraftStorage();
    }
    if (recovery.shouldRestore && recovery.restored) {
      this.openDialog({
        name: recovery.restored.name,
        note: recovery.restored.note,
        duration: recovery.restored.duration,
        isAnchor: recovery.restored.isAnchor,
        fixedTime: recovery.restored.fixedTime,
        dayOffset: recovery.restored.dayOffset,
        isSchedule: recovery.restored.isSchedule,
        lat: recovery.restored.lat,
        lng: recovery.restored.lng
      });
    } else if (recovery.reason === 'temp_invalid') {
      this.safeShowToast('草稿已损坏，已自动清理。');
    } else if (recovery.reason === 'picked_invalid') {
      this.safeShowToast('地图选点缓存损坏，已自动清理。');
    }

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
  // 在 Index.ets 中找到 openTimeEditDialog 方法

  // 文件路径: ets/pages/Index.ets

  openTimeEditDialog(item: EventEntity) {

    // 1. 计算基准日期 (保持不变)
    let targetDateTs = new Date().getTime();
    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    if (this.vm.planStartDate > 0) {
      targetDateTs = TimelineDatePolicy.dayOffsetToDayStartMs(this.vm.planStartDate, effectiveDayOffset);
    }

    let smartTime = '09:00';
    const currentIndex = this.vm.events.findIndex(e => e.id === item.id);

    // 1. 先确定"上一站离场时间" (Base Time)
    let prevEndTime = '09:00';
    if (currentIndex > 0) {
      const prevItem = this.vm.events[currentIndex - 1];
      const prevStart = prevItem.computed_time || prevItem.fixed_start_time || '09:00';
      prevEndTime = DateUtil.calculateEndTime(prevStart, prevItem.duration);
    } else {
      // 如果是第一个地点，假设 09:00 出发
      prevEndTime = '09:00';
    }

    // 2. 叠加当前地点的"路程时间"
    // 建议开始时间 = 上一站离场 + 路上耗时
    smartTime = DateUtil.calculateEndTime(prevEndTime, item.pre_travel_min || 0);

  }

  private handleEventConflictAction(item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number,
    onDone?: () => void) {
    const index = this.vm.events.indexOf(item);
    if (index < 0) {
      hilog.warn(0x0000, 'Index', `[CONFLICT_UI][missing_item] strategy=${strategy}, itemId=${item.id}`);
      return;
    }

    const targetTime = IndexConflictHelper.getConflictTargetTime(item);
    const saveCallback = (nextTime?: string) => {
      void IndexConflictHelper.saveConflictTime(this.vm, item, nextTime, onDone);
    };
    const reopenConflictMenu = () => {
      const latestGap = IndexConflictHelper.resolveConflictGapMinutes(item, gapMinutes);
      this.openConflictMenu(index, item, targetTime, latestGap, saveCallback);
    };

    hilog.info(
      0x0000,
      'Index',
      `[CONFLICT_UI][action] strategy=${strategy}, itemId=${item.id}, targetTime=${targetTime}, gap=${gapMinutes}`
    );

    if (strategy === 'delay') {
      const plan = this.vm.calculateDelayPlan(index);
      this.openPreview(index, item, targetTime, plan, saveCallback, reopenConflictMenu);
      return;
    }

    if (strategy === 'advance') {
      this.openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      return;
    }

    this.openCompressSelectionDialog(index, item, targetTime, saveCallback, reopenConflictMenu);
  }

  private openAdvanceAdjustDialog(index: number, item: EventEntity, targetTime: string, saveCallback: (t?: string) => void): void {
    const context = this.vm.buildAdvanceAdjustContext(index);
    if (!context || context.candidates.length === 0) {
      this.safeShowToast('当前冲突前不存在可调整区间');
      return;
    }

    this.conflictAdvanceController = IndexDialogManager.createAdvanceAdjustController({
      vm: this.vm,
      targetIndex: index,
      targetName: item.name,
      onCancel: () => {},
      onConfirm: (selectedIds: number[], nextStartTime: string) => {
        void this.vm.applyAdvanceAdjust(index, new Set<number>(selectedIds), nextStartTime).then((result) => {
          if (!result.success) {
            this.safeShowToast(result.message || '前移调整失败');
            this.openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
            return;
          }
          saveCallback(targetTime);
          if (result.remainingGapMinutes > 0) {
            this.safeShowToast(`已前移 ${result.appliedShiftMinutes} 分钟，仍有 ${result.remainingGapMinutes} 分钟冲突`);
            this.openConflictMenu(index, item, targetTime, result.remainingGapMinutes, saveCallback);
            return;
          }
          this.safeShowToast(`已前移 ${result.appliedShiftMinutes} 分钟`);
        }).catch((_error: Object) => {
          this.safeShowToast('前移调整失败');
        });
      }
    });
    this.conflictAdvanceController.open();
  }

  private showCompressionBlockedDialog(index: number, item: EventEntity, targetTime: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
    selectedIds: number[], mode: CompressionMode, saveCallback: (t?: string) => void, onBack: () => void) {
    const remain = plan.remainingGapMinutes ?? 0;
    const suggested = plan.suggestedTime || targetTime;
    this.getUIContext().showAlertDialog({
      title: '⛔ 压缩后仍冲突',
      message: `已按所选范围压缩，但仍有 ${remain} 分钟冲突。\n建议最早开始时间：${suggested}\n\n请扩大压缩范围或改为向后顺延。`,
      primaryButton: {
        value: '返回重选',
        action: () => {
          this.openCompressSelectionDialog(index, item, targetTime, saveCallback, onBack, selectedIds, mode);
        }
      },
      secondaryButton: {
        value: '改为顺延',
        action: () => {
          const delayPlan = this.vm.calculateDelayPlan(index);
          this.openPreview(index, item, targetTime, delayPlan, saveCallback, onBack);
        }
      },
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
  }

  private openCompressSelectionDialog(index: number, item: EventEntity, targetTime: string, saveCallback: (t?: string) => void,
    onBack: () => void, presetSelectedIds: number[] = [], presetMode: CompressionMode = 'RATIO') {
    const context = this.vm.buildCompressionSelectionContext(index, targetTime);
    if (!context) {
      this.safeShowToast('当前上下文无法计算压缩方案，请稍后重试');
      return;
    }
    if (context.neededGapMinutes <= 0) {
      saveCallback(targetTime);
      return;
    }

    this.conflictCompressController = IndexDialogManager.createConflictCompressController({
      vm: this.vm,
      targetIndex: index,
      targetTime: targetTime,
      targetName: item.name,
      initialMode: presetMode,
      initialSelectedIds: presetSelectedIds,
      onCancel: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][compress_dialog_cancel] itemId=${item.id}`);
      },
      onConfirm: (selectedIds: number[], mode: CompressionMode) => {
        const plan = this.vm.calculateCompressionPlanBySelection(index, targetTime, new Set<number>(selectedIds), mode);
        if (plan.status === 'NO_ACTION') {
          saveCallback(targetTime);
          return;
        }
        if (plan.status === 'OVERLOAD') {
          this.showCompressionBlockedDialog(index, item, targetTime, plan, selectedIds, mode, saveCallback, onBack);
          return;
        }
        this.openPreview(index, item, targetTime, plan, saveCallback, () => {
          this.openCompressSelectionDialog(index, item, targetTime, saveCallback, onBack, selectedIds, mode);
        });
      }
    });
    this.conflictCompressController.open();
  }

  private requestPlanDateUpdate(newDateTimestamp: number): void {
    const nextDate = new Date(newDateTimestamp);
    nextDate.setHours(0, 0, 0, 0);
    const normalizedTimestamp = nextDate.getTime();

    const preview = this.vm.previewPlanDateShift(normalizedTimestamp);
    if (!preview.hasRigidConflict) {
      hilog.info(0x0000, 'Index', `[SHIFT_UI][direct_apply] date=${normalizedTimestamp}`);
      this.vm.updatePlanDate(normalizedTimestamp);
      return;
    }

    const conflictItem = this.vm.events.find(e => e.id === preview.conflictItemId);
    if (!conflictItem) {
      hilog.warn(0x0000, 'Index', `[SHIFT_UI][fallback_apply] conflict item not found, date=${normalizedTimestamp}`);
      this.vm.updatePlanDate(normalizedTimestamp);
      return;
    }

    const conflictIndex = this.vm.events.indexOf(conflictItem);
    if (conflictIndex < 0) {
      this.vm.updatePlanDate(normalizedTimestamp);
      return;
    }

    const targetTime = IndexConflictHelper.getConflictTargetTime(conflictItem);
    const conflictGap = IndexConflictHelper.resolveConflictGapMinutes(conflictItem, preview.gapMinutes);

    hilog.warn(
      0x0000,
      'Index',
      `[SHIFT_UI][blocked_by_rigid] date=${normalizedTimestamp}, itemId=${conflictItem.id}, itemName=${conflictItem.name}, gap=${conflictGap}`
    );

    this.openConflictMenu(
      conflictIndex,
      conflictItem,
      targetTime,
      conflictGap,
      (suggestedTime?: string) => {
        void IndexConflictHelper.saveConflictTime(this.vm, conflictItem, suggestedTime, async () => {
          await this.vm.updatePlanDate(normalizedTimestamp);
        });
      }
    );
  }

  openConflictMenu(index: number, item: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void) {
    hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_open] index=${index}, itemId=${item.id}, targetTime=${targetTime}, gap=${gap}`);
    this.conflictSelectionController = IndexDialogManager.createConflictSelectionController({
      gapMinutes: gap,
      onDelayY: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_delay] itemId=${item.id}`);
        const plan = this.vm.calculateDelayPlan(index);
        this.openPreview(index, item, targetTime, plan, saveCallback, () => {
          this.openConflictMenu(index, item, targetTime, gap, saveCallback);
        });
      },
      onCompressX: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_compress] itemId=${item.id}`);
        this.openCompressSelectionDialog(index, item, targetTime, saveCallback, () => {
          this.openConflictMenu(index, item, targetTime, gap, saveCallback);
        });
      },
      onAdvanceAdjust: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_advance_adjust] itemId=${item.id}`);
        this.openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      },
      onShiftSameDay: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_shift_same_day_compat] itemId=${item.id}`);
        this.openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      },
      onSmartAdjust: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_smart] itemId=${item.id}`);
        this.openCompressSelectionDialog(index, item, targetTime, saveCallback, () => {
          this.openConflictMenu(index, item, targetTime, gap, saveCallback);
        });
      }
    });
    this.conflictSelectionController.open();
  }

  private async initBacklogExpandedState(planId: number, isNewPlan: boolean): Promise<void> {
    this.backlogExpanded = await IndexStateManager.initBacklogExpandedState(planId, isNewPlan);
  }

  // [新增] 抽离出来的预览逻辑
  openPreview(index: number, item: EventEntity, targetTime: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan, saveCallback: (t?: string) => void, onBack: () => void) {

    // 构建详情文本
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

    // ✅ 准备 Priority 数据
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

  // ✅ [修复步骤 2] 修改打开菜单的方法
  openSettingsDialog() {
    this.settingsDialogController = IndexDialogManager.createSettingsController({
      onRename: () => {
        setTimeout((): void => this.openRenameDialog(), 100);
      },
      onReschedule: () => {
        setTimeout(() => {
          IndexDialogManager.openPlanDatePicker(
            this.getUIContext(),
            this.vm.planStartDate,
            (dateMs: number) => {
              this.requestPlanDateUpdate(dateMs);
            }
          );
        }, 100);
      },
      onShare: () => {
        setTimeout((): void => {
          void this.openShareDialog();
        }, 100);
      },
      weatherUserPreference: this.vm.getWeatherUserPreference(),
      onWeatherPreferenceChange: async (preference: WeatherUserPreference) => {
        try {
          await this.vm.updateWeatherUserPreference(preference);
          if (this.vm.isWeatherFeatureEnabled()) {
            void this.vm.refreshPlanningWeather(false);
          }
          if (this.vm.isWeatherFeatureEnabled() && this.vm.isExecutionWeatherStage()) {
            void this.vm.refreshExecutionWeather(false, 'MANUAL');
          }
        } catch (_error) {
          this.safeShowToast('天气偏好保存失败');
        }
      }
    });

    this.settingsDialogController.open();
  }

  private async openShareDialog(): Promise<void> {
    if (this.currentPlanId <= 0) {
      this.safeShowToast('当前计划无效，无法分享');
      return;
    }
    try {
      const compressedJson = await PlanImportExportService.exportPlanToJson(this.currentPlanId);
      const scheduleEvents = this.vm.events.filter((item: EventEntity) => item.status === 1);
      const totalEvents = scheduleEvents.length;
      const dayOffsets = scheduleEvents.map((item: EventEntity) => TimelineDatePolicy.resolveEventDayOffset(item));
      const maxDayOffset = dayOffsets.length > 0 ? Math.max(...dayOffsets) : 0;
      const startDate = this.vm.planStartDate > 0 ? this.vm.planStartDate : Date.now();
      const endDate = TimelineDatePolicy.dayOffsetToDayStartMs(startDate, maxDayOffset);
      const totalDays = Math.max(1, maxDayOffset + 1);
      this.shareDialogController = IndexDialogManager.createShareController({
        planId: this.currentPlanId,
        planTitle: this.planTitle,
        startDate: startDate,
        endDate: endDate,
        totalDays: totalDays,
        totalEvents: totalEvents,
        compressedJson: compressedJson
      });
      this.shareDialogController.open();
    } catch (_error) {
      this.safeShowToast('分享数据生成失败，请稍后重试');
    }
  }

  // [Priority 2 新增] 打开重命名弹窗
  openRenameDialog() {
    this.dialogController = IndexDialogManager.createRenameController(this.planTitle, (newName: string) => {
      this.planTitle = newName;
      this.vm.renamePlan(newName);
    });
    this.dialogController.open();
  }

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (params && params['planId']) {
      const planId = params['planId'] as number;
      const isNewPlan = (params['isNewPlan'] as boolean) === true;
      const autoStartFromReminder = (params['autoStartFromReminder'] as boolean) === true;
      const forceCompanionMode = (params['forceCompanionMode'] as boolean) === true;
      const reminderEventId = Number(params['reminderEventId'] as number) || -1;

      this.currentPlanId = planId;
      this.hasManualPlanningWeatherRefresh = false;
      this.vm.setHasUnsavedPostponeStorageKey(
        IndexStateManager.scopedStorageKey(AppStorageKeys.HAS_UNSAVED_POSTPONE, this.currentPlanId)
      );
      this.refreshUnsavedFlag();
      this.planTitle = params['title'] as string || '行程详情';
      this.bindReminderSubscriptions();
      void this.vm.loadData(planId).then(() => {
        this.strategyMode = this.vm.getStrategyMode();
        this.loadStrategyExplanation();
        if (this.vm.isWeatherFeatureEnabled()) {
          if (this.vm.shouldAutoRefreshPlanningWeather()) {
            void this.vm.refreshPlanningWeather(false);
          }
        } else {
          this.vm.stopExecutionWeatherScheduler();
        }
        if (autoStartFromReminder && reminderEventId > 0) {
          this.isCompanionMode = true;
          void this.tryStartEventWithConflictPrompt(reminderEventId);
        } else if (forceCompanionMode) {
          this.isCompanionMode = true;
        }
        this.startArrivalReminderEngine();
        this.startStrategyAdaptationCheck();
      }).catch((error: Error) => {
        hilog.error(0x0000, 'Index', `[ARRIVAL][load_data_failed] reason=${this.sanitizeError(error)}`);
      });

      this.initBacklogExpandedState(planId, isNewPlan);
    } else {
      console.error('Index page loaded without Plan ID');
    }
  }

  aboutToDisappear() {
    this.unbindReminderSubscriptions();
    this.planService.stopArrivalEngine();
    this.vm.stopExecutionWeatherScheduler();
    this.vm.unbindPlanState();
    this.clearDialogDraftStorage();
    if (this.strategyAdaptationCheckTimer !== -1) {
      clearInterval(this.strategyAdaptationCheckTimer);
      this.strategyAdaptationCheckTimer = -1;
    }
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

    // 立即清空，防止重复弹窗
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
        action: () => {
          // 已清空，无需操作
        }
      }
    });
  }

  private handleMoveToBacklogFromTimeline(item: EventEntity): void {
    if (item.status !== 1) {
      this.safeShowToast('该地点不在日程表中');
      return;
    }
    void this.vm.moveToBacklog(item);
  }

  private confirmDeleteTimelineEvent(item: EventEntity): void {
    this.getUIContext().showAlertDialog({
      title: '确认删除',
      message: `确定要删除 "${item.name}" 吗？\n删除后无法恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.White,
        backgroundColor: '#2F7DFF',
        action: () => {
          this.vm.hardDelete(item);
        }
      }
    });
  }

  openEditDialog(item: EventEntity) {
    const coordValid = Number.isFinite(item.latitude) && Number.isFinite(item.longitude) &&
      Math.abs(item.latitude) <= 90 && Math.abs(item.longitude) <= 180 &&
      !(item.latitude === 0 && item.longitude === 0);
    hilog.info(
      0x0000,
      'Index',
      `[MAP_TRACE][edit_entry] itemId=${item.id}, source=${item.source}, nameLen=${(item.name || '').length}, coordValid=${coordValid}, lat=${item.latitude}, lng=${item.longitude}`
    );
    this.editingItemId = item.id;
    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    this.openDialog({
      name: item.name,
      note: item.note,
      duration: item.duration,
      isAnchor: item.lock_status === 1,
      fixedTime: item.fixed_start_time || '',
      dayOffset: effectiveDayOffset || 0,
      lat: item.latitude,
      lng: item.longitude
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
          this.openEditDialog(item);
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
          this.handleMoveToBacklogFromTimeline(item);
        },
        onConfirmDeleteEvent: (item: EventEntity) => {
          this.confirmDeleteTimelineEvent(item);
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
