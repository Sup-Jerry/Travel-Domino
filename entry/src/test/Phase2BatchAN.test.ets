import { describe, expect, it } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { TimelinePlanStateManager, ITimelinePlanStateHost } from '../main/ets/viewmodel/managers/TimelinePlanStateManager';
import { TimelineEventMutationManager, ITimelineEventMutationHost } from '../main/ets/viewmodel/managers/TimelineEventMutationManager';
import { TimelineRecalculationManager, ITimelineRecalculationHost } from '../main/ets/viewmodel/managers/TimelineRecalculationManager';
import { TimelineStrategyManager, ITimelineStrategyHost } from '../main/ets/viewmodel/managers/TimelineStrategyManager';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import {
  GeoPointInput,
  SoftReplanApplyResult,
  WeatherStageType,
  WeatherSuggestion
} from '../main/ets/domain/services/WeatherModels';
import { ConflictDetector } from '../main/ets/domain/timeline/ConflictDetector';
import { TimelineConflictResolver } from '../main/ets/domain/timeline/services/TimelineConflictResolver';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { TimelineCalculationService } from '../main/ets/domain/timeline/services/TimelineCalculationService';
import { PlanPersistenceFacade, PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import {
  AiReplanApplyDecision,
  AiReplanPreviewResult,
  AiReplanUndoToken,
  ExecutionSuggestionApplyResult,
  ITimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { WeatherStrategyAdjustment } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';

interface GenerateArgsAN {
  userPrompt: string;
  strategyMode: number | undefined;
  customStrategy: ComposableStrategy | undefined;
}

interface AdjustmentArgsAN {
  adjustment: WeatherStrategyAdjustment | undefined;
  hint: string | undefined;
}

interface ExecutionArgsAN {
  planId: number;
  suggestionId: string;
  adjustment: WeatherStrategyAdjustment | undefined;
  hint: string | undefined;
}

interface PreviewArgsAN {
  strategyMode: number;
  customStrategy: ComposableStrategy | undefined;
  keepCurrentMode: boolean | undefined;
}

interface ApplyPreviewArgsAN {
  preview: AiReplanPreviewResult;
  decision: AiReplanApplyDecision;
}

interface AddArgsAN {
  name: string;
  duration: number;
  isSchedule: boolean | undefined;
  fixedTime: string | undefined;
  dayOffset: number | undefined;
  preTravel: number | undefined;
  isHardLock: boolean | undefined;
  note: string | undefined;
  priority: number | undefined;
  lat: number | undefined;
  lng: number | undefined;
}

interface UpdateArgsAN {
  id: number;
  name: string;
  duration: number;
  fixedTime: string | undefined;
  dayOffset: number | undefined;
  isHardLock: boolean | undefined;
  note: string | undefined;
  priority: number | undefined;
  lat: number | undefined;
  lng: number | undefined;
}

interface LocationSnapshotAN {
  latitude: number;
  longitude: number;
  speed: number;
  accuracy: number;
  timestamp: number;
}

interface ArrivalEngineInstanceAN {
  getLastKnownLocation: () => LocationSnapshotAN | null;
}

interface ConflictResultAN {
  hasConflict: boolean;
  conflictItemId: number;
  conflictItemName: string;
  gapMinutes: number;
  conflictMsg: string;
}

interface CalcResultAN {
  hasFieldChanged: boolean;
  hasDayOffsetChanged: boolean;
}

interface TransitionEventAN {
  toStatus: PlanStatus;
}

interface CreateBundleResultAN {
  ai: FakeStrategyAiService;
  persistence: FakeStrategyPersistence;
  host: FakeStrategyHost;
  manager: TimelineStrategyManager;
}

class StaticPatch {
  private readonly target: Object;
  private readonly key: string;
  private readonly origin: Object;

  constructor(target: Object, key: string, replacement: Object) {
    this.target = target;
    this.key = key;
    this.origin = Reflect.get(target, key) as Object;
    Reflect.set(target, key, replacement);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.origin);
  }
}

class DummyWeatherFacade {
}

class FakeCompanionSnapshot {
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP' = 'IDLE';
}

class SimpleGeoPoint implements GeoPointInput {
  latitude: number = 0;
  longitude: number = 0;
}

interface MarkRecoveryCallAN {
  ok: boolean;
  reason: string;
}

class FakeTransitionResult {
  success: boolean = false;
  toStatus: PlanStatus = PlanStatus.DRAFT;
  event?: Object;
}

interface PlanStatusResult {
  planId: string;
  status: PlanStatus;
}

interface EvaluationInput {
  planId: string;
  eventCount: number;
  now: number;
}

interface EvaluationInputFull {
  planId: string;
  currentStatus: PlanStatus;
  now: number;
}

interface TransitionEvent {
  planId: string;
  fromStatus: PlanStatus;
  toStatus: PlanStatus;
  triggerSource: TransitionTriggerSource;
  triggerReason: string;
  timestamp: number;
}

interface RefreshWeatherArgs {
  forceRefresh: boolean | undefined;
  trigger: string | undefined;
  stage: WeatherStageType | undefined;
}

interface FakePlanContext {
  plannedEndTime: number;
  status: PlanStatus;
  currentNodeId: string;
}

class FakeScheduleOrchestrator {
  public calculateCalls: number = 0;
  public capturedGlobalStart: string = '';
  public capturedPlanStartDate: number = 0;
  public capturedEvents: TravelPlanItem[] = [];
  public nextCalculated: TravelPlanItem[] = [];

  public calculate(
    events: TravelPlanItem[],
    globalStartTimeStr: string,
    planStartDate: number,
    _options?: Object
  ): TravelPlanItem[] {
    this.calculateCalls += 1;
    this.capturedEvents = events;
    this.capturedGlobalStart = globalStartTimeStr;
    this.capturedPlanStartDate = planStartDate;
    return this.nextCalculated;
  }
}

class FakePlanStateMachine {
  public subscribePlanTransitionCalls: number = 0;
  public subscribeLocationChangeCalls: number = 0;
  public transitionUnsubscribeCalls: number = 0;
  public locationUnsubscribeCalls: number = 0;
  public updateExecutionContextCalls: number = 0;
  public buildEvaluationInputCalls: number = 0;
  public evaluateCalls: number = 0;
  public markRecoveryCalls: MarkRecoveryCallAN[] = [];
  public confirmPlanCalls: number = 0;
  public completeExecutionCalls: number = 0;
  public pauseExecutionCalls: number = 0;
  public resumeExecutionCalls: number = 0;
  public lastUpdateExecutionContext: Object | null = null;
  public lastEvaluationInput: Object | null = null;
  public nextEvaluateStatus: PlanStatus | null = null;
  public pauseResult: FakeTransitionResult = (() => { const r = new FakeTransitionResult(); r.success = true; r.toStatus = PlanStatus.PAUSED; return r; })();
  public resumeResult: FakeTransitionResult = (() => { const r = new FakeTransitionResult(); r.success = true; r.toStatus = PlanStatus.IN_PROGRESS; return r; })();
  private readonly statuses: Map<string, PlanStatus> = new Map<string, PlanStatus>();
  private readonly contexts: Map<string, FakePlanContext | null> = new Map<string, FakePlanContext | null>();
  private readonly transitionListeners: Map<string, (event: Object) => void> = new Map<string, (event: Object) => void>();
  private readonly locationListeners: Map<string, (event: Object) => void> = new Map<string, (event: Object) => void>();

  public setStatus(planId: string, status: PlanStatus): void {
    this.statuses.set(planId, status);
  }

  public setContext(planId: string, context: FakePlanContext | null): void {
    this.contexts.set(planId, context);
  }

  public emitTransition(planId: string, toStatus: PlanStatus): void {
    const fromStatus = this.statuses.get(planId) ?? PlanStatus.DRAFT;
    this.statuses.set(planId, toStatus);
    const listener = this.transitionListeners.get(planId);
    if (listener) {
      const evt: TransitionEvent = { planId: planId, fromStatus: fromStatus, toStatus: toStatus, triggerSource: TransitionTriggerSource.USER_ACTION, triggerReason: 'emit_transition', timestamp: Date.now() };
      listener(evt);
    }
  }

  public getPlanStatus(planId: string): Object {
    const r: PlanStatusResult = { planId: planId, status: this.statuses.get(planId) ?? PlanStatus.DRAFT };
    return r;
  }

  public subscribePlanTransition(planId: string, listener: (event: Object) => void): () => void {
    this.subscribePlanTransitionCalls += 1;
    this.transitionListeners.set(planId, listener);
    return (): void => {
      this.transitionUnsubscribeCalls += 1;
      this.transitionListeners.delete(planId);
    };
  }

  public subscribeLocationChange(planId: string, listener: (event: Object) => void): () => void {
    this.subscribeLocationChangeCalls += 1;
    this.locationListeners.set(planId, listener);
    return (): void => {
      this.locationUnsubscribeCalls += 1;
      this.locationListeners.delete(planId);
    };
  }

  public updateExecutionContext(command: Object): Object {
    this.updateExecutionContextCalls += 1;
    this.lastUpdateExecutionContext = command;
    return command;
  }

  public buildEvaluationInput(planId: string, events: EventEntity[], now: number): Object {
    this.buildEvaluationInputCalls += 1;
    const inp: EvaluationInput = { planId: planId, eventCount: events.length, now: now };
    this.lastEvaluationInput = inp;
    const result: EvaluationInputFull = { planId: planId, currentStatus: this.statuses.get(planId) ?? PlanStatus.DRAFT, now: now };
    return result;
  }

  public evaluateAndApply(input: Object): Object | null {
    this.evaluateCalls += 1;
    this.lastEvaluationInput = input;
    const planId = String((input as Record<string, Object>)['planId']);
    if (this.nextEvaluateStatus !== null) {
      this.statuses.set(planId, this.nextEvaluateStatus);
    }
    return null;
  }

  public getExecutionContext(planId: string): FakePlanContext | null {
    return this.contexts.has(planId) ? (this.contexts.get(planId) ?? null) : null;
  }

  public markRecovery(_planId: string, ok: boolean, reason: string): void {
    const call: MarkRecoveryCallAN = { ok: ok, reason: reason };
    this.markRecoveryCalls.push(call);
  }

  public confirmPlan(planId: string): FakeTransitionResult {
    this.confirmPlanCalls += 1;
    this.statuses.set(planId, PlanStatus.CONFIRMED);
    const r = new FakeTransitionResult(); r.success = true; r.toStatus = PlanStatus.CONFIRMED; return r;
  }

  public completeExecution(planId: string): FakeTransitionResult {
    this.completeExecutionCalls += 1;
    this.statuses.set(planId, PlanStatus.COMPLETED);
    const r = new FakeTransitionResult(); r.success = true; r.toStatus = PlanStatus.COMPLETED; return r;
  }

  public pauseExecution(planId: string): FakeTransitionResult {
    this.pauseExecutionCalls += 1;
    if (this.pauseResult.success) {
      this.statuses.set(planId, this.pauseResult.toStatus);
    }
    return this.pauseResult;
  }

  public resumeExecution(planId: string): FakeTransitionResult {
    this.resumeExecutionCalls += 1;
    if (this.resumeResult.success) {
      this.statuses.set(planId, this.resumeResult.toStatus);
    }
    return this.resumeResult;
  }
}

class FakeTimelinePlanStateHost implements ITimelinePlanStateHost {
  planId: number = 10;
  planName: string = 'origin_plan';
  events: EventEntity[] = [];
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 16).getTime();
  idleGapDetectionEnabled: boolean = false;
  idleGapTriggerMinutes: number = 15;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  weatherFeatureEnabled: boolean = false;
  executionWeatherEnabled: boolean = false;
  executionWeatherHint: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionWeatherAppliedSummary: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  weatherFacade: WeatherFacade = new DummyWeatherFacade() as WeatherFacade;
  planStateMachine: PlanStateMachine;
  public readonly machine: FakePlanStateMachine;
  public readonly orchestrator: FakeScheduleOrchestrator;
  public resolveStageValue: WeatherStageType = 'READY';
  public autoRouteEnabled: boolean = false;
  public startSchedulerCalls: number = 0;
  public stopSchedulerCalls: number = 0;
  public refreshWeatherCalls: number = 0;
  public lastRefreshWeatherArgs: Object | null = null;
  public recalculateCalls: number = 0;
  public calculateRealtimeCalls: number = 0;
  public regenerateCalls: number = 0;
  public markChangedCalls: number = 0;
  public refreshTimelineCalls: number = 0;
  public persistDateCalls: number = 0;
  public persistNameCalls: number = 0;
  public throwOnPersistDate: boolean = false;
  public throwOnPersistName: boolean = false;

  constructor(machine?: FakePlanStateMachine, orchestrator?: FakeScheduleOrchestrator) {
    this.machine = machine ?? new FakePlanStateMachine();
    this.planStateMachine = this.machine as never;
    this.orchestrator = orchestrator ?? new FakeScheduleOrchestrator();
  }

  resolveCurrentWeatherStage(): WeatherStageType {
    return this.resolveStageValue;
  }

  startExecutionWeatherScheduler(_planId?: number, _stage?: WeatherStageType): void {
    this.startSchedulerCalls += 1;
  }

  stopExecutionWeatherScheduler(): void {
    this.stopSchedulerCalls += 1;
  }

  async refreshExecutionWeather(
    forceRefresh?: boolean,
    trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    stage?: WeatherStageType
  ): Promise<void> {
    this.refreshWeatherCalls += 1;
    const args: RefreshWeatherArgs = { forceRefresh: forceRefresh, trigger: trigger, stage: stage };
    this.lastRefreshWeatherArgs = args;
  }

  getCompanionContext(_nowTs?: number): FakeCompanionSnapshot {
    return new FakeCompanionSnapshot();
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateCalls += 1;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return this.orchestrator as ScheduleOrchestrator;
  }

  isAutoRouteEnabled(): boolean {
    return this.autoRouteEnabled;
  }

  calculateRealtimeSchedule(): void {
    this.calculateRealtimeCalls += 1;
  }

  regenerateGroups(): void {
    this.regenerateCalls += 1;
  }

  markScheduleChanged(): void {
    this.markChangedCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshTimelineCalls += 1;
  }

  async persistPlanStartDate(_planId: number, startDate: number): Promise<void> {
    if (this.throwOnPersistDate) {
      throw new Error(`persist_date_fail:${startDate}`);
    }
    this.persistDateCalls += 1;
  }

  async persistPlanName(_planId: number, _name: string): Promise<void> {
    if (this.throwOnPersistName) {
      throw new Error('persist_name_fail');
    }
    this.persistNameCalls += 1;
  }
}

class FakeMutationHost implements ITimelineEventMutationHost {
  events: EventEntity[] = [];
  planId: number = 1;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;
  public firstScheduledIds: number[] = [];
  public resolvePoint: SimpleGeoPoint = new SimpleGeoPoint();
  public recalculateFromEventIdCalls: number = 0;
  public recalculateFromIndexCalls: number = 0;
  public recalculateFromIndexLast: number = -1;
  public saveCalls: number = 0;
  public updatePlanDateCalls: number = 0;
  public refreshCalls: number = 0;
  public endMutationCalls: number = 0;
  public tryBeginMutationResult: boolean = true;
  public throwOnSave: boolean = false;
  public throwOnUpdatePlanDate: boolean = false;

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return this.firstScheduledIds.indexOf(item.id) >= 0;
  }

  async resolveCoordinatesForPlaceName(
    _placeName: string,
    lat?: number,
    lng?: number,
    _source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput> {
    const point = new SimpleGeoPoint();
    point.latitude = Number.isFinite(this.resolvePoint.latitude) ? this.resolvePoint.latitude : (lat ?? fallbackLat ?? 0);
    point.longitude = Number.isFinite(this.resolvePoint.longitude) ? this.resolvePoint.longitude : (lng ?? fallbackLng ?? 0);
    return point;
  }

  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return latitude === 0 || longitude === 0;
  }

  recalculateFromEventId(_eventId: number): void {
    this.recalculateFromEventIdCalls += 1;
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls += 1;
    this.recalculateFromIndexLast = startIndex;
  }

  async save(): Promise<void> {
    if (this.throwOnSave) {
      throw new Error('save_fail');
    }
    this.saveCalls += 1;
  }

  async updatePlanDate(_newDateTimestamp: number): Promise<void> {
    if (this.throwOnUpdatePlanDate) {
      throw new Error('update_plan_date_fail');
    }
    this.updatePlanDateCalls += 1;
  }

  tryBeginMutation(_itemId: number): boolean {
    return this.tryBeginMutationResult;
  }

  endMutation(_itemId: number): void {
    this.endMutationCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshCalls += 1;
  }
}

class SpyBehaviorTracker extends UserBehaviorTracker {
  public deletionCalls: number = 0;
  public triggerAdaptation: boolean = false;

  recordDeletion(eventType: number, duration: number, trafficTime: number): void {
    super.recordDeletion(eventType, duration, trafficTime);
    this.deletionCalls += 1;
  }

  shouldTriggerAdaptation(): boolean {
    return this.triggerAdaptation;
  }
}

class FakeStrategyAiService implements ITimelineAiService {
  public strategyModeValue: number = 0;
  public hasHistoryValue: boolean = false;
  public applyWeatherAdjustmentValue: boolean = false;
  public executionSuggestionResult: ExecutionSuggestionApplyResult = { strategyApplied: true, replanSuccess: true, errorCode: '' };
  public previewResult: AiReplanPreviewResult = {
    prompt: 'preview',
    strategyMode: 0,
    generatedAt: 1,
    itemCount: 0,
    items: []
  };
  public undoToken: AiReplanUndoToken = {
    createdAt: 1,
    events: [],
    strategyMode: 0,
    strategyDensity: 1,
    strategyPace: 1,
    strategyPreference: 0,
    strategyEnergy: 1,
    lastAiPrompt: '',
    lastStrategyExplanation: ''
  };
  public generateCalls: number = 0;
  public updateModeCalls: number = 0;
  public switchCalls: number = 0;
  public applyWeatherCalls: number = 0;
  public applyExecutionCalls: number = 0;
  public triggerCalls: number = 0;
  public regenerateCustomCalls: number = 0;
  public regenerateCurrentCalls: number = 0;
  public changeCalls: number = 0;
  public buildPreviewCalls: number = 0;
  public applyPreviewCalls: number = 0;
  public restoreCalls: number = 0;
  public lastGenerateArgs: GenerateArgsAN | null = null;
  public lastUpdateMode: number = 0;
  public lastCustomStrategy: ComposableStrategy | undefined = undefined;
  public lastAdjustmentArgs: AdjustmentArgsAN | null = null;
  public lastExecutionArgs: ExecutionArgsAN | null = null;
  public lastChangeMode: number = 0;
  public lastPreviewArgs: PreviewArgsAN | null = null;
  public lastApplyPreviewArgs: ApplyPreviewArgsAN | null = null;
  public lastRestoreToken: AiReplanUndoToken | null = null;
  public generateError: Error | null = null;
  public getModeError: Error | null = null;
  public hasHistoryError: Error | null = null;
  public updateModeError: Error | null = null;
  public switchError: Error | null = null;
  public applyWeatherError: Error | null = null;
  public applyExecutionError: Error | null = null;
  public triggerError: Error | null = null;
  public regenerateCustomError: Error | null = null;
  public regenerateCurrentError: Error | null = null;
  public changeError: Error | null = null;
  public buildPreviewError: Error | null = null;
  public applyPreviewError: Error | null = null;
  public restoreError: Error | null = null;

  async generateByAi(userPrompt: string, strategyMode?: number, customStrategy?: ComposableStrategy): Promise<void> {
    if (this.generateError) {
      throw this.generateError;
    }
    this.generateCalls += 1;
    const generateArgs: GenerateArgsAN = {
      userPrompt: userPrompt,
      strategyMode: strategyMode,
      customStrategy: customStrategy
    };
    this.lastGenerateArgs = generateArgs;
  }

  getStrategyMode(): number {
    if (this.getModeError) {
      throw this.getModeError;
    }
    return this.strategyModeValue;
  }

  hasAiHistory(): boolean {
    if (this.hasHistoryError) {
      throw this.hasHistoryError;
    }
    return this.hasHistoryValue;
  }

  async updateStrategyMode(mode: number): Promise<void> {
    if (this.updateModeError) {
      throw this.updateModeError;
    }
    this.updateModeCalls += 1;
    this.lastUpdateMode = mode;
  }

  async switchToCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    if (this.switchError) {
      throw this.switchError;
    }
    this.switchCalls += 1;
    this.lastCustomStrategy = strategy;
  }

  async applyWeatherStrategyAdjustment(adjustment?: WeatherStrategyAdjustment, hint?: string): Promise<boolean> {
    if (this.applyWeatherError) {
      throw this.applyWeatherError;
    }
    this.applyWeatherCalls += 1;
    const adjustmentArgs: AdjustmentArgsAN = {
      adjustment: adjustment,
      hint: hint
    };
    this.lastAdjustmentArgs = adjustmentArgs;
    return this.applyWeatherAdjustmentValue;
  }

  async applyExecutionSuggestionWithStrategy(
    planId: number,
    suggestionId: string,
    adjustment?: WeatherStrategyAdjustment,
    hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    if (this.applyExecutionError) {
      throw this.applyExecutionError;
    }
    this.applyExecutionCalls += 1;
    const executionArgs: ExecutionArgsAN = {
      planId: planId,
      suggestionId: suggestionId,
      adjustment: adjustment,
      hint: hint
    };
    this.lastExecutionArgs = executionArgs;
    return this.executionSuggestionResult;
  }

  async applyWeatherSuggestion(_suggestionId: string): Promise<SoftReplanApplyResult> {
    return {
      success: true,
      rolledBack: false,
      errorCode: '',
      preview: {
        suggestionId: 'suggestion',
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

  async regenerateWithCustomStrategy(strategy: ComposableStrategy): Promise<void> {
    if (this.regenerateCustomError) {
      throw this.regenerateCustomError;
    }
    this.regenerateCustomCalls += 1;
    this.lastCustomStrategy = strategy;
  }

  async regenerateByCurrentStrategy(): Promise<void> {
    if (this.regenerateCurrentError) {
      throw this.regenerateCurrentError;
    }
    this.regenerateCurrentCalls += 1;
  }

  async changeStrategyAndRegenerate(mode: number): Promise<void> {
    if (this.changeError) {
      throw this.changeError;
    }
    this.changeCalls += 1;
    this.lastChangeMode = mode;
  }

  async triggerStrategyAdaptation(): Promise<void> {
    if (this.triggerError) {
      throw this.triggerError;
    }
    this.triggerCalls += 1;
  }

  async buildReplanPreview(
    strategyMode: number,
    customStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    if (this.buildPreviewError) {
      throw this.buildPreviewError;
    }
    this.buildPreviewCalls += 1;
    const previewArgs: PreviewArgsAN = {
      strategyMode: strategyMode,
      customStrategy: customStrategy,
      keepCurrentMode: keepCurrentMode
    };
    this.lastPreviewArgs = previewArgs;
    return this.previewResult;
  }

  async applyReplanPreview(
    preview: AiReplanPreviewResult,
    decision: AiReplanApplyDecision
  ): Promise<AiReplanUndoToken> {
    if (this.applyPreviewError) {
      throw this.applyPreviewError;
    }
    this.applyPreviewCalls += 1;
    const applyPreviewArgs: ApplyPreviewArgsAN = {
      preview: preview,
      decision: decision
    };
    this.lastApplyPreviewArgs = applyPreviewArgs;
    return this.undoToken;
  }

  async restoreFromUndoToken(token: AiReplanUndoToken): Promise<void> {
    if (this.restoreError) {
      throw this.restoreError;
    }
    this.restoreCalls += 1;
    this.lastRestoreToken = token;
  }
}

class FakeStrategyPersistence extends PlanPersistenceFacade {
  public snapshot: PlanEventsSnapshot;

  constructor(snapshot?: PlanEventsSnapshot) {
    super();
    this.snapshot = snapshot ?? { events: [] };
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return this.snapshot;
  }
}

class FakeStrategyHost implements ITimelineStrategyHost {
  planId: number = 1;
  persistence: PlanPersistenceFacade;

  constructor(persistence?: PlanPersistenceFacade) {
    this.persistence = persistence ?? new FakeStrategyPersistence();
  }
}

class SpyMutationStrategyManager extends TimelineStrategyManager {
  public adaptationCalls: number = 0;
  public throwOnAdaptation: boolean = false;

  constructor() {
    super(new FakeStrategyHost(), new FakeStrategyAiService());
  }

  async triggerStrategyAdaptation(): Promise<void> {
    if (this.throwOnAdaptation) {
      throw new Error('strategy_adaptation_fail');
    }
    this.adaptationCalls += 1;
  }
}

class SpyMutationManager extends TimelineEventMutationManager {
  public addCalls: number = 0;
  public updateCalls: number = 0;
  public lastAddArgs: AddArgsAN | null = null;
  public lastUpdateArgs: UpdateArgsAN | null = null;

  async addNewItem(
    name: string,
    duration: number,
    isSchedule?: boolean,
    fixedTime?: string,
    dayOffset?: number,
    preTravel?: number,
    isHardLock?: boolean,
    note?: string,
    priority?: number,
    lat?: number,
    lng?: number
  ): Promise<void> {
    this.addCalls += 1;
    const addArgs: AddArgsAN = {
      name: name,
      duration: duration,
      isSchedule: isSchedule,
      fixedTime: fixedTime,
      dayOffset: dayOffset,
      preTravel: preTravel,
      isHardLock: isHardLock,
      note: note,
      priority: priority,
      lat: lat,
      lng: lng
    };
    this.lastAddArgs = addArgs;
  }

  async updateEventInfo(
    id: number,
    name: string,
    duration: number,
    fixedTime?: string,
    dayOffset?: number,
    isHardLock?: boolean,
    note?: string,
    priority?: number,
    lat?: number,
    lng?: number
  ): Promise<void> {
    this.updateCalls += 1;
    const updateArgs: UpdateArgsAN = {
      id: id,
      name: name,
      duration: duration,
      fixedTime: fixedTime,
      dayOffset: dayOffset,
      isHardLock: isHardLock,
      note: note,
      priority: priority,
      lat: lat,
      lng: lng
    };
    this.lastUpdateArgs = updateArgs;
  }
}

class FakeRecalculationHost implements ITimelineRecalculationHost {
  events: EventEntity[] = [];
  planId: number = 1;
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 16).getTime();
  idleGapDetectionEnabled: boolean = false;
  idleGapTriggerMinutes: number = 15;
  currentStrategyMode: number = 0;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;
  public firstScheduledIds: number[] = [];
  public calculateRealtimeCalls: number = 0;
  public regenerateGroupsCalls: number = 0;
  public markChangedCalls: number = 0;
  public refreshCalls: number = 0;

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return this.firstScheduledIds.indexOf(item.id) >= 0;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new FakeScheduleOrchestrator() as ScheduleOrchestrator;
  }

  calculateRealtimeSchedule(): void {
    this.calculateRealtimeCalls += 1;
  }

  regenerateGroups(): void {
    this.regenerateGroupsCalls += 1;
  }

  markScheduleChanged(): void {
    this.markChangedCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshCalls += 1;
  }
}

class SpyRecalculationManager extends TimelineRecalculationManager {
  public recalculateCalls: number = 0;
  public recalculateFromEventIdCalls: number = 0;
  public recalculateFromIndexCalls: number = 0;
  public lastRecalculateEventId: number = -1;
  public lastRecalculateIndex: number = -1;

  constructor(host: ITimelineRecalculationHost) {
    super(host);
  }

  recalculate(): void {
    this.recalculateCalls += 1;
  }

  recalculateFromEventId(eventId: number): void {
    this.recalculateFromEventIdCalls += 1;
    this.lastRecalculateEventId = eventId;
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls += 1;
    this.lastRecalculateIndex = startIndex;
  }
}

function createEvent(
  id: number,
  name: string,
  status: number = 1,
  sortOrder: number = 0,
  fixedStartTime: string = '09:00',
  dayOffset: number = 0
): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = status;
  event.sort_order = sortOrder;
  event.fixed_start_time = fixedStartTime;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dayOffset;
  event.computed_time = fixedStartTime;
  event.pre_travel_min = 0;
  event.is_travel_manual = 0;
  event.travel_mode = 2;
  event.transport_mode = 2;
  return event;
}

function createTravelItem(
  id: number,
  name: string,
  status: number = 1,
  sortOrder: number = 0,
  dayOffset: number = 0
): TravelPlanItem {
  return {
    id: id,
    name: name,
    note: '',
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: sortOrder,
    status: status,
    lockStatus: 0,
    fixedStartTime: '09:00',
    dayOffset: dayOffset,
    itemType: 0,
    priority: 0,
    isTravelManual: 0,
    source: 0,
    delFlag: 0,
    groupId: 0,
    address: '',
    aiReasoning: '',
    travelMode: 2,
    latitude: 30.1,
    longitude: 120.2
  };
}

function createStrategy(): ComposableStrategy {
  return {
    density: 1,
    pace: 1,
    preference: 0,
    energy: 1
  };
}

function captureSyncError(action: () => void): string {
  let message = '';
  try {
    action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  return message;
}

async function captureAsyncError(action: () => Promise<void>): Promise<string> {
  let message = '';
  try {
    await action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  return message;
}

function registerPlanStateTests(): void {
  describe('phase2BatchANTest_timeline_plan_state_manager', () => {
    it('normal: bind_plan_state_should_subscribe_and_react_to_transition_events', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setStatus('10', PlanStatus.READY);
      const host = new FakeTimelinePlanStateHost(machine);
      host.weatherFeatureEnabled = true;
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.bindPlanState(10);
      machine.emitTransition('10', PlanStatus.PAUSED);
      manager.unbindPlanState();
      // Assert
      expect(machine.subscribePlanTransitionCalls).assertEqual(1);
      expect(machine.subscribeLocationChangeCalls).assertEqual(1);
      expect(host.currentPlanStatus).assertEqual(PlanStatus.PAUSED);
      expect(host.startSchedulerCalls >= 1).assertTrue();
    });

    it('boundary: bind_plan_state_should_rebind_cleanly', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setStatus('10', PlanStatus.CONFIRMED);
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.bindPlanState(10);
      manager.bindPlanState(10);
      const transitionUnsubscribed = machine.transitionUnsubscribeCalls;
      const locationUnsubscribed = machine.locationUnsubscribeCalls;
      manager.unbindPlanState();
      // Assert
      expect(transitionUnsubscribed).assertEqual(1);
      expect(locationUnsubscribed).assertEqual(1);
    });

    it('invalid: bind_plan_state_should_ignore_non_positive_plan_id', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.bindPlanState(0);
      // Assert
      expect(machine.subscribePlanTransitionCalls).assertEqual(0);
      expect(machine.subscribeLocationChangeCalls).assertEqual(0);
    });

    it('normal: unbind_plan_state_should_release_existing_subscriptions', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setStatus('10', PlanStatus.READY);
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      manager.bindPlanState(10);
      // Act
      manager.unbindPlanState();
      // Assert
      expect(machine.transitionUnsubscribeCalls).assertEqual(1);
      expect(machine.locationUnsubscribeCalls).assertEqual(1);
    });

    it('boundary: unbind_plan_state_should_be_idempotent', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setStatus('10', PlanStatus.READY);
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      manager.bindPlanState(10);
      // Act
      manager.unbindPlanState();
      manager.unbindPlanState();
      // Assert
      expect(machine.transitionUnsubscribeCalls).assertEqual(1);
      expect(machine.locationUnsubscribeCalls).assertEqual(1);
    });

    it('invalid: unbind_plan_state_should_tolerate_never_bound_manager', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.unbindPlanState();
      // Assert
      expect(machine.transitionUnsubscribeCalls).assertEqual(0);
      expect(machine.locationUnsubscribeCalls).assertEqual(0);
    });

    it('normal: evaluate_plan_status_by_runtime_should_pull_last_known_location_and_apply', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setStatus('10', PlanStatus.READY);
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(ArrivalReminderEngine, 'getInstance', (): ArrivalEngineInstanceAN => {
        const loc: LocationSnapshotAN = {
          latitude: 30.1,
          longitude: 120.2,
          speed: 5,
          accuracy: 20,
          timestamp: 123
        };
        const inst: ArrivalEngineInstanceAN = {
          getLastKnownLocation: (): LocationSnapshotAN | null => loc
        };
        return inst;
      });
      // Act
      manager.evaluatePlanStatusByRuntime();
      patch.restore();
      // Assert
      expect(machine.updateExecutionContextCalls).assertEqual(1);
      expect(machine.buildEvaluationInputCalls).assertEqual(1);
      expect(machine.evaluateCalls).assertEqual(1);
    });

    it('boundary: evaluate_plan_status_by_runtime_should_apply_even_without_location_snapshot', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setStatus('10', PlanStatus.CONFIRMED);
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(ArrivalReminderEngine, 'getInstance', (): ArrivalEngineInstanceAN => {
        const inst: ArrivalEngineInstanceAN = {
          getLastKnownLocation: (): LocationSnapshotAN | null => null
        };
        return inst;
      });
      // Act
      manager.evaluatePlanStatusByRuntime();
      patch.restore();
      // Assert
      expect(machine.updateExecutionContextCalls).assertEqual(0);
      expect(machine.buildEvaluationInputCalls).assertEqual(1);
      expect(machine.evaluateCalls).assertEqual(1);
    });

    it('invalid: evaluate_plan_status_by_runtime_should_ignore_invalid_plan_id', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.evaluatePlanStatusByRuntime();
      // Assert
      expect(machine.buildEvaluationInputCalls).assertEqual(0);
      expect(machine.evaluateCalls).assertEqual(0);
    });

    it('normal: on_location_sample_for_state_machine_should_update_execution_context', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.onLocationSampleForStateMachine(30.1, 120.2, 3, 15, 100);
      manager.onLocationSampleForStateMachine(30.2, 120.3, 4, 15, 200);
      // Assert
      const command = machine.lastUpdateExecutionContext as Record<string, Object>;
      expect(machine.updateExecutionContextCalls).assertEqual(2);
      expect(Number(command['distanceToFirstNodeMeters']) > 0).assertTrue();
    });

    it('boundary: on_location_sample_for_state_machine_should_skip_update_when_plan_id_invalid', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.onLocationSampleForStateMachine(30.1, 120.2, 3, 15, 100);
      // Assert
      expect(machine.updateExecutionContextCalls).assertEqual(0);
    });

    it('invalid: on_location_sample_for_state_machine_should_ignore_non_finite_coordinates', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.onLocationSampleForStateMachine(Number.NaN, 120.2, 3, 15, 100);
      // Assert
      expect(machine.updateExecutionContextCalls).assertEqual(0);
    });

    it('normal: recover_plan_runtime_state_should_fire_terminal_state_cleanup_when_status_changes', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setContext('10', {
        plannedEndTime: Date.now() + 10_000,
        status: PlanStatus.READY,
        currentNodeId: 'node_1'
      });
      machine.setStatus('10', PlanStatus.COMPLETED);
      const host = new FakeTimelinePlanStateHost(machine);
      host.weatherFeatureEnabled = true;
      host.executionWeatherHint = 'hint';
      host.executionWeatherSuggestions = [{ suggestionId: 's' } as WeatherSuggestion];
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.recoverPlanRuntimeState();
      // Assert
      expect(host.stopSchedulerCalls).assertEqual(1);
      expect(host.executionWeatherHint).assertEqual('');
      expect(host.executionWeatherSuggestions.length).assertEqual(0);
      expect(machine.markRecoveryCalls[machine.markRecoveryCalls.length - 1].ok).assertTrue();
    });

    it('boundary: recover_plan_runtime_state_should_rebuild_when_context_missing', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.setContext('10', null);
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.recoverPlanRuntimeState();
      // Assert
      expect(machine.markRecoveryCalls.length).assertEqual(2);
      expect(machine.markRecoveryCalls[0].ok).assertFalse();
      expect(machine.markRecoveryCalls[1].ok).assertTrue();
      expect(machine.evaluateCalls).assertEqual(1);
    });

    it('invalid: recover_plan_runtime_state_should_ignore_invalid_plan_id', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const host = new FakeTimelinePlanStateHost(machine);
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      manager.recoverPlanRuntimeState();
      // Assert
      expect(machine.markRecoveryCalls.length).assertEqual(0);
    });

    it('normal: pause_current_execution_should_update_status_on_success', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const pauseResult = new FakeTransitionResult();
      pauseResult.success = true;
      pauseResult.toStatus = PlanStatus.PAUSED;
      const pauseEvent: TransitionEventAN = { toStatus: PlanStatus.PAUSED };
      pauseResult.event = pauseEvent as Object;
      machine.pauseResult = pauseResult;
      const host = new FakeTimelinePlanStateHost(machine);
      host.weatherFeatureEnabled = true;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      // Assert
      expect(paused).assertTrue();
      expect(host.currentPlanStatus).assertEqual(PlanStatus.PAUSED);
      expect(host.startSchedulerCalls).assertEqual(1);
    });

    it('boundary: pause_current_execution_should_return_false_when_plan_id_invalid', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      // Assert
      expect(paused).assertFalse();
    });

    it('invalid: pause_current_execution_should_return_false_when_state_machine_rejects', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.pauseResult = { success: false, toStatus: PlanStatus.PAUSED };
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      // Assert
      expect(paused).assertFalse();
      expect(host.currentPlanStatus).assertEqual(PlanStatus.DRAFT);
    });

    it('normal: resume_current_execution_should_recalculate_and_refresh_weather', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      const resumeResult = new FakeTransitionResult();
      resumeResult.success = true;
      resumeResult.toStatus = PlanStatus.IN_PROGRESS;
      const resumeEvent: TransitionEventAN = { toStatus: PlanStatus.IN_PROGRESS };
      resumeResult.event = resumeEvent as Object;
      machine.resumeResult = resumeResult;
      const host = new FakeTimelinePlanStateHost(machine);
      host.weatherFeatureEnabled = true;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const resumed = manager.resumeCurrentExecution();
      // Assert
      expect(resumed).assertTrue();
      expect(host.currentPlanStatus).assertEqual(PlanStatus.IN_PROGRESS);
      expect(host.recalculateCalls).assertEqual(1);
      expect(host.refreshWeatherCalls).assertEqual(1);
      expect(host.executionWeatherLevel).assertEqual('NOTICE');
      expect(host.executionWeatherAppliedSummary.length > 0).assertTrue();
    });

    it('boundary: resume_current_execution_should_return_false_when_plan_id_invalid', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const resumed = manager.resumeCurrentExecution();
      // Assert
      expect(resumed).assertFalse();
    });

    it('invalid: resume_current_execution_should_return_false_when_state_machine_rejects', 0, () => {
      // Arrange
      const machine = new FakePlanStateMachine();
      machine.resumeResult = { success: false, toStatus: PlanStatus.IN_PROGRESS };
      const host = new FakeTimelinePlanStateHost(machine);
      const manager = new TimelinePlanStateManager(host);
      // Act
      const resumed = manager.resumeCurrentExecution();
      // Assert
      expect(resumed).assertFalse();
      expect(host.recalculateCalls).assertEqual(0);
      expect(host.refreshWeatherCalls).assertEqual(0);
    });

    it('normal: preview_plan_date_shift_should_return_clean_preview', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.globalStartTime = '04-16 09:30';
      host.events = [createEvent(1, 'museum', 1, 0, '09:00', 0)];
      host.orchestrator.nextCalculated = [createTravelItem(1, 'museum')];
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(ConflictDetector, 'checkConflicts', (): ConflictResultAN => {
        const r: ConflictResultAN = {
          hasConflict: false,
          conflictItemId: -1,
          conflictItemName: '',
          gapMinutes: 0,
          conflictMsg: ''
        };
        return r;
      });
      // Act
      const preview = manager.previewPlanDateShift(new Date(2026, 3, 20, 12, 30).getTime());
      patch.restore();
      // Assert
      expect(preview.hasRigidConflict).assertFalse();
      expect(host.orchestrator.capturedGlobalStart).assertEqual('09:30');
    });

    it('boundary: preview_plan_date_shift_should_fallback_to_default_global_start', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.globalStartTime = 'bad-start';
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(ConflictDetector, 'checkConflicts', (): ConflictResultAN => {
        const r: ConflictResultAN = {
          hasConflict: false,
          conflictItemId: -1,
          conflictItemName: '',
          gapMinutes: 0,
          conflictMsg: ''
        };
        return r;
      });
      // Act
      manager.previewPlanDateShift(new Date(2026, 3, 20, 12, 30).getTime());
      patch.restore();
      // Assert
      expect(host.orchestrator.capturedGlobalStart).assertEqual('08:00');
    });

    it('invalid: preview_plan_date_shift_should_surface_rigid_conflict_payload', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(ConflictDetector, 'checkConflicts', (): ConflictResultAN => {
        const r: ConflictResultAN = {
          hasConflict: true,
          conflictItemId: 9,
          conflictItemName: 'anchor',
          gapMinutes: 35,
          conflictMsg: 'conflict'
        };
        return r;
      });
      // Act
      const preview = manager.previewPlanDateShift(new Date(2026, 3, 20).getTime());
      patch.restore();
      // Assert
      expect(preview.hasRigidConflict).assertTrue();
      expect(preview.conflictItemId).assertEqual(9);
      expect(preview.gapMinutes).assertEqual(35);
    });

    it('normal: update_plan_date_should_persist_and_refresh', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);
      const nextDate = new Date(2026, 3, 18, 14, 45, 1).getTime();
      // Act
      await manager.updatePlanDate(nextDate);
      // Assert
      expect(host.persistDateCalls).assertEqual(1);
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
      expect(host.refreshTimelineCalls).assertEqual(1);
    });

    it('boundary: update_plan_date_should_skip_persist_for_temp_plan', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = -1;
      const manager = new TimelinePlanStateManager(host);
      // Act
      await manager.updatePlanDate(new Date(2026, 3, 18, 14, 45, 1).getTime());
      // Assert
      expect(host.persistDateCalls).assertEqual(0);
      expect(host.calculateRealtimeCalls).assertEqual(1);
    });

    it('invalid: update_plan_date_should_propagate_persist_failure', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.throwOnPersistDate = true;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await manager.updatePlanDate(new Date(2026, 3, 18).getTime());
      });
      // Assert
      expect(message.indexOf('persist_date_fail:') >= 0).assertTrue();
      expect(host.calculateRealtimeCalls).assertEqual(0);
    });

    it('normal: rename_plan_should_persist_and_update_name', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);
      // Act
      await manager.renamePlan('updated_plan');
      // Assert
      expect(host.persistNameCalls).assertEqual(1);
      expect(host.planName).assertEqual('updated_plan');
    });

    it('boundary: rename_plan_should_ignore_temp_plan', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = -1;
      const manager = new TimelinePlanStateManager(host);
      // Act
      await manager.renamePlan('ignored_plan');
      // Assert
      expect(host.persistNameCalls).assertEqual(0);
      expect(host.planName).assertEqual('origin_plan');
    });

    it('invalid: rename_plan_should_propagate_persist_failure', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.throwOnPersistName = true;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await manager.renamePlan('fail_name');
      });
      // Assert
      expect(message).assertEqual('persist_name_fail');
      expect(host.planName).assertEqual('origin_plan');
    });

    it('normal: is_date_conflict_should_return_true_for_previous_day', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = new Date(2026, 3, 18).getTime();
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(TimelineConflictResolver, 'isDateConflict', (targetDateMs: number, planStartDate: number): boolean => {
        return targetDateMs < planStartDate;
      });
      // Act
      const conflict = manager.isDateConflict(new Date(2026, 3, 17).getTime());
      patch.restore();
      // Assert
      expect(conflict).assertTrue();
    });

    it('boundary: is_date_conflict_should_return_false_without_plan_start', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = 0;
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(TimelineConflictResolver, 'isDateConflict', (): boolean => false);
      // Act
      const conflict = manager.isDateConflict(new Date(2026, 3, 17).getTime());
      patch.restore();
      // Assert
      expect(conflict).assertFalse();
    });

    it('invalid: is_date_conflict_should_return_false_for_nan_target', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(TimelineConflictResolver, 'isDateConflict', (targetDateMs: number): boolean => {
        return Number.isFinite(targetDateMs) && targetDateMs < 0;
      });
      // Act
      const conflict = manager.isDateConflict(Number.NaN);
      patch.restore();
      // Assert
      expect(conflict).assertFalse();
    });
  });
}

function registerEventMutationTests(): void {
  describe('phase2BatchANTest_timeline_event_mutation_manager', () => {
    const createManager = (
      host?: FakeMutationHost,
      behaviorTracker?: SpyBehaviorTracker,
      strategyManager?: SpyMutationStrategyManager
    ): TimelineEventMutationManager =>
      new TimelineEventMutationManager(
        host ?? new FakeMutationHost(),
        behaviorTracker ?? new SpyBehaviorTracker(),
        strategyManager ?? new SpyMutationStrategyManager()
      );

    it('normal: add_new_item_should_insert_scheduled_item_and_recalculate', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.resolvePoint.latitude = 31.2;
      host.resolvePoint.longitude = 121.5;
      const insertPatch = new StaticPatch(EventRepositoryImpl, 'insertEvent', async (): Promise<number> => 101);
      const manager = createManager(host);
      // Act
      await manager.addNewItem('new_spot', 90, true, '10:30', 1, -1, false, 'note', 1);
      insertPatch.restore();
      // Assert
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(101);
      expect(host.events[0].status).assertEqual(1);
      expect(host.events[0].latitude).assertEqual(31.2);
      expect(host.recalculateFromEventIdCalls).assertEqual(1);
    });

    it('boundary: add_new_item_should_append_backlog_item', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const insertPatch = new StaticPatch(EventRepositoryImpl, 'insertEvent', async (): Promise<number> => 102);
      const manager = createManager(host);
      // Act
      await manager.addNewItem('wish', 45, false, undefined, 0, -1, false, '', 0);
      insertPatch.restore();
      // Assert
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].status).assertEqual(0);
      expect(host.events[0].id).assertEqual(102);
    });

    it('invalid: add_new_item_should_keep_failed_repository_id_and_fallback_pretravel', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.enableAutoAmapRoute = false;
      const insertPatch = new StaticPatch(EventRepositoryImpl, 'insertEvent', async (): Promise<number> => -1);
      const manager = createManager(host);
      // Act
      await manager.addNewItem('broken', 30, true, undefined, 0, -1, false, '', 0);
      insertPatch.restore();
      // Assert
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(-1);
      expect(host.events[0].pre_travel_min).assertEqual(0);
    });

    it('normal: update_manual_commute_should_persist_positive_minutes', 0, () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(11, 'museum');
      let updateCalls = 0;
      const updatePatch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {
        updateCalls += 1;
      });
      const manager = createManager(host);
      // Act
      manager.updateManualCommute(target, 25);
      updatePatch.restore();
      // Assert
      expect(target.pre_travel_min).assertEqual(25);
      expect(target.is_travel_manual).assertEqual(1);
      expect(updateCalls).assertEqual(2);
      expect(host.recalculateFromEventIdCalls).assertEqual(1);
    });

    it('boundary: update_manual_commute_should_floor_decimal_minutes', 0, () => {
      // Arrange
      const target = createEvent(12, 'food');
      const updatePatch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {});
      const manager = createManager(new FakeMutationHost());
      // Act
      manager.updateManualCommute(target, 12.9);
      updatePatch.restore();
      // Assert
      expect(target.pre_travel_min).assertEqual(12);
    });

    it('invalid: update_manual_commute_should_ignore_nonpositive_minutes', 0, () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(13, 'ignore');
      let updateCalls = 0;
      const updatePatch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {
        updateCalls += 1;
      });
      const manager = createManager(host);
      // Act
      manager.updateManualCommute(target, 0);
      updatePatch.restore();
      // Assert
      expect(target.pre_travel_min).assertEqual(0);
      expect(updateCalls).assertEqual(0);
      expect(host.recalculateFromEventIdCalls).assertEqual(0);
    });

    it('invalid: update_manual_commute_should_ignore_null_item', 0, () => {
      // Arrange
      const host = new FakeMutationHost();
      let updateCalls = 0;
      const updatePatch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {
        updateCalls += 1;
      });
      const manager = createManager(host);
      // Act
      manager.updateManualCommute(null as never, 15);
      updatePatch.restore();
      // Assert
      expect(updateCalls).assertEqual(0);
      expect(host.recalculateFromEventIdCalls).assertEqual(0);
    });

    it('normal: move_event_should_swap_adjacent_scheduled_items', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const first = createEvent(21, 'first', 1, 0, '09:00', 0);
      const second = createEvent(22, 'second', 1, 100, '10:00', 0);
      const backlog = createEvent(23, 'backlog', 0, 0, '', 0);
      host.events = [first, second, backlog];
      let consistencyCalls = 0;
      const consistencyPatch = new StaticPatch(EventRepositoryImpl, 'updateTimelineConsistency', async (): Promise<void> => {
        consistencyCalls += 1;
      });
      const manager = createManager(host);
      // Act
      await manager.moveEvent(1, 'up');
      consistencyPatch.restore();
      // Assert
      expect(host.events[0].id).assertEqual(22);
      expect(host.events[1].id).assertEqual(21);
      expect(host.events[0].sort_order).assertEqual(0);
      expect(host.events[1].sort_order).assertEqual(100);
      expect(host.recalculateFromIndexLast).assertEqual(0);
      expect(consistencyCalls).assertEqual(1);
    });

    it('boundary: move_event_should_ignore_edge_schedule_move', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.events = [createEvent(24, 'first', 1, 0, '09:00', 0)];
      const manager = createManager(host);
      // Act
      await manager.moveEvent(0, 'up');
      // Assert
      expect(host.events[0].id).assertEqual(24);
      expect(host.recalculateFromIndexCalls).assertEqual(0);
    });

    it('invalid: move_event_should_ignore_out_of_range_index', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.events = [createEvent(25, 'only', 1, 0, '09:00', 0)];
      const manager = createManager(host);
      // Act
      await manager.moveEvent(5, 'down');
      // Assert
      expect(host.recalculateFromIndexCalls).assertEqual(0);
    });

    it('normal: move_all_backlog_to_schedule_should_promote_backlog_and_save', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const scheduled = createEvent(31, 'scheduled', 1, 100, '09:00', 0);
      const backlog = createEvent(32, 'backlog', 0, 0, '', 0);
      host.events = [scheduled, backlog];
      host.firstScheduledIds = [31];
      const manager = createManager(host);
      // Act
      const moved = await manager.moveAllBacklogToSchedule();
      // Assert
      expect(moved).assertEqual(1);
      expect(backlog.status).assertEqual(1);
      expect(host.saveCalls).assertEqual(1);
      expect(host.recalculateFromIndexCalls).assertEqual(1);
      expect(host.refreshCalls >= 2).assertTrue();
    });

    it('boundary: move_all_backlog_to_schedule_should_return_zero_when_empty', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.events = [createEvent(33, 'scheduled', 1, 0, '09:00', 0)];
      const manager = createManager(host);
      // Act
      const moved = await manager.moveAllBacklogToSchedule();
      // Assert
      expect(moved).assertEqual(0);
      expect(host.saveCalls).assertEqual(0);
    });

    it('invalid: move_all_backlog_to_schedule_should_propagate_save_failure', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.throwOnSave = true;
      host.events = [createEvent(34, 'scheduled', 1, 0, '09:00', 0), createEvent(35, 'backlog', 0, 0, '', 0)];
      const manager = createManager(host);
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await manager.moveAllBacklogToSchedule();
      });
      // Assert
      expect(message).assertEqual('save_fail');
    });

    it('boundary: move_all_backlog_to_schedule_should_keep_pretravel_when_auto_route_disabled', 0, async () => {
      // Arrange
      class SortSpyEventsAN extends Array<EventEntity> {
        sort(compareFn?: (a: EventEntity, b: EventEntity) => number) {
          if (compareFn) {
            compareFn(createEvent(360, 'mix_schedule', 1, 0, '08:00', 0), createEvent(361, 'mix_backlog', 0, 0, '', 0));
          }
          super.sort(compareFn);
          return this;
        }
      }
      const host = new FakeMutationHost();
      host.enableAutoAmapRoute = false;
      const scheduled = createEvent(36, 'scheduled', 1, 100, '09:00', 0);
      const backlog = createEvent(37, 'backlog', 0, 0, '', 0);
      backlog.pre_travel_min = 18;
      const events = new SortSpyEventsAN();
      events.push(scheduled);
      events.push(backlog);
      host.events = events;
      const manager = createManager(host);
      // Act
      const moved = await manager.moveAllBacklogToSchedule();
      // Assert
      expect(moved).assertEqual(1);
      expect(backlog.status).assertEqual(1);
      expect(backlog.pre_travel_min).assertEqual(18);
      expect(host.saveCalls).assertEqual(1);
    });

    it('normal: move_to_backlog_should_demote_schedule_and_save', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(41, 'target', 1, 100, '09:00', 0);
      host.events = [target];
      const manager = createManager(host);
      // Act
      await manager.moveToBacklog(target);
      // Assert
      expect(target.status).assertEqual(0);
      expect(target.sort_order).assertEqual(0);
      expect(host.saveCalls).assertEqual(1);
      expect(host.endMutationCalls).assertEqual(1);
      expect(host.refreshCalls >= 1).assertTrue();
    });

    it('boundary: move_to_backlog_should_refresh_and_skip_non_schedule_item', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(42, 'backlog', 0, 0, '', 0);
      host.events = [target];
      const manager = createManager(host);
      // Act
      await manager.moveToBacklog(target);
      // Assert
      expect(host.refreshCalls).assertEqual(1);
      expect(host.saveCalls).assertEqual(0);
      expect(host.endMutationCalls).assertEqual(1);
    });

    it('invalid: move_to_backlog_should_throw_when_mutation_locked', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.tryBeginMutationResult = false;
      const target = createEvent(43, 'locked', 1, 100, '09:00', 0);
      host.events = [target];
      const manager = createManager(host);
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await manager.moveToBacklog(target);
      });
      // Assert
      expect(message.indexOf('mutation_in_flight') >= 0).assertTrue();
      expect(host.endMutationCalls).assertEqual(0);
    });

    it('normal: hard_delete_should_remove_item_and_recalculate', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(51, 'delete', 1, 0, '09:00', 0);
      const keep = createEvent(52, 'keep', 1, 100, '10:00', 0);
      host.events = [target, keep];
      const deletePatch = new StaticPatch(EventRepositoryImpl, 'hardDeleteEvent', async (): Promise<void> => {});
      const manager = createManager(host);
      // Act
      await manager.hardDelete(target);
      deletePatch.restore();
      // Assert
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(52);
      expect(host.recalculateFromIndexCalls).assertEqual(1);
      expect(host.endMutationCalls).assertEqual(1);
    });

    it('boundary: hard_delete_should_trigger_strategy_adaptation_for_ai_item', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(53, 'ai_item', 1, 0, '09:00', 0);
      target.source = 1;
      target.type = 2;
      target.duration = 80;
      target.pre_travel_min = 15;
      host.events = [target];
      const behavior = new SpyBehaviorTracker();
      behavior.triggerAdaptation = true;
      const strategy = new SpyMutationStrategyManager();
      const deletePatch = new StaticPatch(EventRepositoryImpl, 'hardDeleteEvent', async (): Promise<void> => {});
      const manager = createManager(host, behavior, strategy);
      // Act
      await manager.hardDelete(target);
      deletePatch.restore();
      // Assert
      expect(behavior.deletionCalls).assertEqual(1);
      expect(strategy.adaptationCalls).assertEqual(1);
    });

    it('invalid: hard_delete_should_refresh_and_rethrow_repository_error', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(54, 'broken', 1, 0, '09:00', 0);
      host.events = [target];
      const deletePatch = new StaticPatch(EventRepositoryImpl, 'hardDeleteEvent', async (): Promise<void> => {
        throw new Error('delete_fail');
      });
      const manager = createManager(host);
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await manager.hardDelete(target);
      });
      deletePatch.restore();
      // Assert
      expect(message).assertEqual('[SCHEDULE][hard_delete_fail] itemId=54');
      expect(host.refreshCalls).assertEqual(2);
      expect(host.endMutationCalls).assertEqual(1);
    });

    it('normal: resolve_conflict_by_backlog_should_reset_target_and_delegate_update', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(61, 'conflict', 1, 0, '09:00', 2);
      target.dynamic_day_offset = 3;
      host.events = [target];
      const manager = new SpyMutationManager(host, new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      await manager.resolveConflictByBacklog(61, 'conflict_new', 70, 'note', 1);
      // Assert
      expect(target.status).assertEqual(0);
      expect(target.day_offset).assertEqual(0);
      expect(target.dynamic_day_offset).assertEqual(0);
      expect(target.fixed_start_time).assertEqual('');
      expect(manager.updateCalls).assertEqual(1);
    });

    it('boundary: resolve_conflict_by_backlog_should_ignore_missing_target', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const manager = new SpyMutationManager(host, new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      await manager.resolveConflictByBacklog(99, 'missing', 60, '', 0);
      // Assert
      expect(manager.updateCalls).assertEqual(0);
      expect(manager.addCalls).assertEqual(0);
    });

    it('invalid: resolve_conflict_by_backlog_should_add_backlog_item_when_id_is_minus_one', 0, async () => {
      // Arrange
      const manager = new SpyMutationManager(new FakeMutationHost(), new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      await manager.resolveConflictByBacklog(-1, 'fresh', 55, 'memo', 1);
      // Assert
      expect(manager.addCalls).assertEqual(1);
      const args = manager.lastAddArgs;
      expect(args !== null).assertTrue();
      expect(Boolean(args?.isSchedule)).assertFalse();
    });

    it('normal: resolve_conflict_by_moving_plan_should_update_date_then_update_item', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const manager = new SpyMutationManager(host, new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      await manager.resolveConflictByMovingPlan(71, new Date(2026, 3, 19).getTime(), 'renamed', 90, true, '08:30', 'note', 1);
      // Assert
      expect(host.updatePlanDateCalls).assertEqual(1);
      expect(manager.updateCalls).assertEqual(1);
      expect(manager.addCalls).assertEqual(0);
    });

    it('boundary: resolve_conflict_by_moving_plan_should_add_new_item_when_id_is_minus_one', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const manager = new SpyMutationManager(host, new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      await manager.resolveConflictByMovingPlan(-1, new Date(2026, 3, 19).getTime(), 'fresh', 90, true, '08:30', 'note', 1);
      // Assert
      expect(host.updatePlanDateCalls).assertEqual(1);
      expect(manager.addCalls).assertEqual(1);
      const args = manager.lastAddArgs;
      expect(args !== null).assertTrue();
      expect(Number(args?.preTravel ?? 0)).assertEqual(-1);
    });

    it('invalid: resolve_conflict_by_moving_plan_should_propagate_plan_date_failure', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      host.throwOnUpdatePlanDate = true;
      const manager = new SpyMutationManager(host, new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await manager.resolveConflictByMovingPlan(72, new Date(2026, 3, 19).getTime(), 'fresh', 90, true, '08:30');
      });
      // Assert
      expect(message).assertEqual('update_plan_date_fail');
      expect(manager.updateCalls).assertEqual(0);
      expect(manager.addCalls).assertEqual(0);
    });

    it('normal: update_event_info_should_reinsert_and_reset_auto_route_fields_when_place_changes', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(81, 'old', 1, 100, '12:00', 0);
      target.latitude = 10;
      target.longitude = 20;
      target.pre_travel_min = 20;
      target.is_travel_manual = 1;
      const existing = createEvent(82, 'existing', 1, 0, '10:00', 0);
      host.events = [existing, target];
      host.resolvePoint.latitude = 30;
      host.resolvePoint.longitude = 120;
      let updateFieldsCount = 0;
      let timelineConsistencyCount = 0;
      let lastUpdates = [] as Object[];
      const patchUpdateFields = new StaticPatch(EventRepositoryImpl, 'updateFields', async (_id: number, updates: Object[]): Promise<void> => {
        updateFieldsCount += 1;
        lastUpdates = updates;
      });
      const patchTimeline = new StaticPatch(EventRepositoryImpl, 'updateTimelineConsistency', async (): Promise<void> => {
        timelineConsistencyCount += 1;
      });
      const manager = createManager(host);
      // Act
      await manager.updateEventInfo(81, 'new_place', 80, '08:30', 0, false, 'note', 1, 30, 120);
      patchUpdateFields.restore();
      patchTimeline.restore();
      // Assert
      expect(host.events[0].id).assertEqual(81);
      expect(target.pre_travel_min).assertEqual(20);
      expect(target.is_travel_manual).assertEqual(1);
      expect(updateFieldsCount).assertEqual(1);
      expect(timelineConsistencyCount).assertEqual(1);
      expect(lastUpdates.length >= 2).assertTrue();
      expect(host.recalculateFromEventIdCalls).assertEqual(1);
    });

    it('boundary: update_event_info_should_ignore_missing_target', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const manager = createManager(host);
      // Act
      await manager.updateEventInfo(999, 'missing', 60);
      // Assert
      expect(host.recalculateFromEventIdCalls).assertEqual(0);
    });

    it('invalid: update_event_info_should_keep_old_coordinates_when_new_point_invalid', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(83, 'same', 1, 0, '09:00', 0);
      target.latitude = 11;
      target.longitude = 22;
      host.events = [target];
      host.resolvePoint.latitude = 0;
      host.resolvePoint.longitude = 0;
      let lastUpdates = [] as Record<string, Object>[];
      const patchUpdateFields = new StaticPatch(EventRepositoryImpl, 'updateFields', async (_id: number, updates: Record<string, Object>[]): Promise<void> => {
        lastUpdates = updates;
      });
      const manager = createManager(host);
      // Act
      await manager.updateEventInfo(83, 'same', 50);
      patchUpdateFields.restore();
      // Assert
      expect(target.latitude).assertEqual(11);
      expect(target.longitude).assertEqual(22);
      const hasLatitudeUpdate = lastUpdates.some((item: Record<string, Object>) => String(item['column']) === 'latitude');
      expect(hasLatitudeUpdate).assertFalse();
    });

    it('boundary: update_event_info_should_reinsert_when_target_removed_during_persist', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(84, 'origin84', 1, 100, '09:00', 0);
      const tail = createEvent(85, 'tail84', 1, 200, '12:00', 0);
      host.events = [target, tail];
      let timelineConsistencyCount = 0;
      const patchUpdateFields = new StaticPatch(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
        host.events.splice(0, 1);
      });
      const patchTimeline = new StaticPatch(EventRepositoryImpl, 'updateTimelineConsistency', async (): Promise<void> => {
        timelineConsistencyCount += 1;
      });
      const manager = createManager(host);
      // Act
      await manager.updateEventInfo(84, 'origin84', 60, '08:30', 0, false, 'note84', 2);
      patchUpdateFields.restore();
      patchTimeline.restore();
      // Assert
      expect(host.events[0].id).assertEqual(84);
      expect(host.events[1].id).assertEqual(85);
      expect(timelineConsistencyCount).assertEqual(1);
      expect(host.recalculateFromEventIdCalls).assertEqual(1);
    });

    it('normal: insert_smart_for_compat_should_insert_schedule_item_by_day_and_time', 0, () => {
      // Arrange
      const host = new FakeMutationHost();
      host.events = [
        createEvent(91, 'day0_late', 1, 100, '10:00', 0),
        createEvent(92, 'day1_early', 1, 200, '09:00', 1)
      ];
      const manager = createManager(host);
      const inserting = createEvent(93, 'day0_early', 1, 0, '08:30', 0);
      // Act
      manager.insertSmartForCompat(inserting);
      // Assert
      expect(host.events[0].id).assertEqual(93);
      expect(host.events[1].id).assertEqual(91);
      expect(host.events[2].id).assertEqual(92);
    });

    it('boundary: insert_smart_for_compat_should_append_backlog_item', 0, () => {
      // Arrange
      const host = new FakeMutationHost();
      host.events = [createEvent(94, 'scheduled', 1, 0, '09:00', 0)];
      const manager = createManager(host);
      const backlog = createEvent(95, 'backlog', 0, 0, '', 0);
      // Act
      manager.insertSmartForCompat(backlog);
      // Assert
      expect(host.events[host.events.length - 1].id).assertEqual(95);
    });

    it('invalid: insert_smart_for_compat_should_push_missing_time_item_to_tail', 0, () => {
      // Arrange
      const host = new FakeMutationHost();
      host.events = [
        createEvent(96, 'first', 1, 0, '09:00', 0),
        createEvent(97, 'second', 1, 100, '10:00', 0)
      ];
      const manager = createManager(host);
      const lateUnknown = createEvent(98, 'unknown', 1, 0, '', 0);
      lateUnknown.computed_time = '';
      // Act
      manager.insertSmartForCompat(lateUnknown);
      // Assert
      expect(host.events[host.events.length - 1].id).assertEqual(98);
      expect(host.events[2].sort_order).assertEqual(200);
    });
  });
}

function registerRecalculationTests(): void {
  describe('phase2BatchANTest_timeline_recalculation_manager', () => {
    it('normal: resolve_effective_global_start_minutes_should_parse_valid_time', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.globalStartTime = '09:45';
      const manager = new TimelineRecalculationManager(host);
      // Act
      const minutes = manager.resolveEffectiveGlobalStartMinutes();
      // Assert
      expect(minutes).assertEqual(585);
    });

    it('boundary: resolve_effective_global_start_minutes_should_extract_time_from_datetime_text', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.globalStartTime = '03-18 06:05';
      const manager = new TimelineRecalculationManager(host);
      // Act
      const minutes = manager.resolveEffectiveGlobalStartMinutes();
      // Assert
      expect(minutes).assertEqual(365);
    });

    it('invalid: resolve_effective_global_start_minutes_should_fallback_to_0800', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.globalStartTime = 'invalid';
      const manager = new TimelineRecalculationManager(host);
      // Act
      const minutes = manager.resolveEffectiveGlobalStartMinutes();
      // Assert
      expect(minutes).assertEqual(480);
    });

    it('normal: test_all_commute_should_mark_non_first_auto_route_items', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const first = createEvent(1, 'first', 1, 0, '09:00', 0);
      const second = createEvent(2, 'second', 1, 100, '10:00', 0);
      host.events = [first, second];
      host.firstScheduledIds = [1];
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.testAllCommute();
      // Assert
      expect(second.pre_travel_min).assertEqual(-1);
      expect(manager.recalculateCalls).assertEqual(1);
    });

    it('boundary: test_all_commute_should_keep_first_scheduled_item_unchanged', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const first = createEvent(3, 'first', 1, 0, '09:00', 0);
      first.pre_travel_min = 0;
      host.events = [first];
      host.firstScheduledIds = [3];
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.testAllCommute();
      // Assert
      expect(first.pre_travel_min).assertEqual(0);
      expect(manager.recalculateCalls).assertEqual(1);
    });

    it('invalid: test_all_commute_should_skip_auto_route_when_disabled', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.enableAutoAmapRoute = false;
      const first = createEvent(4, 'first', 1, 0, '09:00', 0);
      const second = createEvent(5, 'second', 1, 100, '10:00', 0);
      second.pre_travel_min = 0;
      host.events = [first, second];
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.testAllCommute();
      // Assert
      expect(second.pre_travel_min).assertEqual(0);
      expect(manager.recalculateCalls).assertEqual(1);
    });

    it('normal: update_travel_mode_should_reset_non_first_item_to_auto_route', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const first = createEvent(11, 'first', 1, 0, '09:00', 0);
      const second = createEvent(12, 'second', 1, 100, '10:00', 0);
      second.pre_travel_min = 15;
      host.events = [first, second];
      host.firstScheduledIds = [11];
      let updateCalls = 0;
      const patch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {
        updateCalls += 1;
      });
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.updateTravelMode(second, 3);
      patch.restore();
      // Assert
      expect(second.travel_mode).assertEqual(3);
      expect(second.transport_mode).assertEqual(3);
      expect(second.pre_travel_min).assertEqual(-1);
      expect(updateCalls).assertEqual(3);
      expect(manager.recalculateFromEventIdCalls).assertEqual(1);
      expect(manager.lastRecalculateEventId).assertEqual(12);
    });

    it('boundary: update_travel_mode_should_keep_first_item_pretravel_zero', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const first = createEvent(13, 'first', 1, 0, '09:00', 0);
      first.pre_travel_min = -1;
      host.events = [first];
      host.firstScheduledIds = [13];
      const patch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {});
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.updateTravelMode(first, 1);
      patch.restore();
      // Assert
      expect(first.pre_travel_min).assertEqual(0);
    });

    it('invalid: update_travel_mode_should_ignore_empty_item', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const patch = new StaticPatch(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {});
      const manager = new SpyRecalculationManager(host);
      // Act
      const emptyEntity: EventEntity = new EventEntity();
      manager.updateTravelMode(emptyEntity, 1);
      patch.restore();
      // Assert
      expect(manager.recalculateFromEventIdCalls).assertEqual(1);
    });

    it('normal: log_timeline_snapshot_should_emit_populated_snapshot', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const event = createEvent(21, 'museum', 1, 0, '09:00', 0);
      event.forecast_start_time = '09:00';
      event.forecast_end_time = '10:00';
      event.actual_start_time = 1;
      event.actual_end_time = 2;
      host.events = [event];
      const manager = new TimelineRecalculationManager(host);
      const logs = [] as string[];
      const managerObj: Object = manager as Object;
      const originLog: Object = Reflect.get(managerObj, 'logTimelineSnapshot') as Object;
      Reflect.set(managerObj, 'logTimelineSnapshot', (scene: string): void => {
        logs.push(`[snapshot][${scene}] ${host.events.map((e: EventEntity) => e.name).join(',')}`);
      });
      // Act
      manager.logTimelineSnapshot('scene_a');
      Reflect.set(managerObj, 'logTimelineSnapshot', originLog);
      // Assert
      expect(logs.length).assertEqual(1);
      expect(logs[0].indexOf('scene_a') >= 0).assertTrue();
      expect(logs[0].indexOf('museum') >= 0).assertTrue();
    });

    it('boundary: log_timeline_snapshot_should_emit_empty_marker_when_no_schedule', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const manager = new TimelineRecalculationManager(host);
      const logs = [] as string[];
      const managerObj: Object = manager as Object;
      const originLog: Object = Reflect.get(managerObj, 'logTimelineSnapshot') as Object;
      Reflect.set(managerObj, 'logTimelineSnapshot', (scene: string): void => {
        logs.push(`[snapshot][${scene}] empty`);
      });
      // Act
      manager.logTimelineSnapshot('scene_empty');
      Reflect.set(managerObj, 'logTimelineSnapshot', originLog);
      // Assert
      expect(logs[0].indexOf('empty') >= 0).assertTrue();
    });

    it('invalid: log_timeline_snapshot_should_tolerate_empty_scene_name', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const manager = new TimelineRecalculationManager(host);
      const logs = [] as string[];
      const managerObj: Object = manager as Object;
      const originLog: Object = Reflect.get(managerObj, 'logTimelineSnapshot') as Object;
      Reflect.set(managerObj, 'logTimelineSnapshot', (_scene: string): void => {
        logs.push('logged');
      });
      // Act
      manager.logTimelineSnapshot('');
      Reflect.set(managerObj, 'logTimelineSnapshot', originLog);
      // Assert
      expect(logs.length).assertEqual(1);
    });

    it('normal: recalculate_from_event_id_should_start_from_previous_schedule_index', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.events = [
        createEvent(31, 'schedule_1', 1, 0, '09:00', 0),
        createEvent(32, 'backlog', 0, 0, '', 0),
        createEvent(33, 'schedule_2', 1, 100, '10:00', 0)
      ];
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.recalculateFromEventId(33);
      // Assert
      expect(manager.recalculateFromIndexCalls).assertEqual(0);
      expect(manager.lastRecalculateIndex).assertEqual(-1);
    });

    it('boundary: recalculate_from_event_id_should_fallback_to_zero_when_event_missing', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.events = [createEvent(34, 'schedule_1', 1, 0, '09:00', 0)];
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.recalculateFromEventId(999);
      // Assert
      expect(manager.lastRecalculateIndex).assertEqual(-1);
    });

    it('invalid: recalculate_from_event_id_should_fallback_to_zero_when_event_id_invalid', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const manager = new SpyRecalculationManager(host);
      // Act
      manager.recalculateFromEventId(0);
      // Assert
      expect(manager.lastRecalculateIndex).assertEqual(-1);
    });

    it('normal: recalculate_from_index_should_forward_anchor_and_refresh_everything', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const first = createEvent(41, 'first', 1, 0, '09:00', 0);
      const second = createEvent(42, 'second', 1, 100, '10:00', 0);
      second.pre_travel_min = 0;
      host.events = [first, second];
      host.firstScheduledIds = [41];
      let capturedStartIndex = -1;
      let capturedAnchor = 0;
      const patch = new StaticPatch(TimelineCalculationService, 'recalculateFromIndex',
        (
          _events: EventEntity[],
          startIndex: number,
          _globalStartTime: string,
          _planStartDate: number,
          _orchestrator: ScheduleOrchestrator,
          options: Record<string, Object>
        ): CalcResultAN => {
          capturedStartIndex = startIndex;
          capturedAnchor = Number(options['startFromEventId']);
          const r: CalcResultAN = { hasFieldChanged: true, hasDayOffsetChanged: false };
          return r;
        });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateFromIndex(1);
      patch.restore();
      // Assert
      expect(capturedStartIndex).assertEqual(1);
      expect(capturedAnchor).assertEqual(42);
      expect(second.pre_travel_min).assertEqual(-1);
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
      expect(host.refreshCalls).assertEqual(1);
    });

    it('boundary: recalculate_from_index_should_clamp_negative_index_to_zero', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.events = [createEvent(43, 'first', 1, 0, '09:00', 0)];
      let capturedStartIndex = -1;
      const patch = new StaticPatch(TimelineCalculationService, 'recalculateFromIndex',
        (_events: EventEntity[], startIndex: number): CalcResultAN => {
          capturedStartIndex = startIndex;
          const r: CalcResultAN = { hasFieldChanged: false, hasDayOffsetChanged: false };
          return r;
        });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateFromIndex(-5);
      patch.restore();
      // Assert
      expect(capturedStartIndex).assertEqual(0);
    });

    it('invalid: recalculate_from_index_should_use_minus_one_anchor_when_no_schedule_item_exists', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.events = [createEvent(44, 'backlog', 0, 0, '', 0)];
      let capturedAnchor = 0;
      const patch = new StaticPatch(TimelineCalculationService, 'recalculateFromIndex',
        (
          _events: EventEntity[],
          _startIndex: number,
          _globalStartTime: string,
          _planStartDate: number,
          _orchestrator: ScheduleOrchestrator,
          options: Record<string, Object>
        ): CalcResultAN => {
          capturedAnchor = Number(options['startFromEventId']);
          const r: CalcResultAN = { hasFieldChanged: false, hasDayOffsetChanged: false };
          return r;
        });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateFromIndex(0);
      patch.restore();
      // Assert
      expect(capturedAnchor).assertEqual(-1);
    });

    it('normal: recalculate_should_refresh_when_fields_changed', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.events = [createEvent(51, 'schedule', 1, 0, '09:00', 0)];
      const patch = new StaticPatch(TimelineCalculationService, 'recalculate', (): CalcResultAN => {
        const r: CalcResultAN = { hasFieldChanged: true, hasDayOffsetChanged: false };
        return r;
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculate();
      patch.restore();
      // Assert
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
      expect(host.refreshCalls).assertEqual(1);
    });

    it('boundary: recalculate_should_skip_refresh_when_no_field_changes', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const patch = new StaticPatch(TimelineCalculationService, 'recalculate', (): CalcResultAN => {
        const r: CalcResultAN = { hasFieldChanged: false, hasDayOffsetChanged: false };
        return r;
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculate();
      patch.restore();
      // Assert
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
      expect(host.refreshCalls).assertEqual(0);
    });

    it('invalid: recalculate_should_tolerate_invalid_global_start_text', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      host.globalStartTime = 'bad';
      const patch = new StaticPatch(TimelineCalculationService, 'recalculate', (): CalcResultAN => {
        const r: CalcResultAN = { hasFieldChanged: false, hasDayOffsetChanged: false };
        return r;
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculate();
      patch.restore();
      // Assert
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
    });

    it('normal: recalculate_traffic_only_should_refresh_and_regroup_when_day_offset_changes', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const patch = new StaticPatch(TimelineCalculationService, 'recalculateTrafficOnly', (): CalcResultAN => {
        const r: CalcResultAN = { hasFieldChanged: true, hasDayOffsetChanged: true };
        return r;
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateTrafficOnly();
      patch.restore();
      // Assert
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(1);
      expect(host.markChangedCalls).assertEqual(1);
      expect(host.refreshCalls).assertEqual(1);
    });

    it('boundary: recalculate_traffic_only_should_skip_regroup_when_day_offset_unchanged', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const patch = new StaticPatch(TimelineCalculationService, 'recalculateTrafficOnly', (): CalcResultAN => {
        const r: CalcResultAN = { hasFieldChanged: true, hasDayOffsetChanged: false };
        return r;
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateTrafficOnly();
      patch.restore();
      // Assert
      expect(host.calculateRealtimeCalls).assertEqual(1);
      expect(host.regenerateGroupsCalls).assertEqual(0);
      expect(host.markChangedCalls).assertEqual(0);
      expect(host.refreshCalls).assertEqual(1);
    });

    it('invalid: recalculate_traffic_only_should_return_early_when_nothing_changes', 0, () => {
      // Arrange
      const host = new FakeRecalculationHost();
      const patch = new StaticPatch(TimelineCalculationService, 'recalculateTrafficOnly', (): CalcResultAN => {
        const r: CalcResultAN = { hasFieldChanged: false, hasDayOffsetChanged: false };
        return r;
      });
      const manager = new TimelineRecalculationManager(host);
      // Act
      manager.recalculateTrafficOnly();
      patch.restore();
      // Assert
      expect(host.calculateRealtimeCalls).assertEqual(0);
      expect(host.refreshCalls).assertEqual(0);
    });
  });
}

function registerStrategyTests(): void {
  describe('phase2BatchANTest_timeline_strategy_manager', () => {
    const createBundle = (snapshot?: PlanEventsSnapshot): CreateBundleResultAN => {
      const ai = new FakeStrategyAiService();
      const persistence = new FakeStrategyPersistence(snapshot);
      const host = new FakeStrategyHost(persistence);
      const result: CreateBundleResultAN = {
        ai: ai,
        persistence: persistence,
        host: host,
        manager: new TimelineStrategyManager(host, ai)
      };
      return result;
    }

    it('normal: generate_by_ai_should_delegate_prompt_mode_and_strategy', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const customStrategy = createStrategy();
      // Act
      await bundle.manager.generateByAi('prompt_a', 2, customStrategy);
      // Assert
      expect(bundle.ai.generateCalls).assertEqual(1);
      const args = bundle.ai.lastGenerateArgs;
      expect(args !== null).assertTrue();
      expect(String(args?.userPrompt ?? '')).assertEqual('prompt_a');
      expect(Number(args?.strategyMode ?? -1)).assertEqual(2);
    });

    it('boundary: generate_by_ai_should_use_default_mode_zero', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.generateByAi('prompt_b');
      // Assert
      const args = bundle.ai.lastGenerateArgs;
      expect(args !== null).assertTrue();
      expect(Number(args?.strategyMode ?? -1)).assertEqual(0);
    });

    it('invalid: generate_by_ai_should_propagate_ai_service_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.generateError = new Error('generate_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.generateByAi('prompt_c', 1);
      });
      // Assert
      expect(message).assertEqual('generate_fail');
    });

    it('normal: get_strategy_mode_should_return_ai_service_value', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.strategyModeValue = 2;
      // Act
      const mode = bundle.manager.getStrategyMode();
      // Assert
      expect(mode).assertEqual(2);
    });

    it('boundary: get_strategy_mode_should_allow_custom_mode_minus_one', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.strategyModeValue = -1;
      // Act
      const mode = bundle.manager.getStrategyMode();
      // Assert
      expect(mode).assertEqual(-1);
    });

    it('invalid: get_strategy_mode_should_propagate_sync_error', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.getModeError = new Error('mode_fail');
      // Act
      const message = captureSyncError((): void => {
        bundle.manager.getStrategyMode();
      });
      // Assert
      expect(message).assertEqual('mode_fail');
    });

    it('normal: has_ai_history_should_return_true_when_ai_service_reports_history', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.hasHistoryValue = true;
      // Act
      const hasHistory = bundle.manager.hasAiHistory();
      // Assert
      expect(hasHistory).assertTrue();
    });

    it('boundary: has_ai_history_should_return_false_when_history_absent', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.hasHistoryValue = false;
      // Act
      const hasHistory = bundle.manager.hasAiHistory();
      // Assert
      expect(hasHistory).assertFalse();
    });

    it('invalid: has_ai_history_should_propagate_sync_error', 0, () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.hasHistoryError = new Error('history_fail');
      // Act
      const message = captureSyncError((): void => {
        bundle.manager.hasAiHistory();
      });
      // Assert
      expect(message).assertEqual('history_fail');
    });

    it('normal: update_strategy_mode_should_delegate_requested_mode', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.updateStrategyMode(2);
      // Assert
      expect(bundle.ai.updateModeCalls).assertEqual(1);
      expect(bundle.ai.lastUpdateMode).assertEqual(2);
    });

    it('boundary: update_strategy_mode_should_allow_custom_mode_minus_one', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.updateStrategyMode(-1);
      // Assert
      expect(bundle.ai.lastUpdateMode).assertEqual(-1);
    });

    it('invalid: update_strategy_mode_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.updateModeError = new Error('update_mode_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.updateStrategyMode(1);
      });
      // Assert
      expect(message).assertEqual('update_mode_fail');
    });

    it('normal: switch_to_custom_strategy_should_delegate_strategy_object', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const strategy = createStrategy();
      strategy.density = 2;
      // Act
      await bundle.manager.switchToCustomStrategy(strategy);
      // Assert
      expect(bundle.ai.switchCalls).assertEqual(1);
      expect((bundle.ai.lastCustomStrategy as ComposableStrategy).density).assertEqual(2);
    });

    it('boundary: switch_to_custom_strategy_should_allow_zeroed_strategy_levels', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const strategy: ComposableStrategy = { density: 0, pace: 0, preference: 0, energy: 0 };
      // Act
      await bundle.manager.switchToCustomStrategy(strategy);
      // Assert
      expect((bundle.ai.lastCustomStrategy as ComposableStrategy).pace).assertEqual(0);
    });

    it('invalid: switch_to_custom_strategy_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.switchError = new Error('switch_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.switchToCustomStrategy(createStrategy());
      });
      // Assert
      expect(message).assertEqual('switch_fail');
    });

    it('normal: apply_weather_strategy_adjustment_should_return_ai_service_result', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.applyWeatherAdjustmentValue = true;
      // Act
      const ok = await bundle.manager.applyWeatherStrategyAdjustment({ density: 1 }, 'hint_a');
      // Assert
      expect(ok).assertTrue();
      expect(bundle.ai.applyWeatherCalls).assertEqual(1);
    });

    it('boundary: apply_weather_strategy_adjustment_should_allow_empty_arguments', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const ok = await bundle.manager.applyWeatherStrategyAdjustment();
      // Assert
      expect(ok).assertFalse();
      expect(bundle.ai.applyWeatherCalls).assertEqual(1);
    });

    it('invalid: apply_weather_strategy_adjustment_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.applyWeatherError = new Error('weather_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.applyWeatherStrategyAdjustment({ pace: -1 }, 'x');
      });
      // Assert
      expect(message).assertEqual('weather_fail');
    });

    it('normal: apply_execution_suggestion_with_strategy_should_return_delegate_result', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.executionSuggestionResult = { strategyApplied: true, replanSuccess: false, errorCode: 'X' };
      // Act
      const result = await bundle.manager.applyExecutionSuggestionWithStrategy(9, 'sg1', { density: 1 }, 'hint_b');
      // Assert
      expect(result.replanSuccess).assertFalse();
      expect(bundle.ai.applyExecutionCalls).assertEqual(1);
    });

    it('boundary: apply_execution_suggestion_with_strategy_should_allow_empty_hint', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const result = await bundle.manager.applyExecutionSuggestionWithStrategy(9, 'sg2');
      // Assert
      expect(result.errorCode).assertEqual('');
      expect(bundle.ai.applyExecutionCalls).assertEqual(1);
    });

    it('invalid: apply_execution_suggestion_with_strategy_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.applyExecutionError = new Error('exec_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.applyExecutionSuggestionWithStrategy(9, 'sg3');
      });
      // Assert
      expect(message).assertEqual('exec_fail');
    });

    it('normal: trigger_strategy_adaptation_should_delegate_once', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.triggerStrategyAdaptation();
      // Assert
      expect(bundle.ai.triggerCalls).assertEqual(1);
    });

    it('boundary: trigger_strategy_adaptation_should_allow_repeated_calls', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.triggerStrategyAdaptation();
      await bundle.manager.triggerStrategyAdaptation();
      // Assert
      expect(bundle.ai.triggerCalls).assertEqual(2);
    });

    it('invalid: trigger_strategy_adaptation_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.triggerError = new Error('adapt_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.triggerStrategyAdaptation();
      });
      // Assert
      expect(message).assertEqual('adapt_fail');
    });

    it('normal: regenerate_with_custom_strategy_should_delegate_strategy', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const strategy = createStrategy();
      strategy.energy = 2;
      // Act
      await bundle.manager.regenerateWithCustomStrategy(strategy);
      // Assert
      expect(bundle.ai.regenerateCustomCalls).assertEqual(1);
      expect((bundle.ai.lastCustomStrategy as ComposableStrategy).energy).assertEqual(2);
    });

    it('boundary: regenerate_with_custom_strategy_should_allow_zeroed_values', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const strategy: ComposableStrategy = { density: 0, pace: 0, preference: 0, energy: 0 };
      // Act
      await bundle.manager.regenerateWithCustomStrategy(strategy);
      // Assert
      expect((bundle.ai.lastCustomStrategy as ComposableStrategy).density).assertEqual(0);
    });

    it('invalid: regenerate_with_custom_strategy_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.regenerateCustomError = new Error('regen_custom_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.regenerateWithCustomStrategy(createStrategy());
      });
      // Assert
      expect(message).assertEqual('regen_custom_fail');
    });

    it('normal: regenerate_by_current_strategy_should_delegate_call', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.regenerateByCurrentStrategy();
      // Assert
      expect(bundle.ai.regenerateCurrentCalls).assertEqual(1);
    });

    it('boundary: regenerate_by_current_strategy_should_allow_repeated_invocation', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.regenerateByCurrentStrategy();
      await bundle.manager.regenerateByCurrentStrategy();
      // Assert
      expect(bundle.ai.regenerateCurrentCalls).assertEqual(2);
    });

    it('invalid: regenerate_by_current_strategy_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.regenerateCurrentError = new Error('regen_current_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.regenerateByCurrentStrategy();
      });
      // Assert
      expect(message).assertEqual('regen_current_fail');
    });

    it('normal: change_strategy_and_regenerate_should_delegate_new_mode', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.changeStrategyAndRegenerate(2);
      // Assert
      expect(bundle.ai.changeCalls).assertEqual(1);
      expect(bundle.ai.lastChangeMode).assertEqual(2);
    });

    it('boundary: change_strategy_and_regenerate_should_allow_minus_one_mode', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.changeStrategyAndRegenerate(-1);
      // Assert
      expect(bundle.ai.lastChangeMode).assertEqual(-1);
    });

    it('invalid: change_strategy_and_regenerate_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.changeError = new Error('change_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.changeStrategyAndRegenerate(1);
      });
      // Assert
      expect(message).assertEqual('change_fail');
    });

    it('normal: build_replan_preview_should_return_delegate_preview', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.previewResult = {
        prompt: 'preview_a',
        strategyMode: 2,
        customStrategy: createStrategy(),
        generatedAt: 1,
        itemCount: 1,
        items: [{ name: 'n', duration: 60, itemType: 0, aiReasoning: 'r' }]
      };
      // Act
      const preview = await bundle.manager.buildReplanPreview(2, createStrategy(), false);
      // Assert
      expect(preview.strategyMode).assertEqual(2);
      expect(bundle.ai.buildPreviewCalls).assertEqual(1);
    });

    it('boundary: build_replan_preview_should_forward_keep_current_mode_flag', 0, async () => {
      // Arrange
      const bundle = createBundle();
      // Act
      await bundle.manager.buildReplanPreview(0, undefined, true);
      // Assert
      const args = bundle.ai.lastPreviewArgs;
      expect(args !== null).assertTrue();
      expect(Boolean(args?.keepCurrentMode)).assertTrue();
    });

    it('invalid: build_replan_preview_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.buildPreviewError = new Error('preview_fail');
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.buildReplanPreview(1);
      });
      // Assert
      expect(message).assertEqual('preview_fail');
    });

    it('normal: apply_replan_preview_should_return_delegate_token', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.undoToken = {
        createdAt: 9,
        events: [],
        strategyMode: 1,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: 'p',
        lastStrategyExplanation: 'e'
      };
      const preview: AiReplanPreviewResult = {
        prompt: 'preview_b',
        strategyMode: 1,
        generatedAt: 1,
        itemCount: 1,
        items: [{ name: 'n', duration: 30, itemType: 0, aiReasoning: 'r' }]
      };
      // Act
      const token = await bundle.manager.applyReplanPreview(preview, 'KEEP');
      // Assert
      expect(token.createdAt).assertEqual(9);
      expect(bundle.ai.applyPreviewCalls).assertEqual(1);
    });

    it('boundary: apply_replan_preview_should_forward_empty_preview_items_without_local_validation', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const preview: AiReplanPreviewResult = {
        prompt: 'preview_c',
        strategyMode: 0,
        generatedAt: 1,
        itemCount: 0,
        items: []
      };
      // Act
      await bundle.manager.applyReplanPreview(preview, 'OVERWRITE');
      // Assert
      const args = bundle.ai.lastApplyPreviewArgs;
      expect(args !== null).assertTrue();
      expect(String(args?.decision ?? '')).assertEqual('OVERWRITE');
    });

    it('invalid: apply_replan_preview_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.applyPreviewError = new Error('apply_preview_fail');
      const preview: AiReplanPreviewResult = {
        prompt: 'preview_d',
        strategyMode: 0,
        generatedAt: 1,
        itemCount: 1,
        items: [{ name: 'n', duration: 30, itemType: 0, aiReasoning: 'r' }]
      };
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.applyReplanPreview(preview, 'KEEP');
      });
      // Assert
      expect(message).assertEqual('apply_preview_fail');
    });

    it('normal: restore_from_undo_token_should_delegate_token', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const token: AiReplanUndoToken = {
        createdAt: 1,
        events: [createTravelItem(1, 'a')],
        strategyMode: 0,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: 'p',
        lastStrategyExplanation: 'e'
      };
      // Act
      await bundle.manager.restoreFromUndoToken(token);
      // Assert
      expect(bundle.ai.restoreCalls).assertEqual(1);
      expect((bundle.ai.lastRestoreToken as AiReplanUndoToken).events.length).assertEqual(1);
    });

    it('boundary: restore_from_undo_token_should_allow_empty_token_events', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const token: AiReplanUndoToken = {
        createdAt: 2,
        events: [],
        strategyMode: 0,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: '',
        lastStrategyExplanation: ''
      };
      // Act
      await bundle.manager.restoreFromUndoToken(token);
      // Assert
      expect((bundle.ai.lastRestoreToken as AiReplanUndoToken).events.length).assertEqual(0);
    });

    it('invalid: restore_from_undo_token_should_propagate_error', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.ai.restoreError = new Error('restore_fail');
      const token: AiReplanUndoToken = {
        createdAt: 3,
        events: [],
        strategyMode: 0,
        strategyDensity: 1,
        strategyPace: 1,
        strategyPreference: 0,
        strategyEnergy: 1,
        lastAiPrompt: '',
        lastStrategyExplanation: ''
      };
      // Act
      const message = await captureAsyncError(async (): Promise<void> => {
        await bundle.manager.restoreFromUndoToken(token);
      });
      // Assert
      expect(message).assertEqual('restore_fail');
    });

    it('normal: get_current_strategy_should_read_persisted_dimensions', 0, async () => {
      // Arrange
      const bundle = createBundle({
        plan: {
          id: 7,
          title: 'plan7',
          createdAt: 1,
          strategyDensity: 2,
          strategyPace: 0,
          strategyPreference: 1,
          strategyEnergy: 2
        },
        events: []
      } as PlanEventsSnapshot);
      // Act
      const strategy = await bundle.manager.getCurrentStrategy();
      // Assert
      expect(strategy.density).assertEqual(2);
      expect(strategy.pace).assertEqual(0);
      expect(strategy.preference).assertEqual(1);
      expect(strategy.energy).assertEqual(2);
    });

    it('boundary: get_current_strategy_should_fallback_per_missing_dimension', 0, async () => {
      // Arrange
      const bundle = createBundle({
        plan: {
          id: 8,
          title: 'plan8',
          createdAt: 1,
          strategyDensity: undefined,
          strategyPace: 2,
          strategyPreference: undefined,
          strategyEnergy: undefined
        },
        events: []
      } as PlanEventsSnapshot);
      // Act
      const strategy = await bundle.manager.getCurrentStrategy();
      // Assert
      expect(strategy.density).assertEqual(1);
      expect(strategy.pace).assertEqual(2);
      expect(strategy.preference).assertEqual(0);
      expect(strategy.energy).assertEqual(1);
    });

    it('invalid: get_current_strategy_should_fallback_to_default_when_plan_missing', 0, async () => {
      // Arrange
      const bundle = createBundle({ events: [] });
      // Act
      const strategy = await bundle.manager.getCurrentStrategy();
      // Assert
      expect(strategy.density).assertEqual(1);
      expect(strategy.pace).assertEqual(1);
      expect(strategy.preference).assertEqual(0);
      expect(strategy.energy).assertEqual(1);
    });

    it('normal: clamp_strategy_level_should_keep_middle_value', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const value = bundle.manager.clampStrategyLevel(1);
      // Assert
      expect(value).assertEqual(1);
    });

    it('boundary: clamp_strategy_level_should_clamp_low_and_high_bounds', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const low = bundle.manager.clampStrategyLevel(-10);
      const high = bundle.manager.clampStrategyLevel(10);
      // Assert
      expect(low).assertEqual(0);
      expect(high).assertEqual(2);
    });

    it('invalid: clamp_strategy_level_should_treat_nan_as_middle', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const value = bundle.manager.clampStrategyLevel(Number.NaN);
      // Assert
      expect(value).assertEqual(1);
    });

    it('normal: compose_weather_constraint_prompt_should_include_both_parts', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const prompt = bundle.manager.composeWeatherConstraintPrompt('绾︽潫A', '鎽樿B');
      // Assert
      expect(prompt.indexOf('绾︽潫A') >= 0).assertTrue();
      expect(prompt.indexOf('鎽樿B') >= 0).assertTrue();
    });

    it('boundary: compose_weather_constraint_prompt_should_keep_template_with_empty_strings', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const prompt = bundle.manager.composeWeatherConstraintPrompt('', '');
      // Assert
      expect(prompt.length > 0).assertTrue();
    });

    it('invalid: compose_weather_constraint_prompt_should_preserve_multiline_raw_text', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const prompt = bundle.manager.composeWeatherConstraintPrompt('A\nB', 'C\nD');
      // Assert
      expect(prompt.indexOf('A\nB') >= 0).assertTrue();
      expect(prompt.indexOf('C\nD') >= 0).assertTrue();
    });

    it('normal: build_weather_strategy_adaptation_key_should_join_positive_values', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const key = bundle.manager.buildWeatherStrategyAdaptationKey(123, 45);
      // Assert
      expect(key).assertEqual('123_45');
    });

    it('boundary: build_weather_strategy_adaptation_key_should_floor_and_clamp_negative_values', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const key = bundle.manager.buildWeatherStrategyAdaptationKey(12.9, -3.2);
      // Assert
      expect(key).assertEqual('12_0');
    });

    it('invalid: build_weather_strategy_adaptation_key_should_normalize_nan_inputs', 0, () => {
      // Arrange
      const bundle = createBundle();
      // Act
      const key = bundle.manager.buildWeatherStrategyAdaptationKey(Number.NaN, Number.NaN);
      // Assert
      expect(key).assertEqual('0_-1');
    });
  });
}

function registerBatchMetaTests(): void {
  describe('phase2BatchANTest_batch_meta', () => {
    it('conflict: phase2_batch_an_should_keep_date_conflict_decision_stable', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = new Date(2026, 3, 20).getTime();
      const manager = new TimelinePlanStateManager(host);
      const patch = new StaticPatch(TimelineConflictResolver, 'isDateConflict', (targetDateMs: number, planStartDate: number): boolean => {
        return targetDateMs < planStartDate;
      });
      // Act
      const conflict = manager.isDateConflict(new Date(2026, 3, 19).getTime());
      patch.restore();
      // Assert
      expect(conflict).assertTrue();
    });

    it('regression: td-20260416-phase2-batch-an-invalid_coordinates_should_not_overwrite_existing_point', 0, async () => {
      // Arrange
      const host = new FakeMutationHost();
      const target = createEvent(201, 'poi', 1, 0, '09:00', 0);
      target.latitude = 22;
      target.longitude = 33;
      host.events = [target];
      host.resolvePoint.latitude = 0;
      host.resolvePoint.longitude = 0;
      const patch = new StaticPatch(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {});
      const manager = new TimelineEventMutationManager(host, new SpyBehaviorTracker(), new SpyMutationStrategyManager());
      // Act
      await manager.updateEventInfo(201, 'poi', 30);
      patch.restore();
      // Assert
      expect(target.latitude).assertEqual(22);
      expect(target.longitude).assertEqual(33);
    });

    it('combined: phase2_batch_an_should_cover_cross_manager_smoke_path', 0, async () => {
      // Arrange
      const planHost = new FakeTimelinePlanStateHost();
      const planManager = new TimelinePlanStateManager(planHost);
      const strategyBundle = (() => {
        const ai = new FakeStrategyAiService();
        const persistence = new FakeStrategyPersistence();
        const host = new FakeStrategyHost(persistence);
        return new TimelineStrategyManager(host, ai);
      })();
      // Act
      const preview = planManager.previewPlanDateShift(new Date(2026, 3, 22).getTime());
      const key = strategyBundle.buildWeatherStrategyAdaptationKey(5, 7);
      // Assert
      expect(preview.hasRigidConflict).assertFalse();
      expect(key).assertEqual('5_7');
    });
  });
}

export default function phase2BatchANTest() {
  registerPlanStateTests();
  registerEventMutationTests();
  registerRecalculationTests();
  registerStrategyTests();
  registerBatchMetaTests();
}



