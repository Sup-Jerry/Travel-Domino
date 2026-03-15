// @deprecated 使用 IEventRepository 替代
// 此文件将在阶段5删除
import { EventRepositoryImpl } from '../../infrastructure/persistence/EventRepositoryImpl';
import { TravelPlanItem } from '../interface/IStandardEvent';
import type {
  EventFieldUpdate,
  RuntimeTransitionInput,
  RuntimeTransitionResult,
  ActiveEventSnapshot
} from '../../domain/ports/IEventRepository';

export class EventDao {
  static insertEvent(planId: number, item: TravelPlanItem): Promise<number> {
    return EventRepositoryImpl.insertEvent(planId, item);
  }
  static saveAllEvents(planId: number, events: TravelPlanItem[]): Promise<void> {
    return EventRepositoryImpl.saveAllEvents(planId, events);
  }
  static getAllEvents(planId: number): Promise<TravelPlanItem[]> {
    return EventRepositoryImpl.getAllEvents(planId);
  }
  static updateDayOffset(id: number, dayOffset: number): Promise<void> {
    return EventRepositoryImpl.updateDayOffset(id, dayOffset);
  }
  static updateTimelineConsistency(events: TravelPlanItem[], planIdHint: number = -1): Promise<void> {
    return EventRepositoryImpl.updateTimelineConsistency(events, planIdHint);
  }
  static updateSingleField(id: number, column: string, value: Object, planIdHint: number = -1): Promise<void> {
    return EventRepositoryImpl.updateSingleField(id, column, value, planIdHint);
  }
  static updateFields(id: number, updates: EventFieldUpdate[], planIdHint: number = -1): Promise<void> {
    return EventRepositoryImpl.updateFields(id, updates, planIdHint);
  }
  static applyRuntimeTransition(input: RuntimeTransitionInput): Promise<RuntimeTransitionResult> {
    return EventRepositoryImpl.applyRuntimeTransition(input) as Promise<RuntimeTransitionResult>;
  }
  static findGlobalActiveEvent(excludeEventId: number = -1): Promise<ActiveEventSnapshot | null> {
    return EventRepositoryImpl.findGlobalActiveEvent(excludeEventId);
  }
  static softDeleteEvent(id: number): Promise<void> {
    return EventRepositoryImpl.softDeleteEvent(id);
  }
  static hardDeleteEvent(id: number): Promise<void> {
    return EventRepositoryImpl.hardDeleteEvent(id);
  }
  static markPlanDirty(planId: number): void {
    return EventRepositoryImpl.markPlanDirty(planId);
  }
  static consumeDirtyPlanIds(): number[] {
    return EventRepositoryImpl.consumeDirtyPlanIds();
  }
}

export type {
  EventFieldUpdate,
  RuntimeTransitionInput,
  RuntimeTransitionResult,
  ActiveEventSnapshot
} from '../../domain/ports/IEventRepository';
export type { RuntimeTransitionType } from '../../domain/ports/IEventRepository';
