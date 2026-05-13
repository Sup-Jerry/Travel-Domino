import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelinePlanStateManager, ITimelinePlanStateHost } from '../main/ets/viewmodel/managers/TimelinePlanStateManager';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherSuggestion, WeatherStageType } from '../main/ets/domain/services/WeatherModels';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import {
  ExecutionContext,
  GetPlanStatusResult,
  PlanTransitionEvent,
  StateEvaluationInput,
  TransitionResult,
  UpdateExecutionContextCommand
} from '../main/ets/domain/statemachine/ExecutionContext';
import { LocationChangeEvent } from '../main/ets/domain/statemachine/StateEventBus';

class CompanionContextSnapshot {
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP' = 'IDLE';
}

class FakeTimelinePlanStateHost implements ITimelinePlanStateHost {
  planId: number = 10;
  planName: string = 'plan_origin';
  events: EventEntity[] = [];
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 12).getTime();
  idleGapDetectionEnabled: boolean = false;
  idleGapTriggerMinutes: number = 15;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  weatherFeatureEnabled: boolean = false;
  executionWeatherEnabled: boolean = false;
  executionWeatherHint: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionWeatherAppliedSummary: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';

  weatherFacade: WeatherFacade = new WeatherFacade();
  planStateMachine: PlanStateMachine = PlanStateMachine.getInstance({});

  startSchedulerCount: number = 0;
  stopSchedulerCount: number = 0;
  recalculateCount: number = 0;
  realtimeCount: number = 0;
  regenerateCount: number = 0;
  markChangedCount: number = 0;
  refreshCount: number = 0;
  persistDateCalls: number = 0;
  persistNameCalls: number = 0;
  persistedDate: number = 0;
  persistedName: string = '';

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  startExecutionWeatherScheduler(_planId?: number, _stage?: WeatherStageType): void {
    this.startSchedulerCount += 1;
  }

  stopExecutionWeatherScheduler(): void {
    this.stopSchedulerCount += 1;
  }

  async refreshExecutionWeather(
    _forceRefresh?: boolean,
    _trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    _stage?: WeatherStageType
  ): Promise<void> {
    return;
  }

  getCompanionContext(_nowTs?: number): CompanionContextSnapshot {
    const snapshot = new CompanionContextSnapshot();
    return snapshot;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateCount += 1;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new ScheduleOrchestrator();
  }

  isAutoRouteEnabled(): boolean {
    return false;
  }

  calculateRealtimeSchedule(): void {
    this.realtimeCount += 1;
  }

  regenerateGroups(): void {
    this.regenerateCount += 1;
  }

  markScheduleChanged(): void {
    this.markChangedCount += 1;
  }

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }

  async persistPlanStartDate(_planId: number, startDate: number): Promise<void> {
    this.persistDateCalls += 1;
    this.persistedDate = startDate;
  }

  async persistPlanName(_planId: number, name: string): Promise<void> {
    this.persistNameCalls += 1;
    this.persistedName = name;
  }
}

class FakePlanStateMachineForPlanStateTest {
  status: PlanStatus = PlanStatus.DRAFT;
  transitionUnsubscribeCount: number = 0;
  locationUnsubscribeCount: number = 0;
  evaluateCount: number = 0;
  updateContextCount: number = 0;
  recoveryReasons: string[] = [];
  lastDistance: number = -1;
  transitionListener: ((event: PlanTransitionEvent) => void) | null = null;
  locationListener: ((event: LocationChangeEvent) => void) | null = null;
  context: ExecutionContext | null = null;

  getPlanStatus(planId: string): GetPlanStatusResult {
    return {
      planId: planId,
      status: this.status,
      isAutoStarted: false
    };
  }

  subscribePlanTransition(_planId: string, listener: (event: PlanTransitionEvent) => void): () => void {
    this.transitionListener = listener;
    return () => {
      this.transitionUnsubscribeCount += 1;
      this.transitionListener = null;
    };
  }

  subscribeLocationChange(_planId: string, listener: (event: LocationChangeEvent) => void): () => void {
    this.locationListener = listener;
    return () => {
      this.locationUnsubscribeCount += 1;
      this.locationListener = null;
    };
  }

  buildEvaluationInput(planId: string, _events: EventEntity[], now: number): StateEvaluationInput {
    return {
      planId: planId,
      currentStatus: this.status,
      now: now,
      locationPermissionGranted: true,
      userClickedStart: false,
      userClickedPause: false,
      userClickedResume: false,
      userClickedCancel: false,
      hasReachedFirstNode: false,
      motionDetected: false,
      allNodesCompleted: false,
      isPlanExpired: false
    };
  }

  evaluateAndApply(_input: StateEvaluationInput): TransitionResult | null {
    this.evaluateCount += 1;
    return null;
  }

  updateExecutionContext(command: UpdateExecutionContextCommand): ExecutionContext {
    this.updateContextCount += 1;
    this.lastDistance = command.distanceToFirstNodeMeters ?? -1;
    const next: ExecutionContext = {
      planId: command.planId,
      status: this.status,
      plannedStartTime: 0,
      plannedEndTime: 0,
      completedNodeIds: [],
      skippedNodeIds: [],
      isAutoStarted: false,
      isPaused: false,
      lastKnownLatitude: command.lastKnownLatitude,
      lastKnownLongitude: command.lastKnownLongitude,
      lastKnownSpeed: command.lastKnownSpeed,
      lastKnownAccuracy: command.lastKnownAccuracy,
      distanceToFirstNodeMeters: command.distanceToFirstNodeMeters,
      updatedAt: command.updatedAt
    };
    this.context = next;
    return next;
  }

  getExecutionContext(_planId: string): ExecutionContext | null {
    return this.context;
  }

  markRecovery(_planId: string, _success: boolean, reason: string): void {
    this.recoveryReasons.push(reason);
  }

  pauseExecution(planId: string): TransitionResult {
    return this.transition(planId, PlanStatus.PAUSED, 'pause_by_user');
  }

  resumeExecution(planId: string): TransitionResult {
    return this.transition(planId, PlanStatus.IN_PROGRESS, 'resume_by_user');
  }

  confirmPlan(planId: string): TransitionResult {
    return this.transition(planId, PlanStatus.CONFIRMED, 'confirm_plan');
  }

  completeExecution(planId: string): TransitionResult {
    return this.transition(planId, PlanStatus.COMPLETED, 'complete_execution');
  }

  emitTransition(toStatus: PlanStatus): void {
    if (!this.transitionListener) {
      return;
    }
    this.status = toStatus;
    this.transitionListener({
      planId: '10',
      fromStatus: PlanStatus.DRAFT,
      toStatus: toStatus,
      triggerSource: TransitionTriggerSource.USER_ACTION,
      triggerReason: 'test_emit',
      timestamp: Date.now()
    });
  }

  emitLocation(): void {
    if (!this.locationListener) {
      return;
    }
    this.locationListener({
      planId: '10',
      latitude: 30,
      longitude: 120,
      distanceMeters: 10,
      timestamp: Date.now()
    });
  }

  private transition(planId: string, toStatus: PlanStatus, reason: string): TransitionResult {
    const fromStatus = this.status;
    this.status = toStatus;
    return {
      success: true,
      planId: planId,
      fromStatus: fromStatus,
      toStatus: toStatus,
      event: {
        planId: planId,
        fromStatus: fromStatus,
        toStatus: toStatus,
        triggerSource: TransitionTriggerSource.USER_ACTION,
        triggerReason: reason,
        timestamp: Date.now()
      }
    };
  }
}

class IntervalHooksForPlanStateTest {
  private readonly originSetInterval: Object;
  private readonly originClearInterval: Object;
  private readonly callbacks: Map<number, () => void> = new Map<number, () => void>();
  private nextId: number = 1;

  constructor() {
    this.originSetInterval = Reflect.get(globalThis, 'setInterval') as Object;
    this.originClearInterval = Reflect.get(globalThis, 'clearInterval') as Object;
  }

  public install(): void {
    Reflect.set(globalThis, 'setInterval', (callback: () => void, _intervalMs: number): number => {
      const timerId = this.nextId;
      this.nextId += 1;
      this.callbacks.set(timerId, callback);
      return timerId;
    });
    Reflect.set(globalThis, 'clearInterval', (timerId: number): void => {
      this.callbacks.delete(timerId);
    });
  }

  public latestTimerId(): number {
    return this.nextId - 1;
  }

  public trigger(timerId: number): void {
    const callback = this.callbacks.get(timerId);
    callback?.();
  }

  public restore(): void {
    Reflect.set(globalThis, 'setInterval', this.originSetInterval);
    Reflect.set(globalThis, 'clearInterval', this.originClearInterval);
  }
}

export default function timelinePlanStateManagerTest() {
  describe('timelinePlanStateManagerTest', () => {
    it('normal: update_plan_date_should_persist_and_refresh_runtime_views', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);
      const newDateTimestamp = new Date(2026, 3, 20, 14, 30, 25).getTime();
      const expectedNormalized = new Date(2026, 3, 20, 0, 0, 0, 0).getTime();
      // Act
      await manager.updatePlanDate(newDateTimestamp);
      // Assert
      expect(host.planStartDate).assertEqual(expectedNormalized);
      expect(host.persistDateCalls).assertEqual(1);
      expect(host.persistedDate).assertEqual(expectedNormalized);
      expect(host.realtimeCount).assertEqual(1);
      expect(host.regenerateCount).assertEqual(1);
      expect(host.markChangedCount).assertEqual(1);
      expect(host.refreshCount).assertEqual(1);
    });

    it('boundary: pause_current_execution_should_return_false_when_plan_id_non_positive', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      // Assert
      expect(paused).assertFalse();
    });

    it('invalid: rename_plan_should_ignore_when_plan_id_is_minus_one', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = -1;
      const manager = new TimelinePlanStateManager(host);
      // Act
      await manager.renamePlan('new_name');
      // Assert
      expect(host.planName).assertEqual('plan_origin');
      expect(host.persistNameCalls).assertEqual(0);
    });

    it('conflict: is_date_conflict_should_return_true_when_target_before_plan_start', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = new Date(2026, 3, 12).getTime();
      const manager = new TimelinePlanStateManager(host);
      const targetDate = new Date(2026, 3, 11).getTime();
      // Act
      const conflict = manager.isDateConflict(targetDate);
      // Assert
      expect(conflict).assertTrue();
    });

    it('regression: td-20260412-c4-date-conflict-should-ignore-time-part-within-same-day', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = new Date(2026, 3, 12, 8, 0, 0).getTime();
      const manager = new TimelinePlanStateManager(host);
      const sameDayTarget = new Date(2026, 3, 12, 23, 59, 59).getTime();
      // Act
      const conflict = manager.isDateConflict(sameDayTarget);
      // Assert
      expect(conflict).assertFalse();
    });

    it('combined: resume_and_pause_should_both_fail_when_plan_id_invalid_without_side_effect', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      const resumed = manager.resumeCurrentExecution();
      // Assert
      expect(paused).assertFalse();
      expect(resumed).assertFalse();
      expect(host.recalculateCount).assertEqual(0);
      expect(host.executionWeatherAppliedSummary).assertEqual('');
    });

    it('normal: bind_and_unbind_should_wire_transition_and_location_callbacks', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.weatherFeatureEnabled = true;
      host.executionWeatherEnabled = true;
      const machine = new FakePlanStateMachineForPlanStateTest();
      machine.status = PlanStatus.CONFIRMED;
      host.planStateMachine = machine as Object as PlanStateMachine;
      const manager = new TimelinePlanStateManager(host);

      // Act
      manager.bindPlanState(host.planId);
      machine.emitTransition(PlanStatus.IN_PROGRESS);
      machine.emitLocation();
      manager.unbindPlanState();

      // Assert
      expect(host.currentPlanStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(host.startSchedulerCount > 0).assertTrue();
      expect(machine.evaluateCount > 0).assertTrue();
      expect(machine.transitionUnsubscribeCount).assertEqual(1);
      expect(machine.locationUnsubscribeCount).assertEqual(1);
    });

    it('boundary: bind_plan_state_timer_should_trigger_runtime_evaluation_callback', 0, () => {
      // Arrange
      const hooks = new IntervalHooksForPlanStateTest();
      hooks.install();
      const host = new FakeTimelinePlanStateHost();
      const machine = new FakePlanStateMachineForPlanStateTest();
      host.planStateMachine = machine as Object as PlanStateMachine;
      const manager = new TimelinePlanStateManager(host);

      // Act
      manager.bindPlanState(host.planId);
      const evaluateCountBeforeTick = machine.evaluateCount;
      hooks.trigger(hooks.latestTimerId());
      manager.unbindPlanState();
      hooks.restore();

      // Assert
      expect(evaluateCountBeforeTick >= 1).assertTrue();
      expect(machine.evaluateCount).assertEqual(evaluateCountBeforeTick + 1);
    });

    it('boundary: bind_plan_state_should_ignore_non_positive_plan_id', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const machine = new FakePlanStateMachineForPlanStateTest();
      host.planStateMachine = machine as Object as PlanStateMachine;
      const manager = new TimelinePlanStateManager(host);

      // Act
      manager.bindPlanState(0);

      // Assert
      expect(machine.transitionListener === null).assertTrue();
      expect(machine.locationListener === null).assertTrue();
    });

    it('combined: location_samples_should_ignore_invalid_values_and_track_motion_distance', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const machine = new FakePlanStateMachineForPlanStateTest();
      host.planStateMachine = machine as Object as PlanStateMachine;
      const manager = new TimelinePlanStateManager(host);

      // Act
      manager.onLocationSampleForStateMachine(Number.NaN, 120, 1, 5, 1000);
      manager.onLocationSampleForStateMachine(30, 120, 1, 5, 1000);
      manager.onLocationSampleForStateMachine(30.002, 120.002, 2, 6, 2000);
      manager.onLocationSampleForStateMachine(30.004, 120.004, 3, 7, 3000);
      manager.onLocationSampleForStateMachine(30.006, 120.006, 4, 8, 4000);

      // Assert
      expect(machine.updateContextCount).assertEqual(4);
      expect(machine.lastDistance > 0).assertTrue();
      expect(machine.context?.lastKnownSpeed).assertEqual(4);
      expect(machine.context?.lastKnownAccuracy).assertEqual(8);
    });

    it('regression: recover_missing_runtime_context_should_mark_rebuild_and_evaluate', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const machine = new FakePlanStateMachineForPlanStateTest();
      host.planStateMachine = machine as Object as PlanStateMachine;
      const manager = new TimelinePlanStateManager(host);

      // Act
      manager.recoverPlanRuntimeState();

      // Assert
      expect(machine.recoveryReasons[0]).assertEqual('context_missing');
      expect(machine.recoveryReasons[1]).assertEqual('context_rebuild');
      expect(machine.evaluateCount).assertEqual(1);
    });

    it('normal: resume_success_should_update_weather_hint_and_recalculate', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const machine = new FakePlanStateMachineForPlanStateTest();
      machine.status = PlanStatus.PAUSED;
      host.planStateMachine = machine as Object as PlanStateMachine;
      const manager = new TimelinePlanStateManager(host);

      // Act
      const resumed = manager.resumeCurrentExecution();

      // Assert
      expect(resumed).assertTrue();
      expect(host.currentPlanStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(host.recalculateCount).assertEqual(1);
      expect(host.executionWeatherLevel).assertEqual('NOTICE');
      expect(host.executionWeatherHint.length > 0).assertTrue();
    });

    it('normal: rename_plan_should_persist_and_update_host_name', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);

      // Act
      await manager.renamePlan('renamed_plan');

      // Assert
      expect(host.persistNameCalls).assertEqual(1);
      expect(host.persistedName).assertEqual('renamed_plan');
      expect(host.planName).assertEqual('renamed_plan');
    });
  });
}
