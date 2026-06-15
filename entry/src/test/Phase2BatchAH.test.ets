import { describe, expect, it } from '@ohos/hypium';
import {
  AiReplanApplyDecision,
  AiReplanPreviewResult,
  AiReplanUndoToken,
  ITimelineAiHost,
  TimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanPersistenceFacade, PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  SoftReplanApplyResult,
  SoftReplanMode,
  SoftReplanPreview,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { AiGenerateRequest, AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { AdaptationPrompt } from '../main/ets/domain/strategy/StrategyAdaptationEngine';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { WeatherStrategyAdjustment } from '../main/ets/common/utils/weather/WeatherReminderStore';
import {
  ITimelineExecutionHost,
  ReflowHint,
  StartConflictInfo,
  TimelineExecutionService
} from '../main/ets/domain/timeline/services/TimelineExecutionService';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { TimelineGroupingService } from '../main/ets/domain/timeline/services/TimelineGroupingService';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';

class StaticHooksForAH {
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

class PlanRepoHooksForAH {
  private readonly originUpdateStrategyDimensions: Object;

  constructor() {
    this.originUpdateStrategyDimensions = Reflect.get(PlanRepositoryImpl, 'updateStrategyDimensions') as Object;
  }

  setUpdateStrategyDimensions(
    fn: (planId: number, density: number, pace: number, preference: number, energy: number) => Promise<void>
  ): void {
    Reflect.set(PlanRepositoryImpl, 'updateStrategyDimensions', fn);
  }

  restore(): void {
    Reflect.set(PlanRepositoryImpl, 'updateStrategyDimensions', this.originUpdateStrategyDimensions);
  }
}

class EventRepoHooksForAH {
  private readonly originFindGlobalActiveEvent: Object;

  constructor() {
    this.originFindGlobalActiveEvent = Reflect.get(EventRepositoryImpl, 'findGlobalActiveEvent') as Object;
  }

  setFindGlobalActiveEvent(fn: (excludeEventId: number) => Promise<StartConflictInfo | null>): void {
    Reflect.set(EventRepositoryImpl, 'findGlobalActiveEvent', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'findGlobalActiveEvent', this.originFindGlobalActiveEvent);
  }
}

function createTravelItemForAH(id: number, name: string, source: number = 0): TravelPlanItem {
  return {
    id: id,
    name: name,
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: id * 100,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '',
    dayOffset: 0,
    itemType: 0,
    priority: 1,
    isTravelManual: 0,
    source: source,
    aiReasoning: 'reason',
    delFlag: 0,
    groupId: 0,
    address: '',
    travelMode: 2
  };
}

function createEventForAH(id: number, name: string, source: number = 0): EventEntity {
  const item = createTravelItemForAH(id, name, source);
  return EventEntity.fromInterface(item, 1);
}

class AiPersistenceForAH extends PlanPersistenceFacade {
  updateStrategyModeCalls: number = 0;
  lastMode: number = 0;

  async updateStrategyMode(_planId: number, mode: number): Promise<void> {
    this.updateStrategyModeCalls += 1;
    this.lastMode = mode;
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return {
      events: []
    };
  }
}

class EmptyWeatherAdjustmentForAH implements WeatherStrategyAdjustment {
}

class SnapshotPersistenceForAH extends AiPersistenceForAH {
  snapshot: PlanEventsSnapshot;
  saveAiContextCalls: number = 0;
  lastAiPrompt: string = '';
  lastAiExplanation: string = '';
  saveAllEventsCalls: number = 0;

  constructor(snapshot: PlanEventsSnapshot) {
    super();
    this.snapshot = snapshot;
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return this.snapshot;
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

class TimelineAiHostForAH implements ITimelineAiHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  isRegenerating: boolean = false;
  weatherFeatureEnabled: boolean = false;
  weatherUserPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: WeatherCollabOptions = {};
  weatherStrategyHint: string = '';
  strategyAdaptationPrompt: AdaptationPrompt | null = null;
  behaviorTracker: UserBehaviorTracker = new UserBehaviorTracker();
  persistence: PlanPersistenceFacade = new AiPersistenceForAH();
  weatherFacade: WeatherFacade = new WeatherFacade();
  currentStrategy: ComposableStrategy = { density: 1, pace: 1, preference: 0, energy: 1 };
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

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async applyPlanningWeatherResult(_result: WeatherContextBuildResult, _forceRefresh: boolean): Promise<void> {
    return;
  }

  composeWeatherConstraintPrompt(weatherAwareConstraint: string, weatherSummary: string): string {
    return `${weatherAwareConstraint}${weatherSummary}`;
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
    return;
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }
}

class SpyTimelineAiServiceForAH extends TimelineAiService {
  previewError: Error | null = null;
  applyError: Error | null = null;
  lastBuildReplanPreviewArgs: BuildReplanPreviewArgsForAH[] = [];
  lastApplyReplanPreviewArgs: ApplyReplanPreviewArgsForAH[] = [];

  private readonly previewResult: AiReplanPreviewResult = {
    prompt: 'preview',
    strategyMode: 0,
    generatedAt: Date.now(),
    itemCount: 1,
    items: [{ name: 'x', duration: 60, itemType: 0, aiReasoning: 'r' }]
  };

  private readonly undoToken: AiReplanUndoToken = {
    createdAt: Date.now(),
    events: [],
    strategyMode: 0,
    strategyDensity: 1,
    strategyPace: 1,
    strategyPreference: 0,
    strategyEnergy: 1,
    lastAiPrompt: '',
    lastStrategyExplanation: ''
  };

  constructor(host: ITimelineAiHost) {
    super(host);
  }

  public async buildReplanPreview(
    strategyMode: number,
    customStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    if (this.previewError) {
      throw this.previewError;
    }
    const args: BuildReplanPreviewArgsForAH = {
      strategyMode: strategyMode,
      hasCustom: customStrategy ? 1 : 0,
      keepCurrentMode: keepCurrentMode === true ? 1 : 0
    };
    this.lastBuildReplanPreviewArgs.push(args);
    return this.previewResult;
  }

  public async applyReplanPreview(
    preview: AiReplanPreviewResult,
    decision: AiReplanApplyDecision
  ): Promise<AiReplanUndoToken> {
    if (this.applyError) {
      throw this.applyError;
    }
    const args: ApplyReplanPreviewArgsForAH = {
      previewMode: preview.strategyMode,
      decision: decision
    };
    this.lastApplyReplanPreviewArgs.push(args);
    return this.undoToken;
  }
}

class PlanStatusSnapshotForAH {
  status: PlanStatus = PlanStatus.READY;
}

class UnsafeComposableStrategyForAH {
  density: number = 9;
  pace: number = 9;
  preference: number = 9;
  energy: number = 9;
}

class PlanStateMachineForAH {
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

  getPlanStatus(_planId: string): PlanStatusSnapshotForAH {
    const snapshot = new PlanStatusSnapshotForAH();
    snapshot.status = this.status;
    return snapshot;
  }
}

class ReminderFacadeForAH {
  callCount: number = 0;

  async updateScheduleNotification(
    _title: string,
    _body: string,
    _planId: number,
    _eventId: number,
    _ongoing: boolean
  ): Promise<void> {
    this.callCount += 1;
  }
}

class ReflowHintForAH implements ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed' = 'reflow';
  minutesDelta: number = 0;
  message: string = '';
  updatedAt: number = Date.now();
}

class TimelineExecutionHostForAH implements ITimelineExecutionHost {
  events: EventEntity[] = [];
  conflictList: EventEntity[] = [];
  planStartDate: number = Date.now();
  isArchived: boolean = false;
  actualTimeMutationInFlight: boolean = false;
  latestReflowHint: ReflowHint | null = null;
  planId: number = 1;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  planStateMachine: PlanStateMachineForAH = new PlanStateMachineForAH();
  reminderFacade: ReminderFacadeForAH = new ReminderFacadeForAH();
  transitionCallCount: number = 0;
  allowTransition: boolean = true;
  recalculateCalls: number = 0;
  evaluateCalls: number = 0;
  snapshotCalls: number = 0;
  checkinCalls: number = 0;
  markScheduleChangedCalls: number = 0;

  async applyRuntimeTransition(
    target: EventEntity,
    transition: 'START' | 'END' | 'SKIP' | 'REOPEN',
    timestamp: number
  ): Promise<boolean> {
    this.transitionCallCount += 1;
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
    this.recalculateCalls += 1;
  }

  getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.getOrderedScheduleEvents();
    for (let i = 0; i < source.length; i++) {
      const item = source[i];
      if (item.id <= afterId) {
        continue;
      }
      if (item.status !== 1) {
        continue;
      }
      if (item.completion_status !== EventEntity.STATE_PENDING) {
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
    const hint = new ReflowHintForAH();
    if (action === 'skip') {
      hint.type = 'next_changed';
    } else if (beforeTs > 0 && afterTs > 0 && beforeTs !== afterTs) {
      hint.type = 'shift';
    } else {
      hint.type = 'reflow';
    }
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

class WeatherSchedulePolicyForAH implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 0;
  allowLocationTrigger: boolean = false;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

interface BuildReplanPreviewArgsForAH {
  strategyMode: number;
  hasCustom: number;
  keepCurrentMode: number;
}

interface ApplyReplanPreviewArgsForAH {
  previewMode: number;
  decision: AiReplanApplyDecision;
}

interface WeatherPlanStateGateResultForAH {
  success: boolean;
  reasonCode?: string;
  startFromEventId?: number;
}

class WeatherPlanStateMachineForAH {
  requestSoftReplan(_args: Object): WeatherPlanStateGateResultForAH {
    const result: WeatherPlanStateGateResultForAH = {
      success: true,
      reasonCode: 'ok',
      startFromEventId: 1
    };
    return result;
  }
}

class TimelineWeatherHostForAH implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: WeatherCollabOptions = {};
  executionWeatherEnabled: boolean = false;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  executionWeatherLastTrigger: string = '';
  executionWeatherErrorCode: string = '';
  executionWeatherScore: number = -1;
  executionWeatherRefreshAt: number = 0;
  executionWeatherCollabSummary: string = '';
  executionWeatherCollabBadge: string = '';
  executionWeatherDisplaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' = 'UNKNOWN';
  executionWeatherCurrentText: string = '';
  executionWeatherNextText: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionSuggestionMap: Map<string, WeatherSuggestion> = new Map<string, WeatherSuggestion>();
  executionWeatherHint: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  executionWeatherLastLocation: GeoPointInput | null = null;
  executionWeatherLocationTriggerCooldownMs: number = 0;
  executionWeatherLastLocationTriggerAt: number = 0;
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new WeatherSchedulePolicyForAH();
  executionReplanBusy: boolean = false;
  executionWeatherApplying: boolean = false;
  executionWeatherAppliedSummary: string = '';
  executionWeatherLastEmitAt: number = 0;
  executionWeatherLocationDeltaMeters: number = 0;
  executionSuggestionCooldownMs: number = 0;
  executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  weatherPlanningHint: string = '';
  weatherRouteScore: number = -1;
  weatherCollabSummary: string = '';
  weatherCollabLabel: string = '';
  weatherStrategyHint: string = '';
  weatherLastRefreshAt: number = 0;
  planStateMachine: WeatherPlanStateMachineForAH = new WeatherPlanStateMachineForAH();
  recalculateFromIndexCalls: number = 0;

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return { density: 1, pace: 1, preference: 0, energy: 1 };
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  findCurrentActiveEvent(): EventEntity | null {
    return null;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events
      .filter((item: EventEntity) => item.status === 1)
      .slice()
      .sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getMinEventDurationLimit(): number {
    return 20;
  }

  async skipEvent(_item: EventEntity): Promise<void> {
    return;
  }

  recalculateFromEventId(_eventId: number): void {
    return;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateFromIndexCalls += 1;
  }

  markScheduleChanged(): void {
    return;
  }
}

function createSoftReplanResultForAH(success: boolean, errorCode: string): SoftReplanApplyResult {
  const normalizedErrorCode = (
    errorCode as '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY'
  );
  return {
    success: success,
    rolledBack: false,
    errorCode: normalizedErrorCode,
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
}

function createPreviewForAH(ids: string[]): SoftReplanPreview {
  return {
    suggestionId: 's',
    actionType: 'REORDER',
    changedOrder: true,
    changedDurations: false,
    skippedNodeIds: [],
    affectedNodeIds: ids,
    changeSummary: [],
    summary: 'x',
    riskDelta: -10
  };
}

function createPlanSnapshotForAH(prompt: string, strategyMode: number = 0): PlanEventsSnapshot {
  return {
    plan: {
      id: 1,
      title: 'plan',
      createdAt: 1,
      strategyMode: strategyMode,
      strategyDensity: 1,
      strategyPace: 1,
      strategyPreference: 0,
      strategyEnergy: 1,
      lastAiPrompt: prompt
    },
    events: []
  } as PlanEventsSnapshot;
}

function createAiItemsForAH(names: string[]): AiRawItem[] {
  const items: AiRawItem[] = [];
  for (let i = 0; i < names.length; i++) {
    items.push({
      name: names[i],
      duration: 60 + i,
      type: i % 2,
      ai_reasoning: i === 0 ? '' : `reason_${i}`
    } as AiRawItem);
  }
  return items;
}

export default function phase2BatchAHTest() {
  describe('phase2BatchAHTimelineAiService', () => {
    it('normal: timeline_ai_build_day_offsets_should_distribute_evenly', 0, () => {
      // Arrange
      // Act
      // Assert
      const offsets = TimelineAiService.buildAiDayOffsets(7, 3, 1);
      expect(offsets.length).assertEqual(7);
      expect(offsets[0]).assertEqual(1);
      expect(offsets[3]).assertEqual(2);
      expect(offsets[6]).assertEqual(3);
    });

    it('boundary: timeline_ai_build_day_offsets_should_return_empty_for_zero_total', 0, () => {
      // Arrange
      // Act
      // Assert
      const offsets = TimelineAiService.buildAiDayOffsets(0, 5, 2);
      expect(offsets.length).assertEqual(0);
    });

    it('invalid: timeline_ai_build_day_offsets_should_sanitize_invalid_input', 0, () => {
      // Arrange
      // Act
      // Assert
      const offsets = TimelineAiService.buildAiDayOffsets(5, Number.NaN, Number.NaN);
      expect(offsets.length).assertEqual(5);
      expect(offsets.every((item: number) => item === 0)).assertTrue();
    });

    it('invalid: timeline_ai_build_day_offsets_should_return_empty_when_total_is_not_finite', 0, () => {
      // Arrange
      // Act
      // Assert
      const offsets = TimelineAiService.buildAiDayOffsets(Number.NaN, 3, 1);
      expect(offsets.length).assertEqual(0);
    });

    it('normal: timeline_ai_get_strategy_mode_should_return_current_host_mode', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.currentStrategyMode = 2;
      const service = new TimelineAiService(host);
      expect(service.getStrategyMode()).assertEqual(2);
    });

    it('boundary: timeline_ai_get_strategy_mode_should_allow_zero_mode', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      expect(service.getStrategyMode()).assertEqual(0);
    });

    it('invalid: timeline_ai_get_strategy_mode_should_return_out_of_range_value_as_is', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.currentStrategyMode = 99;
      const service = new TimelineAiService(host);
      expect(service.getStrategyMode()).assertEqual(99);
    });

    it('normal: timeline_ai_has_history_should_return_true_when_ai_source_exists', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.events = [createEventForAH(1, 'a', 1)];
      const service = new TimelineAiService(host);
      expect(service.hasAiHistory()).assertTrue();
    });

    it('boundary: timeline_ai_has_history_should_return_false_for_empty_list', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      expect(service.hasAiHistory()).assertFalse();
    });

    it('invalid: timeline_ai_has_history_should_ignore_non_ai_sources', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.events = [createEventForAH(1, 'a', 0)];
      const service = new TimelineAiService(host);
      expect(service.hasAiHistory()).assertFalse();
    });

    it('normal: timeline_ai_update_strategy_mode_should_write_mode_to_persistence', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const persistence = new AiPersistenceForAH();
      host.persistence = persistence;
      const service = new TimelineAiService(host);
      await service.updateStrategyMode(1);
      expect(host.currentStrategyMode).assertEqual(1);
      expect(persistence.lastMode).assertEqual(1);
    });

    it('boundary: timeline_ai_update_strategy_mode_should_allow_custom_mode_flag', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const persistence = new AiPersistenceForAH();
      host.persistence = persistence;
      const service = new TimelineAiService(host);
      await service.updateStrategyMode(-1);
      expect(host.currentStrategyMode).assertEqual(-1);
      expect(persistence.lastMode).assertEqual(-1);
    });

    it('invalid: timeline_ai_update_strategy_mode_should_still_persist_unknown_mode', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const persistence = new AiPersistenceForAH();
      host.persistence = persistence;
      const service = new TimelineAiService(host);
      await service.updateStrategyMode(77);
      expect(host.currentStrategyMode).assertEqual(77);
      expect(persistence.lastMode).assertEqual(77);
    });

    it('normal: timeline_ai_switch_to_custom_strategy_should_update_dimensions_and_set_custom_mode', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PlanRepoHooksForAH();
      let callCount = 0;
      hooks.setUpdateStrategyDimensions(async (): Promise<void> => {
        callCount += 1;
      });
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      await service.switchToCustomStrategy({ density: 2, pace: 1, preference: 0, energy: 2 });
      hooks.restore();
      expect(callCount).assertEqual(1);
      expect(host.currentStrategyMode).assertEqual(-1);
    });

    it('boundary: timeline_ai_switch_to_custom_strategy_should_accept_min_values', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PlanRepoHooksForAH();
      hooks.setUpdateStrategyDimensions(async (): Promise<void> => {
        return;
      });
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      await service.switchToCustomStrategy({ density: 0, pace: 0, preference: 0, energy: 0 });
      hooks.restore();
      expect(host.currentStrategyMode).assertEqual(-1);
    });

    it('invalid: timeline_ai_switch_to_custom_strategy_should_pass_through_out_of_range_dimensions', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PlanRepoHooksForAH();
      let captured = 0;
      hooks.setUpdateStrategyDimensions(async (_planId: number, density: number): Promise<void> => {
        captured = density;
      });
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      const outOfRange = new UnsafeComposableStrategyForAH();
      await service.switchToCustomStrategy(outOfRange as Object as ComposableStrategy);
      hooks.restore();
      expect(captured).assertEqual(9);
    });

    it('normal: timeline_ai_apply_weather_strategy_adjustment_should_apply_clamped_delta_and_hint', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PlanRepoHooksForAH();
      hooks.setUpdateStrategyDimensions(async (): Promise<void> => {
        return;
      });
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      const changed = await service.applyWeatherStrategyAdjustment({ density: 1, pace: -1 }, '天气变更');
      hooks.restore();
      expect(changed).assertTrue();
      expect(host.currentStrategyMode).assertEqual(-1);
      expect(host.weatherStrategyHint).assertEqual('天气变更');
    });

    it('boundary: timeline_ai_apply_weather_strategy_adjustment_should_return_false_when_adjustment_results_in_no_change', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.currentStrategy = { density: 2, pace: 2, preference: 0, energy: 2 };
      const service = new TimelineAiService(host);
      const changed = await service.applyWeatherStrategyAdjustment({ density: 1, pace: 1, energy: 1 }, 'hint');
      expect(changed).assertFalse();
    });

    it('invalid: timeline_ai_apply_weather_strategy_adjustment_should_return_false_when_adjustment_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      const changed = await service.applyWeatherStrategyAdjustment(undefined, 'x');
      expect(changed).assertFalse();
    });

    it('boundary: timeline_ai_apply_weather_strategy_adjustment_should_return_false_when_only_preference_provided', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const service = new TimelineAiService(host);
      const changed = await service.applyWeatherStrategyAdjustment(new EmptyWeatherAdjustmentForAH(), 'x');
      expect(changed).assertFalse();
    });

    it('boundary: timeline_ai_apply_weather_strategy_adjustment_should_allow_pace_only_change_without_overwriting_blank_hint', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PlanRepoHooksForAH();
      hooks.setUpdateStrategyDimensions(async (): Promise<void> => {
        return;
      });
      const host = new TimelineAiHostForAH();
      host.currentStrategy = { density: 1, pace: 1, preference: 0, energy: 1 };
      host.weatherStrategyHint = 'keep_hint';
      const service = new TimelineAiService(host);
      const changed = await service.applyWeatherStrategyAdjustment({ pace: 1 }, '   ');
      hooks.restore();
      expect(changed).assertTrue();
      expect(host.currentStrategyMode).assertEqual(-1);
      expect(host.weatherStrategyHint).assertEqual('keep_hint');
    });

    it('normal: timeline_ai_apply_execution_suggestion_with_strategy_should_apply_and_return_success', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.softReplanResult = createSoftReplanResultForAH(true, '');
      const service = new TimelineAiService(host);
      const result = await service.applyExecutionSuggestionWithStrategy(1, 's1', { density: 1 }, 'h');
      expect(result.strategyApplied).assertTrue();
      expect(result.replanSuccess).assertTrue();
    });

    it('boundary: timeline_ai_apply_execution_suggestion_with_strategy_should_fallback_error_code_when_replan_failed_without_code', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.softReplanResult = createSoftReplanResultForAH(false, '');
      const service = new TimelineAiService(host);
      const result = await service.applyExecutionSuggestionWithStrategy(1, 's2');
      expect(result.replanSuccess).assertFalse();
      expect(result.errorCode).assertEqual('REPLAN_CONFLICT');
    });

    it('invalid: timeline_ai_apply_execution_suggestion_with_strategy_should_keep_replan_error_code', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.softReplanResult = createSoftReplanResultForAH(false, 'REPLAN_INVALID');
      const service = new TimelineAiService(host);
      const result = await service.applyExecutionSuggestionWithStrategy(1, '');
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
    });

    it('normal: timeline_ai_regenerate_by_current_strategy_should_use_current_mode_with_keep_flag', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.currentStrategyMode = 2;
      const service = new SpyTimelineAiServiceForAH(host);
      await service.regenerateByCurrentStrategy();
      const firstBuild = service.lastBuildReplanPreviewArgs[0];
      expect(firstBuild.strategyMode).assertEqual(2);
      expect(firstBuild.keepCurrentMode).assertEqual(1);
    });

    it('boundary: timeline_ai_regenerate_by_current_strategy_should_allow_custom_mode_marker', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.currentStrategyMode = -1;
      const service = new SpyTimelineAiServiceForAH(host);
      await service.regenerateByCurrentStrategy();
      const firstBuild = service.lastBuildReplanPreviewArgs[0];
      expect(firstBuild.strategyMode).assertEqual(-1);
    });

    it('invalid: timeline_ai_regenerate_by_current_strategy_should_throw_when_preview_build_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const service = new SpyTimelineAiServiceForAH(host);
      service.previewError = new Error('preview_failed');
      let message = '';
      try {
        await service.regenerateByCurrentStrategy();
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('preview_failed');
    });

    it('normal: timeline_ai_build_replan_preview_should_keep_current_normal_mode_when_keep_flag_enabled', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('上海两日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.currentStrategyMode = 2;
      host.weatherFeatureEnabled = false;
      let capturedRequest = {} as AiGenerateRequest;
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiItemsForAH(['a', 'b', 'c', 'd']);
      });
      const service = new TimelineAiService(host);

      // Act
      const preview = await service.buildReplanPreview(77, undefined, true);

      // Assert
      aiHooks.restore();
      expect(preview.strategyMode).assertEqual(2);
      expect(preview.customStrategy === undefined).assertTrue();
      expect(capturedRequest.strategyMode).assertEqual(2);
      expect(capturedRequest.userPrompt.indexOf('用户已关闭天气功能') >= 0).assertTrue();
    });

    it('boundary: timeline_ai_build_replan_preview_should_fallback_to_current_custom_strategy_when_request_is_custom_without_payload', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('北京两日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.currentStrategy = { density: 2, pace: 1, preference: 0, energy: 2 };
      host.weatherFeatureEnabled = false;
      let capturedRequest = {} as AiGenerateRequest;
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiItemsForAH(['a', 'b', 'c', 'd']);
      });
      const service = new TimelineAiService(host);

      // Act
      const preview = await service.buildReplanPreview(-1);

      // Assert
      aiHooks.restore();
      expect(preview.strategyMode).assertEqual(-1);
      expect(preview.customStrategy?.density ?? -1).assertEqual(2);
      expect(capturedRequest.strategyMode).assertEqual(-1);
      expect(capturedRequest.customStrategy?.pace ?? -1).assertEqual(1);
    });

    it('boundary: timeline_ai_build_replan_preview_should_allow_single_day_prompt_with_one_item', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('随便逛逛', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.weatherFeatureEnabled = false;
      aiHooks.set('generateItineraryWithStrategy', async (_request: AiGenerateRequest): Promise<AiRawItem[]> => {
        return createAiItemsForAH(['only_one']);
      });
      const service = new TimelineAiService(host);

      // Act
      const preview = await service.buildReplanPreview(0);

      // Assert
      aiHooks.restore();
      expect(preview.itemCount).assertEqual(1);
      expect(preview.items[0].name).assertEqual('only_one');
    });

    it('invalid: timeline_ai_build_replan_preview_should_keep_default_start_hint_when_last_schedule_has_no_end_time', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('广州两日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.weatherFeatureEnabled = false;
      const schedule = createEventForAH(10, 'manual');
      schedule.dynamic_end_time = 0;
      host.events = [schedule];
      let capturedRequest = {} as AiGenerateRequest;
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiItemsForAH(['p1', 'p2', 'p3', 'p4']);
      });
      const service = new TimelineAiService(host);

      // Act
      await service.buildReplanPreview(0);

      // Assert
      aiHooks.restore();
      expect(capturedRequest.userPrompt.indexOf('建议从上午9:00开始') >= 0).assertTrue();
    });

    it('invalid: timeline_ai_build_replan_preview_should_throw_when_ai_returns_empty_items', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('南京两日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.weatherFeatureEnabled = false;
      aiHooks.set('generateItineraryWithStrategy', async (_request: AiGenerateRequest): Promise<AiRawItem[]> => {
        return [];
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
      expect(message).assertEqual('AI 未返回可用地点，请调整描述后重试');
    });

    it('normal: timeline_ai_generate_by_ai_should_persist_builtin_mode_and_allocate_from_zero_when_schedule_empty', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['insertEvent']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('seed', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.weatherFeatureEnabled = false;
      let idSeed = 1000;
      aiHooks.set('generateItineraryWithStrategy', async (_request: AiGenerateRequest): Promise<AiRawItem[]> => {
        return createAiItemsForAH(['g1', 'g2']);
      });
      eventHooks.set('insertEvent', async (_planId: number, _item: TravelPlanItem): Promise<number> => {
        idSeed += 1;
        return idSeed;
      });
      const service = new TimelineAiService(host);

      // Act
      await service.generateByAi('随便逛逛', 0);

      // Assert
      aiHooks.restore();
      eventHooks.restore();
      expect(persistence.lastMode).assertEqual(0);
      expect(host.events.length).assertEqual(2);
      expect(host.events[0].day_offset).assertEqual(0);
    });

    it('invalid: timeline_ai_generate_by_ai_should_throw_when_ai_returns_empty_items', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('seed', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.weatherFeatureEnabled = false;
      aiHooks.set('generateItineraryWithStrategy', async (_request: AiGenerateRequest): Promise<AiRawItem[]> => {
        return [];
      });
      const service = new TimelineAiService(host);
      let message = '';

      // Act
      try {
        await service.generateByAi('武汉两日游', 0);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      aiHooks.restore();
      expect(message).assertEqual('AI 未返回可用地点，请调整描述后重试');
    });

    it('boundary: timeline_ai_generate_by_ai_should_keep_default_start_hint_when_schedule_exists_without_end_time', 0, async () => {
      // Arrange
      const aiHooks = new StaticHooksForAH(AiService as Object, ['generateItineraryWithStrategy']);
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['insertEvent']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('seed', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.weatherFeatureEnabled = false;
      const schedule = createEventForAH(20, 'manual_schedule');
      schedule.dynamic_end_time = 0;
      host.events = [schedule];
      let capturedRequest = {} as AiGenerateRequest;
      let idSeed = 3000;
      aiHooks.set('generateItineraryWithStrategy', async (request: AiGenerateRequest): Promise<AiRawItem[]> => {
        capturedRequest = request;
        return createAiItemsForAH(['g1']);
      });
      eventHooks.set('insertEvent', async (): Promise<number> => {
        idSeed += 1;
        return idSeed;
      });
      const service = new TimelineAiService(host);

      // Act
      await service.generateByAi('广州一日游', 0);

      // Assert
      aiHooks.restore();
      eventHooks.restore();
      expect(capturedRequest.userPrompt.indexOf('建议从上午9:00开始') >= 0).assertTrue();
      expect(host.events.length).assertEqual(2);
    });

    it('boundary: timeline_ai_restore_from_undo_token_should_restore_custom_mode_dimensions', 0, async () => {
      // Arrange
      const planHooks = new StaticHooksForAH(PlanRepositoryImpl as Object, ['updateStrategyDimensions']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('seed', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      let density = -1;
      planHooks.set(
        'updateStrategyDimensions',
        async (_planId: number, nextDensity: number, _pace: number, _preference: number, _energy: number): Promise<void> => {
          density = nextDensity;
        }
      );
      const service = new TimelineAiService(host);
      const token: AiReplanUndoToken = {
        createdAt: Date.now(),
        events: [createTravelItemForAH(1, 'undo')],
        strategyMode: -1,
        strategyDensity: 2,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 2,
        lastAiPrompt: 'undo_prompt',
        lastStrategyExplanation: 'undo_explanation'
      };

      // Act
      await service.restoreFromUndoToken(token);

      // Assert
      planHooks.restore();
      expect(density).assertEqual(2);
      expect(host.currentStrategyMode).assertEqual(-1);
    });

    it('boundary: timeline_ai_apply_replan_preview_should_reject_when_service_is_regenerating', 0, async () => {
      // Arrange
      const host = new TimelineAiHostForAH();
      host.isRegenerating = true;
      const service = new TimelineAiService(host);
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'x', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };
      let message = '';

      // Act
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('正在生成中，请稍后重试');
    });

    it('combined: timeline_ai_apply_replan_preview_overwrite_should_start_sort_from_zero_when_no_schedule_exists', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['deleteEventsBySource', 'updateFields']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('北京一日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.events = [createEventForAH(1, 'old_ai', 1)];
      let lastSort = -1;
      eventHooks.set('deleteEventsBySource', async (): Promise<void> => {
        return;
      });
      eventHooks.set('updateFields', async (_id: number, updates: Record<string, Object>[]): Promise<void> => {
        lastSort = updates[1].value as number;
      });
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        return 2001;
      });
      const service = new TimelineAiService(host);
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'new_ai', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };

      // Act
      await service.applyReplanPreview(preview, 'OVERWRITE');

      // Assert
      TimelineAiService.setInsertAiEventHookForTest(null);
      eventHooks.restore();
      expect(lastSort).assertEqual(100);
      expect(host.events[0].sort_order).assertEqual(100);
    });

    it('boundary: timeline_ai_apply_replan_preview_should_use_repository_insert_when_test_hook_absent', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['insertEvent']);
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('北京一日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      let insertCalls = 0;
      eventHooks.set('insertEvent', async (): Promise<number> => {
        insertCalls += 1;
        return 4001;
      });
      const service = new TimelineAiService(host);
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'repo_insert_ai', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };

      // Act
      await service.applyReplanPreview(preview, 'KEEP');

      // Assert
      eventHooks.restore();
      expect(insertCalls).assertEqual(1);
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(4001);
    });

    it('invalid: timeline_ai_private_normalize_strategy_mode_should_fallback_unknown_mode_to_zero', 0, () => {
      // Arrange
      // Act
      // Assert
      const normalize = Reflect.get(TimelineAiService as Object, 'normalizeStrategyMode') as (mode: number) => number;
      const normalized = normalize(99);
      expect(normalized).assertEqual(0);
    });

    it('invalid: timeline_ai_apply_replan_preview_should_report_mode_mismatch_when_rollback_snapshot_is_inconsistent', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['insertEvent']);
      const host = new TimelineAiHostForAH();
      eventHooks.set('insertEvent', async (): Promise<number> => {
        throw new Error('insert_failed_ah_mode');
      });
      const service = new TimelineAiService(host);
      const token: AiReplanUndoToken = {
        createdAt: Date.now(),
        events: [],
        strategyMode: 0,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: '',
        lastStrategyExplanation: ''
      };
      Reflect.set(service as Object, 'captureUndoToken', async (): Promise<AiReplanUndoToken> => token);
      Reflect.set(service as Object, 'restoreUndoSnapshotUnsafe', async (_token: AiReplanUndoToken): Promise<void> => {
        host.currentStrategyMode = 1;
        host.events = [];
      });
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'mode_mismatch_ai', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };
      let message = '';

      // Act
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      eventHooks.restore();
      expect(message.indexOf('rollback_mode_mismatch') >= 0).assertTrue();
    });

    it('invalid: timeline_ai_apply_replan_preview_should_report_event_count_mismatch_when_rollback_snapshot_is_inconsistent', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['insertEvent']);
      const host = new TimelineAiHostForAH();
      eventHooks.set('insertEvent', async (): Promise<number> => {
        throw new Error('insert_failed_ah_count');
      });
      const service = new TimelineAiService(host);
      const token: AiReplanUndoToken = {
        createdAt: Date.now(),
        events: [],
        strategyMode: 0,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: '',
        lastStrategyExplanation: ''
      };
      Reflect.set(service as Object, 'captureUndoToken', async (): Promise<AiReplanUndoToken> => token);
      Reflect.set(service as Object, 'restoreUndoSnapshotUnsafe', async (_token: AiReplanUndoToken): Promise<void> => {
        host.currentStrategyMode = 0;
        host.events = [createEventForAH(1, 'one')];
      });
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'count_mismatch_ai', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };
      let message = '';

      // Act
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      eventHooks.restore();
      expect(message.indexOf('rollback_event_count_mismatch') >= 0).assertTrue();
    });

    it('invalid: timeline_ai_apply_replan_preview_should_report_ai_count_mismatch_when_rollback_snapshot_is_inconsistent', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['insertEvent']);
      const host = new TimelineAiHostForAH();
      eventHooks.set('insertEvent', async (): Promise<number> => {
        throw new Error('insert_failed_ah_ai_count');
      });
      const service = new TimelineAiService(host);
      const token: AiReplanUndoToken = {
        createdAt: Date.now(),
        events: [createTravelItemForAH(1, 'plain_one', 0)],
        strategyMode: 0,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: '',
        lastStrategyExplanation: ''
      };
      Reflect.set(service as Object, 'captureUndoToken', async (): Promise<AiReplanUndoToken> => token);
      Reflect.set(service as Object, 'restoreUndoSnapshotUnsafe', async (_token: AiReplanUndoToken): Promise<void> => {
        host.currentStrategyMode = 0;
        host.events = [createEventForAH(1, 'ai_one', 1)];
      });
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'ai_count_mismatch_ai', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };
      let message = '';

      // Act
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      eventHooks.restore();
      expect(message.indexOf('rollback_ai_count_mismatch') >= 0).assertTrue();
    });

    it('invalid: timeline_ai_apply_replan_preview_should_rethrow_when_capture_undo_token_fails_before_rollback', 0, async () => {
      // Arrange
      const host = new TimelineAiHostForAH();
      host.events = [createEventForAH(1, 'existing_plain', 0)];
      const service = new TimelineAiService(host);
      let restoreCalled = 0;
      Reflect.set(service as Object, 'captureUndoToken', async (): Promise<AiReplanUndoToken> => {
        throw new Error('capture_undo_failed_ah');
      });
      Reflect.set(service as Object, 'restoreUndoSnapshotUnsafe', async (_token: AiReplanUndoToken): Promise<void> => {
        restoreCalled += 1;
      });
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'capture_fail_preview', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };
      let message = '';

      // Act
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('capture_undo_failed_ah');
      expect(restoreCalled).assertEqual(0);
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].name).assertEqual('existing_plain');
    });

    it('boundary: timeline_ai_apply_replan_preview_overwrite_should_skip_missing_inserted_target', 0, async () => {
      // Arrange
      const eventHooks = new StaticHooksForAH(EventRepositoryImpl as Object, ['deleteEventsBySource', 'updateFields']);
      const entityHooks = new StaticHooksForAH(EventEntity as Object, ['fromInterface']);
      const originalFromInterface = Reflect.get(EventEntity as Object, 'fromInterface') as
        (item: TravelPlanItem, planId: number) => EventEntity;
      const persistence = new SnapshotPersistenceForAH(createPlanSnapshotForAH('北京一日游', 0));
      const host = new TimelineAiHostForAH();
      host.persistence = persistence;
      host.events = [createEventForAH(1, 'old_ai', 1)];
      let updateCalls = 0;
      eventHooks.set('deleteEventsBySource', async (): Promise<void> => {
        return;
      });
      eventHooks.set('updateFields', async (): Promise<void> => {
        updateCalls += 1;
      });
      entityHooks.set('fromInterface', (item: TravelPlanItem, planId: number): EventEntity => {
        const copied: TravelPlanItem = {
          id: (item.id || 0) + 99,
          name: item.name,
          duration: item.duration,
          type: item.type,
          preTravelMinutes: item.preTravelMinutes,
          sortOrder: item.sortOrder,
          status: item.status,
          lockStatus: item.lockStatus,
          fixedStartTime: item.fixedStartTime,
          dayOffset: item.dayOffset,
          itemType: item.itemType,
          priority: item.priority,
          isTravelManual: item.isTravelManual,
          source: item.source,
          aiReasoning: item.aiReasoning,
          delFlag: item.delFlag,
          groupId: item.groupId,
          address: item.address,
          travelMode: item.travelMode
        };
        return originalFromInterface(copied, planId);
      });
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        return 5001;
      });
      const service = new TimelineAiService(host);
      const preview: AiReplanPreviewResult = {
        prompt: '北京一日游',
        strategyMode: 0,
        generatedAt: Date.now(),
        itemCount: 1,
        items: [{ name: 'missing_target_ai', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };

      // Act
      await service.applyReplanPreview(preview, 'OVERWRITE');

      // Assert
      TimelineAiService.setInsertAiEventHookForTest(null);
      entityHooks.restore();
      eventHooks.restore();
      expect(updateCalls).assertEqual(0);
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(5100);
      expect(host.events[0].status).assertEqual(0);
    });
  });

  describe('phase2BatchAHTimelineExecutionService', () => {
    it('normal: timeline_execution_find_current_active_event_should_return_actual_started_pending_item', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const active = createEventForAH(1, 'active');
      active.actual_start_time = Date.now() - 1000;
      active.actual_end_time = 0;
      host.events = [active];
      const service = new TimelineExecutionService(host);
      expect(service.findCurrentActiveEvent()?.id ?? 0).assertEqual(1);
    });

    it('boundary: timeline_execution_find_current_active_event_should_fallback_to_dynamic_window_match', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const now = Date.now();
      const item = createEventForAH(2, 'window');
      item.dynamic_start_time = now - 30000;
      item.dynamic_end_time = now + 30000;
      host.events = [item];
      const service = new TimelineExecutionService(host);
      expect(service.findCurrentActiveEvent()?.id ?? 0).assertEqual(2);
    });

    it('invalid: timeline_execution_find_current_active_event_should_return_null_when_no_candidate', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(3, 'done');
      item.completion_status = EventEntity.STATE_COMPLETED;
      host.events = [item];
      const service = new TimelineExecutionService(host);
      expect(service.findCurrentActiveEvent() === null).assertTrue();
    });

    it('boundary: timeline_execution_find_current_active_event_should_ignore_dynamic_window_when_now_outside_range', 0, () => {
      // Arrange
      const host = new TimelineExecutionHostForAH();
      const now = Date.now();
      const item = createEventForAH(4, 'window_miss');
      item.dynamic_start_time = now + 60000;
      item.dynamic_end_time = now + 120000;
      host.events = [item];
      const service = new TimelineExecutionService(host);

      // Act
      const result = service.findCurrentActiveEvent();

      // Assert
      expect(result === null).assertTrue();
    });

    it('boundary: timeline_execution_find_current_active_event_should_skip_when_dynamic_window_incomplete', 0, () => {
      // Arrange
      const host = new TimelineExecutionHostForAH();
      const now = Date.now();
      const item = createEventForAH(5, 'window_incomplete');
      item.dynamic_start_time = now - 60000;
      item.dynamic_end_time = 0;
      host.events = [item];
      const service = new TimelineExecutionService(host);

      // Act
      const result = service.findCurrentActiveEvent();

      // Assert
      expect(result === null).assertTrue();
    });

    it('normal: timeline_execution_checkout_event_should_apply_end_transition_for_valid_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(11, 'checkout');
      item.actual_start_time = Date.now() - 120000;
      host.events = [item];
      const service = new TimelineExecutionService(host);
      await service.checkOutEvent(item);
      expect(item.completion_status).assertEqual(EventEntity.STATE_COMPLETED);
    });

    it('boundary: timeline_execution_checkout_event_should_recalculate_even_when_item_has_no_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(0, 'tmp');
      item.id = 0;
      host.events = [item];
      const oldRef = host.events;
      const service = new TimelineExecutionService(host);
      await service.checkOutEvent(item);
      expect(oldRef === host.events).assertFalse();
    });

    it('invalid: timeline_execution_checkout_event_should_abort_when_runtime_transition_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      host.allowTransition = false;
      const item = createEventForAH(12, 'fail');
      host.events = [item];
      const oldRef = host.events;
      const service = new TimelineExecutionService(host);
      await service.checkOutEvent(item);
      expect(oldRef === host.events).assertTrue();
    });

    it('normal: timeline_execution_record_start_time_should_apply_start_transition_for_valid_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(21, 'start');
      host.events = [item];
      const service = new TimelineExecutionService(host);
      await service.recordStartTime(item);
      expect(item.actual_start_time > 0).assertTrue();
    });

    it('boundary: timeline_execution_record_start_time_should_refresh_list_when_item_has_no_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(0, 'tmp_start');
      item.id = 0;
      host.events = [item];
      const oldRef = host.events;
      const service = new TimelineExecutionService(host);
      await service.recordStartTime(item);
      expect(oldRef === host.events).assertFalse();
    });

    it('invalid: timeline_execution_record_start_time_should_abort_when_transition_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      host.allowTransition = false;
      const item = createEventForAH(22, 'fail_start');
      host.events = [item];
      const oldRef = host.events;
      const service = new TimelineExecutionService(host);
      await service.recordStartTime(item);
      expect(oldRef === host.events).assertTrue();
    });

    it('normal: timeline_execution_update_actual_time_should_start_plan_when_start_timestamp_applied', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new EventRepoHooksForAH();
      hooks.setFindGlobalActiveEvent(async (): Promise<StartConflictInfo | null> => null);
      const host = new TimelineExecutionHostForAH();
      host.planId = 9;
      const item = createEventForAH(31, 'start_time');
      host.events = [item];
      const service = new TimelineExecutionService(host);
      const ok = await service.updateActualTime(item.id, 'actual_start_time', Date.now());
      hooks.restore();
      expect(ok).assertTrue();
      expect(host.currentPlanStatus).assertEqual(PlanStatus.IN_PROGRESS);
    });

    it('boundary: timeline_execution_update_actual_time_should_return_false_when_archived', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      host.isArchived = true;
      const item = createEventForAH(32, 'archived');
      host.events = [item];
      const service = new TimelineExecutionService(host);
      const ok = await service.updateActualTime(item.id, 'actual_start_time', Date.now());
      expect(ok).assertFalse();
    });

    it('invalid: timeline_execution_update_actual_time_should_block_when_precheck_active_conflict_exists', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const active = createEventForAH(33, 'active');
      active.actual_start_time = Date.now() - 60000;
      active.actual_end_time = 0;
      const target = createEventForAH(34, 'target');
      host.events = [active, target];
      const service = new TimelineExecutionService(host);
      const ok = await service.updateActualTime(target.id, 'actual_start_time', Date.now());
      expect(ok).assertFalse();
    });

    it('normal: timeline_execution_get_start_conflict_info_should_map_snapshot_when_repository_returns_active', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new EventRepoHooksForAH();
      hooks.setFindGlobalActiveEvent(async (): Promise<StartConflictInfo | null> => {
        const snapshot: StartConflictInfo = {
          eventId: 77,
          planId: 8,
          name: 'global_active',
          actualStartTime: 123456
        };
        return snapshot;
      });
      const host = new TimelineExecutionHostForAH();
      const service = new TimelineExecutionService(host);
      const result = await service.getStartConflictInfo(0);
      hooks.restore();
      expect(result?.eventId ?? 0).assertEqual(77);
    });

    it('boundary: timeline_execution_get_start_conflict_info_should_return_null_when_no_active_snapshot', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new EventRepoHooksForAH();
      hooks.setFindGlobalActiveEvent(async (): Promise<StartConflictInfo | null> => null);
      const host = new TimelineExecutionHostForAH();
      const service = new TimelineExecutionService(host);
      const result = await service.getStartConflictInfo(0);
      hooks.restore();
      expect(result === null).assertTrue();
    });

    it('invalid: timeline_execution_get_start_conflict_info_should_throw_when_repository_call_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new EventRepoHooksForAH();
      hooks.setFindGlobalActiveEvent(async (): Promise<StartConflictInfo | null> => {
        throw new Error('repo_failed');
      });
      const host = new TimelineExecutionHostForAH();
      const service = new TimelineExecutionService(host);
      let message = '';
      try {
        await service.getStartConflictInfo(0);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      hooks.restore();
      expect(message).assertEqual('repo_failed');
    });
  });

  describe('phase2BatchAHTimelineExecutionServiceAdditional', () => {
    it('normal: timeline_execution_skip_event_should_mark_target_as_skipped', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(41, 'skip_target');
      host.events = [item];
      const service = new TimelineExecutionService(host);
      await service.skipEvent(item);
      expect(item.completion_status).assertEqual(EventEntity.STATE_SKIPPED);
    });

    it('boundary: timeline_execution_skip_event_should_return_when_archived', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      host.isArchived = true;
      const item = createEventForAH(42, 'archived_skip');
      host.events = [item];
      const service = new TimelineExecutionService(host);
      await service.skipEvent(item);
      expect(item.completion_status).assertEqual(EventEntity.STATE_PENDING);
    });

    it('invalid: timeline_execution_skip_event_should_block_non_pending_target', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(43, 'done_target');
      item.completion_status = EventEntity.STATE_COMPLETED;
      host.events = [item];
      const service = new TimelineExecutionService(host);
      await service.skipEvent(item);
      expect(item.completion_status).assertEqual(EventEntity.STATE_COMPLETED);
    });

    it('invalid: timeline_execution_skip_event_should_return_when_runtime_transition_fails', 0, async () => {
      // Arrange
      const host = new TimelineExecutionHostForAH();
      host.allowTransition = false;
      const item = createEventForAH(46, 'skip_fail');
      host.events = [item];
      const service = new TimelineExecutionService(host);

      // Act
      await service.skipEvent(item);

      // Assert
      expect(item.completion_status).assertEqual(EventEntity.STATE_PENDING);
      expect(host.recalculateCalls).assertEqual(0);
    });

    it('normal: timeline_execution_reopen_skipped_event_should_reset_status_to_pending', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(44, 'reopen_target');
      item.completion_status = EventEntity.STATE_SKIPPED;
      item.actual_end_time = Date.now() - 5000;
      host.events = [item];
      const service = new TimelineExecutionService(host);
      const ok = await service.reopenSkippedEvent(item.id);
      expect(ok).assertTrue();
      expect(item.completion_status).assertEqual(EventEntity.STATE_PENDING);
    });

    it('boundary: timeline_execution_reopen_skipped_event_should_return_false_when_target_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const service = new TimelineExecutionService(host);
      const ok = await service.reopenSkippedEvent(999);
      expect(ok).assertFalse();
    });

    it('invalid: timeline_execution_reopen_skipped_event_should_return_false_when_target_is_not_skipped', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(45, 'pending_target');
      host.events = [item];
      const service = new TimelineExecutionService(host);
      const ok = await service.reopenSkippedEvent(item.id);
      expect(ok).assertFalse();
    });

    it('normal: timeline_execution_calculate_realtime_schedule_should_fill_dynamic_times_for_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const itemA = createEventForAH(46, 'a');
      const itemB = createEventForAH(47, 'b');
      itemA.sort_order = 100;
      itemB.sort_order = 200;
      itemA.duration = 30;
      itemB.duration = 45;
      host.events = [itemA, itemB];
      const service = new TimelineExecutionService(host);
      service.calculateRealtimeSchedule();
      expect(itemA.dynamic_start_time > 0).assertTrue();
      expect(itemA.dynamic_end_time > itemA.dynamic_start_time).assertTrue();
      expect(itemB.dynamic_start_time >= itemA.dynamic_end_time).assertTrue();
    });

    it('boundary: timeline_execution_calculate_realtime_schedule_should_mark_conflict_when_locked_anchor_late', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const itemA = createEventForAH(48, 'base');
      const itemB = createEventForAH(49, 'locked');
      itemA.duration = 240;
      itemA.computed_time = '09:00';
      itemB.fixed_start_time = '09:30';
      itemB.lock_status = 1;
      itemB.computed_time = '09:00';
      host.events = [itemA, itemB];
      const service = new TimelineExecutionService(host);
      service.calculateRealtimeSchedule();
      expect(itemB.is_forecast_conflict).assertTrue();
      expect(host.conflictList.length).assertEqual(1);
    });

    it('invalid: timeline_execution_calculate_realtime_schedule_should_keep_forecast_masked_before_any_start', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineExecutionHostForAH();
      const item = createEventForAH(50, 'mask');
      item.actual_start_time = 0;
      item.actual_end_time = 0;
      host.events = [item];
      const service = new TimelineExecutionService(host);
      service.calculateRealtimeSchedule();
      expect(item.forecast_start_time).assertEqual('xxxx');
    });

    it('boundary: timeline_execution_calculate_realtime_schedule_should_mark_next_day_forecast_label', 0, () => {
      // Arrange
      const host = new TimelineExecutionHostForAH();
      host.planStartDate = new Date('2026-05-26T00:00:00+08:00').getTime();
      const itemA = createEventForAH(51, 'late_started');
      itemA.actual_start_time = new Date('2026-05-26T23:50:00+08:00').getTime();
      itemA.actual_end_time = new Date('2026-05-27T00:20:00+08:00').getTime();
      itemA.duration = 30;
      const itemB = createEventForAH(52, 'next_day');
      itemB.duration = 20;
      host.events = [itemA, itemB];
      const service = new TimelineExecutionService(host);

      // Act
      service.calculateRealtimeSchedule();

      // Assert
      expect(itemB.forecast_start_time.startsWith('次日 ')).assertTrue();
    });

    it('boundary: timeline_execution_update_actual_time_should_skip_plan_state_machine_when_plan_id_not_positive', 0, async () => {
      // Arrange
      const hooks = new EventRepoHooksForAH();
      hooks.setFindGlobalActiveEvent(async (): Promise<StartConflictInfo | null> => null);
      const host = new TimelineExecutionHostForAH();
      host.planId = 0;
      const item = createEventForAH(53, 'zero_plan');
      host.events = [item];
      const service = new TimelineExecutionService(host);

      // Act
      const ok = await service.updateActualTime(item.id, 'actual_start_time', Date.now());
      hooks.restore();

      // Assert
      expect(ok).assertTrue();
      expect(host.currentPlanStatus).assertEqual(PlanStatus.READY);
    });
  });

  describe('phase2BatchAHTimelineGroupingService', () => {
    it('normal: timeline_grouping_generate_groups_should_group_by_resolved_day_offset', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(61, 'd0_a');
      const e2 = createEventForAH(62, 'd0_b');
      const e3 = createEventForAH(63, 'd1_a');
      e1.day_offset = 0;
      e2.day_offset = 0;
      e3.day_offset = 1;
      e1.dynamic_day_offset = 0;
      e2.dynamic_day_offset = 0;
      e3.dynamic_day_offset = 1;
      e1.sort_order = 100;
      e2.sort_order = 200;
      e3.sort_order = 300;
      const groups = TimelineGroupingService.generateGroups([e2, e3, e1], Date.now());
      expect(groups.length).assertEqual(2);
      expect(groups[0].events.length).assertEqual(2);
      expect(groups[1].dayOffset).assertEqual(1);
    });

    it('boundary: timeline_grouping_generate_groups_should_apply_filter_range', 0, () => {
      // Arrange
      // Act
      // Assert
      const base = new Date(2026, 3, 1).getTime();
      const e1 = createEventForAH(64, 'f0');
      const e2 = createEventForAH(65, 'f1');
      e1.day_offset = 0;
      e2.day_offset = 1;
      e1.dynamic_day_offset = 0;
      e2.dynamic_day_offset = 1;
      const dayStartDate = new Date(base);
      dayStartDate.setHours(0, 0, 0, 0);
      const dayStart = dayStartDate.getTime();
      const groups = TimelineGroupingService.generateGroups(
        [e1, e2],
        base,
        dayStart,
        dayStart
      );
      expect(groups.length).assertEqual(1);
      expect(groups[0].events[0].id).assertEqual(64);
    });

    it('boundary: timeline_grouping_generate_groups_should_sort_by_custom_effective_day_offset', 0, () => {
      // Arrange
      const base = new Date(2026, 3, 1).getTime();
      const e1 = createEventForAH(651, 'custom-a');
      const e2 = createEventForAH(652, 'custom-b');
      e1.day_offset = 1;
      e2.day_offset = 0;
      e1.dynamic_day_offset = 1;
      e2.dynamic_day_offset = 0;
      e1.sort_order = 200;
      e2.sort_order = 100;
      // Act
      const groups = TimelineGroupingService.generateGroups(
        [e1, e2],
        base,
        undefined,
        undefined,
        (event: EventEntity): number => event.id === 651 ? -1 : 2
      );
      // Assert
      expect(groups.length).assertEqual(2);
      expect(groups[0].events[0].id).assertEqual(651);
      expect(groups[0].dayOffset).assertEqual(1);
      expect(groups[1].events[0].id).assertEqual(652);
      expect(groups[1].dayOffset).assertEqual(0);
    });

    it('invalid: timeline_grouping_generate_groups_should_return_empty_when_no_schedule_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(66, 'trash');
      e1.status = 0;
      const groups = TimelineGroupingService.generateGroups([e1], Date.now());
      expect(groups.length).assertEqual(0);
    });

    it('boundary: timeline_grouping_generate_groups_should_mark_negative_day_offset_as_conflict_header', 0, () => {
      // Arrange
      const e1 = createEventForAH(85, 'conflict-day');
      e1.day_offset = -1;
      e1.dynamic_day_offset = -1;
      // Act
      const groups = TimelineGroupingService.generateGroups([e1], Date.now());
      // Assert
      expect(groups.length).assertEqual(1);
      expect(groups[0].dayOffset).assertEqual(-1);
      expect(groups[0].dateHeader.indexOf('Day')).assertEqual(-1);
    });

    it('normal: timeline_grouping_get_ordered_schedule_events_should_sort_by_day_then_order', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(67, 'b');
      const e2 = createEventForAH(68, 'a');
      e1.day_offset = 1;
      e2.day_offset = 0;
      e1.dynamic_day_offset = 1;
      e2.dynamic_day_offset = 0;
      e1.sort_order = 50;
      e2.sort_order = 400;
      const ordered = TimelineGroupingService.getOrderedScheduleEvents([e1, e2]);
      expect(ordered[0].id).assertEqual(68);
      expect(ordered[1].id).assertEqual(67);
    });

    it('boundary: timeline_grouping_get_ordered_schedule_events_should_keep_stable_order_for_equal_keys', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(69, 'x1');
      const e2 = createEventForAH(70, 'x2');
      e1.day_offset = 0;
      e2.day_offset = 0;
      e1.sort_order = 100;
      e2.sort_order = 100;
      const ordered = TimelineGroupingService.getOrderedScheduleEvents([e1, e2]);
      expect(ordered[0].id).assertEqual(69);
      expect(ordered[1].id).assertEqual(70);
    });

    it('boundary: timeline_grouping_get_ordered_schedule_events_should_keep_stable_input_order_when_sort_order_equal', 0, () => {
      // Arrange
      const e1 = createEventForAH(86, 'same-order-b');
      const e2 = createEventForAH(85, 'same-order-a');
      const e3 = createEventForAH(87, 'same-order-c');
      e1.day_offset = 0;
      e2.day_offset = 0;
      e3.day_offset = 0;
      e1.dynamic_day_offset = 0;
      e2.dynamic_day_offset = 0;
      e3.dynamic_day_offset = 0;
      e1.sort_order = 100;
      e2.sort_order = 100;
      e3.sort_order = 100;
      // Act
      const ordered = TimelineGroupingService.getOrderedScheduleEvents([e1, e2, e3]);
      // Assert
      expect(ordered[0].id).assertEqual(86);
      expect(ordered[1].id).assertEqual(85);
      expect(ordered[2].id).assertEqual(87);
    });

    it('invalid: timeline_grouping_get_ordered_schedule_events_should_ignore_non_schedule_items', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(71, 'ignore');
      e1.status = 0;
      const ordered = TimelineGroupingService.getOrderedScheduleEvents([e1]);
      expect(ordered.length).assertEqual(0);
    });

    it('normal: timeline_grouping_get_events_by_place_name_should_match_case_insensitive', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(72, 'Museum');
      const e2 = createEventForAH(73, 'museum');
      const result = TimelineGroupingService.getEventsByPlaceName([e1, e2], ' MUSEUM ');
      expect(result.length).assertEqual(2);
    });

    it('boundary: timeline_grouping_get_events_by_place_name_should_return_sorted_records', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(74, 'park');
      const e2 = createEventForAH(75, 'park');
      e1.day_offset = 1;
      e2.day_offset = 0;
      e1.dynamic_day_offset = 1;
      e2.dynamic_day_offset = 0;
      const result = TimelineGroupingService.getEventsByPlaceName([e1, e2], 'park');
      expect(result[0].id).assertEqual(75);
      expect(result[1].id).assertEqual(74);
    });

    it('boundary: timeline_grouping_get_events_by_place_name_should_fallback_to_id_sort_when_order_equal', 0, () => {
      // Arrange
      const e1 = createEventForAH(761, 'gallery');
      const e2 = createEventForAH(760, 'gallery');
      e1.sort_order = 100;
      e2.sort_order = 100;
      e1.day_offset = 0;
      e2.day_offset = 0;
      e1.dynamic_day_offset = 0;
      e2.dynamic_day_offset = 0;
      // Act
      const result = TimelineGroupingService.getEventsByPlaceName([e1, e2], 'gallery');
      // Assert
      expect(result.length).assertEqual(2);
      expect(result[0].id).assertEqual(760);
      expect(result[1].id).assertEqual(761);
    });

    it('invalid: timeline_grouping_get_events_by_place_name_should_return_empty_when_place_blank', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(76, 'x');
      const result = TimelineGroupingService.getEventsByPlaceName([e1], '   ');
      expect(result.length).assertEqual(0);
    });

    it('normal: timeline_grouping_get_place_checkin_summary_should_count_completed_and_avg_stay', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(77, 'bridge');
      e1.actual_start_time = 1000;
      e1.actual_end_time = 61 * 60000;
      e1.completion_status = EventEntity.STATE_COMPLETED;
      const e2 = createEventForAH(78, 'bridge');
      e2.actual_start_time = 2000;
      e2.actual_end_time = 32 * 60000;
      e2.completion_status = EventEntity.STATE_COMPLETED;
      const summary = TimelineGroupingService.getPlaceCheckinSummary([e1, e2], 'bridge');
      expect(summary.totalRecords).assertEqual(2);
      expect(summary.completedRecords).assertEqual(2);
      expect(summary.avgStayMinutes > 0).assertTrue();
    });

    it('boundary: timeline_grouping_get_place_checkin_summary_should_count_skipped_records', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(79, 'square');
      e1.completion_status = EventEntity.STATE_SKIPPED;
      e1.actual_end_time = Date.now();
      const summary = TimelineGroupingService.getPlaceCheckinSummary([e1], 'square');
      expect(summary.totalRecords).assertEqual(1);
      expect(summary.skippedRecords).assertEqual(1);
    });

    it('invalid: timeline_grouping_get_place_checkin_summary_should_skip_unstarted_pending_records', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(80, 'lake');
      e1.completion_status = EventEntity.STATE_PENDING;
      e1.actual_start_time = 0;
      e1.actual_end_time = 0;
      const summary = TimelineGroupingService.getPlaceCheckinSummary([e1], 'lake');
      expect(summary.totalRecords).assertEqual(0);
    });

    it('combined: timeline_grouping_get_place_checkin_summary_should_keep_in_progress_record_and_sort_by_end_or_start', 0, () => {
      // Arrange
      const active = createEventForAH(88, 'tower');
    active.completion_status = EventEntity.STATE_PENDING;
      active.actual_start_time = 80 * 60000;
      active.actual_end_time = 0;
      const completed = createEventForAH(89, 'tower');
      completed.completion_status = EventEntity.STATE_COMPLETED;
      completed.actual_start_time = 20 * 60000;
      completed.actual_end_time = 40 * 60000;

      // Act
      const summary = TimelineGroupingService.getPlaceCheckinSummary([active, completed], 'tower');

      // Assert
      expect(summary.totalRecords).assertEqual(2);
      expect(summary.completedRecords).assertEqual(1);
      expect(summary.skippedRecords).assertEqual(0);
      expect(summary.records[0].id).assertEqual(88);
      expect(summary.records[1].id).assertEqual(89);
    });

    it('boundary: timeline_grouping_get_place_checkin_summary_should_sort_records_by_actual_start_when_end_missing', 0, () => {
      // Arrange
      const first = createEventForAH(891, 'dock');
      first.completion_status = EventEntity.STATE_PENDING;
      first.actual_start_time = 120 * 60000;
      first.actual_end_time = 0;
      const second = createEventForAH(892, 'dock');
      second.completion_status = EventEntity.STATE_PENDING;
      second.actual_start_time = 40 * 60000;
      second.actual_end_time = 0;
      // Act
      const summary = TimelineGroupingService.getPlaceCheckinSummary([second, first], 'dock');
      // Assert
      expect(summary.totalRecords).assertEqual(2);
      expect(summary.records[0].id).assertEqual(891);
      expect(summary.records[1].id).assertEqual(892);
    });

    it('normal: timeline_grouping_get_all_place_checkin_summaries_should_build_multi_place_result', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(81, 'one');
      const e2 = createEventForAH(82, 'two');
      e1.actual_end_time = Date.now();
      e2.actual_end_time = Date.now();
      e1.completion_status = EventEntity.STATE_SKIPPED;
      e2.completion_status = EventEntity.STATE_SKIPPED;
      const result = TimelineGroupingService.getAllPlaceCheckinSummaries([e1, e2]);
      expect(result.length).assertEqual(2);
    });

    it('boundary: timeline_grouping_get_all_place_checkin_summaries_should_ignore_blank_place_name', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(83, '   ');
      e1.actual_end_time = Date.now();
      e1.completion_status = EventEntity.STATE_SKIPPED;
      const result = TimelineGroupingService.getAllPlaceCheckinSummaries([e1]);
      expect(result.length).assertEqual(0);
    });

    it('invalid: timeline_grouping_get_all_place_checkin_summaries_should_filter_empty_summaries', 0, () => {
      // Arrange
      // Act
      // Assert
      const e1 = createEventForAH(84, 'none');
      const result = TimelineGroupingService.getAllPlaceCheckinSummaries([e1]);
      expect(result.length).assertEqual(0);
    });
  });

  describe('phase2BatchAHTimelineWeatherService', () => {
    it('normal: timeline_weather_is_valid_coordinate_should_return_true_for_in_range_value', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isValidCoordinate(39.9, 116.4)).assertTrue();
    });

    it('boundary: timeline_weather_is_valid_coordinate_should_accept_edge_coordinate', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isValidCoordinate(-90, 180)).assertTrue();
    });

    it('invalid: timeline_weather_is_valid_coordinate_should_return_false_for_zero_pair', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isValidCoordinate(0, 0)).assertFalse();
    });

    it('normal: timeline_weather_is_coordinate_missing_should_return_false_for_valid_coordinate', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isCoordinateMissingForWeather(22.5, 113.9)).assertFalse();
    });

    it('boundary: timeline_weather_is_coordinate_missing_should_treat_minus_one_as_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isCoordinateMissingForWeather(-1, -1)).assertTrue();
    });

    it('invalid: timeline_weather_is_coordinate_missing_should_return_true_for_invalid_range', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isCoordinateMissingForWeather(200, 500)).assertTrue();
    });

    it('normal: timeline_weather_is_execution_stage_should_return_true_for_in_progress_plan', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.currentPlanStatus = PlanStatus.IN_PROGRESS;
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isExecutionWeatherStage()).assertTrue();
    });

    it('boundary: timeline_weather_is_execution_stage_should_return_true_when_active_event_exists', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.currentPlanStatus = PlanStatus.DRAFT;
      const active = createEventForAH(91, 'active');
      active.actual_start_time = Date.now() - 5000;
      active.actual_end_time = 0;
      host.events = [active];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isExecutionWeatherStage()).assertTrue();
    });

    it('invalid: timeline_weather_is_execution_stage_should_return_false_when_plan_not_in_execution', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.currentPlanStatus = PlanStatus.DRAFT;
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.isExecutionWeatherStage()).assertFalse();
    });

    it('normal: timeline_weather_clear_runtime_state_should_reset_runtime_fields', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.weatherPlanningHint = 'hint';
      host.weatherRouteScore = 80;
      host.executionWeatherHint = 'exec';
      host.executionWeatherDisplaySource = 'CURRENT';
      host.executionWeatherSuggestions = [{ suggestionId: 's1' } as WeatherSuggestion];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      service.clearWeatherRuntimeState();
      expect(host.weatherPlanningHint).assertEqual('');
      expect(host.weatherRouteScore).assertEqual(-1);
      expect(host.executionWeatherDisplaySource).assertEqual('UNKNOWN');
      expect(host.executionWeatherSuggestions.length).assertEqual(0);
    });

    it('boundary: timeline_weather_clear_runtime_state_should_keep_plan_id_unchanged', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.planId = 99;
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      service.clearWeatherRuntimeState();
      expect(host.planId).assertEqual(99);
    });

    it('invalid: timeline_weather_clear_runtime_state_should_be_idempotent_when_called_twice', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      service.clearWeatherRuntimeState();
      service.clearWeatherRuntimeState();
      expect(host.weatherRouteScore).assertEqual(-1);
    });

    it('normal: timeline_weather_resolve_soft_replan_target_event_ids_should_filter_allowed_ids', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const e1 = createEventForAH(101, 'a');
      const e2 = createEventForAH(102, 'b');
      const e3 = createEventForAH(103, 'c');
      host.events = [e1, e2, e3];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const ids = service.resolveSoftReplanTargetEventIds(['101', '999', '103']);
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual(101);
    });

    it('boundary: timeline_weather_resolve_soft_replan_target_event_ids_should_limit_to_future_candidates', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const done = createEventForAH(104, 'done');
      done.completion_status = EventEntity.STATE_COMPLETED;
      const p1 = createEventForAH(105, 'p1');
      const p2 = createEventForAH(106, 'p2');
      host.events = [done, p1, p2];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const ids = service.resolveSoftReplanTargetEventIds(['104', '105', '106']);
      expect(ids.length).assertEqual(2);
    });

    it('invalid: timeline_weather_resolve_soft_replan_target_event_ids_should_ignore_non_numeric_ids', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const p1 = createEventForAH(107, 'p');
      host.events = [p1];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const ids = service.resolveSoftReplanTargetEventIds(['abc', '']);
      expect(ids.length).assertEqual(0);
    });

    it('normal: timeline_weather_resolve_soft_replan_start_event_id_should_return_smallest_positive_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const startId = service.resolveSoftReplanStartEventId(createPreviewForAH(['9', '3', '7']));
      expect(startId).assertEqual(3);
    });

    it('boundary: timeline_weather_resolve_soft_replan_start_event_id_should_return_zero_when_preview_has_no_ids', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const startId = service.resolveSoftReplanStartEventId(createPreviewForAH([]));
      expect(startId).assertEqual(0);
    });

    it('invalid: timeline_weather_resolve_soft_replan_start_event_id_should_skip_invalid_values', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const startId = service.resolveSoftReplanStartEventId(createPreviewForAH(['x', '-1']));
      expect(startId).assertEqual(0);
    });

    it('normal: timeline_weather_contains_immutable_node_should_detect_locked_fixed_node', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const e1 = createEventForAH(111, 'lock');
      e1.lock_status = 1;
      e1.fixed_start_time = '10:00';
      host.events = [e1];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.containsImmutableNode([111])).assertTrue();
    });

    it('boundary: timeline_weather_contains_immutable_node_should_return_false_for_pending_unlocked_nodes', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const e1 = createEventForAH(112, 'pending');
      host.events = [e1];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.containsImmutableNode([112])).assertFalse();
    });

    it('invalid: timeline_weather_contains_immutable_node_should_return_true_when_target_not_found', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.containsImmutableNode([9999])).assertTrue();
    });

    it('normal: timeline_weather_get_soft_replan_future_candidates_should_skip_active_and_return_next_three', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const active = createEventForAH(121, 'active');
      active.actual_start_time = Date.now() - 10000;
      active.actual_end_time = 0;
      const p1 = createEventForAH(122, 'p1');
      const p2 = createEventForAH(123, 'p2');
      const p3 = createEventForAH(124, 'p3');
      const p4 = createEventForAH(125, 'p4');
      host.events = [active, p1, p2, p3, p4];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const list = service.getSoftReplanFutureCandidates();
      expect(list.length).assertEqual(3);
      expect(list[0].id).assertEqual(122);
    });

    it('boundary: timeline_weather_get_soft_replan_future_candidates_should_return_all_pending_when_no_active', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const p1 = createEventForAH(126, 'p1');
      const p2 = createEventForAH(127, 'p2');
      host.events = [p1, p2];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const list = service.getSoftReplanFutureCandidates();
      expect(list.length).assertEqual(2);
    });

    it('invalid: timeline_weather_get_soft_replan_future_candidates_should_return_empty_when_no_pending', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const done = createEventForAH(128, 'done');
      done.completion_status = EventEntity.STATE_COMPLETED;
      host.events = [done];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const list = service.getSoftReplanFutureCandidates();
      expect(list.length).assertEqual(0);
    });

    it('normal: timeline_weather_dismiss_execution_suggestion_should_remove_existing_suggestion', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.executionWeatherSuggestions = [{ suggestionId: 's1' } as WeatherSuggestion, { suggestionId: 's2' } as WeatherSuggestion];
      host.executionSuggestionMap.set('s1', { suggestionId: 's1' } as WeatherSuggestion);
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      service.dismissExecutionSuggestion('s1');
      expect(host.executionWeatherSuggestions.length).assertEqual(1);
      expect(host.executionSuggestionMap.has('s1')).assertFalse();
    });

    it('boundary: timeline_weather_dismiss_execution_suggestion_should_keep_list_when_id_not_found', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.executionWeatherSuggestions = [{ suggestionId: 's1' } as WeatherSuggestion];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      service.dismissExecutionSuggestion('none');
      expect(host.executionWeatherSuggestions.length).assertEqual(1);
    });

    it('invalid: timeline_weather_dismiss_execution_suggestion_should_ignore_blank_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.executionWeatherSuggestions = [{ suggestionId: 's1' } as WeatherSuggestion];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      service.dismissExecutionSuggestion('   ');
      expect(host.executionWeatherSuggestions.length).assertEqual(1);
    });

    it('normal: timeline_weather_should_auto_refresh_planning_weather_should_return_true_when_no_refresh_timestamp', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.planId = 7;
      host.weatherLastRefreshAt = 0;
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.shouldAutoRefreshPlanningWeather()).assertTrue();
    });

    it('boundary: timeline_weather_should_auto_refresh_planning_weather_should_return_false_with_recent_fetch_time', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.planId = 8;
      const e1 = createEventForAH(131, 'recent');
      e1.weather_fetch_time = Date.now();
      host.events = [e1];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.shouldAutoRefreshPlanningWeather(24 * 60 * 60 * 1000)).assertFalse();
    });

    it('invalid: timeline_weather_should_auto_refresh_planning_weather_should_return_true_when_plan_id_invalid', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      host.planId = 0;
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.shouldAutoRefreshPlanningWeather()).assertTrue();
    });

    it('normal: timeline_weather_build_weather_score_explanation_should_return_low_risk_text_for_high_score', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const text = service.buildWeatherScoreExplanation(95);
      expect(text.includes('95')).assertTrue();
      expect(text.includes('low')).assertFalse();
    });

    it('boundary: timeline_weather_build_weather_score_explanation_should_return_mid_risk_text_for_medium_score', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const text = service.buildWeatherScoreExplanation(80);
      expect(text.includes('80')).assertTrue();
    });

    it('invalid: timeline_weather_build_weather_score_explanation_should_return_default_when_score_invalid', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const text = service.buildWeatherScoreExplanation(-1);
      expect(text.length > 0).assertTrue();
    });

    it('conflict: timeline_weather_contains_immutable_node_should_flag_conflict_when_locked_and_targeted', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineWeatherHostForAH();
      const locked = createEventForAH(141, 'locked');
      locked.lock_status = 1;
      locked.fixed_start_time = '09:00';
      host.events = [locked];
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const hasConflict = service.containsImmutableNode([141]);
      expect(hasConflict).assertTrue();
    });

    it('regression: timeline_ai_get_strategy_mode_should_keep_custom_marker_minus_one', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      host.currentStrategyMode = -1;
      const service = new TimelineAiService(host);
      expect(service.getStrategyMode()).assertEqual(-1);
    });

    it('combined: timeline_ai_update_mode_and_has_history_should_keep_mode_and_detect_ai_source', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new TimelineAiHostForAH();
      const persistence = new AiPersistenceForAH();
      host.persistence = persistence;
      host.events = [createEventForAH(201, 'ai_item', 1)];
      const service = new TimelineAiService(host);
      await service.updateStrategyMode(2);
      expect(service.hasAiHistory()).assertTrue();
      expect(host.currentStrategyMode).assertEqual(2);
      expect(persistence.lastMode).assertEqual(2);
    });
  });
}
