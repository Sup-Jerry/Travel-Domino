import { EventEntity } from '../../model/entity/EventEntity';
import { PlanStatus } from '../statemachine/PlanStatus';
import { WeatherStageType } from '../services/WeatherModels';

export type WeatherPlanningStage = 'PLANNING' | 'EXECUTION';

export class WeatherStagePolicy {
  public static resolveDetailedStage(
    status?: PlanStatus,
    events?: EventEntity[],
    runtimeState?: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP'
  ): WeatherStageType {
    if (status === PlanStatus.CONFIRMED) {
      return 'CONFIRMED';
    }
    if (status === PlanStatus.READY) {
      return 'READY';
    }
    if (status === PlanStatus.PAUSED || runtimeState === 'PAUSED') {
      return 'PAUSED';
    }
    if (status === PlanStatus.IN_PROGRESS) {
      return 'IN_PROGRESS';
    }

    if (events && events.length > 0) {
      for (let i = 0; i < events.length; i++) {
        const event = events[i];
        if (event.status === 1 &&
          event.completion_status === EventEntity.STATE_PENDING &&
          event.actual_start_time > 0) {
          return 'IN_PROGRESS';
        }
      }
      const hasScheduled = events.some((event: EventEntity) => event.status === 1);
      if (hasScheduled) {
        return 'CONFIRMED';
      }
    }
    return 'PLANNING';
  }

  public static resolveStageForEvent(event: EventEntity): WeatherPlanningStage {
    if (!event) {
      return 'PLANNING';
    }
    const isExecution = event.status === 1 &&
      event.completion_status === EventEntity.STATE_PENDING &&
      event.actual_start_time > 0;
    return isExecution ? 'EXECUTION' : 'PLANNING';
  }

  public static resolveStageForPlan(events: EventEntity[]): WeatherPlanningStage {
    const stage = WeatherStagePolicy.resolveDetailedStage(undefined, events);
    return stage === 'IN_PROGRESS' || stage === 'READY' || stage === 'PAUSED' ? 'EXECUTION' : 'PLANNING';
  }
}
