import { describe, expect, it } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { PlanTransitionEvent } from '../main/ets/domain/statemachine/ExecutionContext';
import { NotificationBridge } from '../main/ets/domain/statemachine/NotificationBridge';
import { MetricCounterKey, PlanStateMetricsStore } from '../main/ets/domain/statemachine/PlanStateMetricsStore';
import {
  canAutoTransition,
  isTerminalPlanStatus,
  PlanStatus,
  TransitionTriggerSource
} from '../main/ets/domain/statemachine/PlanStatus';
import { LocationChangeEvent, StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';
import { PlanWeatherRefreshPlanner } from '../main/ets/domain/statemachine/WeatherRefreshScheduler';
import { WeatherFetchPolicy, WeatherPolicyResolver, WeatherTargetType } from '../main/ets/domain/statemachine/WeatherPolicyResolver';

class FixedPolicyResolver extends WeatherPolicyResolver {
  private readonly policy: WeatherFetchPolicy;

  constructor(policy: WeatherFetchPolicy) {
    super();
    this.policy = policy;
  }

  public resolveWeatherFetchPolicy(_status: PlanStatus): WeatherFetchPolicy {
    return this.policy;
  }
}

function createTransitionEvent(
  planId: string,
  toStatus: PlanStatus,
  triggerReason: string = 'test_transition',
  timestamp: number = 1000
): PlanTransitionEvent {
  return {
    planId: planId,
    fromStatus: PlanStatus.CONFIRMED,
    toStatus: toStatus,
    triggerSource: TransitionTriggerSource.USER_ACTION,
    triggerReason: triggerReason,
    timestamp: timestamp
  };
}

function createLocationEvent(planId: string, distanceMeters: number = 120, timestamp: number = 1000): LocationChangeEvent {
  return {
    planId: planId,
    latitude: 31.23,
    longitude: 121.47,
    distanceMeters: distanceMeters,
    timestamp: timestamp
  };
}

function resetMetricsStorage(): void {
  AppStorage.setOrCreate(AppStorageKeys.PLAN_STATE_METRICS, '');
}

function resetReminderStorage(planIdNum: number): void {
  AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_SEQ, 0);
  AppStorage.setOrCreate(AppStorageKeys.WEATHER_REMINDER_PAYLOAD, '');
  AppStorage.setOrCreate(`WeatherReminderPayload_${planIdNum}`, '');
  AppStorage.setOrCreate(`WeatherInProgressShown_${planIdNum}`, 0);
}

function readReminderPayload(planIdNum?: number): string {
  if (planIdNum && planIdNum > 0) {
    return AppStorage.get<string>(`WeatherReminderPayload_${planIdNum}`) ?? '';
  }
  return AppStorage.get<string>(AppStorageKeys.WEATHER_REMINDER_PAYLOAD) ?? '';
}

function createPolicy(intervalMinutes?: number, forceRefreshOnEnter: boolean = true): WeatherFetchPolicy {
  return {
    targets: [WeatherTargetType.CURRENT_LOCATION],
    refreshIntervalMinutes: intervalMinutes,
    forceRefreshOnEnter: forceRefreshOnEnter,
    allowCache: true
  };
}

export default function phase2BatchAFTest() {
  describe('phase2BatchAFTest', () => {
    it('normal: state_event_bus_subscribe_should_receive_specific_plan_events', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let called = 0;
      const dispose = bus.subscribe('plan_subscribe_normal', (_event: PlanTransitionEvent) => {
        called += 1;
      });
      // Act
      bus.publish(createTransitionEvent('plan_subscribe_normal', PlanStatus.READY));
      dispose();
      // Assert
      expect(called).assertEqual(1);
    });

    it('boundary: state_event_bus_subscribe_should_treat_blank_plan_id_as_wildcard', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let called = 0;
      const dispose = bus.subscribe('   ', (_event: PlanTransitionEvent) => {
        called += 1;
      });
      // Act
      bus.publish(createTransitionEvent('plan_subscribe_boundary', PlanStatus.READY));
      dispose();
      // Assert
      expect(called).assertEqual(1);
    });

    it('invalid: state_event_bus_subscribe_dispose_should_be_idempotent', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let called = 0;
      const dispose = bus.subscribe('plan_subscribe_invalid', (_event: PlanTransitionEvent) => {
        called += 1;
      });
      // Act
      dispose();
      dispose();
      bus.publish(createTransitionEvent('plan_subscribe_invalid', PlanStatus.READY));
      // Assert
      expect(called).assertEqual(0);
    });

    it('normal: state_event_bus_publish_should_notify_specific_and_wildcard_listeners', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let specificCalled = 0;
      let wildcardCalled = 0;
      const disposeSpecific = bus.subscribe('plan_publish_normal', (_event: PlanTransitionEvent) => {
        specificCalled += 1;
      });
      const disposeWildcard = bus.subscribe('*', (_event: PlanTransitionEvent) => {
        wildcardCalled += 1;
      });
      // Act
      bus.publish(createTransitionEvent('plan_publish_normal', PlanStatus.READY));
      disposeSpecific();
      disposeWildcard();
      // Assert
      expect(specificCalled).assertEqual(1);
      expect(wildcardCalled).assertEqual(1);
    });

    it('boundary: state_event_bus_publish_should_allow_empty_listener_set', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      // Act
      bus.publish(createTransitionEvent('plan_publish_boundary', PlanStatus.READY));
      // Assert
      expect(true).assertTrue();
    });

    it('invalid: state_event_bus_publish_should_handle_blank_plan_id_event', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let wildcardCalled = 0;
      const disposeWildcard = bus.subscribe('*', (_event: PlanTransitionEvent) => {
        wildcardCalled += 1;
      });
      // Act
      bus.publish(createTransitionEvent('   ', PlanStatus.READY));
      disposeWildcard();
      // Assert
      expect(wildcardCalled >= 1).assertTrue();
    });

    it('normal: state_event_bus_subscribe_location_change_should_receive_specific_plan_events', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let called = 0;
      const dispose = bus.subscribeLocationChange('plan_loc_subscribe_normal', (_event: LocationChangeEvent) => {
        called += 1;
      });
      // Act
      bus.publishLocationChange(createLocationEvent('plan_loc_subscribe_normal'));
      dispose();
      // Assert
      expect(called).assertEqual(1);
    });

    it('boundary: state_event_bus_subscribe_location_change_should_treat_blank_plan_id_as_wildcard', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let called = 0;
      const dispose = bus.subscribeLocationChange('   ', (_event: LocationChangeEvent) => {
        called += 1;
      });
      // Act
      bus.publishLocationChange(createLocationEvent('plan_loc_subscribe_boundary'));
      dispose();
      // Assert
      expect(called).assertEqual(1);
    });

    it('invalid: state_event_bus_subscribe_location_change_dispose_should_be_idempotent', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let called = 0;
      const dispose = bus.subscribeLocationChange('plan_loc_subscribe_invalid', (_event: LocationChangeEvent) => {
        called += 1;
      });
      // Act
      dispose();
      dispose();
      bus.publishLocationChange(createLocationEvent('plan_loc_subscribe_invalid'));
      // Assert
      expect(called).assertEqual(0);
    });

    it('normal: state_event_bus_publish_location_change_should_notify_specific_and_wildcard_listeners', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let specificCalled = 0;
      let wildcardCalled = 0;
      const disposeSpecific = bus.subscribeLocationChange('plan_loc_publish_normal', (_event: LocationChangeEvent) => {
        specificCalled += 1;
      });
      const disposeWildcard = bus.subscribeLocationChange('*', (_event: LocationChangeEvent) => {
        wildcardCalled += 1;
      });
      // Act
      bus.publishLocationChange(createLocationEvent('plan_loc_publish_normal'));
      disposeSpecific();
      disposeWildcard();
      // Assert
      expect(specificCalled).assertEqual(1);
      expect(wildcardCalled).assertEqual(1);
    });

    it('boundary: state_event_bus_publish_location_change_should_allow_empty_listener_set', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      // Act
      bus.publishLocationChange(createLocationEvent('plan_loc_publish_boundary'));
      // Assert
      expect(true).assertTrue();
    });

    it('invalid: state_event_bus_publish_location_change_should_handle_blank_plan_id_event', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let wildcardCalled = 0;
      const disposeWildcard = bus.subscribeLocationChange('*', (_event: LocationChangeEvent) => {
        wildcardCalled += 1;
      });
      // Act
      bus.publishLocationChange(createLocationEvent('   '));
      disposeWildcard();
      // Assert
      expect(wildcardCalled >= 1).assertTrue();
    });

    it('normal: plan_state_metrics_store_get_instance_should_return_instance', 0, () => {
      // Arrange
      // Act
      const instance = PlanStateMetricsStore.getInstance();
      // Assert
      expect(instance !== null).assertTrue();
    });

    it('boundary: plan_state_metrics_store_get_instance_should_keep_singleton_reference', 0, () => {
      // Arrange
      const first = PlanStateMetricsStore.getInstance();
      // Act
      const second = PlanStateMetricsStore.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('invalid: plan_state_metrics_store_get_instance_should_resolve_when_holder_is_null', 0, () => {
      // Arrange
      const maybeStore: PlanStateMetricsStore | null = null;
      // Act
      const resolved = maybeStore ?? PlanStateMetricsStore.getInstance();
      // Assert
      expect(resolved !== null).assertTrue();
    });

    it('normal: plan_state_metrics_store_build_day_key_should_format_regular_timestamp', 0, () => {
      // Arrange
      const timestamp = new Date('2026-04-15T08:09:10.000Z').getTime();
      // Act
      const dayKey = PlanStateMetricsStore.buildDayKey(timestamp);
      // Assert
      expect(dayKey).assertEqual('2026-04-15');
    });

    it('boundary: plan_state_metrics_store_build_day_key_should_support_epoch_timestamp', 0, () => {
      // Arrange
      // Act
      const dayKey = PlanStateMetricsStore.buildDayKey(0);
      // Assert
      expect(dayKey).assertEqual('1970-01-01');
    });

    it('invalid: plan_state_metrics_store_build_day_key_should_expose_invalid_date_signature', 0, () => {
      // Arrange
      // Act
      const dayKey = PlanStateMetricsStore.buildDayKey(Number.NaN);
      // Assert
      expect(dayKey.indexOf('NaN') >= 0).assertTrue();
    });

    it('normal: plan_state_metrics_store_bump_should_accumulate_counter_and_reason', 0, () => {
      // Arrange
      resetMetricsStorage();
      const store = PlanStateMetricsStore.getInstance();
      const key: MetricCounterKey = 'recovery_attempt';
      // Act
      store.bump('plan_metrics_normal', '2026-04-15', key, '  context_missing  ', 1200);
      const snapshot = store.getSnapshot('plan_metrics_normal', '2026-04-15');
      // Assert
      expect(snapshot.counters['recovery_attempt']).assertEqual(1);
      expect(snapshot.reasons['context_missing']).assertEqual(1);
      expect(snapshot.updatedAt).assertEqual(1200);
    });

    it('boundary: plan_state_metrics_store_bump_should_ignore_blank_reason_code', 0, () => {
      // Arrange
      resetMetricsStorage();
      const store = PlanStateMetricsStore.getInstance();
      const key: MetricCounterKey = 'recovery_fail';
      // Act
      store.bump('plan_metrics_boundary', '2026-04-15', key, '   ', 2200);
      const snapshot = store.getSnapshot('plan_metrics_boundary', '2026-04-15');
      // Assert
      expect(snapshot.counters['recovery_fail']).assertEqual(1);
      expect(Object.keys(snapshot.reasons).length).assertEqual(0);
    });

    it('invalid: plan_state_metrics_store_bump_should_ignore_empty_plan_or_day_key', 0, () => {
      // Arrange
      resetMetricsStorage();
      const store = PlanStateMetricsStore.getInstance();
      // Act
      store.bump('', '2026-04-15', 'recovery_attempt', 'x', 1);
      store.bump('plan_metrics_invalid', '', 'recovery_attempt', 'x', 2);
      const raw = AppStorage.get<string>(AppStorageKeys.PLAN_STATE_METRICS) ?? '';
      // Assert
      expect(raw.length).assertEqual(0);
    });

    it('normal: plan_state_metrics_store_get_snapshot_should_return_stored_snapshot', 0, () => {
      // Arrange
      resetMetricsStorage();
      const store = PlanStateMetricsStore.getInstance();
      store.bump('plan_snapshot_normal', '2026-04-16', 'transition_jitter_blocked', undefined, 3300);
      // Act
      const snapshot = store.getSnapshot('plan_snapshot_normal', '2026-04-16');
      // Assert
      expect(snapshot.planId).assertEqual('plan_snapshot_normal');
      expect(snapshot.dayKey).assertEqual('2026-04-16');
      expect(snapshot.counters['transition_jitter_blocked']).assertEqual(1);
    });

    it('boundary: plan_state_metrics_store_get_snapshot_should_return_empty_snapshot_for_missing_key', 0, () => {
      // Arrange
      resetMetricsStorage();
      const store = PlanStateMetricsStore.getInstance();
      // Act
      const snapshot = store.getSnapshot('plan_snapshot_boundary', '2026-04-17');
      // Assert
      expect(snapshot.planId).assertEqual('plan_snapshot_boundary');
      expect(snapshot.dayKey).assertEqual('2026-04-17');
      expect(Object.keys(snapshot.counters).length).assertEqual(0);
      expect(Object.keys(snapshot.reasons).length).assertEqual(0);
      expect(snapshot.updatedAt > 0).assertTrue();
    });

    it('invalid: plan_state_metrics_store_get_snapshot_should_fallback_when_storage_json_is_invalid', 0, () => {
      // Arrange
      AppStorage.setOrCreate(AppStorageKeys.PLAN_STATE_METRICS, '{bad_json');
      const store = PlanStateMetricsStore.getInstance();
      // Act
      const snapshot = store.getSnapshot('plan_snapshot_invalid', '2026-04-18');
      // Assert
      expect(snapshot.planId).assertEqual('plan_snapshot_invalid');
      expect(snapshot.dayKey).assertEqual('2026-04-18');
      expect(Object.keys(snapshot.counters).length).assertEqual(0);
      expect(Object.keys(snapshot.reasons).length).assertEqual(0);
    });

    it('normal: notification_bridge_handle_transition_should_write_ready_payload', 0, () => {
      // Arrange
      const planIdNum = 401;
      resetReminderStorage(planIdNum);
      const bridge = new NotificationBridge();
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.READY, 'enter_ready', 4001));
      const payload = WeatherReminderStore.readPayload(planIdNum);
      // Assert
      expect(payload === null).assertFalse();
      if (!payload) {
        return;
      }
      expect(payload.planId).assertEqual(planIdNum);
      expect(payload.suggestionId).assertEqual('state_ready');
      expect(payload.level).assertEqual('NOTICE');
      expect(payload.createdAt).assertEqual(4001);
    });

    it('boundary: notification_bridge_handle_transition_should_deduplicate_in_progress_notice', 0, () => {
      // Arrange
      const planIdNum = 402;
      resetReminderStorage(planIdNum);
      const bridge = new NotificationBridge();
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.IN_PROGRESS, 'auto_start', 5001));
      const seqAfterFirst = AppStorage.get<number>(AppStorageKeys.WEATHER_REMINDER_SEQ) ?? 0;
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.IN_PROGRESS, 'auto_start', 5002));
      const seqAfterSecond = AppStorage.get<number>(AppStorageKeys.WEATHER_REMINDER_SEQ) ?? 0;
      const shownFlag = AppStorage.get<number>(`WeatherInProgressShown_${planIdNum}`) ?? 0;
      // Assert
      expect(seqAfterFirst > 0).assertTrue();
      expect(seqAfterSecond).assertEqual(seqAfterFirst);
      expect(shownFlag).assertEqual(1);
    });

    it('invalid: notification_bridge_handle_transition_should_ignore_non_numeric_plan_id', 0, () => {
      // Arrange
      resetReminderStorage(403);
      const bridge = new NotificationBridge();
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent('not_a_number', PlanStatus.READY, 'invalid_plan'));
      const payload = WeatherReminderStore.readPayload();
      const seq = AppStorage.get<number>(AppStorageKeys.WEATHER_REMINDER_SEQ) ?? 0;
      // Assert
      expect(payload === null).assertTrue();
      expect(seq).assertEqual(0);
    });

    it('normal: notification_bridge_handle_transition_should_write_paused_payload', 0, () => {
      // Arrange
      const planIdNum = 404;
      resetReminderStorage(planIdNum);
      const bridge = new NotificationBridge();
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.PAUSED, 'pause_by_user', 6001));
      const payload = WeatherReminderStore.readPayload(planIdNum);
      // Assert
      expect(payload === null).assertFalse();
      if (!payload) {
        return;
      }
      expect(payload.suggestionId).assertEqual('state_paused');
      expect(payload.level).assertEqual('INFO');
    });

    it('boundary: notification_bridge_handle_transition_should_skip_resume_by_user_notice', 0, () => {
      // Arrange
      const planIdNum = 405;
      resetReminderStorage(planIdNum);
      const bridge = new NotificationBridge();
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.IN_PROGRESS, 'resume_by_user', 7001));
      const payload = WeatherReminderStore.readPayload(planIdNum);
      const shownFlag = AppStorage.get<number>(`WeatherInProgressShown_${planIdNum}`) ?? 0;
      // Assert
      expect(payload === null).assertTrue();
      expect(shownFlag).assertEqual(0);
    });

    it('invalid: notification_bridge_handle_transition_should_clear_payload_for_terminal_status', 0, () => {
      // Arrange
      const planIdNum = 406;
      resetReminderStorage(planIdNum);
      const bridge = new NotificationBridge();
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.IN_PROGRESS, 'auto_start', 8001));
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.COMPLETED, 'finish_all', 8002));
      const globalPayload = readReminderPayload();
      const scopedPayload = readReminderPayload(planIdNum);
      const shownFlag = AppStorage.get<number>(`WeatherInProgressShown_${planIdNum}`) ?? 0;
      // Assert
      expect(globalPayload).assertEqual('');
      expect(scopedPayload).assertEqual('');
      expect(shownFlag).assertEqual(0);
    });

    it('normal: weather_refresh_planner_on_status_entered_should_schedule_next_run', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner();
      // Act
      const decision = planner.onStatusEntered('plan_weather_enter_normal', PlanStatus.READY, 1000);
      // Assert
      expect(decision.shouldRefresh).assertTrue();
      expect(decision.intervalMinutes).assertEqual(15);
      expect(decision.nextRefreshAt).assertEqual(901000);
    });

    it('boundary: weather_refresh_planner_on_status_entered_should_disable_interval_for_terminal_status', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner();
      // Act
      const decision = planner.onStatusEntered('plan_weather_enter_boundary', PlanStatus.COMPLETED, 2000);
      // Assert
      expect(decision.shouldRefresh).assertFalse();
      expect(decision.intervalMinutes === undefined).assertTrue();
      expect(decision.nextRefreshAt === undefined).assertTrue();
    });

    it('invalid: weather_refresh_planner_on_status_entered_should_handle_negative_interval_policy', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(-5, true)));
      // Act
      const decision = planner.onStatusEntered('plan_weather_enter_invalid', PlanStatus.READY, 3000);
      // Assert
      expect(decision.shouldRefresh).assertTrue();
      expect(decision.intervalMinutes === undefined).assertTrue();
      expect(decision.nextRefreshAt === undefined).assertTrue();
    });

    it('normal: weather_refresh_planner_evaluate_should_trigger_when_due', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(10, true)));
      planner.onStatusEntered('plan_weather_evaluate_normal', PlanStatus.READY, 0);
      // Act
      const decision = planner.evaluate('plan_weather_evaluate_normal', PlanStatus.READY, 600000);
      // Assert
      expect(decision.shouldRefresh).assertTrue();
      expect(decision.intervalMinutes).assertEqual(10);
      expect(decision.nextRefreshAt).assertEqual(1200000);
    });

    it('boundary: weather_refresh_planner_evaluate_should_wait_when_not_due', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(10, true)));
      planner.onStatusEntered('plan_weather_evaluate_boundary', PlanStatus.READY, 0);
      // Act
      const decision = planner.evaluate('plan_weather_evaluate_boundary', PlanStatus.READY, 1000);
      // Assert
      expect(decision.shouldRefresh).assertFalse();
      expect(decision.nextRefreshAt).assertEqual(600000);
      expect(decision.intervalMinutes).assertEqual(10);
    });

    it('invalid: weather_refresh_planner_evaluate_should_disable_for_zero_interval_policy', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(0, false)));
      // Act
      const decision = planner.evaluate('plan_weather_evaluate_invalid', PlanStatus.READY, 4000);
      // Assert
      expect(decision.shouldRefresh).assertFalse();
      expect(decision.intervalMinutes === undefined).assertTrue();
      expect(decision.nextRefreshAt === undefined).assertTrue();
    });

    it('normal: weather_refresh_planner_clear_should_remove_existing_schedule', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(10, true)));
      planner.onStatusEntered('plan_weather_clear_normal', PlanStatus.READY, 0);
      // Act
      planner.clear('plan_weather_clear_normal');
      const decision = planner.evaluate('plan_weather_clear_normal', PlanStatus.READY, 1);
      // Assert
      expect(decision.shouldRefresh).assertTrue();
      expect(decision.intervalMinutes).assertEqual(10);
    });

    it('boundary: weather_refresh_planner_clear_should_ignore_missing_plan_id', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(10, true)));
      planner.onStatusEntered('plan_weather_clear_boundary_kept', PlanStatus.READY, 0);
      // Act
      planner.clear('plan_weather_clear_boundary_missing');
      const decision = planner.evaluate('plan_weather_clear_boundary_kept', PlanStatus.READY, 1000);
      // Assert
      expect(decision.shouldRefresh).assertFalse();
      expect(decision.nextRefreshAt).assertEqual(600000);
    });

    it('invalid: weather_refresh_planner_clear_should_handle_blank_plan_id_key', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(10, true)));
      planner.onStatusEntered('', PlanStatus.READY, 0);
      // Act
      planner.clear('');
      const decision = planner.evaluate('', PlanStatus.READY, 1);
      // Assert
      expect(decision.shouldRefresh).assertTrue();
      expect(decision.intervalMinutes).assertEqual(10);
    });

    it('normal: plan_status_is_terminal_should_return_true_for_completed', 0, () => {
      // Arrange
      // Act
      const result = isTerminalPlanStatus(PlanStatus.COMPLETED);
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: plan_status_is_terminal_should_return_true_for_cancelled_and_expired', 0, () => {
      // Arrange
      // Act
      const cancelled = isTerminalPlanStatus(PlanStatus.CANCELLED);
      const expired = isTerminalPlanStatus(PlanStatus.EXPIRED);
      // Assert
      expect(cancelled).assertTrue();
      expect(expired).assertTrue();
    });

    it('invalid: plan_status_is_terminal_should_return_false_for_unknown_value', 0, () => {
      // Arrange
      const unknownStatus = 'UNKNOWN' as PlanStatus;
      // Act
      const result = isTerminalPlanStatus(unknownStatus);
      // Assert
      expect(result).assertFalse();
    });

    it('normal: plan_status_can_auto_transition_should_return_true_for_ready', 0, () => {
      // Arrange
      // Act
      const result = canAutoTransition(PlanStatus.READY);
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: plan_status_can_auto_transition_should_return_false_for_terminal_status', 0, () => {
      // Arrange
      // Act
      const completed = canAutoTransition(PlanStatus.COMPLETED);
      const cancelled = canAutoTransition(PlanStatus.CANCELLED);
      const expired = canAutoTransition(PlanStatus.EXPIRED);
      // Assert
      expect(completed).assertFalse();
      expect(cancelled).assertFalse();
      expect(expired).assertFalse();
    });

    it('invalid: plan_status_can_auto_transition_should_treat_unknown_status_as_non_terminal', 0, () => {
      // Arrange
      const unknownStatus = 'UNKNOWN' as PlanStatus;
      // Act
      const result = canAutoTransition(unknownStatus);
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: notification_bridge_handle_transition_should_keep_ready_notice_stable_under_repeated_publish', 0, () => {
      // Arrange
      const planIdNum = 407;
      resetReminderStorage(planIdNum);
      const bridge = new NotificationBridge();
      // Act
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.READY, 'first_ready', 9001));
      bridge.handlePlanTransitionNotification(createTransitionEvent(`${planIdNum}`, PlanStatus.READY, 'second_ready', 9002));
      const payload = WeatherReminderStore.readPayload(planIdNum);
      // Assert
      expect(payload === null).assertFalse();
      if (!payload) {
        return;
      }
      expect(payload.suggestionId).assertEqual('state_ready');
    });

    it('regression: plan_state_metrics_store_get_snapshot_should_still_return_default_when_key_missing', 0, () => {
      // Arrange
      resetMetricsStorage();
      const store = PlanStateMetricsStore.getInstance();
      // Act
      const snapshot = store.getSnapshot('regression_plan_missing', '1970-01-01');
      // Assert
      expect(snapshot.planId).assertEqual('regression_plan_missing');
      expect(snapshot.dayKey).assertEqual('1970-01-01');
      expect(Object.keys(snapshot.counters).length).assertEqual(0);
      expect(Object.keys(snapshot.reasons).length).assertEqual(0);
    });

    it('combined: weather_refresh_planner_evaluate_and_clear_should_rebuild_schedule_after_clear', 0, () => {
      // Arrange
      const planner = new PlanWeatherRefreshPlanner(new FixedPolicyResolver(createPolicy(10, true)));
      planner.onStatusEntered('plan_weather_combined', PlanStatus.READY, 0);
      planner.clear('plan_weather_combined');
      // Act
      const decision = planner.evaluate('plan_weather_combined', PlanStatus.READY, 700000);
      // Assert
      expect(decision.shouldRefresh).assertTrue();
      expect(decision.intervalMinutes).assertEqual(10);
    });
  });
}
