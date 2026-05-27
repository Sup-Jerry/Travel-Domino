import { EventEntity } from '../../../model/entity/EventEntity';
import { DateUtil } from '../../../common/utils/DateUtil';
import { EventRepositoryImpl } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TimelineViewModel';

export interface ITimelineDistributionHost {
  events: EventEntity[];
  planId: number;
  idleGapDetectionEnabled: boolean;
  idleGapTriggerMinutes: number;
  getEffectiveDayOffset(item: EventEntity): number;
  getOrderedScheduleEvents(): EventEntity[];
  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number;
  isFirstScheduledItemOfDay(item: EventEntity): boolean;
  _calculateNaturalArrival(targetIndex: number): number;
  recalculateFromIndex(startIndex: number): void;
  updateEventInfo(
    id: number,
    name: string,
    duration: number,
    fixedTime?: string,
    dayOffset?: number
  ): Promise<void>;
}

export interface ITimelineDistributionService {
  resolveGapByDistribution(targetItem: EventEntity): Promise<void>;
  resolveGapBySync(item: EventEntity): void;
  getDistributionCandidates(gapItem: EventEntity): EventEntity[];
  getSafetyCap(candidate: EventEntity, gapItem: EventEntity): number;
  calculateDistributionPreview(
    gapItem: EventEntity,
    candidates: EventEntity[],
    selectedIds: Set<number>,
    strategy: 'EQUAL' | 'SMART'
  ): Map<number, number>;
  getSortedGaps(): EventEntity[];
  getPreviousItemName(gapItem: EventEntity): string;
  applyDistribution(distributionMap: Map<number, number>): Promise<void>;
}

export class TimelineDistributionService implements ITimelineDistributionService {
  private static readonly AUTO_DISTRIBUTION_MAX_DURATION: number = 240;
  private host: ITimelineDistributionHost;

  constructor(host: ITimelineDistributionHost) {
    this.host = host;
  }

  public static clampDistributionAdd(currentDuration: number, requestedAdd: number): number {
    const safeCurrent = Number.isFinite(currentDuration) ? Math.max(0, Math.floor(currentDuration)) : 0;
    const safeRequested = Number.isFinite(requestedAdd) ? Math.max(0, Math.floor(requestedAdd)) : 0;
    if (safeRequested <= 0) {
      return 0;
    }
    const remaining = Math.max(0, TimelineDistributionService.AUTO_DISTRIBUTION_MAX_DURATION - safeCurrent);
    return Math.min(safeRequested, remaining);
  }

  public resolveGapBySync(item: EventEntity): void {
    if (item.natural_start_time) {
      void this.host.updateEventInfo(item.id, item.name, item.duration, item.natural_start_time, item.day_offset);
    }
  }

  public async resolveGapByDistribution(targetItem: EventEntity): Promise<void> {
    if (!targetItem || !targetItem.has_gap || targetItem.gap_minutes <= 0) {
      return;
    }

    const gap = targetItem.gap_minutes;
    const index = this.host.events.indexOf(targetItem);
    if (index <= 0) {
      return;
    }

    const candidates: EventEntity[] = [];
    for (let i = index - 1; i >= 0; i--) {
      const item = this.host.events[i];
      if (item.lock_status !== 0) {
        break;
      }
      candidates.push(item);
    }

    if (candidates.length === 0) {
      return;
    }

    const count = candidates.length;
    const baseAdd = Math.floor(gap / count);
    const remainder = gap % count;
    let totalAppliedAdd = 0;

    candidates.forEach((item: EventEntity, idx: number) => {
      let add = baseAdd;

      if (idx === 0) {
        add += remainder;
      }

      const cappedAdd = TimelineDistributionService.clampDistributionAdd(item.duration, add);
      if (cappedAdd <= 0) {
        return;
      }
      item.duration += cappedAdd;
      totalAppliedAdd += cappedAdd;

      if (item.id) {
        void EventRepositoryImpl.updateSingleField(item.id, 'duration', item.duration, this.host.planId);
      }
    });

    const recalculateStartIndex = this.host.events.indexOf(candidates[candidates.length - 1]);
    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][distribution_auto] targetId=${targetItem.id},gap=${gap},candidateCount=${count},totalAdd=${totalAppliedAdd},startIndex=${recalculateStartIndex}`
    );
    this.host.recalculateFromIndex(recalculateStartIndex > 0 ? recalculateStartIndex - 1 : 0);
  }

  public getDistributionCandidates(gapItem: EventEntity): EventEntity[] {
    const index = this.host.events.indexOf(gapItem);
    if (index <= 0) {
      return [];
    }

    return this.host.events.slice(0, index).filter((event: EventEntity) =>
      event.status === 1 && this.host.getEffectiveDayOffset(event) === this.host.getEffectiveDayOffset(gapItem)
    );
  }

  public getSafetyCap(candidate: EventEntity, gapItem: EventEntity): number {
    const allSchedule = this.host.events.filter((event: EventEntity) => event.status === 1);

    const candIdx = allSchedule.findIndex((event: EventEntity) => event.id === candidate.id);
    const gapIdx = allSchedule.findIndex((event: EventEntity) => event.id === gapItem.id);

    if (candIdx === -1 || gapIdx === -1 || candIdx >= gapIdx) {
      return 0;
    }

    let minBuffer = Math.max(0, gapItem.gap_minutes);

    for (let i = candIdx + 1; i < gapIdx; i++) {
      const item = allSchedule[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        const eventIdxInEvents = this.host.events.findIndex((event: EventEntity) => event.id === item.id);
        const naturalArrival = this.host._calculateNaturalArrival(eventIdxInEvents);
        const targetMin = DateUtil.timeToMinutes(item.fixed_start_time);
        const buffer = targetMin - naturalArrival;

        if (buffer < minBuffer) {
          minBuffer = Math.max(0, buffer);
        }
      }
    }

    const durationCap = Math.max(0, TimelineDistributionService.AUTO_DISTRIBUTION_MAX_DURATION - candidate.duration);
    return Math.min(minBuffer, durationCap);
  }

  public calculateDistributionPreview(
    gapItem: EventEntity,
    candidates: EventEntity[],
    selectedIds: Set<number>,
    strategy: 'EQUAL' | 'SMART'
  ): Map<number, number> {
    const selectedItems = candidates.filter((candidate: EventEntity) => selectedIds.has(candidate.id));
    const result = new Map<number, number>();
    if (selectedItems.length === 0) {
      return result;
    }

    const caps = new Map<number, number>();
    const weights = new Map<number, number>();

    selectedItems.forEach((item: EventEntity) => {
      const cap = this.getSafetyCap(item, gapItem);
      caps.set(item.id, cap);

      let weight = 1.0;
      if (strategy === 'SMART') {
        const priorityFactor = item.priority === 1 ? 2.0 : 1.0;
        weight = priorityFactor * item.duration;
      }
      weights.set(item.id, weight);
      result.set(item.id, 0);
    });

    let remainingGap = gapItem.gap_minutes;
    let activeIds = selectedItems.map((item: EventEntity) => item.id);

    while (remainingGap > 0 && activeIds.length > 0) {
      let currentRoundWeight = 0;
      activeIds.forEach((id: number) => {
        currentRoundWeight += (weights.get(id) ?? 0);
      });

      if (currentRoundWeight <= 0) {
        break;
      }

      const nextActiveIds: number[] = [];
      let allocatedThisRound = 0;

      for (const id of activeIds) {
        const weightVal: number = weights.get(id) ?? 0;
        const share: number = Math.floor(remainingGap * (weightVal / currentRoundWeight));

        const currentAllocated = result.get(id) ?? 0;
        const cap = caps.get(id) ?? 0;

        if (currentAllocated + share >= cap) {
          const actualAdd = cap - currentAllocated;
          result.set(id, cap);
          allocatedThisRound += actualAdd;
        } else {
          result.set(id, currentAllocated + share);
          allocatedThisRound += share;
          nextActiveIds.push(id);
        }
      }

      remainingGap -= allocatedThisRound;

      if (allocatedThisRound === 0 && remainingGap > 0) {
        const luckyId = nextActiveIds[0];
        if (luckyId && (result.get(luckyId) ?? 0) < (caps.get(luckyId) ?? 0)) {
          result.set(luckyId, (result.get(luckyId) ?? 0) + 1);
          remainingGap--;
        } else {
          break;
        }
      }
      activeIds = nextActiveIds;
    }

    let totalAllocated = 0;
    result.forEach((value: number) => {
      totalAllocated += Math.max(0, value);
    });
    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][distribution_preview] gapId=${gapItem.id},strategy=${strategy},selected=${selectedItems.length},allocated=${totalAllocated},remain=${Math.max(0, gapItem.gap_minutes - totalAllocated)}`
    );

    return result;
  }

  public getSortedGaps(): EventEntity[] {
    if (!this.host.idleGapDetectionEnabled) {
      return [];
    }

    const minGap = this.host.idleGapTriggerMinutes;
    return this.host.events
      .filter((event: EventEntity) =>
        event.status === 1 &&
        event.has_gap &&
        event.gap_minutes >= minGap &&
        !this.host.isFirstScheduledItemOfDay(event) &&
        this.isSameDayGapWithPreviousScheduleItem(event)
      )
      .sort((a: EventEntity, b: EventEntity) => b.gap_minutes - a.gap_minutes);
  }

  private isSameDayGapWithPreviousScheduleItem(item: EventEntity): boolean {
    const schedule = this.host.getOrderedScheduleEvents();
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    const prev = schedule[idx - 1];
    return this.host.getEffectiveDayOffset(prev) === this.host.getEffectiveDayOffset(item);
  }

  public getPreviousItemName(gapItem: EventEntity): string {
    const schedule = this.host.getOrderedScheduleEvents();
    const idx = this.host.getOrderedScheduleIndexById(gapItem.id, schedule);
    if (idx <= 0) {
      return '日程开始';
    }

    const prev = schedule[idx - 1];
    if (this.host.getEffectiveDayOffset(prev) !== this.host.getEffectiveDayOffset(gapItem)) {
      return '当日开始';
    }

    return prev.name;
  }

  public async applyDistribution(distributionMap: Map<number, number>): Promise<void> {
    const entries = Array.from(distributionMap.entries());
    let startIndex = this.host.events.length;
    let affectedCount = 0;
    let totalAppliedAdd = 0;
    for (let i = 0; i < entries.length; i++) {
      const id = entries[i][0];
      const addMin = entries[i][1];
      const item = this.host.events.find((event: EventEntity) => event.id === id);
      if (item && addMin > 0) {
        const cappedAdd = TimelineDistributionService.clampDistributionAdd(item.duration, addMin);
        if (cappedAdd <= 0) {
          continue;
        }
        const idx = this.host.events.indexOf(item);
        if (idx >= 0 && idx < startIndex) {
          startIndex = idx;
        }
        item.duration += cappedAdd;
        totalAppliedAdd += cappedAdd;
        affectedCount += 1;
        await EventRepositoryImpl.updateSingleField(item.id, 'duration', item.duration, this.host.planId);
      }
    }
    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][distribution_apply] affected=${affectedCount},totalAdd=${totalAppliedAdd},startIndex=${startIndex < this.host.events.length ? (startIndex > 0 ? startIndex - 1 : 0) : -1}`
    );
    if (startIndex < this.host.events.length) {
      this.host.recalculateFromIndex(startIndex > 0 ? startIndex - 1 : 0);
    }
  }
}

