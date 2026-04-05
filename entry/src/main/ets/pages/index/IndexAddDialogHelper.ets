import { DateUtil } from '../../common/utils/DateUtil';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { AddDialogDefaults } from './IndexTypes';

export class IndexAddDialogHelper {
  private static getDefaultAddTime(): string {
    return '08:00';
  }

  private static normalizeTimeText(raw?: string): string {
    const pure = DateUtil.extractPureTime(raw || '');
    if (pure && DateUtil.isValidTimeString(pure)) {
      return pure;
    }
    return IndexAddDialogHelper.getDefaultAddTime();
  }

  private static resolveEventEndTimeText(event: EventEntity): string {
    const start = IndexAddDialogHelper.normalizeTimeText(event.fixed_start_time || event.computed_time);
    const duration = Number.isFinite(event.duration) && event.duration > 0 ? event.duration : 0;
    return DateUtil.calculateEndTime(start, duration);
  }

  private static getLatestCreatedScheduleEvent(events: EventEntity[]): EventEntity | undefined {
    const scheduled = events.filter((item: EventEntity) => item.status === 1);
    if (scheduled.length === 0) {
      return undefined;
    }
    const sorted = scheduled.slice().sort((a: EventEntity, b: EventEntity) => {
      const idA = Number.isFinite(a.id) ? a.id : -1;
      const idB = Number.isFinite(b.id) ? b.id : -1;
      return idB - idA;
    });
    return sorted[0];
  }

  static calculateSmartTime(events: EventEntity[], targetItemId: number): string {
    if (events.length === 0) {
      return '09:00';
    }

    let prevItem: EventEntity | undefined;
    if (targetItemId === -1) {
      prevItem = events[events.length - 1];
    } else {
      const index = events.findIndex(e => e.id === targetItemId);
      if (index > 0) {
        prevItem = events[index - 1];
      }
    }

    if (prevItem) {
      const startTime = prevItem.computed_time || prevItem.fixed_start_time || '09:00';
      return DateUtil.calculateEndTime(startTime, prevItem.duration);
    }

    return '09:00';
  }

  static recommendAddByDayOffset(events: EventEntity[], dayOffset: number): string {
    const sameDay = events.filter((item: EventEntity) =>
      item.status === 1 && TimelineDatePolicy.resolveEventDayOffset(item) === dayOffset
    );
    if (sameDay.length === 0) {
      return IndexAddDialogHelper.getDefaultAddTime();
    }
    const anchor = sameDay[sameDay.length - 1];
    return IndexAddDialogHelper.resolveEventEndTimeText(anchor);
  }

  static resolveAddDialogDefaults(events: EventEntity[]): AddDialogDefaults {
    const latest = IndexAddDialogHelper.getLatestCreatedScheduleEvent(events);
    if (!latest) {
      const emptyDefaults = new AddDialogDefaults();
      emptyDefaults.dayOffset = 0;
      emptyDefaults.suggestedTime = IndexAddDialogHelper.getDefaultAddTime();
      return emptyDefaults;
    }
    const dayOffset = TimelineDatePolicy.resolveEventDayOffset(latest);
    const nextDefaults = new AddDialogDefaults();
    nextDefaults.dayOffset = dayOffset;
    nextDefaults.suggestedTime = IndexAddDialogHelper.resolveEventEndTimeText(latest);
    return nextDefaults;
  }
}
