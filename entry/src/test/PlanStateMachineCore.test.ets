import { describe, it, expect } from '@ohos/hypium';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { StateEvaluator } from '../main/ets/domain/statemachine/StateEvaluator';
import { TransitionEngine } from '../main/ets/domain/statemachine/TransitionEngine';

export default function planStateMachineCoreTest() {
  describe('planStateMachineCoreTest', () => {
    it('state_evaluator_should_enter_ready_in_time_window', 0, () => {
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const result = evaluator.evaluateNextStatus({
        planId: 'p1',
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
      expect(result.triggerSource).assertEqual(TransitionTriggerSource.TIME_WINDOW);
    });

    it('state_evaluator_should_enter_in_progress_on_start_click', 0, () => {
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const result = evaluator.evaluateNextStatus({
        planId: 'p2',
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now + 10 * 60 * 1000,
        locationPermissionGranted: true,
        userClickedStart: true,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: false
      });
      expect(result.suggestedStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(result.shouldTransition).assertEqual(true);
    });

    it('state_evaluator_should_block_ready_leave_when_min_stay_not_met', 0, () => {
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const result = evaluator.evaluateNextStatus({
        planId: 'p2-1',
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now + 5 * 60 * 1000,
        locationPermissionGranted: true,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: true,
        allNodesCompleted: false,
        isPlanExpired: false,
        lastTransitionAt: now - 30 * 1000
      });
      expect(result.shouldTransition).assertEqual(false);
      expect(result.suggestedStatus).assertEqual(PlanStatus.READY);
    });

    it('state_evaluator_should_block_resume_when_pause_stay_not_met', 0, () => {
      const evaluator = new StateEvaluator();
      const now = Date.now();
      const result = evaluator.evaluateNextStatus({
        planId: 'p2-2',
        currentStatus: PlanStatus.PAUSED,
        now: now,
        locationPermissionGranted: true,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: true,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: false,
        lastTransitionAt: now - 5 * 1000
      });
      expect(result.shouldTransition).assertEqual(false);
      expect(result.suggestedStatus).assertEqual(PlanStatus.PAUSED);
    });

    it('transition_engine_should_reject_invalid_transition', 0, () => {
      const engine = new TransitionEngine();
      const result = engine.transitionPlanStatus(PlanStatus.COMPLETED, {
        planId: 'p3',
        targetStatus: PlanStatus.IN_PROGRESS,
        triggerSource: TransitionTriggerSource.MANUAL_OVERRIDE,
        triggerReason: 'bad'
      });
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('INVALID_TRANSITION');
    });

    it('transition_engine_should_accept_main_chain', 0, () => {
      const engine = new TransitionEngine();
      const result = engine.transitionPlanStatus(PlanStatus.CONFIRMED, {
        planId: 'p4',
        targetStatus: PlanStatus.READY,
        triggerSource: TransitionTriggerSource.TIME_WINDOW,
        triggerReason: 'enter_ready_window'
      });
      expect(result.success).assertEqual(true);
      expect(result.toStatus).assertEqual(PlanStatus.READY);
    });
  });
}
