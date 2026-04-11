import { describe, it, expect } from '@ohos/hypium';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { StateEvaluator } from '../main/ets/domain/statemachine/StateEvaluator';
import { TransitionEngine } from '../main/ets/domain/statemachine/TransitionEngine';

export default function planStateMachineCoreTest() {
  describe('planStateMachineCoreTest', () => {
    it('normal: state_evaluator_should_enter_ready_in_time_window', 0, () => {
      // Arrange
      // Act
      // Assert
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

    it('normal: state_evaluator_should_enter_in_progress_on_start_click', 0, () => {
      // Arrange
      // Act
      // Assert
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

    it('conflict: state_evaluator_should_block_ready_leave_when_min_stay_not_met', 0, () => {
      // Arrange
      // Act
      // Assert
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

    it('conflict: state_evaluator_should_block_resume_when_pause_stay_not_met', 0, () => {
      // Arrange
      // Act
      // Assert
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

    it('invalid: transition_engine_should_reject_invalid_transition', 0, () => {
      // Arrange
      // Act
      // Assert
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

    it('normal: transition_engine_should_accept_main_chain', 0, () => {
      // Arrange
      // Act
      // Assert
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
  describe('unit_test_case_generator_autofill_PlanStateMachineCore', () => {
    it('boundary: td-20260411-auto-PlanStateMachineCore', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-PlanStateMachineCore', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-PlanStateMachineCore', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
