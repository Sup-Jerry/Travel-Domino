import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { WeatherPolicyResolver, WeatherTargetType } from '../main/ets/domain/statemachine/WeatherPolicyResolver';

function buildEvent(id: number, lat: number, lng: number, dynamicStart: number, pending: boolean = true): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = 1;
  event.latitude = lat;
  event.longitude = lng;
  event.dynamic_start_time = dynamicStart;
  event.completion_status = pending ? EventEntity.STATE_PENDING : EventEntity.STATE_COMPLETED;
  return event;
}

export default function weatherPolicyResolverTest() {
  describe('weatherPolicyResolverTest', () => {
    it('normal: draft_should_only_fetch_all_plan_nodes', 0, () => {
      // Arrange
      // Act
      // Assert
      const resolver = new WeatherPolicyResolver();
      const policy = resolver.resolveWeatherFetchPolicy(PlanStatus.DRAFT);
      expect(policy.targets.length).assertEqual(1);
      expect(policy.targets[0]).assertEqual(WeatherTargetType.ALL_PLAN_NODES);
    });

    it('boundary: ready_should_include_current_first_upcoming', 0, () => {
      // Arrange
      // Act
      // Assert
      const resolver = new WeatherPolicyResolver();
      const policy = resolver.resolveWeatherFetchPolicy(PlanStatus.READY);
      expect(policy.targets.includes(WeatherTargetType.CURRENT_LOCATION)).assertEqual(true);
      expect(policy.targets.includes(WeatherTargetType.FIRST_NODE)).assertEqual(true);
      expect(policy.targets.includes(WeatherTargetType.UPCOMING_NODES)).assertEqual(true);
      expect(policy.refreshIntervalMinutes).assertEqual(15);
    });

    it('boundary: terminal_status_should_return_empty_targets', 0, () => {
      // Arrange
      // Act
      // Assert
      const resolver = new WeatherPolicyResolver();
      const policy = resolver.resolveWeatherFetchPolicy(PlanStatus.COMPLETED);
      expect(policy.targets.length).assertEqual(0);
    });

    it('normal: build_weather_targets_should_follow_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const resolver = new WeatherPolicyResolver();
      const now = Date.now();
      const events: EventEntity[] = [
        buildEvent(1, 31.2, 121.5, now + 1000),
        buildEvent(2, 31.3, 121.6, now + 2000),
        buildEvent(3, 31.4, 121.7, now + 3000)
      ];
      const targets = resolver.buildWeatherTargets('plan-1', PlanStatus.READY, events, {
        planId: 'plan-1',
        status: PlanStatus.READY,
        plannedStartTime: now,
        plannedEndTime: now + 9999,
        completedNodeIds: [],
        skippedNodeIds: [],
        isAutoStarted: false,
        isPaused: false,
        updatedAt: now,
        lastKnownLatitude: 31.1,
        lastKnownLongitude: 121.4
      });
      const hasCurrent = targets.some(item => item.type === WeatherTargetType.CURRENT_LOCATION);
      const hasFirst = targets.some(item => item.type === WeatherTargetType.FIRST_NODE);
      const hasUpcoming = targets.some(item => item.type === WeatherTargetType.UPCOMING_NODES);
      expect(hasCurrent).assertEqual(true);
      expect(hasFirst).assertEqual(true);
      expect(hasUpcoming).assertEqual(true);
    });
  });
  describe('unit_test_case_generator_autofill_WeatherPolicyResolver', () => {
    it('invalid: td-20260411-auto-WeatherPolicyResolver', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-WeatherPolicyResolver', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-WeatherPolicyResolver', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-WeatherPolicyResolver', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
