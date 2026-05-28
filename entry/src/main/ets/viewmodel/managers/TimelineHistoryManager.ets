import { DateUtil } from '../../common/utils/DateUtil';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineExecutionState } from '../../domain/policy/TimelineExecutionState';
import { HistoryManager } from '../../domain/timeline/HistoryManager';
import { TimelineGroupingService } from '../../domain/timeline/services/TimelineGroupingService';
import { HistoryTimelineItem, HistoryTimelineSummary } from '../types/TimelineTypes';

export interface ITimelineHistoryHost {
  events: EventEntity[];
  planId: number;
  planName: string;
}

export function resolveLatestEventSortTs(event: EventEntity): number {
  return event.actual_end_time > 0 ? event.actual_end_time : (event.actual_start_time > 0 ? event.actual_start_time : 0);
}

export class TimelineHistoryManager {
  private host: ITimelineHistoryHost;

  constructor(host: ITimelineHistoryHost) {
    this.host = host;
  }

  private getOrderedScheduleEvents(): EventEntity[] {
    return TimelineGroupingService.getOrderedScheduleEvents(this.host.events);
  }

  public getEventsByPlaceName(placeName: string): EventEntity[] {
    return TimelineGroupingService.getEventsByPlaceName(this.host.events, placeName);
  }

  public getPlaceAddress(placeName: string): string {
    const events = this.getEventsByPlaceName(placeName);
    for (let i = 0; i < events.length; i++) {
      const address = (events[i].address || '').trim();
      if (address.length > 0) {
        return address;
      }
    }
    return '-';
  }

  public getLatestEventForPlace(placeName: string): EventEntity | null {
    const events = this.getEventsByPlaceName(placeName)
      .filter((event: EventEntity) => TimelineExecutionState.isScheduled(event));
    if (events.length === 0) {
      return null;
    }
    events.sort((a: EventEntity, b: EventEntity) => {
      const aTs = resolveLatestEventSortTs(a);
      const bTs = resolveLatestEventSortTs(b);
      if (bTs !== aTs) {
        return bTs - aTs;
      }
      return b.id - a.id;
    });
    return events[0];
  }

  public getCurrentPlanHistorySummary(): HistoryTimelineSummary {
    const schedule = this.getOrderedScheduleEvents();
    return HistoryManager.generateSummary(schedule, this.host.planName, this.host.planId);
  }

  public getCurrentPlanHistoryTimelineItems(abnormalThresholdMinutes: number = 10): HistoryTimelineItem[] {
    const threshold = abnormalThresholdMinutes > 0 ? abnormalThresholdMinutes : 10;
    const schedule = this.getOrderedScheduleEvents();
    const items: HistoryTimelineItem[] = [];
    for (let i = 0; i < schedule.length; i++) {
      const event = schedule[i];
      const plannedStart = event.dynamic_start_time > 0 ? event.dynamic_start_time : 0;
      const actualStart = event.actual_start_time > 0 ? event.actual_start_time : 0;
      const actualEnd = event.actual_end_time > 0 ? event.actual_end_time : 0;
      const stayMinutes = (actualStart > 0 && actualEnd > actualStart)
        ? Math.round((actualEnd - actualStart) / 60000)
        : 0;
      const deviationMinutes = (actualStart > 0 && plannedStart > 0)
        ? Math.round((actualStart - plannedStart) / 60000)
        : 0;
      const isSkipped = TimelineExecutionState.isSkipped(event);
      const isAbnormal = isSkipped || Math.abs(deviationMinutes) >= threshold;
      const address = (event.address || '').trim();
      const note = (event.note || '').trim();

      if (isSkipped) {
        const skipTs = actualEnd > 0 ? actualEnd : (actualStart > 0 ? actualStart : plannedStart);
        items.push({
          id: event.id * 10 + 3,
          eventId: event.id,
          placeName: event.name,
          actionType: 'SKIP',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(skipTs),
          address: address,
          note: note,
          displayTs: skipTs,
          isAbnormal: isAbnormal
        });
        continue;
      }

      if (TimelineExecutionState.isActive(event)) {
        const activeTs = actualStart;
        items.push({
          id: event.id * 10 + 4,
          eventId: event.id,
          placeName: event.name,
          actionType: 'ACTIVE',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(activeTs),
          address: address,
          note: note,
          displayTs: activeTs,
          isAbnormal: isAbnormal
        });
        continue;
      }

      if (actualStart > 0) {
        items.push({
          id: event.id * 10 + 1,
          eventId: event.id,
          placeName: event.name,
          actionType: 'ARRIVE',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(actualStart),
          address: address,
          note: note,
          displayTs: actualStart,
          isAbnormal: isAbnormal
        });
      }

      if (actualEnd > 0) {
        items.push({
          id: event.id * 10 + 2,
          eventId: event.id,
          placeName: event.name,
          actionType: 'LEAVE',
          plannedStart: plannedStart,
          actualStart: actualStart,
          actualEnd: actualEnd,
          stayMinutes: stayMinutes,
          deviationMinutes: deviationMinutes,
          status: event.completion_status,
          groupDateKey: this.toHistoryGroupDateKey(actualEnd),
          address: address,
          note: note,
          displayTs: actualEnd,
          isAbnormal: isAbnormal
        });
      }
    }

    items.sort((a: HistoryTimelineItem, b: HistoryTimelineItem) => {
      if (a.displayTs !== b.displayTs) {
        return a.displayTs - b.displayTs;
      }
      return a.id - b.id;
    });
    return items;
  }

  private toHistoryGroupDateKey(ts: number): string {
    if (ts <= 0) {
      return '未定';
    }
    return DateUtil.formatLocalDate(ts);
  }
}
