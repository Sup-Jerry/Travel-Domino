import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../model/entity/EventEntity';
import { ITimelineDistributionService } from '../../domain/timeline/services/TimelineDistributionService';

export interface ITimelineDistributionCoordinatorHost {
  events: EventEntity[];
}

const TAG = 'TimelineViewModel';

export class TimelineDistributionCoordinator {
  private readonly host: ITimelineDistributionCoordinatorHost;
  private readonly distributionService: ITimelineDistributionService;

  constructor(host: ITimelineDistributionCoordinatorHost, distributionService: ITimelineDistributionService) {
    this.host = host;
    this.distributionService = distributionService;
  }

  public async resolveGapByDistribution(targetItem: EventEntity): Promise<void> {
    hilog.info(0x0000, TAG, `[ACPT][GAP][resolveByDistribution] itemId=${targetItem?.id ?? -1}, name=${targetItem?.name ?? ''}`);
    await this.distributionService.resolveGapByDistribution(targetItem);
  }

  public resolveGapBySync(item: EventEntity): void {
    hilog.info(0x0000, TAG, `[ACPT][GAP][resolveBySync] itemId=${item?.id ?? -1}, name=${item?.name ?? ''}`);
    this.distributionService.resolveGapBySync(item);
  }

  public getDistributionCandidates(gapItem: EventEntity): EventEntity[] {
    hilog.info(0x0000, TAG, `[ACPT][GAP][getCandidates] gapItemId=${gapItem?.id ?? -1}, name=${gapItem?.name ?? ''}`);
    return this.distributionService.getDistributionCandidates(gapItem);
  }

  public getSafetyCap(candidate: EventEntity, gapItem: EventEntity): number {
    return this.distributionService.getSafetyCap(candidate, gapItem);
  }

  public calculateDistributionPreview(
    gapItem: EventEntity,
    candidates: EventEntity[],
    selectedIds: Set<number>,
    strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    return this.distributionService.calculateDistributionPreview(gapItem, candidates, selectedIds, strategy);
  }

  public getSortedGaps(): EventEntity[] {
    return this.distributionService.getSortedGaps();
  }

  public getPreviousItemName(gapItem: EventEntity): string {
    return this.distributionService.getPreviousItemName(gapItem);
  }

  public async applyDistribution(distributionMap: Map<number, number>): Promise<void> {
    hilog.info(0x0000, TAG, `[ACPT][GAP][applyDistribution] selected=${distributionMap.size}`);
    await this.distributionService.applyDistribution(distributionMap);
  }

  public checkDistributionRisk(gapItem: EventEntity, distributionMap: Map<number, number>): boolean {
    if (distributionMap.size === 0) {
      return false;
    }

    const allSchedule = this.host.events.filter((event: EventEntity) => event.status === 1);
    const gapIndex = allSchedule.indexOf(gapItem);
    if (gapIndex <= 0) {
      return false;
    }

    let firstModifiedIdx = gapIndex;
    distributionMap.forEach((_, id) => {
      const index = allSchedule.findIndex((event: EventEntity) => event.id === id);
      if (index >= 0 && index < firstModifiedIdx) {
        firstModifiedIdx = index;
      }
    });

    let accumulatedAdd = 0;
    for (let i = firstModifiedIdx; i < gapIndex; i++) {
      const current = allSchedule[i];
      accumulatedAdd += (distributionMap.get(current.id) || 0);

      const nextItem = allSchedule[i + 1];
      if (nextItem && nextItem.lock_status === 1 && accumulatedAdd > nextItem.gap_minutes) {
        return true;
      }
    }
    return false;
  }
}
