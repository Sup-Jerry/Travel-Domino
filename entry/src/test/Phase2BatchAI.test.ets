import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import { WeatherDomainService } from '../main/ets/domain/services/WeatherDomainService';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  WeatherCollabContext,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherGeoPointRequest, WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import {
  PlanWeatherConsumeInput,
  WeatherReminderCoordinator,
  WeatherReminderSubscriptionHandlers
} from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload, WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';

class FakeWeatherServiceForBatch {
  public batchShouldThrow: boolean = false;
  public weatherByPoint: Map<string, WeatherInfo> = new Map<string, WeatherInfo>();
  public currentInfo: WeatherInfo | null = null;
  public lastBatchPoints: WeatherGeoPointRequest[] = [];
  public geoCallCount: number = 0;

  public async batchGetWeather(points: WeatherGeoPointRequest[]): Promise<Map<string, WeatherInfo>> {
    this.lastBatchPoints = points;
    if (this.batchShouldThrow) {
      throw new Error('batch_failed_phase2');
    }
    const map = new Map<string, WeatherInfo>();
    points.forEach((point: WeatherGeoPointRequest) => {
      const key = AmapWeatherService.toPointKey(point.latitude, point.longitude, point.targetTime ?? 0);
      const info = this.weatherByPoint.get(key);
      if (info) {
        map.set(key, info);
      }
    });
    return map;
  }

  public async getWeatherByGeoPoint(): Promise<WeatherInfo | null> {
    this.geoCallCount += 1;
    return this.currentInfo;
  }

  public toSnapshotByPoint(pointKey: string, info: WeatherInfo) {
    return {
      locationKey: pointKey,
      sourceType: 'PLAN_LOCATION' as const,
      weatherTime: 1700000000000,
      fetchTime: 1700000000000,
      conditionCode: info.condition,
      conditionText: info.condition,
      temperatureCelsius: info.temperature,
      humidity: info.humidity,
      windSpeed: info.windSpeed,
      cityCode: info.cityCode,
      reportTime: info.reportTime
    };
  }
}

class FakeRiskEvaluatorForBatch {
  public scoreByEventId: Map<number, number> = new Map<number, number>();
  public tagsByEventId: Map<number, string[]> = new Map<number, string[]>();
  public routeScore: number = 85;
  public routeTags: string[] = [];

  public evaluateNodeSuitability(event: EventEntity, _snapshot: Object | undefined, _pref: WeatherUserPreference) {
    return {
      score: this.scoreByEventId.get(event.id) ?? 80,
      riskTags: this.tagsByEventId.get(event.id) ?? []
    };
  }

  public evaluateRouteSuitability(_bindings: Object[], _pref: WeatherUserPreference, _collab?: WeatherCollabContext) {
    return {
      routeScore: this.routeScore,
      riskTags: this.routeTags,
      summaryText: 'route_ok_phase2'
    };
  }
}

class FakePolicyResolverForBatch {
  public throwOnResolve: boolean = false;
  public throwOnTargets: boolean = false;

  public resolveWeatherFetchPolicy(status: PlanStatus): Object {
    if (this.throwOnResolve) {
      throw new Error('resolve_policy_failed_phase2');
    }
    return { status: status, mode: 'fake' };
  }

  public buildWeatherTargets(planId: string, status: PlanStatus, events: EventEntity[]): Object {
    if (this.throwOnTargets) {
      throw new Error('build_targets_failed_phase2');
    }
    return { planId: planId, status: status, eventCount: events.length };
  }
}

class FakeContextBuilderForDomain {
  public planningThrow: boolean = false;
  public executionThrow: boolean = false;
  public adjustThrow: boolean = false;
  public promptThrow: boolean = false;
  public lastPlanId: number = 0;
  public lastForceRefresh: boolean = false;
  public planningCalls: number = 0;
  public executionCalls: number = 0;
  public adjustmentCalls: number = 0;
  public promptCalls: number = 0;
  public lastPlanningEventsLength: number = -1;

  public async buildPlanningContext(events: EventEntity[]): Promise<WeatherContextBuildResult> {
    this.planningCalls += 1;
    this.lastPlanningEventsLength = events.length;
    if (this.planningThrow) {
      throw new Error('domain_planning_failed_phase2');
    }
    return {
      context: { stage: 'CONFIRMED', generatedAt: 1, bindings: [], routeSuitability: { routeScore: 90, riskTags: [], summaryText: 'ok' } },
      eventMap: new Map<number, Object>() as Map<number, any>,
      sourceEvents: events
    };
  }

  public async buildExecutionContext(_events: EventEntity[], _loc?: Object, forceRefresh: boolean = false): Promise<WeatherContextBuildResult> {
    this.executionCalls += 1;
    this.lastForceRefresh = forceRefresh;
    if (this.executionThrow) {
      throw new Error('domain_execution_failed_phase2');
    }
    return {
      context: { stage: 'IN_PROGRESS', generatedAt: 2, bindings: [], routeSuitability: { routeScore: 75, riskTags: ['RAIN'], summaryText: 'ok' }, executionRiskScore: 75, executionRiskTags: ['RAIN'], futureNodeWeatherList: [] },
      eventMap: new Map<number, Object>() as Map<number, any>,
      sourceEvents: []
    };
  }

  public buildExecutionAdjustments(planId: number): WeatherSuggestion[] {
    this.adjustmentCalls += 1;
    this.lastPlanId = planId;
    if (this.adjustThrow) {
      throw new Error('domain_adjust_failed_phase2');
    }
    return [];
  }

  public buildPromptSummary(): string {
    this.promptCalls += 1;
    if (this.promptThrow) {
      throw new Error('domain_prompt_failed_phase2');
    }
    return 'prompt_ok_phase2';
  }
}

class FakePlanStateMachineForBatch {
  public status: PlanStatus = PlanStatus.IN_PROGRESS;
  private handler: ((event: { toStatus: PlanStatus }) => void) | null = null;

  public subscribePlanTransition(_planId: string, handler: (event: { toStatus: PlanStatus }) => void): () => void {
    this.handler = handler;
    return () => {};
  }

  public getPlanStatus(_planId: string): { status: PlanStatus } {
    return { status: this.status };
  }

  public emit(toStatus: PlanStatus): void {
    this.handler?.({ toStatus: toStatus });
  }
}

class ReminderStoreHooksForBatch {
  private readonly originRead: Object;
  private readonly originClear: Object;

  constructor() {
    this.originRead = Reflect.get(WeatherReminderStore, 'readPayload') as Object;
    this.originClear = Reflect.get(WeatherReminderStore, 'clearPayload') as Object;
  }

  public setRead(fn: (planId?: number) => WeatherReminderPayload | null): void {
    Reflect.set(WeatherReminderStore, 'readPayload', fn);
  }

  public setClear(fn: (planId?: number) => void): void {
    Reflect.set(WeatherReminderStore, 'clearPayload', fn);
  }

  public restore(): void {
    Reflect.set(WeatherReminderStore, 'readPayload', this.originRead);
    Reflect.set(WeatherReminderStore, 'clearPayload', this.originClear);
  }
}

function createEventForBatch(id: number, status: number = 1, lat: number = 30.1, lng: number = 120.1, sortOrder: number = 0): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  event.status = status;
  event.latitude = lat;
  event.longitude = lng;
  event.sort_order = sortOrder;
  event.dynamic_start_time = 1700000000000 + id * 1000;
  event.completion_status = EventEntity.STATE_PENDING;
  event.duration = 60;
  event.type = 0;
  return event;
}

function createInfoForBatch(condition: string, temp: number = 25): WeatherInfo {
  return { temperature: temp, condition: condition, humidity: 50, windSpeed: 3, reportTime: '2026-04-15', cityCode: '320100' };
}

function createBaseExecutionContextForBatch(tags: string[]): WeatherContext {
  return {
    stage: 'IN_PROGRESS',
    generatedAt: 1700000000999,
    bindings: [],
    routeSuitability: { routeScore: 70, riskTags: tags, summaryText: 'route' },
    executionRiskScore: 70,
    executionRiskTags: tags,
    futureNodeWeatherList: [{ nodeId: '1', eventId: 1, nodeName: 'event_1', suitabilityScore: 70, riskTags: tags }]
  };
}

export default function phase2BatchAITest() {
  describe('phase2BatchAITest_weather_context_builder', () => {
    it('normal: resolve_weather_fetch_policy_should_delegate_to_resolver', 0, () => {
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver as unknown as any);
      const policy = builder.resolveWeatherFetchPolicy(PlanStatus.DRAFT) as Record<string, string>;
      expect(policy.status).assertEqual(PlanStatus.DRAFT);
    });

    it('boundary: resolve_weather_fetch_policy_should_support_terminal_status', 0, () => {
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver as unknown as any);
      const policy = builder.resolveWeatherFetchPolicy(PlanStatus.EXPIRED) as Record<string, string>;
      expect(policy.status).assertEqual(PlanStatus.EXPIRED);
    });

    it('invalid: resolve_weather_fetch_policy_should_throw_when_resolver_fails', 0, () => {
      const policyResolver = new FakePolicyResolverForBatch();
      policyResolver.throwOnResolve = true;
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver as unknown as any);
      let message = '';
      try {
        builder.resolveWeatherFetchPolicy(PlanStatus.READY);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('resolve_policy_failed_phase2');
    });

    it('normal: build_weather_targets_should_delegate_with_plan_and_events', 0, () => {
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver as unknown as any);
      const targets = builder.buildWeatherTargets('plan_a', PlanStatus.CONFIRMED, [createEventForBatch(1), createEventForBatch(2)]) as Record<string, number>;
      expect(targets.eventCount).assertEqual(2);
    });

    it('boundary: build_weather_targets_should_handle_empty_events', 0, () => {
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver as unknown as any);
      const targets = builder.buildWeatherTargets('plan_b', PlanStatus.DRAFT, []) as Record<string, number>;
      expect(targets.eventCount).assertEqual(0);
    });

    it('invalid: build_weather_targets_should_throw_when_resolver_fails', 0, () => {
      const policyResolver = new FakePolicyResolverForBatch();
      policyResolver.throwOnTargets = true;
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver as unknown as any);
      let message = '';
      try {
        builder.buildWeatherTargets('plan_c', PlanStatus.READY, []);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('build_targets_failed_phase2');
    });

    it('normal: refresh_weather_by_status_should_route_ready_to_execution_context', 0, async () => {
      const builder = new WeatherContextBuilder();
      Reflect.set(builder as Object, 'buildWeatherTargets', () => ['target_ready']);
      let capturedStage = '';
      Reflect.set(builder as Object, 'buildExecutionContext', async (_events: EventEntity[], _loc?: Object, _force?: boolean, _pref?: Object, _opt?: Object, stage?: string) => {
        capturedStage = stage ?? '';
        return {
          context: { stage: 'READY', generatedAt: 1700000000003, bindings: [], routeSuitability: { routeScore: 80, riskTags: [], summaryText: '' } },
          eventMap: new Map<number, any>(),
          sourceEvents: []
        };
      });
      const result = await builder.refreshWeatherByStatus('plan_ready', PlanStatus.READY, [createEventForBatch(1)], { lastKnownLatitude: 31.1, lastKnownLongitude: 121.5 } as any, true);
      expect(result.success).assertTrue();
      expect(capturedStage).assertEqual('READY');
    });

    it('boundary: refresh_weather_by_status_should_return_direct_result_for_terminal_status', 0, async () => {
      const builder = new WeatherContextBuilder();
      Reflect.set(builder as Object, 'buildWeatherTargets', () => ['target_terminal']);
      const result = await builder.refreshWeatherByStatus('plan_terminal', PlanStatus.EXPIRED, []);
      expect(result.success).assertTrue();
      expect(result.snapshotVersion.includes('EXPIRED_')).assertTrue();
    });

    it('invalid: refresh_weather_by_status_should_return_degraded_when_context_build_fails', 0, async () => {
      const builder = new WeatherContextBuilder();
      Reflect.set(builder as Object, 'buildWeatherTargets', () => ['target_fail']);
      Reflect.set(builder as Object, 'buildPlanningContext', async () => {
        throw new Error('refresh_planning_failed_phase2');
      });
      const result = await builder.refreshWeatherByStatus('plan_fail', PlanStatus.DRAFT, []);
      expect(result.success).assertFalse();
      expect(result.errorMessage).assertEqual('refresh_planning_failed_phase2');
    });

    it('normal: build_planning_context_should_build_bindings_from_weather_map', 0, async () => {
      const weatherService = new FakeWeatherServiceForBatch();
      const risk = new FakeRiskEvaluatorForBatch();
      risk.scoreByEventId.set(1, 66);
      risk.tagsByEventId.set(1, ['RAIN']);
      const builder = new WeatherContextBuilder(weatherService as unknown as any, risk as unknown as any, new FakePolicyResolverForBatch() as unknown as any);
      const event = createEventForBatch(1, 1, 30.3, 120.3);
      const key = AmapWeatherService.toPointKey(event.latitude, event.longitude, event.dynamic_start_time);
      weatherService.weatherByPoint.set(key, createInfoForBatch('RAIN', 23));
      const result = await builder.buildPlanningContext([event], undefined, { enableMultiDay: true, enableMultiCity: true }, 'CONFIRMED');
      expect(result.context.bindings.length).assertEqual(1);
      expect(result.context.bindings[0].suitabilityScore).assertEqual(66);
    });

    it('boundary: build_planning_context_should_filter_invalid_coordinates_and_status', 0, async () => {
      const weatherService = new FakeWeatherServiceForBatch();
      const builder = new WeatherContextBuilder(weatherService as unknown as any, new FakeRiskEvaluatorForBatch() as unknown as any, new FakePolicyResolverForBatch() as unknown as any);
      const result = await builder.buildPlanningContext([createEventForBatch(2, 0, 30.5, 120.5), createEventForBatch(3, 1, 0, 0)]);
      expect(result.sourceEvents.length).assertEqual(0);
      expect(weatherService.lastBatchPoints.length).assertEqual(0);
    });

    it('invalid: build_planning_context_should_throw_when_batch_query_fails', 0, async () => {
      const weatherService = new FakeWeatherServiceForBatch();
      weatherService.batchShouldThrow = true;
      const builder = new WeatherContextBuilder(weatherService as unknown as any, new FakeRiskEvaluatorForBatch() as unknown as any, new FakePolicyResolverForBatch() as unknown as any);
      let message = '';
      try {
        await builder.buildPlanningContext([createEventForBatch(4)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('batch_failed_phase2');
    });
    it('normal: build_execution_context_should_resolve_current_and_next_weather', 0, async () => {
      const weatherService = new FakeWeatherServiceForBatch();
      const builder = new WeatherContextBuilder(weatherService as unknown as any, new FakeRiskEvaluatorForBatch() as unknown as any, new FakePolicyResolverForBatch() as unknown as any);
      const e1 = createEventForBatch(11, 1, 31.1, 121.1, 100);
      e1.actual_start_time = 1700000000001;
      const e2 = createEventForBatch(12, 1, 31.2, 121.2, 200);
      const e3 = createEventForBatch(13, 1, 31.3, 121.3, 300);
      const e4 = createEventForBatch(14, 1, 31.4, 121.4, 400);
      [e2, e3, e4].forEach((event: EventEntity) => {
        const key = AmapWeatherService.toPointKey(event.latitude, event.longitude, event.dynamic_start_time);
        weatherService.weatherByPoint.set(key, createInfoForBatch('CLOUDY', 26));
      });
      weatherService.currentInfo = createInfoForBatch('SUNNY', 28);
      const result = await builder.buildExecutionContext([e1, e2, e3, e4], { latitude: 32.1, longitude: 118.8 });
      expect(result.sourceEvents.length).assertEqual(3);
      expect(result.context.currentLocationWeather !== undefined).assertTrue();
      expect(weatherService.geoCallCount).assertEqual(1);
    });

    it('boundary: build_execution_context_should_return_empty_when_no_pending_nodes', 0, async () => {
      const weatherService = new FakeWeatherServiceForBatch();
      const builder = new WeatherContextBuilder(weatherService as unknown as any, new FakeRiskEvaluatorForBatch() as unknown as any, new FakePolicyResolverForBatch() as unknown as any);
      const completed = createEventForBatch(21);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const result = await builder.buildExecutionContext([completed], { latitude: 0, longitude: 0 });
      expect(result.sourceEvents.length).assertEqual(0);
      expect(result.context.bindings.length).assertEqual(0);
    });

    it('invalid: build_execution_context_should_throw_when_weather_service_fails', 0, async () => {
      const weatherService = new FakeWeatherServiceForBatch();
      weatherService.batchShouldThrow = true;
      const builder = new WeatherContextBuilder(weatherService as unknown as any, new FakeRiskEvaluatorForBatch() as unknown as any, new FakePolicyResolverForBatch() as unknown as any);
      let message = '';
      try {
        await builder.buildExecutionContext([createEventForBatch(31)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('batch_failed_phase2');
    });

    it('normal: build_execution_suggestions_should_emit_rain_actions', 0, () => {
      const builder = new WeatherContextBuilder();
      const context = createBaseExecutionContextForBatch(['RAIN']);
      context.nextNodeWeather = { locationKey: 'k1', sourceType: 'PLAN_LOCATION', weatherTime: 1, fetchTime: 1, conditionCode: 'RAIN', conditionText: 'RAIN' };
      const suggestions = builder.buildExecutionSuggestions(context);
      expect(suggestions.length).assertEqual(2);
      expect(suggestions[0].actionType).assertEqual('REORDER');
    });

    it('boundary: build_execution_suggestions_should_emit_unknown_replacement', 0, () => {
      const builder = new WeatherContextBuilder();
      const context = createBaseExecutionContextForBatch(['UNKNOWN']);
      context.futureNodeWeatherList = [
        { nodeId: '1', eventId: 1, nodeName: 'a', suitabilityScore: 60, riskTags: ['UNKNOWN'] },
        { nodeId: '2', eventId: 2, nodeName: 'b', suitabilityScore: 90, riskTags: [] }
      ];
      const suggestions = builder.buildExecutionSuggestions(context);
      expect(suggestions.length).assertEqual(1);
      expect(suggestions[0].actionType).assertEqual('REPLACE_NODE');
    });

    it('invalid: build_execution_suggestions_should_return_empty_for_invalid_context', 0, () => {
      const builder = new WeatherContextBuilder();
      const suggestions = builder.buildExecutionSuggestions(undefined as unknown as WeatherContext);
      expect(suggestions.length).assertEqual(0);
    });

    it('normal: build_execution_adjustments_should_emit_severe_skip', 0, () => {
      const builder = new WeatherContextBuilder();
      const event = createEventForBatch(41);
      const context = createBaseExecutionContextForBatch(['SEVERE_ALERT']);
      context.futureNodeWeatherList = [{
        nodeId: '41',
        eventId: 41,
        nodeName: 'event_41',
        suitabilityScore: 40,
        riskTags: ['SEVERE_ALERT'],
        weather: { locationKey: 'k41', sourceType: 'PLAN_LOCATION', weatherTime: 1, fetchTime: 1, conditionCode: 'STORM', conditionText: 'storm' }
      }];
      const suggestions = builder.buildExecutionAdjustments(1, context, [event]);
      expect(suggestions.length > 0).assertTrue();
      expect(suggestions[0].actionType).assertEqual('SKIP_NODE');
    });

    it('boundary: build_execution_adjustments_should_return_empty_when_plan_id_invalid', 0, () => {
      const builder = new WeatherContextBuilder();
      const suggestions = builder.buildExecutionAdjustments(0, createBaseExecutionContextForBatch(['RAIN']), [createEventForBatch(51)]);
      expect(suggestions.length).assertEqual(0);
    });

    it('invalid: build_execution_adjustments_should_return_empty_for_null_context', 0, () => {
      const builder = new WeatherContextBuilder();
      const suggestions = builder.buildExecutionAdjustments(1, undefined as unknown as WeatherContext, [createEventForBatch(52)]);
      expect(suggestions.length).assertEqual(0);
    });

    it('normal: build_prompt_summary_should_include_route_and_preference', 0, () => {
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'CONFIRMED',
        generatedAt: 1,
        bindings: [{
          nodeId: '1', eventId: 1, suitabilityScore: 88, riskTags: ['RAIN'],
          weather: { locationKey: 'k1', sourceType: 'PLAN_LOCATION', weatherTime: 1, fetchTime: 1, conditionCode: 'RAIN', conditionText: '小雨', temperatureCelsius: 22 }
        }],
        routeSuitability: { routeScore: 82, riskTags: ['RAIN'], summaryText: '可执行' }
      };
      const summary = builder.buildPromptSummary(context, DEFAULT_WEATHER_USER_PREFERENCE);
      expect(summary.includes('路线天气分')).assertTrue();
      expect(summary.includes('偏好解释')).assertTrue();
    });

    it('boundary: build_prompt_summary_should_return_fallback_text_when_no_binding', 0, () => {
      const builder = new WeatherContextBuilder();
      const summary = builder.buildPromptSummary({ stage: 'CONFIRMED', generatedAt: 1, bindings: [], routeSuitability: { routeScore: 100, riskTags: [], summaryText: 'ok' } });
      expect(summary.includes('暂无可用天气数据')).assertTrue();
    });

    it('invalid: build_prompt_summary_should_throw_when_route_suitability_missing', 0, () => {
      const builder = new WeatherContextBuilder();
      let message = '';
      try {
        builder.buildPromptSummary({ stage: 'CONFIRMED', generatedAt: 1, bindings: [{ nodeId: '1', eventId: 1, suitabilityScore: 88, riskTags: [] }] } as unknown as WeatherContext);
      } catch (error) {
        message = error instanceof Error ? error.message : 'thrown';
      }
      expect(message.length > 0).assertTrue();
    });
  });

  describe('phase2BatchAITest_weather_domain_service', () => {
    it('normal: build_planning_context_should_delegate_to_context_builder', 0, async () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      const result = await service.buildPlanningContext([createEventForBatch(61)]);
      expect(fakeBuilder.planningCalls).assertEqual(1);
      expect(result.context.stage).assertEqual('CONFIRMED');
    });

    it('boundary: build_planning_context_should_support_empty_events', 0, async () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      await service.buildPlanningContext([]);
      expect(fakeBuilder.lastPlanningEventsLength).assertEqual(0);
    });

    it('invalid: build_planning_context_should_throw_when_builder_fails', 0, async () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.planningThrow = true;
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      let message = '';
      try {
        await service.buildPlanningContext([createEventForBatch(62)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_planning_failed_phase2');
    });
    it('normal: build_execution_context_should_delegate_with_force_refresh', 0, async () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      await service.buildExecutionContext([createEventForBatch(63)], { latitude: 30.1, longitude: 120.1 }, true);
      expect(fakeBuilder.executionCalls).assertEqual(1);
      expect(fakeBuilder.lastForceRefresh).assertTrue();
    });

    it('boundary: build_execution_context_should_allow_default_force_refresh_false', 0, async () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      await service.buildExecutionContext([]);
      expect(fakeBuilder.lastForceRefresh).assertFalse();
    });

    it('invalid: build_execution_context_should_throw_when_builder_fails', 0, async () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.executionThrow = true;
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      let message = '';
      try {
        await service.buildExecutionContext([createEventForBatch(64)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_execution_failed_phase2');
    });

    it('normal: build_execution_adjustments_should_delegate_with_plan_id', 0, () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      service.buildExecutionAdjustments(123, createBaseExecutionContextForBatch(['RAIN']), [createEventForBatch(65)]);
      expect(fakeBuilder.adjustmentCalls).assertEqual(1);
      expect(fakeBuilder.lastPlanId).assertEqual(123);
    });

    it('boundary: build_execution_adjustments_should_support_empty_future_nodes', 0, () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      const suggestions = service.buildExecutionAdjustments(1, createBaseExecutionContextForBatch([]), []);
      expect(suggestions.length).assertEqual(0);
    });

    it('invalid: build_execution_adjustments_should_throw_when_builder_fails', 0, () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.adjustThrow = true;
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      let message = '';
      try {
        service.buildExecutionAdjustments(1, createBaseExecutionContextForBatch([]), []);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_adjust_failed_phase2');
    });

    it('normal: build_prompt_summary_should_delegate_to_builder', 0, () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      const text = service.buildPromptSummary(createBaseExecutionContextForBatch([]));
      expect(text).assertEqual('prompt_ok_phase2');
      expect(fakeBuilder.promptCalls).assertEqual(1);
    });

    it('boundary: build_prompt_summary_should_support_preference_override', 0, () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      const text = service.buildPromptSummary(createBaseExecutionContextForBatch([]), { heatSensitivity: 2, rainSensitivity: 0, weatherRiskTolerance: 1 });
      expect(text).assertEqual('prompt_ok_phase2');
    });

    it('invalid: build_prompt_summary_should_throw_when_builder_fails', 0, () => {
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.promptThrow = true;
      const service = new WeatherDomainService(fakeBuilder as unknown as any);
      let message = '';
      try {
        service.buildPromptSummary(createBaseExecutionContextForBatch([]));
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_prompt_failed_phase2');
    });
  });

  describe('phase2BatchAITest_weather_reminder_coordinator', () => {
    it('normal: get_instance_should_return_singleton', 0, () => {
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      const first = WeatherReminderCoordinator.getInstance();
      const second = WeatherReminderCoordinator.getInstance();
      expect(first === second).assertTrue();
    });

    it('boundary: get_instance_should_create_new_after_reset', 0, () => {
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      const one = WeatherReminderCoordinator.getInstance();
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      const two = WeatherReminderCoordinator.getInstance();
      expect(one === two).assertFalse();
    });

    it('invalid: get_instance_should_return_existing_even_if_polluted', 0, () => {
      const polluted = {} as unknown as WeatherReminderCoordinator;
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', polluted);
      const got = WeatherReminderCoordinator.getInstance();
      expect(got === polluted).assertTrue();
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
    });

    it('normal: subscribe_plan_should_show_payload_on_new_seq', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 1, planId: 101, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      hooks.setClear((): void => {});
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', new FakePlanStateMachineForBatch() as unknown as PlanStateMachine);
      let showCount = 0;
      const handlers: WeatherReminderSubscriptionHandlers = {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; },
        pollIntervalMs: 1000
      };
      const unsubscribe = coordinator.subscribePlan(101, handlers);
      unsubscribe();
      hooks.restore();
      expect(showCount).assertEqual(1);
    });

    it('boundary: subscribe_plan_should_return_noop_for_invalid_plan_id', 0, () => {
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      const unsubscribe = coordinator.subscribePlan(0, { isDialogOpen: (): boolean => false, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      unsubscribe();
      expect(showCount).assertEqual(0);
    });

    it('invalid: subscribe_plan_should_ignore_non_incremental_seq_payload', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      let seq = 1;
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: seq, planId: 202, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      hooks.setClear((): void => {});
      const coordinator = WeatherReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineForBatch();
      Reflect.set(coordinator as Object, 'planStateMachine', machine as unknown as PlanStateMachine);
      let showCount = 0;
      const unsubscribe = coordinator.subscribePlan(202, { isDialogOpen: (): boolean => false, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; }, pollIntervalMs: 1000 });
      seq = 1;
      machine.emit(PlanStatus.IN_PROGRESS);
      unsubscribe();
      hooks.restore();
      expect(showCount).assertEqual(1);
    });

    it('normal: consume_on_plan_should_show_when_payload_matches', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 2, planId: 301, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      const input: PlanWeatherConsumeInput = { isDialogOpen: false, currentPlanId: 301, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } };
      coordinator.consumeOnPlan(input);
      hooks.restore();
      expect(showCount).assertEqual(1);
    });

    it('boundary: consume_on_plan_should_skip_when_dialog_is_open', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 3, planId: 302, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      coordinator.consumeOnPlan({ isDialogOpen: true, currentPlanId: 302, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      hooks.restore();
      expect(showCount).assertEqual(0);
    });

    it('invalid: consume_on_plan_should_skip_when_payload_plan_mismatch', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 4, planId: 999, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      coordinator.consumeOnPlan({ isDialogOpen: false, currentPlanId: 303, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      hooks.restore();
      expect(showCount).assertEqual(0);
    });

    it('normal: clear_should_forward_plan_id', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      let capturedPlanId = 0;
      hooks.setClear((planId?: number): void => { capturedPlanId = planId ?? 0; });
      WeatherReminderCoordinator.getInstance().clear(401);
      hooks.restore();
      expect(capturedPlanId).assertEqual(401);
    });

    it('boundary: clear_should_allow_undefined_plan_id', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      let called = false;
      hooks.setClear((): void => { called = true; });
      WeatherReminderCoordinator.getInstance().clear();
      hooks.restore();
      expect(called).assertTrue();
    });

    it('invalid: clear_should_still_forward_negative_plan_id', 0, () => {
      const hooks = new ReminderStoreHooksForBatch();
      let capturedPlanId = 0;
      hooks.setClear((planId?: number): void => { capturedPlanId = planId ?? 0; });
      WeatherReminderCoordinator.getInstance().clear(-1);
      hooks.restore();
      expect(capturedPlanId).assertEqual(-1);
    });
  });
}
