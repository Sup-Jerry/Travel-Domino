import { TimelineViewModel } from '../viewmodel/TimelineViewModel';
// 修改点：View 组件指向 views 目录
import { EventItemView } from './components/views/EventItemView';
import { BacklogView } from './components/views/BacklogView';
// 修改点：Dialog 组件指向 dialogs 目录
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { EventEntity } from '../model/entity/EventEntity';
import { router } from '@kit.ArkUI';
// 修改点：批量更新 Dialog 路径
import { DateUtil } from '../common/utils/DateUtil';
import { promptAction } from '@kit.ArkUI';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';

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
import { ConflictFlowContext, IndexConflictFlowHelper } from './index/IndexConflictFlowHelper';
import { IndexPageBehaviorHelper, ReminderDialogContext, StrategyDialogContext } from './index/IndexPageBehaviorHelper';
import { BacklogActionContext, IndexPageActionsHelper, MoveToScheduleContext, MoveToScheduleItem } from './index/IndexPageActionsHelper';

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
  openTimeEditDialog(_item: EventEntity) {
    // 保留入口，具体冲突调整由统一冲突流程接管。
  }

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

  private findLeastBusyDay(): number {
    return IndexPageActionsHelper.findLeastBusyDay(this.vm);
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
          setTimeout(() => { this.conflictDialogController.open(); }, 100);
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

  private getMoveToScheduleContext(): MoveToScheduleContext {
    const context: MoveToScheduleContext = {
      vm: this.vm,
      setEditingItemId: (id: number): void => {
        this.editingItemId = id;
      },
      openDialog: (initData?: InitDialogData): void => {
        this.openDialog(initData);
      }
    };
    return context;
  }

  private getBacklogActionContext(): BacklogActionContext {
    const context: BacklogActionContext = {
      vm: this.vm,
      safeShowToast: (message: string): void => this.safeShowToast(message),
      getUIContext: (): UIContext => this.getUIContext()
    };
    return context;
  }

  private loadStrategyExplanation(): void {
    this.currentStrategyExplanation = IndexPageBehaviorHelper.loadStrategyExplanation(this.strategyMode);
  }

  private startStrategyAdaptationCheck(): void {
    this.strategyAdaptationCheckTimer = IndexPageBehaviorHelper.startStrategyAdaptationCheck(this.getStrategyDialogContext());
  }

  private showStrategyAdaptationDialog(): void {
    IndexPageBehaviorHelper.showStrategyAdaptationDialog(this.getStrategyDialogContext());
  }

  openEditDialog(item: EventEntity) {
    const prepared = IndexPageActionsHelper.prepareEditDialog(item);
    this.editingItemId = prepared.editingItemId;
    this.openDialog(prepared.initData);
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
          IndexPageActionsHelper.moveItemToSchedule(this.getMoveToScheduleContext(), moveItem);
        },
        onMoveAllToSchedule: (): void => {
          IndexPageActionsHelper.handleMoveAllToSchedule(this.getBacklogActionContext());
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
          IndexPageActionsHelper.handleConfirmMoveToBacklog(this.getBacklogActionContext(), item);
        },
        onConfirmDeleteEvent: (item: EventEntity): void => {
          IndexPageActionsHelper.handleConfirmDeleteEvent(this.getBacklogActionContext(), item);
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
