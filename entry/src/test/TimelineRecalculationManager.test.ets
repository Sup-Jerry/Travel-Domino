import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineRecalculationManager, ITimelineRecalculationHost } from '../main/ets/viewmodel/managers/TimelineRecalculationManager';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import {
  RecalculateResult,
  TimelineCalculationService
} from '../main/ets/domain/timeline/services/TimelineCalculationService';
import { ApplyResultFlags, SolverCalculatedItem } from '../main/ets/viewmodel/types/TimelineTypes';

class FakeTimelineRecalculationHost implements ITimelineRecalculationHost {
  events: EventEntity[] = [];
  planId: number = 100;
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 12).getTime();
  idleGapDetectionEnabled: boolean = false;
  idleGapTriggerMinutes: number = 20;
  currentStrategyMode: number = 0;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;

  calculateRealtimeCount: number = 0;
  regenerateGroupsCount: number = 0;
  markScheduleChangedCount: number = 0;
  refreshCount: number = 0;
  firstIds: number[] = [];

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return this.firstIds.indexOf(item.id) >= 0;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new ScheduleOrchestrator();
  }

  calculateRealtimeSchedule(): void {
    this.calculateRealtimeCount += 1;
  }

  regenerateGroups(): void {
    this.regenerateGroupsCount += 1;
  }

  markScheduleChanged(): void {
    this.markScheduleChangedCount += 1;
  }

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }
}

function createScheduleEvent(id: number, name: string, sortOrder: number, preTravel: number): EventEntity {
  const item = new EventEntity(name, 30);
  item.id = id;
  item.status = 1;
  item.sort_order = sortOrder;
  item.day_offset = 0;
  item.dynamic_day_offset = 0;
  item.pre_travel_min = preTravel;
  item.is_travel_manual = 0;
  item.fixed_start_time = '09:00';
  return item;
}

interface TimelineRecalculationApplyResultTest extends ApplyResultFlags {}

interface TimelineRecalculationManagerPrivateTest {
  updateTravelMode(item: EventEntity, newMode: number): void;
  recalculate(): void;
  completionStatusLabel(status: number): string;
  resolveRecalculateStartIndexByEventId(eventId: number): number;
  resolveScheduleAnchorEventId(startIndex: number): number;
  applyCalculatedResult(
    entity: EventEntity,
    resultItem: SolverCalculatedItem | undefined
  ): TimelineRecalculationApplyResultTest;
}

class StaticMethodPatchTimelineRecalc {
  private readonly target: Object;
  private readonly key: string;
  private readonly origin: Object;

  constructor(target: Object, key: string, next: Object) {
    this.target = target;
    this.key = key;
    this.origin = Reflect.get(target, key) as Object;
    Reflect.set(this.target, this.key, next);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.origin);
  }
}

export default function timelineRecalculationManagerTest() {
  describe('timelineRecalculationManagerTest', () => {
    it('normal: resolve_effective_global_start_minutes_should_parse_valid_time', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      host.globalStartTime = '09:30';
      const manager = new TimelineRecalculationManager(host);
      // Act
      const minutes = manager.resolveEffectiveGlobalStartMinutes();
      // Assert
      expect(minutes).assertEqual(570);
    });

    it('boundary: resolve_effective_global_start_minutes_should_extract_time_from_datetime_text', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      host.globalStartTime = '03-17 06:05';
      const manager = new TimelineRecalculationManager(host);
      // Act
      const minutes = manager.resolveEffectiveGlobalStartMinutes();
      // Assert
      expect(minutes).assertEqual(365);
    });

    it('invalid: resolve_effective_global_start_minutes_should_fallback_to_0800', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      host.globalStartTime = 'invalid-time';
      const manager = new TimelineRecalculationManager(host);
      // Act
      const minutes = manager.resolveEffectiveGlobalStartMinutes();
      // Assert
      expect(minutes).assertEqual(480);
    });

    it('conflict: update_travel_mode_should_keep_first_schedule_manual_pretravel_zero', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      const first = createScheduleEvent(1, 'first', 100, -1);
      host.events = [first];
      host.firstIds = [1];
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.updateTravelMode(first, 3);
      // Assert
      expect(first.travel_mode).assertEqual(3);
      expect(first.transport_mode).assertEqual(3);
      expect(first.is_travel_manual).assertEqual(0);
      expect(first.pre_travel_min).assertEqual(0);
    });

    it('regression: td-20260412-c4-update-travel-mode-should-reset-auto-pretravel-for-non-first-node', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      const first = createScheduleEvent(11, 'first', 100, 0);
      const second = createScheduleEvent(12, 'second', 200, 15);
      host.events = [first, second];
      host.firstIds = [11];
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.updateTravelMode(second, 2);
      // Assert
      expect(second.travel_mode).assertEqual(2);
      expect(second.pre_travel_min !== 15).assertTrue();
      expect(second.is_travel_manual).assertEqual(0);
    });

    it('combined: update_travel_mode_should_keep_zero_pretravel_when_auto_route_disabled', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      host.enableGlobalAmapRouteApi = false;
      const item = createScheduleEvent(21, 'museum', 100, -1);
      host.events = [item];
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.updateTravelMode(item, 1);
      // Assert
      expect(item.travel_mode).assertEqual(1);
      expect(item.pre_travel_min).assertEqual(0);
      expect(host.refreshCount >= 0).assertTrue();
    });

    it('combined: private_helpers_should_cover_completion_labels_start_index_and_anchor_resolution', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      const backlog = new EventEntity('backlog', 15);
      backlog.id = 1;
      backlog.status = 0;
      const scheduleA = createScheduleEvent(10, 'scheduleA', 100, 5);
      const midBacklog = new EventEntity('midBacklog', 20);
      midBacklog.id = 11;
      midBacklog.status = 0;
      const scheduleB = createScheduleEvent(12, 'scheduleB', 200, 10);
      host.events = [backlog, scheduleA, midBacklog, scheduleB];
      const manager = new TimelineRecalculationManager(host) as Object as TimelineRecalculationManagerPrivateTest;

      // Act
      const completed = manager.completionStatusLabel(EventEntity.STATE_COMPLETED);
      const skipped = manager.completionStatusLabel(EventEntity.STATE_SKIPPED);
      const pending = manager.completionStatusLabel(0);
      const nonPositiveIndex = manager.resolveRecalculateStartIndexByEventId(0);
      const missingIndex = manager.resolveRecalculateStartIndexByEventId(999);
      const scheduleStartIndex = manager.resolveRecalculateStartIndexByEventId(12);
      const anchorFromNegative = manager.resolveScheduleAnchorEventId(-5);
      const anchorMissing = manager.resolveScheduleAnchorEventId(10);

      // Assert
      expect(completed).assertEqual('COMPLETED');
      expect(skipped).assertEqual('SKIPPED');
      expect(pending).assertEqual('PENDING');
      expect(nonPositiveIndex).assertEqual(0);
      expect(missingIndex).assertEqual(0);
      expect(scheduleStartIndex).assertEqual(1);
      expect(anchorFromNegative).assertEqual(10);
      expect(anchorMissing).assertEqual(-1);
    });

    it('combined: recalculate_and_apply_result_should_cover_repeat_noop_and_cleanup_branches', 0, () => {
      // Arrange
      const host = new FakeTimelineRecalculationHost();
      const schedule = createScheduleEvent(31, 'schedule', 100, 12);
      schedule.is_conflict = true;
      schedule.conflict_msg = 'stale';
      schedule.computed_time = '09:30';
      schedule.has_gap = true;
      schedule.gap_minutes = 15;
      schedule.natural_start_time = '09:20';
      schedule.transit_warning = true;
      schedule.dynamic_day_offset = 1;
      schedule.day_offset = 1;
      schedule.dynamic_start_time = 100;
      schedule.dynamic_end_time = 200;
      schedule.lock_status = 1;
      schedule.fixed_start_time = '09:30';

      const unscheduledDirty = new EventEntity('dirty', 20);
      unscheduledDirty.id = 32;
      unscheduledDirty.status = 0;
      unscheduledDirty.is_conflict = true;
      unscheduledDirty.computed_time = '10:00';
      unscheduledDirty.has_gap = true;
      unscheduledDirty.gap_minutes = 8;
      unscheduledDirty.natural_start_time = '09:55';
      unscheduledDirty.transit_warning = true;
      unscheduledDirty.day_offset = 2;
      unscheduledDirty.dynamic_day_offset = 3;

      const unscheduledClean = new EventEntity('clean', 20);
      unscheduledClean.id = 33;
      unscheduledClean.status = 0;
      unscheduledClean.day_offset = 4;
      unscheduledClean.dynamic_day_offset = 4;

      host.events = [schedule, unscheduledDirty, unscheduledClean];
      const manager = new TimelineRecalculationManager(host) as Object as TimelineRecalculationManagerPrivateTest;
      const recalcPatch = new StaticMethodPatchTimelineRecalc(
        TimelineCalculationService as Object,
        'recalculate',
        (
          _events: EventEntity[],
          _globalStartTime: string,
          _planStartDate: number,
          _orchestrator: ScheduleOrchestrator,
          _options: Object,
          _apply: Object
        ): RecalculateResult => {
          const result: RecalculateResult = {
            hasFieldChanged: false,
            hasDayOffsetChanged: false
          };
          return result;
        }
      );

      const unchangedResult = {
        isConflict: true,
        conflictMsg: 'stale',
        computedStartTime: '09:30',
        preTravelMinutes: 12,
        hasGap: true,
        gapMinutes: 15,
        naturalStartTime: '09:20',
        transitWarning: true,
        dynamicDayOffset: 1,
        dynamicStartTime: 100,
        dynamicEndTime: 200
      } as SolverCalculatedItem;

      try {
        // Act
        manager.recalculate();
        manager.recalculate();
        const unchangedFlags = manager.applyCalculatedResult(schedule, unchangedResult);
        const scheduledNoResultFlags = manager.applyCalculatedResult(schedule, undefined);
        const dirtyFlags = manager.applyCalculatedResult(unscheduledDirty, undefined);
        const cleanFlags = manager.applyCalculatedResult(unscheduledClean, undefined);

        // Assert
        expect(host.calculateRealtimeCount).assertEqual(2);
        expect(host.regenerateGroupsCount).assertEqual(2);
        expect(host.markScheduleChangedCount).assertEqual(2);
        expect(host.refreshCount).assertEqual(0);
        expect(unchangedFlags.changed).assertFalse();
        expect(unchangedFlags.dayOffsetChanged).assertFalse();
        expect(scheduledNoResultFlags.changed).assertFalse();
        expect(scheduledNoResultFlags.dayOffsetChanged).assertFalse();
        expect(dirtyFlags.changed).assertTrue();
        expect(dirtyFlags.dayOffsetChanged).assertTrue();
        expect(unscheduledDirty.is_conflict).assertFalse();
        expect(unscheduledDirty.computed_time).assertEqual('');
        expect(unscheduledDirty.has_gap).assertFalse();
        expect(unscheduledDirty.gap_minutes).assertEqual(0);
        expect(unscheduledDirty.natural_start_time).assertEqual('');
        expect(unscheduledDirty.transit_warning).assertFalse();
        expect(unscheduledDirty.dynamic_day_offset).assertEqual(unscheduledDirty.day_offset);
        expect(cleanFlags.changed).assertFalse();
        expect(cleanFlags.dayOffsetChanged).assertFalse();
      } finally {
        recalcPatch.restore();
      }
    });
  });
}
