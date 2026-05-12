import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  ITimelineDistributionHost,
  TimelineDistributionService
} from '../main/ets/domain/timeline/services/TimelineDistributionService';

class DistributionHostDC implements ITimelineDistributionHost {
  events: EventEntity[] = [];
  planId: number = 9201;
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;
  recalculateCalls: number = 0;

  getEffectiveDayOffset(item: EventEntity): number {
    return item.day_offset;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events.filter((item: EventEntity) => item.status === 1);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((item: EventEntity) => item.id === eventId);
  }

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    const sameDay = this.getOrderedScheduleEvents().filter((candidate: EventEntity) => {
      return candidate.day_offset === item.day_offset;
    });
    return sameDay.length > 0 && sameDay[0].id === item.id;
  }

  _calculateNaturalArrival(_targetIndex: number): number {
    return 0;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateCalls += 1;
  }

  async updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    _dayOffset?: number
  ): Promise<void> {
    return;
  }
}

function buildDistributionEventDC(id: number, dayOffset: number, gapMinutes: number): EventEntity {
  const event = new EventEntity(`dc-event-${id}`, 60);
  event.id = id;
  event.status = 1;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dayOffset;
  event.sort_order = id * 100;
  event.has_gap = gapMinutes > 0;
  event.gap_minutes = gapMinutes;
  return event;
}

export default function phase2BatchDCTest() {
  describe('phase2BatchDCTest', () => {
    it('normal: distribution_sorted_gaps_should_sort_multiple_same_day_gaps_descending', 0, () => {
      // Arrange
      const host = new DistributionHostDC();
      const first = buildDistributionEventDC(1, 0, 0);
      const smallerGap = buildDistributionEventDC(2, 0, 35);
      const largerGap = buildDistributionEventDC(3, 0, 55);
      const crossDayGap = buildDistributionEventDC(4, 1, 80);
      host.events = [first, smallerGap, largerGap, crossDayGap];
      const service = new TimelineDistributionService(host);

      // Act
      const gaps = service.getSortedGaps();

      // Assert
      expect(gaps.length).assertEqual(2);
      expect(gaps[0].id).assertEqual(3);
      expect(gaps[1].id).assertEqual(2);
      expect(host.recalculateCalls).assertEqual(0);
    });

    it('boundary: distribution_sorted_gaps_should_return_empty_when_detection_disabled', 0, () => {
      // Arrange
      const host = new DistributionHostDC();
      host.idleGapDetectionEnabled = false;
      host.events = [buildDistributionEventDC(1, 0, 40), buildDistributionEventDC(2, 0, 60)];
      const service = new TimelineDistributionService(host);

      // Act
      const gaps = service.getSortedGaps();

      // Assert
      expect(gaps.length).assertEqual(0);
    });
  });
}
