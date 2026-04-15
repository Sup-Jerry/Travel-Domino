import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ITimelineDistributionHost, TimelineDistributionService } from '../main/ets/domain/timeline/services/TimelineDistributionService';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';

class HostMockForW implements ITimelineDistributionHost {
  events: EventEntity[] = [];
  planId: number = 1;
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;
  updateEventInfoCount: number = 0;
  recalculateStartIndex: number = -1;
  naturalArrivalMap: Map<number, number> = new Map<number, number>();

  getEffectiveDayOffset(item: EventEntity): number {
    return item.day_offset;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return [...this.events].filter((event: EventEntity) => event.status === 1).sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((event: EventEntity) => event.id === eventId);
  }

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    const schedule = this.getOrderedScheduleEvents();
    const sameDay = schedule.filter((event: EventEntity) => event.day_offset === item.day_offset);
    return sameDay.length > 0 && sameDay[0].id === item.id;
  }

  _calculateNaturalArrival(targetIndex: number): number {
    return this.naturalArrivalMap.get(targetIndex) ?? 0;
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateStartIndex = startIndex;
  }

  async updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    _dayOffset?: number
  ): Promise<void> {
    this.updateEventInfoCount++;
  }
}

class StaticHooksForW {
  private readonly originUpdateSingleField: Object;

  constructor() {
    this.originUpdateSingleField = Reflect.get(EventRepositoryImpl, 'updateSingleField') as Object;
  }

  setUpdateSingleField(fn: (id: number, column: string, value: Object, planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', this.originUpdateSingleField);
  }
}

class ServiceBundleForW {
  host: HostMockForW = new HostMockForW();
  service: TimelineDistributionService = new TimelineDistributionService(this.host);
}

function createBundleForW(): ServiceBundleForW {
  return new ServiceBundleForW();
}

function createEventForW(id: number, name: string, dayOffset: number = 0): EventEntity {
  const item = new EventEntity(name, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.duration = 60;
  item.day_offset = dayOffset;
  item.has_gap = false;
  item.gap_minutes = 0;
  item.priority = 0;
  item.lock_status = 0;
  return item;
}

export default function phase2CoreCoverageBatchWTest() {
  describe('phase2CoreCoverageBatchWTest', () => {
    it('normal: timeline_distribution_get_candidates_should_keep_only_same_day_scheduled_items', 0, () => {
      // Arrange
      const bundle = createBundleForW();
      const day0A = createEventForW(1, 'day0_a', 0);
      const day0B = createEventForW(2, 'day0_b', 0);
      const day1 = createEventForW(3, 'day1', 1);
      const gap = createEventForW(4, 'gap', 0);
      gap.has_gap = true;
      gap.gap_minutes = 30;
      bundle.host.events = [day0A, day0B, day1, gap];
      // Act
      const candidates = bundle.service.getDistributionCandidates(gap);
      // Assert
      expect(candidates.length).assertEqual(2);
      expect(candidates[0].id).assertEqual(1);
      expect(candidates[1].id).assertEqual(2);
    });

    it('boundary: timeline_distribution_calculate_preview_smart_should_not_exceed_each_candidate_cap', 0, () => {
      // Arrange
      const bundle = createBundleForW();
      const c1 = createEventForW(10, 'c1');
      const locked = createEventForW(11, 'locked');
      locked.lock_status = 1;
      locked.fixed_start_time = '12:00';
      const c2 = createEventForW(12, 'c2');
      const gap = createEventForW(13, 'gap');
      gap.has_gap = true;
      gap.gap_minutes = 90;
      c1.duration = 80;
      c2.duration = 200;
      c1.priority = 1;
      c2.priority = 0;
      bundle.host.events = [c1, locked, c2, gap];
      bundle.host.naturalArrivalMap.set(1, 710); // 11:50
      // Act
      const preview = bundle.service.calculateDistributionPreview(gap, [c1, c2], new Set<number>([10, 12]), 'SMART');
      const cap1 = bundle.service.getSafetyCap(c1, gap);
      const cap2 = bundle.service.getSafetyCap(c2, gap);
      const add1 = preview.get(10) ?? 0;
      const add2 = preview.get(12) ?? 0;
      // Assert
      expect(add1 <= cap1).assertTrue();
      expect(add2 <= cap2).assertTrue();
      expect(add1 + add2 <= gap.gap_minutes).assertTrue();
    });

    it('invalid: timeline_distribution_get_safety_cap_should_return_zero_when_candidate_not_before_gap', 0, () => {
      // Arrange
      const bundle = createBundleForW();
      const candidate = createEventForW(20, 'candidate');
      const gap = createEventForW(21, 'gap');
      gap.has_gap = true;
      gap.gap_minutes = 45;
      bundle.host.events = [gap, candidate];
      // Act
      const cap = bundle.service.getSafetyCap(candidate, gap);
      // Assert
      expect(cap).assertEqual(0);
    });

    it('conflict: timeline_distribution_get_sorted_gaps_should_filter_disabled_and_day_start_entries', 0, () => {
      // Arrange
      const bundle = createBundleForW();
      const first = createEventForW(30, 'first');
      first.has_gap = true;
      first.gap_minutes = 50;
      const second = createEventForW(31, 'second');
      second.has_gap = true;
      second.gap_minutes = 40;
      bundle.host.events = [first, second];
      bundle.host.idleGapDetectionEnabled = false;
      // Act
      const disabled = bundle.service.getSortedGaps();
      bundle.host.idleGapDetectionEnabled = true;
      const enabled = bundle.service.getSortedGaps();
      // Assert
      expect(disabled.length).assertEqual(0);
      expect(enabled.length).assertEqual(1);
      expect(enabled[0].id).assertEqual(31);
    });

    it('regression: td-20260415-resolve-gap-by-distribution-should-stop-at-locked-and-recalculate-from-earliest-candidate', 0, async () => {
      // Arrange
      const bundle = createBundleForW();
      const hooks = new StaticHooksForW();
      hooks.setUpdateSingleField(async (_id: number, _column: string, _value: Object, _planIdHint?: number): Promise<void> => {
        return;
      });
      const earliest = createEventForW(40, 'earliest');
      const locked = createEventForW(42, 'locked');
      locked.lock_status = 1;
      const mid = createEventForW(41, 'mid');
      const gap = createEventForW(43, 'gap');
      gap.has_gap = true;
      gap.gap_minutes = 50;
      bundle.host.events = [earliest, locked, mid, gap];
      const oldEarliestDuration = earliest.duration;
      const oldMidDuration = mid.duration;
      // Act
      await bundle.service.resolveGapByDistribution(gap);
      hooks.restore();
      // Assert
      expect(earliest.duration).assertEqual(oldEarliestDuration);
      expect(mid.duration > oldMidDuration).assertTrue();
      expect(bundle.host.recalculateStartIndex).assertEqual(1);
    });

    it('combined: timeline_distribution_apply_distribution_and_sync_should_cover_apply_recalculate_previous_name_and_sync_update', 0, async () => {
      // Arrange
      const bundle = createBundleForW();
      const hooks = new StaticHooksForW();
      hooks.setUpdateSingleField(async (_id: number, _column: string, _value: Object, _planIdHint?: number): Promise<void> => {
        return;
      });
      const prev = createEventForW(50, 'prev');
      const gap = createEventForW(51, 'gap');
      gap.day_offset = 0;
      gap.has_gap = true;
      gap.gap_minutes = 20;
      gap.natural_start_time = '10:30';
      const nextDay = createEventForW(52, 'next_day', 1);
      bundle.host.events = [prev, gap, nextDay];
      const dist = new Map<number, number>();
      dist.set(50, 15);
      dist.set(52, 0);
      // Act
      await bundle.service.applyDistribution(dist);
      const prevName = bundle.service.getPreviousItemName(nextDay);
      bundle.service.resolveGapBySync(gap);
      hooks.restore();
      // Assert
      expect(prev.duration).assertEqual(75);
      expect(bundle.host.recalculateStartIndex).assertEqual(0);
      expect(prevName).assertEqual('当日开始');
      expect(bundle.host.updateEventInfoCount).assertEqual(1);
    });
  });
}
