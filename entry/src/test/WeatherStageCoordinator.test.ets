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
  describe('unit_test_case_generator_backfill_WeatherStageCoordinator', () => {
    it('boundary: planning_stage_policy_should_disable_polling_and_location_trigger', 0, () => {
      // Arrange
      const coordinator = new WeatherStageCoordinator();
      // Act
      const policy = coordinator.resolveSchedulePolicy('PLANNING');
      // Assert
      expect(policy.pollIntervalMs).assertEqual(0);
      expect(policy.allowLocationTrigger).assertEqual(false);
      expect(policy.forceRefreshOnEnter).assertEqual(false);
    });

    it('invalid: stage_should_fallback_to_planning_when_status_not_in_execution_flow_and_no_schedule', 0, () => {
      // Arrange
      const coordinator = new WeatherStageCoordinator();
      // Act
      const stage = coordinator.resolveStage(PlanStatus.DRAFT, []);
      // Assert
      expect(stage).assertEqual('PLANNING');
    });

    it('conflict: paused_runtime_should_override_in_progress_event_detection', 0, () => {
      // Arrange
      const coordinator = new WeatherStageCoordinator();
      const events = [buildPendingEvent(true)];
      // Act
      const stage = coordinator.resolveStage(PlanStatus.DRAFT, events, 'PAUSED');
      // Assert
      expect(stage).assertEqual('PAUSED');
    });

    it('regression: td-20260411-confirmed_policy_should_force_refresh_on_enter', 0, () => {
      // Arrange
      const coordinator = new WeatherStageCoordinator();
      // Act
      const policy = coordinator.resolveSchedulePolicy('CONFIRMED');
      // Assert
      expect(policy.forceRefreshOnEnter).assertEqual(true);
      expect(policy.allowManualBypass).assertEqual(true);
    });

    it('combined: ready_stage_should_keep_short_interval_with_location_trigger', 0, () => {
      // Arrange
      const coordinator = new WeatherStageCoordinator();
      // Act
      const stage = coordinator.resolveStage(PlanStatus.READY, [buildPendingEvent(false)], 'READY');
      const policy = coordinator.resolveSchedulePolicy(stage);
      // Assert
      expect(stage).assertEqual('READY');
      expect(policy.pollIntervalMs).assertEqual(15 * 60 * 1000);
      expect(policy.allowLocationTrigger).assertEqual(true);
      expect(policy.forceRefreshOnEnter).assertEqual(true);
    });
  });
}

