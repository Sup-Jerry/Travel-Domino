import { EventEntity } from '../../model/entity/EventEntity';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlanStatus } from '../statemachine/PlanStatus';
import {
  GeoPointInput,
  WeatherCollabOptions,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from './WeatherModels';
import { WeatherDomainService } from './WeatherDomainService';
import { WeatherStageCoordinator } from './WeatherStageCoordinator';

export class WeatherFacade {
  private static readonly TAG: string = 'WeatherFacade';
  private readonly domainService: WeatherDomainService;
  private readonly stageCoordinator: WeatherStageCoordinator;

  constructor(domainService?: WeatherDomainService, stageCoordinator?: WeatherStageCoordinator) {
    this.domainService = domainService ?? new WeatherDomainService();
    this.stageCoordinator = stageCoordinator ?? new WeatherStageCoordinator();
  }

  public resolveStage(
    status: PlanStatus,
    events: EventEntity[],
    runtimeState?: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP'
  ): WeatherStageType {
    const stage = this.stageCoordinator.resolveStage(status, events, runtimeState);
    hilog.info(0x0000, WeatherFacade.TAG, `[WEATHER_STAGE][resolve] planStatus=${status}, runtime=${runtimeState ?? 'NONE'}, stage=${stage}`);
    return stage;
  }

  public resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    return this.stageCoordinator.resolveSchedulePolicy(stage);
  }

  public async buildPlanningContext(
    events: EventEntity[],
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    return this.domainService.buildPlanningContext(events, preference, options, stage);
  }

  public async buildExecutionContext(
    events: EventEntity[],
    currentLocation?: GeoPointInput,
    forceRefresh: boolean = false,
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    return this.domainService.buildExecutionContext(events, currentLocation, forceRefresh, preference, options, stage);
  }

  public buildExecutionAdjustments(
    planId: number,
    context: WeatherContext,
    futureNodes: EventEntity[],
    preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    return this.domainService.buildExecutionAdjustments(planId, context, futureNodes, preference);
  }

  public buildPromptSummary(context: WeatherContext, preference?: WeatherUserPreference): string {
    return this.domainService.buildPromptSummary(context, preference);
  }
}
