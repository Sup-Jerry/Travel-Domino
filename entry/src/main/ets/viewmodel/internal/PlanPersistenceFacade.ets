import { EventDao, EventFieldUpdate, RuntimeTransitionInput, RuntimeTransitionResult } from '../../model/entity/EventDao';
import { PlanDao, PlanItem } from '../../model/entity/PlanDao';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

export interface PlanEventsSnapshot {
  plan?: PlanItem;
  events: TravelPlanItem[];
}

export class PlanPersistenceFacade {
  public async getPlanAndEvents(planId: number): Promise<PlanEventsSnapshot> {
    const results = await Promise.all([
      PlanDao.getPlanById(planId),
      EventDao.getAllEvents(planId)
    ]);
    const snapshot: PlanEventsSnapshot = {
      plan: results[0] as PlanItem | undefined,
      events: results[1] as TravelPlanItem[]
    };
    return snapshot;
  }

  public async applyRuntimeTransition(input: RuntimeTransitionInput): Promise<RuntimeTransitionResult> {
    return EventDao.applyRuntimeTransition(input);
  }

  public updateSingleField(eventId: number, column: string, value: Object, planId: number): Promise<void> {
    return EventDao.updateSingleField(eventId, column, value, planId);
  }

  public async updateFields(eventId: number, updates: EventFieldUpdate[], planId: number): Promise<void> {
    await EventDao.updateFields(eventId, updates, planId);
  }

  public async updateTimelineConsistency(events: TravelPlanItem[], planId: number): Promise<void> {
    await EventDao.updateTimelineConsistency(events, planId);
  }

  public async insertEvent(planId: number, item: TravelPlanItem): Promise<number> {
    return EventDao.insertEvent(planId, item);
  }

  public async saveAllEvents(planId: number, events: TravelPlanItem[]): Promise<void> {
    await EventDao.saveAllEvents(planId, events);
  }

  public async hardDeleteEvent(eventId: number): Promise<void> {
    await EventDao.hardDeleteEvent(eventId);
  }

  public async updatePlanStartDate(planId: number, startDate: number): Promise<void> {
    await PlanDao.updateStartDate(planId, startDate);
  }

  public async updatePlanName(planId: number, name: string): Promise<void> {
    await PlanDao.updatePlanName(planId, name);
  }

  public async updateAutoAmapRoute(planId: number, enabled: boolean): Promise<void> {
    await PlanDao.updateAutoAmapRoute(planId, enabled);
  }
}
