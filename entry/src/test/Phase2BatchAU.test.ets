import { describe, it, expect } from '@ohos/hypium';
import { PlanStateMachine, PlanStateMachineDeps } from '../main/ets/domain/statemachine/PlanStateMachine';
import { LocationChangeEvent, StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';
import { TransitionEngine } from '../main/ets/domain/statemachine/TransitionEngine';
import { StateEvaluator } from '../main/ets/domain/statemachine/StateEvaluator';
import {
  ExecutionContext,
  PlanTransitionEvent,
  StateEvaluationInput,
  createDefaultExecutionContext
} from '../main/ets/domain/statemachine/ExecutionContext';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { ExecutionContextStore } from '../main/ets/infrastructure/persistence/ExecutionContextStore';
import { NotificationBridge } from '../main/ets/domain/statemachine/NotificationBridge';
import { FullReplanCommand, ReplanCoordinator, ReplanResult, SoftReplanCommand } from '../main/ets/domain/statemachine/ReplanCoordinator';
import { PlanWeatherRefreshPlanner, PlanWeatherScheduleDecision } from '../main/ets/domain/statemachine/WeatherRefreshScheduler';
import { MetricCounterKey, PlanStateMetricsSnapshot, PlanStateMetricsStore } from '../main/ets/domain/statemachine/PlanStateMetricsStore';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';

interface MetricRecordForAU {
  planId: string;
  dayKey: string;
  key: MetricCounterKey;
  reasonCode: string;
  now: number;
}

interface TransitionMetaForAU {
  triggerSource: TransitionTriggerSource;
  triggerReason: string;
}

interface PlanTimeWindowForAU {
  startTime: number;
  endTime: number;
}

interface EventOverridesForAU {
  id?: number;
  name?: string;
  plan_id?: number;
  status?: number;
  completion_status?: number;
  dynamic_start_time?: number;
  dynamic_end_time?: number;
  duration?: number;
  latitude?: number;
  longitude?: number;
}

class FakeExecutionContextStoreForAU extends ExecutionContextStore {
  private readonly contexts: Map<string, ExecutionContext> = new Map<string, ExecutionContext>();
  private readonly transitions: Map<string, PlanTransitionEvent[]> = new Map<string, PlanTransitionEvent[]>();

  public readContext(planId: string): ExecutionContext | null {
    return this.contexts.get(planId) ?? null;
  }

  public writeContext(context: ExecutionContext): void {
    this.contexts.set(context.planId, context);
  }

  public appendTransition(event: PlanTransitionEvent): void {
    const list = this.transitions.get(event.planId) ?? [];
    list.push(event);
    this.transitions.set(event.planId, list);
  }

  public readTransitions(planId: string): PlanTransitionEvent[] {
    return this.transitions.get(planId) ?? [];
  }

  public readLatestTransition(planId: string): PlanTransitionEvent | null {
    const list = this.readTransitions(planId);
    return list.length > 0 ? list[list.length - 1] : null;
  }
}

class FakeStateEventBusForAU extends StateEventBus {
  public readonly publishedTransitions: PlanTransitionEvent[] = [];
  public readonly publishedLocationEvents: LocationChangeEvent[] = [];

  public publish(event: PlanTransitionEvent): void {
    this.publishedTransitions.push(event);
  }

  public publishLocationChange(event: LocationChangeEvent): void {
    this.publishedLocationEvents.push(event);
  }
}

class FakeNotificationBridgeForAU extends NotificationBridge {
  public handledCount: number = 0;

  public handlePlanTransitionNotification(_event: PlanTransitionEvent): void {
    this.handledCount += 1;
  }
}

class FakeReplanCoordinatorForAU extends ReplanCoordinator {
  public enteredCount: number = 0;

  public onStateEntered(_status: PlanStatus, _context: ExecutionContext): void {
    this.enteredCount += 1;
  }

  public requestSoftReplan(command: SoftReplanCommand, _context: ExecutionContext): ReplanResult {
    return {
      success: true,
      planId: command.planId,
      changed: true,
      reasonCode: 'soft_stub_au'
    };
  }

  public requestFullReplan(command: FullReplanCommand, _status: PlanStatus): ReplanResult {
    return {
      success: true,
      planId: command.planId,
      changed: true,
      reasonCode: 'full_stub_au'
    };
  }
}

class FakeWeatherRefreshPlannerForAU extends PlanWeatherRefreshPlanner {
  public enteredCount: number = 0;

  public onStatusEntered(_planId: string, _status: PlanStatus, now: number): PlanWeatherScheduleDecision {
    this.enteredCount += 1;
    return {
      shouldRefresh: false,
      nextRefreshAt: now + 60_000,
      intervalMinutes: 1
    };
  }

  public evaluate(_planId: string, _status: PlanStatus, now: number): PlanWeatherScheduleDecision {
    return {
      shouldRefresh: false,
      nextRefreshAt: now + 60_000,
      intervalMinutes: 1
    };
  }
}

class FakePlanStateMetricsStoreForAU extends PlanStateMetricsStore {
  public readonly records: MetricRecordForAU[] = [];

  public bump(planId: string, dayKey: string, key: MetricCounterKey, reasonCode?: string, now: number = Date.now()): void {
    this.records.push({
      planId: planId,
      dayKey: dayKey,
      key: key,
      reasonCode: reasonCode ?? '',
      now: now
    });
  }

  public getSnapshot(planId: string, dayKey: string): PlanStateMetricsSnapshot {
    const counters: Record<string, number> = {};
    const reasons: Record<string, number> = {};
    let updatedAt = 0;

    for (let i = 0; i < this.records.length; i++) {
      const record = this.records[i];
      if (record.planId !== planId || record.dayKey !== dayKey) {
        continue;
      }
      counters[record.key] = (counters[record.key] ?? 0) + 1;
      if (record.reasonCode.trim().length > 0) {
        reasons[record.reasonCode] = (reasons[record.reasonCode] ?? 0) + 1;
      }
      updatedAt = record.now;
    }

    return {
      planId: planId,
      dayKey: dayKey,
      counters: counters,
      reasons: reasons,
      updatedAt: updatedAt > 0 ? updatedAt : Date.now()
    };
  }
}

class FakeArrivalLocationForAU {
  latitude: number;
  longitude: number;
  accuracy: number;
  speed: number;

  constructor(latitude: number, longitude: number, accuracy: number, speed: number) {
    this.latitude = latitude;
    this.longitude = longitude;
    this.accuracy = accuracy;
    this.speed = speed;
  }
}

interface MachineBundleForAU {
  machine: PlanStateMachine;
  store: FakeExecutionContextStoreForAU;
  eventBus: FakeStateEventBusForAU;
  notification: FakeNotificationBridgeForAU;
  replan: FakeReplanCoordinatorForAU;
  weather: FakeWeatherRefreshPlannerForAU;
  metrics: FakePlanStateMetricsStoreForAU;
}

function createTransitionEventForAU(
  planId: string,
  toStatus: PlanStatus,
  triggerReason: string = 'test_transition'
): PlanTransitionEvent {
  return {
    planId: planId,
    fromStatus: PlanStatus.CONFIRMED,
    toStatus: toStatus,
    triggerSource: TransitionTriggerSource.USER_ACTION,
    triggerReason: triggerReason,
    timestamp: Date.now()
  };
}

function buildInputForAU(overrides?: Partial<StateEvaluationInput>): StateEvaluationInput {
  const now = overrides?.now ?? Date.now();
  return {
    planId: overrides?.planId ?? 'au_default_plan',
    currentStatus: overrides?.currentStatus ?? PlanStatus.CONFIRMED,
    now: now,
    firstNodeStartTime: overrides?.firstNodeStartTime,
    firstNodeLat: overrides?.firstNodeLat,
    firstNodeLng: overrides?.firstNodeLng,
    lastKnownLat: overrides?.lastKnownLat,
    lastKnownLng: overrides?.lastKnownLng,
    currentSpeed: overrides?.currentSpeed,
    currentAccuracy: overrides?.currentAccuracy,
    motionDistanceMeters: overrides?.motionDistanceMeters,
    lastTransitionAt: overrides?.lastTransitionAt,
    locationPermissionGranted: overrides?.locationPermissionGranted ?? true,
    userClickedStart: overrides?.userClickedStart ?? false,
    userClickedPause: overrides?.userClickedPause ?? false,
    userClickedResume: overrides?.userClickedResume ?? false,
    userClickedCancel: overrides?.userClickedCancel ?? false,
    hasReachedFirstNode: overrides?.hasReachedFirstNode ?? false,
    motionDetected: overrides?.motionDetected ?? false,
    allNodesCompleted: overrides?.allNodesCompleted ?? false,
    isPlanExpired: overrides?.isPlanExpired ?? false
  };
}

function createMachineBundleForAU(): MachineBundleForAU {
  const store = new FakeExecutionContextStoreForAU();
  const eventBus = new FakeStateEventBusForAU();
  const notification = new FakeNotificationBridgeForAU();
  const replan = new FakeReplanCoordinatorForAU();
  const weather = new FakeWeatherRefreshPlannerForAU();
  const metrics = new FakePlanStateMetricsStoreForAU();
  const deps: PlanStateMachineDeps = {
    store: store,
    evaluator: new StateEvaluator(),
    transitionEngine: new TransitionEngine(),
    stateEventBus: eventBus,
    notificationBridge: notification,
    replanCoordinator: replan,
    weatherRefreshPlanner: weather,
    metricsStore: metrics
  };
  return {
    machine: PlanStateMachine.getInstance(deps),
    store: store,
    eventBus: eventBus,
    notification: notification,
    replan: replan,
    weather: weather,
    metrics: metrics
  };
}

function createEventForAU(overrides?: EventOverridesForAU): EventEntity {
  const event = new EventEntity(overrides?.name ?? 'event_au', overrides?.plan_id ?? 1);
  event.id = overrides?.id ?? 1;
  event.status = overrides?.status ?? 1;
  event.completion_status = overrides?.completion_status ?? EventEntity.STATE_PENDING;
  event.dynamic_start_time = overrides?.dynamic_start_time ?? 0;
  event.dynamic_end_time = overrides?.dynamic_end_time ?? 0;
  event.duration = overrides?.duration ?? 30;
  event.latitude = overrides?.latitude ?? 31.2304;
  event.longitude = overrides?.longitude ?? 121.4737;
  return event;
}

function withArrivalLocationForAU(location: Object | null, run: () => void): void {
  const engine = ArrivalReminderEngine.getInstance();
  const original = Reflect.get(engine as Object, 'lastLocation') as Object | null;
  Reflect.set(engine as Object, 'lastLocation', location);
  try {
    run();
  } finally {
    Reflect.set(engine as Object, 'lastLocation', original);
  }
}

export default function phase2BatchAUTest() {
  describe('phase2BatchAUTest_state_event_bus', () => {
    it('conflict: state_event_bus_dispose_should_keep_sibling_transition_listener_when_set_not_empty', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let firstCalled = 0;
      let secondCalled = 0;
      const offFirst = bus.subscribe('plan_multi_listener', (_event: PlanTransitionEvent) => {
        firstCalled += 1;
      });
      const offSecond = bus.subscribe('plan_multi_listener', (_event: PlanTransitionEvent) => {
        secondCalled += 1;
      });
      // Act
      offFirst();
      bus.publish(createTransitionEventForAU('plan_multi_listener', PlanStatus.READY));
      offSecond();
      // Assert
      expect(firstCalled).assertEqual(0);
      expect(secondCalled).assertEqual(1);
    });

    it('conflict: state_event_bus_dispose_should_keep_sibling_location_listener_when_set_not_empty', 0, () => {
      // Arrange
      const bus = new StateEventBus();
      let firstCalled = 0;
      let secondCalled = 0;
      const offFirst = bus.subscribeLocationChange('plan_multi_location', (_event: LocationChangeEvent) => {
        firstCalled += 1;
      });
      const offSecond = bus.subscribeLocationChange('plan_multi_location', (_event: LocationChangeEvent) => {
        secondCalled += 1;
      });
      const event: LocationChangeEvent = {
        planId: 'plan_multi_location',
        latitude: 31.23,
        longitude: 121.47,
        distanceMeters: 180,
        timestamp: Date.now()
      };
      // Act
      offFirst();
      bus.publishLocationChange(event);
      offSecond();
      // Assert
      expect(firstCalled).assertEqual(0);
      expect(secondCalled).assertEqual(1);
    });
  });

  describe('phase2BatchAUTest_transition_engine', () => {
    it('invalid: transition_engine_can_transition_should_return_false_for_unknown_source_status', 0, () => {
      // Arrange
      const engine = new TransitionEngine();
      const unknownStatus = 'UNKNOWN' as PlanStatus;
      // Act
      const canTransition = engine.canTransition(unknownStatus, PlanStatus.READY);
      // Assert
      expect(canTransition).assertEqual(false);
    });
  });

  describe('phase2BatchAUTest_state_evaluator', () => {
    it('boundary: state_evaluator_should_enter_ready_immediately_when_first_node_already_reached', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      // Act
      const canEnter = evaluator.shouldEnterReady(buildInputForAU({
        currentStatus: PlanStatus.CONFIRMED,
        firstNodeStartTime: undefined,
        hasReachedFirstNode: true
      }));
      // Assert
      expect(canEnter).assertEqual(true);
    });

    it('invalid: state_evaluator_should_not_enter_in_progress_without_start_time_or_trigger', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      // Act
      const canEnter = evaluator.shouldEnterInProgress(buildInputForAU({
        currentStatus: PlanStatus.CONFIRMED,
        firstNodeStartTime: undefined,
        userClickedStart: false,
        hasReachedFirstNode: false,
        motionDetected: false
      }));
      // Assert
      expect(canEnter).assertEqual(false);
    });

    it('boundary: state_evaluator_should_not_block_pause_leave_when_transition_time_missing', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const now = Date.now();
      // Act
      const blocked = evaluator.shouldBlockPauseLeave(now, undefined);
      // Assert
      expect(blocked).assertEqual(false);
    });

    it('normal: state_evaluator_should_pause_in_progress_when_user_clicks_pause', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const now = Date.now();
      // Act
      const result = evaluator.evaluateNextStatus(buildInputForAU({
        currentStatus: PlanStatus.IN_PROGRESS,
        now: now,
        userClickedPause: true
      }));
      // Assert
      expect(result.shouldTransition).assertEqual(true);
      expect(result.suggestedStatus).assertEqual(PlanStatus.PAUSED);
      expect(result.triggerReason).assertEqual('pause_by_user');
    });

    it('boundary: state_evaluator_should_keep_paused_when_resume_not_clicked', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const now = Date.now();
      // Act
      const result = evaluator.evaluateNextStatus(buildInputForAU({
        currentStatus: PlanStatus.PAUSED,
        now: now,
        userClickedResume: false
      }));
      // Assert
      expect(result.shouldTransition).assertEqual(false);
      expect(result.suggestedStatus).assertEqual(PlanStatus.PAUSED);
    });

    it('normal: state_evaluator_should_use_location_meta_when_ready_is_reached_by_arrival', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const now = Date.now();
      // Act
      const result = evaluator.evaluateNextStatus(buildInputForAU({
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        firstNodeStartTime: undefined,
        hasReachedFirstNode: true
      }));
      // Assert
      expect(result.shouldTransition).assertEqual(true);
      expect(result.suggestedStatus).assertEqual(PlanStatus.READY);
      expect(result.triggerSource).assertEqual(TransitionTriggerSource.LOCATION_PROXIMITY);
      expect(result.triggerReason).assertEqual('arrived_first_node_window');
    });

    it('normal: state_evaluator_should_use_time_meta_when_confirmed_plan_reaches_start_time', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const now = Date.now();
      // Act
      const result = evaluator.evaluateNextStatus(buildInputForAU({
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        firstNodeStartTime: now - 1,
        hasReachedFirstNode: false,
        motionDetected: false
      }));
      // Assert
      expect(result.shouldTransition).assertEqual(true);
      expect(result.suggestedStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(result.triggerSource).assertEqual(TransitionTriggerSource.TIME_WINDOW);
      expect(result.triggerReason).assertEqual('reach_first_node_start_time');
    });

    it('invalid: state_evaluator_private_transition_meta_should_fallback_to_manual_override_when_no_branch_matches', 0, () => {
      // Arrange
      const evaluator = new StateEvaluator();
      const resolveTransitionMeta = Reflect.get(evaluator as Object, 'resolveTransitionMeta') as Function;
      const input = buildInputForAU({
        currentStatus: PlanStatus.CONFIRMED,
        firstNodeStartTime: undefined,
        hasReachedFirstNode: false,
        motionDetected: false
      });
      // Act
      const meta = (resolveTransitionMeta as (input: StateEvaluationInput, next: PlanStatus) => TransitionMetaForAU)(
        input,
        PlanStatus.CONFIRMED
      );
      // Assert
      expect(meta.triggerSource).assertEqual(TransitionTriggerSource.MANUAL_OVERRIDE);
      expect(meta.triggerReason).assertEqual('state_adjustment');
    });
  });

  describe('phase2BatchAUTest_plan_state_machine', () => {
    it('boundary: plan_state_machine_get_recent_transitions_should_slice_latest_items_when_limit_is_smaller_than_total', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_recent_transitions';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      bundle.machine.startExecution(planId, TransitionTriggerSource.USER_ACTION);
      bundle.machine.pauseExecution(planId);
      // Act
      const transitions = bundle.machine.getRecentTransitions(planId, 2);
      // Assert
      expect(transitions.length).assertEqual(2);
      expect(transitions[0].toStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(transitions[1].toStatus).assertEqual(PlanStatus.PAUSED);
    });

    it('boundary: plan_state_machine_transition_should_be_idempotent_when_target_status_matches_current_status', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_same_status_transition';
      bundle.machine.confirmPlan(planId);
      const transitionCountBefore = bundle.store.readTransitions(planId).length;
      const publishCountBefore = bundle.eventBus.publishedTransitions.length;
      const metricCountBefore = bundle.metrics.records.length;
      // Act
      const result = bundle.machine.confirmPlan(planId);
      // Assert
      expect(result.success).assertEqual(true);
      expect(result.event === undefined).assertEqual(true);
      expect(bundle.store.readTransitions(planId).length).assertEqual(transitionCountBefore);
      expect(bundle.eventBus.publishedTransitions.length).assertEqual(publishCountBefore);
      expect(bundle.metrics.records.length).assertEqual(metricCountBefore);
    });

    it('normal: plan_state_machine_start_execution_should_use_auto_reason_when_source_is_not_user_action', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_auto_start_reason';
      bundle.machine.confirmPlan(planId);
      // Act
      const result = bundle.machine.startExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      // Assert
      expect(result.success).assertEqual(true);
      expect(result.event?.triggerReason).assertEqual('auto_start_execution');
    });

    it('normal: plan_state_machine_evaluate_and_apply_should_transition_when_auto_ready_conditions_are_met', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_evaluate_apply_ready';
      bundle.machine.confirmPlan(planId);
      const now = Date.now();
      // Act
      const result = bundle.machine.evaluateAndApply(buildInputForAU({
        planId: planId,
        currentStatus: PlanStatus.CONFIRMED,
        now: now,
        firstNodeStartTime: now + 10 * 60 * 1000,
        hasReachedFirstNode: false,
        motionDetected: false
      }));
      const status = bundle.machine.getPlanStatus(planId);
      // Assert
      expect(result === null).assertEqual(false);
      expect(result?.success ?? false).assertEqual(true);
      expect(result?.toStatus).assertEqual(PlanStatus.READY);
      expect(status.status).assertEqual(PlanStatus.READY);
    });

    it('conflict: plan_state_machine_evaluate_and_apply_should_surface_status_conflict_when_context_differs_from_input', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_evaluate_apply_conflict';
      bundle.machine.confirmPlan(planId);
      const now = Date.now();
      // Act
      const result = bundle.machine.evaluateAndApply(buildInputForAU({
        planId: planId,
        currentStatus: PlanStatus.READY,
        now: now,
        firstNodeStartTime: now,
        lastTransitionAt: now - 5 * 60 * 1000,
        hasReachedFirstNode: false,
        motionDetected: false
      }));
      // Assert
      expect(result === null).assertEqual(false);
      expect(result?.success ?? true).assertEqual(false);
      expect(result?.errorCode).assertEqual('STATUS_CONFLICT');
      expect(bundle.metrics.records.some((record: MetricRecordForAU) =>
        record.key === 'auto_transition_fail_in_progress' && record.reasonCode === 'STATUS_CONFLICT'
      )).assertEqual(true);
    });

    it('boundary: plan_state_machine_get_plan_status_should_backfill_missing_auto_transition_stats', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_backfill_stats';
      const context = createDefaultExecutionContext(planId, Date.now());
      context.autoTransitionStats = undefined;
      bundle.store.writeContext(context);
      // Act
      const status = bundle.machine.getPlanStatus(planId);
      const updated = bundle.machine.getExecutionContext(planId);
      // Assert
      expect(status.status).assertEqual(PlanStatus.DRAFT);
      expect(updated?.autoTransitionStats !== undefined).assertEqual(true);
      expect(updated?.autoTransitionStats?.readyAttempt).assertEqual(0);
    });

    it('combined: plan_state_machine_build_evaluation_input_should_sync_window_and_use_arrival_location_for_distance_flags', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_build_input_arrival';
      const now = Date.now();
      const firstEvent = createEventForAU({
        id: 101,
        name: 'first_pending',
        plan_id: 99,
        status: 1,
        completion_status: EventEntity.STATE_PENDING,
        dynamic_start_time: now + 10 * 60 * 1000,
        dynamic_end_time: now + 20 * 60 * 1000,
        duration: 10,
        latitude: 31.2304,
        longitude: 121.4737
      });
      const laterCompleted = createEventForAU({
        id: 102,
        name: 'later_completed',
        plan_id: 99,
        status: 1,
        completion_status: EventEntity.STATE_COMPLETED,
        dynamic_start_time: now + 40 * 60 * 1000,
        dynamic_end_time: 0,
        duration: 15,
        latitude: 31.235,
        longitude: 121.48
      });
      const arrivalLocation = new FakeArrivalLocationForAU(firstEvent.latitude, firstEvent.longitude, 15, 2);
      // Act
      withArrivalLocationForAU(arrivalLocation as Object, () => {
        const input = bundle.machine.buildEvaluationInput(planId, [firstEvent, laterCompleted], now);
        const context = bundle.machine.getExecutionContext(planId);
        // Assert
        expect(input.firstNodeStartTime).assertEqual(firstEvent.dynamic_start_time);
        expect(input.lastKnownLat).assertEqual(firstEvent.latitude);
        expect(input.lastKnownLng).assertEqual(firstEvent.longitude);
        expect(input.locationPermissionGranted).assertEqual(true);
        expect(input.hasReachedFirstNode).assertEqual(true);
        expect(input.motionDetected).assertEqual(true);
        expect((input.motionDistanceMeters ?? 999) <= 300).assertEqual(true);
        expect(context?.plannedStartTime).assertEqual(firstEvent.dynamic_start_time);
        expect(context?.plannedEndTime).assertEqual(laterCompleted.dynamic_start_time + laterCompleted.duration * 60 * 1000);
      });
    });

    it('boundary: plan_state_machine_private_time_helpers_should_cover_valid_and_fallback_paths', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const resolvePlannedWindow = Reflect.get(bundle.machine as Object, 'resolvePlannedWindowByEvents') as Function;
      const resolveEventStartTime = Reflect.get(bundle.machine as Object, 'resolveEventStartTime') as Function;
      const resolveEventEndTime = Reflect.get(bundle.machine as Object, 'resolveEventEndTime') as Function;
      const measureDistanceMeters = Reflect.get(bundle.machine as Object, 'measureDistanceMeters') as Function;
      const eventWithDynamicEnd = createEventForAU({
        id: 201,
        dynamic_start_time: 1_000,
        dynamic_end_time: 2_000,
        duration: 10
      });
      const eventWithNoTime = createEventForAU({
        id: 202,
        dynamic_start_time: 0,
        dynamic_end_time: 0,
        duration: 0
      });
      const eventWithDurationOnly = createEventForAU({
        id: 203,
        dynamic_start_time: 3_000,
        dynamic_end_time: 0,
        duration: 15
      });
      // Act
      const startWithValue = (resolveEventStartTime as (event: EventEntity) => number)(eventWithDynamicEnd);
      const startWithoutValue = (resolveEventStartTime as (event: EventEntity) => number)(eventWithNoTime);
      const endWithDynamic = (resolveEventEndTime as (event: EventEntity, startTime: number) => number)(eventWithDynamicEnd, 1_000);
      const endWithZeroDuration = (resolveEventEndTime as (event: EventEntity, startTime: number) => number)(eventWithNoTime, 4_000);
      const endWithMissingStart = (resolveEventEndTime as (event: EventEntity, startTime: number) => number)(eventWithNoTime, 0);
      const endWithDuration = (resolveEventEndTime as (event: EventEntity, startTime: number) => number)(eventWithDurationOnly, 3_000);
      const windowWithValues = (resolvePlannedWindow as (
        scheduled: EventEntity[],
        fallbackStart: number,
        fallbackEnd: number
      ) => PlanTimeWindowForAU)([eventWithDynamicEnd, eventWithNoTime, eventWithDurationOnly], 111, 222);
      const windowFallback = (resolvePlannedWindow as (
        scheduled: EventEntity[],
        fallbackStart: number,
        fallbackEnd: number
      ) => PlanTimeWindowForAU)([eventWithNoTime], 111, 222);
      const validDistance = (measureDistanceMeters as (
        lat1: number,
        lng1: number,
        lat2: number,
        lng2: number
      ) => number)(31.2304, 121.4737, 31.2305, 121.4738);
      const invalidDistance = (measureDistanceMeters as (
        lat1: number,
        lng1: number,
        lat2: number,
        lng2: number
      ) => number)(Number.NaN, 121.4737, 31.2305, 121.4738);
      // Assert
      expect(startWithValue).assertEqual(1_000);
      expect(startWithoutValue).assertEqual(0);
      expect(endWithDynamic).assertEqual(2_000);
      expect(endWithZeroDuration).assertEqual(4_000);
      expect(endWithMissingStart).assertEqual(0);
      expect(endWithDuration).assertEqual(903_000);
      expect(windowWithValues.startTime).assertEqual(1_000);
      expect(windowWithValues.endTime).assertEqual(903_000);
      expect(windowFallback.startTime).assertEqual(111);
      expect(windowFallback.endTime).assertEqual(222);
      expect(validDistance > 0).assertEqual(true);
      expect(invalidDistance).assertEqual(Number.MAX_VALUE);
    });

    it('invalid: plan_state_machine_transition_should_not_record_auto_metrics_for_non_auto_failure_target', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_non_auto_failure';
      // Act
      const result = bundle.machine.transitionPlanStatus({
        planId: planId,
        targetStatus: PlanStatus.COMPLETED,
        triggerSource: TransitionTriggerSource.MANUAL_OVERRIDE,
        triggerReason: 'force_complete_from_draft'
      });
      // Assert
      expect(result.success).assertEqual(false);
      expect(result.errorCode).assertEqual('INVALID_TRANSITION');
      expect(bundle.metrics.records.length).assertEqual(0);
    });

    it('regression: plan_state_machine_private_stage_and_weather_helpers_should_cover_all_status_groups', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const toStageLabel = Reflect.get(bundle.machine as Object, 'toStageLabel') as Function;
      const resolveWeatherMode = Reflect.get(bundle.machine as Object, 'resolveWeatherMode') as Function;
      // Act
      const draftLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.DRAFT);
      const confirmedLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.CONFIRMED);
      const readyLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.READY);
      const inProgressLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.IN_PROGRESS);
      const pausedLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.PAUSED);
      const completedLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.COMPLETED);
      const cancelledLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.CANCELLED);
      const expiredLabel = (toStageLabel as (status: PlanStatus) => string)(PlanStatus.EXPIRED);
      const draftWeather = (resolveWeatherMode as (status: PlanStatus) => string)(PlanStatus.DRAFT);
      const readyWeather = (resolveWeatherMode as (status: PlanStatus) => string)(PlanStatus.READY);
      const pausedWeather = (resolveWeatherMode as (status: PlanStatus) => string)(PlanStatus.PAUSED);
      const completedWeather = (resolveWeatherMode as (status: PlanStatus) => string)(PlanStatus.COMPLETED);
      // Assert
      expect(draftLabel).assertEqual('草稿');
      expect(confirmedLabel).assertEqual('已确认未开始');
      expect(readyLabel).assertEqual('执行预备');
      expect(inProgressLabel).assertEqual('执行中');
      expect(pausedLabel).assertEqual('暂停中');
      expect(completedLabel).assertEqual('已完成');
      expect(cancelledLabel).assertEqual('已取消');
      expect(expiredLabel).assertEqual('已失效');
      expect(draftWeather).assertEqual('PLAN_LOCATION');
      expect(readyWeather).assertEqual('CURRENT_AND_PLAN');
      expect(pausedWeather).assertEqual('CURRENT_PRIORITY');
      expect(completedWeather).assertEqual('DISABLED');
    });

    it('invalid: plan_state_machine_update_execution_context_should_skip_location_publish_when_coordinates_are_missing', 0, () => {
      // Arrange
      const bundle = createMachineBundleForAU();
      const planId = 'au_missing_location_publish';
      bundle.machine.confirmPlan(planId);
      bundle.machine.prepareExecution(planId, TransitionTriggerSource.TIME_WINDOW);
      // Act
      bundle.machine.updateExecutionContext({
        planId: planId,
        distanceToFirstNodeMeters: 180,
        updatedAt: Date.now()
      });
      // Assert
      expect(bundle.eventBus.publishedLocationEvents.length).assertEqual(0);
    });
  });
}
