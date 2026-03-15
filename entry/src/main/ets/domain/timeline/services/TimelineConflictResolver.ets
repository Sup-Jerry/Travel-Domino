import { EventEntity } from '../../../model/entity/EventEntity';
import { TravelPlanItem } from '../../../model/interface/IStandardEvent';
import { DateUtil } from '../../../common/utils/DateUtil';
import { EventRepositoryImpl } from '../../../infrastructure/persistence/EventRepositoryImpl';

export class TimelineConflictResolver {
  static isDateConflict(targetDateMs: number, planStartDate: number): boolean {
    if (planStartDate <= 0) {
      return false;
    }

    const targetDay = new Date(targetDateMs).setHours(0, 0, 0, 0);
    const planDay = new Date(planStartDate).setHours(0, 0, 0, 0);

    return targetDay < planDay;
  }

  static async fixConflict(
    events: EventEntity[],
    itemId: number,
    shiftMinutes: number,
    planId: number
  ): Promise<boolean> {
    const target = events.find(e => e.id === itemId);
    if (!target || !target.fixed_start_time) {
      return false;
    }

    const currentMin = DateUtil.timeToMinutes(target.fixed_start_time);
    const newMin = currentMin + shiftMinutes;
    const h = Math.floor(newMin / 60) % 24;
    const m = newMin % 60;
    const newTimeStr = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;

    target.fixed_start_time = newTimeStr;
    if (target.id) {
      await EventRepositoryImpl.updateSingleField(target.id, 'fixed_start_time', newTimeStr, planId);
    }
    return true;
  }
}
