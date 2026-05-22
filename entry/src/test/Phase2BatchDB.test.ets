import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { TimelineCalculationService } from '../main/ets/domain/timeline/services/TimelineCalculationService';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import {
  ITimelineRecalculationHost,
  TimelineRecalculationManager
} from '../main/ets/viewmodel/managers/TimelineRecalculationManager';
import { ApplyResultFlags, SolverCalculatedItem } from '../main/ets/viewmodel/types/TimelineTypes';

interface CalcResultDB {
  hasFieldChanged: boolean;
  hasDayOffsetChanged: boolean;
}

class StaticPatchDB {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

class RecalculationHostDB implements ITimelineRecalculationHost {
  events: EventEntity[] = [];
  planId: number = 9101;
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 22).getTime();
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;
  currentStrategyMode: number = 0;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;

  calculateRealtimeCalls: number = 0;
  regenerateGroupsCalls: number = 0;
  markChangedCalls: number = 0;
  refreshCalls: number = 0;

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return item.id === 1;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new ScheduleOrchestrator();
  }

  calculateRealtimeSchedule(): void {
    this.calculateRealtimeCalls += 1;
  }

  regenerateGroups(): void {
    this.regenerateGroupsCalls += 1;
  }

  markScheduleChanged(): void {
    this.markChangedCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshCalls += 1;
  }
}

function buildScheduleEventDB(id: number, sortOrder: number): EventEntity {
  const event = new EventEntity(`db-event-${id}`, 60);
  event.id = id;
  event.status = 1;
  event.sort_order = sortOrder;
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.fixed_start_time = '09:00';
  event.computed_time = '09:00';
  event.pre_travel_min = -1;
  event.is_travel_manual = 0;
  event.lock_status = 0;
  return event;
}

export default function phase2BatchDBTest() {
  describe('phase2BatchDBTest', () => {
    it('normal: recalculate_should_execute_solver_apply_result_callback', 0, () => {
      // Arrange
      const host = new RecalculationHostDB();
      const target = buildScheduleEventDB(2, 200);
      host.events = [buildScheduleEventDB(1, 100), target];
      let callbackCalls = 0;
      let persistedCalls = 0;
      const repoPatch = new StaticPatchDB(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
        persistedCalls += 1;
      });
      const calcPatch = new StaticPatchDB(TimelineCalculationService, 'recalculate', (
        events: EventEntity[],
        _globalStartTime: string,
        _planStartDate: number,
        _orchestrator: ScheduleOrchestrator,
        _options: Object,
        applyResult: (entity: EventEntity, calculated: SolverCalculatedItem | undefined) => ApplyResultFlags
      ): CalcResultDB => {
        callbackCalls += 1;
        const calculated: SolverCalculatedItem = {
          computedStartTime: '10:20',
          preTravelMinutes: 18,
          isConflict: true,
          conflictMsg: 'db conflict',
          hasGap: true,
          gapMinutes: 22,
          naturalStartTime: '10:00',
          transitWarning: true,
          dayOffset: 1,
          dynamicDayOffset: 1,
          dynamicStartTime: 1000,
          dynamicEndTime: 2000
        };
        const flags = applyResult(events[1], calculated);
        return { hasFieldChanged: flags.changed, hasDayOffsetChanged: flags.dayOffsetChanged };
      });
      const manager = new TimelineRecalculationManager(host);

      // Act
      manager.recalculate();
      calcPatch.restore();
      repoPatch.restore();

      // Assert
      expect(callbackCalls).assertEqual(1);
      expect(target.computed_time).assertEqual('10:20');
      expect(target.pre_travel_min).assertEqual(18);
      expect(target.is_conflict).assertTrue();
      expect(target.dynamic_day_offset).assertEqual(1);
      expect(host.refreshCalls).assertEqual(1);
      expect(persistedCalls).assertEqual(1);
    });

    it('regression: recalculate_traffic_only_should_execute_auto_pretravel_callback', 0, () => {
      // Arrange
      const host = new RecalculationHostDB();
      const target = buildScheduleEventDB(3, 300);
      host.events = [buildScheduleEventDB(1, 100), target];
      let callbackCalls = 0;
      let persistedCalls = 0;
      const repoPatch = new StaticPatchDB(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
        persistedCalls += 1;
      });
      const calcPatch = new StaticPatchDB(TimelineCalculationService, 'recalculateTrafficOnly', (
        events: EventEntity[],
        _globalStartTime: string,
        _planStartDate: number,
        _orchestrator: ScheduleOrchestrator,
        _options: Object,
        persistPreTravel: (entity: EventEntity, minutes: number) => void
      ): CalcResultDB => {
        callbackCalls += 1;
        persistPreTravel(events[1], 24);
        return { hasFieldChanged: true, hasDayOffsetChanged: true };
      });
      const manager = new TimelineRecalculationManager(host);

      // Act
      manager.recalculateTrafficOnly();
      calcPatch.restore();
      repoPatch.restore();

      // Assert
      expect(callbackCalls).assertEqual(1);
      expect(persistedCalls).assertEqual(1);
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
      expect(host.refreshCalls).assertEqual(1);
    });

    it('boundary: recalculate_should_clear_unscheduled_fields_when_solver_result_missing', 0, () => {
      // Arrange
      const host = new RecalculationHostDB();
      const target = buildScheduleEventDB(4, 400);
      target.status = 0;
      target.is_conflict = true;
      target.computed_time = '11:30';
      target.has_gap = true;
      target.gap_minutes = 14;
      target.natural_start_time = '11:10';
      target.transit_warning = true;
      target.day_offset = 1;
      target.dynamic_day_offset = 3;
      host.events = [target];
      let callbackFlags: ApplyResultFlags = { changed: false, dayOffsetChanged: false };
      const calcPatch = new StaticPatchDB(TimelineCalculationService, 'recalculate', (
        events: EventEntity[],
        _globalStartTime: string,
        _planStartDate: number,
        _orchestrator: ScheduleOrchestrator,
        _options: Object,
        applyResult: (entity: EventEntity, calculated: SolverCalculatedItem | undefined) => ApplyResultFlags
      ): CalcResultDB => {
        callbackFlags = applyResult(events[0], undefined);
        return { hasFieldChanged: callbackFlags.changed, hasDayOffsetChanged: callbackFlags.dayOffsetChanged };
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculate();
      calcPatch.restore();
      // Assert
      expect(callbackFlags.changed).assertTrue();
      expect(callbackFlags.dayOffsetChanged).assertTrue();
      expect(target.is_conflict).assertFalse();
      expect(target.computed_time).assertEqual('');
      expect(target.has_gap).assertFalse();
      expect(target.gap_minutes).assertEqual(0);
      expect(target.natural_start_time).assertEqual('');
      expect(target.transit_warning).assertFalse();
      expect(target.dynamic_day_offset).assertEqual(1);
    });

    it('invalid: recalculate_should_keep_fixed_start_when_item_locked', 0, () => {
      // Arrange
      const host = new RecalculationHostDB();
      const target = buildScheduleEventDB(5, 500);
      target.fixed_start_time = '09:15';
      target.lock_status = 1;
      host.events = [target];
      const calcPatch = new StaticPatchDB(TimelineCalculationService, 'recalculate', (
        events: EventEntity[],
        _globalStartTime: string,
        _planStartDate: number,
        _orchestrator: ScheduleOrchestrator,
        _options: Object,
        applyResult: (entity: EventEntity, calculated: SolverCalculatedItem | undefined) => ApplyResultFlags
      ): CalcResultDB => {
        const calculated: SolverCalculatedItem = {
          computedStartTime: '2026-04-22 13:40',
          dynamicDayOffset: 2,
          dynamicStartTime: 3000,
          dynamicEndTime: 6000
        };
        const flags = applyResult(events[0], calculated);
        return { hasFieldChanged: flags.changed, hasDayOffsetChanged: flags.dayOffsetChanged };
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculate();
      calcPatch.restore();
      // Assert
      expect(target.computed_time).assertEqual('2026-04-22 13:40');
      expect(target.fixed_start_time).assertEqual('09:15');
      expect(target.dynamic_day_offset).assertEqual(2);
    });

    it('conflict: recalculate_traffic_only_should_skip_persist_for_manual_and_first_items', 0, () => {
      // Arrange
      const host = new RecalculationHostDB();
      const first = buildScheduleEventDB(1, 100);
      const manual = buildScheduleEventDB(6, 600);
      manual.is_travel_manual = 1;
      const invalid = buildScheduleEventDB(0, 700);
      host.events = [first, manual, invalid];
      let persistedCalls = 0;
      const repoPatch = new StaticPatchDB(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
        persistedCalls += 1;
      });
      const calcPatch = new StaticPatchDB(TimelineCalculationService, 'recalculateTrafficOnly', (
        events: EventEntity[],
        _globalStartTime: string,
        _planStartDate: number,
        _orchestrator: ScheduleOrchestrator,
        _options: Object,
        persistPreTravel: (entity: EventEntity, minutes: number) => void
      ): CalcResultDB => {
        persistPreTravel(events[0], 12);
        persistPreTravel(events[1], 12);
        persistPreTravel(events[2], -1);
        return { hasFieldChanged: true, hasDayOffsetChanged: false };
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateTrafficOnly();
      calcPatch.restore();
      repoPatch.restore();
      // Assert
      expect(persistedCalls).assertEqual(0);
      expect(host.refreshCalls).assertEqual(1);
    });

    it('combined: recalculate_from_index_should_only_reset_schedulable_zero_pretravel_items', 0, () => {
      // Arrange
      const host = new RecalculationHostDB();
      const first = buildScheduleEventDB(1, 100);
      first.pre_travel_min = 0;
      const autoRoute = buildScheduleEventDB(8, 800);
      autoRoute.pre_travel_min = 0;
      const manual = buildScheduleEventDB(9, 900);
      manual.pre_travel_min = 0;
      manual.is_travel_manual = 1;
      const backlog = buildScheduleEventDB(10, 1000);
      backlog.status = 0;
      backlog.pre_travel_min = 0;
      host.events = [first, autoRoute, manual, backlog];
      let capturedAuto = 0;
      let capturedFirst = 0;
      let capturedManual = 0;
      let capturedBacklog = 0;
      const calcPatch = new StaticPatchDB(TimelineCalculationService, 'recalculateFromIndex', (
        events: EventEntity[]
      ): CalcResultDB => {
        capturedFirst = events[0].pre_travel_min;
        capturedAuto = events[1].pre_travel_min;
        capturedManual = events[2].pre_travel_min;
        capturedBacklog = events[3].pre_travel_min;
        return { hasFieldChanged: false, hasDayOffsetChanged: false };
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateFromIndex(0);
      calcPatch.restore();
      // Assert
      expect(capturedFirst).assertEqual(0);
      expect(capturedAuto).assertEqual(-1);
      expect(capturedManual).assertEqual(0);
      expect(capturedBacklog).assertEqual(0);
    });
  });
}
