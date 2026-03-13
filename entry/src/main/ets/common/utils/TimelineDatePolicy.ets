import { EventEntity } from '../../model/entity/EventEntity';
import { DateUtil } from './DateUtil';

export class TimelineDatePolicy {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  public static resolveDayOffset(dynamicDayOffset?: number, dayOffset?: number): number {
    if (dayOffset !== undefined && Number.isFinite(dayOffset)) {
      return dayOffset;
    }
    if (dynamicDayOffset !== undefined && Number.isFinite(dynamicDayOffset)) {
      return dynamicDayOffset;
    }
    return 0;
  }

  public static resolveEventDayOffset(event: EventEntity): number {
    return TimelineDatePolicy.resolveDayOffset(event.dynamic_day_offset, event.day_offset);
  }

  public static toDayStartMs(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  public static dayOffsetToDayStartMs(planStartDate: number, dayOffset: number): number {
    const baseStart = TimelineDatePolicy.toDayStartMs(planStartDate > 0 ? planStartDate : Date.now());
    return baseStart + dayOffset * TimelineDatePolicy.DAY_MS;
  }

  public static dayOffsetToDate(planStartDate: number, dayOffset: number): Date {
    return new Date(TimelineDatePolicy.dayOffsetToDayStartMs(planStartDate, dayOffset));
  }

  public static timestampToDayOffset(planStartDate: number, timestamp: number): number {
    const baseStart = TimelineDatePolicy.toDayStartMs(planStartDate > 0 ? planStartDate : timestamp);
    const targetStart = TimelineDatePolicy.toDayStartMs(timestamp);
    return Math.floor((targetStart - baseStart) / TimelineDatePolicy.DAY_MS);
  }

  public static buildPlannedTimestamp(planStartDate: number, dayOffset: number, timeText: string): number {
    const dayStart = TimelineDatePolicy.dayOffsetToDayStartMs(planStartDate, dayOffset);
    const minuteOfDay = DateUtil.timeToMinutes(timeText) + DateUtil.getDayShift(timeText) * 24 * 60;
    return dayStart + minuteOfDay * 60 * 1000;
  }
}
