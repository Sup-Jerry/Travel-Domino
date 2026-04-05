import { ComposableStrategy } from '../../domain/strategy/TravelStrategyDimensions';
import {
  ExecutionSuggestionApplyResult,
  ITimelineAiService
} from '../../domain/timeline/services/TimelineAiService';
import { WeatherStrategyAdjustment } from '../../common/utils/weather/WeatherReminderStore';
import { PlanPersistenceFacade } from '../internal/PlanPersistenceFacade';

export interface ITimelineStrategyHost {
  planId: number;
  persistence: PlanPersistenceFacade;
}

export class TimelineStrategyManager {
  private readonly host: ITimelineStrategyHost;
  private readonly aiService: ITimelineAiService;

  constructor(host: ITimelineStrategyHost, aiService: ITimelineAiService) {
    this.host = host;
    this.aiService = aiService;
  }

  public async generateByAi(userPrompt: string, strategyMode: number = 0, customStrategy?: ComposableStrategy): Promise<void> {
    await this.aiService.generateByAi(userPrompt, strategyMode, customStrategy);
  }

  public getStrategyMode(): number {
    return this.aiService.getStrategyMode();
  }

  public hasAiHistory(): boolean {
    return this.aiService.hasAiHistory();
  }

  public async updateStrategyMode(mode: number): Promise<void> {
    await this.aiService.updateStrategyMode(mode);
  }

  public async switchToCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await this.aiService.switchToCustomStrategy(strategy);
  }

  public async applyWeatherStrategyAdjustment(
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<boolean> {
    return this.aiService.applyWeatherStrategyAdjustment(adjustment, hint);
  }

  public async applyExecutionSuggestionWithStrategy(
    planId: number,
    suggestionId: string,
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    return this.aiService.applyExecutionSuggestionWithStrategy(planId, suggestionId, adjustment, hint);
  }

  public async triggerStrategyAdaptation(): Promise<void> {
    await this.aiService.triggerStrategyAdaptation();
  }

  public async regenerateWithCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await this.aiService.regenerateWithCustomStrategy(strategy);
  }

  public async regenerateByCurrentStrategy(): Promise<void> {
    await this.aiService.regenerateByCurrentStrategy();
  }

  public async changeStrategyAndRegenerate(mode: number): Promise<void> {
    await this.aiService.changeStrategyAndRegenerate(mode);
  }

  public async getCurrentStrategy(): Promise<ComposableStrategy> {
    const snapshot = await this.host.persistence.getPlanAndEvents(this.host.planId);
    if (!snapshot.plan) {
      return { density: 1, pace: 1, preference: 0, energy: 1 };
    }
    return {
      density: snapshot.plan.strategyDensity ?? 1,
      pace: snapshot.plan.strategyPace ?? 1,
      preference: snapshot.plan.strategyPreference ?? 0,
      energy: snapshot.plan.strategyEnergy ?? 1
    };
  }

  public clampStrategyLevel(value: number): 0 | 1 | 2 {
    if (value <= 0) {
      return 0;
    }
    if (value >= 2) {
      return 2;
    }
    return 1;
  }

  public composeWeatherConstraintPrompt(weatherAwareConstraint: string, weatherSummary: string): string {
    return `\n【策略天气联合约束】\n${weatherAwareConstraint}\n${weatherSummary}\n请把天气与策略作为联合软约束，不要输出不可执行路线，并根据用户天气偏好优化建议。`;
  }

  public buildWeatherStrategyAdaptationKey(generatedAt: number, routeScore: number): string {
    const safeGeneratedAt = Number.isFinite(generatedAt) ? Math.max(0, Math.floor(generatedAt)) : 0;
    const safeScore = Number.isFinite(routeScore) ? Math.max(0, Math.floor(routeScore)) : -1;
    return `${safeGeneratedAt}_${safeScore}`;
  }
}
