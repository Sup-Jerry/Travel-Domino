import { EventEntity } from '../../model/entity/EventEntity';
import { WeatherContextBuilder } from './WeatherContextBuilder';
import {
  GeoPointInput,
  WeatherCollabOptions,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from './WeatherModels';

export class WeatherDomainService {
  private readonly contextBuilder: WeatherContextBuilder;

  constructor(contextBuilder?: WeatherContextBuilder) {
    this.contextBuilder = contextBuilder ?? new WeatherContextBuilder();
  }

  public async buildPlanningContext(
    events: EventEntity[],
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    return this.contextBuilder.buildPlanningContext(events, preference, options, stage);
  }

  public async buildExecutionContext(
    events: EventEntity[],
    currentLocation?: GeoPointInput,
    forceRefresh: boolean = false,
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    return this.contextBuilder.buildExecutionContext(events, currentLocation, forceRefresh, preference, options, stage);
  }

  public buildExecutionAdjustments(
    planId: number,
    context: WeatherContext,
    futureNodes: EventEntity[],
    preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    return this.contextBuilder.buildExecutionAdjustments(planId, context, futureNodes, preference, context.collabContext);
  }

  public buildPromptSummary(context: WeatherContext, preference?: WeatherUserPreference): string {
    return this.contextBuilder.buildPromptSummary(context, preference);
  }
}
