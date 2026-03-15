import { EventEntity } from '../../../model/entity/EventEntity';
import { DateUtil } from '../../../common/utils/DateUtil';
import { TimelineDatePolicy } from '../../policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../../policy/TimelineExecutionState';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TimelineGroupingService';

export interface DateGroup {
  dateHeader: string;
  dayIndex: number;
  dayOffset: number;
  actualDateMs: number;
  events: EventEntity[];
}

export interface PlaceCheckinRecord {
  id: number;
  name: string;
  dayOffset: number;
  status: number;
  actualStart: number;
  actualEnd: number;
  stayMinutes: number;
}

export interface PlaceCheckinSummary {
  placeName: string;
  totalRecords: number;
  completedRecords: number;
  skippedRecords: number;
  avgStayMinutes: number;
  lastEndTime: number;
  records: PlaceCheckinRecord[];
}

export class TimelineGroupingService {
  static generateGroups(
    events: EventEntity[],
    planStartDate: number,
    filterStart?: number,
    filterEnd?: number,
    getEffectiveDayOffset?: (event: EventEntity) => number
  ): DateGroup[] {
    const nextGroups: DateGroup[] = [];
    const planBaseDayMs = TimelineDatePolicy.toDayStartMs(planStartDate > 0 ? planStartDate : Date.now());

    const scheduleEvents = events
      .filter(e => e.status === 1)
      .sort((a, b) => {
        const dayOffsetA = getEffectiveDayOffset ? getEffectiveDayOffset(a) : TimelineDatePolicy.resolveEventDayOffset(a);
        const dayOffsetB = getEffectiveDayOffset ? getEffectiveDayOffset(b) : TimelineDatePolicy.resolveEventDayOffset(b);
        if (dayOffsetA !== dayOffsetB) {
          return dayOffsetA - dayOffsetB;
        }
        return a.sort_order - b.sort_order;
      });

    if (scheduleEvents.length === 0) {
      return nextGroups;
    }

    let currentGroup: DateGroup | null = null;
    let lastDayOffset = Number.MIN_SAFE_INTEGER;
    let visibleDayIndex = 0;

    scheduleEvents.forEach((item) => {
      const renderDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      const itemDateMs = TimelineDatePolicy.dayOffsetToDayStartMs(planBaseDayMs, renderDayOffset);

      if (filterStart && filterStart > 0 && (itemDateMs < filterStart || itemDateMs > (filterEnd || 0))) {
        return;
      }

      if (renderDayOffset !== lastDayOffset) {
        const groupDate = new Date(itemDateMs);
        visibleDayIndex += 1;

        const dateStr = DateUtil.formatDate(groupDate, "MM月dd日");
        let headerStr = `Day ${visibleDayIndex} (${dateStr})`;

        if (renderDayOffset < 0) {
          headerStr = `待定/冲突 (${renderDayOffset}天前)`;
        }

        currentGroup = {
          dateHeader: headerStr,
          dayIndex: visibleDayIndex,
          dayOffset: renderDayOffset,
          actualDateMs: itemDateMs,
          events: []
        };
        hilog.info(
          0x0000,
          TAG,
          `[DAY_SHIFT_FIX][group_anchor] mode=offset_only, dayOffset=${renderDayOffset}, header=${headerStr}, eventId=${item.id}, eventName=${item.name}, dynamicStart=${item.dynamic_start_time}, actualStart=${item.actual_start_time}`
        );

        nextGroups.push(currentGroup);
        lastDayOffset = renderDayOffset;
      }

      if (currentGroup) {
        currentGroup.events.push(item);
      }
    });
    return nextGroups;
  }

  static getOrderedScheduleEvents(events: EventEntity[]): EventEntity[] {
    const schedule = events.filter((event: EventEntity) => event.status === 1);
    const stableIndex = new Map<number, number>();
    schedule.forEach((event: EventEntity, index: number) => {
      stableIndex.set(event.id, index);
    });
    const ordered = schedule.slice();
    ordered.sort((a: EventEntity, b: EventEntity) => {
      const dayA = TimelineDatePolicy.resolveEventDayOffset(a);
      const dayB = TimelineDatePolicy.resolveEventDayOffset(b);
      if (dayA !== dayB) {
        return dayA - dayB;
      }
      if (a.sort_order !== b.sort_order) {
        return a.sort_order - b.sort_order;
      }
      return (stableIndex.get(a.id) ?? 0) - (stableIndex.get(b.id) ?? 0);
    });
    return ordered;
  }

  private static normalizePlaceKey(placeName: string): string {
    return placeName.trim().toLowerCase();
  }

  static getEventsByPlaceName(events: EventEntity[], placeName: string): EventEntity[] {
    const key = TimelineGroupingService.normalizePlaceKey(placeName);
    if (key.length === 0) {
      return [];
    }
    const items = events.filter((event: EventEntity) =>
      TimelineGroupingService.normalizePlaceKey(event.name || '') === key
    );
    items.sort((a: EventEntity, b: EventEntity) => {
      const dayA = TimelineDatePolicy.resolveEventDayOffset(a);
      const dayB = TimelineDatePolicy.resolveEventDayOffset(b);
      if (dayA !== dayB) {
        return dayA - dayB;
      }
      if (a.sort_order !== b.sort_order) {
        return a.sort_order - b.sort_order;
      }
      return a.id - b.id;
    });
    return items;
  }

  static getPlaceCheckinSummary(events: EventEntity[], placeName: string): PlaceCheckinSummary {
    const samePlaceEvents = TimelineGroupingService.getEventsByPlaceName(events, placeName);
    const records: PlaceCheckinRecord[] = [];
    let completedCount = 0;
    let skippedCount = 0;
    let totalStay = 0;
    let lastEnd = 0;
    for (let i = 0; i < samePlaceEvents.length; i++) {
      const e = samePlaceEvents[i];
      if (e.actual_start_time <= 0 && e.actual_end_time <= 0 && e.completion_status === EventEntity.STATE_PENDING) {
        continue;
      }
      const stayMs = (e.actual_start_time > 0 && e.actual_end_time > e.actual_start_time)
        ? (e.actual_end_time - e.actual_start_time)
        : 0;
      const stayMinutes = stayMs > 0 ? Math.round(stayMs / 60000) : 0;
      if (e.completion_status === EventEntity.STATE_COMPLETED) {
        completedCount += 1;
        totalStay += stayMinutes;
        if (e.actual_end_time > lastEnd) {
          lastEnd = e.actual_end_time;
        }
      } else if (e.completion_status === EventEntity.STATE_SKIPPED) {
        skippedCount += 1;
      }
      records.push({
        id: e.id,
        name: e.name,
        dayOffset: e.day_offset,
        status: e.completion_status,
        actualStart: e.actual_start_time,
        actualEnd: e.actual_end_time,
        stayMinutes: stayMinutes
      });
    }
    records.sort((a, b) => {
      const ta = a.actualEnd > 0 ? a.actualEnd : a.actualStart;
      const tb = b.actualEnd > 0 ? b.actualEnd : b.actualStart;
      return tb - ta;
    });
    const avgStay = completedCount > 0 ? Math.round(totalStay / completedCount) : 0;

    const summary: PlaceCheckinSummary = {
      placeName: placeName,
      totalRecords: records.length,
      completedRecords: completedCount,
      skippedRecords: skippedCount,
      avgStayMinutes: avgStay,
      lastEndTime: lastEnd,
      records: records
    };

    hilog.info(
      0x0000,
      TAG,
      `[CHECKIN_HISTORY][summary] place=${placeName}, total=${summary.totalRecords}, completed=${summary.completedRecords}, skipped=${summary.skippedRecords}, avgStay=${summary.avgStayMinutes}, lastEnd=${summary.lastEndTime}`
    );
    return summary;
  }

  static getAllPlaceCheckinSummaries(events: EventEntity[]): PlaceCheckinSummary[] {
    const summaries: PlaceCheckinSummary[] = [];
    const uniquePlaceNames = new Set<string>();
    for (let i = 0; i < events.length; i++) {
      const rawName = (events[i].name || '').trim();
      if (rawName.length === 0) {
        continue;
      }
      uniquePlaceNames.add(rawName);
    }
    const names = Array.from(uniquePlaceNames.values());
    for (let i = 0; i < names.length; i++) {
      const summary = TimelineGroupingService.getPlaceCheckinSummary(events, names[i]);
      if (summary.totalRecords > 0) {
        summaries.push(summary);
      }
    }
    return summaries;
  }
}
