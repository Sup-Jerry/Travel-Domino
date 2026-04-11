import { describe, it, expect } from '@ohos/hypium';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { StateEvaluator } from '../main/ets/domain/statemachine/StateEvaluator';
import { TransitionEngine } from '../main/ets/domain/statemachine/TransitionEngine';
import { StateEvaluationInput } from '../main/ets/domain/statemachine/ExecutionContext';

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
  describe('unit_test_case_generator_backfill_PlanStateMachineCore', () => {
    it('boundary: should_enter_ready_at_window_start_but_not_before', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const firstNodeStart = Date.now() + 60 * 60 * 1000;
      const atWindowInput: StateEvaluationInput = {
        planId: 'p-boundary',
        currentStatus: PlanStatus.CONFIRMED,
        now: firstNodeStart - 30 * 60 * 1000,
        firstNodeStartTime: firstNodeStart,
        locationPermissionGranted: false,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: false
      };
      const beforeWindowInput: StateEvaluationInput = {
        planId: 'p-boundary',
        currentStatus: PlanStatus.CONFIRMED,
        now: firstNodeStart - 30 * 60 * 1000 - 1,
        firstNodeStartTime: firstNodeStart,
        locationPermissionGranted: false,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: false,
        hasReachedFirstNode: false,
        motionDetected: false,
        allNodesCompleted: false,
        isPlanExpired: false
      };
      // Act
      const atWindowStart = evaluator.shouldEnterReady(atWindowInput);
      const beforeWindow = evaluator.shouldEnterReady(beforeWindowInput);
      // Assert
      expect(atWindowStart).assertEqual(true);
      expect(beforeWindow).assertEqual(false);
    });

    it('regression: td-20260411-transition_engine_should_report_status_conflict_before_transition_table', 0, () => {
      // Arrange
      const engine = new TransitionEngine();
      // Act
      const result = engine.transitionPlanStatus(PlanStatus.READY, {
        planId: 'p-regression',
        expectedFromStatus: PlanStatus.CONFIRMED,
        targetStatus: PlanStatus.IN_PROGRESS,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: 'force_start'
      });
      // Assert
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('STATUS_CONFLICT');
    });

    it('combined: cancel_should_take_precedence_when_cancel_and_complete_happen_together', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const now = Date.now();
      // Act
      const result = evaluator.evaluateNextStatus({
        planId: 'p-combined',
        currentStatus: PlanStatus.IN_PROGRESS,
        now: now,
        firstNodeStartTime: now - 60 * 1000,
        locationPermissionGranted: true,
        userClickedStart: false,
        userClickedPause: false,
        userClickedResume: false,
        userClickedCancel: true,
        hasReachedFirstNode: true,
        motionDetected: true,
        allNodesCompleted: true,
        isPlanExpired: false
      });
      // Assert
      expect(result.shouldTransition).assertEqual(true);
      expect(result.suggestedStatus).assertEqual(PlanStatus.CANCELLED);
      expect(result.triggerSource).assertEqual(TransitionTriggerSource.USER_ACTION);
    });
  });
}
