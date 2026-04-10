import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../../model/entity/EventEntity';
import { TravelPlanItem } from '../../../model/interface/IStandardEvent';
import { EventRepositoryImpl } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl } from '../../../infrastructure/persistence/PlanRepositoryImpl';
import { AiService } from '../../../infrastructure/services/AiService';
import { ComposableStrategy } from '../../strategy/TravelStrategyDimensions';
import { StrategyService } from '../../strategy/StrategyService';
import { UserProfileService } from '../../strategy/UserProfileService';
import { UserBehaviorTracker } from '../../strategy/UserBehaviorTracker';
import { StrategyAdaptationEngine, AdaptationPrompt } from '../../strategy/StrategyAdaptationEngine';
import {
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference,
  WeatherCollabOptions,
  SoftReplanApplyResult,
  SoftReplanMode
} from '../../services/WeatherModels';
import { WeatherFacade } from '../../services/WeatherFacade';
import { WeatherStrategyAdjustment } from '../../../common/utils/weather/WeatherReminderStore';
import { PlanPersistenceFacade } from '../../../viewmodel/internal/PlanPersistenceFacade';

const TAG = 'TimelineViewModel';

export interface ExecutionSuggestionApplyResult {
  strategyApplied: boolean;
  replanSuccess: boolean;
  errorCode: string;
}

export interface ITimelineAiHost {
  events: EventEntity[];
  planId: number;
  currentStrategyMode: number;
  isRegenerating: boolean;
  weatherFeatureEnabled: boolean;
  weatherUserPreference: WeatherUserPreference;
  weatherCollabOptions: WeatherCollabOptions;
  weatherStrategyHint: string;
  strategyAdaptationPrompt: AdaptationPrompt | null;
  behaviorTracker: UserBehaviorTracker;
  persistence: PlanPersistenceFacade;
  weatherFacade: WeatherFacade;

  resolveCurrentWeatherStage(): WeatherStageType;
  applyPlanningWeatherResult(result: WeatherContextBuildResult, forceRefresh: boolean): Promise<void>;
  composeWeatherConstraintPrompt(weatherAwareConstraint: string, weatherSummary: string): string;
  getCurrentStrategy(): Promise<ComposableStrategy>;
  clampStrategyLevel(value: number): 0 | 1 | 2;
  requestSoftReplan(planId: number, suggestionId: string, mode: SoftReplanMode): Promise<SoftReplanApplyResult>;
  markScheduleChanged(): void;
}

export interface ITimelineAiService {
  generateByAi(userPrompt: string, strategyMode?: number, customStrategy?: ComposableStrategy): Promise<void>;
  getStrategyMode(): number;
  hasAiHistory(): boolean;
  updateStrategyMode(mode: number): Promise<void>;
  switchToCustomStrategy(strategy: ComposableStrategy): Promise<void>;
  applyWeatherStrategyAdjustment(adjustment?: WeatherStrategyAdjustment, hint?: string): Promise<boolean>;
  applyExecutionSuggestionWithStrategy(
    planId: number,
    suggestionId: string,
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<ExecutionSuggestionApplyResult>;
  applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult>;
  regenerateWithCustomStrategy(strategy: ComposableStrategy): Promise<void>;
  regenerateByCurrentStrategy(): Promise<void>;
  changeStrategyAndRegenerate(mode: number): Promise<void>;
  triggerStrategyAdaptation(): Promise<void>;
}

export class TimelineAiService implements ITimelineAiService {
  private host: ITimelineAiHost;

  constructor(host: ITimelineAiHost) {
    this.host = host;
  }

  public static buildAiDayOffsets(totalItems: number, requestedDays: number, baseDayOffset: number): number[] {
    const safeTotal = Number.isFinite(totalItems) ? Math.max(0, Math.floor(totalItems)) : 0;
    const safeDays = Number.isFinite(requestedDays) ? Math.max(1, Math.floor(requestedDays)) : 1;
    const safeBase = Number.isFinite(baseDayOffset) ? Math.floor(baseDayOffset) : 0;
    if (safeTotal === 0) {
      return [];
    }

    const quotas: number[] = [];
    const baseCount = Math.floor(safeTotal / safeDays);
    const remainder = safeTotal % safeDays;
    for (let d = 0; d < safeDays; d++) {
      quotas.push(baseCount + (d < remainder ? 1 : 0));
    }

    const offsets: number[] = [];
    for (let i = 0; i < safeTotal; i++) {
      let remain = i;
      let targetDay = 0;
      for (let d = 0; d < quotas.length; d++) {
        if (remain < quotas[d]) {
          targetDay = d;
          break;
        }
        remain -= quotas[d];
      }
      offsets.push(safeBase + targetDay);
    }
    return offsets;
  }

  public async generateByAi(userPrompt: string, strategyMode: number = 0, customStrategy?: ComposableStrategy): Promise<void> {
    try {
      this.host.currentStrategyMode = strategyMode;
      const requestedDays = AiService.resolveRequestedDaysFromPrompt(userPrompt);
      hilog.info(
        0x0000,
        TAG,
        `[AI_DEBUG][timeline_generate_begin] mode=${strategyMode}, custom=${customStrategy ? 1 : 0}, requestedDays=${requestedDays}, promptLen=${userPrompt.length}, eventsBefore=${this.host.events.length}`
      );

      const existingPlaces = this.host.events
        .filter((event: EventEntity) => event.source === 1)
        .map((event: EventEntity) => event.name)
        .filter((name: string) => name.length > 0);

      const scheduleEvents = this.host.events.filter((event: EventEntity) => event.status === 1);
      let startTimeHint = '建议从上午9:00开始';
      if (scheduleEvents.length > 0) {
        const lastEvent = scheduleEvents[scheduleEvents.length - 1];
        const lastEndTime = lastEvent.dynamic_end_time;
        if (lastEndTime > 0) {
          const lastDate = new Date(lastEndTime);
          const nextDay = new Date(lastDate);
          nextDay.setDate(nextDay.getDate() + 1);
          nextDay.setHours(9, 0, 0, 0);
          startTimeHint = `建议从${nextDay.getMonth() + 1}月${nextDay.getDate()}日上午9:00开始`;
        }
      }

      let enhancedPrompt = userPrompt;
      if (existingPlaces.length > 0) {
        enhancedPrompt += `\n【已有地点】请避免重复：${existingPlaces.join('、')}`;
      }
      enhancedPrompt += `\n【起始时间】${startTimeHint}`;
      if (this.host.weatherFeatureEnabled) {
        try {
          const weatherStage = this.host.resolveCurrentWeatherStage();
          const weatherResult = await this.host.weatherFacade.buildPlanningContext(
            this.host.events,
            this.host.weatherUserPreference,
            this.host.weatherCollabOptions,
            weatherStage
          );
          const effectiveStrategy = customStrategy ?? await this.host.getCurrentStrategy();
          const weatherAwareConstraint = StrategyService.buildWeatherAwareConstraint(
            effectiveStrategy,
            weatherResult.context.routeSuitability.routeScore,
            weatherResult.context.routeSuitability.riskTags,
            weatherResult.context.collabContext?.trendTag,
            strategyMode
          );
          const weatherSummary = this.host.weatherFacade.buildPromptSummary(weatherResult.context, this.host.weatherUserPreference);
          enhancedPrompt += this.host.composeWeatherConstraintPrompt(weatherAwareConstraint, weatherSummary);
          await this.host.applyPlanningWeatherResult(weatherResult, false);
        } catch (_weatherError) {
          enhancedPrompt += '\n【天气约束】天气数据暂不可用，请优先保证路线可执行性。';
        }
      } else {
        enhancedPrompt += '\n【天气约束】用户已关闭天气功能，请忽略天气因素。';
      }

      const aiItems = await AiService.generateItineraryWithStrategy({
        userPrompt: enhancedPrompt,
        strategyMode: customStrategy ? -1 : strategyMode,
        customStrategy: customStrategy
      });
      const scenicCount = aiItems.filter((item) => item.type === 0).length;
      const foodCount = aiItems.filter((item) => item.type === 1).length;
      const hotelCount = aiItems.filter((item) => item.type === 2).length;
      hilog.info(
        0x0000,
        TAG,
        `[AI_DEBUG][timeline_generate_result] mode=${strategyMode}, requestedDays=${requestedDays}, itemCount=${aiItems.length}, scenic=${scenicCount}, food=${foodCount}, hotel=${hotelCount}`
      );

      if (!aiItems || aiItems.length === 0) {
        throw new Error('AI 未返回可用地点，请调整描述后重试');
      }

      const explanation = StrategyService.buildStrategyExplanation(strategyMode);
      await this.host.persistence.saveAiContext(this.host.planId, userPrompt, explanation);

      if (customStrategy) {
        await PlanRepositoryImpl.updateStrategyDimensions(
          this.host.planId,
          customStrategy.density,
          customStrategy.pace,
          customStrategy.preference,
          customStrategy.energy
        );
      } else {
        await this.host.persistence.updateStrategyMode(this.host.planId, strategyMode);
      }

      UserProfileService.recordStrategyUsage(strategyMode, customStrategy).catch(() => {});

      const existingSchedule = this.host.events.filter((event: EventEntity) => event.status === 1);
      const baseDayOffset = existingSchedule.length > 0
        ? Math.max(...existingSchedule.map((event: EventEntity) => event.day_offset || 0)) + 1
        : 0;
      const allocatedDayOffsets = TimelineAiService.buildAiDayOffsets(aiItems.length, requestedDays, baseDayOffset);
      hilog.info(
        0x0000,
        TAG,
        `[AI_DEBUG][timeline_day_offset_alloc] mode=${strategyMode}, baseDayOffset=${baseDayOffset}, requestedDays=${requestedDays}, allocatedCount=${allocatedDayOffsets.length}`
      );

      for (let i = 0; i < aiItems.length; i++) {
        const item = aiItems[i];
        const allocatedDayOffset = allocatedDayOffsets[i] ?? baseDayOffset;
        const newItemInterface: TravelPlanItem = {
          name: item.name,
          duration: item.duration,
          type: 'FLOW',
          preTravelMinutes: -1,
          sortOrder: 0,
          status: 0,
          lockStatus: 0,
          fixedStartTime: undefined,
          dayOffset: allocatedDayOffset,
          itemType: item.type,
          priority: item.type === 1 ? 0 : 1,
          isTravelManual: 0,
          source: 1,
          aiReasoning: item.ai_reasoning || 'AI 智能推荐',
          delFlag: 0,
          groupId: 0,
          address: '',
          travelMode: 2
        };

        const newId = await EventRepositoryImpl.insertEvent(this.host.planId, newItemInterface);
        newItemInterface.id = newId;

        const newEntity = EventEntity.fromInterface(newItemInterface, this.host.planId);
        this.host.events.push(newEntity);
      }

      this.host.markScheduleChanged();
      this.host.events = [...this.host.events];
      hilog.info(
        0x0000,
        TAG,
        `[AI_DEBUG][timeline_generate_done] mode=${strategyMode}, eventsAfter=${this.host.events.length}`
      );
    } catch (error) {
      console.error(TAG, 'AI Generation Failed');
      hilog.error(
        0x0000,
        TAG,
        `[AI_DEBUG][timeline_generate_fail] mode=${strategyMode}, reason=${error instanceof Error ? error.message : JSON.stringify(error)}`
      );

      if (error instanceof Error) {
        throw error;
      }
      throw new Error(JSON.stringify(error));
    }
  }

  public getStrategyMode(): number {
    return this.host.currentStrategyMode;
  }

  public hasAiHistory(): boolean {
    return this.host.events.some((event: EventEntity) => event.source === 1);
  }

  public async updateStrategyMode(mode: number): Promise<void> {
    this.host.currentStrategyMode = mode;
    await this.host.persistence.updateStrategyMode(this.host.planId, mode);
  }

  public async switchToCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await PlanRepositoryImpl.updateStrategyDimensions(
      this.host.planId,
      strategy.density,
      strategy.pace,
      strategy.preference,
      strategy.energy
    );
    this.host.currentStrategyMode = -1;
  }

  public async applyWeatherStrategyAdjustment(
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<boolean> {
    if (!adjustment) {
      return false;
    }
    const hasAdjustment = adjustment.density !== undefined ||
      adjustment.pace !== undefined ||
      adjustment.energy !== undefined;
    if (!hasAdjustment) {
      return false;
    }

    const current = await this.host.getCurrentStrategy();
    const next: ComposableStrategy = {
      density: current.density,
      pace: current.pace,
      preference: current.preference,
      energy: current.energy
    };

    if (adjustment.density !== undefined) {
      next.density = this.host.clampStrategyLevel(current.density + adjustment.density);
    }
    if (adjustment.pace !== undefined) {
      next.pace = this.host.clampStrategyLevel(current.pace + adjustment.pace);
    }
    if (adjustment.energy !== undefined) {
      next.energy = this.host.clampStrategyLevel(current.energy + adjustment.energy);
    }

    const changed = next.density !== current.density ||
      next.pace !== current.pace ||
      next.energy !== current.energy;
    if (!changed) {
      return false;
    }

    await PlanRepositoryImpl.updateStrategyDimensions(
      this.host.planId,
      next.density,
      next.pace,
      next.preference,
      next.energy
    );
    this.host.currentStrategyMode = -1;
    if (hint && hint.trim().length > 0) {
      this.host.weatherStrategyHint = hint.trim();
    }
    return true;
  }

  public async applyExecutionSuggestionWithStrategy(
    planId: number,
    suggestionId: string,
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    const strategyApplied = await this.applyWeatherStrategyAdjustment(adjustment, hint);
    const replan = await this.host.requestSoftReplan(planId, suggestionId, 'APPLY');
    return {
      strategyApplied: strategyApplied,
      replanSuccess: replan.success,
      errorCode: replan.errorCode || 'REPLAN_CONFLICT'
    };
  }

  public async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    return this.host.requestSoftReplan(this.host.planId, suggestionId, 'APPLY');
  }

  public async triggerStrategyAdaptation(): Promise<void> {
    const currentStrategy = await this.host.getCurrentStrategy();
    const context = this.host.behaviorTracker.getBehaviorContext(this.host.planId, currentStrategy);
    const decision = StrategyAdaptationEngine.analyzeAndDecide(context);

    if (!decision) {
      return;
    }

    const adjustedStrategy = StrategyAdaptationEngine.applyAdjustment(currentStrategy, decision);
    await PlanRepositoryImpl.updateStrategyDimensions(
      this.host.planId,
      adjustedStrategy.density,
      adjustedStrategy.pace,
      adjustedStrategy.preference,
      adjustedStrategy.energy
    );

    this.host.behaviorTracker.reset();
    hilog.info(0x0000, TAG, `[策略自适应] ${decision.message}`);

    this.host.strategyAdaptationPrompt = {
      message: decision.message,
      oldStrategy: currentStrategy,
      newStrategy: adjustedStrategy
    };
  }

  public async regenerateWithCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    await this.switchToCustomStrategy(strategy);
    await this.regenerateByCurrentStrategy();
  }

  public async regenerateByCurrentStrategy(): Promise<void> {
    if (this.host.isRegenerating) {
      hilog.warn(0x0000, TAG, '[AI重新生成] 正在生成中，忽略重复请求');
      return;
    }

    const snapshot = await this.host.persistence.getPlanAndEvents(this.host.planId);
    if (!snapshot.plan || !snapshot.plan.lastAiPrompt) {
      throw new Error('未找到上次生成记录');
    }

    this.host.isRegenerating = true;
    const oldAiEvents = this.host.events.filter((event: EventEntity) => event.source === 1);
    hilog.info(0x0000, TAG, `[AI重新生成] 开始，旧事件数: ${oldAiEvents.length}`);

    try {
      await this.generateByAi(snapshot.plan.lastAiPrompt, this.host.currentStrategyMode);

      await EventRepositoryImpl.deleteEventsBySource(this.host.planId, 1);

      const newAiEvents = this.host.events.filter((event: EventEntity) =>
        event.source === 1 && !oldAiEvents.some((old: EventEntity) => old.id === event.id)
      );
      this.host.events = this.host.events.filter((event: EventEntity) =>
        event.source !== 1 || newAiEvents.some((next: EventEntity) => next.id === event.id)
      );
      hilog.info(0x0000, TAG, `[AI重新生成] 成功，新事件数: ${newAiEvents.length}`);
    } catch (error) {
      hilog.error(0x0000, TAG, '[AI重新生成] 失败，保留旧数据');
      throw error instanceof Error ? error : new Error('生成失败');
    } finally {
      this.host.isRegenerating = false;
    }
  }

  public async changeStrategyAndRegenerate(mode: number): Promise<void> {
    if (this.host.isRegenerating) {
      hilog.warn(0x0000, TAG, '[切换策略] 正在生成中，忽略重复请求');
      return;
    }

    const snapshot = await this.host.persistence.getPlanAndEvents(this.host.planId);
    if (!snapshot.plan || !snapshot.plan.lastAiPrompt) {
      throw new Error('未找到上次生成记录');
    }

    this.host.isRegenerating = true;
    const oldAiEvents = this.host.events.filter((event: EventEntity) => event.source === 1);
    hilog.info(0x0000, TAG, `[切换策略] 模式${mode}，旧事件数: ${oldAiEvents.length}`);

    try {
      this.host.currentStrategyMode = mode;
      await this.host.persistence.updateStrategyMode(this.host.planId, mode);
      await this.generateByAi(snapshot.plan.lastAiPrompt, mode);

      await EventRepositoryImpl.deleteEventsBySource(this.host.planId, 1);

      const newAiEvents = this.host.events.filter((event: EventEntity) =>
        event.source === 1 && !oldAiEvents.some((old: EventEntity) => old.id === event.id)
      );
      this.host.events = this.host.events.filter((event: EventEntity) =>
        event.source !== 1 || newAiEvents.some((next: EventEntity) => next.id === event.id)
      );
      hilog.info(0x0000, TAG, `[切换策略] 成功，新事件数: ${newAiEvents.length}`);
    } catch (error) {
      hilog.error(0x0000, TAG, '[切换策略] 失败，保留旧数据');
      throw error instanceof Error ? error : new Error('生成失败');
    } finally {
      this.host.isRegenerating = false;
    }
  }
}

