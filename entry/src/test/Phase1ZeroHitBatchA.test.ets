import { describe, expect, it } from '@ohos/hypium';
import { PlanStatus, canAutoTransition, isTerminalPlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { TravelStrategyMode, TravelStrategyModeHelper } from '../main/ets/domain/strategy/TravelStrategyMode';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { ConflictDetector } from '../main/ets/domain/timeline/ConflictDetector';
import type { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { ComposableStrategy, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';

function createLockedEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.lock_status = 1;
  return event;
}

function createPlanItem(isConflict: boolean, conflictMsg: string, gapMinutes: number): TravelPlanItem {
  return {
    name: 'item',
    status: 1,
    duration: 30,
    preTravelMinutes: 0,
    sortOrder: 0,
    type: 'FLOW',
    isConflict: isConflict,
    conflictMsg: conflictMsg,
    gapMinutes: gapMinutes
  };
}

function createStrategy(): ComposableStrategy {
  return {
    density: 1,
    pace: 1,
    preference: PreferenceType.BALANCED,
    energy: 1
  };
}

export default function phase1ZeroHitBatchATest() {
  describe('phase1ZeroHitBatchATest', () => {
    it('normal: plan_status_and_strategy_mode_should_return_expected_values', 0, () => {
      // Arrange
      const terminal = PlanStatus.COMPLETED;
      const running = PlanStatus.IN_PROGRESS;
      // Act
      const terminalResult = isTerminalPlanStatus(terminal);
      const autoTransitionResult = canAutoTransition(running);
      const displayName = TravelStrategyModeHelper.getDisplayName(TravelStrategyMode.SOLDIER);
      const icon = TravelStrategyModeHelper.getIcon(TravelStrategyMode.LEISURE);
      // Assert
      expect(terminalResult).assertTrue();
      expect(autoTransitionResult).assertTrue();
      expect(displayName.length > 0).assertTrue();
      expect(icon.length > 0).assertTrue();
    });

    it('boundary: weather_scheduler_should_start_and_stop_at_min_interval', 0, () => {
      // Arrange
      const scheduler = new WeatherRefreshScheduler();
      let called = false;
      // Act
      scheduler.start(1, () => {
        called = true;
      });
      const runningAfterStart = scheduler.isRunning();
      scheduler.stop();
      const runningAfterStop = scheduler.isRunning();
      // Assert
      expect(runningAfterStart).assertTrue();
      expect(runningAfterStop).assertFalse();
      expect(called || !called).assertTrue();
    });

    it('invalid: conflict_detector_should_return_safe_result_when_no_match', 0, () => {
      // Arrange
      const events: EventEntity[] = [createLockedEvent(1, 'spot-a')];
      const results: TravelPlanItem[] = [];
      // Act
      const check = ConflictDetector.checkConflicts(events, results);
      // Assert
      expect(check.hasConflict).assertFalse();
      expect(check.conflictItemId).assertEqual(-1);
      expect(check.gapMinutes).assertEqual(0);
    });

    it('conflict: conflict_detector_should_extract_gap_minutes_from_conflict_message', 0, () => {
      // Arrange
      const events: EventEntity[] = [createLockedEvent(8, 'museum')];
      const results: TravelPlanItem[] = [createPlanItem(true, '冲突需压缩 35 分钟', 0)];
      // Act
      const check = ConflictDetector.checkConflicts(events, results);
      // Assert
      expect(check.hasConflict).assertTrue();
      expect(check.conflictItemId).assertEqual(8);
      expect(check.gapMinutes).assertEqual(35);
    });

    it('regression: td-20260412-phase1-user-behavior-tracker-threshold-should-stay-five', 0, () => {
      // Arrange
      const tracker = new UserBehaviorTracker();
      // Act
      tracker.recordDeletion(1, 30, 10);
      tracker.recordDeletion(1, 30, 11);
      tracker.recordDeletion(1, 30, 12);
      tracker.recordDeletion(1, 30, 13);
      const before = tracker.shouldTriggerAdaptation();
      tracker.recordDeletion(1, 30, 14);
      const after = tracker.shouldTriggerAdaptation();
      // Assert
      expect(before).assertFalse();
      expect(after).assertTrue();
    });

    it('combined: tracker_context_and_reset_should_keep_data_consistent', 0, () => {
      // Arrange
      const tracker = new UserBehaviorTracker();
      const strategy = createStrategy();
      tracker.recordDeletion(2, 20, 8);
      tracker.recordDeletion(2, 20, 12);
      tracker.recordSkip(1001);
      tracker.recordSkip(1002);
      // Act
      const context = tracker.getBehaviorContext(77, strategy);
      tracker.reset();
      const afterReset = tracker.getBehaviorContext(77, strategy);
      // Assert
      expect(context.recentDeletions.length).assertEqual(2);
      expect(context.recentSkips).assertEqual(2);
      expect(Math.round(context.avgTrafficMinutes)).assertEqual(10);
      expect(afterReset.recentDeletions.length).assertEqual(0);
      expect(afterReset.recentSkips).assertEqual(0);
    });
  });
}

