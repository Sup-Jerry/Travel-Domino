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

  constructor() {
    this.originFindGlobalActiveEvent = Reflect.get(EventRepositoryImpl, 'findGlobalActiveEvent') as Object;
  }

  setFindGlobalActiveEvent(fn: (excludeEventId: number) => Promise<Object | null>): void {
    Reflect.set(EventRepositoryImpl, 'findGlobalActiveEvent', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'findGlobalActiveEvent', this.originFindGlobalActiveEvent);
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
  });
}
