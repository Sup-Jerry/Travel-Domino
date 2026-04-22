import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import { WeatherDomainService } from '../main/ets/domain/services/WeatherDomainService';
import { NodeSuitabilityResult, WeatherRiskEvaluator } from '../main/ets/domain/services/WeatherRiskEvaluator';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  CityWeatherBucket,
  GeoPointInput,
  PlanNodeWeatherBinding,
  RouteWeatherSuitability,
  WeatherCollabOptions,
  WeatherCollabContext,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherDayWindow,
  WeatherSnapshot,
  WeatherSuggestion,
  WeatherTrendTag,
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
import { ExecutionContext, createDefaultExecutionContext } from '../main/ets/domain/statemachine/ExecutionContext';
import { WeatherFetchPolicy, WeatherPolicyResolver, WeatherTarget, WeatherTargetType } from '../main/ets/domain/statemachine/WeatherPolicyResolver';
interface WeatherContextBuilderPrivateAI {
  extractCityKeyFromAddress(address?: string): string;
  buildCollabContext(
    sourceEvents: EventEntity[],
    bindings: PlanNodeWeatherBinding[],
    options: WeatherCollabOptions
  ): WeatherCollabContext;
  buildDayWindows(events: EventEntity[], bindings: PlanNodeWeatherBinding[]): WeatherDayWindow[];
  buildCityBuckets(events: EventEntity[], bindings: PlanNodeWeatherBinding[]): CityBucketBuildResultAI;
  buildCollabSummary(dayWindows: WeatherDayWindow[], cityBuckets: CityWeatherBucket[], trendTag: WeatherTrendTag): string;
  resolveCurrentGeoPoint(input?: GeoPointInput, activeEvent?: EventEntity, nextNode?: EventEntity): GeoPointInput | undefined;
  resolveNextNode(pendingEvents: EventEntity[], activeEvent?: EventEntity): EventEntity | undefined;
  resolveFutureNodes(pendingEvents: EventEntity[], nextNode?: EventEntity, maxCount?: number): EventEntity[];
  getOrderedScheduledEvents(events: EventEntity[]): EventEntity[];
  buildRainReorderTarget(nodes: EventEntity[]): string[];
  isRainWeather(code: string, text: string): boolean;
  isSevereWeather(code: string, text: string): boolean;
  resolveTriggerType(tags?: string[]): 'RAIN' | 'HEAT' | 'COLD' | 'WIND' | 'SEVERE_ALERT' | 'UNKNOWN';
}

interface CityBucketBuildResultAI {
  buckets: CityWeatherBucket[];
  missCount: number;
  cappedCount: number;
}

class FakeWeatherServiceForBatch extends AmapWeatherService {
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

  public toSnapshotByPoint(pointKey: string, info: WeatherInfo): WeatherSnapshot {
    const snapshot: WeatherSnapshot = {
      locationKey: pointKey,
      sourceType: 'PLAN_LOCATION',
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
    return snapshot;
  }
}

class FakeRiskEvaluatorForBatch extends WeatherRiskEvaluator {
  public scoreByEventId: Map<number, number> = new Map<number, number>();
  public tagsByEventId: Map<number, string[]> = new Map<number, string[]>();
  public routeScore: number = 85;
  public routeTags: string[] = [];

  public evaluateNodeSuitability(event: EventEntity, _snapshot?: WeatherSnapshot, _pref?: WeatherUserPreference): NodeSuitabilityResult {
    const result: NodeSuitabilityResult = {
      score: this.scoreByEventId.get(event.id) ?? 80,
      riskTags: this.tagsByEventId.get(event.id) ?? []
    };
    return result;
  }

  public evaluateRouteSuitability(_bindings: PlanNodeWeatherBinding[], _pref?: WeatherUserPreference, _collab?: WeatherCollabContext): RouteWeatherSuitability {
    const result: RouteWeatherSuitability = {
      routeScore: this.routeScore,
      riskTags: this.routeTags,
      summaryText: 'route_ok_phase2'
    };
    return result;
  }
}

class FakePolicyResolverForBatch extends WeatherPolicyResolver {
  public throwOnResolve: boolean = false;
  public throwOnTargets: boolean = false;
  public lastResolvedStatus: PlanStatus = PlanStatus.DRAFT;
  public lastPlanId: string = '';
  public lastTargetStatus: PlanStatus = PlanStatus.DRAFT;
  public lastEventCount: number = 0;

  public resolveWeatherFetchPolicy(status: PlanStatus): WeatherFetchPolicy {
    if (this.throwOnResolve) {
      throw new Error('resolve_policy_failed_phase2');
    }
    this.lastResolvedStatus = status;
    return {
      targets: [WeatherTargetType.ALL_PLAN_NODES],
      forceRefreshOnEnter: true,
      allowCache: true
    };
  }

  public buildWeatherTargets(planId: string, status: PlanStatus, events: EventEntity[]): WeatherTarget[] {
    if (this.throwOnTargets) {
      throw new Error('build_targets_failed_phase2');
    }
    this.lastPlanId = planId;
    this.lastTargetStatus = status;
    this.lastEventCount = events.length;
    return events.map((event: EventEntity) => {
      const target: WeatherTarget = {
        type: WeatherTargetType.ALL_PLAN_NODES,
        planId: planId,
        latitude: event.latitude,
        longitude: event.longitude,
        nodeId: `${event.id}`,
        forecastTime: event.dynamic_start_time
      };
      return target;
    });
  }
}

class FakeContextBuilderForDomain extends WeatherContextBuilder {
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
    const eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
    return {
      context: { stage: 'CONFIRMED', generatedAt: 1, bindings: [], routeSuitability: { routeScore: 90, riskTags: [], summaryText: 'ok' } },
      eventMap: eventMap,
      sourceEvents: events
    };
  }

  public async buildExecutionContext(_events: EventEntity[], _loc?: GeoPointInput, forceRefresh: boolean = false): Promise<WeatherContextBuildResult> {
    this.executionCalls += 1;
    this.lastForceRefresh = forceRefresh;
    if (this.executionThrow) {
      throw new Error('domain_execution_failed_phase2');
    }
    const eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
    return {
      context: { stage: 'IN_PROGRESS', generatedAt: 2, bindings: [], routeSuitability: { routeScore: 75, riskTags: ['RAIN'], summaryText: 'ok' }, executionRiskScore: 75, executionRiskTags: ['RAIN'], futureNodeWeatherList: [] },
      eventMap: eventMap,
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

interface PlanTransitionEventForBatch {
  toStatus: PlanStatus;
}

interface PlanStatusResultForBatch {
  status: PlanStatus;
}

interface MutableWeatherContextForBatch {
  routeSuitability?: RouteWeatherSuitability;
}

class FakePlanStateMachineForBatch {
  public status: PlanStatus = PlanStatus.IN_PROGRESS;
  private handler: ((event: PlanTransitionEventForBatch) => void) | null = null;

  public subscribePlanTransition(_planId: string, handler: (event: PlanTransitionEventForBatch) => void): () => void {
    this.handler = handler;
    return () => {};
  }

  public getPlanStatus(_planId: string): PlanStatusResultForBatch {
    const statusResult: PlanStatusResultForBatch = { status: this.status };
    return statusResult;
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

function createExecutionContextForBatch(lat: number, lng: number): ExecutionContext {
  const context = createDefaultExecutionContext('ctx_weather', Date.now(), 0, 0);
  context.lastKnownLatitude = lat;
  context.lastKnownLongitude = lng;
  return context;
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

function createBindingForBatch(
  event: EventEntity,
  score: number,
  tags: string[],
  cityCode: string = ''
): PlanNodeWeatherBinding {
  const weather: WeatherSnapshot = {
    locationKey: `weather_${event.id}`,
    sourceType: 'PLAN_LOCATION',
    weatherTime: 1700000000000,
    fetchTime: 1700000000000,
    conditionCode: tags.indexOf('RAIN') >= 0 ? 'RAIN' : 'CLEAR',
    conditionText: tags.indexOf('RAIN') >= 0 ? '小雨' : '晴',
    temperatureCelsius: tags.indexOf('HEAT') >= 0 ? 38 : 24,
    cityCode: cityCode
  };
  const binding: PlanNodeWeatherBinding = {
    nodeId: `${event.id}`,
    eventId: event.id,
    nodeName: event.name,
    weather: weather,
    suitabilityScore: score,
    riskTags: tags
  };
  return binding;
}

export default function phase2BatchAITest() {
  describe('phase2BatchAITest_weather_context_builder', () => {
    it('normal: resolve_weather_fetch_policy_should_delegate_to_resolver', 0, () => {
      // Arrange
      // Act
      // Assert
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver);
      const policy = builder.resolveWeatherFetchPolicy(PlanStatus.DRAFT);
      expect(policyResolver.lastResolvedStatus).assertEqual(PlanStatus.DRAFT);
      expect(policy.targets.length > 0).assertTrue();
    });

    it('boundary: resolve_weather_fetch_policy_should_support_terminal_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver);
      const policy = builder.resolveWeatherFetchPolicy(PlanStatus.EXPIRED);
      expect(policyResolver.lastResolvedStatus).assertEqual(PlanStatus.EXPIRED);
      expect(policy.allowCache).assertTrue();
    });

    it('invalid: resolve_weather_fetch_policy_should_throw_when_resolver_fails', 0, () => {
      // Arrange
      // Act
      // Assert
      const policyResolver = new FakePolicyResolverForBatch();
      policyResolver.throwOnResolve = true;
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver);
      let message = '';
      try {
        builder.resolveWeatherFetchPolicy(PlanStatus.READY);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('resolve_policy_failed_phase2');
    });

    it('normal: build_weather_targets_should_delegate_with_plan_and_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver);
      const targets = builder.buildWeatherTargets('plan_a', PlanStatus.CONFIRMED, [createEventForBatch(1), createEventForBatch(2)]);
      expect(policyResolver.lastEventCount).assertEqual(2);
      expect(targets.length).assertEqual(2);
    });

    it('boundary: build_weather_targets_should_handle_empty_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const policyResolver = new FakePolicyResolverForBatch();
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver);
      const targets = builder.buildWeatherTargets('plan_b', PlanStatus.DRAFT, []);
      expect(policyResolver.lastEventCount).assertEqual(0);
      expect(targets.length).assertEqual(0);
    });

    it('invalid: build_weather_targets_should_throw_when_resolver_fails', 0, () => {
      // Arrange
      // Act
      // Assert
      const policyResolver = new FakePolicyResolverForBatch();
      policyResolver.throwOnTargets = true;
      const builder = new WeatherContextBuilder(undefined, undefined, policyResolver);
      let message = '';
      try {
        builder.buildWeatherTargets('plan_c', PlanStatus.READY, []);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('build_targets_failed_phase2');
    });

    it('normal: refresh_weather_by_status_should_route_ready_to_execution_context', 0, async () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      Reflect.set(builder as Object, 'buildWeatherTargets', (): WeatherTarget[] => []);
      let capturedStage = '';
      Reflect.set(builder as Object, 'buildExecutionContext', async (
        _events: EventEntity[],
        _loc?: GeoPointInput,
        _force?: boolean,
        _pref?: WeatherUserPreference,
        _opt?: Object,
        stage?: string
      ): Promise<WeatherContextBuildResult> => {
        capturedStage = stage ?? '';
        const eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
        const context: WeatherContext = {
          stage: 'READY',
          generatedAt: 1700000000003,
          bindings: [],
          routeSuitability: { routeScore: 80, riskTags: [], summaryText: '' }
        };
        const result: WeatherContextBuildResult = { context: context, eventMap: eventMap, sourceEvents: [] };
        return result;
      });
      const result = await builder.refreshWeatherByStatus(
        'plan_ready',
        PlanStatus.READY,
        [createEventForBatch(1)],
        createExecutionContextForBatch(31.1, 121.5),
        true
      );
      expect(result.success).assertTrue();
      expect(capturedStage).assertEqual('READY');
    });

    it('boundary: refresh_weather_by_status_should_return_direct_result_for_terminal_status', 0, async () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      Reflect.set(builder as Object, 'buildWeatherTargets', () => ['target_terminal']);
      const result = await builder.refreshWeatherByStatus('plan_terminal', PlanStatus.EXPIRED, []);
      expect(result.success).assertTrue();
      expect((result.snapshotVersion ?? '').includes('EXPIRED_')).assertTrue();
    });

    it('invalid: refresh_weather_by_status_should_return_degraded_when_context_build_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
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
      // Arrange
      // Act
      // Assert
      const weatherService = new FakeWeatherServiceForBatch();
      const risk = new FakeRiskEvaluatorForBatch();
      risk.scoreByEventId.set(1, 66);
      risk.tagsByEventId.set(1, ['RAIN']);
      const builder = new WeatherContextBuilder(weatherService, risk, new FakePolicyResolverForBatch());
      const event = createEventForBatch(1, 1, 30.3, 120.3);
      const key = AmapWeatherService.toPointKey(event.latitude, event.longitude, event.dynamic_start_time);
      weatherService.weatherByPoint.set(key, createInfoForBatch('RAIN', 23));
      const result = await builder.buildPlanningContext([event], undefined, { enableMultiDay: true, enableMultiCity: true }, 'CONFIRMED');
      expect(result.context.bindings.length).assertEqual(1);
      expect(result.context.bindings[0].suitabilityScore).assertEqual(66);
    });

    it('boundary: build_planning_context_should_filter_invalid_coordinates_and_status', 0, async () => {
      // Arrange
      // Act
      // Assert
      const weatherService = new FakeWeatherServiceForBatch();
      const builder = new WeatherContextBuilder(weatherService, new FakeRiskEvaluatorForBatch(), new FakePolicyResolverForBatch());
      const result = await builder.buildPlanningContext([createEventForBatch(2, 0, 30.5, 120.5), createEventForBatch(3, 1, 0, 0)]);
      expect(result.sourceEvents.length).assertEqual(0);
      expect(weatherService.lastBatchPoints.length).assertEqual(0);
    });

    it('invalid: build_planning_context_should_throw_when_batch_query_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const weatherService = new FakeWeatherServiceForBatch();
      weatherService.batchShouldThrow = true;
      const builder = new WeatherContextBuilder(weatherService, new FakeRiskEvaluatorForBatch(), new FakePolicyResolverForBatch());
      let message = '';
      try {
        await builder.buildPlanningContext([createEventForBatch(4)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('batch_failed_phase2');
    });
    it('normal: build_execution_context_should_resolve_current_and_next_weather', 0, async () => {
      // Arrange
      // Act
      // Assert
      const weatherService = new FakeWeatherServiceForBatch();
      const builder = new WeatherContextBuilder(weatherService, new FakeRiskEvaluatorForBatch(), new FakePolicyResolverForBatch());
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
      // Arrange
      // Act
      // Assert
      const weatherService = new FakeWeatherServiceForBatch();
      const builder = new WeatherContextBuilder(weatherService, new FakeRiskEvaluatorForBatch(), new FakePolicyResolverForBatch());
      const completed = createEventForBatch(21);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const result = await builder.buildExecutionContext([completed], { latitude: 0, longitude: 0 });
      expect(result.sourceEvents.length).assertEqual(0);
      expect(result.context.bindings.length).assertEqual(0);
    });

    it('invalid: build_execution_context_should_throw_when_weather_service_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const weatherService = new FakeWeatherServiceForBatch();
      weatherService.batchShouldThrow = true;
      const builder = new WeatherContextBuilder(weatherService, new FakeRiskEvaluatorForBatch(), new FakePolicyResolverForBatch());
      let message = '';
      try {
        await builder.buildExecutionContext([createEventForBatch(31)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('batch_failed_phase2');
    });

    it('normal: build_execution_suggestions_should_emit_rain_actions', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const context = createBaseExecutionContextForBatch(['RAIN']);
      context.nextNodeWeather = { locationKey: 'k1', sourceType: 'PLAN_LOCATION', weatherTime: 1, fetchTime: 1, conditionCode: 'RAIN', conditionText: 'RAIN' };
      const suggestions = builder.buildExecutionSuggestions(context);
      expect(suggestions.length).assertEqual(2);
      expect(suggestions[0].actionType).assertEqual('REORDER');
    });

    it('boundary: build_execution_suggestions_should_emit_unknown_replacement', 0, () => {
      // Arrange
      // Act
      // Assert
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
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const buildExecutionSuggestions = Reflect.get(builder as Object, 'buildExecutionSuggestions') as (context?: WeatherContext) => WeatherSuggestion[];
      const suggestions = buildExecutionSuggestions(undefined);
      expect(suggestions.length).assertEqual(0);
    });

    it('normal: build_execution_adjustments_should_emit_severe_skip', 0, () => {
      // Arrange
      // Act
      // Assert
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
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const suggestions = builder.buildExecutionAdjustments(0, createBaseExecutionContextForBatch(['RAIN']), [createEventForBatch(51)]);
      expect(suggestions.length).assertEqual(0);
    });

    it('invalid: build_execution_adjustments_should_return_empty_for_null_context', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const buildExecutionAdjustments = Reflect.get(builder as Object, 'buildExecutionAdjustments') as (
        planId: number,
        context?: WeatherContext,
        futureNodes?: EventEntity[]
      ) => WeatherSuggestion[];
      const suggestions = buildExecutionAdjustments(1, undefined, [createEventForBatch(52)]);
      expect(suggestions.length).assertEqual(0);
    });

    it('normal: build_prompt_summary_should_include_route_and_preference', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'CONFIRMED',
        generatedAt: 1,
        bindings: [{
          nodeId: '1', eventId: 1, suitabilityScore: 88, riskTags: ['RAIN'],
          weather: { locationKey: 'k1', sourceType: 'PLAN_LOCATION', weatherTime: 1, fetchTime: 1, conditionCode: 'RAIN', conditionText: '灏忛洦', temperatureCelsius: 22 }
        }],
        routeSuitability: { routeScore: 82, riskTags: ['RAIN'], summaryText: 'ok' }
      };
      const summary = builder.buildPromptSummary(context, DEFAULT_WEATHER_USER_PREFERENCE);
      expect(summary.length > 0).assertTrue();
      expect(summary.includes('82')).assertTrue();
    });

    it('boundary: build_prompt_summary_should_return_fallback_text_when_no_binding', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const summary = builder.buildPromptSummary({ stage: 'CONFIRMED', generatedAt: 1, bindings: [], routeSuitability: { routeScore: 100, riskTags: [], summaryText: 'ok' } });
      expect(summary.length > 0).assertTrue();
    });

    it('invalid: build_prompt_summary_should_throw_when_route_suitability_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      let message = '';
      const badContext = createBaseExecutionContextForBatch([]);
      const mutableContext = badContext as Object as MutableWeatherContextForBatch;
      badContext.bindings = [{
        nodeId: '1',
        eventId: 1,
        suitabilityScore: 80,
        riskTags: ['RAIN']
      }];
      mutableContext.routeSuitability = undefined;
      try {
        builder.buildPromptSummary(badContext);
      } catch (error) {
        message = error instanceof Error ? error.message : 'thrown';
      }
      expect(message.length > 0).assertTrue();
    });
  });

  describe('phase2BatchAITest_weather_domain_service', () => {
    it('normal: build_planning_context_should_delegate_to_context_builder', 0, async () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      const result = await service.buildPlanningContext([createEventForBatch(61)]);
      expect(fakeBuilder.planningCalls).assertEqual(1);
      expect(result.context.stage).assertEqual('CONFIRMED');
    });

    it('boundary: build_planning_context_should_support_empty_events', 0, async () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      await service.buildPlanningContext([]);
      expect(fakeBuilder.lastPlanningEventsLength).assertEqual(0);
    });

    it('invalid: build_planning_context_should_throw_when_builder_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.planningThrow = true;
      const service = new WeatherDomainService(fakeBuilder);
      let message = '';
      try {
        await service.buildPlanningContext([createEventForBatch(62)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_planning_failed_phase2');
    });
    it('normal: build_execution_context_should_delegate_with_force_refresh', 0, async () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      await service.buildExecutionContext([createEventForBatch(63)], { latitude: 30.1, longitude: 120.1 }, true);
      expect(fakeBuilder.executionCalls).assertEqual(1);
      expect(fakeBuilder.lastForceRefresh).assertTrue();
    });

    it('boundary: build_execution_context_should_allow_default_force_refresh_false', 0, async () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      await service.buildExecutionContext([]);
      expect(fakeBuilder.lastForceRefresh).assertFalse();
    });

    it('invalid: build_execution_context_should_throw_when_builder_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.executionThrow = true;
      const service = new WeatherDomainService(fakeBuilder);
      let message = '';
      try {
        await service.buildExecutionContext([createEventForBatch(64)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_execution_failed_phase2');
    });

    it('normal: build_execution_adjustments_should_delegate_with_plan_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      service.buildExecutionAdjustments(123, createBaseExecutionContextForBatch(['RAIN']), [createEventForBatch(65)]);
      expect(fakeBuilder.adjustmentCalls).assertEqual(1);
      expect(fakeBuilder.lastPlanId).assertEqual(123);
    });

    it('boundary: build_execution_adjustments_should_support_empty_future_nodes', 0, () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      const suggestions = service.buildExecutionAdjustments(1, createBaseExecutionContextForBatch([]), []);
      expect(suggestions.length).assertEqual(0);
    });

    it('invalid: build_execution_adjustments_should_throw_when_builder_fails', 0, () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.adjustThrow = true;
      const service = new WeatherDomainService(fakeBuilder);
      let message = '';
      try {
        service.buildExecutionAdjustments(1, createBaseExecutionContextForBatch([]), []);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('domain_adjust_failed_phase2');
    });

    it('normal: build_prompt_summary_should_delegate_to_builder', 0, () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      const text = service.buildPromptSummary(createBaseExecutionContextForBatch([]));
      expect(text).assertEqual('prompt_ok_phase2');
      expect(fakeBuilder.promptCalls).assertEqual(1);
    });

    it('boundary: build_prompt_summary_should_support_preference_override', 0, () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      const service = new WeatherDomainService(fakeBuilder);
      const text = service.buildPromptSummary(createBaseExecutionContextForBatch([]), { heatSensitivity: 2, rainSensitivity: 0, weatherRiskTolerance: 1 });
      expect(text).assertEqual('prompt_ok_phase2');
    });

    it('invalid: build_prompt_summary_should_throw_when_builder_fails', 0, () => {
      // Arrange
      // Act
      // Assert
      const fakeBuilder = new FakeContextBuilderForDomain();
      fakeBuilder.promptThrow = true;
      const service = new WeatherDomainService(fakeBuilder);
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
      // Arrange
      // Act
      // Assert
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      const first = WeatherReminderCoordinator.getInstance();
      const second = WeatherReminderCoordinator.getInstance();
      expect(first === second).assertTrue();
    });

    it('boundary: get_instance_should_create_new_after_reset', 0, () => {
      // Arrange
      // Act
      // Assert
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      const one = WeatherReminderCoordinator.getInstance();
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      const two = WeatherReminderCoordinator.getInstance();
      expect(one === two).assertFalse();
    });

    it('invalid: get_instance_should_return_existing_even_if_polluted', 0, () => {
      // Arrange
      // Act
      // Assert
      const polluted = WeatherReminderCoordinator.getInstance();
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', polluted);
      const got = WeatherReminderCoordinator.getInstance();
      expect(got === polluted).assertTrue();
      Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
    });

    it('normal: subscribe_plan_should_show_payload_on_new_seq', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 1, planId: 101, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      hooks.setClear((): void => {});
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', new FakePlanStateMachineForBatch());
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
      // Arrange
      // Act
      // Assert
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      const unsubscribe = coordinator.subscribePlan(0, { isDialogOpen: (): boolean => false, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      unsubscribe();
      expect(showCount).assertEqual(0);
    });

    it('invalid: subscribe_plan_should_ignore_non_incremental_seq_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      let seq = 1;
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: seq, planId: 202, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      hooks.setClear((): void => {});
      const coordinator = WeatherReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineForBatch();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      let showCount = 0;
      const unsubscribe = coordinator.subscribePlan(202, { isDialogOpen: (): boolean => false, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; }, pollIntervalMs: 1000 });
      seq = 1;
      machine.emit(PlanStatus.IN_PROGRESS);
      unsubscribe();
      hooks.restore();
      expect(showCount).assertEqual(1);
    });

    it('normal: consume_on_plan_should_show_when_payload_matches', 0, () => {
      // Arrange
      // Act
      // Assert
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
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 3, planId: 302, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      coordinator.consumeOnPlan({ isDialogOpen: true, currentPlanId: 302, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      hooks.restore();
      expect(showCount).assertEqual(0);
    });

    it('invalid: consume_on_plan_should_skip_when_payload_plan_mismatch', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 4, planId: 999, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      coordinator.consumeOnPlan({ isDialogOpen: false, currentPlanId: 303, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      hooks.restore();
      expect(showCount).assertEqual(0);
    });

    it('normal: clear_should_forward_plan_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      let capturedPlanId = 0;
      hooks.setClear((planId?: number): void => { capturedPlanId = planId ?? 0; });
      WeatherReminderCoordinator.getInstance().clear(401);
      hooks.restore();
      expect(capturedPlanId).assertEqual(401);
    });

    it('boundary: clear_should_allow_undefined_plan_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      let called = false;
      hooks.setClear((): void => { called = true; });
      WeatherReminderCoordinator.getInstance().clear();
      hooks.restore();
      expect(called).assertTrue();
    });

    it('conflict: consume_on_plan_should_skip_when_dialog_open_and_plan_mismatch', 0, () => {
      // Arrange
      // Act
      // Assert
      // Arrange
      const hooks = new ReminderStoreHooksForBatch();
      hooks.setRead((): WeatherReminderPayload | null => ({ seq: 5, planId: 998, level: 'NOTICE', title: 'weather', message: 'msg', relatedNodeIds: ['1'], createdAt: 1 }));
      const coordinator = WeatherReminderCoordinator.getInstance();
      let showCount = 0;
      // Act
      coordinator.consumeOnPlan({ isDialogOpen: true, currentPlanId: 303, onShow: (_payload: WeatherReminderPayload): void => { showCount += 1; } });
      hooks.restore();
      // Assert
      expect(showCount).assertEqual(0);
    });

    it('regression: build_prompt_summary_should_keep_fallback_when_bindings_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      // Arrange
      const builder = new WeatherContextBuilder();
      // Act
      const summary = builder.buildPromptSummary({
        stage: 'CONFIRMED',
        generatedAt: 1,
        bindings: [],
        routeSuitability: { routeScore: 80, riskTags: [], summaryText: 'ok' }
      });
      // Assert
      expect(summary.length > 0).assertTrue();
    });

    it('combined: resolve_policy_and_build_summary_should_both_return_expected_result', 0, () => {
      // Arrange
      // Act
      // Assert
      // Arrange
      const builder = new WeatherContextBuilder();
      // Act
      const policy = builder.resolveWeatherFetchPolicy(PlanStatus.READY);
      const summary = builder.buildPromptSummary({
        stage: 'CONFIRMED',
        generatedAt: 1,
        bindings: [],
        routeSuitability: { routeScore: 90, riskTags: [], summaryText: 'ok' }
      });
      // Assert
      expect(policy.targets.length > 0).assertTrue();
      expect(summary.length > 0).assertTrue();
    });

    it('invalid: clear_should_still_forward_negative_plan_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ReminderStoreHooksForBatch();
      let capturedPlanId = 0;
      hooks.setClear((planId?: number): void => { capturedPlanId = planId ?? 0; });
      WeatherReminderCoordinator.getInstance().clear(-1);
      hooks.restore();
      expect(capturedPlanId).assertEqual(-1);
    });
    it('boundary: weather_context_builder_should_extract_city_key_from_address_suffix', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;

      // Act
      const city = builder.extractCityKeyFromAddress('北京市朝阳区公园路1号');

      // Assert
      expect(city).assertEqual('北京市');
    });

    it('invalid: weather_context_builder_city_key_should_fallback_empty_for_blank_or_no_suffix', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;

      // Act
      const blank = builder.extractCityKeyFromAddress('   ');
      const noSuffix = builder.extractCityKeyFromAddress('朝阳区公园路1号');

      // Assert
      expect(blank).assertEqual('');
      expect(noSuffix).assertEqual('');
    });

    it('normal: weather_context_builder_collab_context_should_group_multi_day_and_multi_city', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;
      const first = createEventForBatch(901, 1, 31.1, 121.1, 1);
      first.dynamic_day_offset = 0;
      first.address = '上海市黄浦区';
      const second = createEventForBatch(902, 1, 31.2, 121.2, 2);
      second.dynamic_day_offset = 1;
      second.address = '杭州市西湖区';
      const bindings: PlanNodeWeatherBinding[] = [
        createBindingForBatch(first, 72, ['RAIN'], '310100'),
        createBindingForBatch(second, 66, ['RAIN'], '330100')
      ];

      // Act
      const collab = builder.buildCollabContext([first, second], bindings, {
        enableMultiDay: true,
        enableMultiCity: true
      });

      // Assert
      expect(collab.dayWindowCount).assertEqual(2);
      expect(collab.cityGroupCount).assertEqual(2);
      expect(collab.trendTag).assertEqual('RAIN_PERSIST');
      expect(collab.collabSummary.includes('2城2日')).assertTrue();
    });

    it('boundary: weather_context_builder_collab_context_should_report_disabled_fallbacks', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;
      const event = createEventForBatch(903);
      const binding = createBindingForBatch(event, 88, []);

      // Act
      const collab = builder.buildCollabContext([event], [binding], {
        enableMultiDay: false,
        enableMultiCity: false
      });

      // Assert
      expect(collab.dayWindowCount).assertEqual(0);
      expect(collab.cityGroupCount).assertEqual(0);
      expect(collab.fallbackPath.includes('DAY_DISABLED')).assertTrue();
      expect(collab.fallbackPath.includes('CITY_DISABLED')).assertTrue();
      expect(collab.collabSummary).assertEqual('');
    });

    it('invalid: weather_context_builder_private_geo_and_sequence_helpers_should_fallback_safely', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;
      const active = createEventForBatch(904, 1, 30.4, 120.4, 2);
      const next = createEventForBatch(905, 1, 30.5, 120.5, 3);
      const invalidInput: GeoPointInput = { latitude: 0, longitude: 0 };

      // Act
      const emptyNext = builder.resolveNextNode([], undefined);
      const currentGeo = builder.resolveCurrentGeoPoint(invalidInput, active, next);
      const activeAsLast = builder.resolveNextNode([active], active);
      const futureWithoutNext = builder.resolveFutureNodes([active, next], undefined);

      // Assert
      expect(emptyNext === undefined).assertTrue();
      expect(currentGeo?.latitude ?? 0).assertEqual(active.latitude);
      expect(activeAsLast?.id ?? 0).assertEqual(active.id);
      expect(futureWithoutNext.length).assertEqual(0);
    });

    it('conflict: weather_context_builder_adjustments_should_dedupe_filter_and_append_collab_summary', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const outdoor = createEventForBatch(906, 1, 31.6, 121.6, 1);
      outdoor.type = 0;
      outdoor.priority = 1;
      outdoor.weather_condition = 'RAIN';
      outdoor.weather_text = '小雨';
      const indoor = createEventForBatch(907, 1, 31.7, 121.7, 2);
      indoor.type = 1;
      const context = createBaseExecutionContextForBatch(['RAIN']);
      context.generatedAt = 1700000000906;
      context.futureNodeWeatherList = [
        createBindingForBatch(outdoor, 61, ['RAIN']),
        createBindingForBatch(indoor, 90, [])
      ];
      context.collabContext = {
        dayWindows: [],
        cityBuckets: [],
        collabSummary: '2城2日：降雨持续',
        dayWindowCount: 2,
        cityGroupCount: 2,
        cityCappedCount: 0,
        cityMissCount: 0,
        trendTag: 'RAIN_PERSIST',
        fallbackPath: ''
      };

      // Act
      const suggestions = builder.buildExecutionAdjustments(66, context, [outdoor, indoor]);

      // Assert
      expect(suggestions.length).assertEqual(1);
      expect(suggestions[0].actionType).assertEqual('REORDER');
      expect(suggestions[0].message.includes('多日/多城协同')).assertTrue();
      expect((suggestions[0].actionPayload?.targetOrderNodeIds ?? [])[0]).assertEqual(`${indoor.id}`);
    });

    it('regression: weather_context_builder_day_city_helpers_should_cover_trend_and_cap_paths', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;
      const events: EventEntity[] = [];
      const bindings: PlanNodeWeatherBinding[] = [];
      for (let i = 0; i < 7; i++) {
        const event = createEventForBatch(920 + i, 1, 32 + i / 10, 118 + i / 10, i);
        event.dynamic_day_offset = i < 2 ? i : 1;
        event.address = `测试${i}市测试路`;
        events.push(event);
        bindings.push(createBindingForBatch(event, i === 0 ? 80 : 65, ['RAIN'], ''));
      }

      // Act
      const dayWindows = builder.buildDayWindows(events, bindings);
      const cityBuild = builder.buildCityBuckets(events, bindings);
      const summary = builder.buildCollabSummary(dayWindows, [], 'RAIN_PERSIST');

      // Assert
      expect(dayWindows.length).assertEqual(2);
      expect(dayWindows[1].trendTag).assertEqual('RAIN_PERSIST');
      expect(cityBuild.buckets.length).assertEqual(5);
      expect(cityBuild.cappedCount).assertEqual(2);
      expect(summary).assertEqual('2日趋势：降雨持续');
    });

    it('combined: weather_context_builder_weather_match_helpers_should_cover_text_code_and_ordering', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateAI;
      const outdoorEarly = createEventForBatch(940, 1, 31, 121, 1);
      outdoorEarly.type = 0;
      const indoorMiddle = createEventForBatch(941, 1, 31, 121, 2);
      indoorMiddle.type = 1;
      const outdoorLate = createEventForBatch(942, 1, 31, 121, 3);
      outdoorLate.type = 0;
      const unscheduled = createEventForBatch(943, 0, 31, 121, 0);
      const dayTwo = createEventForBatch(944, 1, 31, 121, 0);
      dayTwo.dynamic_day_offset = 2;

      // Act
      const rainByText = builder.isRainWeather('', '阵雨');
      const severeByCode = builder.isSevereWeather('HEAVY_RAIN', '');
      const trigger = builder.resolveTriggerType(['THUNDER']);
      const reordered = builder.buildRainReorderTarget([outdoorLate, indoorMiddle, outdoorEarly]);
      const ordered = builder.getOrderedScheduledEvents([outdoorLate, unscheduled, dayTwo, outdoorEarly]);

      // Assert
      expect(rainByText).assertTrue();
      expect(severeByCode).assertTrue();
      expect(trigger).assertEqual('RAIN');
      expect(reordered[0]).assertEqual(`${indoorMiddle.id}`);
      expect(ordered.length).assertEqual(3);
      expect(ordered[0].id).assertEqual(outdoorEarly.id);
      expect(ordered[2].id).assertEqual(dayTwo.id);
    });
  });
}



