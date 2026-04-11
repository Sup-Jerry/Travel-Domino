import { describe, it, expect } from '@ohos/hypium';
import { NotificationBridge } from '../main/ets/domain/statemachine/NotificationBridge';
import { ReplanCoordinator } from '../main/ets/domain/statemachine/ReplanCoordinator';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanWeatherRefreshPlanner, PlanWeatherScheduleDecision } from '../main/ets/domain/statemachine/WeatherRefreshScheduler';
import { PlanStateMachine, PlanStateMachineDeps } from '../main/ets/domain/statemachine/PlanStateMachine';
import { LocationChangeEvent } from '../main/ets/domain/statemachine/StateEventBus';

class ThrowingWeatherPlanner extends PlanWeatherRefreshPlanner {
  public onStatusEntered(_planId: string, _status: PlanStatus, _timestamp: number): PlanWeatherScheduleDecision {
    throw new Error('weather_failed');
  }

  public evaluate(_planId: string, _status: PlanStatus, _now: number): PlanWeatherScheduleDecision {
    return { shouldRefresh: false };
  }
}

export default function planStateMachineLinkTest() {
  describe('planStateMachineLinkTest', () => {
    it('invalid: soft_replan_should_fail_for_confirmed_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const result = coordinator.requestSoftReplan({
        planId: 'x1',
        reason: 'rain',
        preserveCompletedNodes: true,
        preserveStartedWindow: true,
        useWeatherConstraint: true
      }, {
        planId: 'x1',
        status: PlanStatus.CONFIRMED,
        plannedStartTime: Date.now(),
        plannedEndTime: Date.now() + 1000,
        completedNodeIds: [],
        skippedNodeIds: [],
        isAutoStarted: false,
        isPaused: false,
        updatedAt: Date.now()
      });
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
    });

    it('normal: soft_replan_should_return_reason_and_start_from_event', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new ReplanCoordinator();
      const result = coordinator.requestSoftReplan({
        planId: 'x2',
        reason: 'rain',
        currentNodeId: '1001',
        preserveCompletedNodes: true,
        preserveStartedWindow: true,
        useWeatherConstraint: true
      }, {
        planId: 'x2',
        status: PlanStatus.IN_PROGRESS,
        plannedStartTime: Date.now(),
        plannedEndTime: Date.now() + 1000,
        currentNodeId: '1001',
        completedNodeIds: [],
        skippedNodeIds: [],
        isAutoStarted: false,
        isPaused: false,
        updatedAt: Date.now()
      });
      expect(result.success).assertEqual(true);
      expect(result.reasonCode).assertEqual('weather_soft_replan');
      expect(result.startFromEventId).assertEqual(1001);
      expect((result.changeSummary ?? []).length > 0).assertEqual(true);
      expect(result.changeSummary ? result.changeSummary[0].type : 'NO_OP').assertEqual('NO_OP');
    });

    it('normal: recovery_metrics_should_count_attempt_and_result', 0, () => {
      // Arrange
      // Act
      // Assert
      const machine = PlanStateMachine.getInstance();
      const planId = `recover_${Date.now()}`;
      machine.markRecovery(planId, false, 'context_missing');
      machine.markRecovery(planId, true, 'context_restored');
      machine.markRecovery(planId, false, 'context_expired');
      const metrics = machine.getDailyMetrics(planId);
      const counters = metrics.counters;
      expect((counters['recovery_attempt'] ?? 0) >= 3).assertEqual(true);
      expect((counters['recovery_success'] ?? 0) >= 1).assertEqual(true);
      expect((counters['recovery_fail'] ?? 0) >= 2).assertEqual(true);
      expect((metrics.reasons['context_missing'] ?? 0) >= 1).assertEqual(true);
      expect((metrics.reasons['context_restored'] ?? 0) >= 1).assertEqual(true);
      expect((metrics.reasons['context_expired'] ?? 0) >= 1).assertEqual(true);
    });

    it('normal: diagnostics_snapshot_should_include_metrics_and_transitions', 0, () => {
      // Arrange
      // Act
      // Assert
      const machine = PlanStateMachine.getInstance();
      const planId = `diag_${Date.now()}`;
      machine.confirmPlan(planId);
      const snapshot = machine.exportDiagnosticsSnapshot(planId);
      expect(snapshot.planId).assertEqual(planId);
      expect(snapshot.metrics.planId).assertEqual(planId);
      expect(snapshot.transitions.length >= 1).assertEqual(true);
    });

    it('normal: scheduler_should_trigger_refresh_when_due', 0, () => {
      // Arrange
      // Act
      // Assert
      const scheduler = new PlanWeatherRefreshPlanner();
      const now = Date.now();
      scheduler.onStatusEntered('p1', PlanStatus.READY, now);
      const early = scheduler.evaluate('p1', PlanStatus.READY, now + 5 * 60 * 1000);
      const due = scheduler.evaluate('p1', PlanStatus.READY, now + 16 * 60 * 1000);
      expect(early.shouldRefresh).assertEqual(false);
      expect(due.shouldRefresh).assertEqual(true);
    });

    it('normal: notification_bridge_should_accept_ready_event', 0, () => {
      // Arrange
      // Act
      // Assert
      const bridge = new NotificationBridge();
      bridge.handlePlanTransitionNotification({
        planId: '100',
        fromStatus: PlanStatus.CONFIRMED,
        toStatus: PlanStatus.READY,
        triggerSource: TransitionTriggerSource.TIME_WINDOW,
        triggerReason: 'enter_ready_window',
        timestamp: Date.now()
      });
      expect(true).assertEqual(true);
    });

    it('invalid: weather_side_effect_failure_should_not_break_transition', 0, () => {
      // Arrange
      // Act
      // Assert
      const deps: PlanStateMachineDeps = {
        weatherRefreshPlanner: new ThrowingWeatherPlanner()
      };
      const machine = PlanStateMachine.getInstance(deps);
      const planId = `weather_fail_${Date.now()}`;
      const result = machine.confirmPlan(planId);
      expect(result.success).assertEqual(true);
      expect(result.toStatus).assertEqual(PlanStatus.CONFIRMED);
      const status = machine.getPlanStatus(planId).status;
      expect(status).assertEqual(PlanStatus.CONFIRMED);
    });

    it('normal: location_change_should_publish_when_motion_pass_in_execution_stage', 0, () => {
      // Arrange
      // Act
      // Assert
      const machine = PlanStateMachine.getInstance();
      const planId = `location_trigger_${Date.now()}`;
      machine.confirmPlan(planId);
      machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      let called = false;
      const dispose = machine.subscribeLocationChange(planId, (event: LocationChangeEvent) => {
        called = true;
        expect(event.planId).assertEqual(planId);
        expect(event.distanceMeters >= 120).assertEqual(true);
      });
      machine.updateExecutionContext({
        planId: planId,
        lastKnownLatitude: 31.2304,
        lastKnownLongitude: 121.4737,
        distanceToFirstNodeMeters: 130,
        updatedAt: Date.now()
      });
      dispose();
      expect(called).assertEqual(true);
    });

    it('normal: location_change_should_not_publish_when_stage_not_execution', 0, () => {
      // Arrange
      // Act
      // Assert
      const machine = PlanStateMachine.getInstance();
      const planId = `location_block_${Date.now()}`;
      machine.confirmPlan(planId);
      let called = false;
      const dispose = machine.subscribeLocationChange(planId, (_event: LocationChangeEvent) => {
        called = true;
      });
      machine.updateExecutionContext({
        planId: planId,
        lastKnownLatitude: 31.2304,
        lastKnownLongitude: 121.4737,
        distanceToFirstNodeMeters: 180,
        updatedAt: Date.now()
      });
      dispose();
      expect(called).assertEqual(false);
    });
  });
  describe('unit_test_case_generator_backfill_PlanStateMachineLink', () => {
    it('boundary: weather_scheduler_should_disable_refresh_for_terminal_status', 0, () => {
      // Arrange
      const scheduler = new PlanWeatherRefreshPlanner();
      const now = Date.now();
      // Act
      const entered = scheduler.onStatusEntered('terminal_plan', PlanStatus.COMPLETED, now);
      const evaluated = scheduler.evaluate('terminal_plan', PlanStatus.COMPLETED, now + 60 * 1000);
      // Assert
      expect(entered.shouldRefresh).assertEqual(false);
      expect(evaluated.shouldRefresh).assertEqual(false);
      expect((evaluated.nextRefreshAt === undefined)).assertEqual(true);
    });

    it('conflict: transition_should_fail_when_expected_status_does_not_match_context', 0, () => {
      // Arrange
      const machine = PlanStateMachine.getInstance();
      const planId = `status_conflict_${Date.now()}`;
      machine.confirmPlan(planId);
      // Act
      const result = machine.transitionPlanStatus({
        planId: planId,
        expectedFromStatus: PlanStatus.DRAFT,
        targetStatus: PlanStatus.READY,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'force_ready_with_wrong_expected_status'
      });
      // Assert
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('STATUS_CONFLICT');
    });

    it('regression: td-20260411-location_change_should_not_emit_below_motion_threshold', 0, () => {
      // Arrange
      const machine = PlanStateMachine.getInstance();
      const planId = `location_threshold_${Date.now()}`;
      machine.confirmPlan(planId);
      machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      let called = false;
      const dispose = machine.subscribeLocationChange(planId, (_event: LocationChangeEvent) => {
        called = true;
      });
      // Act
      machine.updateExecutionContext({
        planId: planId,
        lastKnownLatitude: 31.2304,
        lastKnownLongitude: 121.4737,
        distanceToFirstNodeMeters: 119,
        updatedAt: Date.now()
      });
      dispose();
      // Assert
      expect(called).assertEqual(false);
    });

    it('combined: paused_plan_should_support_soft_replan_with_start_node_and_constraints', 0, () => {
      // Arrange
      const machine = PlanStateMachine.getInstance();
      const planId = `combined_replan_${Date.now()}`;
      machine.confirmPlan(planId);
      machine.startExecution(planId, TransitionTriggerSource.USER_ACTION);
      machine.pauseExecution(planId);
      // Act
      const result = machine.requestSoftReplan({
        planId: planId,
        reason: 'rain_and_delay',
        currentNodeId: '2001',
        preserveCompletedNodes: true,
        preserveStartedWindow: true,
        useWeatherConstraint: true
      });
      // Assert
      expect(result.success).assertEqual(true);
      expect(result.reasonCode).assertEqual('weather_soft_replan');
      expect(result.startFromEventId ?? 0).assertEqual(2001);
      expect(result.preserveCompletedNodes ?? false).assertEqual(true);
    });
  });
}
