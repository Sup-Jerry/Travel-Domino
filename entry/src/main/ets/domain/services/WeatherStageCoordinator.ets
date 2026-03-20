import { EventEntity } from '../../model/entity/EventEntity';
import { WeatherStagePolicy } from '../policy/WeatherStagePolicy';
import { PlanStatus } from '../statemachine/PlanStatus';
import { WeatherSchedulePolicy, WeatherStageType } from './WeatherModels';

export class WeatherStageCoordinator {
  public resolveStage(
    status: PlanStatus,
    events: EventEntity[],
    runtimeState?: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP'
  ): WeatherStageType {
    return WeatherStagePolicy.resolveDetailedStage(status, events, runtimeState);
  }

  public resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    if (stage === 'CONFIRMED') {
      return {
        stage: stage,
        pollIntervalMs: 120 * 60 * 1000,
        allowLocationTrigger: false,
        allowManualBypass: true,
        forceRefreshOnEnter: true
      };
    }
    if (stage === 'READY') {
      return {
        stage: stage,
        pollIntervalMs: 15 * 60 * 1000,
        allowLocationTrigger: true,
        allowManualBypass: true,
        forceRefreshOnEnter: true
      };
    }
    if (stage === 'IN_PROGRESS') {
      return {
        stage: stage,
        pollIntervalMs: 20 * 60 * 1000,
        allowLocationTrigger: true,
        allowManualBypass: true,
        forceRefreshOnEnter: true
      };
    }
    if (stage === 'PAUSED') {
      return {
        stage: stage,
        pollIntervalMs: 30 * 60 * 1000,
        allowLocationTrigger: true,
        allowManualBypass: true,
        forceRefreshOnEnter: false
      };
    }
    return {
      stage: 'PLANNING',
      pollIntervalMs: 0,
      allowLocationTrigger: false,
      allowManualBypass: true,
      forceRefreshOnEnter: false
    };
  }
}

