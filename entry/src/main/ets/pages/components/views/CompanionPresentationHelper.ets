import { EventEntity } from '../../../model/entity/EventEntity';
import { DateUtil } from '../../../common/utils/DateUtil';
import { TimelineExecutionState } from '../../../domain/policy/TimelineExecutionState';

export type CompanionEventState = 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED';

export class CompanionPresentationHelper {
  public static formatTs(ts: number): string {
    if (ts <= 0) {
      return '--:--';
    }
    return DateUtil.formatDate(new Date(ts), 'HH:mm');
  }

  public static getEventState(event: EventEntity): CompanionEventState {
    const runtime = TimelineExecutionState.getRuntimeState(event);
    if (runtime === 'COMPLETED') {
      return 'COMPLETED';
    }
    if (runtime === 'SKIPPED') {
      return 'SKIPPED';
    }
    if (runtime === 'ACTIVE') {
      return 'ACTIVE';
    }
    return 'PENDING';
  }

  public static getEventStateLabel(event: EventEntity): string {
    const state = CompanionPresentationHelper.getEventState(event);
    if (state === 'ACTIVE') {
      return '进行中';
    }
    if (state === 'COMPLETED') {
      return '已完成';
    }
    if (state === 'SKIPPED') {
      return '已跳过';
    }
    return '未开始';
  }

  public static getPlannedRange(event: EventEntity): string {
    const start = event.computed_time || event.fixed_start_time || '--:--';
    const end = DateUtil.calculateEndTime(start, event.duration);
    return `${start}-${end}`;
  }

  public static getForecastStartText(event: EventEntity): string {
    if (event.dynamic_start_time > 0) {
      return CompanionPresentationHelper.formatTs(event.dynamic_start_time);
    }
    return event.computed_time || event.fixed_start_time || '--:--';
  }

  public static getMainCardTimeText(event: EventEntity): string {
    const state = CompanionPresentationHelper.getEventState(event);
    if (state === 'ACTIVE') {
      return `已开始 ${CompanionPresentationHelper.formatTs(event.actual_start_time)}`;
    }
    if (state === 'COMPLETED') {
      return `${CompanionPresentationHelper.formatTs(event.actual_start_time)} - ${CompanionPresentationHelper.formatTs(event.actual_end_time)}`;
    }
    if (state === 'SKIPPED') {
      return '已跳过，可重新开始';
    }
    return CompanionPresentationHelper.getPlannedRange(event);
  }

  public static getTimelineSupplement(event: EventEntity, nowTs: number = Date.now()): string {
    const state = CompanionPresentationHelper.getEventState(event);
    if (state === 'ACTIVE') {
      const stayMinutes = event.actual_start_time > 0
        ? Math.max(1, Math.round((nowTs - event.actual_start_time) / 60000))
        : 0;
      return `进行中 | 已停留 ${stayMinutes} 分钟`;
    }
    if (state === 'COMPLETED') {
      return `已完成 | 结束 ${CompanionPresentationHelper.formatTs(event.actual_end_time)}`;
    }
    if (state === 'SKIPPED') {
      return '已跳过';
    }
    return `未开始 | 预计 ${CompanionPresentationHelper.getForecastStartText(event)}`;
  }

  public static formatDateTime(ts: number): string {
    if (ts <= 0) {
      return '--:--';
    }
    const d = new Date(ts);
    const y = d.getFullYear();
    const m = `${d.getMonth() + 1}`.padStart(2, '0');
    const day = `${d.getDate()}`.padStart(2, '0');
    const h = `${d.getHours()}`.padStart(2, '0');
    const min = `${d.getMinutes()}`.padStart(2, '0');
    return `${y}-${m}-${day} ${h}:${min}`;
  }
}
