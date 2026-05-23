import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ITimelineExecutionHost, ReflowHint, TimelineExecutionService } from '../main/ets/domain/timeline/services/TimelineExecutionService';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';

class PlanStatusSnapshotForV {
  status: PlanStatus = PlanStatus.READY;
}

class PlanStateMachineMockForV {
  status: PlanStatus = PlanStatus.READY;
  startCount: number = 0;
  completeCount: number = 0;
  lastSource: TransitionTriggerSource = TransitionTriggerSource.USER_ACTION;

  startExecution(_planId: string, source: TransitionTriggerSource): void {
    this.startCount++;
    this.lastSource = source;
    this.status = PlanStatus.IN_PROGRESS;
  }

  completeExecution(_planId: string): void {
    this.completeCount++;
    this.status = PlanStatus.COMPLETED;
  }

  getPlanStatus(_planId: string): PlanStatusSnapshotForV {
    const snapshot = new PlanStatusSnapshotForV();
    snapshot.status = this.status;
    return snapshot;
  }
}

class ReminderFacadeMockForV {
  callCount: number = 0;
  async updateScheduleNotification(
    _title: string,
    _body: string,
    _planId: number,
    _eventId: number,
    _ongoing: boolean
  ): Promise<void> {
    this.callCount++;
  }
}

class ReflowHintDataForV implements ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed' = 'reflow';
  minutesDelta: number = 0;
  message: string = '';
  updatedAt: number = Date.now();
}

class HostMockForV implements ITimelineExecutionHost {
  events: EventEntity[] = [];
  conflictList: EventEntity[] = [];
  planStartDate: number = Date.now();
  isArchived: boolean = false;
  shouldThrowTransition: boolean = false;
  transitionShouldSucceed: boolean = true;
  actualTimeMutationInFlight: boolean = false;
  latestReflowHint: ReflowHint | null = null;
  planId: number = 1;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  planStateMachine: PlanStateMachineMockForV = new PlanStateMachineMockForV();
  reminderFacade: ReminderFacadeMockForV = new ReminderFacadeMockForV();
  transitionCallCount: number = 0;
  recalculateCallCount: number = 0;
  scheduleChangedCount: number = 0;
  evaluateStatusCount: number = 0;
  checkinCount: number = 0;
  snapshotCount: number = 0;

  async applyRuntimeTransition(
    target: EventEntity,
    transition: 'START' | 'END' | 'SKIP' | 'REOPEN',
    timestamp: number
  ): Promise<boolean> {
    if (this.shouldThrowTransition) {
      throw new Error('transition_failed_v');
    }
    if (!this.transitionShouldSucceed) {
      return false;
    }
    this.transitionCallCount++;
    if (transition === 'START') {
      target.actual_start_time = timestamp;
      target.actual_end_time = 0;
      target.completion_status = EventEntity.STATE_PENDING;
      return true;
    }
    if (transition === 'END') {
      target.actual_end_time = timestamp;
      target.completion_status = EventEntity.STATE_COMPLETED;
      return true;
    }
    if (transition === 'SKIP') {
      target.actual_end_time = timestamp;
      target.completion_status = EventEntity.STATE_SKIPPED;
      return true;
    }
    target.actual_start_time = 0;
    target.actual_end_time = 0;
    target.completion_status = EventEntity.STATE_PENDING;
    return true;
  }

  recalculateFromEventId(_eventId: number): void {
    this.recalculateCallCount++;
  }

  getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.events;
    const target = source.find((item: EventEntity) =>
      item.status === 1 &&
      item.completion_status === EventEntity.STATE_PENDING &&
      item.id > afterId
    );
    return target ?? null;
  }

  buildReflowHint(
    _action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    const hint = new ReflowHintDataForV();
    hint.type = 'shift';
    hint.minutesDelta = Math.floor((afterTs - beforeTs) / 60000);
    hint.message = `${targetName}->${nextName}`;
    hint.updatedAt = Date.now();
    return hint;
  }

  logTimelineSnapshot(_scene: string): void {
    this.snapshotCount++;
  }

  getPlaceCheckinSummary(_placeName: string): void {
    this.checkinCount++;
  }

  evaluatePlanStatusByRuntime(): void {
    this.evaluateStatusCount++;
  }

  getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.events;
    const active = source.find((item: EventEntity) =>
      item.status === 1 &&
      item.completion_status === EventEntity.STATE_PENDING &&
      item.actual_start_time > 0 &&
      item.actual_end_time <= 0
    );
    return active ?? null;
  }

  markScheduleChanged(): void {
    this.scheduleChangedCount++;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return [...this.events].sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((item: EventEntity) => item.id === eventId);
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }
}

class ActiveSnapshotForV {
  eventId: number = 0;
  planId: number = 0;
  name: string = '';
  actualStartTime: number = 0;
}

class StaticHooksForV {
  private readonly originFindGlobalActiveEvent: Object;
  private readonly originUpdateFields: Object;

  constructor() {
    this.originFindGlobalActiveEvent = Reflect.get(EventRepositoryImpl, 'findGlobalActiveEvent') as Object;
    this.originUpdateFields = Reflect.get(EventRepositoryImpl, 'updateFields') as Object;
  }

  setFindGlobalActiveEvent(fn: (excludeEventId: number) => Promise<Object | null>): void {
    Reflect.set(EventRepositoryImpl, 'findGlobalActiveEvent', fn);
  }

  setUpdateFields(
    fn: (id: number, fields: Object[], planId: number) => Promise<void>
  ): void {
    Reflect.set(EventRepositoryImpl, 'updateFields', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'findGlobalActiveEvent', this.originFindGlobalActiveEvent);
    Reflect.set(EventRepositoryImpl, 'updateFields', this.originUpdateFields);
  }
}

function createEventForV(id: number, name: string): EventEntity {
  const item = new EventEntity(name, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.duration = 60;
  item.pre_travel_min = 0;
  item.completion_status = EventEntity.STATE_PENDING;
  return item;
}

class ServiceBundleForV {
  host: HostMockForV = new HostMockForV();
  service: TimelineExecutionService = new TimelineExecutionService(this.host);
}

function createBundleForV(): ServiceBundleForV {
  return new ServiceBundleForV();
}

export default function phase2CoreCoverageBatchVTest() {
  describe('phase2CoreCoverageBatchVTest', () => {
    it('normal: timeline_execution_find_current_active_event_should_prioritize_actual_started_pending_event', 0, () => {
      // Arrange
      const bundle = createBundleForV();
      const active = createEventForV(1, 'active_v');
      active.actual_start_time = Date.now() - 10_000;
      const pending = createEventForV(2, 'pending_v');
      bundle.host.events = [active, pending];
      // Act
      const found = bundle.service.findCurrentActiveEvent();
      // Assert
      expect(found?.id ?? 0).assertEqual(1);
    });

    it('boundary: timeline_execution_find_current_active_event_should_match_dynamic_window_when_no_actual_start_exists', 0, () => {
      // Arrange
      const bundle = createBundleForV();
      const dynamicActive = createEventForV(42, 'dynamic_active_v');
      dynamicActive.dynamic_start_time = Date.now() - 30_000;
      dynamicActive.dynamic_end_time = Date.now() + 30_000;
      const laterPending = createEventForV(43, 'later_pending_v');
      laterPending.dynamic_start_time = Date.now() + 90_000;
      laterPending.dynamic_end_time = Date.now() + 150_000;
      bundle.host.events = [dynamicActive, laterPending];

      // Act
      const found = bundle.service.findCurrentActiveEvent();

      // Assert
      expect(found?.id ?? 0).assertEqual(42);
    });

    it('boundary: timeline_execution_calculate_realtime_schedule_should_mark_anchor_conflict_when_cursor_exceeds_locked_time', 0, () => {
      // Arrange
      const bundle = createBundleForV();
      const first = createEventForV(1, 'first_v');
      first.actual_start_time = bundle.host.planStartDate + 10 * 60 * 60 * 1000;
      first.duration = 120;
      const locked = createEventForV(2, 'locked_v');
      locked.fixed_start_time = '10:30';
      locked.lock_status = 1;
      locked.duration = 30;
      bundle.host.events = [first, locked];
      // Act
      bundle.service.calculateRealtimeSchedule();
      // Assert
      expect(bundle.host.conflictList.length).assertEqual(1);
      expect(bundle.host.conflictList[0].id).assertEqual(2);
      expect(bundle.host.events[1].is_forecast_conflict).assertTrue();
    });

    it('invalid: timeline_execution_update_actual_time_should_reject_start_when_active_event_exists', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const active = createEventForV(1, 'active_v');
      active.actual_start_time = Date.now() - 60_000;
      const target = createEventForV(2, 'target_v');
      bundle.host.events = [active, target];
      // Act
      const ok = await bundle.service.updateActualTime(target.id, 'actual_start_time', Date.now());
      // Assert
      expect(ok).assertFalse();
      expect(bundle.host.transitionCallCount).assertEqual(0);
    });

    it('conflict: timeline_execution_reopen_skipped_should_return_false_for_non_skipped_target', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const target = createEventForV(3, 'non_skipped_v');
      target.completion_status = EventEntity.STATE_PENDING;
      bundle.host.events = [target];
      // Act
      const ok = await bundle.service.reopenSkippedEvent(target.id);
      // Assert
      expect(ok).assertFalse();
      expect(bundle.host.transitionCallCount).assertEqual(0);
    });

    it('regression: td-20260415-update-actual-end-should-complete-plan-when-all-scheduled-events-completed', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      bundle.host.planId = 9;
      const active = createEventForV(10, 'active_finish_v');
      active.actual_start_time = Date.now() - 120_000;
      const done = createEventForV(11, 'done_v');
      done.completion_status = EventEntity.STATE_COMPLETED;
      done.actual_end_time = Date.now() - 60_000;
      bundle.host.events = [active, done];
      // Act
      const ok = await bundle.service.updateActualTime(active.id, 'actual_end_time', Date.now());
      // Assert
      expect(ok).assertTrue();
      expect(bundle.host.planStateMachine.completeCount).assertEqual(1);
      expect(bundle.host.currentPlanStatus).assertEqual(PlanStatus.COMPLETED);
    });

    it('combined: timeline_execution_get_start_conflict_info_and_skip_event_should_cover_repository_mapping_and_reflow_hint', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const hooks = new StaticHooksForV();
      hooks.setFindGlobalActiveEvent(async (_excludeEventId: number): Promise<Object | null> => {
        const snapshot = new ActiveSnapshotForV();
        snapshot.eventId = 77;
        snapshot.planId = 8;
        snapshot.name = 'global_active_v';
        snapshot.actualStartTime = 123456789;
        return snapshot as Object;
      });
      const skipTarget = createEventForV(20, 'skip_target_v');
      const nextPending = createEventForV(21, 'next_v');
      nextPending.dynamic_start_time = Date.now() + 90_000;
      bundle.host.events = [skipTarget, nextPending];
      // Act
      const conflict = await bundle.service.getStartConflictInfo(0);
      await bundle.service.skipEvent(skipTarget);
      hooks.restore();
      // Assert
      expect(conflict?.eventId ?? 0).assertEqual(77);
      expect(conflict?.planId ?? 0).assertEqual(8);
      expect(skipTarget.completion_status).assertEqual(EventEntity.STATE_SKIPPED);
      expect(bundle.host.latestReflowHint !== null).assertTrue();
      expect(bundle.host.checkinCount).assertEqual(1);
    });

    it('normal: timeline_execution_record_start_and_checkout_should_recalculate_and_replace_events_array', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const target = createEventForV(30, 'flow_v');
      bundle.host.events = [target];
      const beforeStartEvents = bundle.host.events;

      // Act
      await bundle.service.recordStartTime(target);
      const afterStartEvents = bundle.host.events;
      await bundle.service.checkOutEvent(target);
      const afterEndEvents = bundle.host.events;

      // Assert
      expect(target.actual_start_time > 0).assertTrue();
      expect(target.actual_end_time > 0).assertTrue();
      expect(bundle.host.recalculateCallCount >= 0).assertTrue();
      expect(beforeStartEvents === afterStartEvents).assertFalse();
      expect(afterStartEvents === afterEndEvents).assertFalse();
    });

    it('invalid: timeline_execution_record_start_and_checkout_should_stop_when_transition_returns_false', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const target = createEventForV(44, 'blocked_transition_v');
      bundle.host.events = [target];
      bundle.host.transitionShouldSucceed = false;
      const beforeEvents = bundle.host.events;

      // Act
      await bundle.service.recordStartTime(target);
      await bundle.service.checkOutEvent(target);

      // Assert
      expect(bundle.host.transitionCallCount).assertEqual(0);
      expect(bundle.host.recalculateCallCount).assertEqual(0);
      expect(target.actual_start_time).assertEqual(0);
      expect(target.actual_end_time).assertEqual(0);
      expect(bundle.host.events === beforeEvents).assertTrue();
    });

    it('boundary: timeline_execution_update_actual_time_should_persist_zero_start_without_starting_plan', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const hooks = new StaticHooksForV();
      const target = createEventForV(31, 'zero_start_v');
      target.actual_start_time = Date.now() - 5_000;
      bundle.host.events = [target];
      let updatedId = -1;
      let updatedPlanId = -1;
      let updatedFieldName = '';
      let updatedFieldValue = -1;
      hooks.setUpdateFields(async (id: number, fields: Object[], planId: number): Promise<void> => {
        updatedId = id;
        updatedPlanId = planId;
        updatedFieldName = String(Reflect.get(fields[0], 'column') ?? '');
        updatedFieldValue = Number(Reflect.get(fields[0], 'value') ?? -1);
      });

      try {
        // Act
        const ok = await bundle.service.updateActualTime(target.id, 'actual_start_time', 0);

        // Assert
        expect(ok).assertTrue();
        expect(updatedId).assertEqual(target.id);
        expect(updatedPlanId).assertEqual(bundle.host.planId);
        expect(updatedFieldName).assertEqual('actual_start_time');
        expect(updatedFieldValue).assertEqual(0);
        expect(target.actual_start_time).assertEqual(0);
        expect(bundle.host.planStateMachine.startCount).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: timeline_execution_update_actual_time_should_reject_when_archived_or_mutation_locked', 0, async () => {
      // Arrange
      const archivedBundle = createBundleForV();
      const archivedTarget = createEventForV(32, 'archived_v');
      archivedBundle.host.events = [archivedTarget];
      archivedBundle.host.isArchived = true;
      const lockedBundle = createBundleForV();
      const lockedTarget = createEventForV(33, 'locked_v');
      lockedBundle.host.events = [lockedTarget];
      lockedBundle.host.actualTimeMutationInFlight = true;

      // Act
      const archivedOk = await archivedBundle.service.updateActualTime(archivedTarget.id, 'actual_start_time', Date.now());
      const lockedOk = await lockedBundle.service.updateActualTime(lockedTarget.id, 'actual_end_time', Date.now());

      // Assert
      expect(archivedOk).assertFalse();
      expect(lockedOk).assertFalse();
      expect(archivedBundle.host.transitionCallCount).assertEqual(0);
      expect(lockedBundle.host.transitionCallCount).assertEqual(0);
    });

    it('combined: timeline_execution_update_actual_time_should_start_plan_and_emit_notification_for_started_event', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const target = createEventForV(34, 'startable_v');
      const nextPending = createEventForV(35, 'next_started_v');
      nextPending.dynamic_start_time = Date.now() + 15 * 60 * 1000;
      bundle.host.events = [target, nextPending];
      const hooks = new StaticHooksForV();
      hooks.setFindGlobalActiveEvent(async (_excludeEventId: number): Promise<Object | null> => null);

      try {
        // Act
        const ok = await bundle.service.updateActualTime(target.id, 'actual_start_time', Date.now());

        // Assert
        expect(ok).assertTrue();
        expect(bundle.host.planStateMachine.startCount).assertEqual(1);
        expect(bundle.host.currentPlanStatus).assertEqual(PlanStatus.IN_PROGRESS);
        expect(bundle.host.reminderFacade.callCount).assertEqual(1);
        expect(bundle.host.latestReflowHint !== null).assertTrue();
        expect(bundle.host.scheduleChangedCount).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('combined: timeline_execution_update_actual_end_should_evaluate_runtime_when_schedule_not_fully_completed', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      bundle.host.planId = 12;
      const active = createEventForV(45, 'active_partial_end_v');
      active.actual_start_time = Date.now() - 60_000;
      const pending = createEventForV(46, 'still_pending_v');
      bundle.host.events = [active, pending];

      // Act
      const ok = await bundle.service.updateActualTime(active.id, 'actual_end_time', Date.now());

      // Assert
      expect(ok).assertTrue();
      expect(bundle.host.planStateMachine.completeCount).assertEqual(0);
      expect(bundle.host.evaluateStatusCount > 0).assertTrue();
      expect(bundle.host.currentPlanStatus).assertEqual(PlanStatus.READY);
    });

    it('boundary: timeline_execution_skip_and_reopen_should_short_circuit_for_archived_or_missing_targets', 0, async () => {
      // Arrange
      const archivedBundle = createBundleForV();
      archivedBundle.host.isArchived = true;
      const archivedTarget = createEventForV(36, 'archived_skip_v');
      archivedBundle.host.events = [archivedTarget];
      const missingBundle = createBundleForV();

      // Act
      await archivedBundle.service.skipEvent(archivedTarget);
      const archivedReopenOk = await archivedBundle.service.reopenSkippedEvent(archivedTarget.id);
      const missingReopenOk = await missingBundle.service.reopenSkippedEvent(999);

      // Assert
      expect(archivedBundle.host.transitionCallCount).assertEqual(0);
      expect(archivedBundle.host.recalculateCallCount).assertEqual(0);
      expect(archivedReopenOk).assertFalse();
      expect(missingReopenOk).assertFalse();
    });

    it('invalid: timeline_execution_reopen_should_return_false_when_runtime_transition_rejects_without_throwing', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const skippedTarget = createEventForV(47, 'reopen_rejected_v');
      skippedTarget.completion_status = EventEntity.STATE_SKIPPED;
      bundle.host.events = [skippedTarget];
      bundle.host.transitionShouldSucceed = false;

      // Act
      const reopenOk = await bundle.service.reopenSkippedEvent(skippedTarget.id);

      // Assert
      expect(reopenOk).assertFalse();
      expect(bundle.host.transitionCallCount).assertEqual(0);
      expect(bundle.host.recalculateCallCount).assertEqual(0);
      expect(skippedTarget.completion_status).assertEqual(EventEntity.STATE_SKIPPED);
    });

    it('invalid: timeline_execution_reopen_and_update_should_rollback_when_transition_or_target_is_invalid', 0, async () => {
      // Arrange
      const reopenBundle = createBundleForV();
      const skippedTarget = createEventForV(37, 'throw_reopen_v');
      skippedTarget.completion_status = EventEntity.STATE_SKIPPED;
      reopenBundle.host.events = [skippedTarget];
      reopenBundle.host.shouldThrowTransition = true;

      const updateBundle = createBundleForV();
      const nonPendingTarget = createEventForV(38, 'non_pending_start_v');
      nonPendingTarget.completion_status = EventEntity.STATE_COMPLETED;
      updateBundle.host.events = [nonPendingTarget];
      const hooks = new StaticHooksForV();
      hooks.setFindGlobalActiveEvent(async (_excludeEventId: number): Promise<Object | null> => null);

      try {
        // Act
        const reopenOk = await reopenBundle.service.reopenSkippedEvent(skippedTarget.id);
        const missingUpdateOk = await updateBundle.service.updateActualTime(999, 'actual_end_time', Date.now());
        const nonPendingStartOk = await updateBundle.service.updateActualTime(
          nonPendingTarget.id,
          'actual_start_time',
          Date.now()
        );

        // Assert
        expect(reopenOk).assertFalse();
        expect(missingUpdateOk).assertFalse();
        expect(nonPendingStartOk).assertFalse();
        expect(updateBundle.host.transitionCallCount).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('regression: td-20260516-timeline-execution-forecast-should-show-placeholder-before-any-start', 0, () => {
      // Arrange
      const bundle = createBundleForV();
      bundle.host.planStartDate = new Date('2026-05-16T00:00:00.000Z').getTime();
      const first = createEventForV(39, 'first_planned_v');
      first.computed_time = '2026-05-16 09:00';
      first.duration = 30;
      const second = createEventForV(40, 'anchored_v');
      second.computed_time = '2026-05-16 09:20';
      second.fixed_start_time = '10:00';
      second.duration = 45;
      second.pre_travel_min = 10;
      bundle.host.events = [first, second];

      // Act
      bundle.service.calculateRealtimeSchedule();

      // Assert
      expect(first.forecast_start_time).assertEqual('xxxx');
      expect(first.forecast_end_time).assertEqual('xxxx');
      expect(second.forecast_start_time).assertEqual('xxxx');
      expect(second.forecast_end_time).assertEqual('xxxx');
      expect(second.dynamic_start_time > first.dynamic_end_time).assertTrue();
      expect(second.dynamic_start_time >= first.dynamic_end_time + 10 * 60 * 1000).assertTrue();
    });

    it('combined: timeline_execution_realtime_schedule_should_advance_cursor_and_keep_forecast_for_mixed_states', 0, () => {
      // Arrange
      const bundle = createBundleForV();
      bundle.host.planStartDate = new Date('2026-05-17T00:00:00.000Z').getTime();
      const first = createEventForV(48, 'started_anchor_v');
      first.actual_start_time = new Date('2026-05-17T09:00:00.000Z').getTime();
      first.duration = 30;
      first.actual_end_time = new Date('2026-05-17T09:30:00.000Z').getTime();
      first.completion_status = EventEntity.STATE_COMPLETED;
      const second = createEventForV(49, 'travel_pending_v');
      second.pre_travel_min = 20;
      second.duration = 40;
      const third = createEventForV(50, 'skipped_tail_v');
      third.pre_travel_min = 15;
      third.duration = 25;
      third.completion_status = EventEntity.STATE_SKIPPED;
      bundle.host.events = [first, second, third];

      // Act
      bundle.service.calculateRealtimeSchedule();

      // Assert
      expect(bundle.host.conflictList.length).assertEqual(0);
      expect(second.dynamic_start_time).assertEqual(first.actual_end_time + 20 * 60 * 1000);
      expect(second.dynamic_end_time).assertEqual(second.dynamic_start_time + 40 * 60 * 1000);
      expect(third.dynamic_start_time).assertEqual(second.dynamic_end_time + 15 * 60 * 1000);
      expect(second.forecast_start_time === 'xxxx').assertFalse();
      expect(third.forecast_end_time === 'xxxx').assertFalse();
    });

    it('boundary: timeline_execution_realtime_schedule_should_respect_actual_start_on_non_first_event', 0, () => {
      // Arrange
      const bundle = createBundleForV();
      bundle.host.planStartDate = new Date('2026-05-18T00:00:00.000Z').getTime();
      const first = createEventForV(52, 'first_cursor_v');
      first.actual_start_time = new Date('2026-05-18T08:00:00.000Z').getTime();
      first.actual_end_time = new Date('2026-05-18T08:20:00.000Z').getTime();
      first.completion_status = EventEntity.STATE_COMPLETED;
      const second = createEventForV(53, 'second_actual_v');
      second.actual_start_time = new Date('2026-05-18T09:10:00.000Z').getTime();
      second.duration = 35;
      const third = createEventForV(54, 'third_follow_v');
      third.pre_travel_min = 10;
      third.duration = 20;
      bundle.host.events = [first, second, third];

      // Act
      bundle.service.calculateRealtimeSchedule();

      // Assert
      expect(second.dynamic_start_time).assertEqual(second.actual_start_time);
      expect(second.dynamic_end_time).assertEqual(second.actual_start_time + 35 * 60 * 1000);
      expect(third.dynamic_start_time).assertEqual(second.dynamic_end_time + 10 * 60 * 1000);
      expect(third.dynamic_end_time).assertEqual(third.dynamic_start_time + 20 * 60 * 1000);
    });

    it('combined: timeline_execution_skip_should_ignore_completed_items_and_conflict_lookup_should_return_null', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const completedTarget = createEventForV(41, 'completed_skip_v');
      completedTarget.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [completedTarget];
      const hooks = new StaticHooksForV();
      hooks.setFindGlobalActiveEvent(async (_excludeEventId: number): Promise<Object | null> => null);

      try {
        // Act
        await bundle.service.skipEvent(completedTarget);
        const conflict = await bundle.service.getStartConflictInfo(completedTarget.id);

        // Assert
        expect(bundle.host.transitionCallCount).assertEqual(0);
        expect(bundle.host.recalculateCallCount).assertEqual(0);
        expect(conflict === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('boundary: timeline_execution_skip_should_recalculate_when_target_has_no_persisted_id', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const transientTarget = createEventForV(55, 'transient_skip_v');
      transientTarget.id = 0;
      transientTarget.dynamic_start_time = Date.now() + 30 * 60 * 1000;
      bundle.host.events = [transientTarget];

      // Act
      await bundle.service.skipEvent(transientTarget);

      // Assert
      expect(bundle.host.transitionCallCount).assertEqual(0);
      expect(bundle.host.recalculateCallCount).assertEqual(1);
      expect(bundle.host.latestReflowHint !== null).assertTrue();
      expect(bundle.host.checkinCount).assertEqual(1);
    });

    it('invalid: timeline_execution_update_actual_end_should_return_false_when_runtime_transition_rejects', 0, async () => {
      // Arrange
      const bundle = createBundleForV();
      const target = createEventForV(51, 'end_rejected_v');
      target.actual_start_time = Date.now() - 30_000;
      bundle.host.events = [target];
      bundle.host.transitionShouldSucceed = false;

      // Act
      const ok = await bundle.service.updateActualTime(target.id, 'actual_end_time', Date.now());

      // Assert
      expect(ok).assertFalse();
      expect(bundle.host.transitionCallCount).assertEqual(0);
      expect(bundle.host.recalculateCallCount).assertEqual(0);
      expect(bundle.host.actualTimeMutationInFlight).assertFalse();
      expect(target.actual_end_time).assertEqual(0);
    });
  });
}
