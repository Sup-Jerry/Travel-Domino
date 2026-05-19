import { describe, it, expect } from '@ohos/hypium';
import { PlanStateMachine, PlanStateMachineDeps } from '../main/ets/domain/statemachine/PlanStateMachine';
import { TransitionEngine } from '../main/ets/domain/statemachine/TransitionEngine';
import { StateEvaluator } from '../main/ets/domain/statemachine/StateEvaluator';
import { FullReplanCommand, ReplanCoordinator, ReplanResult, SoftReplanCommand } from '../main/ets/domain/statemachine/ReplanCoordinator';
import {
  AutoTransitionStats,
  ExecutionContext,
  PlanTransitionEvent,
  StateEvaluationInput,
  createDefaultExecutionContext
} from '../main/ets/domain/statemachine/ExecutionContext';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanWeatherRefreshPlanner, PlanWeatherScheduleDecision } from '../main/ets/domain/statemachine/WeatherRefreshScheduler';
import { ExecutionContextStore } from '../main/ets/infrastructure/persistence/ExecutionContextStore';
import { LocationChangeEvent, StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';
import { NotificationBridge } from '../main/ets/domain/statemachine/NotificationBridge';
import { PlanStateMetricsSnapshot, PlanStateMetricsStore } from '../main/ets/domain/statemachine/PlanStateMetricsStore';

class FakeExecutionContextStore extends ExecutionContextStore {
  private readonly contexts: Map<string, ExecutionContext> = new Map<string, ExecutionContext>();
  private readonly transitions: Map<string, PlanTransitionEvent[]> = new Map<string, PlanTransitionEvent[]>();

  public readContext(planId: string): ExecutionContext | null {
    return this.contexts.get(planId) ?? null;
  }

  public writeContext(context: ExecutionContext): void {
    this.contexts.set(context.planId, context);
  }

  public clearContext(planId: string): void {
    this.contexts.delete(planId);
  }

  public appendTransition(event: PlanTransitionEvent): void {
    const list = this.transitions.get(event.planId) ?? [];
    list.push(event);
    this.transitions.set(event.planId, list);
  }

  public readTransitions(planId: string): PlanTransitionEvent[] {
    return this.transitions.get(planId) ?? [];
  }

  public readLatestTransition(planId: string): PlanTransitionEvent | null {
    const list = this.readTransitions(planId);
    return list.length > 0 ? list[list.length - 1] : null;
  }
}

class FakeStateEventBus extends StateEventBus {
  public publishedTransitions: PlanTransitionEvent[] = [];
  public publishedLocations: number = 0;

  public subscribe(_planId: string, _listener: (event: PlanTransitionEvent) => void): () => void {
    return () => {
      return;
    };
  }

  public publish(event: PlanTransitionEvent): void {
    this.publishedTransitions.push(event);
  }

  public subscribeLocationChange(_planId: string, _listener: (event: LocationChangeEvent) => void): () => void {
    return () => {
      return;
    };
  }

  public publishLocationChange(_event: LocationChangeEvent): void {
    this.publishedLocations += 1;
  }
}

class FakeNotificationBridge extends NotificationBridge {
  public handledCount: number = 0;

  public handlePlanTransitionNotification(_event: PlanTransitionEvent): void {
    this.handledCount += 1;
  }
}

class FakeReplanCoordinator extends ReplanCoordinator {
  public onStateEnteredCount: number = 0;

  public onStateEntered(_status: PlanStatus, _context: ExecutionContext): void {
    this.onStateEnteredCount += 1;
  }

  public requestSoftReplan(command: SoftReplanCommand, _context: ExecutionContext): ReplanResult {
    const result: ReplanResult = {
      success: true,
      planId: command.planId,
      changed: true,
      reasonCode: 'soft_stub'
    };
    return result;
  }

  public requestFullReplan(command: FullReplanCommand, _status: PlanStatus): ReplanResult {
    const result: ReplanResult = {
      success: true,
      planId: command.planId,
      changed: true,
      reasonCode: 'full_stub'
    };
    return result;
  }
}

class FakeWeatherRefreshPlanner extends PlanWeatherRefreshPlanner {
  public enteredCount: number = 0;

  public onStatusEntered(_planId: string, _status: PlanStatus, now: number): PlanWeatherScheduleDecision {
    this.enteredCount += 1;
    return {
      shouldRefresh: false,
      nextRefreshAt: now + 60_000,
      intervalMinutes: 1
    };
  }

  public evaluate(_planId: string, _status: PlanStatus, now: number): PlanWeatherScheduleDecision {
    return {
      shouldRefresh: true,
      nextRefreshAt: now + 120_000,
      intervalMinutes: 2
    };
  }
}

class FakePlanStateMetricsStore extends PlanStateMetricsStore {
  public bumpCount: number = 0;
  public lastReason: string = '';

  public bump(_planId: string, _dayKey: string, _key: string, reasonCode?: string): void {
    this.bumpCount += 1;
    this.lastReason = reasonCode ?? '';
  }

  public getSnapshot(planId: string, dayKey: string): PlanStateMetricsSnapshot {
    const counters: Record<string, number> = {};
    const reasons: Record<string, number> = {};
    const snapshot: PlanStateMetricsSnapshot = {
      planId: planId,
      dayKey: dayKey,
      counters: counters,
      reasons: reasons,
      updatedAt: Date.now()
    };
    return snapshot;
  }
}

function buildInput(overrides?: Partial<StateEvaluationInput>): StateEvaluationInput {
  const now = Date.now();
  return {
    planId: overrides?.planId ?? 'p_default',
    currentStatus: overrides?.currentStatus ?? PlanStatus.CONFIRMED,
    now: overrides?.now ?? now,
    firstNodeStartTime: overrides?.firstNodeStartTime,
    firstNodeLat: overrides?.firstNodeLat,
    firstNodeLng: overrides?.firstNodeLng,
    lastKnownLat: overrides?.lastKnownLat,
    lastKnownLng: overrides?.lastKnownLng,
    currentSpeed: overrides?.currentSpeed,
    currentAccuracy: overrides?.currentAccuracy,
    motionDistanceMeters: overrides?.motionDistanceMeters,
    lastTransitionAt: overrides?.lastTransitionAt,
    locationPermissionGranted: overrides?.locationPermissionGranted ?? true,
    userClickedStart: overrides?.userClickedStart ?? false,
    userClickedPause: overrides?.userClickedPause ?? false,
    userClickedResume: overrides?.userClickedResume ?? false,
    userClickedCancel: overrides?.userClickedCancel ?? false,
    hasReachedFirstNode: overrides?.hasReachedFirstNode ?? false,
    motionDetected: overrides?.motionDetected ?? false,
    allNodesCompleted: overrides?.allNodesCompleted ?? false,
    isPlanExpired: overrides?.isPlanExpired ?? false
  };
}

interface MachineBundleForAE {
  machine: PlanStateMachine;
  store: FakeExecutionContextStore;
  eventBus: FakeStateEventBus;
  notification: FakeNotificationBridge;
  replan: FakeReplanCoordinator;
  weather: FakeWeatherRefreshPlanner;
  metrics: FakePlanStateMetricsStore;
}

function createMachineBundle(): MachineBundleForAE {
  const store = new FakeExecutionContextStore();
  const eventBus = new FakeStateEventBus();
  const notification = new FakeNotificationBridge();
  const replan = new FakeReplanCoordinator();
  const weather = new FakeWeatherRefreshPlanner();
  const metrics = new FakePlanStateMetricsStore();
  const deps: PlanStateMachineDeps = {
    store: store,
    evaluator: new StateEvaluator(),
    transitionEngine: new TransitionEngine(),
    stateEventBus: eventBus,
    notificationBridge: notification,
    replanCoordinator: replan,
    weatherRefreshPlanner: weather,
    metricsStore: metrics
  };
  return {
    machine: PlanStateMachine.getInstance(deps),
    store,
    eventBus,
    notification,
    replan,
    weather,
    metrics
  };
}

export default function phase2BatchAETest() {
  describe('phase2BatchAETest_execution_context', () => {
    it('normal: create_default_execution_context_should_fill_defaults', 0, () => {
      // Arrange
      // Act
      // Assert
      const ctx = createDefaultExecutionContext('ctx_n', 1000, 1200, 1800);
      expect(ctx.planId).assertEqual('ctx_n');
      expect(ctx.status).assertEqual(PlanStatus.DRAFT);
      expect(ctx.plannedStartTime).assertEqual(1200);
      expect(ctx.plannedEndTime).assertEqual(1800);
      expect((ctx.autoTransitionStats?.readyAttempt ?? -1)).assertEqual(0);
      expect(ctx.completedNodeIds.length).assertEqual(0);
    });

    it('boundary: create_default_execution_context_should_accept_zero_times', 0, () => {
      // Arrange
      // Act
      // Assert
      const ctx = createDefaultExecutionContext('ctx_b', 0, 0, 0);
      expect(ctx.updatedAt).assertEqual(0);
      expect(ctx.plannedStartTime).assertEqual(0);
      expect(ctx.plannedEndTime).assertEqual(0);
    });

    it('invalid: create_default_execution_context_should_keep_invalid_plan_id_input', 0, () => {
      // Arrange
      // Act
      // Assert
      const ctx = createDefaultExecutionContext('', 10);
      expect(ctx.planId).assertEqual('');
      expect(ctx.status).assertEqual(PlanStatus.DRAFT);
    });
  });

  describe('phase2BatchAETest_transition_engine', () => {
    it('normal: can_transition_should_allow_confirmed_to_ready', 0, () => {
      // Arrange
      // Act
      // Assert
      const engine = new TransitionEngine();
      expect(engine.canTransition(PlanStatus.CONFIRMED, PlanStatus.READY)).assertEqual(true);
    });

    it('boundary: can_transition_should_allow_same_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const engine = new TransitionEngine();
      expect(engine.canTransition(PlanStatus.PAUSED, PlanStatus.PAUSED)).assertEqual(true);
    });

    it('invalid: transition_plan_status_should_fail_on_status_conflict', 0, () => {
      // Arrange
      // Act
      // Assert
      const engine = new TransitionEngine();
      const result = engine.transitionPlanStatus(PlanStatus.READY, {
        planId: 'te_invalid',
        expectedFromStatus: PlanStatus.CONFIRMED,
        targetStatus: PlanStatus.IN_PROGRESS,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'wrong_expected'
      });
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('STATUS_CONFLICT');
    });

    it('normal: transition_plan_status_should_emit_event_when_status_changes', 0, () => {
      // Arrange
      // Act
      // Assert
      const engine = new TransitionEngine();
      const result = engine.transitionPlanStatus(PlanStatus.CONFIRMED, {
        planId: 'te_normal',
        targetStatus: PlanStatus.READY,
        triggerSource: TransitionTriggerSource.TIME_WINDOW,
        triggerReason: 'window_hit'
      });
      expect(result.success).assertEqual(true);
      expect(result.event?.planId).assertEqual('te_normal');
      expect(result.event?.toStatus).assertEqual(PlanStatus.READY);
    });
  });

  describe('phase2BatchAETest_state_evaluator', () => {
    it('normal: evaluate_next_status_should_resume_from_paused_after_min_stay', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const result = evaluator.evaluateNextStatus(buildInput({
        planId: 'se_resume',
        currentStatus: PlanStatus.PAUSED,
        now: now,
        userClickedResume: true,
        lastTransitionAt: now - 30_000
      }));
      expect(result.shouldTransition).assertEqual(true);
      expect(result.suggestedStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(result.triggerReason).assertEqual('resume_by_user');
    });

    it('boundary: should_enter_ready_should_be_false_when_start_time_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const canEnter = evaluator.shouldEnterReady(buildInput({
        planId: 'se_boundary_ready',
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        firstNodeStartTime: undefined,
        hasReachedFirstNode: false
      }));
      expect(canEnter).assertEqual(false);
    });

    it('invalid: evaluate_next_status_should_fallback_to_manual_override_meta_for_unmatched_path', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const result = evaluator.evaluateNextStatus(buildInput({
        planId: 'se_invalid_manual',
        currentStatus: PlanStatus.DRAFT,
        now: now,
        allNodesCompleted: true
      }));
      expect(result.shouldTransition).assertEqual(true);
      expect(result.suggestedStatus).assertEqual(PlanStatus.COMPLETED);
      expect(result.triggerSource).assertEqual(TransitionTriggerSource.TASK_COMPLETION);
    });

    it('boundary: should_block_ready_leave_should_flip_at_exact_threshold', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new StateEvaluator();
      const now = Date.now();
      expect(evaluator.shouldBlockReadyLeave(now, now - 119_999)).assertEqual(true);
      expect(evaluator.shouldBlockReadyLeave(now, now - 120_000)).assertEqual(false);
    });

    it('invalid: should_enter_in_progress_should_be_false_without_any_trigger', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const canEnter = evaluator.shouldEnterInProgress(buildInput({
        planId: 'se_invalid_inprogress',
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now + 60 * 60 * 1000,
        motionDetected: false,
        userClickedStart: false,
        hasReachedFirstNode: false
      }));
      expect(canEnter).assertEqual(false);
    });
  });

  describe('phase2BatchAETest_replan_coordinator', () => {
    it('normal: request_soft_replan_should_trim_current_node_id_and_generate_start_event_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const ctx = createDefaultExecutionContext('rp_soft_n', Date.now());
      ctx.status = PlanStatus.READY;
      const result = coordinator.requestSoftReplan({
        planId: 'rp_soft_n',
        reason: 'rain',
        currentNodeId: ' 1002 ',
        preserveCompletedNodes: true,
        preserveStartedWindow: true,
        useWeatherConstraint: true
      }, ctx);
      expect(result.success).assertEqual(true);
      expect(result.changed).assertEqual(true);
      expect(result.startFromEventId).assertEqual(1002);
      expect(result.reasonCode).assertEqual('weather_soft_replan');
    });

    it('boundary: request_soft_replan_should_fallback_to_context_current_node_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const ctx = createDefaultExecutionContext('rp_soft_b', Date.now());
      ctx.status = PlanStatus.IN_PROGRESS;
      ctx.currentNodeId = '88';
      const result = coordinator.requestSoftReplan({
        planId: 'rp_soft_b',
        reason: 'traffic',
        currentNodeId: '   ',
        preserveCompletedNodes: false,
        preserveStartedWindow: false,
        useWeatherConstraint: false
      }, ctx);
      expect(result.success).assertEqual(true);
      expect(result.startFromEventId).assertEqual(88);
    });

    it('invalid: request_soft_replan_should_reject_non_runnable_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const ctx = createDefaultExecutionContext('rp_soft_invalid', Date.now());
      ctx.status = PlanStatus.DRAFT;
      const result = coordinator.requestSoftReplan({
        planId: 'rp_soft_invalid',
        reason: 'rain',
        currentNodeId: '101',
        preserveCompletedNodes: true,
        preserveStartedWindow: true,
        useWeatherConstraint: true
      }, ctx);
      expect(result.success).assertEqual(false);
      expect(result.changed).assertEqual(false);
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
      expect(result.reasonCode).assertEqual('status_blocked');
    });

    it('boundary: request_soft_replan_should_return_zero_start_event_id_when_anchor_is_missing_or_non_positive', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const emptyCtx = createDefaultExecutionContext('rp_soft_empty_anchor', Date.now());
      emptyCtx.status = PlanStatus.PAUSED;
      const emptyAnchor = coordinator.requestSoftReplan({
        planId: 'rp_soft_empty_anchor',
        reason: 'rain',
        preserveCompletedNodes: false,
        preserveStartedWindow: false,
        useWeatherConstraint: false
      }, emptyCtx);

      const negativeCtx = createDefaultExecutionContext('rp_soft_negative_anchor', Date.now());
      negativeCtx.status = PlanStatus.READY;
      const negativeAnchor = coordinator.requestSoftReplan({
        planId: 'rp_soft_negative_anchor',
        reason: 'traffic',
        currentNodeId: '-3',
        preserveCompletedNodes: true,
        preserveStartedWindow: false,
        useWeatherConstraint: true
      }, negativeCtx);
      const emptySummary = (emptyAnchor.changeSummary ?? [])[0];
      const negativeSummary = (negativeAnchor.changeSummary ?? [])[0];

      expect(emptyAnchor.success).assertEqual(true);
      expect(emptyAnchor.startFromEventId).assertEqual(0);
      expect(emptySummary ? emptySummary.nodeId : '').assertEqual('');
      expect(negativeAnchor.success).assertEqual(true);
      expect(negativeAnchor.startFromEventId).assertEqual(0);
      expect(negativeSummary ? negativeSummary.nodeId : '').assertEqual('-3');
    });

    it('boundary: request_soft_replan_should_floor_decimal_anchor_and_keep_summary_metadata', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const ctx = createDefaultExecutionContext('rp_soft_decimal', Date.now());
      ctx.status = PlanStatus.PAUSED;
      ctx.completedNodeIds = ['a', 'b'];
      const result = coordinator.requestSoftReplan({
        planId: 'rp_soft_decimal',
        reason: 'weather',
        currentNodeId: '7.9',
        preserveCompletedNodes: false,
        preserveStartedWindow: true,
        useWeatherConstraint: false
      }, ctx);
      const summary = (result.changeSummary ?? [])[0];
      const summaryAfter = summary && summary.after ? summary.after : '';
      expect(result.success).assertEqual(true);
      expect(result.startFromEventId).assertEqual(7);
      expect(result.preserveCompletedNodes).assertEqual(false);
      expect(summaryAfter.includes('completed=2')).assertEqual(true);
    });

    it('invalid: request_full_replan_should_reject_terminal_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const result = coordinator.requestFullReplan({
        planId: 'rp_full_invalid',
        reason: 'force',
        triggeredBy: 'test',
        useWeatherConstraint: true
      }, PlanStatus.PAUSED);
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
      expect(result.reasonCode).assertEqual('status_blocked');
    });

    it('normal: request_full_replan_should_succeed_for_draft_and_confirmed_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const draftResult = coordinator.requestFullReplan({
        planId: 'rp_full_draft',
        reason: 'force',
        triggeredBy: 'draft_test',
        useWeatherConstraint: false
      }, PlanStatus.DRAFT);
      const confirmedResult = coordinator.requestFullReplan({
        planId: 'rp_full_confirmed',
        reason: 'storm',
        triggeredBy: 'confirmed_test',
        useWeatherConstraint: true
      }, PlanStatus.CONFIRMED);
      const draftSummary = (draftResult.changeSummary ?? [])[0];
      const confirmedSummary = (confirmedResult.changeSummary ?? [])[0];
      const draftAfter = draftSummary && draftSummary.after ? draftSummary.after : '';
      const confirmedAfter = confirmedSummary && confirmedSummary.after ? confirmedSummary.after : '';
      expect(draftResult.success).assertEqual(true);
      expect(draftResult.reasonCode).assertEqual('full_replan');
      expect(draftAfter.includes('triggered_by=draft_test')).assertEqual(true);
      expect(confirmedResult.success).assertEqual(true);
      expect(confirmedResult.reasonCode).assertEqual('full_replan');
      expect(confirmedAfter.includes('weather=true')).assertEqual(true);
    });

    it('normal: on_state_entered_should_be_no_op_without_throw', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const ctx = createDefaultExecutionContext('rp_noop', Date.now());
      coordinator.onStateEntered(PlanStatus.READY, ctx);
      expect(true).assertEqual(true);
    });
  });

  describe('phase2BatchAETest_plan_state_machine', () => {
    it('normal: update_execution_context_should_merge_and_emit_location_when_threshold_met', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_update_normal';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);

      const updated = bundle.machine.updateExecutionContext({
        planId: planId,
        currentNodeId: 'node_1',
        completedNodeIds: ['a'],
        skippedNodeIds: ['b'],
        lastKnownLatitude: 31.2,
        lastKnownLongitude: 121.4,
        lastKnownSpeed: 2,
        lastKnownAccuracy: 20,
        distanceToFirstNodeMeters: 150,
        weatherSnapshotVersion: 'w1',
        updatedAt: Date.now()
      });

      expect(updated.currentNodeId).assertEqual('node_1');
      expect(updated.completedNodeIds.length).assertEqual(1);
      expect(bundle.eventBus.publishedLocations >= 1).assertEqual(true);
    });

    it('boundary: get_recent_transitions_should_return_all_when_limit_non_positive', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_recent_boundary';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      const all = bundle.machine.getRecentTransitions(planId, 0);
      expect(all.length).assertEqual(2);
    });

    it('invalid: transition_plan_status_should_fail_for_disallowed_transition_and_record_metric', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_transition_invalid';
      bundle.machine.confirmPlan(planId);
      const result = bundle.machine.transitionPlanStatus({
        planId: planId,
        targetStatus: PlanStatus.IN_PROGRESS,
        expectedFromStatus: PlanStatus.READY,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'bad_expected'
      });
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('STATUS_CONFLICT');
      expect(bundle.metrics.bumpCount >= 2).assertEqual(true);
    });

    it('normal: wrapper_methods_should_drive_status_chain', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_wrapper_normal';
      expect(bundle.machine.confirmPlan(planId).toStatus).assertEqual(PlanStatus.CONFIRMED);
      expect(bundle.machine.prepareExecution(planId, TransitionTriggerSource.USER_ACTION).toStatus).assertEqual(PlanStatus.READY);
      expect(bundle.machine.startExecution(planId, TransitionTriggerSource.USER_ACTION).toStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(bundle.machine.pauseExecution(planId).toStatus).assertEqual(PlanStatus.PAUSED);
      expect(bundle.machine.resumeExecution(planId).toStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(bundle.machine.completeExecution(planId).toStatus).assertEqual(PlanStatus.COMPLETED);
      expect(bundle.machine.cancelPlan('psm_cancel_normal').toStatus).assertEqual(PlanStatus.CANCELLED);
    });

    it('boundary: evaluate_and_apply_should_return_null_when_evaluator_has_no_transition', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_eval_boundary';
      bundle.machine.confirmPlan(planId);
      const now = Date.now();
      const result = bundle.machine.evaluateAndApply(buildInput({
        planId: planId,
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        firstNodeStartTime: now + 4 * 60 * 60 * 1000,
        motionDetected: false,
        hasReachedFirstNode: false,
        allNodesCompleted: false,
        isPlanExpired: false
      }));
      expect(result === null).assertEqual(true);
    });

    it('invalid: evaluate_and_apply_should_block_ready_jitter_and_count_metric', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_eval_invalid';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      const now = Date.now();
      const result = bundle.machine.evaluateAndApply(buildInput({
        planId: planId,
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now + 5 * 60 * 1000,
        motionDetected: true,
        lastTransitionAt: now - 1000
      }));
      expect(result === null).assertEqual(true);
      expect(bundle.metrics.lastReason).assertEqual('ready_min_stay_blocked');
    });

    it('normal: evaluate_weather_refresh_and_replan_entry_should_delegate', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_delegate_normal';
      bundle.machine.confirmPlan(planId);
      const weather = bundle.machine.evaluateWeatherRefresh(planId);
      const soft = bundle.machine.requestSoftReplan({
        planId: planId,
        reason: 'rain',
        preserveCompletedNodes: true,
        preserveStartedWindow: true,
        useWeatherConstraint: true
      });
      const full = bundle.machine.requestFullReplan({
        planId: planId,
        reason: 'rewrite',
        triggeredBy: 'tester',
        useWeatherConstraint: false
      });
      expect(weather.shouldRefresh).assertEqual(true);
      expect(soft.reasonCode ?? '').assertEqual('soft_stub');
      expect(full.reasonCode ?? '').assertEqual('full_stub');
    });

    it('boundary: get_plan_stage_view_model_should_match_status_flags', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_stage_boundary';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      const vm = bundle.machine.getPlanStageViewModel(planId);
      expect(vm.status).assertEqual(PlanStatus.READY);
      expect(vm.canStart).assertEqual(true);
      expect(vm.canPause).assertEqual(false);
      expect(vm.canResume).assertEqual(false);
      expect(vm.canReplan).assertEqual(true);
      expect(vm.weatherMode).assertEqual('CURRENT_AND_PLAN');
    });

    it('invalid: build_evaluation_input_should_mark_location_permission_false_when_coords_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_input_invalid';
      const input = bundle.machine.buildEvaluationInput(planId, [], Date.now());
      expect(input.locationPermissionGranted).assertEqual(false);
      expect(input.motionDetected).assertEqual(false);
      expect(input.allNodesCompleted).assertEqual(false);
    });

    it('normal: subscribe_plan_transition_should_receive_emitted_event', 0, () => {
      // Arrange
      // Act
      // Assert
      const machine = PlanStateMachine.getInstance();
      const planId = `psm_subscribe_${Date.now()}`;
      let called = false;
      const off = machine.subscribePlanTransition(planId, (event: PlanTransitionEvent) => {
        called = true;
        expect(event.planId).assertEqual(planId);
      });
      machine.confirmPlan(planId);
      off();
      expect(called).assertEqual(true);
    });

    it('normal: mark_recovery_should_record_metrics', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_recovery_normal';
      bundle.machine.markRecovery(planId, true, 'recover_ok');
      bundle.machine.markRecovery(planId, false, 'recover_fail');
      expect(bundle.metrics.bumpCount >= 4).assertEqual(true);
    });

    it('boundary: get_plan_status_should_create_default_context_when_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const bundle = createMachineBundle();
      const planId = 'psm_status_boundary';
      const status = bundle.machine.getPlanStatus(planId);
      const ctx = bundle.machine.getExecutionContext(planId);
      expect(status.status).assertEqual(PlanStatus.DRAFT);
      expect(ctx?.planId ?? '').assertEqual(planId);
      expect((ctx?.autoTransitionStats as AutoTransitionStats).readyAttempt).assertEqual(0);
    });

    it('conflict: transition_plan_status_should_reject_conflicting_expected_status_after_ready', 0, () => {
      // Arrange
      // Act
      // Assert
      // Arrange
      const bundle = createMachineBundle();
      const planId = 'psm_conflict_case';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.USER_ACTION);
      // Act
      const result = bundle.machine.transitionPlanStatus({
        planId: planId,
        targetStatus: PlanStatus.IN_PROGRESS,
        expectedFromStatus: PlanStatus.CONFIRMED,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'conflict_case'
      });
      // Assert
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('STATUS_CONFLICT');
    });

    it('regression: get_plan_stage_view_model_should_keep_replan_enabled_for_ready_status', 0, () => {
      // Arrange
      // Act
      // Assert
      // Arrange
      const bundle = createMachineBundle();
      const planId = 'psm_regression_stage';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      // Act
      const vm = bundle.machine.getPlanStageViewModel(planId);
      // Assert
      expect(vm.status).assertEqual(PlanStatus.READY);
      expect(vm.canReplan).assertEqual(true);
    });

    it('combined: evaluate_weather_refresh_and_mark_recovery_should_update_outputs', 0, () => {
      // Arrange
      // Act
      // Assert
      // Arrange
      const bundle = createMachineBundle();
      const planId = 'psm_combined_case';
      bundle.machine.confirmPlan(planId);
      // Act
      const weather = bundle.machine.evaluateWeatherRefresh(planId);
      bundle.machine.markRecovery(planId, true, 'combined_recover');
      // Assert
      expect(weather.shouldRefresh).assertEqual(true);
      expect(bundle.metrics.bumpCount >= 2).assertEqual(true);
    });
  });
}
