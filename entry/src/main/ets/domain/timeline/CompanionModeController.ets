// path: domain/timeline/CompanionModeController.ets
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineExecutionState } from '../policy/TimelineExecutionState';

export type CompanionRuntimeState = 'IDLE' | 'READY' | 'ACTIVE' | 'GAP';

export interface CompanionActions {
  canStart: boolean;
  canEnd: boolean;
  canSkip: boolean;
  canNavigate: boolean;
  canViewDetail: boolean;
}

export class CompanionModeController {
  public static findActiveEvent(events: EventEntity[]): EventEntity | null {
    for (const event of events) {
      if (TimelineExecutionState.isActive(event)) {
        return event;
      }
    }
    return null;
  }

  public static findPendingEvent(events: EventEntity[]): EventEntity | null {
    for (const event of events) {
      if (TimelineExecutionState.isStartable(event)) {
        return event;
      }
    }
    return null;
  }

  public static getActionsForState(state: CompanionRuntimeState): CompanionActions {
    switch (state) {
      case 'ACTIVE':
        return {
          canStart: false,
          canEnd: true,
          canSkip: true,
          canNavigate: true,
          canViewDetail: true
        };
      case 'READY':
        return {
          canStart: true,
          canEnd: false,
          canSkip: true,
          canNavigate: true,
          canViewDetail: true
        };
      default:
        return {
          canStart: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        };
    }
  }
}
