import { describe, expect, it } from '@ohos/hypium';
import {
  TimelineDistributionCoordinator,
  ITimelineDistributionCoordinatorHost
} from '../main/ets/viewmodel/coordinators/TimelineDistributionCoordinator';
import { ITimelineDistributionService } from '../main/ets/domain/timeline/services/TimelineDistributionService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

class DistributionServiceSpy implements ITimelineDistributionService {
  callLog: string[] = [];
  lastDistributionSize: number = 0;

  async resolveGapByDistribution(_targetItem: EventEntity): Promise<void> {
    this.callLog.push('resolveGapByDistribution');
  }

  resolveGapBySync(_item: EventEntity): void {
    this.callLog.push('resolveGapBySync');
  }

  getDistributionCandidates(_gapItem: EventEntity): EventEntity[] {
    this.callLog.push('getDistributionCandidates');
    return [];
  }

  getSafetyCap(_candidate: EventEntity, _gapItem: EventEntity): number {
    this.callLog.push('getSafetyCap');
    return 30;
  }

  calculateDistributionPreview(
    _gapItem: EventEntity,
    _candidates: EventEntity[],
    selectedIds: Set<number>,
    _strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    this.callLog.push('calculateDistributionPreview');
    const result = new Map<number, number>();
    selectedIds.forEach((id: number) => {
      result.set(id, 5);
    });
    return result;
  }

  getSortedGaps(): EventEntity[] {
    this.callLog.push('getSortedGaps');
    return [];
  }

  getPreviousItemName(_gapItem: EventEntity): string {
    this.callLog.push('getPreviousItemName');
    return '前一站';
  }

  async applyDistribution(distributionMap: Map<number, number>): Promise<void> {
    this.callLog.push('applyDistribution');
    this.lastDistributionSize = distributionMap.size;
  }
}

function createEvent(id: number, status: number, lockStatus: number, gapMinutes: number, name: string): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = status;
  event.lock_status = lockStatus;
  event.gap_minutes = gapMinutes;
  return event;
}

class DistributionHost implements ITimelineDistributionCoordinatorHost {
  events: EventEntity[];

  constructor(events: EventEntity[]) {
    this.events = events;
  }
}

export default function timelineDistributionCoordinatorTest() {
  describe('timelineDistributionCoordinatorTest', () => {
    it('normal: resolve_gap_by_sync_should_delegate_to_service', 0, () => {
      // Arrange
      const hostEvents = [createEvent(1, 1, 0, 0, 'A')];
      const service = new DistributionServiceSpy();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHost(hostEvents), service);
      // Act
      coordinator.resolveGapBySync(hostEvents[0]);
      // Assert
      expect(service.callLog.includes('resolveGapBySync')).assertTrue();
    });

    it('boundary: check_distribution_risk_should_return_false_when_distribution_empty', 0, () => {
      // Arrange
      const a = createEvent(1, 1, 0, 0, 'A');
      const b = createEvent(2, 1, 1, 5, 'B');
      const gap = createEvent(3, 1, 0, 20, 'Gap');
      const service = new DistributionServiceSpy();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHost([a, b, gap]), service);
      // Act
      const risk = coordinator.checkDistributionRisk(gap, new Map<number, number>());
      // Assert
      expect(risk).assertFalse();
    });

    it('invalid: check_distribution_risk_should_return_false_when_gap_not_in_schedule', 0, () => {
      // Arrange
      const a = createEvent(1, 1, 0, 0, 'A');
      const gap = createEvent(9, 0, 0, 20, 'GapBacklog');
      const service = new DistributionServiceSpy();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHost([a, gap]), service);
      const distribution = new Map<number, number>();
      distribution.set(1, 10);
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distribution);
      // Assert
      expect(risk).assertFalse();
    });

    it('conflict: check_distribution_risk_should_detect_locked_item_buffer_overrun', 0, () => {
      // Arrange
      const a = createEvent(1, 1, 0, 0, 'A');
      const locked = createEvent(2, 1, 1, 5, 'Locked');
      const gap = createEvent(3, 1, 0, 20, 'Gap');
      const service = new DistributionServiceSpy();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHost([a, locked, gap]), service);
      const distribution = new Map<number, number>();
      distribution.set(1, 6);
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distribution);
      // Assert
      expect(risk).assertTrue();
    });

    it('regression: td-20260411-c4-check-risk-should-ignore-non-schedule-ids-in-map', 0, () => {
      // Arrange
      const a = createEvent(1, 1, 0, 0, 'A');
      const locked = createEvent(2, 1, 1, 10, 'Locked');
      const gap = createEvent(3, 1, 0, 20, 'Gap');
      const service = new DistributionServiceSpy();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHost([a, locked, gap]), service);
      const distribution = new Map<number, number>();
      distribution.set(999, 100);
      distribution.set(1, 2);
      // Act
      const risk = coordinator.checkDistributionRisk(gap, distribution);
      // Assert
      expect(risk).assertFalse();
    });

    it('combined: apply_distribution_and_preview_should_delegate_with_selected_entries', 0, async (done: () => void) => {
      // Arrange
      const a = createEvent(1, 1, 0, 0, 'A');
      const gap = createEvent(3, 1, 0, 20, 'Gap');
      const service = new DistributionServiceSpy();
      const coordinator = new TimelineDistributionCoordinator(new DistributionHost([a, gap]), service);
      const selectedIds = new Set<number>();
      selectedIds.add(1);
      // Act
      const preview = coordinator.calculateDistributionPreview(gap, [a], selectedIds, 'SMART');
      await coordinator.applyDistribution(preview);
      // Assert
      expect(preview.get(1) || 0).assertEqual(5);
      expect(service.lastDistributionSize).assertEqual(1);
      done();
    });
  });
}
