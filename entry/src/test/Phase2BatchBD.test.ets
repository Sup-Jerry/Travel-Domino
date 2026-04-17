import { describe, expect, it } from '@ohos/hypium';
import { TimelineExecutionService } from '../main/ets/domain/timeline/services/TimelineExecutionService';
import { TimelineDistributionService } from '../main/ets/domain/timeline/services/TimelineDistributionService';
import { TimelineAiService } from '../main/ets/domain/timeline/services/TimelineAiService';
import { TimelineCompressionService } from '../main/ets/domain/timeline/services/TimelineCompressionService';
import { TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl, PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { AiService } from '../main/ets/infrastructure/services/AiService';
import { PlanPersistenceFacade } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { DEFAULT_WEATHER_USER_PREFERENCE } from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

function createEvent(id: number, name: string, dayOffset: number = 0): EventEntity {
  const item: TravelPlanItem = {
    id, name, duration: 60, type: 'FLOW', preTravelMinutes: 0, sortOrder: id * 100, status: 1,
    lockStatus: 0, fixedStartTime: '', dayOffset, itemType: 0, priority: 1, isTravelManual: 0, source: 0,
    aiReasoning: '', delFlag: 0, groupId: 0, address: '', travelMode: 2
  };
  const e = EventEntity.fromInterface(item, 1);
  e.day_offset = dayOffset;
  e.dynamic_day_offset = dayOffset;
  e.sort_order = id * 100;
  e.completion_status = EventEntity.STATE_PENDING;
  e.computed_time = '09:00';
  return e;
}

export default function phase2BatchBDTest() {
  describe('phase2BatchBDExecution', () => {
    it('normal: should_find_dynamic_active_event', 0, () => {
      const e = createEvent(1, 'a');
      const now = Date.now();
      e.dynamic_start_time = now - 1000;
      e.dynamic_end_time = now + 60000;
      const host = {
        events: [e], conflictList: [], planStartDate: now, isArchived: false, actualTimeMutationInFlight: false,
        latestReflowHint: null, planId: 1, currentPlanStatus: PlanStatus.READY,
        planStateMachine: { startExecution() {}, completeExecution() {}, getPlanStatus() { return { status: PlanStatus.READY }; } },
        reminderFacade: { async updateScheduleNotification() {} },
        async applyRuntimeTransition() { return true; }, recalculateFromEventId() {}, getNextExecutableEvent() { return null; },
        buildReflowHint() { return { type: 'reflow', minutesDelta: 0, message: '', updatedAt: Date.now() }; },
        logTimelineSnapshot() {}, getPlaceCheckinSummary() {}, evaluatePlanStatusByRuntime() {}, getRealActiveEvent() { return null; },
        markScheduleChanged() {}, getOrderedScheduleEvents() { return [e]; }, getOrderedScheduleIndexById() { return 0; }, getCurrentPlanStatus() { return PlanStatus.READY; }
      };
      const service = new TimelineExecutionService(host as Object as never);
      expect(service.findCurrentActiveEvent()?.id ?? 0).assertEqual(1);
    });

    it('boundary: should_set_placeholder_forecast_when_none_started', 0, () => {
      const e1 = createEvent(2, 'a');
      const e2 = createEvent(3, 'b');
      const host = {
        events: [e1, e2], conflictList: [], planStartDate: Date.now(), isArchived: false, actualTimeMutationInFlight: false,
        latestReflowHint: null, planId: 1, currentPlanStatus: PlanStatus.READY,
        planStateMachine: { startExecution() {}, completeExecution() {}, getPlanStatus() { return { status: PlanStatus.READY }; } },
        reminderFacade: { async updateScheduleNotification() {} },
        async applyRuntimeTransition() { return true; }, recalculateFromEventId() {}, getNextExecutableEvent() { return null; },
        buildReflowHint() { return { type: 'reflow', minutesDelta: 0, message: '', updatedAt: Date.now() }; },
        logTimelineSnapshot() {}, getPlaceCheckinSummary() {}, evaluatePlanStatusByRuntime() {}, getRealActiveEvent() { return null; },
        markScheduleChanged() {}, getOrderedScheduleEvents() { return [e1, e2]; }, getOrderedScheduleIndexById() { return 0; }, getCurrentPlanStatus() { return PlanStatus.READY; }
      };
      new TimelineExecutionService(host as Object as never).calculateRealtimeSchedule();
      expect(e1.forecast_start_time).assertEqual('xxxx');
      expect(e2.forecast_end_time).assertEqual('xxxx');
    });
  });

  describe('phase2BatchBDDistribution', () => {
    it('boundary: clamp_should_cap_max_duration', 0, () => {
      expect(TimelineDistributionService.clampDistributionAdd(239, 10)).assertEqual(1);
      expect(TimelineDistributionService.clampDistributionAdd(300, 1)).assertEqual(0);
    });

    it('normal: resolve_gap_sync_should_call_update', 0, () => {
      let calls = 0;
      const service = new TimelineDistributionService({
        events: [], planId: 1, idleGapDetectionEnabled: true, idleGapTriggerMinutes: 20,
        getEffectiveDayOffset(i: EventEntity) { return i.day_offset; }, getOrderedScheduleEvents() { return []; },
        getOrderedScheduleIndexById() { return 0; }, isFirstScheduledItemOfDay() { return false; },
        _calculateNaturalArrival() { return 0; }, recalculateFromIndex() {},
        async updateEventInfo() { calls += 1; }
      } as Object as never);
      const e = createEvent(11, 'gap');
      e.natural_start_time = '10:00';
      service.resolveGapBySync(e);
      expect(calls).assertEqual(1);
    });
  });

  describe('phase2BatchBDAi', () => {
    it('invalid: apply_weather_adjustment_should_return_false_without_adjustment', 0, async () => {
      const persistence = new PlanPersistenceFacade();
      const host = {
        events: [], planId: 1, currentStrategyMode: 0, isRegenerating: false, weatherFeatureEnabled: false,
        weatherUserPreference: DEFAULT_WEATHER_USER_PREFERENCE, weatherCollabOptions: {}, weatherStrategyHint: '',
        strategyAdaptationPrompt: null, behaviorTracker: { getBehaviorContext() { return {} as Object; }, reset() {} },
        persistence, weatherFacade: new WeatherFacade(),
        resolveCurrentWeatherStage() { return 'PLANNING'; }, async applyPlanningWeatherResult() {}, composeWeatherConstraintPrompt(a: string, b: string) { return a + b; },
        async getCurrentStrategy() { return { density: 1, pace: 1, preference: 0, energy: 1 }; }, clampStrategyLevel(v: number) { return v <= 0 ? 0 : (v >= 2 ? 2 : 1); },
        async requestSoftReplan() { return { success: true, rolledBack: false, errorCode: '', preview: { suggestionId: 's', actionType: 'NONE', changedOrder: false, changedDurations: false, skippedNodeIds: [], affectedNodeIds: [], changeSummary: [], summary: 'ok', riskDelta: 0 } }; },
        markScheduleChanged() {}, recalculateFromIndex() {}
      };
      const ok = await new TimelineAiService(host as Object as never).applyWeatherStrategyAdjustment(undefined, 'x');
      expect(ok).assertFalse();
    });

    it('conflict: build_replan_preview_should_fail_on_insufficient_items', 0, async () => {
      const aiHook = Reflect.get(AiService, 'generateItineraryWithStrategy') as Object;
      Reflect.set(AiService, 'generateItineraryWithStrategy', async () => [{ name: 'A', duration: 60, ai_reasoning: 'r', type: 0 }]);
      const plan: PlanItem = { id: 1, title: 'p', createdAt: 1, strategyMode: 0, strategyDensity: 1, strategyPace: 1, strategyPreference: 0, strategyEnergy: 1, lastAiPrompt: '北京三日游', lastStrategyExplanation: '' };
      const persistence = new class extends PlanPersistenceFacade { async getPlanAndEvents() { return { plan, events: [] }; } };
      const host = { events: [], planId: 1, currentStrategyMode: 0, isRegenerating: false, weatherFeatureEnabled: false, weatherUserPreference: DEFAULT_WEATHER_USER_PREFERENCE, weatherCollabOptions: {}, weatherStrategyHint: '', strategyAdaptationPrompt: null, behaviorTracker: { getBehaviorContext() { return {} as Object; }, reset() {} }, persistence, weatherFacade: new WeatherFacade(), resolveCurrentWeatherStage() { return 'PLANNING'; }, async applyPlanningWeatherResult() {}, composeWeatherConstraintPrompt(a: string, b: string) { return a + b; }, async getCurrentStrategy() { return { density: 1, pace: 1, preference: 0, energy: 1 }; }, clampStrategyLevel(v: number) { return v <= 0 ? 0 : (v >= 2 ? 2 : 1); }, async requestSoftReplan() { return { success: true, rolledBack: false, errorCode: '', preview: { suggestionId: 's', actionType: 'NONE', changedOrder: false, changedDurations: false, skippedNodeIds: [], affectedNodeIds: [], changeSummary: [], summary: 'ok', riskDelta: 0 } }; }, markScheduleChanged() {}, recalculateFromIndex() {} };
      let message = '';
      try { await new TimelineAiService(host as Object as never).buildReplanPreview(0); } catch (e) { message = e instanceof Error ? e.message : ''; }
      Reflect.set(AiService, 'generateItineraryWithStrategy', aiHook);
      expect(message.indexOf('数量不足') >= 0).assertTrue();
    });
  });

  describe('phase2BatchBDCompressionAndWeather', () => {
    it('normal: compression_delay_plan_should_return_confirm', 0, () => {
      const a = createEvent(21, 'a');
      const b = createEvent(22, 'b');
      b.pre_travel_min = 15;
      const host = { events: [a, b], planId: 1, globalStartTime: '08:00', getMinEventDurationLimit() { return 20; }, getEffectiveDayOffset(i: EventEntity) { return i.day_offset; }, resolveEffectiveGlobalStartMinutes() { return 8 * 60; }, recalculateFromEventId() {}, recalculateFromIndex() {}, markHasUnsavedPostpone() {} };
      const plan = new TimelineCompressionService(host as Object as never).calculateDelayPlan(1);
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
    });

    it('normal: weather_should_return_display_source', 0, () => {
      const host = {
        events: [], planId: 1, currentStrategyMode: 0, weatherFeatureEnabled: true, weatherLoading: false, weatherUserPreference: DEFAULT_WEATHER_USER_PREFERENCE, weatherCollabOptions: {},
        executionWeatherEnabled: false, executionWeatherLoading: false, currentPlanStatus: PlanStatus.DRAFT, executionWeatherLastTrigger: '', executionWeatherErrorCode: '', executionWeatherScore: -1, executionWeatherRefreshAt: 0,
        executionWeatherCollabSummary: '', executionWeatherCollabBadge: '', executionWeatherDisplaySource: 'NEXT_FALLBACK', executionWeatherCurrentText: '', executionWeatherNextText: '', executionWeatherSuggestions: [],
        executionSuggestionMap: new Map<string, Object>(), executionWeatherHint: '', executionWeatherLevel: 'INFO', executionWeatherLastLocation: null, executionWeatherLocationTriggerCooldownMs: 0, executionWeatherLastLocationTriggerAt: 0, currentWeatherSchedulePolicy: { stage: 'PLANNING', pollIntervalMs: 0, allowLocationTrigger: false, allowManualBypass: true, forceRefreshOnEnter: false }, executionReplanBusy: false, executionWeatherApplying: false, executionWeatherAppliedSummary: '', executionWeatherLastEmitAt: 0, executionWeatherLocationDeltaMeters: 0, executionSuggestionCooldownMs: 0, executionSuggestionCooldownMap: new Map<string, number>(),
        weatherPlanningHint: '', weatherRouteScore: -1, weatherCollabSummary: '', weatherCollabLabel: '', weatherStrategyHint: '', weatherLastRefreshAt: 0,
        resolveCurrentWeatherStage() { return 'PLANNING'; }, async getCurrentStrategy() { return { density: 1, pace: 1, preference: 0, energy: 1 }; }, getCurrentPlanStatus() { return PlanStatus.DRAFT; }, findCurrentActiveEvent() { return null; }, getOrderedScheduleEvents() { return []; }, getMinEventDurationLimit() { return 20; }, async skipEvent() {}, planStateMachine: { requestSoftReplan() { return { success: true, reasonCode: 'ok', startFromEventId: 1 }; } }, recalculateFromEventId() {}, recalculateFromIndex() {}, markScheduleChanged() {}
      };
      const service = new TimelineWeatherService(host as Object as never, new WeatherFacade(), new WeatherRefreshScheduler());
      expect(service.getExecutionWeatherDisplaySource()).assertEqual('NEXT_FALLBACK');
    });
  });
}
