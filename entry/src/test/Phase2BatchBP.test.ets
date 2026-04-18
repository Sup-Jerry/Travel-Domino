import { describe, expect, it } from '@ohos/hypium';
import {
  ITimelineExecutionHost,
  ReflowHint,
  TimelineExecutionService
} from '../main/ets/domain/timeline/services/TimelineExecutionService';
import {
  ITimelineDistributionHost,
  TimelineDistributionService
} from '../main/ets/domain/timeline/services/TimelineDistributionService';
import {
  AiReplanApplyDecision,
  AiReplanPreviewResult,
  ITimelineAiHost,
  TimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import {
  ITimelineCompressionHost,
  TimelineCompressionService
} from '../main/ets/domain/timeline/services/TimelineCompressionService';
import {
  ITimelineWeatherHost,
  TimelineWeatherService
} from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  SoftReplanApplyResult,
  SoftReplanMode,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { PlanPersistenceFacade } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { AdaptationPrompt } from '../main/ets/domain/strategy/StrategyAdaptationEngine';
import { AiService, AiRawItem } from '../main/ets/infrastructure/services/AiService';
import { TimelineDatePolicy } from '../main/ets/domain/policy/TimelineDatePolicy';

class StaticHooksBP {
  private readonly target: Object;
  private readonly originals: Map<string, Object> = new Map<string, Object>();

  constructor(target: Object, keys: string[]) {
    this.target = target;
    for (let i = 0; i < keys.length; i++) {
      this.originals.set(keys[i], Reflect.get(target, keys[i]) as Object);
    }
  }

  set(key: string, value: Object): void {
    Reflect.set(this.target, key, value);
  }

  restore(): void {
    this.originals.forEach((value: Object, key: string) => {
      Reflect.set(this.target, key, value);
    });
  }
}

function createItemBP(id: number, name: string): TravelPlanItem {
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
    source: 0,
    aiReasoning: '',
    delFlag: 0,
    groupId: 0,
    address: '',
    travelMode: 2
  };
}

function createEventBP(id: number, name: string): EventEntity {
  return EventEntity.fromInterface(createItemBP(id, name), 1);
}

class ExecutionPlanStateMachineBP {
  status: PlanStatus = PlanStatus.READY;

  startExecution(_planId: string, _source: TransitionTriggerSource): void {
    this.status = PlanStatus.IN_PROGRESS;
  }

  completeExecution(_planId: string): void {
    this.status = PlanStatus.COMPLETED;
  }

  getPlanStatus(_planId: string): { status: PlanStatus } {
    return { status: this.status };
  }
}

class ReminderFacadeBP {
  calls: number = 0;

  async updateScheduleNotification(
    _title: string,
    _body: string,
    _planId: number,
    _eventId: number,
    _ongoing: boolean
  ): Promise<void> {
    this.calls += 1;
  }
}

class ExecutionHostBP implements ITimelineExecutionHost {
  events: EventEntity[] = [];
  conflictList: EventEntity[] = [];
  planStartDate: number = Date.now();
  isArchived: boolean = false;
  actualTimeMutationInFlight: boolean = false;
  latestReflowHint: ReflowHint | null = null;
  planId: number = 1;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  planStateMachine: ExecutionPlanStateMachineBP = new ExecutionPlanStateMachineBP();
  reminderFacade: ReminderFacadeBP = new ReminderFacadeBP();
  throwOnEnd: boolean = false;

  async applyRuntimeTransition(target: EventEntity, transition: 'START' | 'END' | 'SKIP' | 'REOPEN', timestamp: number): Promise<boolean> {
    if (transition === 'END' && this.throwOnEnd) {
      throw new Error('end_transition_failed_bp');
    }
    if (transition === 'START') {
      target.actual_start_time = timestamp;
      target.completion_status = EventEntity.STATE_PENDING;
      return true;
    }
    if (transition === 'END') {
      target.actual_end_time = timestamp;
      target.completion_status = EventEntity.STATE_COMPLETED;
      return true;
    }
    if (transition === 'SKIP') {
      target.completion_status = EventEntity.STATE_SKIPPED;
      return true;
    }
    if (transition === 'REOPEN') {
      target.completion_status = EventEntity.STATE_PENDING;
      target.actual_start_time = 0;
      target.actual_end_time = 0;
      return true;
    }
    return false;
  }

  recalculateFromEventId(_eventId: number): void {
    return;
  }

  getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.events;
    const idx = source.findIndex((item: EventEntity) => item.id === afterId);
    if (idx >= 0 && idx + 1 < source.length) {
      return source[idx + 1];
    }
    return null;
  }

  buildReflowHint(
    _action: 'start' | 'end' | 'skip',
    _beforeTs: number,
    _afterTs: number,
    _targetName: string,
    _nextName: string
  ): ReflowHint {
    return {
      type: 'reflow',
      minutesDelta: 0,
      message: 'ok',
      updatedAt: Date.now()
    };
  }

  logTimelineSnapshot(_scene: string): void {
    return;
  }

  getPlaceCheckinSummary(_placeName: string): void {
    return;
  }

  evaluatePlanStatusByRuntime(): void {
    return;
  }

  getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.events;
    return source.find((item: EventEntity) => item.actual_start_time > 0 && item.actual_end_time <= 0) ?? null;
  }

  markScheduleChanged(): void {
    return;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events;
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.events;
    return source.findIndex((item: EventEntity) => item.id === eventId);
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }
}

class DistributionHostBP implements ITimelineDistributionHost {
  events: EventEntity[] = [];
  planId: number = 1;
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;
  recalcCalls: number = 0;

  getEffectiveDayOffset(item: EventEntity): number {
    return item.day_offset;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events.filter((item: EventEntity) => item.status === 1);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((item: EventEntity) => item.id === eventId);
  }

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    const sameDay = this.getOrderedScheduleEvents().filter((it: EventEntity) => it.day_offset === item.day_offset);
    return sameDay.length > 0 && sameDay[0].id === item.id;
  }

  _calculateNaturalArrival(_targetIndex: number): number {
    return 0;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalcCalls += 1;
  }

  async updateEventInfo(_id: number, _name: string, _duration: number, _fixedTime?: string, _dayOffset?: number): Promise<void> {
    return;
  }
}

class AiPersistenceBP extends PlanPersistenceFacade {
}

class AiHostBP implements ITimelineAiHost {
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
  persistence: PlanPersistenceFacade = new AiPersistenceBP();
  weatherFacade: WeatherFacade = new WeatherFacade();
  requestSoftReplanArgs: string = '';

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
      density: 1,
      pace: 1,
      preference: 0,
      energy: 1
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

  async requestSoftReplan(planId: number, suggestionId: string, mode: SoftReplanMode): Promise<SoftReplanApplyResult> {
    this.requestSoftReplanArgs = `${planId}-${suggestionId}-${mode}`;
    return {
      success: true,
      rolledBack: false,
      errorCode: '',
      preview: {
        suggestionId: suggestionId,
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

  markScheduleChanged(): void {
    return;
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }
}

class SpyTimelineAiServiceBP extends TimelineAiService {
  previewCalls: string[] = [];
  applyCalls: string[] = [];

  async buildReplanPreview(
    strategyMode: number,
    customStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    this.previewCalls.push(`${strategyMode}-${customStrategy ? 1 : 0}-${keepCurrentMode === true ? 1 : 0}`);
    return {
      prompt: 'bp_preview',
      strategyMode: strategyMode,
      customStrategy: customStrategy,
      generatedAt: Date.now(),
      itemCount: 1,
      items: [{ name: 'n', duration: 60, itemType: 0, aiReasoning: 'r' }]
    };
  }

  async applyReplanPreview(_preview: AiReplanPreviewResult, decision: AiReplanApplyDecision) {
    this.applyCalls.push(decision);
    return {
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
  }
}

class CompressionHostBP implements ITimelineCompressionHost {
  events: EventEntity[] = [];
  planId: number = 1;
  globalStartTime: string = '08:00';

  getMinEventDurationLimit(): number {
    return 20;
  }

  getEffectiveDayOffset(item: EventEntity): number {
    return item.day_offset;
  }

  resolveEffectiveGlobalStartMinutes(): number {
    return 8 * 60;
  }

  recalculateFromEventId(_eventId: number): void {
    return;
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }

  markHasUnsavedPostpone(): void {
    return;
  }
}

class WeatherHostBP implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: WeatherCollabOptions = {};
  executionWeatherEnabled: boolean = true;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  executionWeatherLastTrigger: string = '';
  executionWeatherErrorCode: string = '';
  executionWeatherScore: number = 0;
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
  executionWeatherLocationTriggerCooldownMs: number = 5 * 60_000;
  executionWeatherLastLocationTriggerAt: number = 0;
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = {
    stage: 'PLANNING',
    pollIntervalMs: 60_000,
    allowLocationTrigger: true,
    allowManualBypass: true,
    forceRefreshOnEnter: true
  };
  executionReplanBusy: boolean = false;
  executionWeatherApplying: boolean = false;
  executionWeatherAppliedSummary: string = '';
  executionWeatherLastEmitAt: number = 0;
  executionWeatherLocationDeltaMeters: number = 200;
  executionSuggestionCooldownMs: number = 120_000;
  executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();

  weatherPlanningHint: string = '';
  weatherRouteScore: number = 0;
  weatherCollabSummary: string = '';
  weatherCollabLabel: string = '';
  weatherStrategyHint: string = '';
  weatherLastRefreshAt: number = 0;

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'EXECUTION';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return {
      density: 1,
      pace: 1,
      preference: 0,
      energy: 1
    };
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  findCurrentActiveEvent(): EventEntity | null {
    return this.events.find((item: EventEntity) => item.actual_start_time > 0 && item.actual_end_time <= 0) ?? null;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events.filter((item: EventEntity) => item.status === 1);
  }

  getMinEventDurationLimit(): number {
    return 20;
  }

  async skipEvent(_item: EventEntity): Promise<void> {
    return;
  }

  planStateMachine = {
    requestSoftReplan: (_args: Object): { success: boolean; reasonCode?: string; startFromEventId?: number } => {
      return { success: true };
    }
  };

  recalculateFromEventId(_eventId: number): void {
    return;
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }

  markScheduleChanged(): void {
    return;
  }
}

function createSuggestionBP(
  id: string,
  level: 'INFO' | 'NOTICE' | 'WARNING',
  createdAt: number,
  expiresAt: number = 0,
  cooldownKey: string = ''
): WeatherSuggestion {
  return {
    suggestionId: id,
    level: level,
    triggerType: 'HEAT',
    actionType: 'REORDER',
    title: 'title',
    message: `${id}_message`,
    relatedNodeIds: ['1'],
    createdAt: createdAt,
    reason: 'reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: cooldownKey || id,
    expiresAt: expiresAt,
    actionPayload: {
      targetNodeIds: ['1']
    }
  };
}

export default function phase2BatchBPTest() {
  describe('phase2BatchBP_targeted_gap_suite', () => {
    it('normal: execution_service_should_return_false_when_reopen_target_not_skipped', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new ExecutionHostBP();
      const event = createEventBP(1, 'bp_reopen_non_skipped');
      event.completion_status = EventEntity.STATE_PENDING;
      host.events = [event];

      const result = await new TimelineExecutionService(host).reopenSkippedEvent(1);

      expect(result).assertFalse();
    });

    it('invalid: execution_service_should_reject_archived_reopen', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new ExecutionHostBP();
      host.isArchived = true;
      const event = createEventBP(2, 'bp_archived_reopen');
      event.completion_status = EventEntity.STATE_SKIPPED;
      host.events = [event];

      const result = await new TimelineExecutionService(host).reopenSkippedEvent(2);

      expect(result).assertFalse();
    });

    it('regression: execution_service_should_reset_inflight_when_end_transition_throws', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new ExecutionHostBP();
      const event = createEventBP(3, 'bp_end_throw');
      event.completion_status = EventEntity.STATE_PENDING;
      host.events = [event];
      host.throwOnEnd = true;

      const result = await new TimelineExecutionService(host).updateActualTime(3, 'actual_end_time', Date.now());

      expect(result).assertFalse();
      expect(host.actualTimeMutationInFlight).assertFalse();
    });

    it('boundary: execution_service_should_format_cross_day_forecast_with_plus_day_prefix', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new ExecutionHostBP();
      host.planStartDate = Date.now();
      const base = TimelineDatePolicy.toDayStartMs(host.planStartDate);
      const first = createEventBP(4, 'bp_cross_day_anchor');
      first.actual_start_time = base + 2 * 86_400_000;
      first.duration = 30;
      const second = createEventBP(5, 'bp_cross_day_follow');
      second.duration = 30;
      host.events = [first, second];

      new TimelineExecutionService(host).calculateRealtimeSchedule();

      expect(first.forecast_start_time.indexOf('+2澶?')).assertEqual(0);
    });

    it('boundary: distribution_service_should_filter_gaps_by_threshold_and_same_day', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new DistributionHostBP();
      const e1 = createEventBP(11, 'bp_day0_first');
      const e2 = createEventBP(12, 'bp_day0_gap_small');
      const e3 = createEventBP(13, 'bp_day0_gap_valid');
      const e4 = createEventBP(14, 'bp_day1_gap');
      e1.day_offset = 0;
      e2.day_offset = 0;
      e3.day_offset = 0;
      e4.day_offset = 1;
      e2.has_gap = true;
      e2.gap_minutes = 19;
      e3.has_gap = true;
      e3.gap_minutes = 35;
      e4.has_gap = true;
      e4.gap_minutes = 50;
      host.events = [e1, e2, e3, e4];

      const gaps = new TimelineDistributionService(host).getSortedGaps();

      expect(gaps.length).assertEqual(1);
      expect(gaps[0].id).assertEqual(13);
    });

    it('invalid: distribution_service_should_skip_auto_distribution_when_no_unlocked_candidate', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new DistributionHostBP();
      const locked = createEventBP(21, 'bp_locked_prev');
      locked.lock_status = 1;
      const target = createEventBP(22, 'bp_gap_target');
      target.has_gap = true;
      target.gap_minutes = 40;
      host.events = [locked, target];

      await new TimelineDistributionService(host).resolveGapByDistribution(target);

      expect(host.recalcCalls).assertEqual(0);
    });

    it('normal: distribution_service_should_ignore_invalid_entries_during_apply', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new DistributionHostBP();
      const a = createEventBP(31, 'bp_apply_a');
      const b = createEventBP(32, 'bp_apply_b');
      b.duration = 239;
      host.events = [a, b];
      const map = new Map<number, number>();
      map.set(999, 10);
      map.set(31, -5);
      map.set(32, 3);

      await new TimelineDistributionService(host).applyDistribution(map);

      expect(a.duration).assertEqual(60);
      expect(b.duration).assertEqual(240);
      expect(host.recalcCalls).assertEqual(1);
    });

    it('normal: ai_service_should_delegate_regenerate_with_custom_strategy', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AiHostBP();
      const service = new SpyTimelineAiServiceBP(host);

      await service.regenerateWithCustomStrategy({ density: 2, pace: 0, preference: 1, energy: 2 });

      expect(service.previewCalls.length).assertEqual(1);
      expect(service.previewCalls[0]).assertEqual('-1-1-0');
      expect(service.applyCalls[0]).assertEqual('OVERWRITE');
    });

    it('normal: ai_service_should_delegate_change_strategy_and_regenerate_with_mode', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AiHostBP();
      const service = new SpyTimelineAiServiceBP(host);

      await service.changeStrategyAndRegenerate(2);

      expect(service.previewCalls.length).assertEqual(1);
      expect(service.previewCalls[0]).assertEqual('2-0-0');
      expect(service.applyCalls[0]).assertEqual('OVERWRITE');
    });

    it('normal: ai_service_should_proxy_apply_weather_suggestion_to_host', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AiHostBP();
      const service = new TimelineAiService(host);

      const result = await service.applyWeatherSuggestion('s_bp');

      expect(result.success).assertTrue();
      expect(host.requestSoftReplanArgs).assertEqual('1-s_bp-APPLY');
    });

    it('invalid: ai_service_should_reject_restore_without_token', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AiHostBP();
      const service = new TimelineAiService(host);
      let message = '';

      try {
        await service.restoreFromUndoToken(undefined as unknown as never);
      } catch (error) {
        message = (error as Error).message;
      }

      expect(message.length > 0).assertTrue();
    });

    it('invalid: ai_service_should_reject_restore_while_regenerating', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AiHostBP();
      host.isRegenerating = true;
      const service = new TimelineAiService(host);
      let message = '';

      try {
        await service.restoreFromUndoToken({
          createdAt: Date.now(),
          events: [],
          strategyMode: 0,
          strategyDensity: 1,
          strategyPace: 1,
          strategyPreference: 0,
          strategyEnergy: 1,
          lastAiPrompt: '',
          lastStrategyExplanation: ''
        });
      } catch (error) {
        message = (error as Error).message;
      }

      expect(message.length > 0).assertTrue();
    });

    it('combined: ai_service_should_wrap_non_error_throwable_from_generate', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new StaticHooksBP(AiService, ['generateItineraryWithStrategy']);
      hooks.set('generateItineraryWithStrategy', (_request: Object): Promise<AiRawItem[]> => {
        throw 'bp_non_error_throwable';
      });

      const host = new AiHostBP();
      const service = new TimelineAiService(host);
      let message = '';

      try {
        await service.generateByAi('bp prompt', 0);
      } catch (error) {
        message = (error as Error).message;
      } finally {
        hooks.restore();
      }

      expect(message.indexOf('bp_non_error_throwable') >= 0).assertTrue();
    });

    it('boundary: compression_service_should_reject_non_earlier_advance_time', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new CompressionHostBP();
      const rigid = createEventBP(41, 'bp_rigid');
      rigid.lock_status = 1;
      rigid.fixed_start_time = '09:00';
      const moving = createEventBP(42, 'bp_moving');
      moving.fixed_start_time = '10:00';
      const target = createEventBP(43, 'bp_target');
      target.lock_status = 1;
      target.fixed_start_time = '12:00';
      host.events = [rigid, moving, target];

      const preview = new TimelineCompressionService(host).previewAdvanceAdjust(2, new Set<number>([42]), '10:00', 30);

      expect(preview.valid).assertFalse();
      expect(preview.message.length > 0).assertTrue();
    });

    it('conflict: compression_service_should_reject_advance_that_hits_following_item', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new CompressionHostBP();
      const rigid = createEventBP(51, 'bp_rigid');
      rigid.lock_status = 1;
      rigid.fixed_start_time = '09:00';
      const selected = createEventBP(52, 'bp_selected');
      selected.fixed_start_time = '10:00';
      selected.duration = 120;
      const next = createEventBP(53, 'bp_next_unselected');
      next.fixed_start_time = '11:00';
      const target = createEventBP(54, 'bp_target');
      target.lock_status = 1;
      target.fixed_start_time = '14:00';
      host.events = [rigid, selected, next, target];

      const preview = new TimelineCompressionService(host).previewAdvanceAdjust(3, new Set<number>([52]), '09:30', 20);

      expect(preview.valid).assertFalse();
      expect(preview.message.length > 0).assertTrue();
    });

    it('normal: weather_service_should_return_stable_summary_when_no_structured_changes', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new WeatherHostBP();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const summary = service.buildStructuredReplanSummary(new Map(), new Map(), []);
      const text = service.composeReplanSummaryText({
        suggestionId: 'bp',
        actionType: 'REORDER',
        changedOrder: false,
        changedDurations: false,
        skippedNodeIds: [],
        affectedNodeIds: [],
        changeSummary: [],
        summary: '',
        riskDelta: 0
      }, summary);

      expect(summary.length).assertEqual(1);
      expect(summary[0].type).assertEqual('NO_OP');
      expect(text.length > 0).assertTrue();
    });

    it('boundary: weather_service_should_render_immutable_blocked_summary_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new WeatherHostBP();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const text = service.composeReplanSummaryText({
        suggestionId: 'bp_immutable',
        actionType: 'REORDER',
        changedOrder: false,
        changedDurations: false,
        skippedNodeIds: [],
        affectedNodeIds: ['1'],
        reasonCode: 'immutable_blocked',
        changeSummary: [],
        summary: '',
        riskDelta: 0
      }, []);

      expect(text.length > 0).assertTrue();
    });

    it('normal: weather_service_should_filter_expired_and_cooldown_items_and_sort_by_priority', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new WeatherHostBP();
      host.executionSuggestionCooldownMap.set('cool_keep', Date.now());
      const now = Date.now();
      const s1 = createSuggestionBP('info_old', 'INFO', now - 5000);
      const s2 = createSuggestionBP('warn_new', 'WARNING', now - 1000);
      const s3 = createSuggestionBP('notice_expired', 'NOTICE', now - 3000, now - 1);
      const s4 = createSuggestionBP('notice_cooldown', 'NOTICE', now - 4000, 0, 'cool_keep');
      const s5 = createSuggestionBP('warn_old', 'WARNING', now - 9000);
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());

      const result = service.filterActiveExecutionSuggestions([s1, s2, s3, s4, s5]);

      expect(result.length).assertEqual(3);
      expect(result[0].suggestionId).assertEqual('warn_old');
      expect(result[1].suggestionId).assertEqual('warn_new');
      expect(result[2].suggestionId).assertEqual('info_old');
    });

    it('normal: weather_service_should_emit_heat_reminder_payload_with_strategy_adjustment', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new WeatherHostBP();
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      WeatherReminderStore.clearPayload(host.planId);
      const suggestion = createSuggestionBP('heat_emit_bp', 'WARNING', Date.now());
      suggestion.triggerType = 'HEAT';
      suggestion.actionType = 'REORDER';

      service.applyExecutionSuggestion(suggestion, 'TIMER');

      const payload = WeatherReminderStore.readPayload(host.planId);
      expect(payload !== null).assertTrue();
      expect(payload?.suggestionId).assertEqual('heat_emit_bp');
      expect(payload?.strategyAdjustment?.pace).assertEqual(-1);
      expect(payload?.strategyAdjustment?.energy).assertEqual(-1);
      WeatherReminderStore.clearPayload(host.planId);
    });

    it('boundary: weather_service_should_skip_emit_when_global_emit_interval_not_reached', 0, () => {
      // Arrange
      // Act
      // Assert
      const host = new WeatherHostBP();
      host.executionWeatherLastEmitAt = Date.now();
      const previousEmitAt = host.executionWeatherLastEmitAt;
      const service = new TimelineWeatherService(host, new WeatherFacade(), new WeatherRefreshScheduler());
      const suggestion = createSuggestionBP('emit_blocked_bp', 'NOTICE', Date.now());

      service.applyExecutionSuggestion(suggestion, 'TIMER');

      expect(host.executionWeatherLastEmitAt).assertEqual(previousEmitAt);
      expect(host.executionSuggestionMap.has('emit_blocked_bp')).assertTrue();
    });
  });
}
