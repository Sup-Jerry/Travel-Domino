// 文件路径: ets/viewmodel/TimelineViewModel.ets
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { ActiveEventSnapshot } from '../infrastructure/persistence/EventRepositoryImpl';
import { EventRepositoryImpl } from '../infrastructure/persistence/EventRepositoryImpl';
import { EventEntity } from '../model/entity/EventEntity'; // 引入 Entity
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TimelineDatePolicy } from '../domain/policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../domain/policy/TimelineExecutionState';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { ScheduleOrchestrator } from './internal/ScheduleOrchestrator';
import { PlanPersistenceFacade } from './internal/PlanPersistenceFacade';
import { ReminderFacade } from './internal/ReminderFacade';
import {
  ApplyResultFlags as TimelineApplyResultFlags,
  AdvanceAdjustApplyResult,
  AdvanceAdjustContext,
  AdvanceAdjustPreview,
  CompressionMode,
  CompressionPlan,
  CompressionSelectionContext,
  CompanionActions as TimelineCompanionActions,
  CompanionContext as TimelineCompanionContext,
  CompanionRuntimeState as TimelineCompanionRuntimeState,
  ExecutionSuggestionApplyResult,
  HistoryTimelineActionType as TimelineHistoryTimelineActionType,
  HistoryTimelineFilter as TimelineHistoryTimelineFilter,
  HistoryTimelineItem as TimelineHistoryTimelineItem,
  HistoryTimelineSummary as TimelineHistoryTimelineSummary,
  PlanDateShiftPreview as TimelinePlanDateShiftPreview,
  ReflowHint as TimelineReflowHint,
  SolverCalculatedItem as TimelineSolverCalculatedItem,
  StartConflictInfo
} from './types/TimelineTypes';
import {
  ITimelineExecutionCoordinatorHost,
  TimelineExecutionCoordinator
} from './coordinators/TimelineExecutionCoordinator';
import { TimelineWeatherCoordinator } from './coordinators/TimelineWeatherCoordinator';
import { TimelineCompressionCoordinator } from './coordinators/TimelineCompressionCoordinator';
import {
  ITimelineDistributionCoordinatorHost,
  TimelineDistributionCoordinator
} from './coordinators/TimelineDistributionCoordinator';
import { ITimelineCompanionHost, TimelineCompanionManager } from './managers/TimelineCompanionManager';
import { ITimelineHistoryHost, TimelineHistoryManager } from './managers/TimelineHistoryManager';
import { ITimelinePlanStateHost, TimelinePlanStateManager } from './managers/TimelinePlanStateManager';
import { ITimelineStrategyHost, TimelineStrategyManager } from './managers/TimelineStrategyManager';
import { ITimelineEventMutationHost, TimelineEventMutationManager } from './managers/TimelineEventMutationManager';
import { ITimelineRecalculationHost, TimelineRecalculationManager } from './managers/TimelineRecalculationManager';
import { CompressionEngine } from '../domain/timeline/CompressionEngine';
import { TimelineGroupingService, DateGroup, PlaceCheckinSummary, PlaceCheckinRecord } from '../domain/timeline/services/TimelineGroupingService';
import {
  ITimelineCompressionHost,
  ITimelineCompressionService,
  TimelineCompressionService
} from '../domain/timeline/services/TimelineCompressionService';
import {
  ITimelineAiHost,
  ITimelineAiService,
  TimelineAiService
} from '../domain/timeline/services/TimelineAiService';
import {
  ITimelineExecutionHost,
  ITimelineExecutionService,
  TimelineExecutionService
} from '../domain/timeline/services/TimelineExecutionService';
import {
  ITimelineDistributionHost,
  ITimelineDistributionService,
  TimelineDistributionService
} from '../domain/timeline/services/TimelineDistributionService';
import {
  ITimelineWeatherHost,
  ITimelineWeatherService,
  TimelineWeatherService
} from '../domain/timeline/services/TimelineWeatherService';
import { UserBehaviorTracker } from '../domain/strategy/UserBehaviorTracker';
import { AdaptationPrompt } from '../domain/strategy/StrategyAdaptationEngine';
import { WeatherFacade } from '../domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../domain/services/WeatherRefreshScheduler';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  SoftReplanApplyResult,
  SoftReplanMode,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../domain/services/WeatherModels';
import { WeatherStrategyAdjustment } from '../common/utils/weather/WeatherReminderStore';
import { PlanStateMachine } from '../domain/statemachine/PlanStateMachine';
import { PlanStatus } from '../domain/statemachine/PlanStatus';

// 重新导出类型以保持向后兼容
export { DateGroup, PlaceCheckinSummary, PlaceCheckinRecord };
export {
  CompressionPlan,
  CompressionMode,
  CompressionSelectionCandidate,
  CompressionSelectionContext,
  AdvanceAdjustCandidate,
  AdvanceAdjustContext,
  AdvanceAdjustPreviewItem,
  AdvanceAdjustPreview,
  AdvanceAdjustApplyResult,
  ExecutionSuggestionApplyResult,
  StartConflictInfo
} from './types/TimelineTypes';

export type PlanDateShiftPreview = TimelinePlanDateShiftPreview;
export type HistoryTimelineFilter = TimelineHistoryTimelineFilter;
export type HistoryTimelineActionType = TimelineHistoryTimelineActionType;
export type HistoryTimelineItem = TimelineHistoryTimelineItem;
export type HistoryTimelineSummary = TimelineHistoryTimelineSummary;
export type CompanionRuntimeState = TimelineCompanionRuntimeState;
export type ReflowHint = TimelineReflowHint;
export type CompanionActions = TimelineCompanionActions;

export type CompanionContext = TimelineCompanionContext;

const TAG = 'TimelineViewModel';
export type SolverCalculatedItem = TimelineSolverCalculatedItem;
export type ApplyResultFlags = TimelineApplyResultFlags;

interface ActualTimeMutationMeta {
  beforeNextTs: number;
  beforeNextName: string;
}

@Observed
export class TimelineViewModel implements
  ITimelineHistoryHost,
  ITimelineCompanionHost,
  ITimelineExecutionCoordinatorHost,
  ITimelineDistributionCoordinatorHost,
  ITimelinePlanStateHost,
  ITimelineStrategyHost,
  ITimelineEventMutationHost,
  ITimelineRecalculationHost {
  private static readonly AUTO_DISTRIBUTION_MAX_DURATION: number = 240;
  @Track public events: EventEntity[] = [];
  @Track public planId: number = -1;
  @Track public planName: string = '';
  @Track public globalStartTime: string = '09:00';
  @Track public planStartDate: number = 0;
  @Track public isArchived: boolean = false;
  @Track public enableAutoAmapRoute: boolean = true;
  @Track public enableGlobalAmapRouteApi: boolean = false;
  @Track public groupedEvents: DateGroup[] = [];
  @Track public filterStart: number = 0;
  @Track public filterEnd: number = 0;
  @Track public conflictList: EventEntity[] = [];
  @Track public latestReflowHint: ReflowHint | null = null;
  @Track private scheduleVersion: number = 0;
  
  public actualTimeMutationInFlight: boolean = false;
  private saveQueue: Promise<void> = Promise.resolve();
  private readonly mutatingItemIds: Set<number> = new Set<number>();
  private hasUnsavedPostponeStorageKey: string = AppStorageKeys.HAS_UNSAVED_POSTPONE;
  private minEventDurationLimit: number = 30;
  private readonly scheduleOrchestrator: ScheduleOrchestrator = new ScheduleOrchestrator();
  public readonly persistence: PlanPersistenceFacade = new PlanPersistenceFacade();
  public readonly reminderFacade: ReminderFacade = new ReminderFacade();
  @Track public idleGapDetectionEnabled: boolean = true;
  @Track public idleGapTriggerMinutes: number = 45;
  public currentStrategyMode: number = 0;
  public isRegenerating: boolean = false;  // AI重新生成锁
  public behaviorTracker: UserBehaviorTracker = new UserBehaviorTracker();
  @Track public strategyAdaptationPrompt: AdaptationPrompt | null = null;
  @Track public weatherPlanningHint: string = '';
  @Track public weatherStrategyHint: string = '';
  @Track public weatherRouteScore: number = -1;
  @Track public weatherCollabSummary: string = '';
  @Track public weatherCollabLabel: string = '';
  @Track public weatherLastRefreshAt: number = 0;
  @Track public weatherLoading: boolean = false;
  @Track public weatherFeatureEnabled: boolean = true;
  @Track public executionWeatherHint: string = '';
  @Track public executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  @Track public executionWeatherCurrentText: string = '';
  @Track public executionWeatherNextText: string = '';
  @Track public executionWeatherDisplaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' = 'UNKNOWN';
  @Track public executionWeatherScore: number = -1;
  @Track public executionWeatherRefreshAt: number = 0;
  @Track public executionWeatherLoading: boolean = false;
  @Track public executionWeatherEnabled: boolean = false;
  @Track public executionWeatherLastTrigger: string = '';
  @Track public executionWeatherErrorCode: string = '';
  @Track public executionWeatherSuggestions: WeatherSuggestion[] = [];
  @Track public executionWeatherAppliedSummary: string = '';
  @Track public executionWeatherApplying: boolean = false;
  @Track public executionWeatherCollabBadge: string = '';
  @Track public executionWeatherCollabSummary: string = '';
  @Track public weatherUserPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };
  public readonly weatherFacade: WeatherFacade = new WeatherFacade();
  private readonly weatherRefreshScheduler: WeatherRefreshScheduler = new WeatherRefreshScheduler();
  public readonly planStateMachine: PlanStateMachine = PlanStateMachine.getInstance();
  @Track public currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  public executionWeatherLastLocation: GeoPointInput | null = null;
  public executionWeatherLastEmitAt: number = 0;
  public readonly executionWeatherLocationDeltaMeters: number = 120;
  public readonly executionWeatherLocationTriggerCooldownMs: number = 5 * 60 * 1000;
  public executionWeatherLastLocationTriggerAt: number = 0;
  public currentWeatherSchedulePolicy: WeatherSchedulePolicy = {
    stage: 'IN_PROGRESS',
    pollIntervalMs: 20 * 60 * 1000,
    allowLocationTrigger: true,
    allowManualBypass: true,
    forceRefreshOnEnter: true
  };
  public readonly executionSuggestionCooldownMs: number = 30 * 60 * 1000;

  public readonly executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  public readonly executionSuggestionMap: Map<string, WeatherSuggestion> = new Map<string, WeatherSuggestion>();
  public executionReplanBusy: boolean = false;
  public readonly weatherCollabOptions: WeatherCollabOptions = {
    enableMultiDay: true,
    enableMultiCity: true
  };
  private readonly weatherService: ITimelineWeatherService;
  private readonly compressionService: ITimelineCompressionService;
  private readonly aiService: ITimelineAiService;
  private readonly executionService: ITimelineExecutionService;
  private readonly distributionService: ITimelineDistributionService;
  public readonly executionCoordinator: TimelineExecutionCoordinator;
  public readonly weatherCoordinator: TimelineWeatherCoordinator;
  public readonly compressionCoordinator: TimelineCompressionCoordinator;
  public readonly distributionCoordinator: TimelineDistributionCoordinator;
  public readonly historyManager: TimelineHistoryManager;
  public readonly companionManager: TimelineCompanionManager;
  private readonly planStateManager: TimelinePlanStateManager;
  private readonly strategyManager: TimelineStrategyManager;
  private readonly eventMutationManager: TimelineEventMutationManager;
  private readonly recalculationManager: TimelineRecalculationManager;

  public constructor() {
    this.weatherService = new TimelineWeatherService(
      this as ITimelineWeatherHost,
      this.weatherFacade,
      this.weatherRefreshScheduler
    );
    this.compressionService = new TimelineCompressionService(
      this as ITimelineCompressionHost
    );
    this.aiService = new TimelineAiService(
      this as ITimelineAiHost
    );
    this.executionService = new TimelineExecutionService(
      this as ITimelineExecutionHost
    );
    this.distributionService = new TimelineDistributionService(
      this as ITimelineDistributionHost
    );
    this.executionCoordinator = new TimelineExecutionCoordinator(
      this as ITimelineExecutionCoordinatorHost
    );
    this.weatherCoordinator = new TimelineWeatherCoordinator(
      this.weatherService
    );
    this.compressionCoordinator = new TimelineCompressionCoordinator(
      this.compressionService
    );
    this.distributionCoordinator = new TimelineDistributionCoordinator(
      this as ITimelineDistributionCoordinatorHost,
      this.distributionService
    );
    this.historyManager = new TimelineHistoryManager(
      this as ITimelineHistoryHost
    );
    this.companionManager = new TimelineCompanionManager(
      this as ITimelineCompanionHost
    );
    this.planStateManager = new TimelinePlanStateManager(
      this as ITimelinePlanStateHost
    );
    this.strategyManager = new TimelineStrategyManager(
      this as ITimelineStrategyHost,
      this.aiService
    );
    this.eventMutationManager = new TimelineEventMutationManager(
      this as ITimelineEventMutationHost,
      this.behaviorTracker,
      this.strategyManager
    );
    this.recalculationManager = new TimelineRecalculationManager(
      this as ITimelineRecalculationHost
    );
  }

  /**
   *
   */
  public setFilter(start: number, end: number) {
    this.filterStart = start;
    this.filterEnd = end;
    this.generateGroups(); // 重新分组
  }

  /**
   *
   */
  public clearFilter() {
    this.filterStart = 0;
    this.filterEnd = 0;
    this.generateGroups();
  }

  public markScheduleChanged(): void {
    this.scheduleVersion += 1;
  }

  public getScheduleOrchestrator(): ScheduleOrchestrator {
    return this.scheduleOrchestrator;
  }

  public regenerateGroups(): void {
    this.generateGroups();
  }

  public getScheduleVersion(): number {
    return this.scheduleVersion;
  }
  public getMinEventDurationLimit(): number {
    return this.minEventDurationLimit;
  }

  public setHasUnsavedPostponeStorageKey(key: string): void {
    this.hasUnsavedPostponeStorageKey = key && key.length > 0 ? key : AppStorageKeys.HAS_UNSAVED_POSTPONE;
  }

  public markHasUnsavedPostpone(): void {
    AppStorage.setOrCreate(this.hasUnsavedPostponeStorageKey, true);
  }

  public tryBeginMutation(itemId: number): boolean {
    if (this.mutatingItemIds.has(itemId)) {
      return false;
    }
    this.mutatingItemIds.add(itemId);
    return true;
  }

  public endMutation(itemId: number): void {
    this.mutatingItemIds.delete(itemId);
  }

  public refreshTimelineView(): void {
    this.generateGroups();
    this.events = [...this.events];
  }

  public async applyRuntimeTransition(target: EventEntity, transition: 'START' | 'END' | 'SKIP' | 'REOPEN', timestamp: number): Promise<boolean> {
    if (!target || target.id <= 0 || this.planId <= 0) {
      return false;
    }
    const result = await this.persistence.applyRuntimeTransition({
      planId: this.planId,
      eventId: target.id,
      transition: transition,
      timestamp: timestamp
    });
    if (!result.ok) {
      hilog.warn(0x0000, TAG, `[RUNTIME_TRANSITION][blocked] event=${target.id}, transition=${transition}, reason=${result.reason}`);
      return false;
    }
    target.actual_start_time = result.startTime;
    target.actual_end_time = result.endTime;
    target.completion_status = result.completionStatus;
    return true;
  }

  public async reloadMinEventDurationLimit(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      const value = await pref.getMinEventDuration();
      this.minEventDurationLimit = PreferenceManager.normalizeMinEventDuration(value);
      hilog.info(0x0000, TAG, `[SETTING_VM][min_duration_loaded] value=${this.minEventDurationLimit}`);
    } catch (error) {
      this.minEventDurationLimit = 30;
      hilog.warn(0x0000, TAG, `[SETTING_VM][min_duration_fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public getIdleGapTriggerMinutes(): number {
    return this.idleGapTriggerMinutes;
  }

  public async reloadIdleGapSettings(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      const enabled = await pref.getIdleGapDetectionEnabled();
      const threshold = await pref.getIdleGapTriggerMinutes();
      this.idleGapDetectionEnabled = enabled;
      this.idleGapTriggerMinutes = PreferenceManager.normalizeIdleGapTriggerMinutes(threshold);
      hilog.info(
        0x0000,
        TAG,
        `[SETTING_VM][idle_gap_loaded] enabled=${this.idleGapDetectionEnabled}, threshold=${this.idleGapTriggerMinutes}`
      );
    } catch (error) {
      this.idleGapDetectionEnabled = true;
      this.idleGapTriggerMinutes = 45;
      hilog.warn(0x0000, TAG, `[SETTING_VM][idle_gap_fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public async loadData(planId: number): Promise<void> {
    this.planId = planId;
    this.planName = `计划 #${planId}`;
    this.filterStart = 0;
    this.filterEnd = 0;
    try {
      const snapshot = await this.persistence.getPlanAndEvents(planId);
      const plan = snapshot.plan;
      const rawEvents = snapshot.events;

      if (plan) {
        this.planName = (plan.title || '').trim().length > 0 ? (plan.title || '').trim() : `计划 #${planId}`;
        if (plan.startDate) {
          this.planStartDate = plan.startDate;
        }

        this.isArchived = (plan.status === 2);
        this.enableAutoAmapRoute = (plan.enableAutoAmapRoute ?? 1) === 1;
      }

      const entities = rawEvents.map(item => EventEntity.fromInterface(item, planId));
      this.events = entities;
      this.generateGroups();
      const loadedScheduleCount = this.events.filter((event: EventEntity) => event.status === 1).length;
      hilog.info(
        0x0000,
        TAG,
        `[LOAD_DIAG][after_query] planId=${planId}, total=${this.events.length}, schedule=${loadedScheduleCount}, groups=${this.groupedEvents.length}, filterStart=${this.filterStart}, filterEnd=${this.filterEnd}`
      );
      this.weatherCoordinator.restorePlanningWeatherSnapshot(planId);

      await this.reloadMinEventDurationLimit();
      await this.reloadIdleGapSettings();
      await this.reloadGlobalRouteApiSwitch();
      await this.weatherCoordinator.reloadWeatherUserPreference();
      try {
        this.recalculate();
      } catch (recalcError) {
        hilog.error(0x0000, TAG, `[LOAD_DIAG][recalculate_failed] planId=${planId}, reason=${JSON.stringify(recalcError)}`);
        this.generateGroups();
      }
      hilog.info(
        0x0000,
        TAG,
        `[LOAD_DIAG][after_recalc] planId=${planId}, total=${this.events.length}, groups=${this.groupedEvents.length}`
      );
      this.bindPlanState(planId);
    } catch (err) {
      hilog.error(0x0000, TAG, `Load data failed: ${JSON.stringify(err)}`);
    }
  }
  public bindPlanState(planId: number): void {
    this.planStateManager.bindPlanState(planId);
  }

  public unbindPlanState(): void {
    this.planStateManager.unbindPlanState();
  }

  public getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  public evaluatePlanStatusByRuntime(): void {
    this.planStateManager.evaluatePlanStatusByRuntime();
  }

  public resolveCurrentWeatherStage(): WeatherStageType {
    const runtimeState = this.getCompanionContext().runtimeState;
    return this.weatherFacade.resolveStage(this.currentPlanStatus, this.events, runtimeState);
  }

  public onLocationSampleForStateMachine(
    latitude: number,
    longitude: number,
    speed?: number,
    accuracy?: number,
    sampleTs: number = Date.now()
  ): void {
    this.planStateManager.onLocationSampleForStateMachine(latitude, longitude, speed, accuracy, sampleTs);
  }

  public recoverPlanRuntimeState(): void {
    this.planStateManager.recoverPlanRuntimeState();
  }

  public pauseCurrentExecution(): boolean {
    return this.planStateManager.pauseCurrentExecution();
  }

  public resumeCurrentExecution(): boolean {
    return this.planStateManager.resumeCurrentExecution();
  }
  /**
   * 用户修改路程时间 (修复保存问题)
   */
  public updateCommute(index: number, newMinutes: number): void {
    if (index < 0 || index >= this.events.length) {
      return;
    }

    this.updateManualCommute(this.events[index], newMinutes);
  }

  public updateManualCommute(item: EventEntity, minutes: number): void {
    this.eventMutationManager.updateManualCommute(item, minutes);
  }

  public async moveEvent(index: number, direction: 'up' | 'down'): Promise<void> {
    await this.eventMutationManager.moveEvent(index, direction);
  }

  public moveAllBacklogToSchedule(): number {
    return this.eventMutationManager.moveAllBacklogToSchedule();
  }

  // 兼容 Backlog 移除逻辑
  public async moveToBacklog(item: TravelPlanItem | EventEntity): Promise<void> {
    await this.eventMutationManager.moveToBacklog(item);
  }
  public async fixConflict(item: TravelPlanItem | EventEntity, shiftMinutes: number) {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][COMPRESS][fixConflict] itemId=${item?.id ?? -1}, shiftMinutes=${shiftMinutes}`
    );
    await this.compressionService.fixConflict(item, shiftMinutes);
  }


  // 文件路径: ets/viewmodel/TimelineViewModel.ets

  /**
   * [节点 3A] 新增地点入库
   */
  public async addNewItem(name: string, duration: number, isSchedule: boolean = false, fixedTime?: string,
    dayOffset: number = 0, preTravel: number = -1, isHardLock: boolean = false, note: string = '', priority: number = 0,
    lat?: number, lng?: number
  ) {
    await this.eventMutationManager.addNewItem(
      name,
      duration,
      isSchedule,
      fixedTime,
      dayOffset,
      preTravel,
      isHardLock,
      note,
      priority,
      lat,
      lng
    );
  }
  public save(): Promise<void> {
    if (this.planId === -1) {
      return Promise.resolve();
    }

    const task = async (): Promise<void> => {
      const payload = this.events.map(e => e.toInterface());
      const idPreview = payload.map(item => item.id || -1).slice(0, 20).join(',');
      const idSuffix = payload.length > 20 ? `...(+${payload.length - 20})` : '';
      hilog.info(0x0000, TAG, `[ID_FIX][VM_SAVE_TRIGGER] planId=${this.planId} count=${payload.length} ids=[${idPreview}]${idSuffix}`);
      await EventRepositoryImpl.saveAllEvents(this.planId, payload);
    };

    const queued = this.saveQueue.then(task);
    this.saveQueue = queued.catch(() => {
      hilog.error(0x0000, TAG, '[ID_FIX][VM_SAVE_QUEUE_FAIL] reason=queued_save_failed');
    });
    return queued;
  }

  public async persistPlanStartDate(planId: number, startDate: number): Promise<void> {
    await this.persistence.updatePlanStartDate(planId, startDate);
  }

  public async persistPlanName(planId: number, name: string): Promise<void> {
    await this.persistence.updatePlanName(planId, name);
  }

  // TimelineViewModel.ets 内部修改/替换原有冲突处理方法

  /**
   *
   */
  public async resolveConflictByBacklog(id: number, name: string, duration: number, note: string = '', priority: number = 0) {
    await this.eventMutationManager.resolveConflictByBacklog(id, name, duration, note, priority);
  }

  /**
   *
   * 既然该地点早于原计划，我们将计划起点平移到该地点的日期，该地点的 offset 变为 0
   */
  public async resolveConflictByMovingPlan(id: number, targetDateMs: number, name: string, duration: number, isSchedule: boolean,
    fixedTime?: string, note: string = '', priority: number = 0) {
    await this.eventMutationManager.resolveConflictByMovingPlan(
      id,
      targetDateMs,
      name,
      duration,
      isSchedule,
      fixedTime,
      note,
      priority
    );
  }

  // path: ets/viewmodel/TimelineViewModel.ets


  /** [测试功能] 强制全量重算所有路线 */
  public testAllCommute() {
    this.recalculationManager.testAllCommute();
  }

  /**
   *
   */
  public updateTravelMode(item: EventEntity, newMode: number) {
    this.recalculationManager.updateTravelMode(item, newMode);
  }

  public getEffectiveDayOffset(item: EventEntity): number {
    return TimelineDatePolicy.resolveEventDayOffset(item);
  }

  public resolveEffectiveGlobalStartMinutes(): number {
    return this.recalculationManager.resolveEffectiveGlobalStartMinutes();
  }

  public logTimelineSnapshot(scene: string): void {
    this.recalculationManager.logTimelineSnapshot(scene);
  }

  public recalculateFromEventId(eventId: number): void {
    this.recalculationManager.recalculateFromEventId(eventId);
  }

  public recalculateFromIndex(startIndex: number): void {
    this.recalculationManager.recalculateFromIndex(startIndex);
  }

  public recalculate(): void {
    this.recalculationManager.recalculate();
  }

  public getSortedGaps(): EventEntity[] {
    if (!this.idleGapDetectionEnabled) {
      return [];
    }
    const minGap = this.idleGapTriggerMinutes;
    return this.events
      .filter((item: EventEntity) =>
      item.status === 1 &&
      item.has_gap &&
      item.gap_minutes >= minGap &&
      !this.isFirstScheduledItemOfDayForUi(item) &&
      this.isSameDayGapWithPreviousScheduleItemForUi(item))
      .sort((a: EventEntity, b: EventEntity) => b.gap_minutes - a.gap_minutes);
  }

  private isSameDayGapWithPreviousScheduleItemForUi(item: EventEntity): boolean {
    const schedule = TimelineGroupingService.getOrderedScheduleEvents(this.events);
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    if (idx <= 0) {
      return false;
    }
    const prev = schedule[idx - 1];
    return TimelineDatePolicy.resolveEventDayOffset(prev) === TimelineDatePolicy.resolveEventDayOffset(item);
  }

  private isFirstScheduledItemOfDayForUi(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    const schedule = TimelineGroupingService.getOrderedScheduleEvents(this.events);
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    if (idx <= 0) {
      return idx === 0;
    }
    const prev = schedule[idx - 1];
    return TimelineDatePolicy.resolveEventDayOffset(prev) !== TimelineDatePolicy.resolveEventDayOffset(item);
  }


  private generateGroups() {
    this.groupedEvents = TimelineGroupingService.generateGroups(
      this.events,
      this.planStartDate,
      this.filterStart,
      this.filterEnd,
      (event) => this.getEffectiveDayOffset(event)
    );
  }


  /**
   * [交互升级] 物理删除 (右滑)
   * 彻底从数据库移除
   */
  public async hardDelete(item: EventEntity) {
    await this.eventMutationManager.hardDelete(item);
  }

  // 文件路径: ets/viewmodel/TimelineViewModel.ets

  /**
   * [节点 3B] 更新地点入库
   */
  public async updateEventInfo(id: number, name: string, duration: number, fixedTime?: string, dayOffset: number = 0,
    isHardLock: boolean = false, note: string = '', priority: number = 0,
    lat?: number, lng?: number
  ) {
    await this.eventMutationManager.updateEventInfo(
      id,
      name,
      duration,
      fixedTime,
      dayOffset,
      isHardLock,
      note,
      priority,
      lat,
      lng
    );
  }

  public previewPlanDateShift(newDateTimestamp: number): PlanDateShiftPreview {
    return this.planStateManager.previewPlanDateShift(newDateTimestamp);
  }
  /**
   * [Priority 4] 修改计划出发日期 (整体平移)
   */
  public async updatePlanDate(newDateTimestamp: number) {
    await this.planStateManager.updatePlanDate(newDateTimestamp);
  }

  /**
   *
   */
  public async renamePlan(newName: string) {
    await this.planStateManager.renamePlan(newName);
  }



  /**
   *
   *
   */
  public isDateConflict(targetDateMs: number): boolean {
    return this.planStateManager.isDateConflict(targetDateMs);
  }

  public async refreshPlanningWeather(forceRefresh: boolean = false): Promise<void> {
    await this.weatherCoordinator.refreshPlanningWeather(forceRefresh);
  }

  public async applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void> {
    await this.weatherCoordinator.applyPlanningWeatherResult(result, forceRefresh);
  }
  public isExecutionWeatherStage(): boolean {
    return this.weatherCoordinator.isExecutionWeatherStage();
  }

  public startExecutionWeatherScheduler(_planId?: number, stage?: WeatherStageType): void {
    this.weatherCoordinator.startExecutionWeatherScheduler(_planId, stage);
  }

  public stopExecutionWeatherScheduler(): void {
    this.weatherCoordinator.stopExecutionWeatherScheduler();
  }

  public async refreshExecutionWeather(
    forceRefresh: boolean = false,
    trigger: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL' = 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void> {
    hilog.info(0x0000, TAG, `[ACPT][WEATHER][refreshExecution] forceRefresh=${forceRefresh}, trigger=${trigger}, stage=${stage ?? 'auto'}`);
    await this.weatherCoordinator.refreshExecutionWeather(forceRefresh, trigger, stage);
  }
  public async requestSoftReplan(
    planId: number,
    suggestionId: string,
    mode: SoftReplanMode
  ): Promise<SoftReplanApplyResult> {
    hilog.info(0x0000, TAG, `[ACPT][WEATHER][softReplan] planId=${planId}, suggestionId=${suggestionId}, mode=${mode}`);
    return this.weatherCoordinator.requestSoftReplan(planId, suggestionId, mode);
  }

  public dismissExecutionSuggestion(suggestionId: string): void {
    this.weatherCoordinator.dismissExecutionSuggestion(suggestionId);
  }

  public async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    return this.weatherCoordinator.applyWeatherSuggestion(suggestionId);
  }

  public async resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source: 'add' | 'update' = 'add',
    fallbackLat: number = 0,
    fallbackLng: number = 0
  ): Promise<GeoPointInput> {
    return this.weatherCoordinator.resolveCoordinatesForPlaceName(placeName, lat, lng, source, fallbackLat, fallbackLng);
  }

  public isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return this.weatherCoordinator.isCoordinateMissingForWeather(latitude, longitude);
  }

  public isValidCoordinate(latitude: number, longitude: number): boolean {
    return this.weatherCoordinator.isValidCoordinate(latitude, longitude);
  }

  /**
   * [新增] AI 智能生成入口
   */
  public async generateByAi(userPrompt: string, strategyMode: number = 0, customStrategy?: ComposableStrategy) {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][AI][generateByAi] strategyMode=${strategyMode}, custom=${customStrategy ? 'yes' : 'no'}, promptLen=${userPrompt.length}`
    );
    await this.strategyManager.generateByAi(userPrompt, strategyMode, customStrategy);
  }

  public getStrategyMode(): number {
    return this.strategyManager.getStrategyMode();
  }

  public hasAiHistory(): boolean {
    return this.strategyManager.hasAiHistory();
  }

  public async updateStrategyMode(mode: number): Promise<void> {
    await this.strategyManager.updateStrategyMode(mode);
  }

  public async switchToCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await this.strategyManager.switchToCustomStrategy(strategy);
  }

  public async applyWeatherStrategyAdjustment(
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<boolean> {
    return this.strategyManager.applyWeatherStrategyAdjustment(adjustment, hint);
  }

  public async applyExecutionSuggestionWithStrategy(
    planId: number,
    suggestionId: string,
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    hilog.info(
      0x0000,
      TAG,
      `[ACPT][AI][applyExecutionSuggestionWithStrategy] planId=${planId}, suggestionId=${suggestionId}, hasAdjustment=${adjustment ? 'yes' : 'no'}, hintLen=${hint?.length ?? 0}`
    );
    return this.strategyManager.applyExecutionSuggestionWithStrategy(planId, suggestionId, adjustment, hint);
  }

  public async getCurrentStrategy(): Promise<ComposableStrategy> {
    return this.strategyManager.getCurrentStrategy();
  }

  public clampStrategyLevel(value: number): 0 | 1 | 2 {
    return this.strategyManager.clampStrategyLevel(value);
  }

  public composeWeatherConstraintPrompt(
    weatherAwareConstraint: string,
    weatherSummary: string
  ): string {
    return this.strategyManager.composeWeatherConstraintPrompt(weatherAwareConstraint, weatherSummary);
  }

  private buildWeatherStrategyAdaptationKey(generatedAt: number, routeScore: number): string {
    return this.strategyManager.buildWeatherStrategyAdaptationKey(generatedAt, routeScore);
  }

  public async regenerateWithCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await this.strategyManager.regenerateWithCustomStrategy(strategy);
  }

  public async regenerateByCurrentStrategy(): Promise<void> {
    await this.strategyManager.regenerateByCurrentStrategy();
  }

  public async changeStrategyAndRegenerate(mode: number): Promise<void> {
    await this.strategyManager.changeStrategyAndRegenerate(mode);
  }



  // 修改点：完全重构 findCurrentActiveEvent，改用绝对时间戳判定
  public findCurrentActiveEvent(): EventEntity | null {
    return this.executionService.findCurrentActiveEvent();
  }

  // =========================================================

  // =========================================================

  /**
   *
   */
  public async skipEvent(item: EventEntity) {
    hilog.info(0x0000, TAG, `[ACPT][EXEC][skipEvent] itemId=${item?.id ?? -1}, name=${item?.name ?? ''}`);
    await this.executionService.skipEvent(item);
  }

  public async reopenSkippedEvent(id: number): Promise<boolean> {
    return this.executionService.reopenSkippedEvent(id);
  }


  // 修改点：重构 calculateRealtimeSchedule 循环内部逻辑
  public calculateRealtimeSchedule() {
    hilog.info(0x0000, TAG, `[ACPT][EXEC][calculateRealtimeSchedule] events=${this.events.length}`);
    this.executionService.calculateRealtimeSchedule();
  }

  public async checkOutEvent(item: EventEntity) {
    hilog.info(0x0000, TAG, `[ACPT][EXEC][checkOutEvent] itemId=${item?.id ?? -1}, name=${item?.name ?? ''}`);
    await this.executionService.checkOutEvent(item);
  }

  public async recordStartTime(item: EventEntity) {
    hilog.info(0x0000, TAG, `[ACPT][EXEC][recordStartTime] itemId=${item?.id ?? -1}, name=${item?.name ?? ''}`);
    await this.executionService.recordStartTime(item);
  }




  /**
   *
   */
  public async updateActualTime(id: number, field: 'actual_start_time' | 'actual_end_time', timestamp: number): Promise<boolean> {
    hilog.info(0x0000, TAG, `[ACPT][EXEC][updateActualTime] id=${id}, field=${field}, timestamp=${timestamp}`);
    return this.executionService.updateActualTime(id, field, timestamp);
  }

  public async getStartConflictInfo(excludeEventId: number): Promise<StartConflictInfo | null> {
    hilog.info(0x0000, TAG, `[ACPT][EXEC][getStartConflictInfo] excludeEventId=${excludeEventId}`);
    return this.executionService.getStartConflictInfo(excludeEventId);
  }


  private async reloadGlobalRouteApiSwitch(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      this.enableGlobalAmapRouteApi = await pref.isAmapRouteApiEnabled();
    } catch (error) {
      this.enableGlobalAmapRouteApi = false;
      hilog.warn(0x0000, TAG, `[SETTING_VM][amap_api_switch_fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public async reloadRouteSwitches(): Promise<void> {
    await this.reloadIdleGapSettings();
    await this.reloadGlobalRouteApiSwitch();
    await this.weatherCoordinator.reloadWeatherUserPreference();
  }

  public getWeatherUserPreference(): WeatherUserPreference {
    return {
      heatSensitivity: this.weatherUserPreference.heatSensitivity,
      rainSensitivity: this.weatherUserPreference.rainSensitivity,
      weatherRiskTolerance: this.weatherUserPreference.weatherRiskTolerance
    };
  }

  public isWeatherFeatureEnabled(): boolean {
    return this.weatherFeatureEnabled;
  }

  public buildWeatherScoreExplanation(score: number): string {
    if (!Number.isFinite(score) || score < 0) {
      return '暂无可用天气评分。评分范围 0-100，分值越高代表路线受天气影响越小。';
    }
    const safeScore = Math.max(0, Math.min(100, Math.floor(score)));
    let level = '低风险';
    let desc = '天气条件较稳定，可按当前计划执行。';
    if (safeScore < 70) {
      level = '高风险';
      desc = '天气对路线影响明显，建议优先室内点位或减少暴露时长。';
    } else if (safeScore < 85) {
      level = '中风险';
      desc = '部分节点受天气影响，建议关注时段变化并准备替代方案。';
    }
    const riskMeaning = safeScore < 70
      ? '含义：后续节点更容易发生顺序变化、停留压缩或替代建议。'
      : (safeScore < 85
        ? '含义：计划可执行，但部分时段可能触发轻量调整。'
        : '含义：总体稳定，通常不需要对行程做结构性改动。');
    return `天气评分：${safeScore}\n等级：${level}\n区间：0-69 高风险，70-84 中风险，85-100 低风险。\n说明：评分会综合降雨/温度风险、你的怕热/怕雨/风险容忍偏好，以及多日多城协同结果。\n${riskMeaning}\n建议：${desc}`;
  }

  public buildWeatherHintExplanation(): string {
    const sourceText = this.executionWeatherDisplaySource === 'CURRENT'
      ? '当前定位天气'
      : (this.executionWeatherDisplaySource === 'NEXT_FALLBACK' ? '下一节点天气估算' : '当前定位缺失');
    const hint = this.executionWeatherHint && this.executionWeatherHint.trim().length > 0
      ? this.executionWeatherHint
      : this.weatherPlanningHint;
    const safeHint = hint && hint.trim().length > 0 ? hint : '当前暂无额外天气提示。';
    const collab = this.weatherCollabSummary && this.weatherCollabSummary.trim().length > 0
      ? this.weatherCollabSummary
      : this.executionWeatherCollabSummary;
    const collabExplain = collab && collab.trim().length > 0
      ? `多日/多城说明：${collab}\n作用：表示系统在跨城市、跨日期对天气趋势做了联合评估，用于提前发现“后续转差/转好”。`
      : '多日/多城说明：当前无跨日跨城协同摘要。';
    return `提示来源：${sourceText}\n当前提示：${safeHint}\n${collabExplain}\n该提示仅用于辅助决策，不会自动修改行程。`;
  }

  public buildPlanningWeatherHintExplanation(): string {
    const sourceText = '计划节点天气（已按地点批量计算）';
    const safeHint = this.weatherPlanningHint && this.weatherPlanningHint.trim().length > 0
      ? this.weatherPlanningHint
      : '当前暂无额外天气提示。';
    const collabExplain = this.weatherCollabSummary && this.weatherCollabSummary.trim().length > 0
      ? `多日/多城说明：${this.weatherCollabSummary}\n作用：用于提前判断跨日跨城趋势变化，减少后续被动改计划。`
      : '多日/多城说明：当前无跨日跨城协同摘要。';
    return `提示来源：${sourceText}\n当前提示：${safeHint}\n${collabExplain}\n该提示仅用于辅助决策，不会自动修改行程。`;
  }

  public getExecutionWeatherDisplaySource(): 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' {
    return this.executionWeatherDisplaySource;
  }

  public shouldAutoRefreshPlanningWeather(maxAgeMs: number = 24 * 60 * 60 * 1000): boolean {
    return this.weatherCoordinator.shouldAutoRefreshPlanningWeather(maxAgeMs);
  }

  public async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    await this.weatherCoordinator.setWeatherFeatureEnabled(enabled);
  }

  public async updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    await this.weatherCoordinator.updateWeatherUserPreference(preference);
  }

  public isAutoRouteEnabled(): boolean {
    return this.enableAutoAmapRoute && this.enableGlobalAmapRouteApi;
  }

  public getOrderedScheduleEvents(): EventEntity[] {
    return this.executionCoordinator.getOrderedScheduleEvents();
  }

  public getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    return this.executionCoordinator.getOrderedScheduleIndexById(eventId, schedule);
  }

  public getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    return this.executionCoordinator.getNextExecutableEvent(afterId, schedule);
  }

  public buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    return this.executionCoordinator.buildReflowHint(action, beforeTs, afterTs, targetName, nextName);
  }

  public _calculateNaturalArrival(targetIndex: number): number {
    return this.compressionCoordinator.calculateNaturalArrival(targetIndex);
  }

  public calculateDelayPlan(targetIndex: number): CompressionPlan {
    return this.compressionCoordinator.calculateDelayPlan(targetIndex);
  }

  public buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null {
    return this.compressionCoordinator.buildAdvanceAdjustContext(targetIndex);
  }

  public async applyAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string
  ): Promise<AdvanceAdjustApplyResult> {
    return this.compressionCoordinator.applyAdvanceAdjust(targetIndex, selectedIds, targetStartTime);
  }

  public buildCompressionSelectionContext(targetIndex: number, targetTime: string): CompressionSelectionContext | null {
    return this.compressionCoordinator.buildCompressionSelectionContext(targetIndex, targetTime);
  }

  public calculateCompressionPlanBySelection(
    targetIndex: number,
    targetTime: string,
    selectedIds: Set<number>,
    mode: CompressionMode
  ): CompressionPlan {
    return this.compressionCoordinator.calculateCompressionPlanBySelection(targetIndex, targetTime, selectedIds, mode);
  }

  public applyCompressionPlan(plan: CompressionPlan): void {
    this.compressionCoordinator.applyCompressionPlan(plan);
  }

  public getCurrentPlanHistorySummary(): HistoryTimelineSummary {
    return this.historyManager.getCurrentPlanHistorySummary();
  }

  public getCurrentPlanHistoryTimelineItems(abnormalThresholdMinutes: number = 10): HistoryTimelineItem[] {
    return this.historyManager.getCurrentPlanHistoryTimelineItems(abnormalThresholdMinutes);
  }

  public getAllPlaceCheckinSummaries(): PlaceCheckinSummary[] {
    return TimelineGroupingService.getAllPlaceCheckinSummaries(this.events);
  }


  public getPlaceCheckinSummary(placeName: string): PlaceCheckinSummary {
    return TimelineGroupingService.getPlaceCheckinSummary(this.events, placeName);
  }

  public getCompanionContext(nowTs: number = Date.now()): CompanionContext {
    return this.companionManager.getCompanionContext(nowTs);
  }

  public getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    return this.companionManager.getRealActiveEvent(schedule);
  }

  public isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return this.executionCoordinator.isFirstScheduledItemOfDay(item);
  }

  private insertSmart(newEntity: EventEntity): void {
    this.eventMutationManager.insertSmartForCompat(newEntity);
  }
}
