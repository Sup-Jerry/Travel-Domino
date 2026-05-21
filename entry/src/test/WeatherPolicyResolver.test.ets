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

    it('boundary: confirmed_should_refresh_all_plan_nodes_every_120_minutes', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      // Act
      const policy = resolver.resolveWeatherFetchPolicy(PlanStatus.CONFIRMED);
      // Assert
      expect(policy.targets.length).assertEqual(1);
      expect(policy.targets[0]).assertEqual(WeatherTargetType.ALL_PLAN_NODES);
      expect(policy.refreshIntervalMinutes).assertEqual(120);
      expect(policy.forceRefreshOnEnter).assertEqual(true);
      expect(policy.allowCache).assertEqual(true);
    });

    it('boundary: paused_should_use_current_and_upcoming_without_force_refresh', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      // Act
      const policy = resolver.resolveWeatherFetchPolicy(PlanStatus.PAUSED);
      // Assert
      expect(policy.targets.includes(WeatherTargetType.CURRENT_LOCATION)).assertEqual(true);
      expect(policy.targets.includes(WeatherTargetType.UPCOMING_NODES)).assertEqual(true);
      expect(policy.targets.includes(WeatherTargetType.FIRST_NODE)).assertEqual(false);
      expect(policy.refreshIntervalMinutes).assertEqual(30);
      expect(policy.forceRefreshOnEnter).assertEqual(false);
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
  describe('unit_test_case_generator_backfill_WeatherPolicyResolver', () => {
    it('invalid: build_weather_targets_should_filter_out_invalid_geo_events', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      const now = Date.now();
      const events: EventEntity[] = [
        buildEvent(1, 0, 0, now + 1000),
        buildEvent(2, 91, 121.5, now + 2000),
        buildEvent(3, 31.2, 121.5, now + 3000)
      ];
      // Act
      const targets = resolver.buildWeatherTargets('p-invalid', PlanStatus.DRAFT, events);
      // Assert
      expect(targets.length).assertEqual(2);
      const nodeIds = targets.map((item) => item.nodeId ?? '');
      expect(nodeIds.includes('1')).assertEqual(false);
      expect(nodeIds.includes('2')).assertEqual(true);
      expect(nodeIds.includes('3')).assertEqual(true);
    });

    it('conflict: in_progress_policy_should_exclude_first_node_target_type', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      // Act
      const policy = resolver.resolveWeatherFetchPolicy(PlanStatus.IN_PROGRESS);
      // Assert
      expect(policy.targets.includes(WeatherTargetType.CURRENT_LOCATION)).assertEqual(true);
      expect(policy.targets.includes(WeatherTargetType.UPCOMING_NODES)).assertEqual(true);
      expect(policy.targets.includes(WeatherTargetType.FIRST_NODE)).assertEqual(false);
    });

    it('regression: td-20260411-current_location_should_not_emit_without_valid_runtime_geo', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      const now = Date.now();
      const events: EventEntity[] = [buildEvent(1, 31.2, 121.5, now + 1000)];
      // Act
      const targets = resolver.buildWeatherTargets('p-regression', PlanStatus.READY, events, {
        planId: 'p-regression',
        status: PlanStatus.READY,
        plannedStartTime: now,
        plannedEndTime: now + 60000,
        completedNodeIds: [],
        skippedNodeIds: [],
        isAutoStarted: false,
        isPaused: false,
        updatedAt: now,
        lastKnownLatitude: 0,
        lastKnownLongitude: 0
      });
      // Assert
      const hasCurrent = targets.some((item) => item.type === WeatherTargetType.CURRENT_LOCATION);
      expect(hasCurrent).assertEqual(false);
    });

    it('combined: ready_targets_should_include_current_and_upcoming_with_deduped_nodes', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      const now = Date.now();
      const events: EventEntity[] = [
        buildEvent(1, 31.2, 121.5, now + 1000),
        buildEvent(2, 31.2, 121.5, now + 2000),
        buildEvent(3, 31.3, 121.6, now + 3000)
      ];
      // Act
      const targets = resolver.buildWeatherTargets('p-combined', PlanStatus.READY, events, {
        planId: 'p-combined',
        status: PlanStatus.READY,
        plannedStartTime: now,
        plannedEndTime: now + 60000,
        completedNodeIds: [],
        skippedNodeIds: [],
        isAutoStarted: false,
        isPaused: false,
        updatedAt: now,
        lastKnownLatitude: 31.1,
        lastKnownLongitude: 121.4
      });
      // Assert
      const currentCount = targets.filter((item) => item.type === WeatherTargetType.CURRENT_LOCATION).length;
      const upcomingCount = targets.filter((item) => item.type === WeatherTargetType.UPCOMING_NODES).length;
      expect(currentCount).assertEqual(1);
      expect(upcomingCount >= 1).assertEqual(true);
    });

    it('invalid: completed_plan_should_not_build_any_weather_targets', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      const now = Date.now();
      const events: EventEntity[] = [buildEvent(1, 31.2, 121.5, now + 1000)];
      // Act
      const targets = resolver.buildWeatherTargets('p-completed', PlanStatus.COMPLETED, events, {
        planId: 'p-completed',
        status: PlanStatus.COMPLETED,
        plannedStartTime: now,
        plannedEndTime: now + 60000,
        completedNodeIds: ['1'],
        skippedNodeIds: [],
        isAutoStarted: false,
        isPaused: false,
        updatedAt: now,
        lastKnownLatitude: 31.1,
        lastKnownLongitude: 121.4
      });
      // Assert
      expect(targets.length).assertEqual(0);
    });

    it('regression: td-20260521-weather_targets_should_fallback_forecast_time_and_dedup_same_nodes', 0, () => {
      // Arrange
      const resolver = new WeatherPolicyResolver();
      const firstPending = buildEvent(7, 31.2, 121.5, 0);
      const duplicatePending = buildEvent(7, 31.2, 121.5, 0);
      const draftEvents: EventEntity[] = [firstPending, duplicatePending];
      const readyEvents: EventEntity[] = [buildEvent(8, 31.3, 121.6, 0)];

      // Act
      const draftTargets = resolver.buildWeatherTargets('p-draft-dedup', PlanStatus.DRAFT, draftEvents);
      const readyTargets = resolver.buildWeatherTargets('p-ready-fallback', PlanStatus.READY, readyEvents);

      // Assert
      expect(draftTargets.length).assertEqual(1);
      expect(draftTargets[0].type).assertEqual(WeatherTargetType.ALL_PLAN_NODES);
      expect(draftTargets[0].forecastTime === undefined).assertEqual(true);

      const firstTarget = readyTargets.find((item) => item.type === WeatherTargetType.FIRST_NODE);
      const upcomingTarget = readyTargets.find((item) => item.type === WeatherTargetType.UPCOMING_NODES);
      expect(firstTarget !== undefined).assertEqual(true);
      expect(upcomingTarget !== undefined).assertEqual(true);
      expect(firstTarget?.forecastTime === undefined).assertEqual(true);
      expect(upcomingTarget?.forecastTime === undefined).assertEqual(true);
    });
  });
}
