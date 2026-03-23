// 文件路径: ets/viewmodel/TimelineViewModel.ets
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { ActiveEventSnapshot, EventFieldUpdate } from '../infrastructure/persistence/EventRepositoryImpl';
import { EventRepositoryImpl } from '../infrastructure/persistence/EventRepositoryImpl';
import { EventEntity } from '../model/entity/EventEntity'; // 引入 Entity
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../common/utils/DateUtil';
import { TimelineDatePolicy } from '../domain/policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../domain/policy/TimelineExecutionState';
import { AiService } from '../infrastructure/services/AiService';
import { ComposableStrategy } from '../domain/strategy/TravelStrategyDimensions';
import { PlanRepositoryImpl } from '../infrastructure/persistence/PlanRepositoryImpl';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { ScheduleOrchestrator } from './internal/ScheduleOrchestrator';
import { PlanPersistenceFacade } from './internal/PlanPersistenceFacade';
import { ReminderFacade } from './internal/ReminderFacade';
import { ConflictDetector } from '../domain/timeline/ConflictDetector';
import { CompressionEngine } from '../domain/timeline/CompressionEngine';
import { HistoryManager } from '../domain/timeline/HistoryManager';
import { TimelineGroupingService, DateGroup, PlaceCheckinSummary, PlaceCheckinRecord } from '../domain/timeline/services/TimelineGroupingService';
import { TimelineCalculationService } from '../domain/timeline/services/TimelineCalculationService';
import { TimelineConflictResolver } from '../domain/timeline/services/TimelineConflictResolver';
import { StrategyPresets } from '../domain/strategy/StrategyPresets';
import { TravelStrategyMode } from '../domain/strategy/TravelStrategyMode';
import { StrategyService } from '../domain/strategy/StrategyService';
import { UserProfileService } from '../domain/strategy/UserProfileService';
import { UserBehaviorTracker } from '../domain/strategy/UserBehaviorTracker';
import { StrategyAdaptationEngine, AdaptationPrompt } from '../domain/strategy/StrategyAdaptationEngine';
import { WeatherFacade } from '../domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../domain/services/WeatherRefreshScheduler';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  ReplanChangeSummaryItem,
  SoftReplanApplyResult,
  SoftReplanMode,
  SoftReplanPreview,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherSuggestionActionType,
  WeatherUserPreference
} from '../domain/services/WeatherModels';
import { ArrivalReminderEngine } from '../infrastructure/services/ArrivalReminderEngine';
import { WeatherReminderStore, WeatherStrategyAdjustment } from '../common/utils/weather/WeatherReminderStore';
import { AmapService } from '../infrastructure/services/AmapService';
import { PlanStateMachine } from '../domain/statemachine/PlanStateMachine';
import { PlanStatus, TransitionTriggerSource } from '../domain/statemachine/PlanStatus';
import { PlanTransitionEvent } from '../domain/statemachine/ExecutionContext';
import { LocationChangeEvent } from '../domain/statemachine/StateEventBus';

// 重新导出类型以保持向后兼容
export { DateGroup, PlaceCheckinSummary, PlaceCheckinRecord };

interface GeneratedTypeLiteralInterface_7 {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

export interface CompressionPlan {

  status: 'NO_ACTION' | 'COMPRESS_CONFIRM' | 'OVERLOAD' | 'FAIL_TOO_SHORT';
  msg: string;
  affectedItems: GeneratedTypeLiteralInterface_7[];
  suggestedTime?: string;
  remainingGapMinutes?: number;
  capacityMinutes?: number;
  mode?: CompressionMode;
}

export type CompressionMode = 'EQUAL' | 'RATIO';

export interface CompressionSelectionCandidate {
  index: number;
  id: number;
  name: string;
  oldVal: number;
  minAllowed: number;
  maxReducible: number;
  isRigid: boolean;
  selectable: boolean;
  disabledReason?: string;
}

export interface CompressionSelectionContext {
  targetIndex: number;
  targetTime: string;
  neededGapMinutes: number;
  naturalArrivalMinutes: number;
  chainStartIndex: number;
  candidates: CompressionSelectionCandidate[];
}

export interface PlanDateShiftPreview {
  hasRigidConflict: boolean;
  conflictItemId: number;
  conflictItemName: string;
  gapMinutes: number;
  conflictMsg: string;
}

export interface SameDayShiftAffectedItem {
  id: number;
  name: string;
  oldTime: string;
  newTime: string;
  index: number;
}

export interface SameDayFixedShiftPreview {
  targetItemId: number;
  targetIndex: number;
  targetDayOffset: number;
  requestedShiftMinutes: number;
  appliedShiftMinutes: number;
  remainingGapMinutes: number;
  affectedItems: SameDayShiftAffectedItem[];
  message: string;
}

export interface SameDayFixedShiftApplyResult {
  appliedShiftMinutes: number;
  remainingGapMinutes: number;
  affectedCount: number;
}

export type HistoryTimelineFilter = 'all' | 'completed' | 'skipped' | 'abnormal';
export type HistoryTimelineActionType = 'ARRIVE' | 'LEAVE' | 'SKIP' | 'ACTIVE';

export interface HistoryTimelineItem {
  id: number;
  eventId: number;
  placeName: string;
  actionType: HistoryTimelineActionType;
  plannedStart: number;
  actualStart: number;
  actualEnd: number;
  stayMinutes: number;
  deviationMinutes: number;
  status: number;
  groupDateKey: string;
  address: string;
  note: string;
  displayTs: number;
  isAbnormal: boolean;
}

export interface HistoryTimelineSummary {
  planName: string;
  completedCount: number;
  skippedCount: number;
  activeCount: number;
}

export type CompanionRuntimeState = 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP';

export interface ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed';
  minutesDelta: number;
  message: string;
  updatedAt: number;
}

export interface CompanionActions {
  canStart: boolean;
  canPause: boolean;
  canResume: boolean;
  canEnd: boolean;
  canSkip: boolean;
  canNavigate: boolean;
  canViewDetail: boolean;
}

export interface ExecutionSuggestionApplyResult {
  strategyApplied: boolean;
  replanSuccess: boolean;
  errorCode: string;
}

export interface CompanionContext {
  runtimeState: CompanionRuntimeState;
  currentEvent: EventEntity | null;
  nextEvent: EventEntity | null;
  hint: ReflowHint | null;
  actions: CompanionActions;
}

export interface StartConflictInfo {
  eventId: number;
  planId: number;
  name: string;
  actualStartTime: number;
}

const TAG = 'TimelineViewModel';


interface GeneratedTypeLiteralInterface_5 {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

interface GeneratedTypeLiteralInterface_6 {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

export interface SolverCalculatedItem {
  isConflict?: boolean;
  conflictMsg?: string;
  computedStartTime?: string;
  preTravelMinutes?: number;
  hasGap?: boolean;
  gapMinutes?: number;
  naturalStartTime?: string;
  transitWarning?: boolean;
  dynamicDayOffset?: number;
  dayOffset?: number;
  dynamicStartTime?: number;
  dynamicEndTime?: number;
}

export interface ApplyResultFlags {
  changed: boolean;
  dayOffsetChanged: boolean;
}

interface ActualTimeMutationMeta {
  beforeNextTs: number;
  beforeNextName: string;
}

interface RuntimeMotionSnapshot {
  latitude: number;
  longitude: number;
  speed?: number;
  accuracy?: number;
  ts: number;
}

interface ReplanNodeSnapshot {
  id: number;
  sortOrder: number;
  duration: number;
  startTs: number;
  endTs: number;
}

interface DemoPlanTemplateItem {
  name: string;
  duration: number;
  isSchedule: boolean;
  fixedTime: string;
  dayOffset: number;
  note: string;
  priority: number;
  latitude: number;
  longitude: number;
}

interface PlanningWeatherSnapshot {
  hint: string;
  score: number;
  collabSummary: string;
  strategyHint: string;
  refreshedAt: number;
}


@Observed
export class TimelineViewModel {
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
  
  private hasLoggedLifecycleDetach: boolean = false;
  private actualTimeMutationInFlight: boolean = false;
  private hasUnsavedPostponeStorageKey: string = AppStorageKeys.HAS_UNSAVED_POSTPONE;
  private minEventDurationLimit: number = 30;
  private readonly scheduleOrchestrator: ScheduleOrchestrator = new ScheduleOrchestrator();
  private readonly persistence: PlanPersistenceFacade = new PlanPersistenceFacade();
  private readonly reminderFacade: ReminderFacade = new ReminderFacade();
  @Track private idleGapDetectionEnabled: boolean = true;
  @Track private idleGapTriggerMinutes: number = 45;
  private currentStrategyMode: number = 0;
  private isRegenerating: boolean = false;  // AI重新生成锁
  private behaviorTracker: UserBehaviorTracker = new UserBehaviorTracker();
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
  private readonly weatherFacade: WeatherFacade = new WeatherFacade();
  private readonly weatherRefreshScheduler: WeatherRefreshScheduler = new WeatherRefreshScheduler();
  private readonly planStateMachine: PlanStateMachine = PlanStateMachine.getInstance();
  private planStateUnsubscribe: (() => void) | null = null;
  private planLocationChangeUnsubscribe: (() => void) | null = null;
  @Track private currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  private stateEvaluationTimerId: number = -1;
  private readonly stateEvaluationIntervalMs: number = 60 * 1000;
  private readonly runtimeMotionSamples: RuntimeMotionSnapshot[] = [];
  private readonly runtimeMotionSampleLimit: number = 3;
  private executionWeatherLastLocation: GeoPointInput | null = null;
  private executionWeatherLastEmitAt: number = 0;
  private weatherStrategyAppliedKey: string = '';
  private readonly executionWeatherLocationDeltaMeters: number = 120;
  private readonly executionWeatherLocationTriggerCooldownMs: number = 5 * 60 * 1000;
  private executionWeatherLastLocationTriggerAt: number = 0;
  private currentWeatherSchedulePolicy: WeatherSchedulePolicy = {
    stage: 'IN_PROGRESS',
    pollIntervalMs: 20 * 60 * 1000,
    allowLocationTrigger: true,
    allowManualBypass: true,
    forceRefreshOnEnter: true
  };
  private readonly executionSuggestionCooldownMs: number = 30 * 60 * 1000;
  private readonly executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  private readonly executionSuggestionMap: Map<string, WeatherSuggestion> = new Map<string, WeatherSuggestion>();
  private executionReplanBusy: boolean = false;
  private readonly weatherCollabOptions: WeatherCollabOptions = {
    enableMultiDay: true,
    enableMultiCity: true
  };

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

  private markScheduleChanged(): void {
    this.scheduleVersion += 1;
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

  private markHasUnsavedPostpone(): void {
    AppStorage.setOrCreate(this.hasUnsavedPostponeStorageKey, true);
  }

  private async applyRuntimeTransition(target: EventEntity, transition: 'START' | 'END' | 'SKIP' | 'REOPEN', timestamp: number): Promise<boolean> {
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

  public isIdleGapDetectionEnabled(): boolean {
    return this.idleGapDetectionEnabled;
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
      this.restorePlanningWeatherSnapshot(planId);

      await this.reloadMinEventDurationLimit();
      await this.reloadIdleGapSettings();
      await this.reloadGlobalRouteApiSwitch();
      await this.reloadWeatherUserPreference();
      this.recalculate();
      this.bindPlanState(planId);
    } catch (err) {
      hilog.error(0x0000, TAG, `Load data failed: ${JSON.stringify(err)}`);
    }
  }
  public bindPlanState(planId: number): void {
    if (planId <= 0) {
      return;
    }
    this.unbindPlanState();
    const planIdStr = `${planId}`;
    this.currentPlanStatus = this.planStateMachine.getPlanStatus(planIdStr).status;
    this.planStateUnsubscribe = this.planStateMachine.subscribePlanTransition(planIdStr, (event: PlanTransitionEvent) => {
      this.currentPlanStatus = event.toStatus;
      this.handlePlanStateChanged(event.toStatus, event);
    });
    this.planLocationChangeUnsubscribe = this.planStateMachine.subscribeLocationChange(planIdStr, (event: LocationChangeEvent) => {
      this.handlePlanLocationChanged(event);
    });
    this.stateEvaluationTimerId = setInterval(() => {
      this.evaluatePlanStatusByRuntime();
    }, this.stateEvaluationIntervalMs);
    this.recoverPlanRuntimeState();
    this.syncPlanStatusAfterLoad();
    this.handlePlanStateChanged(this.currentPlanStatus);
  }

  public unbindPlanState(): void {
    if (this.planStateUnsubscribe) {
      this.planStateUnsubscribe();
      this.planStateUnsubscribe = null;
    }
    if (this.planLocationChangeUnsubscribe) {
      this.planLocationChangeUnsubscribe();
      this.planLocationChangeUnsubscribe = null;
    }
    if (this.stateEvaluationTimerId !== -1) {
      clearInterval(this.stateEvaluationTimerId);
      this.stateEvaluationTimerId = -1;
    }
  }

  public getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  private syncPlanStatusAfterLoad(): void {
    if (this.planId <= 0) {
      return;
    }
    const planIdStr = `${this.planId}`;
    const scheduled = this.events.filter((item: EventEntity) => item.status === 1);
    const allCompleted = scheduled.length > 0 && scheduled.every((item: EventEntity) => item.completion_status === EventEntity.STATE_COMPLETED);

    if (allCompleted) {
      this.planStateMachine.completeExecution(planIdStr);
      this.currentPlanStatus = this.planStateMachine.getPlanStatus(planIdStr).status;
      return;
    }

    if (scheduled.length > 0) {
      this.planStateMachine.confirmPlan(planIdStr);
      this.currentPlanStatus = this.planStateMachine.getPlanStatus(planIdStr).status;
      this.evaluatePlanStatusByRuntime();
      this.currentPlanStatus = this.planStateMachine.getPlanStatus(planIdStr).status;
    }
  }

  private evaluatePlanStatusByRuntime(): void {
    if (this.planId <= 0) {
      return;
    }
    const planIdStr = `${this.planId}`;
    const locationSnapshot = ArrivalReminderEngine.getInstance().getLastKnownLocation();
    if (locationSnapshot) {
      this.onLocationSampleForStateMachine(
        locationSnapshot.latitude,
        locationSnapshot.longitude,
        locationSnapshot.speed,
        locationSnapshot.accuracy,
        locationSnapshot.timestamp
      );
    }
    const input = this.planStateMachine.buildEvaluationInput(planIdStr, this.events, Date.now());
    this.planStateMachine.evaluateAndApply(input);
    this.currentPlanStatus = this.planStateMachine.getPlanStatus(planIdStr).status;
  }

  private handlePlanStateChanged(status: PlanStatus, _event?: PlanTransitionEvent): void {
    if (!this.weatherFeatureEnabled) {
      this.stopExecutionWeatherScheduler();
      return;
    }
    const stage = this.resolveCurrentWeatherStage();
    if (status === PlanStatus.CONFIRMED || status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED) {
      this.startExecutionWeatherScheduler(this.planId, stage);
      return;
    }
    if (status === PlanStatus.COMPLETED || status === PlanStatus.CANCELLED || status === PlanStatus.EXPIRED || status === PlanStatus.DRAFT) {
      this.stopExecutionWeatherScheduler();
      if (status === PlanStatus.COMPLETED || status === PlanStatus.CANCELLED || status === PlanStatus.EXPIRED) {
        this.executionWeatherHint = '';
        this.executionWeatherSuggestions = [];
      }
    }
  }

  private resolveCurrentWeatherStage(): WeatherStageType {
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
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return;
    }
    this.runtimeMotionSamples.push({
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accuracy: accuracy,
      ts: sampleTs
    });
    if (this.runtimeMotionSamples.length > this.runtimeMotionSampleLimit) {
      this.runtimeMotionSamples.splice(0, this.runtimeMotionSamples.length - this.runtimeMotionSampleLimit);
    }
    if (this.planId <= 0) {
      return;
    }
    let motionDistance = 0;
    if (this.runtimeMotionSamples.length >= 2) {
      const first = this.runtimeMotionSamples[0];
      const last = this.runtimeMotionSamples[this.runtimeMotionSamples.length - 1];
      motionDistance = this.measureDistanceMeters(first.latitude, first.longitude, last.latitude, last.longitude);
    }
    this.planStateMachine.updateExecutionContext({
      planId: `${this.planId}`,
      lastKnownLatitude: latitude,
      lastKnownLongitude: longitude,
      lastKnownSpeed: speed,
      lastKnownAccuracy: accuracy,
      distanceToFirstNodeMeters: motionDistance,
      updatedAt: sampleTs
    });
  }

  private handlePlanLocationChanged(_event: LocationChangeEvent): void {
    if (!this.weatherFeatureEnabled || !this.executionWeatherEnabled) {
      return;
    }
    const stage = this.resolveCurrentWeatherStage();
    const policy = this.weatherFacade.resolveSchedulePolicy(stage);
    if (!policy.allowLocationTrigger) {
      return;
    }
    if (!(stage === 'READY' || stage === 'IN_PROGRESS' || stage === 'PAUSED')) {
      return;
    }
    void this.refreshExecutionWeather(false, 'LOCATION_CHANGE', stage);
  }

  public recoverPlanRuntimeState(): void {
    if (this.planId <= 0) {
      return;
    }
    const planIdStr = `${this.planId}`;
    const ctx = this.planStateMachine.getExecutionContext(planIdStr);
    const now = Date.now();
    if (!ctx) {
      this.planStateMachine.markRecovery(planIdStr, false, 'context_missing');
      this.evaluatePlanStatusByRuntime();
      this.planStateMachine.markRecovery(planIdStr, true, 'context_rebuild');
      return;
    }
    if (ctx.plannedEndTime > 0 && now > ctx.plannedEndTime && ctx.status !== PlanStatus.COMPLETED && ctx.status !== PlanStatus.CANCELLED && ctx.status !== PlanStatus.EXPIRED) {
      this.planStateMachine.markRecovery(planIdStr, false, 'context_expired');
    }
    if ((ctx.status === PlanStatus.IN_PROGRESS || ctx.status === PlanStatus.PAUSED) &&
      (!ctx.currentNodeId || ctx.currentNodeId.trim().length === 0)) {
      this.planStateMachine.markRecovery(planIdStr, false, 'context_partial');
    }
    this.currentPlanStatus = ctx.status;
    this.evaluatePlanStatusByRuntime();
    this.planStateMachine.markRecovery(planIdStr, true, 'context_restored');
    const latest = this.planStateMachine.getPlanStatus(planIdStr).status;
    if (latest !== ctx.status) {
      this.handlePlanStateChanged(latest, {
        planId: planIdStr,
        fromStatus: ctx.status,
        toStatus: latest,
        triggerSource: TransitionTriggerSource.SYSTEM_RECOVERY,
        triggerReason: 'recovery_re_evaluated',
        timestamp: now
      });
    }
  }

  public pauseCurrentExecution(): boolean {
    if (this.planId <= 0) {
      return false;
    }
    const planIdStr = `${this.planId}`;
    const result = this.planStateMachine.pauseExecution(planIdStr);
    if (!result.success) {
      return false;
    }
    this.currentPlanStatus = result.toStatus;
    this.handlePlanStateChanged(result.toStatus, result.event);
    return true;
  }

  public resumeCurrentExecution(): boolean {
    if (this.planId <= 0) {
      return false;
    }
    const planIdStr = `${this.planId}`;
    const result = this.planStateMachine.resumeExecution(planIdStr);
    if (!result.success) {
      return false;
    }
    this.currentPlanStatus = result.toStatus;
    this.handlePlanStateChanged(result.toStatus, result.event);
    this.recalculateFromIndex(0);
    this.executionWeatherAppliedSummary = '执行恢复已触发增量重算（reasonCode=resume_recalculate）。';
    this.executionWeatherHint = this.executionWeatherAppliedSummary;
    this.executionWeatherLevel = 'NOTICE';
    void this.refreshExecutionWeather(true, 'ENTER_EXECUTION');
    return true;
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
    if (!item) {
      return;
    }
    const safeMinutes = Math.floor(minutes);
    if (!Number.isFinite(safeMinutes) || safeMinutes <= 0) {
      return;
    }

    item.pre_travel_min = safeMinutes;
    item.is_travel_manual = 1;

    if (item.id) {
      EventRepositoryImpl.updateSingleField(item.id, EventEntity.PRE_TRAVEL_MINUTES, safeMinutes, this.planId);
      EventRepositoryImpl.updateSingleField(item.id, EventEntity.IS_TRAVEL_MANUAL, 1, this.planId);
    }

    this.recalculateFromEventId(item.id);
  }

  public updateDuration(index: number, newDuration: number): void {
    if (index < 0 || index >= this.events.length) {
      return;
    }
    const item = this.events[index];
    item.duration = newDuration;
    this.recalculateFromEventId(item.id);
    if (item.id) {
      EventRepositoryImpl.updateSingleField(item.id, 'duration', newDuration, this.planId);
      void EventRepositoryImpl.updateTimelineConsistency(this.events.map(e => e.toInterface()), this.planId);
    }
  }

  public async moveEvent(index: number, direction: 'up' | 'down'): Promise<void> {
    if (index < 0 || index >= this.events.length) {
      return;
    }
    const source = this.events[index];
    if (source.status !== 1) {
      return;
    }

    const scheduleIndexes: number[] = [];
    this.events.forEach((item, idx) => {
      if (item.status === 1) {
        scheduleIndexes.push(idx);
      }
    });

    const currentSchedulePos = scheduleIndexes.indexOf(index);
    if (currentSchedulePos < 0) {
      return;
    }
    const targetSchedulePos = direction === 'up' ? currentSchedulePos - 1 : currentSchedulePos + 1;
    if (targetSchedulePos < 0 || targetSchedulePos >= scheduleIndexes.length) {
      return;
    }
    const targetIndex = scheduleIndexes[targetSchedulePos];

    const swappedEvents = [...this.events];
    const temp = swappedEvents[index];
    swappedEvents[index] = swappedEvents[targetIndex];
    swappedEvents[targetIndex] = temp;

    let order = 0;
    swappedEvents.forEach((item) => {
      if (item.status !== 1) {
        return;
      }
      item.sort_order = order;
      order += 100;
    });

    await EventRepositoryImpl.updateTimelineConsistency(swappedEvents.map(e => e.toInterface()), this.planId);
    this.events = swappedEvents;
    const recalculateStartIndex = Math.max(Math.min(index, targetIndex) - 1, 0);
    this.recalculateFromIndex(recalculateStartIndex);
  }

  public moveToSchedule(item: TravelPlanItem): void {

    // 我们需要在 this.events 里找到对应的 Entity
    const target = this.events.find(e => e.id === item.id);
    if (target) {
      target.status = 1;

      const scheduleItems = this.events.filter(e => e.status === 1);
      const maxSort = scheduleItems.reduce((max, cur) => cur.sort_order > max ? cur.sort_order : max, 0);
      target.sort_order = maxSort + 100;

      // 清除暂存池可能携带的时间字段，让recalculate重新计算
      target.fixed_start_time = '';
      target.computed_time = '';
      target.dynamic_start_time = 0;
      target.dynamic_end_time = 0;

      if (this.shouldAutoRouteForItem(target)) {
        target.pre_travel_min = -1;
      }

      // 关键修复：按sort_order排序后再重算
      // 日程表地点(status=1)在前，暂存池(status=0)在后
      this.events.sort((a, b) => {
        if (a.status !== b.status) return b.status - a.status; // 降序：1在前，0在后
        return a.sort_order - b.sort_order;
      });

      this.recalculateFromEventId(target.id);

      this.save();
    }
  }

  public moveAllBacklogToSchedule(): number {
    const backlogItems = this.events.filter((event) => event.status !== 1);
    if (backlogItems.length === 0) {
      return 0;
    }

    const scheduleItems = this.events.filter((event) => event.status === 1);
    let maxSort = scheduleItems.reduce((max, cur) => cur.sort_order > max ? cur.sort_order : max, 0);

    backlogItems.forEach((target) => {
      maxSort += 100;
      target.status = 1;
      target.sort_order = maxSort;
      target.fixed_start_time = '';
      target.computed_time = '';
      target.dynamic_start_time = 0;
      target.dynamic_end_time = 0;
      if (this.shouldAutoRouteForItem(target)) {
        target.pre_travel_min = -1;
      }
    });

    this.events.sort((a, b) => {
      if (a.status !== b.status) return b.status - a.status;
      return a.sort_order - b.sort_order;
    });
    this.recalculateFromIndex(0);
    this.save();
    return backlogItems.length;
  }

  // 兼容 Backlog 移除逻辑
  public moveToBacklog(item: TravelPlanItem | EventEntity): void {
    const target = this.events.find(e => e.id === item.id);
    if (target) {
      const previousIndex = this.events.indexOf(target);
      target.status = 0;
      target.sort_order = 0;
      this.recalculateFromIndex(previousIndex > 0 ? previousIndex - 1 : 0);
      this.save();
    }
  }

  public async fixConflict(item: TravelPlanItem | EventEntity, shiftMinutes: number) {
    const updated = await TimelineConflictResolver.fixConflict(this.events, item.id || 0, shiftMinutes, this.planId);
    if (updated) {
      this.recalculateFromEventId(item.id || 0);
    }
  }

  public previewSameDayFixedShiftBeforeTarget(targetIndex: number, requestedShiftMinutes: number): SameDayFixedShiftPreview {
    const target = this.events[targetIndex];
    const safeRequested = Math.max(0, Math.floor(requestedShiftMinutes));
    if (!target || target.status !== 1 || targetIndex <= 0) {
      return {
        targetItemId: target?.id ?? -1,
        targetIndex: targetIndex,
        targetDayOffset: 0,
        requestedShiftMinutes: safeRequested,
        appliedShiftMinutes: 0,
        remainingGapMinutes: safeRequested,
        affectedItems: [],
        message: '未找到可处理的冲突目标'
      };
    }

    const targetDayOffset = this.getEffectiveDayOffset(target);
    const dayStartMin = this.resolveEffectiveGlobalStartMinutes();
    const affectedItems: SameDayShiftAffectedItem[] = [];
    let maxShift = Number.MAX_SAFE_INTEGER;

    for (let i = 0; i < targetIndex; i++) {
      const item = this.events[i];
      if (item.status !== 1 || this.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }
      const fixed = DateUtil.extractPureTime(item.fixed_start_time || '');
      if (!fixed || !DateUtil.isValidTimeString(fixed)) {
        continue;
      }

      const oldMin = DateUtil.timeToMinutes(fixed);
      const itemCap = Math.max(0, oldMin - dayStartMin);
      if (itemCap < maxShift) {
        maxShift = itemCap;
      }

      affectedItems.push({
        id: item.id,
        name: item.name,
        oldTime: fixed,
        newTime: fixed,
        index: i
      });
    }

    if (affectedItems.length === 0) {
      return {
        targetItemId: target.id,
        targetIndex: targetIndex,
        targetDayOffset: targetDayOffset,
        requestedShiftMinutes: safeRequested,
        appliedShiftMinutes: 0,
        remainingGapMinutes: safeRequested,
        affectedItems: [],
        message: '当前 DayX 没有可整体前移的前序固定地点'
      };
    }

    if (maxShift === Number.MAX_SAFE_INTEGER) {
      maxShift = 0;
    }
    const appliedShift = Math.min(safeRequested, Math.max(0, maxShift));
    const remainingGap = Math.max(0, safeRequested - appliedShift);

    for (let i = 0; i < affectedItems.length; i++) {
      const oldMin = DateUtil.timeToMinutes(affectedItems[i].oldTime);
      affectedItems[i].newTime = DateUtil.minutesToTime(oldMin - appliedShift);
    }

    const message = appliedShift > 0
      ? `将同日 ${affectedItems.length} 个前序固定地点整体提前 ${appliedShift} 分钟`
      : '当前 DayX 的前序固定地点已到当天起点，无法继续前移';

    return {
      targetItemId: target.id,
      targetIndex: targetIndex,
      targetDayOffset: targetDayOffset,
      requestedShiftMinutes: safeRequested,
      appliedShiftMinutes: appliedShift,
      remainingGapMinutes: remainingGap,
      affectedItems: affectedItems,
      message: message
    };
  }

  public async applySameDayFixedShiftBeforeTarget(preview: SameDayFixedShiftPreview): Promise<SameDayFixedShiftApplyResult> {
    if (!preview || preview.appliedShiftMinutes <= 0 || preview.affectedItems.length === 0) {
      return {
        appliedShiftMinutes: 0,
        remainingGapMinutes: preview?.remainingGapMinutes ?? 0,
        affectedCount: 0
      };
    }

    let minTouchedIndex = this.events.length;
    for (let i = 0; i < preview.affectedItems.length; i++) {
      const patch = preview.affectedItems[i];
      const target = this.events.find((item) => item.id === patch.id);
      if (!target || target.status !== 1) {
        continue;
      }
      if (this.getEffectiveDayOffset(target) !== preview.targetDayOffset) {
        continue;
      }
      target.fixed_start_time = patch.newTime;
      const idx = this.events.indexOf(target);
      if (idx >= 0 && idx < minTouchedIndex) {
        minTouchedIndex = idx;
      }
      if (target.id > 0) {
        await EventRepositoryImpl.updateSingleField(target.id, 'fixed_start_time', patch.newTime, this.planId);
      }
    }

    if (minTouchedIndex < this.events.length) {
      this.recalculateFromIndex(minTouchedIndex > 0 ? minTouchedIndex - 1 : 0);
      await this.save();
    }

    const target = this.events.find((item) => item.id === preview.targetItemId);
    const remainingGap = target && target.gap_minutes > 0 ? target.gap_minutes : 0;
    return {
      appliedShiftMinutes: preview.appliedShiftMinutes,
      remainingGapMinutes: remainingGap,
      affectedCount: preview.affectedItems.length
    };
  }


  // 文件路径: ets/viewmodel/TimelineViewModel.ets

  /**
   * [节点 3A] 新增地点入库
   */
  public async addNewItem(name: string, duration: number, isSchedule: boolean = false, fixedTime?: string,
    dayOffset: number = 0, preTravel: number = -1, isHardLock: boolean = false, note: string = '', priority: number = 0,
    lat?: number, lng?: number
  ) {

    hilog.info(0x0000, TAG, `[节点3A: 准备新增入库] -> 地点: ${name}, lat: ${lat}, lng: ${lng}`);
    const resolvedCoordinate = await this.resolveCoordinatesForPlaceName(name, lat, lng, 'add');

    const newItemInterface: TravelPlanItem = {
      name: name,
      duration: duration,
      type: fixedTime ? 'ANCHOR' : 'FLOW',
      preTravelMinutes: preTravel,
      sortOrder: 0,
      status: isSchedule ? 1 : 0,
      lockStatus: fixedTime ? (isHardLock ? 1 : 0) : 0,
      fixedStartTime: fixedTime || undefined,
      dayOffset: dayOffset,
      note: note,
      itemType: 0,
      priority: priority,
      isTravelManual: 0,
      source: 0,
      delFlag: 0,
      groupId: 0,
      address: '',
      aiReasoning: '',
      travelMode: 2,
      latitude: resolvedCoordinate.latitude,
      longitude: resolvedCoordinate.longitude
    };

    const newId = await EventRepositoryImpl.insertEvent(this.planId, newItemInterface);
    newItemInterface.id = newId;

    const newEntity = EventEntity.fromInterface(newItemInterface, this.planId);
    if (isSchedule) {
      this.insertSmart(newEntity);
      if (newEntity.pre_travel_min < 0 && !this.shouldAutoRouteForItem(newEntity)) {
        newEntity.pre_travel_min = 0;
      }
    } else {
      this.events.push(newEntity);
    }

    this.recalculateFromEventId(newEntity.id);
  }
  public async save(): Promise<void> {
    if (this.planId === -1) {
      return;
    }

    const payload = this.events.map(e => e.toInterface());
    const idPreview = payload.map(item => item.id || -1).slice(0, 20).join(',');
    const idSuffix = payload.length > 20 ? `...(+${payload.length - 20})` : '';
    hilog.info(0x0000, TAG, `[ID_FIX][VM_SAVE_TRIGGER] planId=${this.planId} count=${payload.length} ids=[${idPreview}]${idSuffix}`);
    await EventRepositoryImpl.saveAllEvents(this.planId, payload);
  }

  // TimelineViewModel.ets 内部修改/替换原有冲突处理方法

  /**
   *
   */
  public async resolveConflictByBacklog(id: number, name: string, duration: number, note: string = '', priority: number = 0) {
    if (id !== -1) {


      const target = this.events.find(e => e.id === id);
      if (target) {
        target.status = 0; // 回归暂存
        target.day_offset = 0;
        target.dynamic_day_offset = 0;
        target.fixed_start_time = '';
        await this.updateEventInfo(id, name, duration, undefined, 0, false, note, priority);
      }
    } else {

      await this.addNewItem(name, duration, false, undefined, 0, 0, false, note, priority);
    }

  }

  /**
   *
   * 既然该地点早于原计划，我们将计划起点平移到该地点的日期，该地点的 offset 变为 0
   */
  public async resolveConflictByMovingPlan(id: number, targetDateMs: number, name: string, duration: number, isSchedule: boolean,
    fixedTime?: string, note: string = '', priority: number = 0) {

    // 1. 全局平移计划起点
    await this.updatePlanDate(targetDateMs);

    // 2. 判断更新还是新增
    if (id !== -1) {

      await this.updateEventInfo(id, name, duration, fixedTime, 0, false, note, priority);
    } else {
      await this.addNewItem(name, duration, isSchedule, fixedTime, 0, -1, false, note, priority);
    }
  }

  // path: ets/viewmodel/TimelineViewModel.ets


  /** [测试功能] 强制全量重算所有路线 */
  public testAllCommute() {
    this.events.forEach((item, index) => {
      if (item.status === 1 && index > 0) {
        if (this.shouldAutoRouteForItem(item)) {
          item.pre_travel_min = -1;
        }
      }
    });
    this.recalculate(); // 触发 Solver 调用 TrafficEngine
  }

  public async generateRecordingDemoPlan(): Promise<void> {
    if (this.planId <= 0) {
      return;
    }

    const tomorrow = new Date();
    tomorrow.setHours(0, 0, 0, 0);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const targetStartDate = tomorrow.getTime();

    hilog.info(0x0000, TAG, `[DEMO_PLAN][generate_begin] planId=${this.planId}, targetStartDate=${targetStartDate}`);
    await this.updatePlanDate(targetStartDate);

    this.events = [];
    await this.save();

    const templates: DemoPlanTemplateItem[] = [
      {
        name: '酒店办理入住',
        duration: 30,
        isSchedule: true,
        fixedTime: '09:00',
        dayOffset: 0,
        note: '演示锚点：固定开始',
        priority: 1,
        latitude: 31.2304,
        longitude: 121.4737
      },
      {
        name: '城市博物馆',
        duration: 120,
        isSchedule: true,
        fixedTime: '10:00',
        dayOffset: 0,
        note: '演示编辑与时间链联动',
        priority: 0,
        latitude: 31.2270,
        longitude: 121.4740
      },
      {
        name: '午餐·本帮菜馆',
        duration: 60,
        isSchedule: true,
        fixedTime: '13:00',
        dayOffset: 0,
        note: '演示冲突与压缩处理',
        priority: 0,
        latitude: 31.2290,
        longitude: 121.4800
      },
      {
        name: '江边步道',
        duration: 90,
        isSchedule: true,
        fixedTime: '15:00',
        dayOffset: 0,
        note: '演示伴游开始/暂停/继续',
        priority: 0,
        latitude: 31.2400,
        longitude: 121.4900
      },
      {
        name: '古镇晨游',
        duration: 120,
        isSchedule: true,
        fixedTime: '09:30',
        dayOffset: 1,
        note: '演示跨日行程',
        priority: 0,
        latitude: 31.2989,
        longitude: 120.5853
      },
      {
        name: '返程高铁站',
        duration: 40,
        isSchedule: true,
        fixedTime: '13:30',
        dayOffset: 1,
        note: '演示结束与历史记录',
        priority: 0,
        latitude: 31.1947,
        longitude: 121.3180
      },
      {
        name: '夜景观景台',
        duration: 60,
        isSchedule: false,
        fixedTime: '',
        dayOffset: 0,
        note: '暂存池示例：可一键加入日程',
        priority: 0,
        latitude: 31.2390,
        longitude: 121.4990
      },
      {
        name: '特色咖啡馆',
        duration: 45,
        isSchedule: false,
        fixedTime: '',
        dayOffset: 0,
        note: '暂存池示例：待确认地点',
        priority: 0,
        latitude: 31.2210,
        longitude: 121.4710
      }
    ];

    for (let i = 0; i < templates.length; i++) {
      const item = templates[i];
      await this.addNewItem(
        item.name,
        item.duration,
        item.isSchedule,
        item.fixedTime && item.fixedTime.trim().length > 0 ? item.fixedTime : undefined,
        item.dayOffset,
        -1,
        false,
        item.note,
        item.priority,
        item.latitude,
        item.longitude
      );
    }

    this.recalculateFromIndex(0);
    this.markScheduleChanged();
    this.events = [...this.events];

    if (this.isWeatherFeatureEnabled()) {
      try {
        await this.refreshPlanningWeather(true);
      } catch (error) {
        hilog.warn(0x0000, TAG, `[DEMO_PLAN][weather_refresh_fail] reason=${JSON.stringify(error)}`);
      }
    }

    hilog.info(0x0000, TAG, `[DEMO_PLAN][generate_done] planId=${this.planId}, total=${this.events.length}`);
  }


  /**
   *
   */
  public updateTravelMode(item: EventEntity, newMode: number) {
    if (!item) return;


    hilog.info(0x0000, TAG, `[VM层] 接收到模式切换 -> ${item.name} 切换为: ${newMode}`);


    item.travel_mode = newMode;
    item.transport_mode = newMode;
    item.is_travel_manual = 0;
    if (this.shouldAutoRouteForItem(item)) {
      item.pre_travel_min = -1; // 触发 Loading
    } else if (item.pre_travel_min < 0) {
      item.pre_travel_min = 0;
    }


    if (item.id) {
      import('../infrastructure/persistence/EventRepositoryImpl').then(m => {
        m.EventRepositoryImpl.updateSingleField(item.id, EventEntity.TRAVEL_MODE, newMode, this.planId);
        m.EventRepositoryImpl.updateSingleField(item.id, EventEntity.IS_TRAVEL_MANUAL, 0, this.planId);
        m.EventRepositoryImpl.updateSingleField(item.id, EventEntity.PRE_TRAVEL_MINUTES, item.pre_travel_min, this.planId);
      });
    }


    this.recalculateFromEventId(item.id);
  }

  /** [测试功能] 针对单项进行路程刷新 */
  public testSingleCommute(item: EventEntity) {
    if (this.shouldAutoRouteForItem(item)) {
      item.pre_travel_min = -1;
    }
    this.recalculateFromEventId(item.id);
  }

  private getEffectiveDayOffset(item: EventEntity): number {
    return TimelineDatePolicy.resolveEventDayOffset(item);
  }

  private resolveEffectiveGlobalStartMinutes(): number {
    const pure = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    if (DateUtil.isValidTimeString(pure)) {
      return DateUtil.timeToMinutes(pure);
    }
    return DateUtil.timeToMinutes('08:00');
  }

  private completionStatusLabel(status: number): string {
    if (status === EventEntity.STATE_COMPLETED) {
      return 'COMPLETED';
    }
    if (status === EventEntity.STATE_SKIPPED) {
      return 'SKIPPED';
    }
    return 'PENDING';
  }

  private buildTimelineSnapshot(limit: number = 6): string {
    const schedule = this.events
      .filter(e => e.status === 1)
      .slice(0, limit)
      .map((e, idx) => {
        const forecastStart = e.forecast_start_time || '--:--';
        const forecastEnd = e.forecast_end_time || '--:--';
        return `${idx + 1}:${e.id}/${e.name}|${this.completionStatusLabel(e.completion_status)}|f=${forecastStart}-${forecastEnd}|aS=${e.actual_start_time}|aE=${e.actual_end_time}`;
      });

    if (schedule.length === 0) {
      return 'empty';
    }
    return schedule.join('; ');
  }

  private buildScheduleOrderSnapshot(limit: number = 12): string {
    const schedule = this.events
      .filter(e => e.status === 1)
      .slice(0, limit)
      .map((e, idx) => `${idx + 1}:${e.id}/${e.name}[base=${e.day_offset},dyn=${e.dynamic_day_offset},fix=${e.fixed_start_time || '--'},sort=${e.sort_order}]`);

    if (schedule.length === 0) {
      return 'empty';
    }
    return schedule.join('; ');
  }

  private logTimelineSnapshot(scene: string): void {
    hilog.info(0x0000, TAG, `[DUAL_MODE_ACCEPT][snapshot][${scene}] ${this.buildTimelineSnapshot()}`);
  }

  private resolveRecalculateStartIndexByEventId(eventId: number): number {
    if (eventId <= 0) {
      return 0;
    }
    const index = this.events.findIndex((event: EventEntity) => event.id === eventId);
    if (index < 0) {
      return 0;
    }

    // 找到该地点之前的最后一个日程表地点
    let prevScheduleIndex = -1;
    for (let i = index - 1; i >= 0; i--) {
      if (this.events[i].status === 1) {
        prevScheduleIndex = i;
        break;
      }
    }

    const startIndex = prevScheduleIndex >= 0 ? prevScheduleIndex : 0;
    return startIndex;
  }

  private shouldPersistAutoPreTravel(entity: EventEntity, minutes: number): boolean {
    if (!entity || entity.id <= 0 || this.planId <= 0) {
      return false;
    }
    if (entity.status !== 1 || entity.is_travel_manual === 1) {
      return false;
    }
    if (!this.shouldAutoRouteForItem(entity)) {
      return false;
    }
    return Number.isFinite(minutes) && minutes >= 0;
  }

  private persistAutoPreTravel(entity: EventEntity, minutes: number): void {
    if (!this.shouldPersistAutoPreTravel(entity, minutes)) {
      return;
    }
    const updates: EventFieldUpdate[] = [
      { column: EventEntity.PRE_TRAVEL_MINUTES, value: minutes },
      { column: EventEntity.IS_TRAVEL_MANUAL, value: 0 }
    ];
    void EventRepositoryImpl.updateFields(entity.id, updates, this.planId);
  }

  private applyCalculatedResult(entity: EventEntity, resultItem: SolverCalculatedItem | undefined): ApplyResultFlags {
    let changed = false;
    let dayOffsetChanged = false;

    if (resultItem) {
      const nextConflict = resultItem.isConflict || false;
      if (entity.is_conflict !== nextConflict) {
        entity.is_conflict = nextConflict;
        changed = true;
      }
      const nextConflictMsg = resultItem.conflictMsg || '';
      if (entity.conflict_msg !== nextConflictMsg) {
        entity.conflict_msg = nextConflictMsg;
        changed = true;
      }

      if (resultItem.computedStartTime && entity.computed_time !== resultItem.computedStartTime) {
        entity.computed_time = resultItem.computedStartTime;
        changed = true;
      }

      if (resultItem.preTravelMinutes !== undefined && entity.pre_travel_min !== resultItem.preTravelMinutes) {
        entity.pre_travel_min = resultItem.preTravelMinutes;
        this.persistAutoPreTravel(entity, resultItem.preTravelMinutes);
        changed = true;
      }

      const nextHasGap = resultItem.hasGap || false;
      if (entity.has_gap !== nextHasGap) {
        entity.has_gap = nextHasGap;
        changed = true;
      }
      const nextGapMinutes = resultItem.gapMinutes || 0;
      if (entity.gap_minutes !== nextGapMinutes) {
        entity.gap_minutes = nextGapMinutes;
        changed = true;
      }
      const nextNaturalStart = resultItem.naturalStartTime || '';
      if (entity.natural_start_time !== nextNaturalStart) {
        entity.natural_start_time = nextNaturalStart;
        changed = true;
      }
      const nextTransitWarning = resultItem.transitWarning || false;
      if (entity.transit_warning !== nextTransitWarning) {
        entity.transit_warning = nextTransitWarning;
        changed = true;
      }

      const dynamicDayOffset = resultItem.dynamicDayOffset ?? resultItem.dayOffset ?? entity.day_offset;
      if (entity.dynamic_day_offset !== dynamicDayOffset) {
        entity.dynamic_day_offset = dynamicDayOffset;
        changed = true;
        dayOffsetChanged = true;
      }
      if (entity.day_offset !== dynamicDayOffset) {
        hilog.info(
          0x0000,
          TAG,
          `[DAY_SHIFT_FIX][solver_reconcile] id=${entity.id}, name=${entity.name}, base=${entity.day_offset}, dynamic=${dynamicDayOffset}`
        );
      }

      if (resultItem.dynamicStartTime !== undefined && entity.dynamic_start_time !== resultItem.dynamicStartTime) {
        entity.dynamic_start_time = resultItem.dynamicStartTime;
        changed = true;
      }
      if (resultItem.dynamicEndTime !== undefined && entity.dynamic_end_time !== resultItem.dynamicEndTime) {
        entity.dynamic_end_time = resultItem.dynamicEndTime;
        changed = true;
      }

      // 对于非锁定地点，同步computed_time到fixed_start_time
      if (entity.lock_status === 0 && resultItem.computedStartTime) {
        // 提取纯时间部分（去掉日期前缀）
        const timeOnly = resultItem.computedStartTime.includes(' ')
          ? resultItem.computedStartTime.split(' ').pop() || resultItem.computedStartTime
          : resultItem.computedStartTime;

        if (entity.fixed_start_time !== timeOnly) {
          entity.fixed_start_time = timeOnly;
          changed = true;
        }
      }

      return {
        changed: changed,
        dayOffsetChanged: dayOffsetChanged
      };
    }

    if (entity.status === 0) {
      if (entity.is_conflict) {
        entity.is_conflict = false;
        changed = true;
      }
      if (entity.computed_time !== '') {
        entity.computed_time = '';
        changed = true;
      }
      if (entity.has_gap) {
        entity.has_gap = false;
        changed = true;
      }
      if (entity.gap_minutes !== 0) {
        entity.gap_minutes = 0;
        changed = true;
      }
      if (entity.natural_start_time !== '') {
        entity.natural_start_time = '';
        changed = true;
      }
      if (entity.transit_warning) {
        entity.transit_warning = false;
        changed = true;
      }
      if (entity.dynamic_day_offset !== entity.day_offset) {
        entity.dynamic_day_offset = entity.day_offset;
        changed = true;
        dayOffsetChanged = true;
      }
    }

    return {
      changed: changed,
      dayOffsetChanged: dayOffsetChanged
    };
  }

  public recalculateFromEventId(eventId: number): void {
    const startIndex = this.resolveRecalculateStartIndexByEventId(eventId);
    this.recalculateFromIndex(startIndex);
  }

  private resolveScheduleAnchorEventId(startIndex: number): number {
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    for (let i = safeStartIndex; i < this.events.length; i++) {
      const item = this.events[i];
      if (item.status === 1 && item.id > 0) {
        return item.id;
      }
    }
    return -1;
  }

  public recalculateFromIndex(startIndex: number): void {
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    const startFromEventId = this.resolveScheduleAnchorEventId(safeStartIndex);

    const result = TimelineCalculationService.recalculateFromIndex(
      this.events,
      safeStartIndex,
      this.globalStartTime,
      this.planStartDate,
      this.scheduleOrchestrator,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes,
        startFromEventId: startFromEventId
      },
      (entity: EventEntity, calculated: SolverCalculatedItem | undefined): ApplyResultFlags => this.applyCalculatedResult(entity, calculated)
    );

    this.calculateRealtimeSchedule();
    this.generateGroups();
    this.markScheduleChanged();
    if (result.hasFieldChanged || result.hasDayOffsetChanged) {
      this.events = [...this.events];
      return;
    }
    this.events = [...this.events];
  }

  public recalculate(): void {
    if (!this.hasLoggedLifecycleDetach) {
      hilog.info(0x0000, TAG, '[LIFECYCLE_GUARD] recalculate uses context-free solver path.');
      this.hasLoggedLifecycleDetach = true;
    }
    const globalStartCandidate = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';
    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][recalculate_input] globalStart=${this.globalStartTime}, effectiveStart=${effectiveGlobalStart}, planStartDate=${this.planStartDate}, total=${this.events.length}`
    );

    const result = TimelineCalculationService.recalculate(
      this.events,
      this.globalStartTime,
      this.planStartDate,
      this.scheduleOrchestrator,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes,
        slackRatio: StrategyPresets.getProfile(this.currentStrategyMode as TravelStrategyMode).slackRatio
      },
      (entity: EventEntity, calculated: SolverCalculatedItem | undefined): ApplyResultFlags => this.applyCalculatedResult(entity, calculated)
    );

    this.calculateRealtimeSchedule();
    this.generateGroups();
    this.markScheduleChanged();
    if (result.hasFieldChanged || result.hasDayOffsetChanged) {
      this.events = [...this.events];
    }
    this.logTimelineSnapshot('recalculate');
  }

  public recalculateTrafficOnly(): void {
    const result = TimelineCalculationService.recalculateTrafficOnly(
      this.events,
      this.globalStartTime,
      this.planStartDate,
      this.scheduleOrchestrator,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes
      },
      (entity, minutes) => this.persistAutoPreTravel(entity, minutes)
    );

    if (!result.hasFieldChanged) {
      return;
    }

    this.calculateRealtimeSchedule();
    if (result.hasDayOffsetChanged) {
      this.generateGroups();
      this.markScheduleChanged();
    }
    this.events = [...this.events];
  }


  public resolveGapBySync(item: EventEntity) {
    if (item.natural_start_time) {
      this.updateEventInfo(item.id, item.name, item.duration, item.natural_start_time, item.day_offset);
    }
  }

  /** [选项 C] 临时提前：本次运行不等待，直接开始 */
  public resolveGapByIgnore(item: EventEntity) {
    item.is_ignore_wait = true;
    this.recalculateFromEventId(item.id);
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
    // 1. 内存移除
    const index = this.events.indexOf(item);
    if (index !== -1) {
      this.events.splice(index, 1);
    }


    if (item.id) {
      await EventRepositoryImpl.hardDeleteEvent(item.id);
    }

    // 3. 触发刷新
    this.recalculateFromIndex(index > 0 ? index - 1 : 0);

    // 4. 记录删除行为并检查策略调整
    if (item.source === 1) {
      this.behaviorTracker.recordDeletion(item.type, item.duration, item.pre_travel_min);
      if (this.behaviorTracker.shouldTriggerAdaptation()) {
        await this.triggerStrategyAdaptation();
      }
    }
  }

  // 文件路径: ets/viewmodel/TimelineViewModel.ets

  /**
   * [节点 3B] 更新地点入库
   */
  public async updateEventInfo(id: number, name: string, duration: number, fixedTime?: string, dayOffset: number = 0,
    isHardLock: boolean = false, note: string = '', priority: number = 0,
    lat?: number, lng?: number
  ) {

    hilog.info(0x0000, TAG, `[节点3B: 准备更新入库] -> 地点: ${name}(ID:${id}), lat: ${lat}, lng: ${lng}`);

    const target = this.events.find(e => e.id === id);
    if (!target) return;

    const oldStatus = target.status;
    const oldTime = target.fixed_start_time;
    const oldDayOffset = target.day_offset;
    const oldName = target.name;
    const oldLat = target.latitude;
    const oldLng = target.longitude;
    const resolvedCoordinate = await this.resolveCoordinatesForPlaceName(name, lat, lng, 'update', oldLat, oldLng);
    const resolvedLat = resolvedCoordinate.latitude;
    const resolvedLng = resolvedCoordinate.longitude;
    const dayOffsetChanged = oldDayOffset !== dayOffset;
    const nextLat = this.isCoordinateMissingForWeather(resolvedLat, resolvedLng) ? oldLat : resolvedLat;
    const nextLng = this.isCoordinateMissingForWeather(resolvedLat, resolvedLng) ? oldLng : resolvedLng;
    const placeChanged = oldName !== name || oldLat !== nextLat || oldLng !== nextLng;

    if (dayOffsetChanged) {
      hilog.info(
        0x0000,
        TAG,
        `[DAY_SHIFT_FIX][update_day_offset][begin] id=${id}, name=${name}, oldDayOffset=${oldDayOffset}, newDayOffset=${dayOffset}, orderBefore=${this.buildScheduleOrderSnapshot()}`
      );
    }

    // 1. 更新内存
    target.name = name;
    target.duration = duration;
    target.note = note;
    target.day_offset = dayOffset;
    target.dynamic_day_offset = dayOffset;
    target.priority = priority;
    if (!this.isCoordinateMissingForWeather(resolvedLat, resolvedLng)) {
      target.latitude = resolvedLat;
      target.longitude = resolvedLng;
    }

    if (placeChanged && this.shouldAutoRouteForItem(target)) {
      target.is_travel_manual = 0;
      target.pre_travel_min = -1;
    }

    if (fixedTime) {
      target.status = 1;
      target.fixed_start_time = fixedTime;
      target.lock_status = isHardLock ? 1 : 0;
    }


    if (target.id) {
      const updates: EventFieldUpdate[] = [
        { column: 'status', value: target.status },
        { column: 'name', value: name },
        { column: 'duration', value: duration },
        { column: 'lock_status', value: target.lock_status },
        { column: 'fixed_start_time', value: target.fixed_start_time || '' },
        { column: EventEntity.DAY_OFFSET, value: dayOffset },
        { column: 'note', value: note },
        { column: 'priority', value: priority }
      ];
      if (placeChanged && this.shouldAutoRouteForItem(target)) {
        updates.push({ column: EventEntity.IS_TRAVEL_MANUAL, value: 0 });
        updates.push({ column: EventEntity.PRE_TRAVEL_MINUTES, value: -1 });
      }
      if (!this.isCoordinateMissingForWeather(resolvedLat, resolvedLng)) {
        updates.push({ column: 'latitude', value: resolvedLat });
        updates.push({ column: 'longitude', value: resolvedLng });
      }
      await EventRepositoryImpl.updateFields(target.id, updates, this.planId);
      hilog.info(0x0000, TAG, `[节点3B: 准备更新入库] -> 地点: ${name}(ID:${id}), lat: ${resolvedLat}, lng: ${resolvedLng}`);
    }

    // 3. 逻辑联动：处理状态变更、时间变动或 day_offset 变动
    const shouldReinsert = ((oldStatus === 0 && target.status === 1) || (fixedTime && fixedTime !== oldTime) ||
      (dayOffsetChanged && target.status === 1));
    if (shouldReinsert) {
      const currentIndex = this.events.indexOf(target);
      if (currentIndex >= 0) {
        this.events.splice(currentIndex, 1);
      }
      this.insertSmart(target);
      hilog.info(
        0x0000,
        TAG,
        `[DAY_SHIFT_FIX][reinsert_done] id=${id}, name=${name}, reason=status_or_time_or_day_offset, newIndex=${this.events.indexOf(target)}, orderAfter=${this.buildScheduleOrderSnapshot()}`
      );
      await EventRepositoryImpl.updateTimelineConsistency(this.events.map(e => e.toInterface()), this.planId);
    } else if (dayOffsetChanged) {
      hilog.info(
        0x0000,
        TAG,
        `[DAY_SHIFT_FIX][update_day_offset][skip_reinsert] id=${id}, name=${name}, status=${target.status}`
      );
    }

    this.recalculateFromEventId(id);
  }

  public previewPlanDateShift(newDateTimestamp: number): PlanDateShiftPreview {
    const nextDate = new Date(newDateTimestamp);
    nextDate.setHours(0, 0, 0, 0);
    const normalizedTimestamp = nextDate.getTime();

    const globalStartCandidate = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = this.scheduleOrchestrator.calculate(
      this.events.map(e => e.toInterface()),
      effectiveGlobalStart,
      normalizedTimestamp,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes
      }
    );

    const result = ConflictDetector.checkConflicts(this.events, calculated);

    if (result.hasConflict) {
      hilog.warn(
        0x0000,
        TAG,
        `[SHIFT_VM][preview_conflict] targetDate=${normalizedTimestamp}, eventId=${result.conflictItemId}, eventName=${result.conflictItemName}, gapMinutes=${result.gapMinutes}, msg=${result.conflictMsg}`
      );
    } else {
      hilog.info(
        0x0000,
        TAG,
        `[SHIFT_VM][preview_ok] targetDate=${normalizedTimestamp}, eventCount=${this.events.length}`
      );
    }

    return {
      hasRigidConflict: result.hasConflict,
      conflictItemId: result.conflictItemId,
      conflictItemName: result.conflictItemName,
      gapMinutes: result.gapMinutes,
      conflictMsg: result.conflictMsg
    };
  }
  /**
   * [Priority 4] 修改计划出发日期 (整体平移)
   */
  public async updatePlanDate(newDateTimestamp: number) {
    const nextDate = new Date(newDateTimestamp);
    nextDate.setHours(0, 0, 0, 0);
    const normalizedTimestamp = nextDate.getTime();

    const oldPlanStartDate = this.planStartDate;
    this.planStartDate = normalizedTimestamp;

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][apply_plan_date] oldPlanStartDate=${oldPlanStartDate}, newPlanStartDate=${normalizedTimestamp}`
    );

    if (this.planId !== -1) {
      await this.persistence.updatePlanStartDate(this.planId, normalizedTimestamp);
    }

    // 仅计划基准日期变更时，无需重新求解整条时间链；刷新绝对时间与分组即可
    this.calculateRealtimeSchedule();
    this.generateGroups();
    this.markScheduleChanged();
    this.events = [...this.events];

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][apply_plan_date_done] planId=${this.planId}, groups=${this.groupedEvents.length}`
    );
  }

  /**
   *
   */
  public async renamePlan(newName: string) {
    if (this.planId === -1) {
      return;
    }


    await this.persistence.updatePlanName(this.planId, newName);



  }

  public async updatePlanAutoAmapRoute(enabled: boolean): Promise<void> {
    const previousEnabled = this.enableAutoAmapRoute;
    this.enableAutoAmapRoute = enabled;
    let hasLocalFieldChanged = false;
    if (!enabled) {
      this.events.forEach((item) => {
        if (item.pre_travel_min < 0 && item.is_travel_manual !== 1) {
          item.pre_travel_min = 0;
          hasLocalFieldChanged = true;
        }
      });
    }
    if (this.planId !== -1) {
      await this.persistence.updateAutoAmapRoute(this.planId, enabled);
    }
    if (previousEnabled !== enabled || hasLocalFieldChanged) {
      this.recalculateFromIndex(0);
    }
  }



  /**
   *
   *
   */
  public isDateConflict(targetDateMs: number): boolean {
    return TimelineConflictResolver.isDateConflict(targetDateMs, this.planStartDate);
  }



  /**
   *
   *
   *
   * @returns 是否存在风险
   */
  public checkDistributionRisk(gapItem: EventEntity, distributionMap: Map<number, number>): boolean {
    if (distributionMap.size === 0) return false;

    // 1. 确定受影响的范围：从最早被分配的地点到 gapItem 之前
    const allSchedule = this.events.filter(e => e.status === 1);
    const gapIndex = allSchedule.indexOf(gapItem);


    let firstModifiedIdx = gapIndex;
    distributionMap.forEach((_, id) => {
      const idx = allSchedule.findIndex(e => e.id === id);
      if (idx < firstModifiedIdx) firstModifiedIdx = idx;
    });

    // 2. 模拟推演
    let accumulatedAdd = 0;
    for (let i = firstModifiedIdx; i < gapIndex; i++) {
      const current = allSchedule[i];
      accumulatedAdd += (distributionMap.get(current.id) || 0);


      const nextItem = allSchedule[i + 1];
      if (nextItem && nextItem.lock_status === 1) {


        if (accumulatedAdd > nextItem.gap_minutes) {
          return true; // 触发预警
        }
      }
    }
    return false;
  }


  public async resolveConflictBySyncItem(name: string, duration: number, isSchedule: boolean, fixedTime?: string, note: string = '') {
    // 透传 note
    await this.addNewItem(name, duration, isSchedule, fixedTime, 0, -1, false, note);
  }

  public async resolveConflictByKeepDraft(name: string, duration: number,  isSchedule: boolean,
    fixedTime: string | undefined, negativeOffset: number, note: string = '') {
    // 透传 note
    await this.addNewItem(name, duration, false, fixedTime, negativeOffset, -1, false, note);
  }




  public async smartFixConflict(targetItem: EventEntity) {
    if (!targetItem || !targetItem.is_conflict) {
      return;
    }

    const index = this.events.indexOf(targetItem);
    if (index === -1) {
      return;
    }

    // =========================================================
    // 策略 A: 硬锚点保卫战 (尝试压缩前序)
    // =========================================================
    if (targetItem.lock_status === 1 && targetItem.fixed_start_time) {
      console.info(TAG, `SmartFix: 检测到刚性冲突 [${targetItem.name}]，尝试反向压缩...`);

      const plan = this.calculateCompressionPlan(index, targetItem.fixed_start_time);


      if (plan.status === 'NO_ACTION' || plan.status === 'COMPRESS_CONFIRM') {
        if (plan.status === 'COMPRESS_CONFIRM') {
          this.applyCompressionPlan(plan);
        }
        this.markHasUnsavedPostpone();
        return;
      }


      // ⚠️ 修改点：刚性逻辑下，压缩失败就是失败，禁止降级去改时间！
      console.warn(TAG, `SmartFix: 刚性冲突且无法压缩，修复失败。请用户手动调整。`);
      return;
    }
  }

  public calculateCompressionPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    const context = this.buildCompressionSelectionContext(targetIndex, newTimeStr);
    if (!context || context.neededGapMinutes <= 0) {
      return { status: 'NO_ACTION', msg: '时间充裕', affectedItems: [] };
    }

    const selectedIds = new Set<number>();
    context.candidates.forEach((candidate) => {
      if (candidate.selectable) {
        selectedIds.add(candidate.id);
      }
    });
    return this.calculateCompressionPlanBySelection(targetIndex, newTimeStr, selectedIds, 'RATIO');
  }

  private resolveCompressionChainStart(targetIndex: number): number {
    let chainStartIndex = 0;
    for (let i = targetIndex - 1; i >= 0; i--) {
      const item = this.events[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        chainStartIndex = i;
        break;
      }
    }
    return chainStartIndex;
  }

  private buildCompressionSelectionContextInternal(targetIndex: number, targetTime: string): CompressionSelectionContext | null {
    if (targetIndex <= 0 || !this.events[targetIndex]) {
      return null;
    }
    if (!DateUtil.isValidTimeString(targetTime)) {
      return null;
    }

    const naturalArrivalMinutes = this._calculateNaturalArrival(targetIndex);
    const targetMinutes = DateUtil.timeToMinutes(targetTime);
    const targetDayOffset = this.getEffectiveDayOffset(this.events[targetIndex]);
    const neededGapMinutes = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);
    const chainStartIndex = this.resolveCompressionChainStart(targetIndex);
    const minKeepDuration = this.getMinEventDurationLimit();

    const candidates: CompressionSelectionCandidate[] = [];
    for (let i = 0; i < targetIndex; i++) {
      const item = this.events[i];
      if (item.status !== 1) {
        continue;
      }

      const minAllowed = Math.min(item.duration, minKeepDuration);
      const maxReducible = Math.max(0, item.duration - minAllowed);
      const isRigid = item.lock_status === 1;
      const withinActiveChain = i >= chainStartIndex;
      let selectable = !isRigid && withinActiveChain && maxReducible > 0;
      let disabledReason = '';

      if (isRigid) {
        disabledReason = '刚性地点不可压缩';
      } else if (!withinActiveChain) {
        disabledReason = '受前序刚性锚点阻断';
      } else if (maxReducible <= 0) {
        disabledReason = `已达到最短停留 ${minKeepDuration} 分钟`;
      }

      candidates.push({
        index: i,
        id: item.id,
        name: item.name,
        oldVal: item.duration,
        minAllowed: minAllowed,
        maxReducible: maxReducible,
        isRigid: isRigid,
        selectable: selectable,
        disabledReason: disabledReason
      });
    }

    return {
      targetIndex: targetIndex,
      targetTime: targetTime,
      neededGapMinutes: neededGapMinutes,
      naturalArrivalMinutes: naturalArrivalMinutes,
      chainStartIndex: chainStartIndex,
      candidates: candidates
    };
  }

  public buildCompressionSelectionContext(targetIndex: number, targetTime: string): CompressionSelectionContext | null {
    return this.buildCompressionSelectionContextInternal(targetIndex, targetTime);
  }

  private buildCompressionAffectedItems(selected: CompressionSelectionCandidate[], reducedMap: Map<number, number>): GeneratedTypeLiteralInterface_7[] {
    const affected: GeneratedTypeLiteralInterface_7[] = [];
    selected.forEach((candidate) => {
      const reduced = reducedMap.get(candidate.id) ?? 0;
      if (reduced <= 0) {
        return;
      }
      affected.push({
        index: candidate.index,
        name: candidate.name,
        oldVal: candidate.oldVal,
        newVal: candidate.oldVal - reduced
      });
    });
    return affected;
  }

  public calculateCompressionPlanBySelection(targetIndex: number, targetTime: string, selectedIds: Set<number>,
    mode: CompressionMode = 'RATIO'): CompressionPlan {
    const context = this.buildCompressionSelectionContextInternal(targetIndex, targetTime);
    if (!context) {
      return { status: 'NO_ACTION', msg: '无需操作', affectedItems: [], mode: mode };
    }
    if (context.neededGapMinutes <= 0) {
      return { status: 'NO_ACTION', msg: '时间充裕', affectedItems: [], mode: mode };
    }

    const selected = context.candidates.filter((candidate) => selectedIds.has(candidate.id) && candidate.selectable);
    if (selected.length === 0) {
      return {
        status: 'OVERLOAD',
        msg: '请先选择至少一个可压缩地点',
        affectedItems: [],
        suggestedTime: DateUtil.minutesToTime(context.naturalArrivalMinutes),
        remainingGapMinutes: context.neededGapMinutes,
        capacityMinutes: 0,
        mode: mode
      };
    }

    const remainingCapMap = new Map<number, number>();
    const reducedMap = new Map<number, number>();
    const weightMap = new Map<number, number>();
    let capacityMinutes = 0;
    selected.forEach((candidate) => {
      remainingCapMap.set(candidate.id, candidate.maxReducible);
      reducedMap.set(candidate.id, 0);
      weightMap.set(candidate.id, Math.max(1, candidate.oldVal));
      capacityMinutes += candidate.maxReducible;
    });

    let remainingNeed = context.neededGapMinutes;

    if (mode === 'EQUAL') {
      let progressed = true;
      while (remainingNeed > 0 && progressed) {
        progressed = false;
        for (let i = 0; i < selected.length; i++) {
          if (remainingNeed <= 0) {
            break;
          }
          const id = selected[i].id;
          const cap = remainingCapMap.get(id) ?? 0;
          if (cap <= 0) {
            continue;
          }
          remainingCapMap.set(id, cap - 1);
          reducedMap.set(id, (reducedMap.get(id) ?? 0) + 1);
          remainingNeed--;
          progressed = true;
        }
      }
    } else {
      let activeIds = selected.map((candidate) => candidate.id);
      while (remainingNeed > 0 && activeIds.length > 0) {
        let totalWeight = 0;
        activeIds.forEach((id) => {
          totalWeight += (weightMap.get(id) ?? 0);
        });
        if (totalWeight <= 0) {
          break;
        }

        let allocatedThisRound = 0;
        const nextActiveIds: number[] = [];
        for (let i = 0; i < activeIds.length; i++) {
          const id = activeIds[i];
          const cap = remainingCapMap.get(id) ?? 0;
          if (cap <= 0) {
            continue;
          }
          const share = Math.floor(remainingNeed * ((weightMap.get(id) ?? 0) / totalWeight));
          const grant = Math.min(cap, Math.max(share, 0));
          if (grant > 0) {
            remainingCapMap.set(id, cap - grant);
            reducedMap.set(id, (reducedMap.get(id) ?? 0) + grant);
            remainingNeed -= grant;
            allocatedThisRound += grant;
          }
          if ((remainingCapMap.get(id) ?? 0) > 0) {
            nextActiveIds.push(id);
          }
        }

        if (allocatedThisRound === 0) {
          const sorted = [...activeIds].sort((a, b) => (weightMap.get(b) ?? 0) - (weightMap.get(a) ?? 0));
          for (let i = 0; i < sorted.length; i++) {
            if (remainingNeed <= 0) {
              break;
            }
            const id = sorted[i];
            const cap = remainingCapMap.get(id) ?? 0;
            if (cap <= 0) {
              continue;
            }
            remainingCapMap.set(id, cap - 1);
            reducedMap.set(id, (reducedMap.get(id) ?? 0) + 1);
            remainingNeed -= 1;
            allocatedThisRound += 1;
          }
          if (allocatedThisRound === 0) {
            break;
          }
        }

        activeIds = nextActiveIds.filter((id) => (remainingCapMap.get(id) ?? 0) > 0);
      }
    }

    const reducedTotal = context.neededGapMinutes - remainingNeed;
    const affectedItems = this.buildCompressionAffectedItems(selected, reducedMap);
    const suggestedMinutes = context.naturalArrivalMinutes - reducedTotal;
    const suggestedTime = DateUtil.minutesToTime(suggestedMinutes);

    if (remainingNeed > 0) {
      return {
        status: 'OVERLOAD',
        msg: `所选地点可压缩总量不足，仍冲突 ${remainingNeed} 分钟`,
        affectedItems: affectedItems,
        suggestedTime: suggestedTime,
        remainingGapMinutes: remainingNeed,
        capacityMinutes: capacityMinutes,
        mode: mode
      };
    }

    hilog.info(
      0x0000,
      TAG,
      `[CONFLICT_VM][compress_plan_ready] targetIndex=${targetIndex}, mode=${mode}, needed=${context.neededGapMinutes}, capacity=${capacityMinutes}`
    );

    return {
      status: 'COMPRESS_CONFIRM',
      msg: '需要压缩前序行程',
      affectedItems: affectedItems,
      suggestedTime: targetTime,
      remainingGapMinutes: 0,
      capacityMinutes: capacityMinutes,
      mode: mode
    };
  }

  /**
   * [执行] 应用压缩方案
   */
  public applyCompressionPlan(plan: CompressionPlan) {
    if (!plan.affectedItems || plan.affectedItems.length === 0) {
      return;
    }

    let minChangedIndex = Number.MAX_SAFE_INTEGER;
    plan.affectedItems.forEach(change => {
      const item = this.events[change.index];
      // 1. 更新内存
      item.duration = change.newVal;
      if (change.index < minChangedIndex) {
        minChangedIndex = change.index;
      }

      if (item.id) {
        EventRepositoryImpl.updateSingleField(item.id, 'duration', change.newVal, this.planId);
      }
    });


    const startIndex = minChangedIndex > 0 ? minChangedIndex - 1 : 0;
    this.recalculateFromIndex(startIndex);
  }

  public async refreshPlanningWeather(forceRefresh: boolean = false): Promise<void> {
    if (!this.weatherFeatureEnabled) {
      this.clearWeatherRuntimeState();
      return;
    }
    if (this.weatherLoading) {
      return;
    }
    this.weatherLoading = true;
    try {
      const stage = this.resolveCurrentWeatherStage();
      const scheduleEvents = this.events.filter((item: EventEntity) => item.status === 1);
      await this.backfillPlanningCoordinatesByName(scheduleEvents);
      const validGeoCount = scheduleEvents.filter((item: EventEntity) =>
        this.isValidCoordinate(item.latitude, item.longitude)
      ).length;
      const missingGeoEvents = scheduleEvents.filter((item: EventEntity) =>
        this.isCoordinateMissingForWeather(item.latitude, item.longitude)
      );
      const missingNamePreview = missingGeoEvents
        .slice(0, 3)
        .map((item: EventEntity) => item.name.trim())
        .join('|');
      hilog.info(0x0000, TAG, `[WEATHER_STAGE][planning] stage=${stage}`);
      hilog.info(0x0000, TAG, `[WEATHER_PREF][planning_begin] schedule=${scheduleEvents.length}, validGeo=${validGeoCount}, forceRefresh=${forceRefresh}`);
      if (missingGeoEvents.length > 0) {
        hilog.warn(
          0x0000,
          TAG,
          `[WEATHER_PREF][planning_geo_missing] count=${missingGeoEvents.length}, sample=${missingNamePreview}`
        );
      }
      const result = await this.weatherFacade.buildPlanningContext(
        this.events,
        this.weatherUserPreference,
        this.weatherCollabOptions,
        stage
      );
      await this.applyPlanningWeatherResult(result, forceRefresh);
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_PREF][planning] heat=${this.weatherUserPreference.heatSensitivity}, rain=${this.weatherUserPreference.rainSensitivity}, tolerance=${this.weatherUserPreference.weatherRiskTolerance}`
      );
    } finally {
      this.weatherLoading = false;
    }
  }

  private async applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void> {
    const context = result.context;
    this.weatherRouteScore = context.routeSuitability.routeScore;
    this.weatherPlanningHint = context.routeSuitability.summaryText;
    this.weatherCollabSummary = context.collabContext?.collabSummary ?? '';
    this.weatherCollabLabel = this.weatherCollabSummary.trim().length > 0 ? '多日/多城' : '';
    this.weatherLastRefreshAt = Date.now();
    this.persistPlanningWeatherSnapshot();

    this.events.forEach((event: EventEntity) => {
      const binding = result.eventMap.get(event.id);
      if (!binding) {
        if (event.status === 1 && (event.latitude !== 0 || event.longitude !== 0)) {
          event.weather_text = '天气未知';
          event.weather_condition = 'UNKNOWN';
          event.weather_temperature = 0;
          event.weather_fetch_time = Date.now();
        }
        return;
      }
      event.weather_text = binding.weather?.conditionText || '天气未知';
      event.weather_condition = binding.weather?.conditionCode || 'UNKNOWN';
      event.weather_temperature = binding.weather?.temperatureCelsius ?? 0;
      event.weather_fetch_time = binding.weather?.fetchTime ?? Date.now();
      if (forceRefresh && event.id > 0) {
        const updates: EventFieldUpdate[] = [
          { column: EventEntity.WEATHER_CONDITION, value: event.weather_condition },
          { column: EventEntity.WEATHER_TEMPERATURE, value: event.weather_temperature },
          { column: EventEntity.WEATHER_TEXT, value: event.weather_text },
          { column: EventEntity.WEATHER_FETCH_TIME, value: event.weather_fetch_time }
        ];
        void EventRepositoryImpl.updateFields(event.id, updates, this.planId);
      }
    });
    const unknownCount = this.events.filter((event: EventEntity) =>
      event.status === 1 && (((event.weather_text || '').trim().length === 0) || event.weather_text === '天气未知')
    ).length;
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_PREF][planning_apply] total=${this.events.filter((item: EventEntity) => item.status === 1).length}, unknown=${unknownCount}, routeScore=${this.weatherRouteScore}`
    );
    const currentStrategy = await this.getCurrentStrategy();
    const weatherDecision = StrategyAdaptationEngine.adaptToWeather(
      context.collabContext,
      context.routeSuitability.routeScore,
      currentStrategy
    );
    if (weatherDecision) {
      const nextStrategy = StrategyAdaptationEngine.applyAdjustment(currentStrategy, weatherDecision);
      const hasStrategyChange = nextStrategy.density !== currentStrategy.density ||
        nextStrategy.pace !== currentStrategy.pace ||
        nextStrategy.preference !== currentStrategy.preference ||
        nextStrategy.energy !== currentStrategy.energy;
      const adaptationKey = this.buildWeatherStrategyAdaptationKey(
        context.generatedAt,
        context.routeSuitability.routeScore
      );
      if (hasStrategyChange && adaptationKey !== this.weatherStrategyAppliedKey) {
        await PlanRepositoryImpl.updateStrategyDimensions(
          this.planId,
          nextStrategy.density,
          nextStrategy.pace,
          nextStrategy.preference,
          nextStrategy.energy
        );
        this.currentStrategyMode = -1;
        this.weatherStrategyHint = weatherDecision.message;
        this.weatherStrategyAppliedKey = adaptationKey;
        hilog.info(
          0x0000,
          TAG,
          `[WEATHER_STRATEGY][planning_applied] reason=${weatherDecision.reason}, generatedAt=${context.generatedAt}, score=${context.routeSuitability.routeScore}, trend=${context.collabContext?.trendTag ?? 'UNKNOWN'}`
        );
      } else if (hasStrategyChange) {
        this.weatherStrategyHint = weatherDecision.message;
      } else {
        this.weatherStrategyHint = '';
      }
    } else {
      this.weatherStrategyHint = '';
    }
    this.events = [...this.events];
  }

  public isExecutionWeatherStage(): boolean {
    return this.currentPlanStatus === PlanStatus.READY ||
      this.currentPlanStatus === PlanStatus.IN_PROGRESS ||
      this.currentPlanStatus === PlanStatus.PAUSED ||
      this.events.some((event: EventEntity) => TimelineExecutionState.isActive(event));
  }

  public startExecutionWeatherScheduler(_planId?: number, stage?: WeatherStageType): void {
    if (!this.weatherFeatureEnabled) {
      this.stopExecutionWeatherScheduler();
      return;
    }
    this.executionWeatherEnabled = true;
    const resolvedStage = stage ?? this.resolveCurrentWeatherStage();
    this.currentWeatherSchedulePolicy = this.weatherFacade.resolveSchedulePolicy(resolvedStage);
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_STAGE][scheduler_start] stage=${resolvedStage}, intervalMs=${this.currentWeatherSchedulePolicy.pollIntervalMs}`
    );
    this.weatherRefreshScheduler.start(this.currentWeatherSchedulePolicy.pollIntervalMs, () => {
      if (!this.weatherFeatureEnabled) {
        return;
      }
      if (this.currentPlanStatus === PlanStatus.CONFIRMED) {
        if (this.shouldAutoRefreshPlanningWeather()) {
          void this.refreshPlanningWeather(false);
        }
        return;
      }
      void this.refreshExecutionWeather(false, 'TIMER', resolvedStage);
    });
    if (this.currentWeatherSchedulePolicy.forceRefreshOnEnter) {
      if (resolvedStage === 'CONFIRMED' || resolvedStage === 'PLANNING') {
        if (this.shouldAutoRefreshPlanningWeather()) {
          void this.refreshPlanningWeather(true);
        }
      } else {
        void this.refreshExecutionWeather(true, 'ENTER_EXECUTION', resolvedStage);
      }
    }
  }

  public stopExecutionWeatherScheduler(): void {
    this.executionWeatherEnabled = false;
    this.weatherRefreshScheduler.stop();
  }

  public async refreshExecutionWeather(
    forceRefresh: boolean = false,
    trigger: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL' = 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void> {
    if (!this.weatherFeatureEnabled) {
      return;
    }
    if (!this.executionWeatherEnabled && trigger !== 'MANUAL') {
      return;
    }
    if (this.executionWeatherLoading) {
      return;
    }
    if (!this.isExecutionWeatherStage() && trigger !== 'MANUAL') {
      return;
    }
    const resolvedStage = stage ?? this.resolveCurrentWeatherStage();
    const policy = this.weatherFacade.resolveSchedulePolicy(resolvedStage);
    if (trigger === 'LOCATION_CHANGE' && !policy.allowLocationTrigger) {
      return;
    }
    this.executionWeatherLoading = true;
    this.executionWeatherLastTrigger = trigger;
    this.executionWeatherErrorCode = '';
    hilog.info(0x0000, TAG, `[WEATHER_STAGE][refresh_begin] stage=${resolvedStage}, trigger=${trigger}, forceRefresh=${forceRefresh}`);
    hilog.info(0x0000, TAG, `[WEATHER_EXEC][refresh_begin] trigger=${trigger}, forceRefresh=${forceRefresh}`);
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_REPLAN][refresh_begin] trigger=${trigger}, forceRefresh=${forceRefresh}, prefHeat=${this.weatherUserPreference.heatSensitivity}, prefRain=${this.weatherUserPreference.rainSensitivity}, prefTolerance=${this.weatherUserPreference.weatherRiskTolerance}`
    );

    try {
      const currentLocation = this.resolveExecutionCurrentLocation();
      if ((trigger === 'TIMER' || trigger === 'LOCATION_CHANGE') && !forceRefresh &&
        this.shouldSkipByLocationThreshold(currentLocation)) {
        this.executionWeatherLoading = false;
        return;
      }
      if (trigger === 'LOCATION_CHANGE' && !forceRefresh) {
        const nowTs = Date.now();
        if (nowTs - this.executionWeatherLastLocationTriggerAt < this.executionWeatherLocationTriggerCooldownMs) {
          this.executionWeatherLoading = false;
          return;
        }
        this.executionWeatherLastLocationTriggerAt = nowTs;
      }

      const result = await this.weatherFacade.buildExecutionContext(
        this.events,
        currentLocation ?? undefined,
        forceRefresh,
        this.weatherUserPreference,
        this.weatherCollabOptions,
        resolvedStage
      );
      const context = result.context;
      const collab = context.collabContext;
      this.executionWeatherScore = context.executionRiskScore ?? -1;
      this.executionWeatherRefreshAt = Date.now();
      this.executionWeatherCollabSummary = collab?.collabSummary ?? '';
      this.executionWeatherCollabBadge = this.executionWeatherCollabSummary.trim().length > 0
        ? (collab && collab.cityGroupCount > 1 ? '跨城协同中' : '多日趋势已纳入')
        : '';
      if (context.currentLocationWeather) {
        this.executionWeatherDisplaySource = 'CURRENT';
        this.executionWeatherCurrentText = `${context.currentLocationWeather.conditionText}${Number.isFinite(context.currentLocationWeather.temperatureCelsius) ? ` ${context.currentLocationWeather.temperatureCelsius}°C` : ''}`;
      } else if (context.nextNodeWeather) {
        this.executionWeatherDisplaySource = 'NEXT_FALLBACK';
        this.executionWeatherCurrentText = `按下一节点天气估算（${context.nextNodeWeather.conditionText}${Number.isFinite(context.nextNodeWeather.temperatureCelsius) ? ` ${context.nextNodeWeather.temperatureCelsius}°C` : ''}）`;
      } else {
        this.executionWeatherDisplaySource = 'UNKNOWN';
        this.executionWeatherCurrentText = '天气未知';
      }
      this.executionWeatherNextText = context.nextNodeWeather
        ? `${context.nextNodeWeather.conditionText}${Number.isFinite(context.nextNodeWeather.temperatureCelsius) ? ` ${context.nextNodeWeather.temperatureCelsius}°C` : ''}`
        : '天气未知';

      const suggestions = this.weatherFacade.buildExecutionAdjustments(
        this.planId,
        context,
        result.sourceEvents,
        this.weatherUserPreference
      );
      this.executionWeatherSuggestions = this.filterActiveExecutionSuggestions(suggestions);
      this.executionSuggestionMap.clear();
      this.executionWeatherSuggestions.forEach((item: WeatherSuggestion) => {
        this.executionSuggestionMap.set(item.suggestionId, item);
      });
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][suggestion_sync] listSize=${this.executionWeatherSuggestions.length}, mapSize=${this.executionSuggestionMap.size}`
      );
      if (this.executionWeatherSuggestions.length > 0) {
        this.applyExecutionSuggestion(this.executionWeatherSuggestions[0], trigger);
      } else {
        this.executionWeatherHint = '执行天气稳定，按当前节奏继续即可。';
        this.executionWeatherLevel = 'INFO';
      }
      this.patchExecutionWeatherToEvents(result.eventMap, forceRefresh);
      this.events = [...this.events];
      if (currentLocation) {
        this.executionWeatherLastLocation = {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude
        };
      }
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_EXEC][refresh_done] trigger=${trigger}, targets=${result.sourceEvents.length}, suggestions=${this.executionWeatherSuggestions.length}, score=${this.executionWeatherScore}, level=${this.executionWeatherLevel}, dayWindowCount=${collab?.dayWindowCount ?? 0}, cityGroupCount=${collab?.cityGroupCount ?? 0}, cityCappedCount=${collab?.cityCappedCount ?? 0}, cityMissCount=${collab?.cityMissCount ?? 0}, trendTag=${collab?.trendTag ?? 'UNKNOWN'}, fallbackPath=${collab?.fallbackPath ?? ''}`
      );
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][refresh_done] trigger=${trigger}, requestTargets=${result.sourceEvents.length}, cacheHit=0, failures=${this.executionWeatherErrorCode || 'NONE'}, prefHeat=${this.weatherUserPreference.heatSensitivity}, prefRain=${this.weatherUserPreference.rainSensitivity}, dayWindowCount=${collab?.dayWindowCount ?? 0}, cityGroupCount=${collab?.cityGroupCount ?? 0}, cityCappedCount=${collab?.cityCappedCount ?? 0}, cityMissCount=${collab?.cityMissCount ?? 0}, trendTag=${collab?.trendTag ?? 'UNKNOWN'}, fallbackPath=${collab?.fallbackPath ?? ''}`
      );
    } catch (error) {
      this.executionWeatherErrorCode = 'WEATHER_002';
      this.executionWeatherHint = '执行天气刷新失败，已降级使用节点天气/缓存。';
      this.executionWeatherDisplaySource = 'UNKNOWN';
      this.executionWeatherCollabBadge = '';
      this.executionWeatherCollabSummary = '';
      hilog.warn(0x0000, TAG, `[WEATHER_EXEC][refresh_failed] trigger=${trigger}, reason=${JSON.stringify(error)}`);
      hilog.warn(0x0000, TAG, `[WEATHER_REPLAN][refresh_failed] trigger=${trigger}, reason=${JSON.stringify(error)}`);
    } finally {
      this.executionWeatherLoading = false;
    }
  }

  private applyExecutionSuggestion(suggestion: WeatherSuggestion, trigger: string): void {
    this.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
    this.executionWeatherHint = suggestion.message;
    this.executionWeatherLevel = suggestion.level;

    const now = Date.now();
    if (now - this.executionWeatherLastEmitAt < 90_000 && trigger !== 'MANUAL') {
      return;
    }
    if (this.isExecutionSuggestionCoolingDown(suggestion, now) && trigger !== 'MANUAL') {
      return;
    }
    this.executionWeatherLastEmitAt = now;
    this.markExecutionSuggestionCooldown(suggestion, now);

    if (suggestion.level === 'NOTICE' || suggestion.level === 'WARNING') {
      const strategyHint = this.buildExecutionStrategyHint(suggestion);
      const strategyAdjustment = this.buildExecutionStrategyAdjustment(suggestion);
      const payload = WeatherReminderStore.fromSuggestion(this.planId, suggestion, strategyHint, strategyAdjustment);
      WeatherReminderStore.writePayload(payload);
      const candidateCount = suggestion.actionPayload?.replacementCandidates?.length ?? 0;
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][reminder_emit] level=${suggestion.level}, trigger=${trigger}, action=${suggestion.actionType}, candidates=${candidateCount}, message=${suggestion.message}`
      );
    }
  }

  private buildExecutionStrategyHint(suggestion: WeatherSuggestion): string | undefined {
    if (suggestion.triggerType === 'RAIN') {
      return '明日有雨，建议降低行程密度。';
    }
    if (suggestion.triggerType === 'HEAT') {
      return '持续高温，建议减少体力消耗。';
    }
    return undefined;
  }

  private buildExecutionStrategyAdjustment(suggestion: WeatherSuggestion): WeatherStrategyAdjustment | undefined {
    if (suggestion.triggerType === 'RAIN') {
      return { density: -1 };
    }
    if (suggestion.triggerType === 'HEAT') {
      return { pace: -1, energy: -1 };
    }
    return undefined;
  }

  public async requestSoftReplan(
    planId: number,
    suggestionId: string,
    mode: SoftReplanMode
  ): Promise<SoftReplanApplyResult> {
    const emptyPreview: SoftReplanPreview = {
      suggestionId: suggestionId,
      actionType: 'NONE',
      changedOrder: false,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      reasonCode: 'no_suggestion',
      startFromEventId: 0,
      changeSummary: [],
      summary: '无可用建议',
      riskDelta: 0
    };
    const failWithLog = (
      errorCode: '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY',
      reasonCode: string,
      startFromEventId: number,
      preview: SoftReplanPreview,
      rolledBack: boolean,
      actionType: WeatherSuggestionActionType = 'NONE'
    ): SoftReplanApplyResult => {
      this.logSoftReplanFailure(
        planId,
        suggestionId,
        mode,
        this.getCurrentPlanStatus(),
        errorCode,
        reasonCode,
        startFromEventId,
        actionType,
        preview.affectedNodeIds.length
      );
      return {
        success: false,
        rolledBack: rolledBack,
        errorCode: errorCode,
        reasonCode: reasonCode,
        startFromEventId: startFromEventId,
        preview: preview
      };
    };
    if (planId <= 0 || this.planId !== planId || !suggestionId || suggestionId.trim().length === 0) {
      return failWithLog('REPLAN_INVALID', 'invalid_input', 0, emptyPreview, false);
    }
    const status = this.getCurrentPlanStatus();
    const suggestionInList = this.executionWeatherSuggestions.some((item: WeatherSuggestion) => item.suggestionId === suggestionId);
    const mapHasSuggestion = this.executionSuggestionMap.has(suggestionId);
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_REPLAN][apply_begin] planId=${planId}, suggestionId=${suggestionId}, mode=${mode}, status=${status}, busy=${this.executionReplanBusy ? 1 : 0}, listSize=${this.executionWeatherSuggestions.length}, mapSize=${this.executionSuggestionMap.size}, suggestionInList=${suggestionInList ? 1 : 0}, mapHasSuggestion=${mapHasSuggestion ? 1 : 0}`
    );
    if (!(status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED)) {
      return failWithLog('REPLAN_INVALID', 'status_blocked', 0, emptyPreview, false);
    }
    if (this.executionReplanBusy) {
      return failWithLog('REPLAN_BUSY', 'busy', 0, emptyPreview, false);
    }
    const activeEvent = this.findCurrentActiveEvent();
    const softGate = this.planStateMachine.requestSoftReplan({
      planId: `${planId}`,
      reason: 'weather_suggestion',
      currentNodeId: activeEvent ? `${activeEvent.id}` : undefined,
      preserveCompletedNodes: true,
      preserveStartedWindow: true,
      useWeatherConstraint: true
    });
    if (!softGate.success) {
      return failWithLog(
        'REPLAN_INVALID',
        softGate.reasonCode ?? 'status_blocked',
        softGate.startFromEventId ?? 0,
        emptyPreview,
        false
      );
    }
    const suggestion = this.executionSuggestionMap.get(suggestionId);
    if (!suggestion) {
      return failWithLog('REPLAN_INVALID', 'suggestion_missing', 0, emptyPreview, false);
    }
    const preview = this.buildSoftReplanPreview(suggestion, softGate.reasonCode, softGate.startFromEventId ?? 0);
    if (mode === 'PREVIEW') {
      return {
        success: true,
        rolledBack: false,
        errorCode: '',
        reasonCode: preview.reasonCode,
        startFromEventId: preview.startFromEventId,
        preview: preview
      };
    }

    this.executionReplanBusy = true;
    this.executionWeatherApplying = true;
    const snapshot = this.cloneEventSnapshot();
    const beforeNodes = this.snapshotScheduleNodes();
    const startedAt = Date.now();
    try {
      if (this.containsImmutableNode(this.resolveSoftReplanTargetEventIds(suggestion.actionPayload?.targetNodeIds ?? suggestion.relatedNodeIds))) {
        preview.reasonCode = 'immutable_blocked';
        preview.changeSummary = [{
          type: 'IMMUTABLE_BLOCKED',
          nodeId: '',
          before: 'pending',
          after: 'blocked',
          deltaMinutes: 0
        }];
        return failWithLog(
          'REPLAN_IMMUTABLE',
          preview.reasonCode ?? 'immutable_blocked',
          preview.startFromEventId ?? 0,
          preview,
          false,
          suggestion.actionType
        );
      }
      const applyOk = await this.applySuggestionAction(suggestion);
      if (!applyOk) {
        this.restoreEventSnapshot(snapshot);
        return failWithLog(
          'REPLAN_CONFLICT',
          'apply_failed',
          preview.startFromEventId ?? 0,
          preview,
          true,
          suggestion.actionType
        );
      }
      const startFromEventId = softGate.startFromEventId && softGate.startFromEventId > 0
        ? softGate.startFromEventId
        : this.resolveSoftReplanStartEventId(preview);
      if (startFromEventId > 0) {
        this.recalculateFromEventId(startFromEventId);
      } else {
        this.recalculateFromIndex(0);
      }
      if (Date.now() - startedAt > 10_000) {
        this.restoreEventSnapshot(snapshot);
        return failWithLog(
          'REPLAN_TIMEOUT',
          'timeout',
          startFromEventId,
          preview,
          true,
          suggestion.actionType
        );
      }
      const afterNodes = this.snapshotScheduleNodes();
      const structuredSummary = this.buildStructuredReplanSummary(beforeNodes, afterNodes, preview.affectedNodeIds);
      preview.startFromEventId = startFromEventId;
      preview.changeSummary = structuredSummary;
      preview.summary = this.composeReplanSummaryText(preview, structuredSummary);
      this.executionWeatherAppliedSummary = preview.summary;
      this.executionWeatherHint = preview.summary;
      this.executionWeatherLevel = 'NOTICE';
      this.executionWeatherSuggestions = this.executionWeatherSuggestions.filter((item: WeatherSuggestion) =>
        item.suggestionId !== suggestionId
      );
      this.executionSuggestionMap.delete(suggestionId);
      this.markScheduleChanged();
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_REPLAN][apply_done] mode=${mode}, suggestionId=${suggestionId}, action=${suggestion.actionType}, affected=${preview.affectedNodeIds.length}, riskDelta=${preview.riskDelta}, reason=${softGate.reasonCode ?? ''}, startFromEventId=${softGate.startFromEventId ?? 0}, rolledBack=false, result=SUCCESS`
      );
      return {
        success: true,
        rolledBack: false,
        errorCode: '',
        reasonCode: preview.reasonCode,
        startFromEventId: preview.startFromEventId,
        preview: preview
      };
    } catch (error) {
      this.restoreEventSnapshot(snapshot);
      hilog.warn(0x0000, TAG, `[WEATHER_REPLAN][apply_failed] suggestionId=${suggestionId}, rolledBack=true, result=FAILED, reason=${JSON.stringify(error)}`);
      return failWithLog(
        'REPLAN_CONFLICT',
        'exception',
        preview.startFromEventId ?? 0,
        preview,
        true,
        suggestion.actionType
      );
    } finally {
      this.executionReplanBusy = false;
      this.executionWeatherApplying = false;
    }
  }

  private logSoftReplanFailure(
    planId: number,
    suggestionId: string,
    mode: SoftReplanMode,
    status: PlanStatus,
    errorCode: string,
    reasonCode: string,
    startFromEventId: number,
    actionType: WeatherSuggestionActionType,
    affectedNodeCount: number
  ): void {
    hilog.warn(
      0x0000,
      TAG,
      `[WEATHER_REPLAN][apply_fail] planId=${planId}, suggestionId=${suggestionId}, mode=${mode}, status=${status}, errorCode=${errorCode}, reasonCode=${reasonCode}, startFromEventId=${startFromEventId}, actionType=${actionType}, affectedNodeCount=${affectedNodeCount}`
    );
  }

  public dismissExecutionSuggestion(suggestionId: string): void {
    if (!suggestionId || suggestionId.trim().length === 0) {
      return;
    }
    this.executionWeatherSuggestions = this.executionWeatherSuggestions.filter((item: WeatherSuggestion) =>
      item.suggestionId !== suggestionId
    );
    this.executionSuggestionMap.delete(suggestionId);
  }

  private filterActiveExecutionSuggestions(items: WeatherSuggestion[]): WeatherSuggestion[] {
    const now = Date.now();
    const filtered = items.filter((item: WeatherSuggestion) => {
      if (!item) {
        return false;
      }
      if (item.expiresAt > 0 && item.expiresAt < now) {
        return false;
      }
      return !this.isExecutionSuggestionCoolingDown(item, now);
    });
    filtered.sort((a: WeatherSuggestion, b: WeatherSuggestion) => {
      const levelWeight = (level: 'INFO' | 'NOTICE' | 'WARNING'): number =>
        level === 'WARNING' ? 3 : (level === 'NOTICE' ? 2 : 1);
      if (levelWeight(a.level) !== levelWeight(b.level)) {
        return levelWeight(b.level) - levelWeight(a.level);
      }
      return a.createdAt - b.createdAt;
    });
    return filtered;
  }

  private isExecutionSuggestionCoolingDown(suggestion: WeatherSuggestion, now: number): boolean {
    const key = suggestion.cooldownKey || suggestion.suggestionId;
    const last = this.executionSuggestionCooldownMap.get(key) ?? 0;
    return last > 0 && now - last < this.executionSuggestionCooldownMs;
  }

  private markExecutionSuggestionCooldown(suggestion: WeatherSuggestion, now: number): void {
    const key = suggestion.cooldownKey || suggestion.suggestionId;
    this.executionSuggestionCooldownMap.set(key, now);
  }

  private buildSoftReplanPreview(
    suggestion: WeatherSuggestion,
    reasonCode: string | undefined,
    startFromEventId: number
  ): SoftReplanPreview {
    const payload = suggestion.actionPayload;
    const affectedNodeIds = payload?.targetNodeIds ?? suggestion.relatedNodeIds ?? [];
    const skippedNodeIds = suggestion.actionType === 'SKIP_NODE' ? affectedNodeIds.slice(0, 1) : [];
    const changedOrder = suggestion.actionType === 'REORDER' || suggestion.actionType === 'REPLACE_NODE';
    const changedDurations = suggestion.actionType === 'SHORTEN_STAY';
    let summary = '天气建议已准备，可应用调整。';
    if (suggestion.actionType === 'REORDER') {
      summary = `已应用顺序调整，影响 ${affectedNodeIds.length} 个节点。`;
    } else if (suggestion.actionType === 'SHORTEN_STAY') {
      const mins = payload?.suggestedStayMinutes ?? 45;
      summary = `已缩短停留时长至约 ${mins} 分钟。`;
    } else if (suggestion.actionType === 'SKIP_NODE') {
      summary = '已跳过高风险节点，继续后续安排。';
    } else if (suggestion.actionType === 'REPLACE_NODE') {
      summary = '已切换到保守执行策略（替代建议）。';
    }
    return {
      suggestionId: suggestion.suggestionId,
      actionType: suggestion.actionType,
      changedOrder: changedOrder,
      changedDurations: changedDurations,
      skippedNodeIds: skippedNodeIds,
      affectedNodeIds: affectedNodeIds,
      reasonCode: reasonCode ?? this.resolveReplanReasonCode(suggestion.actionType),
      startFromEventId: startFromEventId,
      changeSummary: [],
      summary: summary,
      riskDelta: suggestion.level === 'WARNING' ? -20 : (suggestion.level === 'NOTICE' ? -10 : -5)
    };
  }

  private resolveReplanReasonCode(actionType: WeatherSuggestionActionType): string {
    if (actionType === 'REORDER') {
      return 'order_adjusted';
    }
    if (actionType === 'SHORTEN_STAY') {
      return 'duration_adjusted';
    }
    if (actionType === 'SKIP_NODE') {
      return 'node_skipped';
    }
    if (actionType === 'REPLACE_NODE') {
      return 'node_replaced';
    }
    return 'soft_replan';
  }

  private snapshotScheduleNodes(): Map<number, ReplanNodeSnapshot> {
    const map = new Map<number, ReplanNodeSnapshot>();
    this.events.filter((item: EventEntity) => item.status === 1).forEach((item: EventEntity) => {
      map.set(item.id, {
        id: item.id,
        sortOrder: item.sort_order,
        duration: item.duration,
        startTs: item.dynamic_start_time,
        endTs: item.dynamic_end_time
      });
    });
    return map;
  }

  private buildStructuredReplanSummary(
    beforeMap: Map<number, ReplanNodeSnapshot>,
    afterMap: Map<number, ReplanNodeSnapshot>,
    affectedNodeIds: string[]
  ): ReplanChangeSummaryItem[] {
    const summary: ReplanChangeSummaryItem[] = [];
    const ids: number[] = [];
    (affectedNodeIds || []).forEach((idText: string) => {
      const id = Number(idText);
      if (Number.isFinite(id) && id > 0) {
        ids.push(id);
      }
    });
    ids.forEach((id: number) => {
      const before = beforeMap.get(id);
      const after = afterMap.get(id);
      if (!before || !after) {
        return;
      }
      if (before.sortOrder !== after.sortOrder) {
        summary.push({
          type: 'ORDER_CHANGED',
          nodeId: `${id}`,
          before: `${before.sortOrder}`,
          after: `${after.sortOrder}`
        });
      }
      if (before.duration !== after.duration) {
        summary.push({
          type: 'DURATION_CHANGED',
          nodeId: `${id}`,
          before: `${before.duration}`,
          after: `${after.duration}`,
          deltaMinutes: after.duration - before.duration
        });
      }
      if (before.startTs !== after.startTs || before.endTs !== after.endTs) {
        summary.push({
          type: 'TIME_SHIFTED',
          nodeId: `${id}`,
          before: `${before.startTs}-${before.endTs}`,
          after: `${after.startTs}-${after.endTs}`,
          deltaMinutes: Math.round((after.startTs - before.startTs) / 60000)
        });
      }
    });
    if (summary.length === 0) {
      summary.push({
        type: 'NO_OP',
        nodeId: '',
        before: 'stable',
        after: 'stable',
        deltaMinutes: 0
      });
    }
    return summary;
  }

  private composeReplanSummaryText(preview: SoftReplanPreview, structured: ReplanChangeSummaryItem[]): string {
    const orderCount = structured.filter((item: ReplanChangeSummaryItem) => item.type === 'ORDER_CHANGED').length;
    const durationCount = structured.filter((item: ReplanChangeSummaryItem) => item.type === 'DURATION_CHANGED').length;
    const shiftCount = structured.filter((item: ReplanChangeSummaryItem) => item.type === 'TIME_SHIFTED').length;
    if (preview.reasonCode === 'immutable_blocked') {
      return '命中已完成/锁定节点保护，未执行重排。';
    }
    if (orderCount === 0 && durationCount === 0 && shiftCount === 0) {
      return '重排执行完成，计划保持稳定。';
    }
    return `重排完成：顺序变更 ${orderCount} 项，时长变更 ${durationCount} 项，时间偏移 ${shiftCount} 项。`;
  }

  private async applySuggestionAction(suggestion: WeatherSuggestion): Promise<boolean> {
    const payload = suggestion.actionPayload;
    const targetIds = this.resolveSoftReplanTargetEventIds(payload?.targetNodeIds ?? suggestion.relatedNodeIds);
    if (targetIds.length === 0 && suggestion.actionType !== 'NONE') {
      return false;
    }
    if (this.containsImmutableNode(targetIds)) {
      return false;
    }
    if (suggestion.actionType === 'REORDER') {
      return await this.applySoftReorder(payload?.targetOrderNodeIds ?? []);
    }
    if (suggestion.actionType === 'SHORTEN_STAY') {
      return await this.applySoftShorten(targetIds, payload?.suggestedStayMinutes);
    }
    if (suggestion.actionType === 'SKIP_NODE') {
      return await this.applySoftSkip(targetIds);
    }
    if (suggestion.actionType === 'REPLACE_NODE') {
      const candidateCount = suggestion.actionPayload?.replacementCandidates?.length ?? 0;
      hilog.info(0x0000, TAG, `[WEATHER_REPLAN][replace_quality] candidates=${candidateCount}, suggestionId=${suggestion.suggestionId}`);
      const reordered = await this.applySoftReorder(payload?.targetOrderNodeIds ?? []);
      if (reordered) {
        return true;
      }
      hilog.info(0x0000, TAG, `[WEATHER_REPLAN][replace_fallback] suggestionId=${suggestion.suggestionId}, fallback=SHORTEN_STAY, targetCount=${targetIds.length}`);
      return await this.applySoftShorten(targetIds, payload?.suggestedStayMinutes ?? 45);
    }
    return true;
  }

  private resolveSoftReplanTargetEventIds(nodeIds: string[]): number[] {
    const allowed = this.getSoftReplanFutureCandidates().map((item: EventEntity) => item.id);
    const allowSet = new Set<number>(allowed);
    const resolved: number[] = [];
    (nodeIds || []).forEach((idText: string) => {
      const id = Number(idText);
      if (Number.isFinite(id) && allowSet.has(id)) {
        resolved.push(id);
      }
    });
    return resolved;
  }

  private resolveSoftReplanStartEventId(preview: SoftReplanPreview): number {
    const ids = preview.affectedNodeIds ?? [];
    if (ids.length === 0) {
      return 0;
    }
    let minId = Number.MAX_SAFE_INTEGER;
    ids.forEach((idText: string) => {
      const id = Number(idText);
      if (Number.isFinite(id) && id > 0 && id < minId) {
        minId = id;
      }
    });
    return minId === Number.MAX_SAFE_INTEGER ? 0 : minId;
  }

  private getSoftReplanFutureCandidates(): EventEntity[] {
    const ordered = this.getOrderedScheduleEvents();
    const pending = ordered.filter((item: EventEntity) => item.completion_status === EventEntity.STATE_PENDING);
    const active = pending.find((item: EventEntity) => TimelineExecutionState.isActive(item));
    let start = 0;
    if (active) {
      const idx = pending.findIndex((item: EventEntity) => item.id === active.id);
      start = idx >= 0 ? Math.min(idx + 1, Math.max(0, pending.length - 1)) : 0;
    }
    return pending.slice(start, start + 3);
  }

  private containsImmutableNode(targetIds: number[]): boolean {
    return targetIds.some((id: number) => {
      const event = this.events.find((item: EventEntity) => item.id === id);
      if (!event) {
        return true;
      }
      if (event.completion_status !== EventEntity.STATE_PENDING) {
        return true;
      }
      return event.lock_status === 1 && !!event.fixed_start_time;
    });
  }

  private async applySoftReorder(orderNodeIds: string[]): Promise<boolean> {
    if (!orderNodeIds || orderNodeIds.length < 2) {
      return false;
    }
    const targetIds = this.resolveSoftReplanTargetEventIds(orderNodeIds);
    if (targetIds.length < 2) {
      return false;
    }
    const schedule = this.events.filter((item: EventEntity) => item.status === 1);
    const byId = new Map<number, EventEntity>();
    schedule.forEach((item: EventEntity) => byId.set(item.id, item));

    const reorderedTargets: EventEntity[] = [];
    targetIds.forEach((id: number) => {
      const found = byId.get(id);
      if (found) {
        reorderedTargets.push(found);
      }
    });
    if (reorderedTargets.length < 2) {
      return false;
    }

    const targetSet = new Set<number>(reorderedTargets.map((item: EventEntity) => item.id));
    const merged: EventEntity[] = [];
    let writeIdx = 0;
    schedule.forEach((item: EventEntity) => {
      if (targetSet.has(item.id)) {
        if (writeIdx < reorderedTargets.length) {
          merged.push(reorderedTargets[writeIdx]);
          writeIdx += 1;
        } else {
          merged.push(item);
        }
      } else {
        merged.push(item);
      }
    });
    merged.forEach((item: EventEntity, idx: number) => {
      item.sort_order = idx * 100;
    });
    await EventRepositoryImpl.updateTimelineConsistency(merged.map((item: EventEntity) => item.toInterface()), this.planId);
    this.events.sort((a: EventEntity, b: EventEntity) => {
      if (a.status !== b.status) {
        return b.status - a.status;
      }
      return a.sort_order - b.sort_order;
    });
    this.recalculateFromIndex(0);
    return true;
  }

  private async applySoftShorten(targetIds: number[], suggestedStayMinutes?: number): Promise<boolean> {
    if (!targetIds || targetIds.length === 0) {
      return false;
    }
    const normalizedSuggestion = suggestedStayMinutes ?? 45;
    const minutes = Number.isFinite(normalizedSuggestion) && normalizedSuggestion > 0
      ? Math.floor(normalizedSuggestion)
      : 45;
    const minAllowed = Math.max(20, this.getMinEventDurationLimit());
    const newDuration = Math.max(minAllowed, minutes);
    let changed = false;
    for (let i = 0; i < targetIds.length; i++) {
      const target = this.events.find((item: EventEntity) => item.id === targetIds[i]);
      if (!target || target.duration <= newDuration) {
        continue;
      }
      target.duration = newDuration;
      await EventRepositoryImpl.updateSingleField(target.id, EventEntity.DURATION, target.duration, this.planId);
      changed = true;
    }
    if (changed) {
      this.recalculateFromIndex(0);
    }
    return changed;
  }

  private async applySoftSkip(targetIds: number[]): Promise<boolean> {
    if (!targetIds || targetIds.length === 0) {
      return false;
    }
    const target = this.events.find((item: EventEntity) => item.id === targetIds[0]);
    if (!target) {
      return false;
    }
    await this.skipEvent(target);
    return true;
  }

  private cloneEventSnapshot(): EventEntity[] {
    return this.events.map((item: EventEntity) => EventEntity.fromInterface(item.toInterface(), this.planId));
  }

  private restoreEventSnapshot(snapshot: EventEntity[]): void {
    this.events = snapshot.map((item: EventEntity) => EventEntity.fromInterface(item.toInterface(), this.planId));
    this.recalculateFromIndex(0);
  }

  private patchExecutionWeatherToEvents(eventMap: Map<number, import('../domain/services/WeatherModels').PlanNodeWeatherBinding>, forceRefresh: boolean): void {
    this.events.forEach((event: EventEntity) => {
      if (event.completion_status !== EventEntity.STATE_PENDING) {
        return;
      }
      const binding = eventMap.get(event.id);
      if (!binding) {
        return;
      }
      event.weather_text = binding.weather?.conditionText ?? '天气未知';
      event.weather_condition = binding.weather?.conditionCode ?? 'UNKNOWN';
      event.weather_temperature = binding.weather?.temperatureCelsius ?? 0;
      event.weather_fetch_time = binding.weather?.fetchTime ?? Date.now();
      if (forceRefresh && event.id > 0) {
        const updates: EventFieldUpdate[] = [
          { column: EventEntity.WEATHER_CONDITION, value: event.weather_condition },
          { column: EventEntity.WEATHER_TEMPERATURE, value: event.weather_temperature },
          { column: EventEntity.WEATHER_TEXT, value: event.weather_text },
          { column: EventEntity.WEATHER_FETCH_TIME, value: event.weather_fetch_time }
        ];
        void EventRepositoryImpl.updateFields(event.id, updates, this.planId);
      }
    });
  }

  private resolveExecutionCurrentLocation(): GeoPointInput | null {
    const snapshot = ArrivalReminderEngine.getInstance().getLastKnownLocation();
    if (snapshot && this.isValidCoordinate(snapshot.latitude, snapshot.longitude)) {
      return { latitude: snapshot.latitude, longitude: snapshot.longitude };
    }

    const active = this.findCurrentActiveEvent();
    if (active && this.isValidCoordinate(active.latitude, active.longitude)) {
      return { latitude: active.latitude, longitude: active.longitude };
    }
    const next = this.getCompanionContext().nextEvent;
    if (next && this.isValidCoordinate(next.latitude, next.longitude)) {
      return { latitude: next.latitude, longitude: next.longitude };
    }
    return null;
  }

  private shouldSkipByLocationThreshold(currentLocation: GeoPointInput | null): boolean {
    if (!currentLocation || !this.executionWeatherLastLocation) {
      return false;
    }
    const delta = this.measureDistanceMeters(
      currentLocation.latitude,
      currentLocation.longitude,
      this.executionWeatherLastLocation.latitude,
      this.executionWeatherLastLocation.longitude
    );
    return delta < this.executionWeatherLocationDeltaMeters;
  }

  private async resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source: 'add' | 'update' = 'add',
    fallbackLat: number = 0,
    fallbackLng: number = 0
  ): Promise<GeoPointInput> {
    const baseLat = lat ?? fallbackLat;
    const baseLng = lng ?? fallbackLng;
    if (!this.isCoordinateMissingForWeather(baseLat, baseLng)) {
      const keep: GeoPointInput = { latitude: baseLat, longitude: baseLng };
      return keep;
    }
    const trimmedName = placeName.trim();
    if (trimmedName.length === 0) {
      const keep: GeoPointInput = { latitude: baseLat, longitude: baseLng };
      return keep;
    }
    const geocode = await AmapService.getGeocode(trimmedName);
    if (geocode && this.isValidCoordinate(geocode.lat, geocode.lng)) {
      hilog.info(0x0000, TAG, `[WEATHER_GEO][${source}] geocode_hit name=${trimmedName}, lat=${geocode.lat}, lng=${geocode.lng}`);
      const hit: GeoPointInput = { latitude: geocode.lat, longitude: geocode.lng };
      return hit;
    }
    hilog.warn(0x0000, TAG, `[WEATHER_GEO][${source}] geocode_miss name=${trimmedName}, fallbackLat=${baseLat}, fallbackLng=${baseLng}`);
    const miss: GeoPointInput = { latitude: baseLat, longitude: baseLng };
    return miss;
  }

  private isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    if (!this.isValidCoordinate(latitude, longitude)) {
      return true;
    }
    return latitude === -1 || longitude === -1 || latitude === 0 || longitude === 0;
  }

  private isValidCoordinate(latitude: number, longitude: number): boolean {
    return Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude === 0 && longitude === 0);
  }

  private measureDistanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const rad = (deg: number): number => deg * Math.PI / 180;
    const earthRadius = 6378137;
    const dLat = rad(lat2 - lat1);
    const dLng = rad(lng2 - lng1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  /**
   * [新增] AI 智能生成入口
   */
  public async generateByAi(userPrompt: string, strategyMode: number = 0, customStrategy?: ComposableStrategy) {
    try {
      this.currentStrategyMode = strategyMode;

      // 收集已有AI生成的地点，避免重复
      const existingPlaces = this.events
        .filter(e => e.source === 1)
        .map(e => e.name)
        .filter(name => name.length > 0);

      // 计算合理的起始时间
      const scheduleEvents = this.events.filter(e => e.status === 1);
      let startTimeHint = '建议从上午9:00开始';
      if (scheduleEvents.length > 0) {
        const lastEvent = scheduleEvents[scheduleEvents.length - 1];
        const lastEndTime = lastEvent.dynamic_end_time;
        if (lastEndTime > 0) {
          const lastDate = new Date(lastEndTime);
          const nextDay = new Date(lastDate);
          nextDay.setDate(nextDay.getDate() + 1);
          nextDay.setHours(9, 0, 0, 0);
          startTimeHint = `建议从${nextDay.getMonth() + 1}月${nextDay.getDate()}日上午9:00开始`;
        }
      }

      // 增强userPrompt
      let enhancedPrompt = userPrompt;
      if (existingPlaces.length > 0) {
        enhancedPrompt += `\n【已有地点】请避免重复：${existingPlaces.join('、')}`;
      }
      enhancedPrompt += `\n【起始时间】${startTimeHint}`;
      if (this.weatherFeatureEnabled) {
        try {
          const weatherStage = this.resolveCurrentWeatherStage();
          const weatherResult = await this.weatherFacade.buildPlanningContext(
            this.events,
            this.weatherUserPreference,
            this.weatherCollabOptions,
            weatherStage
          );
          const effectiveStrategy = customStrategy ?? await this.getCurrentStrategy();
          const weatherAwareConstraint = StrategyService.buildWeatherAwareConstraint(
            effectiveStrategy,
            weatherResult.context.routeSuitability.routeScore,
            weatherResult.context.routeSuitability.riskTags,
            weatherResult.context.collabContext?.trendTag,
            strategyMode
          );
          const weatherSummary = this.weatherFacade.buildPromptSummary(weatherResult.context, this.weatherUserPreference);
          enhancedPrompt += this.composeWeatherConstraintPrompt(weatherAwareConstraint, weatherSummary);
          await this.applyPlanningWeatherResult(weatherResult, false);
        } catch (_weatherError) {
          enhancedPrompt += '\n【天气约束】天气数据暂不可用，请优先保证路线可执行性。';
        }
      } else {
        enhancedPrompt += '\n【天气约束】用户已关闭天气功能，请忽略天气因素。';
      }

      const aiItems = await AiService.generateItineraryWithStrategy({
        userPrompt: enhancedPrompt,
        strategyMode: customStrategy ? -1 : strategyMode,
        customStrategy: customStrategy
      });

      if (!aiItems || aiItems.length === 0) {
        return;
      }

      // 保存AI上下文到数据库
      const explanation = StrategyService.buildStrategyExplanation(strategyMode);
      await this.persistence.saveAiContext(this.planId, userPrompt, explanation);

      if (customStrategy) {
        await PlanRepositoryImpl.updateStrategyDimensions(
          this.planId,
          customStrategy.density,
          customStrategy.pace,
          customStrategy.preference,
          customStrategy.energy
        );
      } else {
        await this.persistence.updateStrategyMode(this.planId, strategyMode);
      }

      // 记录用户策略偏好（用于个性化推荐）
      UserProfileService.recordStrategyUsage(strategyMode, customStrategy).catch(() => {});

      // 计算新事件的dayOffset（如果已有行程，新事件应该在下一天）
      const existingSchedule = this.events.filter(e => e.status === 1);
      const newDayOffset = existingSchedule.length > 0
        ? Math.max(...existingSchedule.map(e => e.day_offset || 0)) + 1
        : 0;

      for (const item of aiItems) {
        const newItemInterface: import('../model/interface/IStandardEvent').TravelPlanItem = {
          name: item.name,
          duration: item.duration,
          type: 'FLOW',
          preTravelMinutes: -1,
          sortOrder: 0,
          status: 0,
          lockStatus: 0,
          fixedStartTime: undefined,
          dayOffset: newDayOffset,
          itemType: item.type,
          priority: item.type === 1 ? 0 : 1,  // 美食=普通(0), 景点/住宿=必去(1)
          isTravelManual: 0,
          source: 1,
          aiReasoning: item.ai_reasoning || 'AI 智能推荐',
          delFlag: 0,
          groupId: 0,
          address: '',
          travelMode: 2
        };

        const newId = await EventRepositoryImpl.insertEvent(this.planId, newItemInterface);
        newItemInterface.id = newId;

        const newEntity = EventEntity.fromInterface(newItemInterface, this.planId);
        this.events.push(newEntity);
      }

      this.markScheduleChanged();
      this.events = [...this.events];

    } catch (error) {
      console.error(TAG, 'AI Generation Failed');

      if (error instanceof Error) {
        throw error;
      } else {
        throw new Error(JSON.stringify(error));
      }
    }
  }


  public getStrategyMode(): number {
    return this.currentStrategyMode;
  }

  public hasAiHistory(): boolean {
    return this.events.some(e => e.source === 1);
  }

  public async updateStrategyMode(mode: number): Promise<void> {
    this.currentStrategyMode = mode;
    await this.persistence.updateStrategyMode(this.planId, mode);
  }

  public async switchToCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await PlanRepositoryImpl.updateStrategyDimensions(
      this.planId,
      strategy.density,
      strategy.pace,
      strategy.preference,
      strategy.energy
    );
    this.currentStrategyMode = -1;
  }

  public async applyWeatherStrategyAdjustment(
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<boolean> {
    if (!adjustment) {
      return false;
    }
    const hasAdjustment = adjustment.density !== undefined ||
      adjustment.pace !== undefined ||
      adjustment.energy !== undefined;
    if (!hasAdjustment) {
      return false;
    }

    const current = await this.getCurrentStrategy();
    const next: ComposableStrategy = {
      density: current.density,
      pace: current.pace,
      preference: current.preference,
      energy: current.energy
    };

    if (adjustment.density !== undefined) {
      next.density = this.clampStrategyLevel(current.density + adjustment.density);
    }
    if (adjustment.pace !== undefined) {
      next.pace = this.clampStrategyLevel(current.pace + adjustment.pace);
    }
    if (adjustment.energy !== undefined) {
      next.energy = this.clampStrategyLevel(current.energy + adjustment.energy);
    }

    const changed = next.density !== current.density ||
      next.pace !== current.pace ||
      next.energy !== current.energy;
    if (!changed) {
      return false;
    }

    await PlanRepositoryImpl.updateStrategyDimensions(
      this.planId,
      next.density,
      next.pace,
      next.preference,
      next.energy
    );
    this.currentStrategyMode = -1;
    if (hint && hint.trim().length > 0) {
      this.weatherStrategyHint = hint.trim();
    }
    return true;
  }

  public async applyExecutionSuggestionWithStrategy(
    planId: number,
    suggestionId: string,
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    const strategyApplied = await this.applyWeatherStrategyAdjustment(adjustment, hint);
    const replan = await this.requestSoftReplan(planId, suggestionId, 'APPLY');
    return {
      strategyApplied: strategyApplied,
      replanSuccess: replan.success,
      errorCode: replan.errorCode || 'REPLAN_CONFLICT'
    };
  }

  public async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    return this.requestSoftReplan(this.planId, suggestionId, 'APPLY');
  }

  private async getCurrentStrategy(): Promise<ComposableStrategy> {
    const snapshot = await this.persistence.getPlanAndEvents(this.planId);
    if (!snapshot.plan) {
      return { density: 1, pace: 1, preference: 0, energy: 1 };
    }
    return {
      density: snapshot.plan.strategyDensity ?? 1,
      pace: snapshot.plan.strategyPace ?? 1,
      preference: snapshot.plan.strategyPreference ?? 0,
      energy: snapshot.plan.strategyEnergy ?? 1
    };
  }

  private clampStrategyLevel(value: number): 0 | 1 | 2 {
    if (value <= 0) {
      return 0;
    }
    if (value >= 2) {
      return 2;
    }
    return 1;
  }

  private buildWeatherStrategyAdaptationKey(generatedAt: number, routeScore: number): string {
    return `${generatedAt}_${routeScore}`;
  }

  private composeWeatherConstraintPrompt(
    weatherAwareConstraint: string,
    weatherSummary: string
  ): string {
    return `\n【策略天气联合约束】\n${weatherAwareConstraint}\n${weatherSummary}\n请把天气与策略作为联合软约束，不要输出不可执行路线，并根据用户天气偏好优化建议。`;
  }

  private async triggerStrategyAdaptation(): Promise<void> {
    const currentStrategy = await this.getCurrentStrategy();
    const context = this.behaviorTracker.getBehaviorContext(this.planId, currentStrategy);
    const decision = StrategyAdaptationEngine.analyzeAndDecide(context);

    if (!decision) {
      return;
    }

    const adjustedStrategy = StrategyAdaptationEngine.applyAdjustment(currentStrategy, decision);
    await PlanRepositoryImpl.updateStrategyDimensions(
      this.planId,
      adjustedStrategy.density,
      adjustedStrategy.pace,
      adjustedStrategy.preference,
      adjustedStrategy.energy
    );

    this.behaviorTracker.reset();
    hilog.info(0x0000, 'TimelineViewModel', `[策略自适应] ${decision.message}`);

    // 触发UI提示
    this.strategyAdaptationPrompt = {
      message: decision.message,
      oldStrategy: currentStrategy,
      newStrategy: adjustedStrategy
    };
  }

  public async regenerateWithCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await this.switchToCustomStrategy(strategy);
    await this.regenerateByCurrentStrategy();
  }

  public async regenerateByCurrentStrategy(): Promise<void> {
    // 防重复请求
    if (this.isRegenerating) {
      hilog.warn(0x0000, 'TimelineViewModel', '[AI重新生成] 正在生成中，忽略重复请求');
      return;
    }

    const snapshot = await this.persistence.getPlanAndEvents(this.planId);
    if (!snapshot.plan || !snapshot.plan.lastAiPrompt) {
      throw new Error('未找到上次生成记录');
    }

    this.isRegenerating = true;
    const oldAiEvents = this.events.filter(e => e.source === 1);
    hilog.info(0x0000, 'TimelineViewModel', `[AI重新生成] 开始，旧事件数: ${oldAiEvents.length}`);

    try {
      // 先生成新数据
      await this.generateByAi(snapshot.plan.lastAiPrompt, this.currentStrategyMode);

      // 成功后删除旧数据
      await EventRepositoryImpl.deleteEventsBySource(this.planId, 1);

      // 从内存中移除旧事件
      const newAiEvents = this.events.filter(e =>
        e.source === 1 && !oldAiEvents.some(old => old.id === e.id)
      );
      this.events = this.events.filter(e =>
        e.source !== 1 || newAiEvents.some(n => n.id === e.id)
      );
      hilog.info(0x0000, 'TimelineViewModel', `[AI重新生成] 成功，新事件数: ${newAiEvents.length}`);
    } catch (error) {
      // 失败时保留旧数据
      hilog.error(0x0000, 'TimelineViewModel', `[AI重新生成] 失败，保留旧数据`);
      throw error instanceof Error ? error : new Error('生成失败');
    } finally {
      this.isRegenerating = false;
    }
  }

  public async changeStrategyAndRegenerate(mode: number): Promise<void> {
    // 防重复请求
    if (this.isRegenerating) {
      hilog.warn(0x0000, 'TimelineViewModel', '[切换策略] 正在生成中，忽略重复请求');
      return;
    }

    const snapshot = await this.persistence.getPlanAndEvents(this.planId);
    if (!snapshot.plan || !snapshot.plan.lastAiPrompt) {
      throw new Error('未找到上次生成记录');
    }

    this.isRegenerating = true;
    const oldAiEvents = this.events.filter(e => e.source === 1);
    hilog.info(0x0000, 'TimelineViewModel', `[切换策略] 模式${mode}，旧事件数: ${oldAiEvents.length}`);

    try {
      // 先生成新数据
      this.currentStrategyMode = mode;
      await this.persistence.updateStrategyMode(this.planId, mode);
      await this.generateByAi(snapshot.plan.lastAiPrompt, mode);

      // 成功后删除旧数据
      await EventRepositoryImpl.deleteEventsBySource(this.planId, 1);

      // 从内存中移除旧事件
      const newAiEvents = this.events.filter(e =>
        e.source === 1 && !oldAiEvents.some(old => old.id === e.id)
      );
      this.events = this.events.filter(e =>
        e.source !== 1 || newAiEvents.some(n => n.id === e.id)
      );
      hilog.info(0x0000, 'TimelineViewModel', `[切换策略] 成功，新事件数: ${newAiEvents.length}`);
    } catch (error) {
      // 失败时保留旧数据
      hilog.error(0x0000, 'TimelineViewModel', `[切换策略] 失败，保留旧数据`);
      throw error instanceof Error ? error : new Error('生成失败');
    } finally {
      this.isRegenerating = false;
    }
  }


  // 修改点：完全重构 findCurrentActiveEvent，改用绝对时间戳判定
  public findCurrentActiveEvent(): EventEntity | null {
    const currentTs = new Date().getTime();

    for (const item of this.events) {

      if (item.status !== 1 || item.completion_status !== 0) continue;


      if (item.actual_start_time > 0) return item;


      if (item.dynamic_start_time > 0 && item.dynamic_end_time > 0) {

        if (currentTs >= item.dynamic_start_time && currentTs < item.dynamic_end_time) {
          return item;
        }
      }
    }
    return null;
  }
  // =========================================================

  // =========================================================

  /**
   * [方案1] 计算顺延方案 (Delay Y)
   * 逻辑：完全不动前面，计算出自然到达时间，作为建议时间
   */
  public calculateDelayPlan(targetIndex: number): CompressionPlan {
    // 1. 直接调用公共辅助方法计算自然到达时间
    const naturalArrivalMinutes = this._calculateNaturalArrival(targetIndex);

    // 2. 转换为字符串 (HH:mm)
    const timeStr = DateUtil.minutesToTime(naturalArrivalMinutes);

    // 3. 返回方案：affectedItems 为空，表示前面没人需要改
    return {
      status: 'COMPRESS_CONFIRM',
      msg: '顺延',
      affectedItems: [],
      suggestedTime: timeStr
    };
  }

  /**
   * [方案2] 计算强压方案 (Force Compress X)
   *
   */
  public calculateForceCompressPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    const targetMinutes = DateUtil.timeToMinutes(newTimeStr);
    const naturalArrivalMinutes = this._calculateNaturalArrival(targetIndex);
    const targetDayOffset = this.getEffectiveDayOffset(this.events[targetIndex]);
    const neededGap = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);


    if (neededGap <= 0) {
      return {
        status: 'NO_ACTION',
        msg: '时间充裕',
        affectedItems: [],
        suggestedTime: newTimeStr
      };
    }

    // 1. 寻找最近的一个非锁定邻居 (Location X)
    let prevIndex = -1;
    for (let i = targetIndex - 1; i >= 0; i--) {
      if (this.events[i].lock_status !== 1) {
        prevIndex = i;
        break;
      }
    }


    if (prevIndex === -1) {
      return {
        status: 'OVERLOAD',
        msg: '前序行程均为固定时间，无法压缩',
        affectedItems: [],
        suggestedTime: DateUtil.minutesToTime(naturalArrivalMinutes)
      };
    }

    // 3. 计算压缩后的时长
    const item = this.events[prevIndex];
    const original = item.duration;
    let newDur = original - neededGap;
    const minKeepDuration = this.getMinEventDurationLimit();

    if (newDur < minKeepDuration) {

      return {
        status: 'FAIL_TOO_SHORT',
        msg: `行程将低于${minKeepDuration}分钟`,

        affectedItems: [{
          index: prevIndex,
          name: item.name,
          oldVal: original,
          newVal: newDur
        }],
        suggestedTime: ''
      };
    }

    // 4. 成功
    return {
      status: 'COMPRESS_CONFIRM',
      msg: '强力压缩',
      affectedItems: [{
        index: prevIndex,
        name: item.name,
        oldVal: original,
        newVal: newDur
      }],
      suggestedTime: newTimeStr
    };
  }

  /**
   *
   *
   */
  public _calculateNaturalArrival(targetIndex: number): number {
    // 1. 寻找计算起点
    let chainStartIndex = 0;

    let startMinutes = DateUtil.timeToMinutes(this.globalStartTime);

    for (let i = targetIndex - 1; i >= 0; i--) {
      const item = this.events[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        chainStartIndex = i;
        startMinutes = DateUtil.timeToMinutes(item.fixed_start_time);
        break;
      }
    }

    const chainStartItem = this.events[chainStartIndex];
    const chainDayOffset = chainStartItem ? this.getEffectiveDayOffset(chainStartItem) : 0;
    // 使用绝对分钟轴计算，避免跨天(day_offset)场景下建议时间偏移。
    startMinutes += chainDayOffset * 24 * 60;

    // 2. 累加时间
    let currentCursor = startMinutes;
    for (let i = chainStartIndex; i < targetIndex; i++) {
      const item = this.events[i];


      if (i > chainStartIndex) {
        if (item.pre_travel_min > 0) {
          currentCursor += item.pre_travel_min;
        }
      } else {

        if (item.lock_status !== 1 && item.pre_travel_min > 0) {
          currentCursor += item.pre_travel_min;
        }
      }


      currentCursor += item.duration;
    }


    const targetItem = this.events[targetIndex];
    if (targetItem.pre_travel_min > 0) {
      currentCursor += targetItem.pre_travel_min;
    }

    return currentCursor;
  }

  public async resolveGapByDistribution(targetItem: EventEntity) {
    if (!targetItem || !targetItem.has_gap || targetItem.gap_minutes <= 0) {
      return;
    }

    const gap = targetItem.gap_minutes;
    const index = this.events.indexOf(targetItem);
    if (index <= 0) {
      return;
    }

    // 1. 回溯寻找可分摊的浮动行程 (Lock=0)

    const candidates: EventEntity[] = [];
    for (let i = index - 1; i >= 0; i--) {
      const item = this.events[i];
      if (item.lock_status !== 0) {
        break;
      }
      candidates.push(item);
    }

    if (candidates.length === 0) {

      return;
    }


    const count = candidates.length;
    const baseAdd = Math.floor(gap / count);
    const remainder = gap % count;

    // 3. 应用更改 (注意：candidates 是倒序收集的，candidates[0] 是离 gap 最近的那个)
    candidates.forEach((item, idx) => {
      let add = baseAdd;

      if (idx === 0) {
        add += remainder;
      }

      item.duration += add;


      if (item.id) {
        EventRepositoryImpl.updateSingleField(item.id, 'duration', item.duration, this.planId);
      }
    });


    const recalculateStartIndex = this.events.indexOf(candidates[candidates.length - 1]);
    this.recalculateFromIndex(recalculateStartIndex > 0 ? recalculateStartIndex - 1 : 0);
  }


  /**
   *
   */
  public async skipEvent(item: EventEntity) {
    if (this.isArchived) {
      return;
    }
    const beforeNext = this.getNextExecutableEvent(item.id);
    const beforeNextTs = beforeNext ? beforeNext.dynamic_start_time : 0;
    const beforeNextName = beforeNext ? beforeNext.name : '';
    const now = new Date().getTime();
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][skip_event][begin] id=${item.id}, name=${item.name}, now=${now}, oldStatus=${item.completion_status}`
    );

    if (!TimelineExecutionState.isStartable(item) && !TimelineExecutionState.isActive(item)) {
      hilog.warn(
        0x0000,
        TAG,
        `[DUAL_MODE_ACCEPT][skip_event][blocked] reason=non_pending_skip, id=${item.id}, name=${item.name}, status=${item.completion_status}`
      );
      return;
    }

    if (item.id) {
      const ok = await this.applyRuntimeTransition(item, 'SKIP', now);
      if (!ok) {
        return;
      }
    }

    // 3. 刷新
    this.recalculateFromEventId(item.id);
    const afterNext = this.getNextExecutableEvent(item.id);
    const afterNextTs = afterNext ? afterNext.dynamic_start_time : 0;
    const afterNextName = afterNext ? afterNext.name : beforeNextName;
    this.latestReflowHint = this.buildReflowHint('skip', beforeNextTs, afterNextTs, item.name, afterNextName);
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][skip_event][done] id=${item.id}, name=${item.name}, status=${item.completion_status}, actualEnd=${item.actual_end_time}`
    );
    this.logTimelineSnapshot('skip_event');
    this.getPlaceCheckinSummary(item.name);
    this.evaluatePlanStatusByRuntime();

    // 记录跳过行为
    if (item.source === 1) {
      this.behaviorTracker.recordSkip(item.id);
    }
  }


  public async reopenSkippedEvent(id: number): Promise<boolean> {
    if (this.isArchived) {
      return false;
    }
    const target = this.events.find(e => e.id === id);
    if (!target) {
      return false;
    }
    const oldStatus = target.completion_status;
    const oldStart = target.actual_start_time;
    const oldEnd = target.actual_end_time;

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][reopen_skipped][begin] id=${target.id}, name=${target.name}, oldStatus=${target.completion_status}, oldStart=${target.actual_start_time}, oldEnd=${target.actual_end_time}`
    );

    if (!TimelineExecutionState.isSkipped(target)) {
      hilog.warn(
        0x0000,
        TAG,
        `[DUAL_MODE_ACCEPT][reopen_skipped][blocked] reason=non_skipped_target, id=${target.id}, name=${target.name}, status=${target.completion_status}`
      );
      return false;
    }

    try {
      const ok = await this.applyRuntimeTransition(target, 'REOPEN', Date.now());
      if (!ok) {
        return false;
      }
    } catch (error) {
      hilog.error(
        0x0000,
        TAG,
        `[DUAL_MODE_ACCEPT][reopen_skipped][rollback] id=${target.id}, name=${target.name}, reason=${JSON.stringify(error)}`
      );
      return false;
    }
    this.recalculateFromEventId(target.id);

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][reopen_skipped][done] id=${target.id}, name=${target.name}, newStatus=${target.completion_status}, newStart=${target.actual_start_time}, newEnd=${target.actual_end_time}`
    );
    this.logTimelineSnapshot('reopen_skipped');
    this.getPlaceCheckinSummary(target.name);
    this.evaluatePlanStatusByRuntime();
    return true;
  }

  // 修改点：重构 calculateRealtimeSchedule 循环内部逻辑
  public calculateRealtimeSchedule() {
    this.conflictList = [];
    const anyStarted = this.events.some(e => e.actual_start_time > 0);
    let completedCount = 0;
    let skippedCount = 0;
    let pendingCount = 0;
    let actualOverrideCount = 0;
    const baseTimeMs = TimelineDatePolicy.toDayStartMs(this.planStartDate || Date.now());
    let currentCursor = baseTimeMs;

    for (let i = 0; i < this.events.length; i++) {
      const item = this.events[i];
      const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      item.is_forecast_conflict = false;

      if (i === 0) {
        const rawTime = (item.computed_time || '09:00').split(' ').pop() || '09:00';
        currentCursor = item.actual_start_time > 0 ? item.actual_start_time :
          TimelineDatePolicy.buildPlannedTimestamp(baseTimeMs, effectiveDayOffset, rawTime);
      } else {
        if (item.actual_start_time > 0) {
          currentCursor = item.actual_start_time;
        } else {
          currentCursor += (item.pre_travel_min > 0 ? item.pre_travel_min : 0) * 60000;
        }
      }

      if (item.fixed_start_time && item.completion_status === 0) {
        const anchorTs = TimelineDatePolicy.buildPlannedTimestamp(baseTimeMs, effectiveDayOffset, item.fixed_start_time);

        // 刚性冲突仅记录 UI 警告
        if (item.lock_status === 1 && currentCursor > anchorTs + 60000) {
          item.is_forecast_conflict = true;
          this.conflictList.push(item);
        }

        if (currentCursor < anchorTs) {
          currentCursor = anchorTs; // 修改点：核心修复
        }
      }

      item.dynamic_start_time = currentCursor; // 物理层始终写入，保障伴游模式工作
      let stepEndTime = item.actual_end_time > 0 ? item.actual_end_time : (currentCursor + item.duration * 60000);
      item.dynamic_end_time = stepEndTime;
      if (item.actual_end_time > 0) {
        actualOverrideCount += 1;
      }

      if (item.completion_status === EventEntity.STATE_COMPLETED) {
        completedCount += 1;
      } else if (item.completion_status === EventEntity.STATE_SKIPPED) {
        skippedCount += 1;
      } else {
        pendingCount += 1;
      }

      if (!anyStarted) {
        item.forecast_start_time = "xxxx";
        item.forecast_end_time = "xxxx";
      } else {
        const diff = Math.round((new Date(currentCursor).setHours(0,0,0,0) - (baseTimeMs + effectiveDayOffset * 86400000)) / 86400000);
        const dayLabel = (diff === 1 ? "次日 " : (diff > 1 ? `+${diff}天 ` : ""));
        item.forecast_start_time = dayLabel + DateUtil.formatDate(new Date(currentCursor), 'HH:mm');
        item.forecast_end_time = DateUtil.formatDate(new Date(stepEndTime), 'HH:mm');
      }

      // --- D. 推进游标 ---
      currentCursor = stepEndTime;
    }

    const active = this.getRealActiveEvent();
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][realtime] anyStarted=${anyStarted}, pending=${pendingCount}, completed=${completedCount}, skipped=${skippedCount}, actualOverride=${actualOverrideCount}, active=${active ? active.name : 'none'}`
    );
  }

  public async checkOutEvent(item: EventEntity) {
    const now = new Date().getTime();
    if (item.id) {
      const ok = await this.applyRuntimeTransition(item, 'END', now);
      if (!ok) {
        return;
      }
    }

    // 2. 触发预测
    this.calculateRealtimeSchedule();

    // 3. 刷新
    this.events = [...this.events];
  }

  public async recordStartTime(item: EventEntity) {
    const now = new Date().getTime();
    if (item.id) {
      const ok = await this.applyRuntimeTransition(item, 'START', now);
      if (!ok) {
        return;
      }
    }

    // 触发预测更新
    this.calculateRealtimeSchedule();
    this.events = [...this.events];
  }

  private hasPrecheckActiveConflict(id: number): boolean {
    return this.events.some((item: EventEntity) => item.id !== id && TimelineExecutionState.isActive(item));
  }

  private buildActualTimeMutationMeta(
    id: number,
    target: EventEntity,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): ActualTimeMutationMeta {
    const beforeNext = this.getNextExecutableEvent(id);
    const beforeNextTs = beforeNext ? beforeNext.dynamic_start_time : 0;
    const beforeNextName = beforeNext ? beforeNext.name : '';
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][actual_time][begin] id=${id}, name=${target.name}, field=${field}, ts=${timestamp}, oldStart=${target.actual_start_time}, oldEnd=${target.actual_end_time}, oldStatus=${target.completion_status}`
    );
    const meta: ActualTimeMutationMeta = {
      beforeNextTs: beforeNextTs,
      beforeNextName: beforeNextName
    };
    return meta;
  }

  private async applyActualTimeMutation(
    target: EventEntity,
    id: number,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): Promise<boolean> {
    if (field === 'actual_start_time') {
      if (timestamp > 0) {
        const started = await this.applyRuntimeTransition(target, 'START', timestamp);
        return started;
      }
      await EventRepositoryImpl.updateFields(id, [{ column: field, value: timestamp }], this.planId);
      target.actual_start_time = timestamp;
      return true;
    } else {
      const ended = await this.applyRuntimeTransition(target, 'END', timestamp);
      return ended;
    }
  }

  private async postActualTimeMutationEffects(
    id: number,
    target: EventEntity,
    field: 'actual_start_time' | 'actual_end_time',
    beforeNextTs: number,
    beforeNextName: string
  ): Promise<void> {
    this.recalculateFromEventId(id);
    this.markScheduleChanged();
    const schedule = this.getOrderedScheduleEvents();
    const afterNext = this.getNextExecutableEvent(id, schedule);
    const afterNextTs = afterNext ? afterNext.dynamic_start_time : 0;
    const afterNextName = afterNext ? afterNext.name : beforeNextName;
    this.latestReflowHint = this.buildReflowHint(
      field === 'actual_start_time' ? 'start' : 'end',
      beforeNextTs,
      afterNextTs,
      target.name,
      afterNextName
    );

    const active = this.getRealActiveEvent(schedule);
    if (active) {
      const nextIdx = this.getOrderedScheduleIndexById(active.id, schedule) + 1;
      const next = (nextIdx > 0 && nextIdx < schedule.length) ? schedule[nextIdx] : null;
      const nextTip = next ? `下个地点：${next.name}` : '今日行程即将结束';
      void this.reminderFacade.updateScheduleNotification(
        `正在：${active.name}`,
        nextTip,
        this.planId,
        active.id,
        true
      );
    }

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][actual_time][done] id=${id}, name=${target.name}, field=${field}, newStart=${target.actual_start_time}, newEnd=${target.actual_end_time}, newStatus=${target.completion_status}, active=${active ? active.name : 'none'}`
    );
    this.logTimelineSnapshot(`actual_time_${field}`);
    if (field === 'actual_end_time') {
      this.getPlaceCheckinSummary(target.name);
    }
  }


  /**
   *
   */
  public async updateActualTime(id: number, field: 'actual_start_time' | 'actual_end_time', timestamp: number): Promise<boolean> {
    if (this.isArchived) {
      return false;
    }
    if (this.actualTimeMutationInFlight) {
      hilog.warn(0x0000, TAG, `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=mutation_in_flight, id=${id}, field=${field}`);
      return false;
    }
    const target = this.events.find(e => e.id === id);
    if (!target) return false;

    if (field === 'actual_start_time' && timestamp > 0) {
      if (this.hasPrecheckActiveConflict(id)) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=active_exists_precheck, id=${id}, name=${target.name}, ts=${timestamp}`
        );
        return false;
      }
      const globalConflict = await this.getStartConflictInfo(id);
      if (globalConflict) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=active_exists_global, id=${id}, name=${target.name}, conflictEventId=${globalConflict.eventId}, conflictPlanId=${globalConflict.planId}`
        );
        return false;
      }
    }

    this.actualTimeMutationInFlight = true;
    try {
      const mutationMeta = this.buildActualTimeMutationMeta(id, target, field, timestamp);
      const beforeNextTs = mutationMeta.beforeNextTs;
      const beforeNextName = mutationMeta.beforeNextName;

      if (field === 'actual_start_time' &&
        timestamp > 0 &&
        !TimelineExecutionState.isStartable(target)) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=non_pending_start, id=${id}, name=${target.name}, status=${target.completion_status}, ts=${timestamp}`
        );
        return false;
      }

      try {
        const applied = await this.applyActualTimeMutation(target, id, field, timestamp);
        if (!applied) {
          return false;
        }
      } catch (error) {
        hilog.error(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][rollback] id=${id}, name=${target.name}, field=${field}, reason=${JSON.stringify(error)}`
        );
        return false;
      }
      await this.postActualTimeMutationEffects(id, target, field, beforeNextTs, beforeNextName);

      if (this.planId > 0) {
        const planIdStr = `${this.planId}`;
        if (field === 'actual_start_time' && timestamp > 0) {
          this.planStateMachine.startExecution(planIdStr, TransitionTriggerSource.USER_ACTION);
        } else if (field === 'actual_end_time') {
          const scheduled = this.events.filter((item: EventEntity) => item.status === 1);
          const allCompleted = scheduled.length > 0 && scheduled.every((item: EventEntity) => item.completion_status === EventEntity.STATE_COMPLETED);
          if (allCompleted) {
            this.planStateMachine.completeExecution(planIdStr);
          } else {
            this.evaluatePlanStatusByRuntime();
          }
        }
        this.currentPlanStatus = this.planStateMachine.getPlanStatus(planIdStr).status;
      }

      return true;
    } finally {
      this.actualTimeMutationInFlight = false;
    }
  }

  public async getStartConflictInfo(excludeEventId: number): Promise<StartConflictInfo | null> {
    const active: ActiveEventSnapshot | null = await EventRepositoryImpl.findGlobalActiveEvent(excludeEventId);
    if (!active) {
      return null;
    }
    return {
      eventId: active.eventId,
      planId: active.planId,
      name: active.name,
      actualStartTime: active.actualStartTime
    };
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
    await this.reloadWeatherUserPreference();
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
    if (this.planId <= 0) {
      return true;
    }
    let latestTs = this.weatherLastRefreshAt;
    this.events.forEach((event: EventEntity) => {
      if (event.status !== 1) {
        return;
      }
      const fetchTs = Number(event.weather_fetch_time ?? 0);
      if (Number.isFinite(fetchTs) && fetchTs > latestTs) {
        latestTs = fetchTs;
      }
    });
    if (!Number.isFinite(latestTs) || latestTs <= 0) {
      return true;
    }
    return Date.now() - latestTs >= maxAgeMs;
  }

  public async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    const manager = PreferenceManager.getInstance();
    await manager.setWeatherFeatureEnabled(enabled);
    this.weatherFeatureEnabled = enabled;
    if (!enabled) {
      this.stopExecutionWeatherScheduler();
      this.clearWeatherRuntimeState();
      this.events = [...this.events];
    } else {
      void this.refreshPlanningWeather(false);
      const stage = this.resolveCurrentWeatherStage();
      const policy = this.weatherFacade.resolveSchedulePolicy(stage);
      if (policy.pollIntervalMs > 0) {
        this.startExecutionWeatherScheduler(this.planId, stage);
      }
    }
    hilog.info(0x0000, TAG, `[WEATHER_SWITCH][update] enabled=${this.weatherFeatureEnabled}`);
  }

  public async updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    const manager = PreferenceManager.getInstance();
    await manager.setWeatherUserPreference(preference);
    await this.reloadWeatherUserPreference();
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_PREF][update] heat=${this.weatherUserPreference.heatSensitivity}, rain=${this.weatherUserPreference.rainSensitivity}, tolerance=${this.weatherUserPreference.weatherRiskTolerance}`
    );
  }

  private async reloadWeatherUserPreference(): Promise<void> {
    try {
      const manager = PreferenceManager.getInstance();
      this.weatherUserPreference = await manager.getWeatherUserPreference();
      this.weatherFeatureEnabled = await manager.isWeatherFeatureEnabled();
      hilog.info(
        0x0000,
        TAG,
        `[WEATHER_PREF][load] enabled=${this.weatherFeatureEnabled}, heat=${this.weatherUserPreference.heatSensitivity}, rain=${this.weatherUserPreference.rainSensitivity}, tolerance=${this.weatherUserPreference.weatherRiskTolerance}`
      );
      if (!this.weatherFeatureEnabled) {
        this.clearWeatherRuntimeState();
      }
    } catch (error) {
      this.weatherUserPreference = {
        heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
        rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
        weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
      };
      this.weatherFeatureEnabled = true;
      hilog.warn(0x0000, TAG, `[WEATHER_PREF][fallback] reason=${JSON.stringify(error)}`);
    }
  }

  private async backfillPlanningCoordinatesByName(scheduleEvents: EventEntity[]): Promise<void> {
    const geocodeCache: Map<string, GeoPointInput | null> = new Map();
    for (const event of scheduleEvents) {
      if (!this.isCoordinateMissingForWeather(event.latitude, event.longitude)) {
        continue;
      }
      const placeName = event.name.trim();
      if (placeName.length === 0) {
        continue;
      }
      let cached = geocodeCache.get(placeName);
      if (cached === undefined) {
        const geocode = await AmapService.getGeocode(placeName);
        if (geocode && this.isValidCoordinate(geocode.lat, geocode.lng)) {
          cached = { latitude: geocode.lat, longitude: geocode.lng };
          hilog.info(0x0000, TAG, `[WEATHER_GEO][planning_fill] geocode_hit id=${event.id}, name=${placeName}, lat=${geocode.lat}, lng=${geocode.lng}`);
        } else {
          cached = null;
          hilog.warn(0x0000, TAG, `[WEATHER_GEO][planning_fill] geocode_miss id=${event.id}, name=${placeName}`);
        }
        geocodeCache.set(placeName, cached);
      }
      if (!cached) {
        continue;
      }
      event.latitude = cached.latitude;
      event.longitude = cached.longitude;
      if (event.id > 0) {
        const updates: EventFieldUpdate[] = [
          { column: 'latitude', value: cached.latitude },
          { column: 'longitude', value: cached.longitude }
        ];
        await EventRepositoryImpl.updateFields(event.id, updates, this.planId);
      }
    }
  }

  private clearWeatherRuntimeState(): void {
    this.weatherRouteScore = -1;
    this.weatherPlanningHint = '';
    this.weatherStrategyHint = '';
    this.weatherCollabSummary = '';
    this.weatherCollabLabel = '';
    this.executionWeatherHint = '';
    this.executionWeatherCurrentText = '';
    this.executionWeatherDisplaySource = 'UNKNOWN';
    this.executionWeatherNextText = '';
    this.executionWeatherScore = -1;
    this.executionWeatherErrorCode = '';
    this.executionWeatherSuggestions = [];
    this.executionWeatherAppliedSummary = '';
    this.executionWeatherCollabBadge = '';
    this.executionWeatherCollabSummary = '';
    this.weatherStrategyAppliedKey = '';
  }

  private getPlanningWeatherSnapshotKey(planId: number): string {
    return `PlanningWeatherSnapshot_${planId}`;
  }

  private persistPlanningWeatherSnapshot(): void {
    if (this.planId <= 0) {
      return;
    }
    const snapshot: PlanningWeatherSnapshot = {
      hint: this.weatherPlanningHint,
      score: this.weatherRouteScore,
      collabSummary: this.weatherCollabSummary,
      strategyHint: this.weatherStrategyHint,
      refreshedAt: this.weatherLastRefreshAt
    };
    AppStorage.setOrCreate(this.getPlanningWeatherSnapshotKey(this.planId), JSON.stringify(snapshot));
  }

  private restorePlanningWeatherSnapshot(planId: number): void {
    const raw = AppStorage.get<string>(this.getPlanningWeatherSnapshotKey(planId)) ?? '';
    if (!raw || raw.trim().length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as PlanningWeatherSnapshot;
      this.weatherPlanningHint = parsed.hint ?? '';
      this.weatherRouteScore = Number.isFinite(parsed.score) ? parsed.score : -1;
      this.weatherCollabSummary = parsed.collabSummary ?? '';
      this.weatherCollabLabel = this.weatherCollabSummary.trim().length > 0 ? '多日/多城' : '';
      this.weatherStrategyHint = parsed.strategyHint ?? '';
      this.weatherLastRefreshAt = Number.isFinite(parsed.refreshedAt) ? parsed.refreshedAt : 0;
    } catch (_error) {
    }
  }

  private isAutoRouteEnabled(): boolean {
    return this.enableAutoAmapRoute && this.enableGlobalAmapRouteApi;
  }

  private shouldAutoRouteForItem(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    if (!this.isAutoRouteEnabled()) {
      return false;
    }
    if (item.is_travel_manual === 1) {
      return false;
    }
    if (this.isFirstScheduledItemOfDay(item)) {
      return false;
    }
    return true;
  }

  public getOrderedScheduleEvents(): EventEntity[] {
    return TimelineGroupingService.getOrderedScheduleEvents(this.events);
  }

  private getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((event: EventEntity) => event.id === eventId);
  }

  public getEventsByPlaceName(placeName: string): EventEntity[] {
    return TimelineGroupingService.getEventsByPlaceName(this.events, placeName);
  }

  public getPlaceAddress(placeName: string): string {
    const events = this.getEventsByPlaceName(placeName);
    for (let i = 0; i < events.length; i++) {
      const address = (events[i].address || '').trim();
      if (address.length > 0) {
        return address;
      }
    }
    return '-';
  }

  public getLatestEventForPlace(placeName: string): EventEntity | null {
    const events = this.getEventsByPlaceName(placeName)
      .filter((event: EventEntity) => TimelineExecutionState.isScheduled(event));
    if (events.length === 0) {
      return null;
    }
    events.sort((a: EventEntity, b: EventEntity) => {
      const aTs = a.actual_end_time > 0 ? a.actual_end_time : (a.actual_start_time > 0 ? a.actual_start_time : 0);
      const bTs = b.actual_end_time > 0 ? b.actual_end_time : (b.actual_start_time > 0 ? b.actual_start_time : 0);
      if (bTs !== aTs) {
        return bTs - aTs;
      }
      return b.id - a.id;
    });
    return events[0];
  }

  public getAllPlaceCheckinSummaries(): PlaceCheckinSummary[] {
    return TimelineGroupingService.getAllPlaceCheckinSummaries(this.events);
  }

  public getCurrentPlanHistorySummary(): HistoryTimelineSummary {
    const schedule = this.getOrderedScheduleEvents();
    return HistoryManager.generateSummary(schedule, this.planName, this.planId);
  }

  public getCurrentPlanHistoryTimelineItems(abnormalThresholdMinutes: number = 10): HistoryTimelineItem[] {
    const threshold = abnormalThresholdMinutes > 0 ? abnormalThresholdMinutes : 10;
    const schedule = this.getOrderedScheduleEvents();
    const items: HistoryTimelineItem[] = [];
    for (let i = 0; i < schedule.length; i++) {
      const event = schedule[i];
      if (!TimelineExecutionState.isScheduled(event)) {
        continue;
      }

      const plannedStart = event.dynamic_start_time > 0 ? event.dynamic_start_time : 0;
      const actualStart = event.actual_start_time > 0 ? event.actual_start_time : 0;
      const actualEnd = event.actual_end_time > 0 ? event.actual_end_time : 0;
      const stayMinutes = (actualStart > 0 && actualEnd > actualStart)
        ? Math.round((actualEnd - actualStart) / 60000)
        : 0;
      const deviationMinutes = (actualStart > 0 && plannedStart > 0)
        ? Math.round((actualStart - plannedStart) / 60000)
        : 0;
      const isSkipped = TimelineExecutionState.isSkipped(event);
      const isAbnormal = isSkipped || Math.abs(deviationMinutes) >= threshold;
      const address = (event.address || '').trim();
      const note = (event.note || '').trim();

      if (isSkipped) {
        const skipTs = actualEnd > 0 ? actualEnd : (actualStart > 0 ? actualStart : plannedStart);
        items.push({
          id: event.id * 10 + 3,
          eventId: event.id,
          placeName: event.name,
          actionType: 'SKIP',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(skipTs),
          address: address,
          note: note,
          displayTs: skipTs,
          isAbnormal: isAbnormal
        });
        continue;
      }

      if (TimelineExecutionState.isActive(event)) {
        const activeTs = actualStart > 0 ? actualStart : plannedStart;
        items.push({
          id: event.id * 10 + 4,
          eventId: event.id,
          placeName: event.name,
          actionType: 'ACTIVE',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(activeTs),
          address: address,
          note: note,
          displayTs: activeTs,
          isAbnormal: isAbnormal
        });
        continue;
      }

      if (actualStart > 0) {
        items.push({
          id: event.id * 10 + 1,
          eventId: event.id,
          placeName: event.name,
          actionType: 'ARRIVE',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(actualStart),
          address: address,
          note: note,
          displayTs: actualStart,
          isAbnormal: isAbnormal
        });
      }

      if (actualEnd > 0) {
        items.push({
          id: event.id * 10 + 2,
          eventId: event.id,
          placeName: event.name,
          actionType: 'LEAVE',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(actualEnd),
          address: address,
          note: note,
          displayTs: actualEnd,
          isAbnormal: isAbnormal
        });
      }
    }

    items.sort((a: HistoryTimelineItem, b: HistoryTimelineItem) => {
      if (a.displayTs !== b.displayTs) {
        return a.displayTs - b.displayTs;
      }
      return a.id - b.id;
    });
    return items;
  }

  private toHistoryGroupDateKey(ts: number): string {
    if (ts <= 0) {
      return '未定';
    }
    return DateUtil.formatLocalDate(ts);
  }

  private getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.getOrderedScheduleEvents();
    const idx = this.getOrderedScheduleIndexById(afterId, source);
    if (idx === -1) {
      return null;
    }
    for (let i = idx + 1; i < source.length; i++) {
      if (TimelineExecutionState.isStartable(source[i])) {
        return source[i];
      }
    }
    return null;
  }

  public buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    if (action === 'skip') {
      return {
        type: 'next_changed',
        minutesDelta: 0,
        message: nextName
          ? `已跳过 ${targetName}，下一站改为 ${nextName}`
          : `已跳过 ${targetName}，后续行程已自动重排`,
        updatedAt: Date.now()
      };
    }

    if (beforeTs > 0 && afterTs > 0) {
      const deltaMinutes = Math.round((afterTs - beforeTs) / 60000);
      if (deltaMinutes > 0) {
        return {
          type: 'shift',
          minutesDelta: deltaMinutes,
          message: `后续整体顺延 ${deltaMinutes} 分钟`,
          updatedAt: Date.now()
        };
      }
      if (deltaMinutes < 0) {
        return {
          type: 'shift',
          minutesDelta: deltaMinutes,
          message: `后续整体提前 ${Math.abs(deltaMinutes)} 分钟`,
          updatedAt: Date.now()
        };
      }
    }

    return {
      type: 'reflow',
      minutesDelta: 0,
      message: '已根据实际时间自动更新后续安排',
      updatedAt: Date.now()
    };
  }

  public getDistributionCandidates(gapItem: EventEntity): EventEntity[] {
    const index = this.events.indexOf(gapItem);
    if (index <= 0) return [];

    return this.events.slice(0, index).filter(e => e.status === 1 && this.getEffectiveDayOffset(e) === this.getEffectiveDayOffset(gapItem));
  }

  // TimelineViewModel.ets 内部新增/修改

  /**
   *
   */
  public getSafetyCap(candidate: EventEntity, gapItem: EventEntity): number {
    const allSchedule = this.events.filter(e => e.status === 1);

    const candIdx = allSchedule.findIndex(e => e.id === candidate.id);
    const gapIdx = allSchedule.findIndex(e => e.id === gapItem.id);

    if (candIdx === -1 || gapIdx === -1 || candIdx >= gapIdx) {
      return 0;
    }

    let minBuffer = Math.max(0, gapItem.gap_minutes);

    for (let i = candIdx + 1; i < gapIdx; i++) {
      const item = allSchedule[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        const eventIdxInEvents = this.events.findIndex(e => e.id === item.id);
        if (eventIdxInEvents === -1) {
          continue;
        }

        const naturalArrival = this._calculateNaturalArrival(eventIdxInEvents);
        const targetMin = DateUtil.timeToMinutes(item.fixed_start_time);
        const buffer = targetMin - naturalArrival;

        if (buffer < minBuffer) {
          minBuffer = Math.max(0, buffer);
        }
      }
    }

    return minBuffer;
  }

  public calculateDistributionPreview(gapItem: EventEntity, candidates: EventEntity[], selectedIds: Set<number>,
    strategy: 'EQUAL' | 'SMART'): Map<number, number> {
    const selectedItems = candidates.filter(c => selectedIds.has(c.id));
    const result = new Map<number, number>();
    if (selectedItems.length === 0) return result;

    const caps = new Map<number, number>();
    const weights = new Map<number, number>();
    let totalWeight = 0;


    selectedItems.forEach(item => {
      // 强制限制逻辑：A=3 安全策略
      const cap = this.getSafetyCap(item, gapItem);
      caps.set(item.id, cap);

      let w = 1.0;
      if (strategy === 'SMART') {


        const pFactor = (item.priority === 1 ? 2.0 : 1.0);
        const dFactor = item.duration;
        w = pFactor * dFactor;
      }
      weights.set(item.id, w);
      totalWeight += w;
      result.set(item.id, 0);
    });


    let remainingGap = gapItem.gap_minutes;
    let activeIds = selectedItems.map(i => i.id);

    while (remainingGap > 0 && activeIds.length > 0) {
      let currentRoundWeight = 0;
      activeIds.forEach(id => {
        currentRoundWeight += (weights.get(id) ?? 0);
      });

      if (currentRoundWeight <= 0) break;

      let nextActiveIds: number[] = [];
      let allocatedThisRound = 0;

      for (const id of activeIds) {

        const weightVal: number = weights.get(id) ?? 0;
        const share: number = Math.floor(remainingGap * (weightVal / currentRoundWeight));

        const currentAllocated = result.get(id) ?? 0;
        const cap = caps.get(id) ?? 0;

        if (currentAllocated + share >= cap) {

          const actualAdd = cap - currentAllocated;
          result.set(id, cap);
          allocatedThisRound += actualAdd;
        } else {
          result.set(id, currentAllocated + share);
          allocatedThisRound += share;
          nextActiveIds.push(id);
        }
      }

      remainingGap -= allocatedThisRound;


      if (allocatedThisRound === 0 && remainingGap > 0) {
        const luckyId = nextActiveIds[0];
        if (luckyId && (result.get(luckyId) ?? 0) < (caps.get(luckyId) ?? 0)) {
          result.set(luckyId, (result.get(luckyId) ?? 0) + 1);
          remainingGap--;
        } else {
          break;
        }
      }
      activeIds = nextActiveIds;
    }

    return result;
  }


  /** * 获取所有已排序的空闲时间段
   */
  public getSortedGaps(): EventEntity[] {
    if (!this.idleGapDetectionEnabled) {
      return [];
    }

    const minGap = this.idleGapTriggerMinutes;
    return this.events
      .filter(e =>
      e.status === 1 &&
      e.has_gap &&
        e.gap_minutes >= minGap &&
        !this.isFirstScheduledItemOfDay(e) &&
        this.isSameDayGapWithPreviousScheduleItem(e)
      )
      .sort((a, b) => b.gap_minutes - a.gap_minutes);
  }

  private isSameDayGapWithPreviousScheduleItem(item: EventEntity): boolean {
    const schedule = this.getOrderedScheduleEvents();
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    if (idx <= 0) {
      return false;
    }
    const prev = schedule[idx - 1];
    return this.getEffectiveDayOffset(prev) === this.getEffectiveDayOffset(item);
  }

  /** * 获取空闲时间段的前序地点名称
   */
  public getPreviousItemName(gapItem: EventEntity): string {
    const schedule = this.getOrderedScheduleEvents();
    const idx = this.getOrderedScheduleIndexById(gapItem.id, schedule);
    if (idx <= 0) {
      return "日程开始";
    }

    const prev = schedule[idx - 1];
    if (this.getEffectiveDayOffset(prev) !== this.getEffectiveDayOffset(gapItem)) {
      return "当日开始";
    }

    return prev.name;
  }


  public async applyDistribution(distributionMap: Map<number, number>) {
    const entries = Array.from(distributionMap.entries());
    let startIndex = this.events.length;
    for (let i = 0; i < entries.length; i++) {
      const id = entries[i][0];
      const addMin = entries[i][1];
      const item = this.events.find(e => e.id === id);
      if (item && addMin > 0) {
        const idx = this.events.indexOf(item);
        if (idx >= 0 && idx < startIndex) {
          startIndex = idx;
        }
        item.duration += addMin;
        await EventRepositoryImpl.updateSingleField(item.id, 'duration', item.duration, this.planId);
      }
    }
    if (startIndex < this.events.length) {
      this.recalculateFromIndex(startIndex > 0 ? startIndex - 1 : 0);
    }
  }

  public getPlaceCheckinSummary(placeName: string): PlaceCheckinSummary {
    return TimelineGroupingService.getPlaceCheckinSummary(this.events, placeName);
  }

  public getCompanionContext(nowTs: number = Date.now()): CompanionContext {
    const schedule = this.getOrderedScheduleEvents();
    if (schedule.length === 0) {
      return {
        runtimeState: 'IDLE',
        currentEvent: null,
        nextEvent: null,
        hint: this.latestReflowHint,
        actions: {
          canStart: false,
          canPause: false,
          canResume: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        }
      };
    }

    let active: EventEntity | null = null;
    let pending: EventEntity | null = null;
    for (let i = 0; i < schedule.length; i++) {
      const event = schedule[i];
      if (!active && TimelineExecutionState.isActive(event)) {
        active = event;
      }
      if (!pending && TimelineExecutionState.isStartable(event)) {
        pending = event;
      }
      if (active && pending) {
        break;
      }
    }

    if (active) {
      const stage = this.planStateMachine.getPlanStageViewModel(`${this.planId}`);
      const next = this.getNextExecutableEvent(active.id, schedule);
      if (stage.canResume && !stage.canPause) {
        return {
          runtimeState: 'PAUSED',
          currentEvent: active,
          nextEvent: next,
          hint: this.latestReflowHint,
          actions: {
            canStart: false,
            canPause: false,
            canResume: true,
            canEnd: true,
            canSkip: true,
            canNavigate: true,
            canViewDetail: true
          }
        };
      }
      return {
        runtimeState: 'ACTIVE',
        currentEvent: active,
        nextEvent: next,
        hint: this.latestReflowHint,
        actions: {
          canStart: false,
          canPause: stage.canPause,
          canResume: stage.canResume,
          canEnd: true,
          canSkip: true,
          canNavigate: true,
          canViewDetail: true
        }
      };
    }

    if (!pending) {
      return {
        runtimeState: 'IDLE',
        currentEvent: null,
        nextEvent: null,
        hint: this.latestReflowHint,
        actions: {
          canStart: false,
          canPause: false,
          canResume: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        }
      };
    }

    const hasDynamicStart = pending.dynamic_start_time > 0;
    const next = this.getNextExecutableEvent(pending.id, schedule);
    let runtimeHint = this.latestReflowHint;
    if (!runtimeHint && hasDynamicStart) {
      const deltaMinutes = Math.round((pending.dynamic_start_time - nowTs) / 60000);
      runtimeHint = {
        type: 'reflow',
        minutesDelta: deltaMinutes,
        message: deltaMinutes > 0
          ? `距计划开始约 ${Math.max(1, deltaMinutes)} 分钟，可手动提前开始`
          : `已超过计划开始 ${Math.max(1, Math.abs(deltaMinutes))} 分钟，可直接开始`,
        updatedAt: nowTs
      };
    }

    return {
      runtimeState: 'READY',
      currentEvent: pending,
      nextEvent: next,
      hint: runtimeHint,
      actions: {
        canStart: true,
        canPause: false,
        canResume: false,
        canEnd: false,
        canSkip: true,
        canNavigate: true,
        canViewDetail: true
      }
    };
  }

  public getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    const now = new Date().getTime();
    const source = schedule ?? this.getOrderedScheduleEvents();
    let pending: EventEntity | null = null;
    for (let i = 0; i < source.length; i++) {
      const event = source[i];
      if (TimelineExecutionState.isActive(event)) {
        return event;
      }
      if (!pending && TimelineExecutionState.isStartable(event) && event.dynamic_end_time > now) {
        pending = event;
      }
    }
    return pending;
  }

  private isFirstScheduledItemOfDay(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    const schedule = this.getOrderedScheduleEvents();
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    if (idx <= 0) {
      return idx === 0;
    }
    const prev = schedule[idx - 1];
    return TimelineDatePolicy.resolveEventDayOffset(prev) !== TimelineDatePolicy.resolveEventDayOffset(item);
  }


  private insertSmart(newEntity: EventEntity) {

    if (newEntity.status === 0) {
      this.events.push(newEntity);
      return;
    }

    // 1. 准备比较标准（无 fixed_start_time 时回退到 computed_time）
    const targetTimeStr = newEntity.fixed_start_time || newEntity.computed_time || '23:59';
    const targetMin = DateUtil.timeToMinutes(targetTimeStr);


    let insertIndex = -1;

    // 遍历现有数组 (假设 this.events 主要是大概有序的，或者我们只关心同一天的相对顺序)
    for (let i = 0; i < this.events.length; i++) {
      const curr = this.events[i];
      if (curr.status !== 1) {
        continue;
      }

      const currDayOffset = TimelineDatePolicy.resolveEventDayOffset(curr);
      const targetDayOffset = TimelineDatePolicy.resolveEventDayOffset(newEntity);

      if (currDayOffset > targetDayOffset) {
        insertIndex = i;
        break;
      }

      // 只比较同一天的日程
      if (currDayOffset === targetDayOffset) {

        // 获取当前项的比较时间 (优先用固定时间，没有则用推算时间)
        const currTimeStr = curr.fixed_start_time || curr.computed_time || '23:59';
        const currMin = DateUtil.timeToMinutes(currTimeStr);


        if (currMin > targetMin) {
          insertIndex = i;
          break;
        }
      }
    }

    if (insertIndex !== -1) {
      this.events.splice(insertIndex, 0, newEntity);
    } else {

      this.events.push(newEntity);
    }


    this.events.forEach((e, index) => {
      e.sort_order = index * 100;
    });
  }
}













































