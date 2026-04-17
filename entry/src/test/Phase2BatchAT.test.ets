import { describe, expect, it } from '@ohos/hypium';
import {
  AiReplanPreviewItem,
  AiReplanPreviewResult,
  ITimelineAiHost,
  TimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { AiGenerateRequest, AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanPersistenceFacade, PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { PlanItem, PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { ActiveEventSnapshot, EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  PlanNodeWeatherBinding,
  RouteWeatherSuitability,
  SoftReplanApplyResult,
  SoftReplanMode,
  WeatherCollabContext,
  WeatherCollabOptions,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherStageType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { BehaviorContext, AdaptationDecision, AdaptationPrompt, StrategyAdaptationEngine } from '../main/ets/domain/strategy/StrategyAdaptationEngine';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { UserProfileService } from '../main/ets/domain/strategy/UserProfileService';
import {
  ITimelineExecutionHost,
  ReflowHint,
  StartConflictInfo,
  TimelineExecutionService
} from '../main/ets/domain/timeline/services/TimelineExecutionService';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import {
  ITimelineDistributionHost,
  TimelineDistributionService
} from '../main/ets/domain/timeline/services/TimelineDistributionService';
import {
  ITimelineCompressionHost,
  TimelineCompressionService
} from '../main/ets/domain/timeline/services/TimelineCompressionService';

class StaticHooksForAT {
  private readonly target: Object;
  private readonly keys: string[];
  private readonly originals: Object[] = [];

  constructor(target: Object, keys: string[]) {
    this.target = target;
    this.keys = keys;
    for (let i = 0; i < keys.length; i++) {
      this.originals.push(Reflect.get(target, keys[i]) as Object);
    }
  }

  set(key: string, value: Object): void {
    Reflect.set(this.target, key, value);
  }

  restore(): void {
    for (let i = 0; i < this.keys.length; i++) {
      Reflect.set(this.target, this.keys[i], this.originals[i]);
    }
  }
}

class AiPersistenceForAT extends PlanPersistenceFacade {
  snapshot: PlanEventsSnapshot;
  updateStrategyModeCalls: number = 0;
  saveAiContextCalls: number = 0;
  saveAllEventsCalls: number = 0;
  lastMode: number = 0;
  lastAiPrompt: string = '';
  lastAiExplanation: string = '';

  constructor(snapshot: PlanEventsSnapshot) {
    super();
    this.snapshot = snapshot;
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return this.snapshot;
  }

  async updateStrategyMode(_planId: number, mode: number): Promise<void> {
    this.updateStrategyModeCalls += 1;
    this.lastMode = mode;
  }

  async saveAiContext(_planId: number, prompt: string, explanation: string): Promise<void> {
    this.saveAiContextCalls += 1;
    this.lastAiPrompt = prompt;
    this.lastAiExplanation = explanation;
  }

  async saveAllEvents(_planId: number, events: TravelPlanItem[]): Promise<void> {
    this.saveAllEventsCalls += 1;
    const copied: TravelPlanItem[] = [];
    for (let i = 0; i < events.length; i++) {
      copied.push(events[i]);
    }
    this.snapshot = {
      plan: this.snapshot.plan,
      events: copied
    };
  }
}

class RouteWeatherSuitabilityStubForAT implements RouteWeatherSuitability {
  routeScore: number = 88;
  riskTags: string[] = [];
  summaryText: string = '婢垛晜鐨电粙鍐茬暰';
}

class WeatherCollabContextStubForAT implements WeatherCollabContext {
  dayWindows = [];
  cityBuckets = [];
  collabSummary: string = '';
  dayWindowCount: number = 0;
  cityGroupCount: number = 0;
  cityCappedCount: number = 0;
  cityMissCount: number = 0;
  trendTag: 'STABLE' = 'STABLE';
  fallbackPath: string = 'NONE';
}

class WeatherContextStubForAT implements WeatherContext {
  stage: WeatherStageType = 'PLANNING';
  generatedAt: number = Date.now();
  bindings: PlanNodeWeatherBinding[] = [];
  routeSuitability: RouteWeatherSuitability = new RouteWeatherSuitabilityStubForAT();
  collabContext?: WeatherCollabContext = new WeatherCollabContextStubForAT();
}

class WeatherContextBuildResultStubForAT implements WeatherContextBuildResult {
  context: WeatherContext = new WeatherContextStubForAT();
  eventMap: Map<number, PlanNodeWeatherBinding> = new Map();
  sourceEvents: EventEntity[] = [];
}

class WeatherFacadeMockForAT {
  shouldThrowOnBuild: boolean = false;
  buildCalls: number = 0;
  summaryText: string = '澶╂皵绋冲畾';
  result: WeatherContextBuildResult = new WeatherContextBuildResultStubForAT();

  async buildPlanningContext(
    _events: EventEntity[],
    _preference: WeatherUserPreference,
    _options: WeatherCollabOptions,
    _stage: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.buildCalls += 1;
    if (this.shouldThrowOnBuild) {
      throw new Error('weather_context_failed');
    }
    return this.result;
  }

  buildPromptSummary(_context: Object, _preference: WeatherUserPreference): string {
    return this.summaryText;
  }
}

class BehaviorTrackerForAT extends UserBehaviorTracker {
  resetCalls: number = 0;
  context: BehaviorContext = {
    recentDeletions: [],
    recentSkips: 0,
    avgTrafficMinutes: 0,
    currentStrategy: { density: 1, pace: 1, preference: 0, energy: 1 },
    planId: 1
  };

  getBehaviorContext(planId: number, currentStrategy: ComposableStrategy): BehaviorContext {
    return {
      recentDeletions: this.context.recentDeletions,
      recentSkips: this.context.recentSkips,
      avgTrafficMinutes: this.context.avgTrafficMinutes,
      currentStrategy: currentStrategy,
      planId: planId
    };
  }

  reset(): void {
    this.resetCalls += 1;
  }
}

class TimelineAiHostForAT implements ITimelineAiHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  isRegenerating: boolean = false;
  weatherFeatureEnabled: boolean = false;
  weatherUserPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: WeatherCollabOptions = {};
  weatherStrategyHint: string = '';
  strategyAdaptationPrompt: AdaptationPrompt | null = null;
  behaviorTracker: UserBehaviorTracker = new BehaviorTrackerForAT();
  persistence: PlanPersistenceFacade;
  weatherFacade: WeatherFacade = new WeatherFacadeMockForAT() as Object as WeatherFacade;
  currentStrategy: ComposableStrategy = { density: 1, pace: 1, preference: 0, energy: 1 };
  planningWeatherApplyCalls: number = 0;
  markScheduleChangedCalls: number = 0;
  recalculateCalls: number = 0;
  softReplanResult: SoftReplanApplyResult = {
    success: true,
    rolledBack: false,
    errorCode: '',
    preview: {
      suggestionId: 's',
      actionType: 'NONE',
      changedOrder: false,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: 'ok',
      riskDelta: 0
    }
  };

  constructor(persistence: PlanPersistenceFacade) {
    this.persistence = persistence;
  }

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async applyPlanningWeatherResult(_result: WeatherContextBuildResult, _forceRefresh: boolean): Promise<void> {
    this.planningWeatherApplyCalls += 1;
  }

  composeWeatherConstraintPrompt(weatherAwareConstraint: string, weatherSummary: string): string {
    return `\n[weather]${weatherAwareConstraint}|${weatherSummary}`;
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return {
      density: this.currentStrategy.density,
      pace: this.currentStrategy.pace,
      preference: this.currentStrategy.preference,
      energy: this.currentStrategy.energy
    };
  }

  clampStrategyLevel(value: number): 0 | 1 | 2 {
    if (value <= 0) {
      return 0;
    }
    if (value >= 2) {
      return 2;
    }
    return 1;
  }

  async requestSoftReplan(_planId: number, _suggestionId: string, _mode: SoftReplanMode): Promise<SoftReplanApplyResult> {
    return this.softReplanResult;
  }

  markScheduleChanged(): void {
    this.markScheduleChangedCalls += 1;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateCalls += 1;
  }
}

class PlanStatusSnapshotForAT {
  status: PlanStatus = PlanStatus.READY;
}

class PlanStateMachineForAT {
  status: PlanStatus = PlanStatus.READY;
  startCount: number = 0;
  completeCount: number = 0;

  startExecution(_planId: string, _source: TransitionTriggerSource): void {
    this.startCount += 1;
    this.status = PlanStatus.IN_PROGRESS;
  }

  completeExecution(_planId: string): void {
    this.completeCount += 1;
    this.status = PlanStatus.COMPLETED;
  }

  getPlanStatus(_planId: string): PlanStatusSnapshotForAT {
    const snapshot = new PlanStatusSnapshotForAT();
    snapshot.status = this.status;
    return snapshot;
  }
}

class ReminderFacadeForAT {
  notificationCalls: number = 0;

  async updateScheduleNotification(
    _title: string,
    _body: string,
    _planId: number,
    _eventId: number,
    _ongoing: boolean
  ): Promise<void> {
    this.notificationCalls += 1;
  }
}

class ReflowHintForAT implements ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed' = 'reflow';
  minutesDelta: number = 0;
  message: string = '';
  updatedAt: number = Date.now();
}

class TimelineExecutionHostForAT implements ITimelineExecutionHost {
  events: EventEntity[] = [];
  conflictList: EventEntity[] = [];
  planStartDate: number = Date.now();
  isArchived: boolean = false;
  actualTimeMutationInFlight: boolean = false;
  latestReflowHint: ReflowHint | null = null;
  planId: number = 1;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  planStateMachine: PlanStateMachineForAT = new PlanStateMachineForAT();
  reminderFacade: ReminderFacadeForAT = new ReminderFacadeForAT();
  allowTransition: boolean = true;
  throwTransitionError: boolean = false;
  evaluateCalls: number = 0;
  reflowCalls: number = 0;
  snapshotCalls: number = 0;
  checkinCalls: number = 0;
  markScheduleChangedCalls: number = 0;

  async applyRuntimeTransition(
    target: EventEntity,
    transition: 'START' | 'END' | 'SKIP' | 'REOPEN',
    timestamp: number
  ): Promise<boolean> {
    if (this.throwTransitionError) {
      throw new Error('transition_failed_at');
    }
    if (!this.allowTransition) {
      return false;
    }
    if (transition === 'START') {
      target.actual_start_time = timestamp;
      target.actual_end_time = 0;
      target.completion_status = EventEntity.STATE_PENDING;
      return true;
    }
    if (transition === 'END') {
      target.actual_end_time = timestamp;
      target.completion_status = EventEntity.STATE_COMPLETED;
      return true;
    }
    if (transition === 'SKIP') {
      target.actual_end_time = timestamp;
      target.completion_status = EventEntity.STATE_SKIPPED;
      return true;
    }
    target.actual_start_time = 0;
    target.actual_end_time = 0;
    target.completion_status = EventEntity.STATE_PENDING;
    return true;
  }

  recalculateFromEventId(_eventId: number): void {
    this.reflowCalls += 1;
  }

  getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.getOrderedScheduleEvents();
    for (let i = 0; i < source.length; i++) {
      const item = source[i];
      if (item.id <= afterId) {
        continue;
      }
      if (item.status !== 1 || item.completion_status !== EventEntity.STATE_PENDING) {
        continue;
      }
      if (item.actual_start_time > 0 && item.actual_end_time <= 0) {
        continue;
      }
      return item;
    }
    return null;
  }

  buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    const hint = new ReflowHintForAT();
    hint.type = action === 'skip' ? 'next_changed' : (beforeTs === afterTs ? 'reflow' : 'shift');
    hint.minutesDelta = Math.round((afterTs - beforeTs) / 60000);
    hint.message = `${targetName}->${nextName}`;
    hint.updatedAt = Date.now();
    return hint;
  }

  logTimelineSnapshot(_scene: string): void {
    this.snapshotCalls += 1;
  }

  getPlaceCheckinSummary(_placeName: string): void {
    this.checkinCalls += 1;
  }

  evaluatePlanStatusByRuntime(): void {
    this.evaluateCalls += 1;
  }

  getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.getOrderedScheduleEvents();
    for (let i = 0; i < source.length; i++) {
      const item = source[i];
      if (item.status === 1 &&
        item.completion_status === EventEntity.STATE_PENDING &&
        item.actual_start_time > 0 &&
        item.actual_end_time <= 0) {
        return item;
      }
    }
    return null;
  }

  markScheduleChanged(): void {
    this.markScheduleChangedCalls += 1;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events
      .filter((item: EventEntity) => item.status === 1)
      .slice()
      .sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((item: EventEntity) => item.id === eventId);
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }
}

class TimelineDistributionHostForAT implements ITimelineDistributionHost {
  events: EventEntity[] = [];
  planId: number = 200;
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;
  recalculateFromIndexCalls: number[] = [];
  updateEventInfoCalls: number = 0;
  naturalArrivalMap: Map<number, number> = new Map<number, number>();

  getEffectiveDayOffset(item: EventEntity): number {
    return item.dynamic_day_offset || item.day_offset;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events
      .filter((item: EventEntity) => item.status === 1)
      .sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((item: EventEntity) => item.id === eventId);
  }

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    const schedule = this.getOrderedScheduleEvents()
      .filter((candidate: EventEntity) => this.getEffectiveDayOffset(candidate) === this.getEffectiveDayOffset(item));
    return schedule.length > 0 && schedule[0].id === item.id;
  }

  _calculateNaturalArrival(targetIndex: number): number {
    return this.naturalArrivalMap.get(targetIndex) ?? 0;
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
  }

  async updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    _dayOffset?: number
  ): Promise<void> {
    this.updateEventInfoCalls += 1;
  }
}

class TimelineCompressionHostForAT implements ITimelineCompressionHost {
  events: EventEntity[] = [];
  planId: number = 300;
  globalStartTime: string = '08:00';
  minDurationLimit: number = 20;
  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];
  unsavedCalls: number = 0;

  getMinEventDurationLimit(): number {
    return this.minDurationLimit;
  }

  getEffectiveDayOffset(item: EventEntity): number {
    return item.dynamic_day_offset || item.day_offset;
  }

  resolveEffectiveGlobalStartMinutes(): number {
    return 8 * 60;
  }

  recalculateFromEventId(eventId: number): void {
    this.recalculateFromEventIdCalls.push(eventId);
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
  }

  markHasUnsavedPostpone(): void {
    this.unsavedCalls += 1;
  }
}

class CompressionSelectionCandidateForAT {
  selectable?: boolean = true;
  disabledReason: string = '';
}

function createPlanSnapshotForAT(prompt: string, strategyMode: number = 0): PlanEventsSnapshot {
  const plan: PlanItem = {
    id: 1,
    title: 'plan',
    createdAt: 1,
    strategyMode: strategyMode,
    strategyDensity: 1,
    strategyPace: 1,
    strategyPreference: 0,
    strategyEnergy: 1,
    lastAiPrompt: prompt,
    lastStrategyExplanation: 'old'
  };
  const snapshot: PlanEventsSnapshot = {
    plan: plan,
    events: []
  };
  return snapshot;
}

function createTravelItemForAT(id: number, name: string, source: number = 0, dayOffset: number = 0): TravelPlanItem {
  return {
    id: id,
    name: name,
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: 0,
    sortOrder: id * 100,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '',
    dayOffset: dayOffset,
    itemType: 0,
    priority: 1,
    isTravelManual: 0,
    source: source,
    aiReasoning: '',
    delFlag: 0,
    groupId: 0,
    address: '',
    travelMode: 2
  };
}

function createEventForAT(id: number, name: string, dayOffset: number = 0, source: number = 0): EventEntity {
  const item = createTravelItemForAT(id, name, source, dayOffset);
  const entity = EventEntity.fromInterface(item, 1);
  entity.dynamic_day_offset = dayOffset;
  entity.day_offset = dayOffset;
  entity.sort_order = id * 100;
  entity.completion_status = EventEntity.STATE_PENDING;
  entity.duration = 60;
  entity.pre_travel_min = 0;
  entity.computed_time = '09:00';
  entity.fixed_start_time = '';
  entity.gap_minutes = 0;
  entity.has_gap = false;
  entity.priority = 0;
  entity.lock_status = 0;
  return entity;
}

function createAiRawItemsForAT(names: string[]): AiRawItem[] {
  const items: AiRawItem[] = [];
  for (let i = 0; i < names.length; i++) {
    items.push({
      name: names[i],
      duration: 60 + i * 10,
      ai_reasoning: i === 0 ? '' : `reason_${i}`,
      type: i % 3
    });
  }
  return items;
}

function createAiGenerateRequestForAT(): AiGenerateRequest {
  const request: AiGenerateRequest = {
    userPrompt: '',
    strategyMode: 0
  };
  return request;
}

function createPreviewForAT(
  mode: number,
  names: string[],
  customStrategy?: ComposableStrategy
): AiReplanPreviewResult {
  const items: AiReplanPreviewItem[] = [];
  for (let index = 0; index < names.length; index++) {
    const item: AiReplanPreviewItem = {
      name: names[index],
      duration: 90,
      itemType: index % 2,
      aiReasoning: index === 0 ? '' : `preview_reason_${index}`
    };
    items.push(item);
  }
  const preview: AiReplanPreviewResult = {
    prompt: '鍖椾含涓€鏃ユ父',
    strategyMode: mode,
    customStrategy: customStrategy,
    generatedAt: Date.now(),
    itemCount: names.length,
    items: items
  };
  return preview;
}

export default function phase2BatchATTest() {
  describe('phase2BatchATTimelineAiService', () => {
    it('normal: timeline_ai_build_replan_preview_should_keep_current_custom_strategy_and_compose_weather_off_prompt', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAT(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('北京三日游', -1));
      const host = new TimelineAiHostForAT(persistence);
      host.currentStrategyMode = -1;
      host.currentStrategy = { density: 2, pace: 1, preference: 0, energy: 2 };
      host.weatherFeatureEnabled = false;
      const existingAi = createEventForAT(1, '旧景点', 0, 1);
      const lastSchedule = createEventForAT(2, '宸叉帓鍦扮偣', 0, 0);
      lastSchedule.dynamic_end_time = new Date('2026-04-16T18:00:00+08:00').getTime();
      host.events = [existingAi, lastSchedule];
      let capturedRequest: AiGenerateRequest = createAiGenerateRequestForAT();
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiRawItemsForAT(['鏂板湴鐐?', '鏂板湴鐐?', '鏂板湴鐐?', '鏂板湴鐐?', '鏂板湴鐐?', '鏂板湴鐐?']);
      });
      const service = new TimelineAiService(host);

      // Act
      const preview = await service.buildReplanPreview(2, undefined, true);

      // Assert
      aiHooks.restore();
      expect(capturedRequest !== null).assertTrue();
      const request = capturedRequest as AiGenerateRequest;
      expect(preview.strategyMode).assertEqual(-1);
      expect(preview.itemCount).assertEqual(6);
      expect(preview.customStrategy?.density ?? -1).assertEqual(2);
      expect(request.strategyMode).assertEqual(-1);
      expect(request.userPrompt.indexOf('已有地点') >= 0).assertTrue();
      expect(request.userPrompt.indexOf('用户已关闭天气功能') >= 0).assertTrue();
      expect(request.userPrompt.indexOf('上午9:00开始') >= 0).assertTrue();
      expect(preview.items[0].aiReasoning).assertEqual('AI 智能推荐');
    });

    it('boundary: timeline_ai_build_replan_preview_should_use_requested_custom_strategy_and_weather_fallback_hint', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAT(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('川西六日游', 0));
      const host = new TimelineAiHostForAT(persistence);
      const weatherFacade = new WeatherFacadeMockForAT();
      weatherFacade.shouldThrowOnBuild = true;
      host.weatherFeatureEnabled = true;
      host.weatherFacade = weatherFacade as Object as WeatherFacade;
      const strategy: ComposableStrategy = { density: 1, pace: 2, preference: 0, energy: 1 };
      let capturedRequest: AiGenerateRequest = createAiGenerateRequestForAT();
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiRawItemsForAT(['a', 'b', 'c', 'd', 'e', 'f']);
      });
      const service = new TimelineAiService(host);

      // Act
      const preview = await service.buildReplanPreview(-1, strategy, false);

      // Assert
      aiHooks.restore();
      const request = capturedRequest;
      expect(preview.strategyMode).assertEqual(-1);
      expect(preview.customStrategy?.pace ?? -1).assertEqual(2);
      expect(request.strategyMode ?? 99).assertEqual(-1);
      expect(request.userPrompt.indexOf('天气数据暂不可用') >= 0).assertTrue();
      expect(weatherFacade.buildCalls).assertEqual(1);
    });

    it('invalid: timeline_ai_build_replan_preview_should_throw_when_history_prompt_missing', 0, async () => {
      // Arrange
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('   ', 0));
      const host = new TimelineAiHostForAT(persistence);
      const service = new TimelineAiService(host);
      let message = '';

      // Act
      try {
        await service.buildReplanPreview(0);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('未找到上次生成记录');
      expect(host.isRegenerating).assertFalse();
    });

    it('conflict: timeline_ai_build_replan_preview_should_reject_partial_multi_day_result', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAT(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('上海三日游', 0));
      const host = new TimelineAiHostForAT(persistence);
      host.weatherFeatureEnabled = false;
      aiHooks.set('generateItineraryWithStrategy', async (_request: AiGenerateRequest): Promise<AiRawItem[]> => {
        return createAiRawItemsForAT(['a', 'b', 'c', 'd', 'e']);
      });
      const service = new TimelineAiService(host);
      let message = '';

      // Act
      try {
        await service.buildReplanPreview(0);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      aiHooks.restore();
      expect(message.indexOf('至少需要') >= 0).assertTrue();
      expect(host.isRegenerating).assertFalse();
    });

    it('regression: timeline_ai_generate_by_ai_should_apply_weather_context_and_allocate_new_day_offsets', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAT(AiService as Object, ['generateItineraryWithStrategy']);
      const planHooks = new StaticHooksForAT(PlanRepositoryImpl as Object, ['updateStrategyDimensions']);
      const eventHooks = new StaticHooksForAT(EventRepositoryImpl as Object, ['insertEvent']);
      const profileHooks = new StaticHooksForAT(UserProfileService as Object, ['recordStrategyUsage']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('旧提示', 0));
      const host = new TimelineAiHostForAT(persistence);
      const weatherFacade = new WeatherFacadeMockForAT();
      host.weatherFeatureEnabled = true;
      host.weatherFacade = weatherFacade as Object as WeatherFacade;
      const oldAi = createEventForAT(10, '旧景点', 2, 1);
      oldAi.dynamic_end_time = new Date('2026-04-15T18:00:00+08:00').getTime();
      const oldManual = createEventForAT(11, '旧手动', 1, 0);
      host.events = [oldManual, oldAi];
      const customStrategy: ComposableStrategy = { density: 2, pace: 1, preference: 0, energy: 2 };
      let capturedRequest: AiGenerateRequest = createAiGenerateRequestForAT();
      const inserted: TravelPlanItem[] = [];
      let strategyUpdateCalls = 0;
      let idSeed = 900;
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiRawItemsForAT(['鏂?', '鏂?', '鏂?', '鏂?']);
      });
      planHooks.set(
        'updateStrategyDimensions',
        async (_planId: number, density: number, pace: number, preference: number, energy: number): Promise<void> => {
          strategyUpdateCalls += 1;
          expect(density).assertEqual(2);
          expect(pace).assertEqual(1);
          expect(preference).assertEqual(0);
          expect(energy).assertEqual(2);
        }
      );
      eventHooks.set('insertEvent', async (_planId: number, item: TravelPlanItem): Promise<number> => {
        inserted.push(item);
        idSeed += 1;
        return idSeed;
      });
      profileHooks.set('recordStrategyUsage', async (): Promise<void> => {
        return;
      });
      const service = new TimelineAiService(host);

      // Act
      await service.generateByAi('杭州两日游', 2, customStrategy);

      // Assert
      aiHooks.restore();
      planHooks.restore();
      eventHooks.restore();
      profileHooks.restore();
      expect(strategyUpdateCalls).assertEqual(1);
      expect(host.planningWeatherApplyCalls).assertEqual(1);
      expect(inserted.length).assertEqual(4);
      expect(inserted[0].dayOffset).assertEqual(3);
      expect(inserted[1].dayOffset).assertEqual(3);
      expect(inserted[2].dayOffset).assertEqual(4);
      expect(inserted[3].dayOffset).assertEqual(4);
      expect(host.events.length).assertEqual(6);
      expect(persistence.lastAiPrompt).assertEqual('杭州两日游');
      const request = capturedRequest as AiGenerateRequest;
      expect(request.userPrompt.indexOf('[weather]') >= 0).assertTrue();
    });

    it('combined: timeline_ai_apply_replan_preview_should_persist_custom_dimensions_for_custom_mode', 0, async () => {
      // Arrange
      const planHooks = new StaticHooksForAT(PlanRepositoryImpl as Object, ['updateStrategyDimensions']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('北京一日游', 0));
      const host = new TimelineAiHostForAT(persistence);
      const customStrategy: ComposableStrategy = { density: 0, pace: 2, preference: 0, energy: 1 };
      const preview = createPreviewForAT(-1, ['新地点'], customStrategy);
      let updated = 0;
      planHooks.set(
        'updateStrategyDimensions',
        async (_planId: number, density: number, pace: number, preference: number, energy: number): Promise<void> => {
          updated += 1;
          expect(density).assertEqual(0);
          expect(pace).assertEqual(2);
          expect(preference).assertEqual(0);
          expect(energy).assertEqual(1);
        }
      );
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        return 1001;
      });
      const service = new TimelineAiService(host);

      // Act
      await service.applyReplanPreview(preview, 'KEEP');

      // Assert
      TimelineAiService.setInsertAiEventHookForTest(null);
      planHooks.restore();
      expect(updated).assertEqual(1);
      expect(host.currentStrategyMode).assertEqual(-1);
      expect(host.events.length).assertEqual(1);
      expect(persistence.lastAiExplanation).assertEqual('\\u5DF2\\u91C7\\u7528\\u81EA\\u5B9A\\u4E49\\u7B56\\u7565');
    });

    it('boundary: timeline_ai_trigger_strategy_adaptation_should_noop_when_engine_returns_null', 0, async () => {
      // Arrange
      const strategyHooks = new StaticHooksForAT(StrategyAdaptationEngine as Object, ['analyzeAndDecide', 'applyAdjustment']);
      const planHooks = new StaticHooksForAT(PlanRepositoryImpl as Object, ['updateStrategyDimensions']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('鎻愮ず', 0));
      const host = new TimelineAiHostForAT(persistence);
      strategyHooks.set('analyzeAndDecide', (_context: BehaviorContext): AdaptationDecision | null => {
        return null;
      });
      let updateCalls = 0;
      planHooks.set('updateStrategyDimensions', async (): Promise<void> => {
        updateCalls += 1;
      });
      const service = new TimelineAiService(host);

      // Act
      await service.triggerStrategyAdaptation();

      // Assert
      strategyHooks.restore();
      planHooks.restore();
      expect(updateCalls).assertEqual(0);
      expect(host.strategyAdaptationPrompt === null).assertTrue();
    });

    it('combined: timeline_ai_trigger_strategy_adaptation_should_apply_decision_and_reset_tracker', 0, async () => {
      // Arrange
      const strategyHooks = new StaticHooksForAT(StrategyAdaptationEngine as Object, ['analyzeAndDecide', 'applyAdjustment']);
      const planHooks = new StaticHooksForAT(PlanRepositoryImpl as Object, ['updateStrategyDimensions']);
      const persistence = new AiPersistenceForAT(createPlanSnapshotForAT('鎻愮ず', 0));
      const host = new TimelineAiHostForAT(persistence);
      const tracker = new BehaviorTrackerForAT();
      host.behaviorTracker = tracker;
      const decision: AdaptationDecision = {
        reason: 'EXCESSIVE_TRAFFIC',
        adjustments: { density: -1 },
        message: '\\u5EFA\\u8BAE\\u964D\\u4F4E\\u666F\\u70B9\\u5BC6\\u5EA6'
      };
      strategyHooks.set('analyzeAndDecide', (_context: BehaviorContext): AdaptationDecision | null => {
        return decision;
      });
      strategyHooks.set(
        'applyAdjustment',
        (_current: ComposableStrategy, _decision: AdaptationDecision): ComposableStrategy => {
          return { density: 0, pace: 1, preference: 0, energy: 1 };
        }
      );
      let updateCalls = 0;
      planHooks.set(
        'updateStrategyDimensions',
        async (_planId: number, density: number, pace: number, preference: number, energy: number): Promise<void> => {
          updateCalls += 1;
          expect(density).assertEqual(0);
          expect(pace).assertEqual(1);
          expect(preference).assertEqual(0);
          expect(energy).assertEqual(1);
        }
      );
      const service = new TimelineAiService(host);

      // Act
      await service.triggerStrategyAdaptation();

      // Assert
      strategyHooks.restore();
      planHooks.restore();
      expect(updateCalls).assertEqual(1);
      expect(tracker.resetCalls).assertEqual(1);
      expect(host.strategyAdaptationPrompt?.message ?? '').assertEqual('建议降低景点密度');
      expect(host.strategyAdaptationPrompt?.newStrategy.density ?? -1).assertEqual(0);
    });
  });

  describe('phase2BatchATTimelineExecutionService', () => {
    it('normal: timeline_execution_update_actual_time_should_clear_start_time_with_zero_timestamp', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAT(EventRepositoryImpl as Object, ['updateFields']);
      const host = new TimelineExecutionHostForAT();
      const target = createEventForAT(31, 'target');
      target.actual_start_time = 123456;
      host.events = [target];
      let updateCalls = 0;
      eventHooks.set('updateFields', async (_id: number, _updates: Object[], _planIdHint: number): Promise<void> => {
        updateCalls += 1;
      });
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(target.id, 'actual_start_time', 0);

      // Assert
      eventHooks.restore();
      expect(ok).assertTrue();
      expect(updateCalls).assertEqual(1);
      expect(target.actual_start_time).assertEqual(0);
      expect(host.planStateMachine.startCount).assertEqual(0);
    });

    it('boundary: timeline_execution_update_actual_time_should_block_when_mutation_is_in_flight', 0, async () => {
      // Arrange
      const host = new TimelineExecutionHostForAT();
      const target = createEventForAT(32, 'busy_target');
      host.events = [target];
      host.actualTimeMutationInFlight = true;
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(target.id, 'actual_start_time', Date.now());

      // Assert
      expect(ok).assertFalse();
      expect(host.actualTimeMutationInFlight).assertTrue();
    });

    it('invalid: timeline_execution_update_actual_time_should_block_non_pending_start_after_checks', 0, async () => {
      // Arrange
      const activeHooks = new StaticHooksForAT(EventRepositoryImpl as Object, ['findGlobalActiveEvent']);
      const host = new TimelineExecutionHostForAT();
      const target = createEventForAT(33, 'done_target');
      target.completion_status = EventEntity.STATE_COMPLETED;
      host.events = [target];
      activeHooks.set('findGlobalActiveEvent', async (_excludeEventId: number): Promise<ActiveEventSnapshot | null> => {
        return null;
      });
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(target.id, 'actual_start_time', Date.now());

      // Assert
      activeHooks.restore();
      expect(ok).assertFalse();
      expect(target.actual_start_time).assertEqual(0);
      expect(host.actualTimeMutationInFlight).assertFalse();
    });

    it('conflict: timeline_execution_update_actual_time_should_block_when_global_active_event_exists', 0, async () => {
      // Arrange
      const activeHooks = new StaticHooksForAT(EventRepositoryImpl as Object, ['findGlobalActiveEvent']);
      const host = new TimelineExecutionHostForAT();
      const target = createEventForAT(34, 'target');
      host.events = [target];
      activeHooks.set('findGlobalActiveEvent', async (_excludeEventId: number): Promise<ActiveEventSnapshot | null> => {
        return {
          eventId: 88,
          planId: 9,
          name: 'other_plan_active',
          actualStartTime: 123456
        };
      });
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(target.id, 'actual_start_time', Date.now());

      // Assert
      activeHooks.restore();
      expect(ok).assertFalse();
      expect(host.planStateMachine.startCount).assertEqual(0);
    });

    it('regression: timeline_execution_update_actual_time_should_evaluate_runtime_when_plan_not_all_completed', 0, async () => {
      // Arrange
      const host = new TimelineExecutionHostForAT();
      const first = createEventForAT(35, 'first');
      first.actual_start_time = Date.now() - 60000;
      const second = createEventForAT(36, 'second');
      host.events = [first, second];
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(first.id, 'actual_end_time', Date.now());

      // Assert
      expect(ok).assertTrue();
      expect(host.planStateMachine.completeCount).assertEqual(0);
      expect(host.evaluateCalls).assertEqual(1);
      expect(host.currentPlanStatus).assertEqual(PlanStatus.READY);
    });

    it('combined: timeline_execution_update_actual_time_should_complete_plan_when_last_event_finishes', 0, async () => {
      // Arrange
      const host = new TimelineExecutionHostForAT();
      const only = createEventForAT(37, 'only');
      only.actual_start_time = Date.now() - 60000;
      host.events = [only];
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(only.id, 'actual_end_time', Date.now());

      // Assert
      expect(ok).assertTrue();
      expect(host.planStateMachine.completeCount).assertEqual(1);
      expect(host.evaluateCalls).assertEqual(0);
      expect(host.currentPlanStatus).assertEqual(PlanStatus.COMPLETED);
    });
  });

  describe('phase2BatchATTimelineDistributionService', () => {
    it('normal: timeline_distribution_apply_distribution_should_recalculate_from_previous_index_when_change_starts_later', 0, async () => {
      // Arrange
      const updateHooks = new StaticHooksForAT(EventRepositoryImpl as Object, ['updateSingleField']);
      const host = new TimelineDistributionHostForAT();
      const first = createEventForAT(1, 'first');
      const second = createEventForAT(2, 'second');
      const third = createEventForAT(3, 'third');
      host.events = [first, second, third];
      updateHooks.set('updateSingleField', async (): Promise<void> => {
        return;
      });
      const service = new TimelineDistributionService(host);
      const distribution = new Map<number, number>();
      distribution.set(3, 15);

      // Act
      await service.applyDistribution(distribution);

      // Assert
      updateHooks.restore();
      expect(third.duration).assertEqual(75);
      expect(host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(host.recalculateFromIndexCalls[0]).assertEqual(1);
    });

    it('boundary: timeline_distribution_calculate_preview_should_use_lucky_allocation_when_floor_share_is_zero', 0, () => {
      // Arrange
      const host = new TimelineDistributionHostForAT();
      const c1 = createEventForAT(11, 'c1');
      const c2 = createEventForAT(12, 'c2');
      const gap = createEventForAT(13, 'gap');
      gap.gap_minutes = 1;
      host.events = [c1, c2, gap];
      const service = new TimelineDistributionService(host);

      // Act
      const preview = service.calculateDistributionPreview(gap, [c1, c2], new Set<number>([11, 12]), 'EQUAL');

      // Assert
      expect(preview.get(11) ?? 0).assertEqual(1);
      expect(preview.get(12) ?? 0).assertEqual(0);
    });

    it('invalid: timeline_distribution_resolve_gap_by_distribution_should_return_when_target_has_no_gap', 0, async () => {
      // Arrange
      const host = new TimelineDistributionHostForAT();
      const target = createEventForAT(21, 'no_gap');
      host.events = [target];
      const service = new TimelineDistributionService(host);

      // Act
      await service.resolveGapByDistribution(target);

      // Assert
      expect(host.recalculateFromIndexCalls.length).assertEqual(0);
      expect(target.duration).assertEqual(60);
    });

    it('conflict: timeline_distribution_calculate_preview_should_break_when_total_weight_is_zero', 0, () => {
      // Arrange
      const host = new TimelineDistributionHostForAT();
      const candidate = createEventForAT(22, 'zero_weight');
      candidate.duration = 0;
      const gap = createEventForAT(23, 'gap');
      gap.gap_minutes = 10;
      host.events = [candidate, gap];
      const service = new TimelineDistributionService(host);

      // Act
      const preview = service.calculateDistributionPreview(gap, [candidate], new Set<number>([22]), 'SMART');

      // Assert
      expect(preview.size).assertEqual(1);
      expect(preview.get(22) ?? 0).assertEqual(0);
    });
  });

  describe('phase2BatchATTimelineCompressionService', () => {
    it('normal: timeline_compression_build_selection_context_should_mark_pre_anchor_items_as_blocked', 0, () => {
      // Arrange
      const host = new TimelineCompressionHostForAT();
      const free = createEventForAT(1, 'free');
      free.duration = 50;
      const rigid = createEventForAT(2, 'rigid');
      rigid.lock_status = 1;
      rigid.fixed_start_time = '09:00';
      const target = createEventForAT(3, 'target');
      target.pre_travel_min = 60;
      host.events = [free, rigid, target];
      const service = new TimelineCompressionService(host);

      // Act
      const context = service.buildCompressionSelectionContext(2, '08:00', 30);

      // Assert
      const blocked = context?.candidates.find((candidate) => candidate.id === 1);
      const blockedReason = blocked?.disabledReason ?? '';
      expect(context !== null).assertTrue();
      expect(blocked?.selectable ?? true).assertFalse();
      expect(blockedReason.indexOf('阻断') >= 0).assertTrue();
    });

    it('boundary: timeline_compression_build_selection_context_should_mark_min_duration_candidate_unselectable', 0, () => {
      // Arrange
      const host = new TimelineCompressionHostForAT();
      const shortStay = createEventForAT(11, 'short_stay');
      shortStay.duration = 20;
      const target = createEventForAT(12, 'target');
      host.events = [shortStay, target];
      const service = new TimelineCompressionService(host);

      // Act
      const context = service.buildCompressionSelectionContext(1, '08:00', 10);

      // Assert
      const candidate = context?.candidates[0];
      const candidateReason = candidate?.disabledReason ?? '';
      expect(candidate?.selectable ?? true).assertFalse();
      expect(candidateReason.indexOf('20 分钟') >= 0).assertTrue();
    });

    it('invalid: timeline_compression_calculate_force_compress_plan_should_return_overload_when_all_previous_items_locked', 0, () => {
      // Arrange
      const host = new TimelineCompressionHostForAT();
      const locked = createEventForAT(21, 'locked');
      locked.lock_status = 1;
      locked.fixed_start_time = '08:00';
      locked.duration = 120;
      const target = createEventForAT(22, 'target');
      target.pre_travel_min = 60;
      host.events = [locked, target];
      const service = new TimelineCompressionService(host);

      // Act
      const plan = service.calculateForceCompressPlan(1, '08:00');

      // Assert
      expect(plan.status).assertEqual('OVERLOAD');
      expect(plan.msg.indexOf('固定时间') >= 0).assertTrue();
    });

    it('combined: timeline_compression_build_advance_adjust_context_should_skip_cross_day_candidates', 0, () => {
      // Arrange
      const host = new TimelineCompressionHostForAT();
      const dayZero = createEventForAT(31, 'day_zero', 0);
      const sameDay = createEventForAT(32, 'same_day', 1);
      sameDay.fixed_start_time = '10:00';
      const target = createEventForAT(33, 'target', 1);
      host.events = [dayZero, sameDay, target];
      const service = new TimelineCompressionService(host);

      // Act
      const context = service.buildAdvanceAdjustContext(2);

      // Assert
      expect(context !== null).assertTrue();
      expect(context?.candidates.length ?? 0).assertEqual(1);
      expect(context?.candidates[0].id ?? 0).assertEqual(32);
    });
  });
}

