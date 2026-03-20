import { describe, it, expect } from '@ohos/hypium';
import { NotificationBridge } from '../main/ets/domain/statemachine/NotificationBridge';
import { ReplanCoordinator } from '../main/ets/domain/statemachine/ReplanCoordinator';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanWeatherRefreshPlanner } from '../main/ets/domain/statemachine/WeatherRefreshScheduler';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';

export default function planStateMachineLinkTest() {
  describe('planStateMachineLinkTest', () => {
    it('soft_replan_should_fail_for_confirmed_status', 0, () => {
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

    it('soft_replan_should_return_reason_and_start_from_event', 0, () => {
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

    it('recovery_metrics_should_count_attempt_and_result', 0, () => {
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

    it('diagnostics_snapshot_should_include_metrics_and_transitions', 0, () => {
      const machine = PlanStateMachine.getInstance();
      const planId = `diag_${Date.now()}`;
      machine.confirmPlan(planId);
      const snapshot = machine.exportDiagnosticsSnapshot(planId);
      expect(snapshot.planId).assertEqual(planId);
      expect(snapshot.metrics.planId).assertEqual(planId);
      expect(snapshot.transitions.length >= 1).assertEqual(true);
    });

    it('scheduler_should_trigger_refresh_when_due', 0, () => {
      const scheduler = new PlanWeatherRefreshPlanner();
      const now = Date.now();
      scheduler.onStatusEntered('p1', PlanStatus.READY, now);
      const early = scheduler.evaluate('p1', PlanStatus.READY, now + 5 * 60 * 1000);
      const due = scheduler.evaluate('p1', PlanStatus.READY, now + 16 * 60 * 1000);
      expect(early.shouldRefresh).assertEqual(false);
      expect(due.shouldRefresh).assertEqual(true);
    });

    it('notification_bridge_should_accept_ready_event', 0, () => {
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

    it('weather_side_effect_failure_should_not_break_transition', 0, () => {
      const machine = PlanStateMachine.getInstance({
        weatherRefreshPlanner: {
          onStatusEntered: (_planId: string, _status: PlanStatus, _timestamp: number): void => {
            throw new Error('weather_failed');
          },
          evaluate: (_planId: string, _status: PlanStatus, _now: number) => {
            return { shouldRefresh: false, reason: 'none', nextDueAt: 0 };
          }
        } as unknown as PlanWeatherRefreshPlanner
      });
      const planId = `weather_fail_${Date.now()}`;
      const result = machine.confirmPlan(planId);
      expect(result.success).assertEqual(true);
      expect(result.toStatus).assertEqual(PlanStatus.CONFIRMED);
      const status = machine.getPlanStatus(planId).status;
      expect(status).assertEqual(PlanStatus.CONFIRMED);
    });
  });
}
