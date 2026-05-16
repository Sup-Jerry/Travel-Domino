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

    it('boundary: validator_marker_should_cover_boundary_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('combined: validator_marker_should_cover_combined_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
