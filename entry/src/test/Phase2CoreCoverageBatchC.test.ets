import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherSuggestionActionPayload,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { TimelineWeatherService, ITimelineWeatherHost } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyData implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceData implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsData implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyData implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 0;
  allowLocationTrigger: boolean = false;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultData {
  success: boolean = true;
  reasonCode?: string = 'gate_ok';
  startFromEventId?: number = 2;
}

class PlanStateTransitionRequestData {
  planId: string = '';
  reason: string = '';
  currentNodeId?: string = '';
  preserveCompletedNodes: boolean = true;
  preserveStartedWindow: boolean = true;
  useWeatherConstraint: boolean = true;
}

class PlanStateMachineMock {
  gateResult: GateResultData = new GateResultData();

  requestSoftReplan(_args: PlanStateTransitionRequestData): GateResultData {
    return this.gateResult;
  }
}

class HostMock implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceData();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsData();
  executionWeatherEnabled: boolean = false;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyData();
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

  planStateMachine: PlanStateMachineMock = new PlanStateMachineMock();

  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];
  skipEventCalls: number = 0;
  markScheduleChangedCalls: number = 0;

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return new StrategyData();
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  findCurrentActiveEvent(): EventEntity | null {
    return this.events.find((item: EventEntity) => item.actual_start_time > 0 && item.actual_end_time <= 0) ?? null;
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
    this.skipEventCalls += 1;
  }

  recalculateFromEventId(eventId: number): void {
    this.recalculateFromEventIdCalls.push(eventId);
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
  }

  markScheduleChanged(): void {
    this.markScheduleChangedCalls += 1;
  }
}

class SpyTimelineWeatherService extends TimelineWeatherService {
  throwOnApplySuggestion: boolean = false;
  forceApplySuggestionResult: boolean | null = null;

  reorderResults: boolean[] = [];
  shortenResults: boolean[] = [];
  skipResults: boolean[] = [];

  reorderCalls: number = 0;
  shortenCalls: number = 0;
  skipCalls: number = 0;

  public async applySuggestionAction(suggestion: WeatherSuggestion): Promise<boolean> {
    if (this.throwOnApplySuggestion) {
      throw new Error('mock_error');
    }
    if (this.forceApplySuggestionResult !== null) {
      return this.forceApplySuggestionResult;
    }
    return await super.applySuggestionAction(suggestion);
  }

  public async applySoftReorder(orderNodeIds: string[]): Promise<boolean> {
    this.reorderCalls += 1;
    if (this.reorderResults.length > 0) {
      return this.reorderResults.shift() === true;
    }
    return await super.applySoftReorder(orderNodeIds);
  }

  public async applySoftShorten(targetIds: number[], suggestedStayMinutes?: number): Promise<boolean> {
    this.shortenCalls += 1;
    if (this.shortenResults.length > 0) {
      return this.shortenResults.shift() === true;
    }
    return await super.applySoftShorten(targetIds, suggestedStayMinutes);
  }

  public async applySoftSkip(targetIds: number[]): Promise<boolean> {
    this.skipCalls += 1;
    if (this.skipResults.length > 0) {
      return this.skipResults.shift() === true;
    }
    return await super.applySoftSkip(targetIds);
  }
}

class ServiceBundle {
  host: HostMock = new HostMock();
  service: SpyTimelineWeatherService = new SpyTimelineWeatherService(
    this.host,
    new WeatherFacade(),
    new WeatherRefreshScheduler()
  );
}

function createBundle(): ServiceBundle {
  return new ServiceBundle();
}

function createEvent(id: number, sortOrder: number, immutable: boolean = false): EventEntity {
  const item = new EventEntity(`event_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = sortOrder;
  item.duration = 90;
  item.completion_status = EventEntity.STATE_PENDING;
  if (immutable) {
    item.lock_status = 1;
    item.fixed_start_time = '09:30';
  }
  return item;
}

function createSuggestion(
  suggestionId: string,
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE',
  payload?: WeatherSuggestionActionPayload
): WeatherSuggestion {
  return {
    suggestionId: suggestionId,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title_${suggestionId}`,
    message: `message_${suggestionId}`,
    relatedNodeIds: payload?.targetNodeIds ?? [],
    createdAt: Date.now(),
    reason: 'reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: `cool_${suggestionId}`,
    expiresAt: Date.now() + 60000,
    actionPayload: payload
  };
}

export default function phase2CoreCoverageBatchCTest() {
  describe('phase2CoreCoverageBatchCTest', () => {
    it('normal: timeline_weather_service_request_soft_replan_preview_should_succeed_with_valid_gate', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.host.events = [createEvent(1, 100), createEvent(2, 200)];
      const suggestion = createSuggestion('preview_1', 'SHORTEN_STAY', {
        targetNodeIds: ['2'],
        suggestedStayMinutes: 35
      });
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      // Act
      const result = await bundle.service.requestSoftReplan(bundle.host.planId, suggestion.suggestionId, 'PREVIEW');
      // Assert
      expect(result.success).assertTrue();
      expect(result.errorCode).assertEqual('');
      expect(result.preview.suggestionId).assertEqual('preview_1');
      expect(result.preview.actionType).assertEqual('SHORTEN_STAY');
      expect(bundle.host.executionReplanBusy).assertFalse();
      expect(bundle.host.executionWeatherApplying).assertFalse();
    });

    it('boundary: timeline_weather_service_request_soft_replan_should_block_invalid_status_or_busy', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const suggestion = createSuggestion('guard_1', 'NONE');
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      bundle.host.executionWeatherSuggestions = [suggestion];
      // Act
      const invalidInput = await bundle.service.requestSoftReplan(0, suggestion.suggestionId, 'APPLY');

      bundle.host.currentPlanStatus = PlanStatus.DRAFT;
      const statusBlocked = await bundle.service.requestSoftReplan(bundle.host.planId, suggestion.suggestionId, 'APPLY');

      bundle.host.currentPlanStatus = PlanStatus.READY;
      bundle.host.executionReplanBusy = true;
      const busyBlocked = await bundle.service.requestSoftReplan(bundle.host.planId, suggestion.suggestionId, 'APPLY');
      // Assert
      expect(invalidInput.success).assertFalse();
      expect(invalidInput.reasonCode).assertEqual('invalid_input');
      expect(statusBlocked.reasonCode).assertEqual('status_blocked');
      expect(busyBlocked.errorCode).assertEqual('REPLAN_BUSY');
      expect(busyBlocked.reasonCode).assertEqual('busy');
    });

    it('invalid: timeline_weather_service_request_soft_replan_should_handle_gate_fail_and_missing_suggestion', 0, async () => {
      // Arrange
      const bundle = createBundle();
      const suggestion = createSuggestion('gate_1', 'NONE');
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      bundle.host.executionWeatherSuggestions = [suggestion];
      // Act
      bundle.host.planStateMachine.gateResult = {
        success: false,
        reasonCode: 'gate_denied',
        startFromEventId: 0
      };
      const gateFail = await bundle.service.requestSoftReplan(bundle.host.planId, suggestion.suggestionId, 'APPLY');

      bundle.host.planStateMachine.gateResult = {
        success: true,
        reasonCode: 'gate_ok',
        startFromEventId: 2
      };
      bundle.host.executionSuggestionMap.clear();
      const missingSuggestion = await bundle.service.requestSoftReplan(bundle.host.planId, suggestion.suggestionId, 'APPLY');
      // Assert
      expect(gateFail.success).assertFalse();
      expect(gateFail.reasonCode).assertEqual('gate_denied');
      expect(missingSuggestion.success).assertFalse();
      expect(missingSuggestion.reasonCode).assertEqual('suggestion_missing');
    });

    it('conflict: timeline_weather_service_request_soft_replan_should_cover_immutable_apply_fail_and_exception_paths', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.host.events = [createEvent(1, 100), createEvent(2, 200, true), createEvent(3, 300)];

      const immutableSuggestion = createSuggestion('immut_1', 'SHORTEN_STAY', {
        targetNodeIds: ['2'],
        suggestedStayMinutes: 30
      });
      bundle.host.executionSuggestionMap.set(immutableSuggestion.suggestionId, immutableSuggestion);
      bundle.host.executionWeatherSuggestions = [immutableSuggestion];

      const applyFailSuggestion = createSuggestion('apply_fail_1', 'REORDER', {
        targetNodeIds: ['1'],
        targetOrderNodeIds: ['1']
      });

      const exceptionSuggestion = createSuggestion('exception_1', 'NONE');
      // Act
      const immutableBlocked = await bundle.service.requestSoftReplan(bundle.host.planId, immutableSuggestion.suggestionId, 'APPLY');

      bundle.host.executionSuggestionMap.clear();
      bundle.host.executionWeatherSuggestions = [applyFailSuggestion];
      bundle.host.executionSuggestionMap.set(applyFailSuggestion.suggestionId, applyFailSuggestion);
      const applyFailed = await bundle.service.requestSoftReplan(bundle.host.planId, applyFailSuggestion.suggestionId, 'APPLY');

      bundle.host.executionSuggestionMap.clear();
      bundle.host.executionWeatherSuggestions = [exceptionSuggestion];
      bundle.host.executionSuggestionMap.set(exceptionSuggestion.suggestionId, exceptionSuggestion);
      bundle.service.throwOnApplySuggestion = true;
      const exceptionFailed = await bundle.service.requestSoftReplan(bundle.host.planId, exceptionSuggestion.suggestionId, 'APPLY');
      // Assert
      expect(immutableBlocked.errorCode).assertEqual('REPLAN_IMMUTABLE');
      expect(immutableBlocked.reasonCode).assertEqual('immutable_blocked');
      expect(applyFailed.errorCode).assertEqual('REPLAN_CONFLICT');
      expect(applyFailed.reasonCode).assertEqual('apply_failed');
      expect(applyFailed.rolledBack).assertTrue();
      expect(exceptionFailed.errorCode).assertEqual('REPLAN_CONFLICT');
      expect(exceptionFailed.reasonCode).assertEqual('exception');
      expect(exceptionFailed.rolledBack).assertTrue();
      expect(bundle.host.executionReplanBusy).assertFalse();
      expect(bundle.host.executionWeatherApplying).assertFalse();
    });

    it('regression: td-20260413-phase2-soft-replan-future-candidates_should_follow_active_event_window', 0, () => {
      // Arrange
      const bundle = createBundle();
      const e1 = createEvent(1, 100);
      const e2 = createEvent(2, 200);
      const e3 = createEvent(3, 300);
      const e4 = createEvent(4, 400);
      e2.actual_start_time = Date.now() - 1000;
      e2.actual_end_time = 0;
      bundle.host.events = [e1, e2, e3, e4];
      // Act
      const future = bundle.service.getSoftReplanFutureCandidates();
      const startId = bundle.service.resolveSoftReplanStartEventId({
        suggestionId: 'preview',
        actionType: 'REORDER',
        changedOrder: true,
        changedDurations: false,
        skippedNodeIds: [],
        affectedNodeIds: ['4', '3'],
        reasonCode: 'ok',
        startFromEventId: 0,
        changeSummary: [],
        summary: 'summary',
        riskDelta: -10
      });
      // Assert
      expect(future.length).assertEqual(2);
      expect(future[0].id).assertEqual(3);
      expect(future[1].id).assertEqual(4);
      expect(startId).assertEqual(3);
    });

    it('combined: timeline_weather_service_apply_suggestion_action_should_dispatch_and_fallback_correctly', 0, async () => {
      // Arrange
      const bundle = createBundle();
      bundle.host.events = [createEvent(1, 100), createEvent(2, 200), createEvent(3, 300)];
      bundle.service.reorderResults = [true, true, false];
      bundle.service.shortenResults = [true, true];
      bundle.service.skipResults = [true];
      // Act
      const reorderOk = await bundle.service.applySuggestionAction(createSuggestion('dispatch_reorder', 'REORDER', {
        targetNodeIds: ['1', '2'],
        targetOrderNodeIds: ['1', '2']
      }));

      const shortenOk = await bundle.service.applySuggestionAction(createSuggestion('dispatch_shorten', 'SHORTEN_STAY', {
        targetNodeIds: ['2'],
        suggestedStayMinutes: 30
      }));

      const skipOk = await bundle.service.applySuggestionAction(createSuggestion('dispatch_skip', 'SKIP_NODE', {
        targetNodeIds: ['3']
      }));

      const replaceOk = await bundle.service.applySuggestionAction(createSuggestion('dispatch_replace', 'REPLACE_NODE', {
        targetNodeIds: ['1'],
        targetOrderNodeIds: ['1', '2'],
        suggestedStayMinutes: 40
      }));

      const replaceFallbackOk = await bundle.service.applySuggestionAction(createSuggestion('dispatch_replace_fb', 'REPLACE_NODE', {
        targetNodeIds: ['2'],
        targetOrderNodeIds: ['2', '3'],
        suggestedStayMinutes: 25
      }));

      const targetEmptyFail = await bundle.service.applySuggestionAction(createSuggestion('dispatch_empty', 'REORDER', {
        targetNodeIds: [],
        targetOrderNodeIds: []
      }));
      // Assert
      expect(reorderOk).assertTrue();
      expect(shortenOk).assertTrue();
      expect(skipOk).assertTrue();
      expect(replaceOk).assertTrue();
      expect(replaceFallbackOk).assertTrue();
      expect(targetEmptyFail).assertFalse();
      expect(bundle.service.reorderCalls).assertEqual(3);
      expect(bundle.service.shortenCalls).assertEqual(2);
      expect(bundle.service.skipCalls).assertEqual(1);
    });
  });
}
