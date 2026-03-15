import { EventRepositoryImpl, EventFieldUpdate, RuntimeTransitionInput, RuntimeTransitionResult } from '../../infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl, PlanItem } from '../../infrastructure/persistence/PlanRepositoryImpl';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

export interface PlanEventsSnapshot {
  plan?: PlanItem;
  events: TravelPlanItem[];
}

export class PlanPersistenceFacade {
  public async getPlanAndEvents(planId: number): Promise<PlanEventsSnapshot> {
    const results = await Promise.all([
      PlanRepositoryImpl.getPlanById(planId),
      EventRepositoryImpl.getAllEvents(planId)
    ]);
    const snapshot: PlanEventsSnapshot = {
      plan: results[0] as PlanItem | undefined,
      events: results[1] as TravelPlanItem[]
    };
    return snapshot;
  }

  public async applyRuntimeTransition(input: RuntimeTransitionInput): Promise<RuntimeTransitionResult> {
    return EventRepositoryImpl.applyRuntimeTransition(input);
  }

  public updateSingleField(eventId: number, column: string, value: Object, planId: number): Promise<void> {
    return EventRepositoryImpl.updateSingleField(eventId, column, value, planId);
  }

  public async updateFields(eventId: number, updates: EventFieldUpdate[], planId: number): Promise<void> {
    await EventRepositoryImpl.updateFields(eventId, updates, planId);
  }

  public async updateTimelineConsistency(events: TravelPlanItem[], planId: number): Promise<void> {
    await EventRepositoryImpl.updateTimelineConsistency(events, planId);
  }

  public async insertEvent(planId: number, item: TravelPlanItem): Promise<number> {
    return EventRepositoryImpl.insertEvent(planId, item);
  }

  public async saveAllEvents(planId: number, events: TravelPlanItem[]): Promise<void> {
    await EventRepositoryImpl.saveAllEvents(planId, events);
  }

  public async hardDeleteEvent(eventId: number): Promise<void> {
    await EventRepositoryImpl.hardDeleteEvent(eventId);
  }

  public async updatePlanStartDate(planId: number, startDate: number): Promise<void> {
    await PlanRepositoryImpl.updateStartDate(planId, startDate);
  }

  public async updatePlanName(planId: number, name: string): Promise<void> {
    await PlanRepositoryImpl.updatePlanName(planId, name);
  }

  public async updateAutoAmapRoute(planId: number, enabled: boolean): Promise<void> {
    await PlanRepositoryImpl.updateAutoAmapRoute(planId, enabled);
  }
}
