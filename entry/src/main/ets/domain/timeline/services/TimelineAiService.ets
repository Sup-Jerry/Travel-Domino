import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../../model/entity/EventEntity';
import { TravelPlanItem } from '../../../model/interface/IStandardEvent';
import { EventRepositoryImpl } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl } from '../../../infrastructure/persistence/PlanRepositoryImpl';
import { AiGenerateRequest, AiRawItem, AiService } from '../../../infrastructure/services/AiService';
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

export type AiReplanApplyDecision = 'KEEP' | 'OVERWRITE';

export interface AiReplanPreviewItem {
  name: string;
  duration: number;
  itemType: number;
  aiReasoning: string;
}

export interface AiReplanPreviewResult {
  prompt: string;
  strategyMode: number;
  customStrategy?: ComposableStrategy;
  generatedAt: number;
  itemCount: number;
  items: AiReplanPreviewItem[];
}

export interface AiReplanUndoToken {
  createdAt: number;
  events: TravelPlanItem[];
  strategyMode: number;
  strategyDensity: number;
  strategyPace: number;
  strategyPreference: number;
  strategyEnergy: number;
  lastAiPrompt: string;
  lastStrategyExplanation: string;
}

interface EffectiveStrategyChoice {
  mode: number;
  customStrategy?: ComposableStrategy;
}

type InsertAiEventHook = (planId: number, item: TravelPlanItem) => Promise<number>;

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
  recalculateFromIndex(startIndex: number): void;
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
  buildReplanPreview(
    strategyMode: number,
    customStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult>;
  applyReplanPreview(
    preview: AiReplanPreviewResult,
    decision: AiReplanApplyDecision
  ): Promise<AiReplanUndoToken>;
  restoreFromUndoToken(token: AiReplanUndoToken): Promise<void>;
}

export class TimelineAiService implements ITimelineAiService {
  private static insertAiEventHookForTest: InsertAiEventHook | null = null;
  private host: ITimelineAiHost;

  constructor(host: ITimelineAiHost) {
    this.host = host;
  }

  public static setInsertAiEventHookForTest(hook: InsertAiEventHook | null): void {
    TimelineAiService.insertAiEventHookForTest = hook;
  }

  private static async insertAiEvent(planId: number, item: TravelPlanItem): Promise<number> {
    if (TimelineAiService.insertAiEventHookForTest) {
      return TimelineAiService.insertAiEventHookForTest(planId, item);
    }
    return EventRepositoryImpl.insertEvent(planId, item);
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

  private static normalizeStrategyMode(mode: number): number {
    if (mode === -1 || mode === 0 || mode === 1 || mode === 2) {
      return mode;
    }
    return 0;
  }

  private static cloneCustomStrategy(strategy?: ComposableStrategy): ComposableStrategy | undefined {
    if (!strategy) {
      return undefined;
    }
    return {
      density: strategy.density,
      pace: strategy.pace,
      preference: strategy.preference,
      energy: strategy.energy
    };
  }

  private async resolveHistoryPrompt(): Promise<string> {
    const snapshot = await this.host.persistence.getPlanAndEvents(this.host.planId);
    const prompt = (snapshot.plan?.lastAiPrompt || '').trim();
    hilog.info(
      0x0000,
      TAG,
      `[airest]AI_REPLAN_TRACE[service_history_prompt] planId=${this.host.planId}, promptLen=${prompt.length}`
    );
    if (prompt.length === 0) {
      throw new Error('未找到上次生成记录');
    }
    return prompt;
  }

  private async resolveEffectiveStrategy(
    requestedMode: number,
    requestedCustomStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<EffectiveStrategyChoice> {
    hilog.info(
      0x0000,
      TAG,
      `[airest]AI_REPLAN_TRACE[service_strategy_resolve_in] requestedMode=${requestedMode}, hasRequestedCustom=${requestedCustomStrategy ? 1 : 0}, keepCurrent=${keepCurrentMode === true ? 1 : 0}, currentMode=${this.host.currentStrategyMode}`
    );
    if (keepCurrentMode === true) {
      const currentMode = TimelineAiService.normalizeStrategyMode(this.host.currentStrategyMode);
      if (currentMode === -1) {
        const currentCustom = await this.host.getCurrentStrategy();
        const currentChoice: EffectiveStrategyChoice = {
          mode: -1,
          customStrategy: TimelineAiService.cloneCustomStrategy(currentCustom)
        };
        return currentChoice;
      }
      const currentModeChoice: EffectiveStrategyChoice = {
        mode: currentMode
      };
      return currentModeChoice;
    }

    const normalized = TimelineAiService.normalizeStrategyMode(requestedMode);
    if (normalized === -1) {
      if (requestedCustomStrategy) {
        const requestChoice: EffectiveStrategyChoice = {
          mode: -1,
          customStrategy: TimelineAiService.cloneCustomStrategy(requestedCustomStrategy)
        };
        return requestChoice;
      }
      const currentCustom = await this.host.getCurrentStrategy();
      const fallbackChoice: EffectiveStrategyChoice = {
        mode: -1,
        customStrategy: TimelineAiService.cloneCustomStrategy(currentCustom)
      };
      return fallbackChoice;
    }

    const normalizedChoice: EffectiveStrategyChoice = {
      mode: normalized
    };
    return normalizedChoice;
  }

  private buildAiReplanExplanation(mode: number): string {
    if (mode === -1) {
      return '已采用自定义策略';
    }
    return StrategyService.buildStrategyExplanation(mode);
  }

  private resolveReplanMinItems(requestedDays: number): number {
    if (!Number.isFinite(requestedDays) || requestedDays <= 1) {
      return 1;
    }
    const safeDays = Math.max(1, Math.floor(requestedDays));
    if (safeDays <= 5) {
      return safeDays * 2;
    }
    return safeDays;
  }

  private async buildAiCandidates(
    sourcePrompt: string,
    strategyMode: number,
    customStrategy?: ComposableStrategy
  ): Promise<AiReplanPreviewItem[]> {
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

    let enhancedPrompt = sourcePrompt;
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
      } catch (_weatherError) {
        enhancedPrompt += '\n【天气约束】天气数据暂不可用，请优先保证路线可执行性。';
      }
    } else {
      enhancedPrompt += '\n【天气约束】用户已关闭天气功能，请忽略天气因素。';
    }

    const request: AiGenerateRequest = {
      userPrompt: enhancedPrompt,
      strategyMode: customStrategy ? -1 : strategyMode,
      customStrategy: customStrategy,
      allowPartialResult: false
    };
    const aiItems = await AiService.generateItineraryWithStrategy(request);

    if (!aiItems || aiItems.length === 0) {
      throw new Error('AI 未返回可用地点，请调整描述后重试');
    }

    const rawItems: AiRawItem[] = aiItems as AiRawItem[];
    return rawItems.map((item: AiRawItem): AiReplanPreviewItem => {
      const mapped: AiReplanPreviewItem = {
        name: item.name,
        duration: item.duration,
        itemType: item.type,
        aiReasoning: item.ai_reasoning || 'AI 智能推荐'
      };
      return mapped;
    });
  }

  private async captureUndoToken(): Promise<AiReplanUndoToken> {
    const snapshot = await this.host.persistence.getPlanAndEvents(this.host.planId);
    const plan = snapshot.plan;
    return {
      createdAt: Date.now(),
      events: this.host.events.map((event: EventEntity) => event.toInterface()),
      strategyMode: Number(plan?.strategyMode ?? this.host.currentStrategyMode),
      strategyDensity: Number(plan?.strategyDensity ?? 1),
      strategyPace: Number(plan?.strategyPace ?? 1),
      strategyPreference: Number(plan?.strategyPreference ?? 0),
      strategyEnergy: Number(plan?.strategyEnergy ?? 1),
      lastAiPrompt: plan?.lastAiPrompt || '',
      lastStrategyExplanation: plan?.lastStrategyExplanation || ''
    };
  }

  private async restoreUndoSnapshotUnsafe(token: AiReplanUndoToken): Promise<void> {
    await this.host.persistence.saveAllEvents(this.host.planId, token.events);
    this.host.events = token.events.map((item: TravelPlanItem) => EventEntity.fromInterface(item, this.host.planId));

    const restoredMode = TimelineAiService.normalizeStrategyMode(token.strategyMode);
    if (restoredMode === -1) {
      await PlanRepositoryImpl.updateStrategyDimensions(
        this.host.planId,
        token.strategyDensity,
        token.strategyPace,
        token.strategyPreference,
        token.strategyEnergy
      );
    } else {
      await this.host.persistence.updateStrategyMode(this.host.planId, restoredMode);
    }
    this.host.currentStrategyMode = restoredMode;
    await this.host.persistence.saveAiContext(this.host.planId, token.lastAiPrompt, token.lastStrategyExplanation);

    this.host.markScheduleChanged();
    this.host.recalculateFromIndex(0);
    this.host.events = [...this.host.events];
  }

  private static countAiSourceInTokenEvents(events: TravelPlanItem[]): number {
    return events.filter((item: TravelPlanItem) => Number(item.source || 0) === 1).length;
  }

  private ensureRollbackConsistency(token: AiReplanUndoToken): void {
    const expectedMode = TimelineAiService.normalizeStrategyMode(token.strategyMode);
    const actualMode = TimelineAiService.normalizeStrategyMode(this.host.currentStrategyMode);
    if (actualMode !== expectedMode) {
      throw new Error(`rollback_mode_mismatch expected=${expectedMode} actual=${actualMode}`);
    }
    if (this.host.events.length !== token.events.length) {
      throw new Error(`rollback_event_count_mismatch expected=${token.events.length} actual=${this.host.events.length}`);
    }
    const actualAiCount = this.host.events.filter((event: EventEntity) => event.source === 1).length;
    const expectedAiCount = TimelineAiService.countAiSourceInTokenEvents(token.events);
    if (actualAiCount !== expectedAiCount) {
      throw new Error(`rollback_ai_count_mismatch expected=${expectedAiCount} actual=${actualAiCount}`);
    }
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
        `[AI_DEBUG][timeline_generate_fail] mode=${strategyMode}, reason=${(error as Error).message}`
      );
      throw error as Error;
    }
  }

  public async buildReplanPreview(
    strategyMode: number,
    customStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    if (this.host.isRegenerating) {
      throw new Error('正在生成中，请稍后重试');
    }

    this.host.isRegenerating = true;
    try {
      hilog.info(
        0x0000,
        TAG,
        `[airest]AI_REPLAN_TRACE[service_preview_in] planId=${this.host.planId}, strategy=${strategyMode}, custom=${customStrategy ? 1 : 0}, keepCurrent=${keepCurrentMode === true ? 1 : 0}`
      );
      const prompt = await this.resolveHistoryPrompt();
      const effective = await this.resolveEffectiveStrategy(strategyMode, customStrategy, keepCurrentMode);
      const items = await this.buildAiCandidates(prompt, effective.mode, effective.customStrategy);
      const requestedDays = AiService.resolveRequestedDaysFromPrompt(prompt);
      const minRequired = this.resolveReplanMinItems(requestedDays);
      if (items.length < minRequired) {
        const reason = `AI 返回地点数量不足，当前仅${items.length}个，无法满足${requestedDays}天行程（至少需要${minRequired}个地点）`;
        hilog.error(
          0x0000,
          TAG,
          `[airest]AI_REPLAN_TRACE[service_preview_partial] mode=${effective.mode}, requestedDays=${requestedDays}, generated=${items.length}, minRequired=${minRequired}`
        );
        throw new Error(reason);
      }
      hilog.info(
        0x0000,
        TAG,
        `[airest]AI_REPLAN_TRACE[service_preview_out] mode=${effective.mode}, custom=${effective.customStrategy ? 1 : 0}, count=${items.length}, promptLen=${prompt.length}`
      );
      return {
        prompt: prompt,
        strategyMode: effective.mode,
        customStrategy: TimelineAiService.cloneCustomStrategy(effective.customStrategy),
        generatedAt: Date.now(),
        itemCount: items.length,
        items: items
      };
    } catch (error) {
      const reason = (error as Error).message;
      hilog.error(0x0000, TAG, `[airest]AI_REPLAN_TRACE[service_preview_fail] reason=${reason}`);
      throw error as Error;
    } finally {
      this.host.isRegenerating = false;
    }
  }

  public async applyReplanPreview(
    preview: AiReplanPreviewResult,
    decision: AiReplanApplyDecision
  ): Promise<AiReplanUndoToken> {
    if (this.host.isRegenerating) {
      throw new Error('正在生成中，请稍后重试');
    }
    if (!preview || !preview.items || preview.items.length === 0) {
      throw new Error('预览结果为空，无法应用');
    }
    this.host.isRegenerating = true;
    let undoToken = null as AiReplanUndoToken | null;
    let beforeTotalCount = this.host.events.length;
    let beforeAiCount = this.host.events.filter((event: EventEntity) => event.source === 1).length;
    let removedAiCount = 0;
    let insertedCount = 0;
    try {
      hilog.info(
        0x0000,
        TAG,
        `[airest]AI_REPLAN_TRACE[service_apply_in] planId=${this.host.planId}, decision=${decision}, previewMode=${preview.strategyMode}, previewCount=${preview.items.length}, beforeTotal=${beforeTotalCount}, beforeAi=${beforeAiCount}`
      );
      undoToken = await this.captureUndoToken();
      const mode = TimelineAiService.normalizeStrategyMode(preview.strategyMode);
      const customStrategy = TimelineAiService.cloneCustomStrategy(preview.customStrategy);
      if (decision === 'OVERWRITE') {
        await EventRepositoryImpl.deleteEventsBySource(this.host.planId, 1);
        this.host.events = this.host.events.filter((event: EventEntity) => event.source !== 1);
        removedAiCount = beforeAiCount;
      }

      const requestedDays = AiService.resolveRequestedDaysFromPrompt(preview.prompt);
      const scheduleEvents = this.host.events.filter((event: EventEntity) => event.status === 1);
      const baseDayOffset = scheduleEvents.length > 0
        ? Math.max(...scheduleEvents.map((event: EventEntity) => event.day_offset || 0)) + 1
        : 0;
      const allocatedDayOffsets = TimelineAiService.buildAiDayOffsets(preview.items.length, requestedDays, baseDayOffset);
      hilog.info(
        0x0000,
        TAG,
        `[airest]AI_REPLAN_TRACE[service_apply_plan] decision=${decision}, requestedDays=${requestedDays}, baseDayOffset=${baseDayOffset}, scheduleCount=${scheduleEvents.length}, allocatedCount=${allocatedDayOffsets.length}`
      );
      const insertedIds: number[] = [];

      for (let i = 0; i < preview.items.length; i++) {
        const item = preview.items[i];
        const newItem: TravelPlanItem = {
          name: item.name,
          duration: item.duration,
          type: 'FLOW',
          preTravelMinutes: -1,
          sortOrder: 0,
          status: 0,
          lockStatus: 0,
          fixedStartTime: undefined,
          dayOffset: allocatedDayOffsets[i] ?? baseDayOffset,
          itemType: item.itemType,
          priority: item.itemType === 1 ? 0 : 1,
          isTravelManual: 0,
          source: 1,
          aiReasoning: item.aiReasoning || 'AI 智能推荐',
          delFlag: 0,
          groupId: 0,
          address: '',
          travelMode: 2
        };
        const newId = await TimelineAiService.insertAiEvent(this.host.planId, newItem);
        newItem.id = newId;
        insertedIds.push(newId);
        insertedCount += 1;
        this.host.events.push(EventEntity.fromInterface(newItem, this.host.planId));
      }

      if (decision === 'OVERWRITE') {
        const scheduleCount = this.host.events.filter((event: EventEntity) => event.status === 1).length;
        let nextSort = scheduleCount > 0
          ? Math.max(...this.host.events.filter((event: EventEntity) => event.status === 1).map((event: EventEntity) => event.sort_order))
          : 0;
        for (let i = 0; i < insertedIds.length; i++) {
          const target = this.host.events.find((event: EventEntity) => event.id === insertedIds[i]);
          if (!target) {
            continue;
          }
          nextSort += 100;
          target.status = 1;
          target.sort_order = nextSort;
          target.fixed_start_time = '';
          target.lock_status = 0;
          await EventRepositoryImpl.updateFields(target.id, [
            { column: EventEntity.STATUS, value: 1 },
            { column: EventEntity.SORT_ORDER, value: nextSort },
            { column: EventEntity.FIXED_START_TIME, value: '' },
            { column: EventEntity.LOCK_STATUS, value: 0 }
          ], this.host.planId);
        }
      }

      const explanation = this.buildAiReplanExplanation(mode);
      await this.host.persistence.saveAiContext(this.host.planId, preview.prompt, explanation);
      if (mode === -1 && customStrategy) {
        await PlanRepositoryImpl.updateStrategyDimensions(
          this.host.planId,
          customStrategy.density,
          customStrategy.pace,
          customStrategy.preference,
          customStrategy.energy
        );
      } else {
        await this.host.persistence.updateStrategyMode(this.host.planId, mode);
      }
      this.host.currentStrategyMode = mode;

      this.host.markScheduleChanged();
      if (decision === 'OVERWRITE') {
        this.host.recalculateFromIndex(0);
      }
      this.host.events = [...this.host.events];
      hilog.info(
        0x0000,
        TAG,
        `[airest]AI_REPLAN_TRACE[service_apply_out] decision=${decision}, mode=${mode}, insertedCount=${insertedIds.length}, removedAi=${removedAiCount}, totalEvents=${this.host.events.length}`
      );
      return undoToken;
    } catch (error) {
      const reason = (error as Error).message;
      hilog.error(
        0x0000,
        TAG,
        `[airest]AI_REPLAN_TRACE[service_apply_fail] decision=${decision}, reason=${reason}, beforeTotal=${beforeTotalCount}, beforeAi=${beforeAiCount}, removedAi=${removedAiCount}, inserted=${insertedCount}, currentTotal=${this.host.events.length}`
      );
      if (undoToken) {
        try {
          await this.restoreUndoSnapshotUnsafe(undoToken);
          this.ensureRollbackConsistency(undoToken);
          const rollbackAiCount = this.host.events.filter((event: EventEntity) => event.source === 1).length;
          hilog.warn(
            0x0000,
            TAG,
            `[airest]AI_REPLAN_TRACE[service_apply_rollback_ok] decision=${decision}, restoredCount=${undoToken.events.length}, restoredAi=${rollbackAiCount}`
          );
        } catch (rollbackError) {
          const rollbackReason = (rollbackError as Error).message;
          hilog.error(
            0x0000,
            TAG,
            `[airest]AI_REPLAN_TRACE[service_apply_rollback_fail] decision=${decision}, reason=${rollbackReason}`
          );
          throw new Error(`${reason}; 回滚失败: ${rollbackReason}`);
        }
      }
      throw error as Error;
    } finally {
      this.host.isRegenerating = false;
    }
  }

  public async restoreFromUndoToken(token: AiReplanUndoToken): Promise<void> {
    if (!token) {
      throw new Error('没有可撤回的重规划记录');
    }
    if (this.host.isRegenerating) {
      throw new Error('正在生成中，请稍后重试');
    }
    this.host.isRegenerating = true;
    try {
      await this.restoreUndoSnapshotUnsafe(token);
      const restoredMode = TimelineAiService.normalizeStrategyMode(token.strategyMode);
      hilog.info(0x0000, TAG, `[AI_REPLAN][undo] restoredCount=${this.host.events.length}, mode=${restoredMode}`);
    } finally {
      this.host.isRegenerating = false;
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
    hilog.info(0x0000, TAG, `[airest]AI_REPLAN_TRACE[service_regenerate_custom] planId=${this.host.planId}`);
    const preview = await this.buildReplanPreview(-1, strategy, false);
    await this.applyReplanPreview(preview, 'OVERWRITE');
  }

  public async regenerateByCurrentStrategy(): Promise<void> {
    hilog.info(
      0x0000,
      TAG,
      `[airest]AI_REPLAN_TRACE[service_regenerate_current] planId=${this.host.planId}, currentMode=${this.host.currentStrategyMode}`
    );
    const preview = await this.buildReplanPreview(this.host.currentStrategyMode, undefined, true);
    await this.applyReplanPreview(preview, 'OVERWRITE');
  }

  public async changeStrategyAndRegenerate(mode: number): Promise<void> {
    hilog.info(0x0000, TAG, `[airest]AI_REPLAN_TRACE[service_regenerate_change] planId=${this.host.planId}, mode=${mode}`);
    const preview = await this.buildReplanPreview(mode, undefined, false);
    await this.applyReplanPreview(preview, 'OVERWRITE');
  }
}


