import { DateUtil } from '../../common/utils/DateUtil';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export class IndexConflictHelper {
  static resolveConflictGapMinutes(item: EventEntity, fallbackGap: number = 0): number {
    if (item.gap_minutes > 0) {
      return item.gap_minutes;
    }

    const match = (item.conflict_msg || '').match(/(\d+)/);
    if (match && match.length > 1) {
      const parsed = Number.parseInt(match[1], 10);
      if (Number.isFinite(parsed) && parsed > 0) {
        return parsed;
      }
    }

    return fallbackGap > 0 ? fallbackGap : 0;
  }

  static getConflictTargetTime(item: EventEntity): string {
    const raw = item.fixed_start_time || item.computed_time || '09:00';
    const pure = DateUtil.extractPureTime(raw);
    return pure && DateUtil.isValidTimeString(pure) ? pure : '09:00';
  }

  static async saveConflictTime(
    vm: TimelineViewModel,
    item: EventEntity,
    newTime?: string,
    onDone?: () => Promise<void> | void
  ): Promise<void> {
    if (newTime && item.id > 0) {
      const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      await vm.updateEventInfo(
        item.id,
        item.name,
        item.duration,
        newTime,
        effectiveDayOffset,
        item.lock_status === 1,
        item.note,
        item.priority,
        item.latitude,
        item.longitude
      );
    }

    if (onDone) {
      await onDone();
    }
  }
}
