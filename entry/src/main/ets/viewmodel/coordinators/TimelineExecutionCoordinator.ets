import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../../domain/policy/TimelineExecutionState';
import { TimelineGroupingService } from '../../domain/timeline/services/TimelineGroupingService';
import { ReflowHint } from '../types/TimelineTypes';

export interface ITimelineExecutionCoordinatorHost {
  events: EventEntity[];
}

export class TimelineExecutionCoordinator {
  private host: ITimelineExecutionCoordinatorHost;

  constructor(host: ITimelineExecutionCoordinatorHost) {
    this.host = host;
  }

  public getOrderedScheduleEvents(): EventEntity[] {
    return TimelineGroupingService.getOrderedScheduleEvents(this.host.events);
  }

  public getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((event: EventEntity) => event.id === eventId);
  }

  public getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.getOrderedScheduleEvents();
    const idx = this.getOrderedScheduleIndexById(afterId, source);
    if (idx === -1) {
      return null;
    }
    for (let i = idx + 1; i < source.length; i++) {
      if (TimelineExecutionState.isStartable(source[i])) {
        return source[i];
      }
    }
    return null;
  }

  public buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    if (action === 'skip') {
      return {
        type: 'next_changed',
        minutesDelta: 0,
        message: nextName
          ? `已跳过 ${targetName}，下一站改为 ${nextName}`
          : `已跳过 ${targetName}，后续行程已自动重排`,
        updatedAt: Date.now()
      };
    }

    if (beforeTs > 0 && afterTs > 0) {
      const deltaMinutes = Math.round((afterTs - beforeTs) / 60000);
      if (deltaMinutes > 0) {
        return {
          type: 'shift',
          minutesDelta: deltaMinutes,
          message: `后续整体顺延 ${deltaMinutes} 分钟`,
          updatedAt: Date.now()
        };
      }
      if (deltaMinutes < 0) {
        return {
          type: 'shift',
          minutesDelta: deltaMinutes,
          message: `后续整体提前 ${Math.abs(deltaMinutes)} 分钟`,
          updatedAt: Date.now()
        };
      }
    }

    return {
      type: 'reflow',
      minutesDelta: 0,
      message: '已根据实际时间自动更新后续安排',
      updatedAt: Date.now()
    };
  }

  public isFirstScheduledItemOfDay(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    const schedule = this.getOrderedScheduleEvents();
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    if (idx <= 0) {
      return idx === 0;
    }
    const prev = schedule[idx - 1];
    return TimelineDatePolicy.resolveEventDayOffset(prev) !== TimelineDatePolicy.resolveEventDayOffset(item);
  }
}
