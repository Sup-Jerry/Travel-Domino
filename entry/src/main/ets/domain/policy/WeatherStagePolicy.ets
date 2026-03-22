import { EventEntity } from '../../model/entity/EventEntity';
import { PlanStatus } from '../statemachine/PlanStatus';
import { WeatherStageType } from '../services/WeatherModels';

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
}
