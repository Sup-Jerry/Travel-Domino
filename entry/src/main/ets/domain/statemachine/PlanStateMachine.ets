import { EventEntity } from '../../model/entity/EventEntity';
import {
  AutoTransitionStats,
  ExecutionContext,
  EvaluateStatusResult,
  GetPlanStatusResult,
  PlanStageViewModel,
  PlanTransitionEvent,
  StateEvaluationInput,
  TransitionCommand,
  TransitionResult,
  UpdateExecutionContextCommand,
  createDefaultExecutionContext
} from './ExecutionContext';
import { PlanStatus, TransitionTriggerSource } from './PlanStatus';
import { StateEvaluator } from './StateEvaluator';
import { TransitionEngine } from './TransitionEngine';
import { ExecutionContextStore } from '../../infrastructure/persistence/ExecutionContextStore';
import { StateEventBus } from './StateEventBus';
import { NotificationBridge } from './NotificationBridge';
import { ReplanCoordinator, FullReplanCommand, ReplanResult, SoftReplanCommand } from './ReplanCoordinator';
import { WeatherRefreshScheduler, WeatherScheduleDecision } from './WeatherRefreshScheduler';
import { ArrivalReminderEngine } from '../../infrastructure/services/ArrivalReminderEngine';
import { PlanStateMetricsSnapshot, PlanStateMetricsStore } from './PlanStateMetricsStore';

export interface PlanStateMachineDeps {
  store?: ExecutionContextStore;
  evaluator?: StateEvaluator;
  transitionEngine?: TransitionEngine;
  stateEventBus?: StateEventBus;
  notificationBridge?: NotificationBridge;
  replanCoordinator?: ReplanCoordinator;
  weatherRefreshScheduler?: WeatherRefreshScheduler;
  metricsStore?: PlanStateMetricsStore;
}

export interface PlanStateDiagnosticsSnapshot {
  planId: string;
  dayKey: string;
  generatedAt: number;
  metrics: PlanStateMetricsSnapshot;
  transitions: PlanTransitionEvent[];
}

export class PlanStateMachine {
  private static instance: PlanStateMachine | null = null;

  private readonly store: ExecutionContextStore;
  private readonly evaluator: StateEvaluator;
  private readonly transitionEngine: TransitionEngine;
  private readonly stateEventBus: StateEventBus;
  private readonly notificationBridge: NotificationBridge;
  private readonly replanCoordinator: ReplanCoordinator;
  private readonly weatherRefreshScheduler: WeatherRefreshScheduler;
  private readonly metricsStore: PlanStateMetricsStore;

  private constructor(deps?: PlanStateMachineDeps) {
    this.store = deps?.store ?? ExecutionContextStore.getInstance();
    this.evaluator = deps?.evaluator ?? new StateEvaluator();
    this.transitionEngine = deps?.transitionEngine ?? new TransitionEngine();
    this.stateEventBus = deps?.stateEventBus ?? new StateEventBus();
    this.notificationBridge = deps?.notificationBridge ?? new NotificationBridge();
    this.replanCoordinator = deps?.replanCoordinator ?? new ReplanCoordinator();
    this.weatherRefreshScheduler = deps?.weatherRefreshScheduler ?? new WeatherRefreshScheduler();
    this.metricsStore = deps?.metricsStore ?? PlanStateMetricsStore.getInstance();
  }

  public static getInstance(deps?: PlanStateMachineDeps): PlanStateMachine {
    if (deps) {
      return new PlanStateMachine(deps);
    }
    if (!PlanStateMachine.instance) {
      PlanStateMachine.instance = new PlanStateMachine();
    }
    return PlanStateMachine.instance;
  }

  public getPlanStatus(planId: string): GetPlanStatusResult {
    const ctx = this.getOrCreateContext(planId, Date.now());
    const last = this.store.readLatestTransition(planId);
    return {
      planId: planId,
      status: ctx.status,
      lastTransitionTime: last?.timestamp,
      lastTransitionReason: last?.triggerReason,
      isAutoStarted: ctx.isAutoStarted
    };
  }

  public getExecutionContext(planId: string): ExecutionContext | null {
    return this.store.readContext(planId);
  }

  public getRecentTransitions(planId: string, limit: number = 10): PlanTransitionEvent[] {
    const all = this.store.readTransitions(planId);
    if (limit <= 0 || all.length <= limit) {
      return all;
    }
    return all.slice(all.length - limit);
  }

  public getDailyMetrics(planId: string, dayKey: string = PlanStateMetricsStore.buildDayKey(Date.now())): PlanStateMetricsSnapshot {
    return this.metricsStore.getSnapshot(planId, dayKey);
  }

  public exportDiagnosticsSnapshot(
    planId: string,
    dayKey: string = PlanStateMetricsStore.buildDayKey(Date.now()),
    transitionLimit: number = 50
  ): PlanStateDiagnosticsSnapshot {
    return {
      planId: planId,
      dayKey: dayKey,
      generatedAt: Date.now(),
      metrics: this.getDailyMetrics(planId, dayKey),
      transitions: this.getRecentTransitions(planId, transitionLimit)
    };
  }

  public updateExecutionContext(command: UpdateExecutionContextCommand): ExecutionContext {
    const current = this.getOrCreateContext(command.planId, command.updatedAt);
    const next = this.cloneContext(current);
    next.currentNodeId = command.currentNodeId ?? current.currentNodeId;
    next.nextNodeId = command.nextNodeId ?? current.nextNodeId;
    next.completedNodeIds = command.completedNodeIds ?? current.completedNodeIds;
    next.skippedNodeIds = command.skippedNodeIds ?? current.skippedNodeIds;
    next.lastKnownLatitude = command.lastKnownLatitude ?? current.lastKnownLatitude;
    next.lastKnownLongitude = command.lastKnownLongitude ?? current.lastKnownLongitude;
    next.lastKnownSpeed = command.lastKnownSpeed ?? current.lastKnownSpeed;
    next.lastKnownAccuracy = command.lastKnownAccuracy ?? current.lastKnownAccuracy;
    next.distanceToFirstNodeMeters = command.distanceToFirstNodeMeters ?? current.distanceToFirstNodeMeters;
    next.weatherSnapshotVersion = command.weatherSnapshotVersion ?? current.weatherSnapshotVersion;
    next.updatedAt = command.updatedAt;
    this.store.writeContext(next);
    return next;
  }

  public evaluatePlanStatus(input: StateEvaluationInput): EvaluateStatusResult {
    return this.evaluator.evaluateNextStatus(input);
  }

  public transitionPlanStatus(command: TransitionCommand): TransitionResult {
    const current = this.getOrCreateContext(command.planId, Date.now());
    const result = this.transitionEngine.transitionPlanStatus(current.status, command);
    if (!result.success) {
      this.bumpTransitionFailMetric(command.planId, command.targetStatus, result.errorCode ?? 'transition_failed');
      return result;
    }
    if (!result.event) {
      return result;
    }
    const transitionEvent = result.event;

    const now = transitionEvent.timestamp;
    const nextContext = this.cloneContext(current);
    nextContext.status = result.toStatus;
    nextContext.isPaused = result.toStatus === PlanStatus.PAUSED;
    nextContext.isAutoStarted = current.isAutoStarted || command.triggerSource !== TransitionTriggerSource.USER_ACTION;
    nextContext.actualStartTime = result.toStatus === PlanStatus.IN_PROGRESS && !current.actualStartTime ? now : current.actualStartTime;
    nextContext.actualEndTime = this.isEndStatus(result.toStatus) ? now : current.actualEndTime;
    nextContext.lastTransitionReason = command.triggerReason;
    nextContext.lastTransitionAt = now;
    nextContext.updatedAt = now;

    this.store.writeContext(nextContext);
    this.store.appendTransition(transitionEvent);
    this.safeSideEffect(() => this.stateEventBus.publish(transitionEvent), 'event_bus_publish');
    this.safeSideEffect(() => this.notificationBridge.handlePlanTransitionNotification(transitionEvent), 'notification_bridge');
    this.safeSideEffect(() => this.weatherRefreshScheduler.onStatusEntered(command.planId, result.toStatus, now), 'weather_scheduler');
    this.safeSideEffect(() => this.replanCoordinator.onStateEntered(result.toStatus, nextContext), 'replan_coordinator');
    this.bumpTransitionSuccessMetric(command.planId, result.toStatus, command.triggerReason);
    return result;
  }

  public confirmPlan(planId: string): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.CONFIRMED,
      triggerSource: TransitionTriggerSource.USER_ACTION,
      triggerReason: 'confirm_plan'
    });
  }

  public prepareExecution(planId: string, source: TransitionTriggerSource = TransitionTriggerSource.USER_ACTION): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.READY,
      triggerSource: source,
      triggerReason: source === TransitionTriggerSource.USER_ACTION ? 'prepare_by_user' : 'auto_enter_ready'
    });
  }

  public startExecution(planId: string, source: TransitionTriggerSource = TransitionTriggerSource.USER_ACTION): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.IN_PROGRESS,
      triggerSource: source,
      triggerReason: source === TransitionTriggerSource.USER_ACTION ? 'start_by_user' : 'auto_start_execution'
    });
  }

  public pauseExecution(planId: string, reason: string = 'pause_by_user'): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.PAUSED,
      triggerSource: TransitionTriggerSource.USER_ACTION,
      triggerReason: reason
    });
  }

  public resumeExecution(planId: string): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.IN_PROGRESS,
      triggerSource: TransitionTriggerSource.USER_ACTION,
      triggerReason: 'resume_by_user'
    });
  }

  public completeExecution(planId: string): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.COMPLETED,
      triggerSource: TransitionTriggerSource.TASK_COMPLETION,
      triggerReason: 'complete_execution'
    });
  }

  public cancelPlan(planId: string, reason: string = 'cancel_by_user'): TransitionResult {
    return this.transitionPlanStatus({
      planId: planId,
      targetStatus: PlanStatus.CANCELLED,
      triggerSource: TransitionTriggerSource.USER_ACTION,
      triggerReason: reason
    });
  }

  public evaluateAndApply(input: StateEvaluationInput): TransitionResult | null {
    if (input.currentStatus === PlanStatus.READY &&
      this.evaluator.shouldEnterInProgress(input) &&
      this.evaluator.shouldBlockReadyLeave(input.now, input.lastTransitionAt)) {
      this.metricsStore.bump(input.planId, PlanStateMetricsStore.buildDayKey(input.now), 'transition_jitter_blocked', 'ready_min_stay_blocked', input.now);
      return null;
    }

    const evalResult = this.evaluatePlanStatus(input);
    if (!evalResult.shouldTransition || !evalResult.triggerSource || !evalResult.triggerReason) {
      return null;
    }

    const result = this.transitionPlanStatus({
      planId: input.planId,
      expectedFromStatus: input.currentStatus,
      targetStatus: evalResult.suggestedStatus,
      triggerSource: evalResult.triggerSource,
      triggerReason: evalResult.triggerReason
    });

    if (!result.success) {
      this.bumpTransitionFailMetric(input.planId, evalResult.suggestedStatus, result.errorCode ?? 'auto_transition_failed');
    }
    return result;
  }

  public markRecovery(planId: string, ok: boolean, reasonCode: string): void {
    const dayKey = PlanStateMetricsStore.buildDayKey(Date.now());
    this.metricsStore.bump(planId, dayKey, 'recovery_attempt', reasonCode);
    this.metricsStore.bump(planId, dayKey, ok ? 'recovery_success' : 'recovery_fail', reasonCode);
  }

  public getPlanStageViewModel(planId: string): PlanStageViewModel {
    const ctx = this.getOrCreateContext(planId, Date.now());
    const status = ctx.status;
    return {
      planId: planId,
      status: status,
      stageLabel: this.toStageLabel(status),
      canStart: status === PlanStatus.CONFIRMED || status === PlanStatus.READY,
      canPause: status === PlanStatus.IN_PROGRESS,
      canResume: status === PlanStatus.PAUSED,
      canCancel: !this.isEndStatus(status),
      canReplan: status === PlanStatus.DRAFT || status === PlanStatus.CONFIRMED || status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED,
      weatherMode: this.resolveWeatherMode(status),
      statusHint: ctx.lastTransitionReason
    };
  }

  public buildEvaluationInput(planId: string, events: EventEntity[], now: number = Date.now()): StateEvaluationInput {
    const current = this.getOrCreateContext(planId, now);
    const scheduled = (events || []).filter((item: EventEntity) => item.status === 1);
    const pending = scheduled.filter((item: EventEntity) => item.completion_status === EventEntity.STATE_PENDING);
    const first = pending.length > 0 ? pending[0] : undefined;
    const allCompleted = scheduled.length > 0 && scheduled.every((item: EventEntity) => item.completion_status === EventEntity.STATE_COMPLETED);

    let lastLat = current.lastKnownLatitude;
    let lastLng = current.lastKnownLongitude;
    let lastSpeed = current.lastKnownSpeed;
    let lastAccuracy = current.lastKnownAccuracy;
    const arrival = ArrivalReminderEngine.getInstance().getLastKnownLocation();
    if (arrival) {
      lastLat = arrival.latitude;
      lastLng = arrival.longitude;
      lastSpeed = arrival.speed;
      lastAccuracy = arrival.accuracy;
    }

    let distance: number | undefined = undefined;
    if (first && this.hasLocation(lastLat, lastLng)) {
      distance = this.measureDistanceMeters(Number(lastLat), Number(lastLng), first.latitude, first.longitude);
    }

    const reachedFirst = distance !== undefined ? distance <= 300 : false;
    const accuracyPass = lastAccuracy === undefined || !Number.isFinite(lastAccuracy) || lastAccuracy <= 80;
    const speedPass = lastSpeed !== undefined && Number.isFinite(lastSpeed) && lastSpeed >= 1.2;
    const distancePass = distance !== undefined && distance >= 120;

    return {
      planId: planId,
      currentStatus: current.status,
      now: now,
      firstNodeStartTime: first?.dynamic_start_time,
      firstNodeLat: first?.latitude,
      firstNodeLng: first?.longitude,
      lastKnownLat: lastLat,
      lastKnownLng: lastLng,
      currentSpeed: lastSpeed,
      currentAccuracy: lastAccuracy,
      motionDistanceMeters: distance,
      lastTransitionAt: current.lastTransitionAt,
      locationPermissionGranted: this.hasLocation(lastLat, lastLng),
      userClickedStart: false,
      userClickedPause: false,
      userClickedResume: false,
      userClickedCancel: false,
      hasReachedFirstNode: reachedFirst,
      motionDetected: accuracyPass && (speedPass || distancePass),
      allNodesCompleted: allCompleted,
      isPlanExpired: current.plannedEndTime > 0 && now > current.plannedEndTime
    };
  }

  public subscribePlanTransition(planId: string, listener: (event: PlanTransitionEvent) => void): () => void {
    return this.stateEventBus.subscribe(planId, listener);
  }

  public requestSoftReplan(command: SoftReplanCommand): ReplanResult {
    const context = this.getOrCreateContext(command.planId, Date.now());
    return this.replanCoordinator.requestSoftReplan(command, context);
  }

  public requestFullReplan(command: FullReplanCommand): ReplanResult {
    const status = this.getOrCreateContext(command.planId, Date.now()).status;
    return this.replanCoordinator.requestFullReplan(command, status);
  }

  public evaluateWeatherRefresh(planId: string): WeatherScheduleDecision {
    const ctx = this.getOrCreateContext(planId, Date.now());
    return this.weatherRefreshScheduler.evaluate(planId, ctx.status, Date.now());
  }

  private getOrCreateContext(planId: string, now: number): ExecutionContext {
    const existing = this.store.readContext(planId);
    if (existing) {
      if (!existing.autoTransitionStats) {
        existing.autoTransitionStats = this.createEmptyStats();
        this.store.writeContext(existing);
      }
      return existing;
    }
    const created = createDefaultExecutionContext(planId, now);
    this.store.writeContext(created);
    return created;
  }

  private cloneContext(source: ExecutionContext): ExecutionContext {
    return {
      planId: source.planId,
      status: source.status,
      plannedStartTime: source.plannedStartTime,
      plannedEndTime: source.plannedEndTime,
      actualStartTime: source.actualStartTime,
      actualEndTime: source.actualEndTime,
      currentNodeId: source.currentNodeId,
      nextNodeId: source.nextNodeId,
      completedNodeIds: source.completedNodeIds.slice(),
      skippedNodeIds: source.skippedNodeIds.slice(),
      lastKnownLatitude: source.lastKnownLatitude,
      lastKnownLongitude: source.lastKnownLongitude,
      lastKnownSpeed: source.lastKnownSpeed,
      lastKnownAccuracy: source.lastKnownAccuracy,
      lastLocationUpdateTime: source.lastLocationUpdateTime,
      lastTransitionAt: source.lastTransitionAt,
      distanceToFirstNodeMeters: source.distanceToFirstNodeMeters,
      autoTransitionStats: this.cloneStats(source.autoTransitionStats),
      isAutoStarted: source.isAutoStarted,
      isPaused: source.isPaused,
      lastTransitionReason: source.lastTransitionReason,
      weatherSnapshotVersion: source.weatherSnapshotVersion,
      updatedAt: source.updatedAt
    };
  }

  private cloneStats(source?: AutoTransitionStats): AutoTransitionStats {
    const stats = source ?? this.createEmptyStats();
    return {
      readyAttempt: stats.readyAttempt,
      readySuccess: stats.readySuccess,
      readyFail: stats.readyFail,
      inProgressAttempt: stats.inProgressAttempt,
      inProgressSuccess: stats.inProgressSuccess,
      inProgressFail: stats.inProgressFail,
      jitterBlocked: stats.jitterBlocked
    };
  }

  private createEmptyStats(): AutoTransitionStats {
    return {
      readyAttempt: 0,
      readySuccess: 0,
      readyFail: 0,
      inProgressAttempt: 0,
      inProgressSuccess: 0,
      inProgressFail: 0,
      jitterBlocked: 0
    };
  }

  private bumpTransitionSuccessMetric(planId: string, toStatus: PlanStatus, reason: string): void {
    const dayKey = PlanStateMetricsStore.buildDayKey(Date.now());
    if (toStatus === PlanStatus.READY) {
      this.metricsStore.bump(planId, dayKey, 'auto_transition_attempt_ready', reason);
      this.metricsStore.bump(planId, dayKey, 'auto_transition_success_ready', reason);
      return;
    }
    if (toStatus === PlanStatus.IN_PROGRESS) {
      this.metricsStore.bump(planId, dayKey, 'auto_transition_attempt_in_progress', reason);
      this.metricsStore.bump(planId, dayKey, 'auto_transition_success_in_progress', reason);
    }
  }

  private bumpTransitionFailMetric(planId: string, toStatus: PlanStatus, reason: string): void {
    const dayKey = PlanStateMetricsStore.buildDayKey(Date.now());
    if (toStatus === PlanStatus.READY) {
      this.metricsStore.bump(planId, dayKey, 'auto_transition_attempt_ready', reason);
      this.metricsStore.bump(planId, dayKey, 'auto_transition_fail_ready', reason);
      return;
    }
    if (toStatus === PlanStatus.IN_PROGRESS) {
      this.metricsStore.bump(planId, dayKey, 'auto_transition_attempt_in_progress', reason);
      this.metricsStore.bump(planId, dayKey, 'auto_transition_fail_in_progress', reason);
    }
  }

  private isEndStatus(status: PlanStatus): boolean {
    return status === PlanStatus.COMPLETED || status === PlanStatus.CANCELLED || status === PlanStatus.EXPIRED;
  }

  private toStageLabel(status: PlanStatus): string {
    if (status === PlanStatus.DRAFT) return '草稿';
    if (status === PlanStatus.CONFIRMED) return '已确认未开始';
    if (status === PlanStatus.READY) return '执行预备';
    if (status === PlanStatus.IN_PROGRESS) return '执行中';
    if (status === PlanStatus.PAUSED) return '暂停中';
    if (status === PlanStatus.COMPLETED) return '已完成';
    if (status === PlanStatus.CANCELLED) return '已取消';
    return '已失效';
  }

  private resolveWeatherMode(status: PlanStatus): 'PLAN_LOCATION' | 'CURRENT_AND_PLAN' | 'CURRENT_PRIORITY' | 'DISABLED' {
    if (status === PlanStatus.DRAFT || status === PlanStatus.CONFIRMED) {
      return 'PLAN_LOCATION';
    }
    if (status === PlanStatus.READY) {
      return 'CURRENT_AND_PLAN';
    }
    if (status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED) {
      return 'CURRENT_PRIORITY';
    }
    return 'DISABLED';
  }

  private hasLocation(lat?: number, lng?: number): boolean {
    if (lat === undefined || lng === undefined) {
      return false;
    }
    return Number.isFinite(lat) && Number.isFinite(lng);
  }

  private measureDistanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    if (!Number.isFinite(lat1) || !Number.isFinite(lng1) || !Number.isFinite(lat2) || !Number.isFinite(lng2)) {
      return Number.MAX_VALUE;
    }
    const rad = Math.PI / 180;
    const dLat = (lat2 - lat1) * rad;
    const dLng = (lng2 - lng1) * rad;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return 6371000 * c;
  }

  private safeSideEffect(run: () => void, _tag: string): void {
    try {
      run();
    } catch (_error) {
      // Side-effect failures must not break status transitions.
    }
  }
}





