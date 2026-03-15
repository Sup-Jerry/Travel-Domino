// Repository接口：事件数据访问抽象
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

export interface EventFieldUpdate {
  column: string;
  value: number | string | boolean | null;
}

export type RuntimeTransitionType = 'START' | 'END' | 'SKIP' | 'REOPEN';

export interface RuntimeTransitionInput {
  planId: number;
  eventId: number;
  transition: RuntimeTransitionType;
  timestamp: number;
}

export interface RuntimeTransitionResult {
  ok: boolean;
  reason: string;
  startTime: number;
  endTime: number;
  completionStatus: number;
}

export interface ActiveEventSnapshot {
  eventId: number;
  planId: number;
  name: string;
  actualStartTime: number;
}

export interface IEventRepository {
  insertEvent(planId: number, item: TravelPlanItem): Promise<number>;
  saveAllEvents(planId: number, events: TravelPlanItem[]): Promise<void>;
  getAllEvents(planId: number): Promise<TravelPlanItem[]>;
  updateDayOffset(id: number, dayOffset: number): Promise<void>;
  updateTimelineConsistency(events: TravelPlanItem[], planIdHint?: number): Promise<void>;
  updateSingleField(id: number, column: string, value: Object, planIdHint?: number): Promise<void>;
  updateFields(id: number, updates: EventFieldUpdate[], planIdHint?: number): Promise<void>;
  applyRuntimeTransition(input: RuntimeTransitionInput): Promise<RuntimeTransitionResult>;
  findGlobalActiveEvent(excludeEventId?: number): Promise<ActiveEventSnapshot | null>;
  softDeleteEvent(id: number): Promise<void>;
  hardDeleteEvent(id: number): Promise<void>;
  markPlanDirty(planId: number): void;
  consumeDirtyPlanIds(): number[];
}
