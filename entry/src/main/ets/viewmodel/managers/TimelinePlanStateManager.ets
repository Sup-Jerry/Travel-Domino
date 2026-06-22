import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../../common/utils/DateUtil';
import { EventEntity } from '../../model/entity/EventEntity';
import { ArrivalReminderEngine } from '../../infrastructure/services/ArrivalReminderEngine';
import { PlanStateMachine } from '../../domain/statemachine/PlanStateMachine';
import { PlanStatus, TransitionTriggerSource } from '../../domain/statemachine/PlanStatus';
import { PlanTransitionEvent } from '../../domain/statemachine/ExecutionContext';
import { LocationChangeEvent } from '../../domain/statemachine/StateEventBus';
import { WeatherFacade } from '../../domain/services/WeatherFacade';
import { WeatherSuggestion, WeatherStageType } from '../../domain/services/WeatherModels';
import { ScheduleOrchestrator } from '../internal/ScheduleOrchestrator';
import { ConflictDetector } from '../../domain/timeline/ConflictDetector';
import { TimelineConflictResolver } from '../../domain/timeline/services/TimelineConflictResolver';
import { PlanDateShiftPreview } from '../types/TimelineTypes';

const TAG = 'TimelineViewModel';

interface RuntimeMotionSnapshot {
  latitude: number;
  longitude: number;
  speed?: number;
  accuracy?: number;
  ts: number;
}

interface CompanionRuntimeSnapshot {
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP';
}

export interface ITimelinePlanStateHost {
  planId: number;
  planName: string;
  events: EventEntity[];
  globalStartTime: string;
  planStartDate: number;
  idleGapDetectionEnabled: boolean;
  idleGapTriggerMinutes: number;
  currentPlanStatus: PlanStatus;
  weatherFeatureEnabled: boolean;
  executionWeatherEnabled: boolean;
  executionWeatherHint: string;
  executionWeatherSuggestions: WeatherSuggestion[];
  executionWeatherAppliedSummary: string;
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING';

  weatherFacade: WeatherFacade;
  planStateMachine: PlanStateMachine;

  resolveCurrentWeatherStage(): WeatherStageType;
  startExecutionWeatherScheduler(planId?: number, stage?: WeatherStageType): void;
  stopExecutionWeatherScheduler(): void;
  refreshExecutionWeather(
    forceRefresh?: boolean,
    trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void>;
  getCompanionContext(nowTs?: number): CompanionRuntimeSnapshot;
  recalculateFromIndex(startIndex: number): void;
  getScheduleOrchestrator(): ScheduleOrchestrator;
  isAutoRouteEnabled(): boolean;
  calculateRealtimeSchedule(): void;
  regenerateGroups(): void;
  markScheduleChanged(): void;
  refreshTimelineView(): void;
  persistPlanStartDate(planId: number, startDate: number): Promise<void>;
  persistPlanName(planId: number, name: string): Promise<void>;
}

export class TimelinePlanStateManager {
  private readonly host: ITimelinePlanStateHost;
  private planStateUnsubscribe: (() => void) | null = null;
  private planLocationChangeUnsubscribe: (() => void) | null = null;
  private stateEvaluationTimerId: number = -1;
  private readonly stateEvaluationIntervalMs: number = 60 * 1000;
  private readonly runtimeMotionSamples: RuntimeMotionSnapshot[] = [];
  private readonly runtimeMotionSampleLimit: number = 3;

  constructor(host: ITimelinePlanStateHost) {
    this.host = host;
  }

  public bindPlanState(planId: number): void {
    if (planId <= 0) {
      return;
    }
    this.unbindPlanState();
    const planIdStr = `${planId}`;
    this.host.currentPlanStatus = this.host.planStateMachine.getPlanStatus(planIdStr).status;
    this.planStateUnsubscribe = this.host.planStateMachine.subscribePlanTransition(planIdStr, (event: PlanTransitionEvent) => {
      this.host.currentPlanStatus = event.toStatus;
      this.handlePlanStateChanged(event.toStatus, event);
    });
    this.planLocationChangeUnsubscribe = this.host.planStateMachine.subscribeLocationChange(planIdStr, (event: LocationChangeEvent) => {
      this.handlePlanLocationChanged(event);
    });
    this.stateEvaluationTimerId = setInterval(() => {
      this.evaluatePlanStatusByRuntime();
    }, this.stateEvaluationIntervalMs);
    this.recoverPlanRuntimeState();
    this.syncPlanStatusAfterLoad();
    this.handlePlanStateChanged(this.host.currentPlanStatus);
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

  private syncPlanStatusAfterLoad(): void {
    if (this.host.planId <= 0) {
      return;
    }
    const planIdStr = `${this.host.planId}`;
    const scheduled = this.host.events.filter((item: EventEntity) => item.status === 1);
    const allCompleted = scheduled.length > 0 && scheduled.every((item: EventEntity) => item.completion_status === EventEntity.STATE_COMPLETED);

    if (allCompleted) {
      this.host.planStateMachine.completeExecution(planIdStr);
      this.host.currentPlanStatus = this.host.planStateMachine.getPlanStatus(planIdStr).status;
      return;
    }

    if (scheduled.length > 0) {
      this.host.planStateMachine.confirmPlan(planIdStr);
      this.host.currentPlanStatus = this.host.planStateMachine.getPlanStatus(planIdStr).status;
      this.evaluatePlanStatusByRuntime();
      this.host.currentPlanStatus = this.host.planStateMachine.getPlanStatus(planIdStr).status;
    }
  }

  public evaluatePlanStatusByRuntime(): void {
    if (this.host.planId <= 0) {
      return;
    }
    const planIdStr = `${this.host.planId}`;
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
    const input = this.host.planStateMachine.buildEvaluationInput(planIdStr, this.host.events, Date.now());
    this.host.planStateMachine.evaluateAndApply(input);
    this.host.currentPlanStatus = this.host.planStateMachine.getPlanStatus(planIdStr).status;
  }

  private handlePlanStateChanged(status: PlanStatus, _event?: PlanTransitionEvent): void {
    if (!this.host.weatherFeatureEnabled) {
      this.host.stopExecutionWeatherScheduler();
      return;
    }
    const stage = this.host.resolveCurrentWeatherStage();
    if (status === PlanStatus.CONFIRMED || status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED) {
      this.host.startExecutionWeatherScheduler(this.host.planId, stage);
      return;
    }
    this.host.stopExecutionWeatherScheduler();
    if (status === PlanStatus.COMPLETED || status === PlanStatus.CANCELLED || status === PlanStatus.EXPIRED) {
      this.host.executionWeatherHint = '';
      this.host.executionWeatherSuggestions = [];
    }
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
    if (this.host.planId <= 0) {
      return;
    }
    let motionDistance = 0;
    if (this.runtimeMotionSamples.length >= 2) {
      const first = this.runtimeMotionSamples[0];
      const last = this.runtimeMotionSamples[this.runtimeMotionSamples.length - 1];
      motionDistance = this.measureDistanceMeters(first.latitude, first.longitude, last.latitude, last.longitude);
    }
    this.host.planStateMachine.updateExecutionContext({
      planId: `${this.host.planId}`,
      lastKnownLatitude: latitude,
      lastKnownLongitude: longitude,
      lastKnownSpeed: speed,
      lastKnownAccuracy: accuracy,
      distanceToFirstNodeMeters: motionDistance,
      updatedAt: sampleTs
    });
  }

  private handlePlanLocationChanged(_event: LocationChangeEvent): void {
    if (!this.host.weatherFeatureEnabled || !this.host.executionWeatherEnabled) {
      return;
    }
    const stage = this.host.resolveCurrentWeatherStage();
    const policy = this.host.weatherFacade.resolveSchedulePolicy(stage);
    if (!policy.allowLocationTrigger) {
      return;
    }
    if (!(stage === 'READY' || stage === 'IN_PROGRESS' || stage === 'PAUSED')) {
      return;
    }
    void this.host.refreshExecutionWeather(false, 'LOCATION_CHANGE', stage);
  }

  public recoverPlanRuntimeState(): void {
    if (this.host.planId <= 0) {
      return;
    }
    const planIdStr = `${this.host.planId}`;
    const ctx = this.host.planStateMachine.getExecutionContext(planIdStr);
    const now = Date.now();
    if (!ctx) {
      this.host.planStateMachine.markRecovery(planIdStr, false, 'context_missing');
      this.evaluatePlanStatusByRuntime();
      this.host.planStateMachine.markRecovery(planIdStr, true, 'context_rebuild');
      return;
    }
    if (ctx.plannedEndTime > 0 && now > ctx.plannedEndTime && ctx.status !== PlanStatus.COMPLETED && ctx.status !== PlanStatus.CANCELLED && ctx.status !== PlanStatus.EXPIRED) {
      this.host.planStateMachine.markRecovery(planIdStr, false, 'context_expired');
    }
    if ((ctx.status === PlanStatus.IN_PROGRESS || ctx.status === PlanStatus.PAUSED) &&
      (!ctx.currentNodeId || ctx.currentNodeId.trim().length === 0)) {
      this.host.planStateMachine.markRecovery(planIdStr, false, 'context_partial');
    }
    this.host.currentPlanStatus = ctx.status;
    this.evaluatePlanStatusByRuntime();
    this.host.planStateMachine.markRecovery(planIdStr, true, 'context_restored');
    const latest = this.host.planStateMachine.getPlanStatus(planIdStr).status;
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
    if (this.host.planId <= 0) {
      return false;
    }
    const planIdStr = `${this.host.planId}`;
    const result = this.host.planStateMachine.pauseExecution(planIdStr);
    if (!result.success) {
      return false;
    }
    this.host.currentPlanStatus = result.toStatus;
    this.handlePlanStateChanged(result.toStatus, result.event);
    return true;
  }

  public resumeCurrentExecution(): boolean {
    if (this.host.planId <= 0) {
      return false;
    }
    const planIdStr = `${this.host.planId}`;
    const result = this.host.planStateMachine.resumeExecution(planIdStr);
    if (!result.success) {
      return false;
    }
    this.host.currentPlanStatus = result.toStatus;
    this.handlePlanStateChanged(result.toStatus, result.event);
    this.host.recalculateFromIndex(0);
    this.host.executionWeatherAppliedSummary = '执行恢复已触发增量重算（reasonCode=resume_recalculate）。';
    this.host.executionWeatherHint = this.host.executionWeatherAppliedSummary;
    this.host.executionWeatherLevel = 'NOTICE';
    void this.host.refreshExecutionWeather(true, 'ENTER_EXECUTION');
    return true;
  }

  public previewPlanDateShift(newDateTimestamp: number): PlanDateShiftPreview {
    const normalizedTimestamp = this.normalizeDateTimestamp(newDateTimestamp);
    const globalStartCandidate = DateUtil.extractPureTime(this.host.globalStartTime) || this.host.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = this.host.getScheduleOrchestrator().calculate(
      this.host.events.map((event: EventEntity) => event.toInterface()),
      effectiveGlobalStart,
      normalizedTimestamp,
      {
        autoRouteEnabled: this.host.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.host.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.host.idleGapTriggerMinutes
      }
    );

    const result = ConflictDetector.checkConflicts(this.host.events, calculated);
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
        `[SHIFT_VM][preview_ok] targetDate=${normalizedTimestamp}, eventCount=${this.host.events.length}`
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

  public async updatePlanDate(newDateTimestamp: number): Promise<void> {
    const normalizedTimestamp = this.normalizeDateTimestamp(newDateTimestamp);
    const oldPlanStartDate = this.host.planStartDate;
    this.host.planStartDate = normalizedTimestamp;

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][apply_plan_date] oldPlanStartDate=${oldPlanStartDate}, newPlanStartDate=${normalizedTimestamp}`
    );

    if (this.host.planId !== -1) {
      await this.host.persistPlanStartDate(this.host.planId, normalizedTimestamp);
    }

    this.host.calculateRealtimeSchedule();
    this.host.regenerateGroups();
    this.host.markScheduleChanged();
    this.host.refreshTimelineView();

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][apply_plan_date_done] planId=${this.host.planId}, groups_refreshed=true`
    );
  }

  public async renamePlan(newName: string): Promise<void> {
    if (this.host.planId === -1) {
      return;
    }
    await this.host.persistPlanName(this.host.planId, newName);
    this.host.planName = newName;
  }

  public isDateConflict(targetDateMs: number): boolean {
    return TimelineConflictResolver.isDateConflict(targetDateMs, this.host.planStartDate);
  }

  private normalizeDateTimestamp(timestamp: number): number {
    const nextDate = new Date(timestamp);
    nextDate.setHours(0, 0, 0, 0);
    return nextDate.getTime();
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
}
