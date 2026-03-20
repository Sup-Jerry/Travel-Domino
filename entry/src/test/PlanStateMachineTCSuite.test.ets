import { describe, it, expect } from '@ohos/hypium';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { StateEvaluator } from '../main/ets/domain/statemachine/StateEvaluator';
import { TransitionEngine } from '../main/ets/domain/statemachine/TransitionEngine';
import { WeatherPolicyResolver, WeatherTargetType } from '../main/ets/domain/statemachine/WeatherPolicyResolver';

function nowMs(): number {
  return Date.now();
}

export default function planStateMachineTCSuiteTest() {
  describe('planStateMachineTCSuiteTest', () => {
    it('TC-SM-001_confirm_plan_should_enter_confirmed', 0, () => {
      const machine = PlanStateMachine.getInstance();
      const planId = `tc_sm_001_${nowMs()}`;
      const result = machine.confirmPlan(planId);
      expect(result.success).assertEqual(true);
      expect(result.toStatus).assertEqual(PlanStatus.CONFIRMED);
      const transitions = machine.getRecentTransitions(planId, 5);
      expect(transitions.length >= 1).assertEqual(true);
      expect(transitions[transitions.length - 1].toStatus).assertEqual(PlanStatus.CONFIRMED);
    });

    it('TC-SM-003_004_005_start_pause_resume_should_work', 0, () => {
      const machine = PlanStateMachine.getInstance();
      const planId = `tc_sm_345_${nowMs()}`;
      machine.confirmPlan(planId);
      const start = machine.startExecution(planId, TransitionTriggerSource.USER_ACTION);
      expect(start.success).assertEqual(true);
      expect(start.toStatus).assertEqual(PlanStatus.IN_PROGRESS);
      const pause = machine.pauseExecution(planId);
      expect(pause.success).assertEqual(true);
      expect(pause.toStatus).assertEqual(PlanStatus.PAUSED);
      const resume = machine.resumeExecution(planId);
      expect(resume.success).assertEqual(true);
      expect(resume.toStatus).assertEqual(PlanStatus.IN_PROGRESS);
    });

    it('TC-SM-006_complete_execution_should_enter_completed', 0, () => {
      const machine = PlanStateMachine.getInstance();
      const planId = `tc_sm_006_${nowMs()}`;
      machine.confirmPlan(planId);
      machine.startExecution(planId, TransitionTriggerSource.USER_ACTION);
      const complete = machine.completeExecution(planId);
      expect(complete.success).assertEqual(true);
      expect(complete.toStatus).assertEqual(PlanStatus.COMPLETED);
    });

    it('TC-SM-007_expired_should_be_suggested_when_confirmed_and_timeout', 0, () => {
      const evaluator = new StateEvaluator();
      const now = nowMs();
      const result = evaluator.evaluateNextStatus({
        planId: `tc_sm_007_${now}`,
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        locationPermissionGranted: false,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: true
      });
      expect(result.suggestedStatus).assertEqual(PlanStatus.EXPIRED);
      expect(result.shouldTransition).assertEqual(true);
    });

    it('TC-SM-008_cancel_plan_should_enter_cancelled', 0, () => {
      const machine = PlanStateMachine.getInstance();
      const planId = `tc_sm_008_${nowMs()}`;
      machine.confirmPlan(planId);
      const cancelled = machine.cancelPlan(planId);
      expect(cancelled.success).assertEqual(true);
      expect(cancelled.toStatus).assertEqual(PlanStatus.CANCELLED);
    });

    it('TC-AUTO-003_004_motion_and_window_conditions_should_match', 0, () => {
      const evaluator = new StateEvaluator();
      const now = nowMs();
      const hit = evaluator.evaluateNextStatus({
        planId: `tc_auto_003_${now}`,
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now + 8 * 60 * 1000,
        locationPermissionGranted: true,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: true,
        allNodesCompleted: false,
        isPlanExpired: false,
        lastTransitionAt: now - 5 * 60 * 1000
      });
      expect(hit.suggestedStatus).assertEqual(PlanStatus.IN_PROGRESS);
      const keep = evaluator.evaluateNextStatus({
        planId: `tc_auto_004_${now}`,
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now + 90 * 60 * 1000,
        locationPermissionGranted: true,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: false,
        lastTransitionAt: now - 5 * 60 * 1000
      });
      expect(keep.suggestedStatus).assertEqual(PlanStatus.READY);
      expect(keep.shouldTransition).assertEqual(false);
    });

    it('TC-WEATHER-003_004_policy_should_match_in_progress_and_terminal', 0, () => {
      const resolver = new WeatherPolicyResolver();
      const inProgress = resolver.resolveWeatherFetchPolicy(PlanStatus.IN_PROGRESS);
      expect(inProgress.targets.includes(WeatherTargetType.CURRENT_LOCATION)).assertEqual(true);
      expect(inProgress.targets.includes(WeatherTargetType.UPCOMING_NODES)).assertEqual(true);
      const terminal = resolver.resolveWeatherFetchPolicy(PlanStatus.EXPIRED);
      expect(terminal.targets.length).assertEqual(0);
    });

    it('TC-ERR-001_location_missing_should_still_enter_ready_by_time', 0, () => {
      const evaluator = new StateEvaluator();
      const now = nowMs();
      const result = evaluator.evaluateNextStatus({
        planId: `tc_err_001_${now}`,
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        firstNodeStartTime: now + 10 * 60 * 1000,
        locationPermissionGranted: false,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: false
      });
      expect(result.suggestedStatus).assertEqual(PlanStatus.READY);
      expect(result.shouldTransition).assertEqual(true);
    });

    it('TC-ERR-004_repeat_start_should_be_idempotent', 0, () => {
      const engine = new TransitionEngine();
      const first = engine.transitionPlanStatus(PlanStatus.CONFIRMED, {
        planId: `tc_err_004_${nowMs()}`,
        targetStatus: PlanStatus.IN_PROGRESS,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'start_once'
      });
      expect(first.success).assertEqual(true);
      const second = engine.transitionPlanStatus(PlanStatus.IN_PROGRESS, {
        planId: `tc_err_004_${nowMs()}_2`,
        targetStatus: PlanStatus.IN_PROGRESS,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'start_twice'
      });
      expect(second.success).assertEqual(true);
      expect(second.event === undefined).assertEqual(true);
    });

    it('TC-RECOVER-002_confirmed_should_be_expired_after_timeout_on_recover_eval', 0, () => {
      const evaluator = new StateEvaluator();
      const now = nowMs();
      const result = evaluator.evaluateNextStatus({
        planId: `tc_recover_002_${now}`,
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        locationPermissionGranted: true,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: true
      });
      expect(result.suggestedStatus).assertEqual(PlanStatus.EXPIRED);
    });

    it('TC-LINK-001_003_ready_and_completed_transitions_should_exist', 0, () => {
      const machine = PlanStateMachine.getInstance();
      const planId = `tc_link_13_${nowMs()}`;
      machine.confirmPlan(planId);
      const ready = machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      expect(ready.success).assertEqual(true);
      expect(ready.toStatus).assertEqual(PlanStatus.READY);
      machine.startExecution(planId, TransitionTriggerSource.USER_ACTION);
      const completed = machine.completeExecution(planId);
      expect(completed.success).assertEqual(true);
      expect(completed.toStatus).assertEqual(PlanStatus.COMPLETED);
    });
  });
}
