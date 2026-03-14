// path: domain/timeline/HistoryManager.ets
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineExecutionState } from '../policy/TimelineExecutionState';

export type HistoryTimelineFilter = 'all' | 'completed' | 'skipped' | 'abnormal';
export type HistoryTimelineActionType = 'ARRIVE' | 'LEAVE' | 'SKIP' | 'ACTIVE';

export interface HistoryTimelineItem {
  id: number;
  eventId: number;
  placeName: string;
  actionType: HistoryTimelineActionType;
  plannedStart: number;
  actualStart: number;
  actualEnd: number;
  stayMinutes: number;
  deviationMinutes: number;
  status: number;
  groupDateKey: string;
  address: string;
  note: string;
  displayTs: number;
  isAbnormal: boolean;
}

export interface HistoryTimelineSummary {
  planName: string;
  completedCount: number;
  skippedCount: number;
  activeCount: number;
}

export class HistoryManager {
  public static generateSummary(events: EventEntity[], planName: string, planId: number): HistoryTimelineSummary {
    let completedCount = 0;
    let skippedCount = 0;
    let activeCount = 0;

    for (const event of events) {
      if (!TimelineExecutionState.isScheduled(event)) continue;

      if (TimelineExecutionState.isCompleted(event)) {
        completedCount++;
      } else if (TimelineExecutionState.isSkipped(event)) {
        skippedCount++;
      } else if (TimelineExecutionState.isActive(event)) {
        activeCount++;
      }
    }

    return {
      planName: (planName || '').trim().length > 0 ? planName : `计划 #${planId}`,
      completedCount,
      skippedCount,
      activeCount
    };
  }
}
