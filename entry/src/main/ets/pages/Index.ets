import { CompressionMode, TimelineViewModel } from '../viewmodel/TimelineViewModel';
// 修改点：View 组件指向 views 目录
import { EventItemView } from './components/views/EventItemView';
import { BacklogView } from './components/views/BacklogView';
// 修改点：Dialog 组件指向 dialogs 目录
import { AddItemDialog } from './components/dialogs/AddItemDialog';
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { EventEntity } from '../model/entity/EventEntity';
import { router } from '@kit.ArkUI';
// 修改点：批量更新 Dialog 路径
import { DateUtil } from '../common/utils/DateUtil';
import { promptAction } from '@kit.ArkUI';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';
import { StrategyService } from '../domain/strategy/StrategyService';

import { TimelineInteractionHelper } from '../viewmodel/TimelineInteractionHelper';
import { CompanionView } from './components/views/CompanionView';
import { PlanBottomActionBar } from './components/views/BottomNavBar';
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
import { IndexPageLayout } from './index/IndexPageLayout';
import { IndexEventHandlers } from './index/IndexEventHandlers';
import { AddDialogDefaults, InitDialogData, PendingItemData } from './index/IndexTypes';
import { IndexStateManager } from './index/IndexStateManager';
import { IndexLifecycleHelper } from './index/IndexLifecycleHelper';
import { IndexDialogManager } from './index/IndexDialogManager';
import { IndexAddDialogHelper } from './index/IndexAddDialogHelper';
import { IndexConflictHelper } from './index/IndexConflictHelper';

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


  // Index.ets 约 118 行开始替换
  conflictDialogController: CustomDialogController = IndexDialogManager.createDateConflictController({
      // 显示给用户看的冲突详情
      conflictDateStr: this.pendingItem ? DateUtil.formatDate(new Date(this.pendingItem.targetDateMs), 'MM月dd日') : '',
      planStartDateStr: DateUtil.formatDate(new Date(this.vm.planStartDate), 'MM月dd日'),
      planStartDate: this.vm.planStartDate,

      // 选项 1: 更改地点日期 (拉起 DatePicker -> 选好后直接入库)
      onChangeItemDate: () => {
        if (this.pendingItem) {
          // 延迟一会儿弹出，避免弹窗冲突
          setTimeout(() => {
            this.getUIContext().showDatePickerDialog({
              start: new Date(this.vm.planStartDate),
              end: new Date("2100-12-31"),
              selected: new Date(this.vm.planStartDate),
              onAccept: async (value: DatePickerResult) => {
                // 1. 计算新的 DayOffset
                const newSelectedDate = new Date();
                newSelectedDate.setFullYear(value.year, value.month, value.day);
                const newOffset = TimelineDatePolicy.timestampToDayOffset(this.vm.planStartDate, newSelectedDate.getTime());

                // 2. 直接保存并入库
                if (this.pendingItem) {
                  if (this.pendingItem.id !== -1) {
                    // ✨ 关键点：如果是从已有项移动来的，调用更新
                    await this.vm.updateEventInfo(
                      this.pendingItem.id,
                      this.pendingItem.name,
                      this.pendingItem.duration,
                      this.pendingItem.fixedTime,
                      newOffset,
                      false,
                      this.pendingItem.note
                    );
                  } else {
                    // 只有确实是全新添加的，才调用新增
                    await this.vm.addNewItem(this.pendingItem.name, this.pendingItem.duration, true, this.pendingItem.fixedTime, newOffset, -1, false, this.pendingItem.note);
                  }
                  this.pendingItem = null;
                  this.safeShowToast("已更新日期并移至日程");
                }
              },
              onCancel: () => {
                console.info("DatePicker cancelled, returning to ConflictDialog");
                // 重新拉起冲突解决弹窗，让用户选别的选项（比如改主计划或入池）
                this.conflictDialogController.open();
              }
            })
          }, 200);
        }
      },


      // 选项 2: 放入暂存池 (清洗数据)
      onMoveToBacklog: async () => {
        if (this.pendingItem) {
          // 调用 VM 中刚写好的清洗方法
          await this.vm.resolveConflictByBacklog(
            this.pendingItem.id,       // ✨ 必须把 id 作为第一个参数传进去
            this.pendingItem.name,
            this.pendingItem.duration,
            this.pendingItem.note
          );
          this.pendingItem = null;
          this.safeShowToast("已移至暂存池");
        }
      },

      // 选项 3: 更改计划出发日期 (整体平移)
      onChangePlanStartDate: async () => {
        if (this.pendingItem) {
          // 调用平移方法
          await this.vm.resolveConflictByMovingPlan(
            this.pendingItem.id,             // ✨ 同样，id 必须是第一个参数
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
            isAnchor: false, // 可根据需要保持或设为默认
            fixedTime: data.fixedTime || '',
            dayOffset: data.dayOffset,
            isSchedule: data.isSchedule
          });
          // 只有回到 AddItemDialog 且用户再次点取消，或者成功保存后，pendingItem 才最终销毁
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

  private calculateSmartTime(targetItemId: number): string {
    return IndexAddDialogHelper.calculateSmartTime(this.vm.events, targetItemId);
  }

  private getDefaultAddTime(): string {
    return '08:00';
  }

  private normalizeTimeText(raw?: string): string {
    const pure = DateUtil.extractPureTime(raw || '');
    if (pure && DateUtil.isValidTimeString(pure)) {
      return pure;
    }
    return this.getDefaultAddTime();
  }

  private resolveEventEndTimeText(event: EventEntity): string {
    const start = this.normalizeTimeText(event.fixed_start_time || event.computed_time);
    const duration = Number.isFinite(event.duration) && event.duration > 0 ? event.duration : 0;
    return DateUtil.calculateEndTime(start, duration);
  }

  private getLatestCreatedScheduleEvent(): EventEntity | undefined {
    const scheduled = this.vm.events.filter((item: EventEntity) => item.status === 1);
    if (scheduled.length === 0) {
      return undefined;
    }
    const sorted = scheduled.slice().sort((a: EventEntity, b: EventEntity) => {
      const idA = Number.isFinite(a.id) ? a.id : -1;
      const idB = Number.isFinite(b.id) ? b.id : -1;
      return idB - idA;
    });
    return sorted[0];
  }

  private recommendAddByDayOffset(dayOffset: number): string {
    return IndexAddDialogHelper.recommendAddByDayOffset(this.vm.events, dayOffset);
  }

  private resolveAddDialogDefaults(): AddDialogDefaults {
    return IndexAddDialogHelper.resolveAddDialogDefaults(this.vm.events);
  }
  private resolveConflictGapMinutes(item: EventEntity, fallbackGap: number = 0): number {
    return IndexConflictHelper.resolveConflictGapMinutes(item, fallbackGap);
  }

  private getConflictTargetTime(item: EventEntity): string {
    return IndexConflictHelper.getConflictTargetTime(item);
  }

  private async saveConflictTime(item: EventEntity, newTime?: string, onDone?: () => Promise<void> | void): Promise<void> {
    await IndexConflictHelper.saveConflictTime(this.vm, item, newTime, onDone);
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
      (message: string): void => {
        this.safeShowToast(message);
      },
      (): void => {
        this.openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      },
      (gap: number): void => {
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
        presetSelectedIds: number[], presetMode: CompressionMode) => {
        this.openCompressSelectionDialog(indexVal, itemVal, targetTimeVal, saveFn, backFn, presetSelectedIds, presetMode);
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
      (message: string) => this.safeShowToast(message),
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void) => {
        this.openPreview(indexVal, itemVal, targetTimeVal, plan, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan,
        selectedIds: number[], mode: CompressionMode, saveFn: (t?: string) => void, backFn: () => void) => {
        this.showCompressionBlockedDialog(indexVal, itemVal, targetTimeVal, plan, selectedIds, mode, saveFn, backFn);
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

  // [新增] 抽离出来的预览逻辑
  openPreview(index: number, item: EventEntity, targetTime: string, plan: import('../viewmodel/TimelineViewModel').CompressionPlan, saveCallback: (t?: string) => void, onBack: () => void) {
    const detailMsg = plan.affectedItems.length === 0
      ? '• 没有前序行程受到压缩，仅调整当前开始时间。'
      : plan.affectedItems.map((aff) => `• ${aff.name}: ${aff.oldVal}m ➔ ${aff.newVal}m`).join('\n');
    const prevItem = index > 0 ? this.vm.events[index - 1] : null;
    this.suggestionDialogController = IndexDialogManager.createSuggestionController({
      itemName: item.name,
      conflictName: prevItem ? prevItem.name : '前序行程',
      targetTime: targetTime,
      suggestedTime: plan.suggestedTime || targetTime,
      detailMsg: detailMsg,
      onConfirm: (): void => {
        if (!plan.suggestedTime) {
          return;
        }
        if (plan.affectedItems.length > 0) {
          this.vm.applyCompressionPlan(plan);
        }
        saveCallback(plan.suggestedTime);
      },
      onBack: onBack
    });
    this.suggestionDialogController.open();
  }

  private findLeastBusyDay(): number {
    if (this.vm.groupedEvents.length === 0) return 0;

    // 简单逻辑：找出事件数量最少的组
    // 进阶逻辑：找出总时长最短的组 (这里先用数量)
    let minDay = 0;
    let minCount = Number.MAX_SAFE_INTEGER;

    this.vm.groupedEvents.forEach(group => {
      if (group.events.length > 0 && group.events.length < minCount) {
        minCount = group.events.length;
        minDay = group.dayOffset;
      }
    });
    return minDay;
  }

  openDialog(initData?: InitDialogData) {
    const isCreateMode = this.editingItemId === -1;
    const createDefaults = new AddDialogDefaults();
    if (isCreateMode) {
      const computed = this.resolveAddDialogDefaults();
      createDefaults.dayOffset = computed.dayOffset;
      createDefaults.suggestedTime = computed.suggestedTime;
    } else {
      createDefaults.dayOffset = 0;
      createDefaults.suggestedTime = '';
    }
    const smartTime = initData?.suggestedTime || (isCreateMode ? createDefaults.suggestedTime : this.calculateSmartTime(this.editingItemId));
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

    this.dialogController = new CustomDialogController({
      builder: AddItemDialog({
        initName: initData?.name || '',
        initNote: initData?.note || '',
        initDuration: initData?.duration || 60,
        initIsAnchor: initData?.isAnchor || false,
        initFixedTime: initData?.fixedTime || '',
        initSuggestedTime: smartTime,
        initIsSchedule: initData ? true : false,
        initDayOffset: initDayOffset,
        initPreTravel: currentPreTravel,
        initPriority: currentPriority, // ✅ 传入
        storageScopePlanId: this.currentPlanId,
        planStartDate: this.vm.planStartDate,

        initLat: initLat, // ✅ 确保把坐标传给弹窗
        initLng: initLng,
        onDateChangedRecommendTime: (dayOffset: number, currentTime: string): string => {
          if (!isCreateMode) {
            return currentTime;
          }
          return this.recommendAddByDayOffset(dayOffset);
        },

        // ✅ [核心拦截逻辑] 更新回调签名
        // ✅ 增加 lat, lng 接收参数
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
              lat, lng // ✅ 传给下一步 Helper
            );
            if (isSchedule) {
              const targetDayOffset = dayOffset ?? 0;
              const collapsedIdx = this.collapsedDayOffsets.indexOf(targetDayOffset);
              if (collapsedIdx >= 0) {
                this.collapsedDayOffsets.splice(collapsedIdx, 1);
                this.collapsedDayOffsets = [...this.collapsedDayOffsets];
              }
              if (this.vm.filterStart > 0 || this.vm.filterEnd > 0) {
                this.vm.clearFilter();
                hilog.info(0x0000, 'IndexPage', '[ADD_UI][clear_filter_for_visibility] reason=new_schedule_item');
              }
            }
            this.vm.refreshTimelineView();
            const scheduleCount = this.vm.events.filter((event: EventEntity) => event.status === 1).length;
            hilog.info(
              0x0000,
              'IndexPage',
              `[ADD_UI][after_save] total=${this.vm.events.length}, schedule=${scheduleCount}, groups=${this.vm.groupedEvents.length}, dayOffset=${dayOffset ?? 0}, isSchedule=${isSchedule}`
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
            lat: lat, // ✅ 暂存起来，应对日期冲突的情况
            lng: lng
          };

          setTimeout(() => { this.conflictDialogController.open(); }, 100);
        }
      }),
      alignment: DialogAlignment.Center,
      offset: { dx: 0, dy: -50 }, // 稍微向上偏移 50vp
      autoCancel: true,
      customStyle: true
    });
    this.dialogController.open();
  }


  // ✅ [修改] 打开高颜值筛选弹窗 (支持范围选择)
  openDateFilterDialog() {
    this.dateFilterController = IndexDialogManager.openDateFilterDialog(
      this.getUIContext(),
      this.vm.planStartDate,
      {
        onShowAll: (): void => {
          this.vm.clearFilter();
        },
        onSelectDate: (dateMs: number): void => {
          this.vm.setFilter(dateMs, dateMs);
        },
        onSelectRange: (startMs: number, endMs: number): void => {
          this.vm.setFilter(startMs, endMs);
        }
      }
    );
  }

  // [新增] 提取日期选择逻辑
  openDatePicker() {
    IndexDialogManager.openPlanDatePicker(this.getUIContext(), this.vm.planStartDate, (dateMs: number): void => {
      this.requestPlanDateUpdate(dateMs);
    });
  }

  // ✅ [修复步骤 2] 修改打开菜单的方法
  openSettingsDialog() {
    this.settingsDialogController = IndexDialogManager.createSettingsController({
      onRename: (): void => {
        setTimeout((): void => this.openRenameDialog(), 100);
      },
      onReschedule: (): void => {
        setTimeout((): void => this.openDatePicker(), 100);
      },
      onShare: (): void => {
        this.safeShowToast('分享功能暂不可用');
      },
      weatherUserPreference: this.vm.getWeatherUserPreference(),
      onWeatherPreferenceChange: async (preference: WeatherUserPreference): Promise<void> => {
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

  // [Priority 2 新增] 打开重命名弹窗
  openRenameDialog() {
    this.dialogController = IndexDialogManager.createRenameController(this.planTitle, (newName: string): void => {
      this.planTitle = newName;
      this.vm.renamePlan(newName);
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

  @Builder
  SwipeEndAction(item: EventEntity) {
    Button({ type: ButtonType.Normal }) {
      Text('暂存') // 改名为暂存更贴切
        .fontSize(14).fontColor(Color.White)
    }
    .width(60).height('100%')
    .backgroundColor('#FF9800') // 橙色
    .onClick(async () => {
      if (item.status !== 1) {
        this.safeShowToast('该地点不在日程表中');
        return;
      }
      try {
        await this.vm.moveToBacklog(item);
        this.vm.refreshTimelineView();
      } catch (_error) {
        this.safeShowToast('暂存失败，请重试');
      }
    })
  }

  @Builder
  SwipeStartAction(item: EventEntity) {
    Button({ type: ButtonType.Normal }) {
      Text('删除')
        .fontSize(14).fontColor(Color.White)
    }
    .width(60).height('100%')
    .backgroundColor('#D32F2F') // 深红色
    .onClick(() => {
      // ✅ [修改] 增加二次确认弹窗
      this.getUIContext().showAlertDialog({
        title: '确认删除',
        message: `确定要删除 "${item.name}" 吗？\n删除后无法恢复。`, // 如果有回收站逻辑可改为"移入回收站"
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
          action: async () => {
            // 确认后才执行删除
            try {
              await this.vm.hardDelete(item);
              this.vm.refreshTimelineView();
            } catch (_error) {
              this.safeShowToast('删除失败，请重试');
            }
          }
        }
      });
    })
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

  @Builder
  BuildDateHeader(text: string, dayOffset: number) {
    Row() {
      Text(this.isDayCollapsed(dayOffset) ? '▶' : '▼')
        .fontSize(12)
        .fontColor(this.getThemePalette().textTertiary)
        .margin({ right: 8 })

      Column()
        .width(4)
        .height(14)
        .backgroundColor(this.getThemePalette().warning)
        .margin({ right: 8 })
        .borderRadius(2)

      Text(text)
        .fontSize(16)
        .fontColor(this.getThemePalette().textPrimary)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .padding({ top: 16, bottom: 8, left: 4 })
    .backgroundColor(this.getThemePalette().pageBg) // 保持与背景一致
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.toggleDayCollapse(dayOffset);
      });
    })
  }




  @Builder
  CompanionModeBuilder() {
    CompanionView({
      vm: this.vm, // 传递 ViewModel
      isShow: $isCompanionMode, // 双向绑定，用于内部关闭
      backRequestToken: $companionBackRequestToken
    })
  }

  @Builder
  private PlanningWeatherHintPopupBuilder() {
    Scroll() {
      Column({ space: 2 }) {
        Text(this.getPlanningHintLine(0))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#1565C0')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningHintLine(1))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#2E7D32')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningHintLine(2))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#6A1B9A')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningHintLine(3))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#455A64')
          .fontWeight(FontWeight.Medium)
        Text('仅作为建议，不会自动改行程。')
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#D32F2F')
          .fontWeight(FontWeight.Bold)
      }
      .padding(10)
      .width('100%');
    }
    .height(230)
    .width(280);
  }

  private getPlanningHintLine(index: number): string {
    const lines = this.vm.buildPlanningWeatherHintExplanation().split('\n');
    return lines[index] ?? '';
  }

  @Builder
  private PlanningWeatherScorePopupBuilder() {
    Scroll() {
      Column({ space: 2 }) {
        Text(this.getPlanningScoreLine(0))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#1565C0')
          .fontWeight(FontWeight.Bold)
        Text(this.getPlanningScoreLine(1))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#2E7D32')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningScoreLine(2))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#6A1B9A')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningScoreLine(3))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#455A64')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningScoreLine(4))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#EF6C00')
          .fontWeight(FontWeight.Medium)
        Text(this.getPlanningScoreLine(5))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#1B5E20')
          .fontWeight(FontWeight.Medium)
      }
      .padding(10)
      .width('100%');
    }
    .height(230)
    .width(280);
  }

  private getPlanningScoreLine(index: number): string {
    const lines = this.vm.buildWeatherScoreExplanation(this.vm.weatherRouteScore).split('\n');
    return lines[index] ?? '';
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
          const suggestedDay = this.findLeastBusyDay();
          const smartTime = this.calculateSmartTime(item.id ?? -1);
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
        onMoveAllToSchedule: (): void => {
          const movedCount = this.vm.moveAllBacklogToSchedule();
          if (movedCount > 0) {
            this.safeShowToast(`已加入日程 ${movedCount} 个地点`);
          } else {
            this.safeShowToast('暂存池暂无可加入地点');
          }
        },
        onIsDayCollapsed: (dayOffset: number): boolean => this.isDayCollapsed(dayOffset),
        onToggleDay: (dayOffset: number): void => this.toggleDayCollapse(dayOffset),
        onScheduleRefresh: (): void => {
          void this.handlePagePullRefresh();
        },
        onOpenEditDialog: (item: EventEntity): void => this.openEditDialog(item),
        onOpenTimeEditDialog: (item: EventEntity): void => this.openTimeEditDialog(item),
        onGapFound: (item: EventEntity): void => this.onGapFoundCallback(item),
        onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number): void => {
          this.handleEventConflictAction(item, strategy, gapMinutes);
        },
        onConfirmMoveToBacklog: (item: EventEntity): void => {
          if (item.status !== 1) {
            this.safeShowToast('该地点不在日程表中');
            return;
          }
          void this.vm.moveToBacklog(item).then((): void => {
            this.vm.refreshTimelineView();
          }).catch((_error: Object): void => {
            this.safeShowToast('暂存失败，请重试');
          });
        },
        onConfirmDeleteEvent: (item: EventEntity): void => {
          this.getUIContext().showAlertDialog({
            title: '确认删除',
            message: `确定要删除 "${item.name}" 吗？\n删除后无法恢复。`,
            autoCancel: true,
            alignment: DialogAlignment.Center,
            primaryButton: {
              value: '取消',
              action: (): void => {}
            },
            secondaryButton: {
              value: '删除',
              fontColor: Color.White,
              backgroundColor: '#2F7DFF',
              action: (): void => {
                void this.vm.hardDelete(item).then((): void => {
                  this.vm.refreshTimelineView();
                }).catch((_error: Object): void => {
                  this.safeShowToast('删除失败，请重试');
                });
              }
            }
          });
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

































