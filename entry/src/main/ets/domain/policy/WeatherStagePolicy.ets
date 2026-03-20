import { EventEntity } from '../../model/entity/EventEntity';

export type WeatherPlanningStage = 'PLANNING' | 'EXECUTION';

export class WeatherStagePolicy {
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
    if (!events || events.length === 0) {
      return 'PLANNING';
    }
    for (let i = 0; i < events.length; i++) {
      if (WeatherStagePolicy.resolveStageForEvent(events[i]) === 'EXECUTION') {
        return 'EXECUTION';
      }
    }
    return 'PLANNING';
  }
}
