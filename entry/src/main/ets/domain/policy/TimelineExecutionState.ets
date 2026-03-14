import { EventEntity } from '../../model/entity/EventEntity';

export type TimelineRuntimeState = 'BACKLOG' | 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED';

export class TimelineExecutionState {
  public static isScheduled(event: EventEntity): boolean {
    return event.status === 1;
  }

  public static isBacklog(event: EventEntity): boolean {
    return event.status !== 1;
  }

  public static isPending(event: EventEntity): boolean {
    return event.completion_status === EventEntity.STATE_PENDING;
  }

  public static isCompleted(event: EventEntity): boolean {
    return event.completion_status === EventEntity.STATE_COMPLETED;
  }

  public static isSkipped(event: EventEntity): boolean {
    return event.completion_status === EventEntity.STATE_SKIPPED;
  }

  public static isActive(event: EventEntity): boolean {
    return TimelineExecutionState.isScheduled(event) &&
      TimelineExecutionState.isPending(event) &&
      event.actual_start_time > 0 &&
      event.actual_end_time <= 0;
  }

  public static isStartable(event: EventEntity): boolean {
    return TimelineExecutionState.isScheduled(event) &&
      TimelineExecutionState.isPending(event) &&
      event.actual_start_time <= 0;
  }

  public static getRuntimeState(event: EventEntity): TimelineRuntimeState {
    if (TimelineExecutionState.isBacklog(event)) {
      return 'BACKLOG';
    }
    if (TimelineExecutionState.isCompleted(event)) {
      return 'COMPLETED';
    }
    if (TimelineExecutionState.isSkipped(event)) {
      return 'SKIPPED';
    }
    if (TimelineExecutionState.isActive(event)) {
      return 'ACTIVE';
    }
    return 'PENDING';
  }
}
