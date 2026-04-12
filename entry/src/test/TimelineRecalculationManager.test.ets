import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineRecalculationManager, ITimelineRecalculationHost } from '../main/ets/viewmodel/managers/TimelineRecalculationManager';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';

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
  });
}
