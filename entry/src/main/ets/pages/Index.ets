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
import { RenameDialog } from './components/dialogs/RenameDialog';
import { PlanSettingsDialog } from './components/dialogs/PlanSettingsDialog';
import { DateFilterDialog } from './components/dialogs/DateFilterDialog';
import { DateConflictDialog } from './components/dialogs/DateConflictDialog';
import { DateUtil } from '../common/utils/DateUtil';
import { promptAction } from '@kit.ArkUI';
import { AiInputDialog } from './components/dialogs/AiInputDialog';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';
import { StrategyService } from '../domain/strategy/StrategyService';

import { SuggestionDialog } from './components/dialogs/SuggestionDialog';
import { ConflictSelectionDialog } from './components/dialogs/ConflictSelectionDialog';
import { ConflictCompressDialog } from './components/dialogs/ConflictCompressDialog';
import { TimelineInteractionHelper } from '../viewmodel/TimelineInteractionHelper';
import { GapResolutionDialog } from './components/dialogs/GapResolutionDialog';
import { CompanionView } from './components/views/CompanionView';
import { PlanBottomActionBar } from './components/views/BottomNavBar';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { NavigationHelper } from '../common/utils/NavigationHelper';
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { WeatherReminderCoordinator } from '../infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload } from '../common/utils/weather/WeatherReminderStore';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { TimelineDatePolicy } from '../domain/policy/TimelineDatePolicy';
import { PageDraftRecovery } from '../common/utils/PageDraftRecovery';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { DomainConstants } from '../common/constants/DomainConstants';
import { PlanRepositoryImpl } from '../infrastructure/persistence/PlanRepositoryImpl';
import { WeatherUserPreference } from '../domain/services/WeatherModels';

interface InitDialogData {
  name: string;
  note: string;
  duration: number;
  isAnchor: boolean;
  fixedTime: string;
  dayOffset: number;
  suggestedTime?: string;
  isSchedule?: boolean;
  lat?: number; // ✅ 新增
  lng?: number; // ✅ 新增
}

interface PendingItemData {
  id: number;
  name: string;
  duration: number;
  isSchedule: boolean;
  fixedTime?: string;
  dayOffset: number;
  targetDateMs: number;
  note: string;
  lat?: number;
  lng?: number;
}

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
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  @StorageLink('TrafficDataUpdated') @Watch('onTrafficSignal') trafficSignal: number = 0;
  private arrivalReminderUnsubscribe: (() => void) | null = null;
  private weatherReminderUnsubscribe: (() => void) | null = null;
  @State isArrivalDialogOpen: boolean = false;
  @State isWeatherDialogOpen: boolean = false;
  private readonly planService: PlanAppService = PlanAppService.getInstance();
  private readonly arrivalCoordinator: ArrivalReminderCoordinator = ArrivalReminderCoordinator.getInstance();
  private readonly weatherCoordinator: WeatherReminderCoordinator = WeatherReminderCoordinator.getInstance();
  private strategyAdaptationCheckTimer: number = -1;
  dialogController: CustomDialogController | null = null;

  settingsDialogController: CustomDialogController | null = null;
  dateFilterController: CustomDialogController | null = null;
  conflictSelectionController: CustomDialogController | null = null;
  conflictCompressController: CustomDialogController | null = null;
  timeDialogController: CustomDialogController | null = null;
  suggestionDialogController: CustomDialogController | null = null;

  onTrafficSignal() {
    hilog.info(0x0000, 'Index', '收到高德数据更新信号，触发 UI 重算');
    this.vm.recalculateTrafficOnly(); // 路况回填走轻量重算，避免全量重算风暴
  }

   private scopedStorageKey(base: string): string {
    if (this.currentPlanId > 0) {
      return `${base}_${this.currentPlanId}`;
    }
    return base;
  }

  private clearDialogDraftStorage(): void {
    AppStorage.setOrCreate(this.scopedStorageKey(AppStorageKeys.TEMP_DIALOG_STATE), '');
    AppStorage.setOrCreate(this.scopedStorageKey(AppStorageKeys.PICKED_LOCATION_STR), '');
    AppStorage.setOrCreate(AppStorageKeys.TEMP_DIALOG_STATE, '');
    AppStorage.setOrCreate(AppStorageKeys.PICKED_LOCATION_STR, '');
  }

  private readDraftStorageWithFallback(key: string): string {
    const scoped = AppStorage.get<Object>(this.scopedStorageKey(key));
    if (typeof scoped === 'string' && scoped.trim().length > 0) {
      return scoped;
    }
    const globalVal = AppStorage.get<Object>(key);
    if (typeof globalVal === 'string' && globalVal.trim().length > 0) {
      return globalVal;
    }
    return '';
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
    this.hasUnsavedChanges = AppStorage.get<boolean>(this.scopedStorageKey(AppStorageKeys.HAS_UNSAVED_POSTPONE)) ?? false;
  }

  private setUnsavedFlag(value: boolean): void {
    AppStorage.setOrCreate(this.scopedStorageKey(AppStorageKeys.HAS_UNSAVED_POSTPONE), value);
    this.hasUnsavedChanges = value;
  }

  private hasScopedUnsavedChanges(): boolean {
    return AppStorage.get<boolean>(this.scopedStorageKey(AppStorageKeys.HAS_UNSAVED_POSTPONE)) ?? false;
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

    this.arrivalReminderUnsubscribe = this.arrivalCoordinator.subscribePlan(this.currentPlanId, {
      isDialogOpen: (): boolean => this.isArrivalDialogOpen,
      resolveEvents: (): EventEntity[] => this.vm.events,
      onShowPlan: (payload: ArrivalReminderPayload): void => {
        this.showArrivalReminderDialog(payload);
      }
    });

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
  }

  private unbindReminderSubscriptions(): void {
    if (this.arrivalReminderUnsubscribe) {
      this.arrivalReminderUnsubscribe();
      this.arrivalReminderUnsubscribe = null;
    }
    if (this.weatherReminderUnsubscribe) {
      this.weatherReminderUnsubscribe();
      this.weatherReminderUnsubscribe = null;
    }
  }

  private showArrivalReminderDialog(payload: ArrivalReminderPayload): void {
    this.isArrivalDialogOpen = true;
    this.getUIContext().showAlertDialog({
      title: '到达提醒',
      message: `你已到达【${payload.placeName}】附近（约${Math.max(1, payload.distanceMeters)}米）`,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '进入行程页',
        action: () => {
          this.isCompanionMode = true;
          this.isArrivalDialogOpen = false;
          this.arrivalCoordinator.acknowledge(payload.eventId, 'open_page');
        }
      },
      secondaryButton: {
        value: '立即开始',
        action: () => {
          this.isCompanionMode = true;
          this.isArrivalDialogOpen = false;
          void this.tryStartEventWithConflictPrompt(payload.eventId).then((started: boolean) => {
            if (started) {
              this.arrivalCoordinator.acknowledge(payload.eventId, 'start');
            } else {
              this.arrivalCoordinator.acknowledge(payload.eventId, 'open_page');
            }
          });
        }
      }
    });
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
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '知道了',
        action: () => {
          this.isWeatherDialogOpen = false;
          this.weatherCoordinator.clear(this.currentPlanId);
        }
      },
      secondaryButton: {
        value: payload.suggestionId ? '应用建议+调整策略' : '可选：刷新天气',
        action: () => {
          this.isWeatherDialogOpen = false;
          this.weatherCoordinator.clear(this.currentPlanId);
          if (payload.suggestionId) {
            void this.vm.applyExecutionSuggestionWithStrategy(
              this.currentPlanId,
              payload.suggestionId || '',
              payload.strategyAdjustment,
              payload.strategyHint
            ).then((applyResult) => {
              if (applyResult.replanSuccess) {
                if (applyResult.strategyApplied) {
                  this.safeShowToast('已应用建议并调整策略');
                } else {
                  this.safeShowToast('已按可选建议调整行程');
                }
              } else if (applyResult.strategyApplied) {
                this.safeShowToast('策略已应用，行程重排失败，可稍后重试。');
              } else {
                this.safeShowToast(`可选建议未应用：${applyResult.errorCode}`);
              }
            });
          } else {
            void this.vm.refreshExecutionWeather(true, 'MANUAL');
          }
        }
      }
    });
  }

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  gapDialogController: CustomDialogController | null = new CustomDialogController({
    builder: GapResolutionDialog({
      vm: this.vm,
      currentGap: this.gapItem  // ✅ 核心修复：属性名对齐
    }),
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: 0 },
    customStyle: true
  });


  // Index.ets 约 118 行开始替换
  conflictDialogController: CustomDialogController = new CustomDialogController({
    builder: DateConflictDialog({
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
              onAccept: (value: DatePickerResult) => {
                // 1. 计算新的 DayOffset
                const newSelectedDate = new Date();
                newSelectedDate.setFullYear(value.year, value.month, value.day);
                const newOffset = TimelineDatePolicy.timestampToDayOffset(this.vm.planStartDate, newSelectedDate.getTime());

                // 2. 直接保存并入库
                if (this.pendingItem) {
                  if (this.pendingItem.id !== -1) {
                    // ✨ 关键点：如果是从已有项移动来的，调用更新
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
                    // 只有确实是全新添加的，才调用新增
                    this.vm.addNewItem(this.pendingItem.name, this.pendingItem.duration, true, this.pendingItem.fixedTime, newOffset, -1, false, this.pendingItem.note);
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
      onMoveToBacklog: () => {
        if (this.pendingItem) {
          // 调用 VM 中刚写好的清洗方法
          this.vm.resolveConflictByBacklog(
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
      onChangePlanStartDate: () => {
        if (this.pendingItem) {
          // 调用平移方法
          this.vm.resolveConflictByMovingPlan(
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
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center
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

  aiDialogController: CustomDialogController = new CustomDialogController({
    builder: AiInputDialog({
      hasAiHistory: this.vm.hasAiHistory(),
      onConfirm: async (text: string, strategy: number, customStrategy?: ComposableStrategy) => {
        try {
          await this.vm.generateByAi(text, strategy, customStrategy);
          this.safeShowToast('AI 生成成功，已加入暂存池！');
          this.aiDialogController.close();
        } catch {
          this.safeShowToast('生成失败');
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
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
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
    // 1. 如果是列表为空，返回默认行程开始时间 (09:00)
    if (this.vm.events.length === 0) return '09:00';

    let prevItem: EventEntity | undefined;

    // 2. 寻找参照物
    if (targetItemId === -1) {
      // Case A: 新增模式 -> 取列表最后一个作为参照
      prevItem = this.vm.events[this.vm.events.length - 1];
    } else {
      // Case B: 编辑模式 -> 取当前元素的前一个作为参照
      const index = this.vm.events.findIndex(e => e.id === targetItemId);
      if (index > 0) {
        prevItem = this.vm.events[index - 1];
      }
    }

    // 3. 计算时间
    if (prevItem) {
      const startTime = prevItem.computed_time || prevItem.fixed_start_time || '09:00';
      // 计算结束时间 (这里直接调用 DateUtil，假设它已引入)
      return DateUtil.calculateEndTime(startTime, prevItem.duration);
    }

    // 4. 如果是第一个元素，返回 09:00
    return '09:00';
  }
  private resolveConflictGapMinutes(item: EventEntity, fallbackGap: number = 0): number {
    if (item.gap_minutes > 0) {
      return item.gap_minutes;
    }

    const match = (item.conflict_msg || '').match(/(\d+)/);
    if (match && match.length > 1) {
      const parsed = Number.parseInt(match[1], 10);
      if (Number.isFinite(parsed) && parsed > 0) {
        return parsed;
      }
    }

    return fallbackGap > 0 ? fallbackGap : 0;
  }

  private getConflictTargetTime(item: EventEntity): string {
    const raw = item.fixed_start_time || item.computed_time || '09:00';
    const pure = DateUtil.extractPureTime(raw);
    return pure && DateUtil.isValidTimeString(pure) ? pure : '09:00';
  }

  private async saveConflictTime(item: EventEntity, newTime?: string, onDone?: () => Promise<void> | void): Promise<void> {
    if (newTime && item.id > 0) {
      const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      await this.vm.updateEventInfo(
        item.id,
        item.name,
        item.duration,
        newTime,
        effectiveDayOffset,
        item.lock_status === 1,
        item.note,
        item.priority,
        item.latitude,
        item.longitude
      );
    }

    if (onDone) {
      await onDone();
    }
  }

  private handleEventConflictAction(item: EventEntity, strategy: 'delay' | 'compress' | 'smart', gapMinutes: number,
    onDone?: () => void) {
    const index = this.vm.events.indexOf(item);
    if (index < 0) {
      hilog.warn(0x0000, 'Index', `[CONFLICT_UI][missing_item] strategy=${strategy}, itemId=${item.id}`);
      return;
    }

    const targetTime = this.getConflictTargetTime(item);
    const saveCallback = (nextTime?: string) => {
      void this.saveConflictTime(item, nextTime, onDone);
    };
    const reopenConflictMenu = () => {
      const latestGap = this.resolveConflictGapMinutes(item, gapMinutes);
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

    this.openCompressSelectionDialog(index, item, targetTime, saveCallback, reopenConflictMenu);
  }

  private handleSameDayShiftConflict(index: number, item: EventEntity, targetTime: string, gap: number,
    saveCallback: (t?: string) => void): void {
    const requestedShift = this.resolveConflictGapMinutes(item, gap);
    const preview = this.vm.previewSameDayFixedShiftBeforeTarget(index, requestedShift);
    if (preview.appliedShiftMinutes <= 0 || preview.affectedItems.length === 0) {
      this.safeShowToast(preview.message);
      return;
    }

    const remainText = preview.remainingGapMinutes > 0
      ? `\n前移后仍预计剩余 ${preview.remainingGapMinutes} 分钟冲突。`
      : '\n前移后预计可消除本次冲突。';

    this.getUIContext().showAlertDialog({
      title: '同日整体前移',
      message: `${preview.message}${remainText}\n仅作用于当前 DayX，不影响其他 DayX。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认前移',
        action: () => {
          void this.vm.applySameDayFixedShiftBeforeTarget(preview).then((result) => {
            if (result.appliedShiftMinutes <= 0) {
              this.safeShowToast('整体前移未生效');
              return;
            }
            if (result.remainingGapMinutes > 0) {
              this.safeShowToast(`已前移 ${result.appliedShiftMinutes} 分钟，仍有 ${result.remainingGapMinutes} 分钟冲突`);
              const latestGap = this.resolveConflictGapMinutes(item, result.remainingGapMinutes);
              this.openConflictMenu(index, item, targetTime, latestGap, saveCallback);
              return;
            }
            this.safeShowToast(`已整体前移 ${result.appliedShiftMinutes} 分钟`);
          }).catch((_error: Object) => {
            this.safeShowToast('整体前移失败');
          });
        }
      },
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
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

    this.conflictCompressController = new CustomDialogController({
      builder: ConflictCompressDialog({
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
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false
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

    const targetTime = this.getConflictTargetTime(conflictItem);
    const conflictGap = this.resolveConflictGapMinutes(conflictItem, preview.gapMinutes);

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
        void this.saveConflictTime(conflictItem, suggestedTime, async () => {
          await this.vm.updatePlanDate(normalizedTimestamp);
        });
      }
    );
  }

  openConflictMenu(index: number, item: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void) {
    hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_open] index=${index}, itemId=${item.id}, targetTime=${targetTime}, gap=${gap}`);
    this.conflictSelectionController = new CustomDialogController({
      builder: ConflictSelectionDialog({
        gapMinutes: gap,

        // 方案 1: 延迟 Y
        onDelayY: () => {
          hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_delay] itemId=${item.id}`);
          const plan = this.vm.calculateDelayPlan(index);
          this.openPreview(index, item, targetTime, plan, saveCallback, () => {
            // 如果在预览点返回，重新打开菜单
            this.openConflictMenu(index, item, targetTime, gap, saveCallback);
          });
        },

        // 方案 2: 压缩前序（可选范围）
        onCompressX: () => {
          hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_compress] itemId=${item.id}`);
          this.openCompressSelectionDialog(index, item, targetTime, saveCallback, () => {
            this.openConflictMenu(index, item, targetTime, gap, saveCallback);
          });
        },

        onShiftSameDay: () => {
          hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_shift_same_day] itemId=${item.id}`);
          this.handleSameDayShiftConflict(index, item, targetTime, gap, saveCallback);
        },

        // 兼容入口：智能均衡并入压缩前序
        onSmartAdjust: () => {
          hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_smart] itemId=${item.id}`);
          this.openCompressSelectionDialog(index, item, targetTime, saveCallback, () => {
            this.openConflictMenu(index, item, targetTime, gap, saveCallback);
          });
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
    this.conflictSelectionController.open();
  }

  private getBacklogExpandedKey(planId: number): string {
    return `backlog_expanded_plan_${planId}`;
  }

  private getBacklogInitializedKey(planId: number): string {
    return `backlog_expanded_initialized_plan_${planId}`;
  }

  private async initBacklogExpandedState(planId: number, isNewPlan: boolean): Promise<void> {
    const pref = PreferenceManager.getInstance();

    // 新建计划首次进入：默认展开，并立即持久化
    if (isNewPlan) {
      this.backlogExpanded = true;
      await pref.setValue(this.getBacklogExpandedKey(planId), true);
      await pref.setValue(this.getBacklogInitializedKey(planId), true);
      return;
    }

    // 非新建进入：读取历史状态
    const initialized = await pref.getValue(this.getBacklogInitializedKey(planId), false);
    if (initialized === true) {
      const savedExpanded = await pref.getValue(this.getBacklogExpandedKey(planId), false);
      this.backlogExpanded = (savedExpanded === true);
      return;
    }

    // 旧计划但此前没有记录：按你的规则，不自动展开
    this.backlogExpanded = false;
    await pref.setValue(this.getBacklogExpandedKey(planId), false);
    await pref.setValue(this.getBacklogInitializedKey(planId), true);
  }

  private onToggleBacklogExpand(): void {
    this.backlogExpanded = !this.backlogExpanded;
    const planId = this.currentPlanId;
    if (planId > 0) {
      PreferenceManager.getInstance().setValue(
        this.getBacklogExpandedKey(planId),
        this.backlogExpanded
      );
    }
  }

  private isDayCollapsed(dayOffset: number): boolean {
    return this.collapsedDayOffsets.indexOf(dayOffset) >= 0;
  }

  private toggleDayCollapse(dayOffset: number): void {
    const idx = this.collapsedDayOffsets.indexOf(dayOffset);
    if (idx >= 0) {
      this.collapsedDayOffsets.splice(idx, 1);
    } else {
      this.collapsedDayOffsets.push(dayOffset);
    }
    this.collapsedDayOffsets = [...this.collapsedDayOffsets];
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

    this.suggestionDialogController = new CustomDialogController({
      builder: SuggestionDialog({
        itemName: item.name,
        conflictName: conflictName,
        targetTime: targetTime,
        suggestedTime: plan.suggestedTime || targetTime,
        detailMsg: detailMsg,

        onConfirm: () => {
          if (plan.suggestedTime) {
            // 这里要注意：如果是 Delay 方案，affectedItems 是空的，只需应用时间
            // 如果是压缩方案，需要 applyCompressionPlan
            if (plan.affectedItems.length > 0) {
              // 注意：这里需要构造一个临时的 plan 对象传回去，或者直接用 plan
              // 因为 applyCompressionPlan 只认 affectedItems
              this.vm.applyCompressionPlan(plan);
            }
            saveCallback(plan.suggestedTime);
          }
        },
        onBack: onBack // 🔙 传递返回能力
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
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
    const smartTime = initData?.suggestedTime || this.calculateSmartTime(this.editingItemId);
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
        initDayOffset: initData?.dayOffset || 0,
        initPreTravel: currentPreTravel,
        initPriority: currentPriority, // ✅ 传入
        storageScopePlanId: this.currentPlanId,
        planStartDate: this.vm.planStartDate,

        initLat: initData?.lat || 0, // ✅ 确保把坐标传给弹窗
        initLng: initData?.lng || 0,

        // ✅ [核心拦截逻辑] 更新回调签名
        // ✅ 增加 lat, lng 接收参数
        onConfirm: async (name, duration, isSchedule, fixedTime, dayOffset, preTravel, isHardLock, note, isMustVisit, lat, lng) => {
          const hasCoordinate = Number.isFinite(lat) && Number.isFinite(lng) && lat !== 0 && lng !== 0;
          hilog.info(0x0000, 'IndexPage', `[DIALOG_SAVE] has_coordinate=${hasCoordinate}`);
          if (this.vm.planStartDate <= 0 || (dayOffset !== undefined && dayOffset >= 0)) {
            await TimelineInteractionHelper.handleSaveItem(
              this.vm, this.editingItemId, name, duration, isSchedule,
              fixedTime, dayOffset, preTravel, this.onGapFoundCallback,
              isHardLock, note, isMustVisit,
              lat, lng // ✅ 传给下一步 Helper
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
    this.dateFilterController = new CustomDialogController({
      builder: DateFilterDialog({
        onShowAll: () => {
          this.vm.clearFilter();
        },
        onSelectDate: () => {
          this.openSingleDateFilterPicker();
        },
        onSelectRange: () => {
          this.openRangeDateFilterPicker();
        }
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      autoCancel: true
    });

    this.dateFilterController.open();
  }

  private openSingleDateFilterPicker(): void {
    setTimeout(() => {
      this.getUIContext().showDatePickerDialog({
        start: new Date(this.vm.planStartDate || new Date()),
        end: new Date(DomainConstants.DATE_PICKER_MAX),
        selected: new Date(this.vm.planStartDate || new Date()),
        onAccept: (value: DatePickerResult) => {
          const selectDate = new Date();
          selectDate.setFullYear(value.year, value.month, value.day);
          selectDate.setHours(0, 0, 0, 0);
          this.vm.setFilter(selectDate.getTime(), selectDate.getTime());
        }
      });
    }, 100);
  }

  private openRangeDateFilterPicker(): void {
    setTimeout(() => {
      this.getUIContext().showDatePickerDialog({
        start: new Date(this.vm.planStartDate || new Date()),
        end: new Date(DomainConstants.DATE_PICKER_MAX),
        selected: new Date(this.vm.planStartDate || new Date()),
        onAccept: (startValue: DatePickerResult) => {
          const startDate = new Date();
          startDate.setFullYear(startValue.year, startValue.month, startValue.day);
          startDate.setHours(0, 0, 0, 0);
          setTimeout(() => {
            this.openRangeEndDatePicker(startDate);
          }, 300);
        }
      });
    }, 100);
  }

  private openRangeEndDatePicker(startDate: Date): void {
    this.getUIContext().showDatePickerDialog({
      start: startDate,
      end: new Date(DomainConstants.DATE_PICKER_MAX),
      selected: startDate,
      onAccept: (endValue: DatePickerResult) => {
        const endDate = new Date();
        endDate.setFullYear(endValue.year, endValue.month, endValue.day);
        endDate.setHours(
          DomainConstants.END_OF_DAY_HOUR,
          DomainConstants.END_OF_DAY_MINUTE,
          DomainConstants.END_OF_DAY_SECOND,
          DomainConstants.END_OF_DAY_MILLISECOND
        );
        this.vm.setFilter(startDate.getTime(), endDate.getTime());
      }
    });
  }

  // [新增] 提取日期选择逻辑
  openDatePicker() {
    this.getUIContext().showDatePickerDialog({
      start: new Date(DomainConstants.DATE_PICKER_MIN),
      end: new Date(DomainConstants.DATE_PICKER_MAX),
      selected: new Date(this.vm.planStartDate || new Date()),
      onAccept: (value: DatePickerResult) => {
        const newDate = new Date();
        newDate.setFullYear(value.year, value.month, value.day);
        newDate.setHours(0, 0, 0, 0);
        this.requestPlanDateUpdate(newDate.getTime());
      }
    });
  }

  // ✅ [修复步骤 2] 修改打开菜单的方法
  openSettingsDialog() {
    // ❌ 不要用 let settingsController = ... (这是导致闪退的原因)
    // ✅ 改用 this.settingsDialogController
    this.settingsDialogController = new CustomDialogController({
      builder: PlanSettingsDialog({
        autoRouteEnabled: this.vm.enableAutoAmapRoute,
        currentStrategyMode: this.vm.getStrategyMode(),
        hasAiHistory: this.vm.hasAiHistory(),
        onRename: () => {
          setTimeout((): void => this.openRenameDialog(), 100);
        },
        onReschedule: () => {
          setTimeout(() => {
            this.getUIContext().showDatePickerDialog({
              start: new Date(DomainConstants.DATE_PICKER_MIN),
              end: new Date(DomainConstants.DATE_PICKER_MAX),
              selected: new Date(this.vm.planStartDate || new Date()),
              onAccept: (value: DatePickerResult) => {
                const newDate = new Date();
                newDate.setFullYear(value.year, value.month, value.day);
                newDate.setHours(0, 0, 0, 0);
                this.requestPlanDateUpdate(newDate.getTime());
              }
            });
          }, 100);
        },
        onAutoRouteChange: (enabled: boolean) => {
          this.vm.updatePlanAutoAmapRoute(enabled);
        },
        onStrategyChange: async (mode: number) => {
          try {
            await this.vm.updateStrategyMode(mode);
            this.strategyMode = mode;
            this.currentStrategyExplanation = StrategyService.buildStrategyExplanation(mode);
            const modeName = mode === 1 ? '特种兵' : mode === 2 ? '休闲' : '默认';
            this.safeShowToast(`已切换为${modeName}模式`);
          } catch (error) {
            this.safeShowToast('策略更新失败');
          }
        },
        onRegenerateWithStrategy: async (mode: number) => {
          try {
            await this.vm.changeStrategyAndRegenerate(mode);
            this.strategyMode = mode;
            this.currentStrategyExplanation = StrategyService.buildStrategyExplanation(mode);
            const modeName = mode === 1 ? '特种兵' : mode === 2 ? '休闲' : '默认';
            this.safeShowToast(`已切换为${modeName}模式并重新生成`);
          } catch (error) {
            const msg = error instanceof Error ? error.message : '重新生成失败';
            this.safeShowToast(msg);
          }
        },
        onCustomStrategyChange: async (strategy: ComposableStrategy) => {
          try {
            await this.vm.switchToCustomStrategy(strategy);
            this.strategyMode = -1;
            this.currentStrategyExplanation = StrategyService.buildComposableExplanation(strategy);
            this.safeShowToast('已应用自定义策略');
          } catch (error) {
            this.safeShowToast('策略更新失败');
          }
        },
        onRegenerateWithCustomStrategy: async (strategy: ComposableStrategy) => {
          try {
            await this.vm.regenerateWithCustomStrategy(strategy);
            this.strategyMode = -1;
            this.currentStrategyExplanation = StrategyService.buildComposableExplanation(strategy);
            this.safeShowToast('已应用自定义策略并重新生成');
          } catch (error) {
            const msg = error instanceof Error ? error.message : '重新生成失败';
            this.safeShowToast(msg);
          }
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
      }),
      alignment: DialogAlignment.Bottom, // 底部弹出
      customStyle: true, // 开启自定义样式
      autoCancel: true
    });

    // 打开弹窗
    this.settingsDialogController.open();
  }

  // [Priority 2 新增] 打开重命名弹窗
  openRenameDialog() {
    // 复用 dialogController 变量 (反正同一时间只能开一个弹窗)
    this.dialogController = new CustomDialogController({
      builder: RenameDialog({
        initName: this.planTitle,
        onConfirm: (newName) => {
          // 1. 更新 UI
          this.planTitle = newName;
          // 2. 更新数据库
          this.vm.renamePlan(newName);
        }
      }),
      alignment: DialogAlignment.Center, // 居中显示
      autoCancel: true
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
      this.vm.setHasUnsavedPostponeStorageKey(this.scopedStorageKey(AppStorageKeys.HAS_UNSAVED_POSTPONE));
      this.refreshUnsavedFlag();
      this.planTitle = params['title'] as string || '行程详情';
      this.bindReminderSubscriptions();
      void this.vm.loadData(planId).then(() => {
        this.strategyMode = this.vm.getStrategyMode();
        this.loadStrategyExplanation();
        if (this.vm.isWeatherFeatureEnabled()) {
          void this.vm.refreshPlanningWeather(false);
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

  @Builder
  SwipeEndAction(item: EventEntity) {
    Button({ type: ButtonType.Normal }) {
      Text('暂存') // 改名为暂存更贴切
        .fontSize(14).fontColor(Color.White)
    }
    .width(60).height('100%')
    .backgroundColor('#FF9800') // 橙色
    .onClick(() => {
      this.vm.moveToBacklog(item);
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
          fontColor: '#D32F2F',
          action: () => {
            // 确认后才执行删除
            this.vm.hardDelete(item);
          }
        }
      });
    })
  }

  openEditDialog(item: EventEntity) {
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
      isShow: $isCompanionMode // 双向绑定，用于内部关闭
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Text('返回')
              .fontSize(16)
              .fontColor(this.getThemePalette().primary)
          }
          .backgroundColor(Color.Transparent)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(8)
          .onClick(() => {
            void NavigationHelper.backOrFallbackToPlanList(this.getUIContext());
          })

          Column() {
            Text(this.planTitle.length > 7
              ? this.planTitle.substring(0, 7) + '...'
              : this.planTitle
            )
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .maxLines(1) // 确保单行
              .textOverflow({ overflow: TextOverflow.Ellipsis }) // 兜底省略
              .textAlign(TextAlign.Center)

            if (this.strategyMode === 1) {
              Text('🚀 特种兵模式')
                .fontSize(11)
                .fontColor('#FF6B35')
                .margin({ top: 2 })
            } else if (this.strategyMode === 2) {
              Text('🌴 休闲模式')
                .fontSize(11)
                .fontColor('#4CAF50')
                .margin({ top: 2 })
            } else if (this.strategyMode === -1) {
              Text('🎛 自定义策略')
                .fontSize(11)
                .fontColor('#2196F3')
                .margin({ top: 2 })
            }

            // 策略解释文案（非默认模式时展示）
            if (this.strategyMode !== 0 && this.currentStrategyExplanation) {
              Text(this.currentStrategyExplanation)
                .fontSize(10)
                .fontColor(this.strategyMode === 1 ? '#FF6B35'
                  : this.strategyMode === 2 ? '#4CAF50'
                  : '#2196F3')
                .margin({ top: 1 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            Text('点击修改日期')
              .fontSize(10)
              .fontColor(this.getThemePalette().textTertiary)
              .margin({ top: 2 })
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
          .onClick(() => {
            // [新增] 只读模式下禁止操作
            if (this.vm.isArchived) {
              return;
            }
            this.openSettingsDialog();
          })

       //   Button('全量测速')
          //   .fontSize(12).height(28).backgroundColor('#4CAF50').margin({ right: 8 })
          //        .onClick(() => {
          //   this.vm.testAllCommute();
          //      promptAction.openToast({ message: '同步高德实时路况中...' });
          //     })


          // ✅ [修复版] 稳健的伴游模式入口
          Row() {
            Text('🚀').fontSize(18)
          }
          .padding(8)
          .margin({ right: 4 })
          .onClick(() => {
            hilog.info(0x0000, 'Index', '[DUAL_MODE_ACCEPT][mode_switch][click_enter]');
            if (this.vm.isArchived) {
              this.safeShowToast('归档计划不可进入伴游');
              return;
            }
            this.isCompanionMode = true;
          })

          if (!this.isCompanionMode) {
            if (this.vm.isWeatherFeatureEnabled()) {
              Button(this.vm.weatherLoading ? '刷新中' : '可选刷新天气')
                .height(30)
                .fontSize(12)
                .padding({ left: 10, right: 10 })
                .backgroundColor(this.getThemePalette().cardBgSoft)
                .fontColor(this.getThemePalette().textPrimary)
                .enabled(!this.vm.weatherLoading)
                .onClick(() => {
                  void this.vm.refreshPlanningWeather(true).then(() => {
                    this.safeShowToast('天气已刷新');
                  }).catch((_error: Object) => {
                    this.safeShowToast('天气刷新失败');
                  });
                })
            }
          }

        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.Transparent)

        if (this.vm.isWeatherFeatureEnabled() && this.vm.weatherPlanningHint) {
          Row() {
            Text(`天气建议（可选）${this.vm.weatherCollabLabel ? `· ${this.vm.weatherCollabLabel}` : ''}：${this.vm.weatherPlanningHint}${this.vm.weatherCollabSummary ? `（${this.vm.weatherCollabSummary}）` : ''}${this.vm.weatherStrategyHint ? `；策略联动：${this.vm.weatherStrategyHint}` : ''}`)
              .fontSize(12)
              .fontColor(this.getThemePalette().warning)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (this.vm.weatherRouteScore >= 0) {
              Text(`评分 ${this.vm.weatherRouteScore}`)
                .fontSize(11)
                .fontColor(this.getThemePalette().textSecondary)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ bottom: 4 })
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .borderRadius(12)
        }

        // --- 区域 1: 顶部暂存池 ---
        BacklogView({
          items: this.vm.events
            .filter(e => e.status !== 1)
            .map(e => e.toInterface()),

          isExpanded: this.backlogExpanded,

          onToggleExpand: () => {
            this.onToggleBacklogExpand();
          },

          onMoveToSchedule: (item) => {
            const suggestedDay = this.findLeastBusyDay();

            // 计算建议时间：日程表最后一个地点的结束时间
            const scheduleItems = this.vm.events
              .filter(e => e.status === 1)
              .sort((a, b) => a.sort_order - b.sort_order);

            let smartTime = '09:00';
            if (scheduleItems.length > 0) {
              const lastItem = scheduleItems[scheduleItems.length - 1];
              // 优先使用computed_time（Solver计算结果，更可靠）
              if (lastItem.computed_time) {
                const timeStr = lastItem.computed_time.includes(' ')
                  ? lastItem.computed_time.split(' ').pop()
                  : lastItem.computed_time;
                if (timeStr) {
                  const parts = timeStr.split(':');
                  const h = Number(parts[0]);
                  const m = Number(parts[1]);
                  const endMinutes = h * 60 + m + (lastItem.duration || 60);
                  smartTime = `${String(Math.floor(endMinutes / 60)).padStart(2, '0')}:${String(endMinutes % 60).padStart(2, '0')}`;
                }
              }
              // 降级使用dynamic_end_time
              else if (lastItem.dynamic_end_time > 0) {
                const endDate = new Date(lastItem.dynamic_end_time);
                smartTime = `${String(endDate.getHours()).padStart(2, '0')}:${String(endDate.getMinutes()).padStart(2, '0')}`;
              }
            }

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
          }
        })
          .constraintSize({ maxHeight: '30%' })
          .zIndex(1)

        Divider().color(this.getThemePalette().divider)

        // --- 区域 2: 底部日程表 ---
        List({ space: 0 }) { // space 设为 0，由 Group 内间距控制

          // [第一层循环] 遍历日期组
          ForEach(this.vm.groupedEvents, (group: import('../viewmodel/TimelineViewModel').DateGroup) => {

            // [新增] 日期组组件
            ListItemGroup({ header: this.BuildDateHeader(group.dateHeader, group.dayOffset) }) {

              // [第二层循环] 遍历组内事件
              if (!this.isDayCollapsed(group.dayOffset)) {
                ForEach(group.events, (item: EventEntity, dayIndex: number) => {
                  ListItem() {
                    EventItemView({
                      event: item,
                      isCompanionMode: this.isCompanionMode,
                      showWeather: this.vm.isWeatherFeatureEnabled(),
                      showTravelIndicator: dayIndex > 0,

                      index: this.vm.events.indexOf(item),
                      totalCount: this.vm.events.length,

                      onMoveUp: () => {
                        this.vm.moveEvent(this.vm.events.indexOf(item), 'up');
                      },
                      onMoveDown: () => {
                        this.vm.moveEvent(this.vm.events.indexOf(item), 'down');
                      },
                      onMainContentClick: () => { // 原 onItemClick / onEditClick
                        if (this.vm.isArchived) return;
                        this.openEditDialog(item); // 点击中间 -> 完整编辑
                      },

                      onTimeClick: () => { // 点击左侧时间
                        if (this.vm.isArchived) return;
                        this.openTimeEditDialog(item); // 点击左侧 -> 时间编辑
                      },
                      onTravelModeChange: (mode: number) => {
                        this.vm.updateTravelMode(item, mode);
                      },
                      onManualTravelInput: (minutes: number) => {
                        this.vm.updateManualCommute(item, minutes);
                      },
                      onCommuteChange: (m) => {
                        TimelineInteractionHelper.handleCommuteChange(this.vm, item, m,this.onGapFoundCallback);
                      },
                      onConflictAction: (targetItem: EventEntity, strategy: 'delay' | 'compress' | 'smart', gapMinutes: number) => {
                        if (this.vm.isArchived) {
                          return;
                        }
                        this.handleEventConflictAction(targetItem, strategy, gapMinutes);
                      },
                    })
                      .enabled(!this.vm.isArchived)
                  }
                  .swipeAction(this.vm.isArchived ? undefined : {
                    start: {
                      builder: () => {
                        this.SwipeStartAction(item)
                      },
                      actionAreaDistance: 60
                    },
                    end: {
                      builder: () => {
                        this.SwipeEndAction(item)
                      },
                      actionAreaDistance: 60
                    }
                  })
                }, (item: EventEntity) => `${item.id}_${item.sort_order}_${item.status}`)
              }
            }
            .divider({ strokeWidth: 0 }) // 组内分割线 (可选)
          }, (group: import('../viewmodel/TimelineViewModel').DateGroup) =>
            `${group.dayOffset}_${group.actualDateMs}_${group.events.length}`)

          if (!this.vm.isArchived && this.vm.getSortedGaps().length > 0) {
            ListItem() {
              Row() {

                Text('→')
                  .fontSize(14)
                  .fontColor(this.getThemePalette().textTertiary)
                
                Text(`检测到 ${this.vm.getSortedGaps().length} 处空闲时间，是否立即优化？`)
                  .fontSize(13)
                  .fontColor(this.getThemePalette().textSecondary)
                  .layoutWeight(1) // 👈 报错点：确保这行上面没有分号

              }
              .width('100%')
              .padding({ top: 12, bottom: 12, left: 16, right: 16 })
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                // 这里的逻辑已按你的要求修改
                this.gapItem = null
                this.gapDialogController?.open()
              })
            }
          }
          ListItem().height(this.isCompanionMode ? 24 : 100)
        }
        .layoutWeight(1)
        .padding({
          top: 0,
          bottom: 0,
          left: 12,
          right: 12
        })
        .backgroundColor(this.getThemePalette().pageBg)
        .sticky(StickyStyle.Header) // 效果：日期标题吸顶
      }
      .width('100%').height('100%').backgroundColor(this.getThemePalette().pageBg)

      if (!this.isCompanionMode) {
        PlanBottomActionBar({
          onFilter: () => {
            this.openDateFilterDialog();
          },
          onAi: () => {
            if (this.vm.isArchived) {
              this.safeShowToast('归档计划不可操作');
              return;
            }
            this.aiDialogController.open();
          },
          onAdd: () => {
            if (this.vm.isArchived) {
              this.safeShowToast('归档计划不可操作');
              return;
            }
            this.editingItemId = -1;
            this.openDialog();
          },
          aiEnabled: !this.vm.isArchived,
          addEnabled: !this.vm.isArchived
        })
          .zIndex(8);
      }

      if (this.hasScopedUnsavedChanges()) {
        Row() {
          Row() {
            Text("✨").fontSize(16).margin({ right: 6 })
            Text("已自动优化行程时间")
              .fontSize(14)
              .fontColor(this.getThemePalette().textPrimary)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)

          Row() {
            Text("撤销")
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onClick(() => {
                this.vm.loadData(this.vm.planId);
                this.setUnsavedFlag(false);
              })

            Line().width(1).height(14).backgroundColor(this.getThemePalette().divider).margin({ left: 4, right: 4 })

            Text("保存")
              .fontSize(14)
              .fontColor(this.getThemePalette().primary)
              .fontWeight(FontWeight.Bold)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onClick(() => {
                this.vm.save();
                this.setUnsavedFlag(false);
              })
          }
        }
        .width('90%')
        .height(56)
        .padding({ left: 16, right: 8 })
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(28)
        .shadow({ radius: 20, color: '#1A000000', offsetY: 8 })
        .margin({ bottom: this.isCompanionMode ? 30 : 96 })
        .transition({ type: TransitionType.All, opacity: 0, translate: { y: 20 } })
      }
      if (this.isCompanionMode) {
        CompanionView({
          vm: this.vm,
          isShow: $isCompanionMode
        })
          .zIndex(DomainConstants.COMPANION_OVERLAY_Z_INDEX) // 确保在最上层
          .transition({
            type: TransitionType.All,
            opacity: 0,
            translate: { y: 12 },
            scale: { x: 0.985, y: 0.985 }
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg)
    }

}

































