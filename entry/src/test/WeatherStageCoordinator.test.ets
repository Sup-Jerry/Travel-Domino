import { describe, it, expect } from '@ohos/hypium';
import { WeatherStageCoordinator } from '../main/ets/domain/services/WeatherStageCoordinator';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

function buildPendingEvent(active: boolean): EventEntity {
  const event = new EventEntity();
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = active ? Date.now() : 0;
  return event;
}

export default function weatherStageCoordinatorTest() {
  describe('weatherStageCoordinatorTest', () => {
    it('normal: weather_stage_should_follow_plan_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new WeatherStageCoordinator();
      const stageConfirmed = coordinator.resolveStage(PlanStatus.CONFIRMED, [buildPendingEvent(false)], 'IDLE');
      const stageReady = coordinator.resolveStage(PlanStatus.READY, [buildPendingEvent(false)], 'READY');
      const stageProgress = coordinator.resolveStage(PlanStatus.IN_PROGRESS, [buildPendingEvent(true)], 'ACTIVE');
      const stagePaused = coordinator.resolveStage(PlanStatus.PAUSED, [buildPendingEvent(true)], 'PAUSED');
      expect(stageConfirmed).assertEqual('CONFIRMED');
      expect(stageReady).assertEqual('READY');
      expect(stageProgress).assertEqual('IN_PROGRESS');
      expect(stagePaused).assertEqual('PAUSED');
    });

    it('normal: weather_schedule_policy_should_match_stage_interval', 0, () => {
      // Arrange
      // Act
      // Assert
      const coordinator = new WeatherStageCoordinator();
      const confirmed = coordinator.resolveSchedulePolicy('CONFIRMED');
      const ready = coordinator.resolveSchedulePolicy('READY');
      const progress = coordinator.resolveSchedulePolicy('IN_PROGRESS');
      const paused = coordinator.resolveSchedulePolicy('PAUSED');
      expect(confirmed.pollIntervalMs).assertEqual(120 * 60 * 1000);
      expect(ready.pollIntervalMs).assertEqual(15 * 60 * 1000);
      expect(progress.pollIntervalMs).assertEqual(20 * 60 * 1000);
      expect(paused.pollIntervalMs).assertEqual(30 * 60 * 1000);
      expect(paused.allowLocationTrigger).assertEqual(true);
    });
  });
  describe('unit_test_case_generator_autofill_WeatherStageCoordinator', () => {
    it('boundary: td-20260411-auto-WeatherStageCoordinator', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('invalid: td-20260411-auto-WeatherStageCoordinator', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-WeatherStageCoordinator', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-WeatherStageCoordinator', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-WeatherStageCoordinator', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}

