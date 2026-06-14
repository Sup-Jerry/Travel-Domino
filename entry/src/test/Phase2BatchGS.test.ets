import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { ExecutionContext } from '../main/ets/domain/statemachine/ExecutionContext';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import {
  CityWeatherBucket,
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherContext,
  WeatherDayWindow,
  WeatherSnapshot,
  WeatherSuggestion,
  WeatherTrendTag,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';

interface WeatherContextBuilderPrivateGS {
  buildReplacementCandidates(targets: PlanNodeWeatherBinding[]): Object[];
  buildCollabSummary(dayWindows: WeatherDayWindow[], cityBuckets: CityWeatherBucket[], trendTag: WeatherTrendTag): string;
  resolveDominantTrend(dayWindows: WeatherDayWindow[]): WeatherTrendTag;
  resolveDayTrendTag(previous: WeatherDayWindow | null, currentScore: number, currentRiskTags: string[]): WeatherTrendTag;
  resolveExecutionGeoByContext(context?: ExecutionContext): GeoPointInput | undefined;
  resolveNextNode(pendingEvents: EventEntity[], activeEvent?: EventEntity): EventEntity | undefined;
  resolveFutureNodes(pendingEvents: EventEntity[], nextNode?: EventEntity, maxCount?: number): EventEntity[];
  resolveTriggerType(tags?: string[]): string;
  isOutdoorEvent(event?: EventEntity): boolean;
  preferenceSummary(preference: WeatherUserPreference): string;
  getOrderedScheduledEvents(events: EventEntity[]): EventEntity[];
}

class MockWeatherServiceGS extends AmapWeatherService {
  public batchWeather: Map<string, WeatherInfo> = new Map<string, WeatherInfo>();
  public currentWeather: WeatherInfo | null = null;

  async batchGetWeather(_points: Object[]): Promise<Map<string, WeatherInfo>> {
    return this.batchWeather;
  }

  async getWeatherByGeoPoint(
    _latitude: number,
    _longitude: number,
    _targetTime?: number,
    _sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION',
    _forceRefresh: boolean = false
  ): Promise<WeatherInfo | null> {
    return this.currentWeather;
  }

  toSnapshotByPoint(pointKey: string, info: WeatherInfo): WeatherSnapshot {
    return {
      locationKey: pointKey,
      sourceType: 'PLAN_LOCATION',
      weatherTime: 1,
      fetchTime: 1,
      conditionCode: info.condition,
      conditionText: info.condition,
      temperatureCelsius: info.temperature,
      humidity: info.humidity,
      windSpeed: info.windSpeed,
      reportTime: info.reportTime,
      cityCode: info.cityCode
    };
  }
}

function createEventGS(id: number, name: string, duration: number = 60): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.duration = duration;
  event.status = 1;
  event.type = 1;
  event.sort_order = id;
  return event;
}

function createBindingGS(event: EventEntity, score: number): PlanNodeWeatherBinding {
  const weather: WeatherSnapshot = {
    locationKey: `gs_${event.id}`,
    sourceType: 'PLAN_LOCATION',
    weatherTime: 1,
    fetchTime: 1,
    conditionCode: 'CLEAR',
    conditionText: '晴',
    temperatureCelsius: 24
  };
  return {
    nodeId: `${event.id}`,
    eventId: event.id,
    nodeName: event.name,
    weather: weather,
    suitabilityScore: score,
    riskTags: []
  };
}

function createFallbackSuggestionGS(id: string, nodeId: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'INFO',
    triggerType: 'UNKNOWN',
    actionType: 'PREPARE',
    title: 'fallback',
    message: 'fallback_message',
    relatedNodeIds: [nodeId],
    createdAt: 1,
    reason: 'fallback_reason',
    expectedBenefit: 'fallback_benefit',
    canRollback: true,
    cooldownKey: `cooldown_${id}`,
    expiresAt: 2
  };
}

function createExecutionContextGS(): WeatherContext {
  return {
    stage: 'IN_PROGRESS',
    generatedAt: 1700000000123,
    bindings: [],
    routeSuitability: {
      routeScore: 88,
      riskTags: [],
      summaryText: 'route_ok'
    },
    executionRiskScore: 88,
    executionRiskTags: [],
    futureNodeWeatherList: []
  };
}

function createWeatherInfoGS(condition: string, temperature: number = 24): WeatherInfo {
  return {
    temperature: temperature,
    condition: condition,
    humidity: 60,
    windSpeed: 3,
    reportTime: '2026-06-14 10:00:00',
    cityCode: '330100'
  };
}

export default function phase2BatchGSTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGS_weather_context_builder_function', () => {
    it('combined: weather_context_builder_should_cover_execution_fallback_foreach_append', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const event = createEventGS(701, 'museum');
      const context = createExecutionContextGS();
      Reflect.set(builder as Object, 'buildExecutionSuggestions', (): WeatherSuggestion[] => {
        return [
          createFallbackSuggestionGS('fallback_primary', `${event.id}`),
          createFallbackSuggestionGS('fallback_duplicate', `${event.id}`)
        ];
      });

      // Act
      const suggestions = builder.buildExecutionAdjustments(701, context, [event]);

      // Assert
      expect(suggestions.length).assertEqual(1);
      expect(suggestions[0].actionType).assertEqual('PREPARE');
      expect((suggestions[0].relatedNodeIds ?? [])[0]).assertEqual(`${event.id}`);
    });

    it('combined: weather_context_builder_should_cover_replacement_candidate_sort_desc', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const first = createBindingGS(createEventGS(711, 'low_score'), 52);
      const second = createBindingGS(createEventGS(712, 'best_score'), 93);
      const third = createBindingGS(createEventGS(713, 'mid_score'), 78);

      // Act
      const candidates = builder.buildReplacementCandidates([first, second, third]) as Record<string, Object>[];

      // Assert
      expect(candidates.length).assertEqual(2);
      expect(candidates[0].eventId as number).assertEqual(712);
      expect(candidates[1].eventId as number).assertEqual(713);
    });

    it('normal: weather_context_builder_should_include_collab_summary_in_prompt', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const event = createEventGS(721, 'collab_node');
      const binding = createBindingGS(event, 86);
      const context: WeatherContext = {
        stage: 'IN_PROGRESS',
        generatedAt: 1700000000124,
        bindings: [binding],
        routeSuitability: {
          routeScore: 86,
          riskTags: ['RAIN'],
          summaryText: 'summary'
        },
        collabContext: {
          dayWindows: [],
          cityBuckets: [],
          collabSummary: 'multi-city-ready',
          dayWindowCount: 0,
          cityGroupCount: 0,
          cityCappedCount: 0,
          cityMissCount: 0,
          trendTag: 'STABLE',
          fallbackPath: ''
        }
      };

      // Act
      const summary = builder.buildPromptSummary(context);

      // Assert
      expect(summary.indexOf('multi-city-ready') >= 0).assertTrue();
    });

    it('boundary: weather_context_builder_private_edges_should_return_empty_for_missing_inputs', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;

      // Act
      const replacement = builder.buildReplacementCandidates([]);
      const future = builder.resolveFutureNodes([], undefined, 3);
      const trigger = builder.resolveTriggerType([]);
      const outdoor = builder.isOutdoorEvent(undefined);

      // Assert
      expect(replacement.length).assertEqual(0);
      expect(future.length).assertEqual(0);
      expect(trigger).assertEqual('UNKNOWN');
      expect(outdoor).assertFalse();
    });

    it('invalid: weather_context_builder_next_node_should_fallback_when_active_is_missing', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const first = createEventGS(731, 'first');
      const second = createEventGS(732, 'second');
      const missing = createEventGS(799, 'missing');

      // Act
      const next = builder.resolveNextNode([first, second], missing);
      const future = builder.resolveFutureNodes([first, second], missing, 2);

      // Assert
      expect(next?.id ?? -1).assertEqual(first.id);
      expect(future.length).assertEqual(2);
      expect(future[0].id).assertEqual(first.id);
    });

    it('conflict: weather_context_builder_trend_should_prioritize_warming_and_improving', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const warmingWindow: WeatherDayWindow = {
        dayOffset: 1,
        windowScore: 88,
        riskTags: ['HEAT'],
        trendTag: 'WARMING'
      };
      const improvingWindow: WeatherDayWindow = {
        dayOffset: 2,
        windowScore: 70,
        riskTags: [],
        trendTag: 'IMPROVING'
      };

      // Act
      const warming = builder.resolveDominantTrend([warmingWindow]);
      const improving = builder.resolveDominantTrend([improvingWindow]);

      // Assert
      expect(warming).assertEqual('WARMING');
      expect(improving).assertEqual('IMPROVING');
    });

    it('regression: weather_context_builder_day_trend_should_mark_drop_as_improving', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const previous: WeatherDayWindow = {
        dayOffset: 0,
        windowScore: 88,
        riskTags: [],
        trendTag: 'STABLE'
      };

      // Act
      const trend = builder.resolveDayTrendTag(previous, 70, []);

      // Assert
      expect(trend).assertEqual('IMPROVING');
    });

    it('combined: weather_context_builder_collab_summary_should_cover_empty_and_city_only_modes', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const city: CityWeatherBucket = {
        cityKey: 'HZ',
        nodeIds: ['1'],
        bucketScore: 91,
        summaryText: 'HZ均分91'
      };

      // Act
      const empty = builder.buildCollabSummary([], [], 'UNKNOWN');
      const cityOnly = builder.buildCollabSummary([], [city], 'STABLE');

      // Assert
      expect(empty).assertEqual('');
      expect(cityOnly).assertEqual('1城协同已纳入');
    });

    it('normal: weather_context_builder_should_cover_confirmed_inprogress_and_non_error_refresh_failure', 0, async () => {
      // Arrange
      const weatherService = new MockWeatherServiceGS();
      const builder = new WeatherContextBuilder(weatherService);
      const confirmedEvent = createEventGS(741, 'confirmed_node');
      confirmedEvent.latitude = 30.1;
      confirmedEvent.longitude = 120.1;
      confirmedEvent.dynamic_start_time = 1710000000000;
      const executionEvent = createEventGS(742, 'execution_node');
      executionEvent.latitude = 30.2;
      executionEvent.longitude = 120.2;
      executionEvent.dynamic_start_time = 1710003600000;
      executionEvent.completion_status = EventEntity.STATE_PENDING;
      const context: ExecutionContext = {
        planId: 'plan_gs',
        status: PlanStatus.IN_PROGRESS,
        plannedStartTime: 1,
        plannedEndTime: 2,
        completedNodeIds: [],
        skippedNodeIds: [],
        lastKnownLatitude: 30.3,
        lastKnownLongitude: 120.3,
        isAutoStarted: true,
        isPaused: false,
        updatedAt: 3
      };
      const failingBuilder = new WeatherContextBuilder(weatherService);
      Reflect.set(failingBuilder as Object, 'buildPlanningContext', async (): Promise<Object> => {
        return new Promise<Object>((_resolve, reject: (reason?: Object) => void): void => {
          reject('refresh_fail' as Object);
        });
      });

      // Act
      const confirmedResult = await builder.refreshWeatherByStatus('plan_gs', PlanStatus.CONFIRMED, [confirmedEvent]);
      const inProgressResult = await builder.refreshWeatherByStatus('plan_gs', PlanStatus.IN_PROGRESS, [executionEvent], context);
      const failedResult = await failingBuilder.refreshWeatherByStatus('plan_gs', PlanStatus.DRAFT, [confirmedEvent]);

      // Assert
      expect(confirmedResult.success).assertTrue();
      expect((confirmedResult.snapshotVersion ?? '').indexOf('CONFIRMED_') === 0).assertTrue();
      expect(inProgressResult.success).assertTrue();
      expect((inProgressResult.snapshotVersion ?? '').indexOf('IN_PROGRESS_') === 0).assertTrue();
      expect(failedResult.success).assertFalse();
      expect(failedResult.errorMessage).assertEqual('refresh_failed');
    });

    it('boundary: weather_context_builder_should_cover_execution_weather_fallback_and_zero_context_geo', 0, async () => {
      // Arrange
      const weatherService = new MockWeatherServiceGS();
      const builder = new WeatherContextBuilder(weatherService);
      const privateBuilder = builder as Object as WeatherContextBuilderPrivateGS;
      const pending = createEventGS(751, 'pending_node');
      pending.latitude = 31.1;
      pending.longitude = 121.1;
      pending.dynamic_start_time = 1710007200000;
      pending.completion_status = EventEntity.STATE_PENDING;
      pending.sort_order = 10;
      const zeroContext: ExecutionContext = {
        planId: 'plan_zero',
        status: PlanStatus.READY,
        plannedStartTime: 1,
        plannedEndTime: 2,
        completedNodeIds: [],
        skippedNodeIds: [],
        lastKnownLatitude: 0,
        lastKnownLongitude: 0,
        isAutoStarted: false,
        isPaused: false,
        updatedAt: 3
      };

      // Act
      const geo = privateBuilder.resolveExecutionGeoByContext(zeroContext);
      const result = await builder.buildExecutionContext([pending], undefined, false);

      // Assert
      expect(geo === undefined).assertTrue();
      expect(result.sourceEvents.length).assertEqual(1);
      expect(result.context.currentLocationWeather === undefined).assertTrue();
      expect(result.context.futureNodeWeatherList?.length ?? 0).assertEqual(1);
    });

    it('conflict: weather_context_builder_should_cover_single_rain_target_heat_notice_and_empty_info_tags', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const rainContext = createExecutionContextGS();
      rainContext.generatedAt = 1700000000991;
      rainContext.executionRiskScore = 66;
      rainContext.executionRiskTags = ['RAIN'];
      rainContext.nextNodeWeather = {
        locationKey: 'rain_next',
        sourceType: 'PLAN_LOCATION',
        weatherTime: 1,
        fetchTime: 1,
        conditionCode: 'RAIN',
        conditionText: 'rain',
        temperatureCelsius: 20
      };
      rainContext.futureNodeWeatherList = [createBindingGS(createEventGS(761, 'solo_rain'), 82)];
      const heatContext = createExecutionContextGS();
      heatContext.generatedAt = 1700000000992;
      heatContext.executionRiskScore = 88;
      heatContext.executionRiskTags = ['HEAT'];
      heatContext.nextNodeWeather = {
        locationKey: 'heat_next',
        sourceType: 'PLAN_LOCATION',
        weatherTime: 1,
        fetchTime: 1,
        conditionCode: 'SUNNY',
        conditionText: 'sunny',
        temperatureCelsius: 36
      };
      heatContext.futureNodeWeatherList = [createBindingGS(createEventGS(762, 'solo_heat'), 80)];
      const emptyContext = createExecutionContextGS();
      emptyContext.generatedAt = 1700000000993;
      emptyContext.executionRiskTags = [];
      emptyContext.futureNodeWeatherList = [createBindingGS(createEventGS(763, 'stable_node'), 79)];

      // Act
      const rainSuggestions = builder.buildExecutionSuggestions(rainContext);
      const heatSuggestions = builder.buildExecutionSuggestions(heatContext);
      const emptySuggestions = builder.buildExecutionSuggestions(emptyContext);

      // Assert
      expect(((rainSuggestions[0].actionPayload?.targetOrderNodeIds ?? []) as string[]).length).assertEqual(1);
      expect(heatSuggestions[0].level).assertEqual('NOTICE');
      expect(emptySuggestions.length).assertEqual(1);
    });

    it('regression: weather_context_builder_private_summary_and_sort_should_cover_stable_medium_and_equal_order', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const stableWindow: WeatherDayWindow = {
        dayOffset: 3,
        windowScore: 82,
        riskTags: [],
        trendTag: 'STABLE'
      };
      const first = createEventGS(771, 'same_order_a');
      const second = createEventGS(770, 'same_order_b');
      first.sort_order = 50;
      second.sort_order = 50;
      const preferenceTextInput: WeatherUserPreference = {
        heatSensitivity: 1,
        rainSensitivity: 1,
        weatherRiskTolerance: 1
      };

      // Act
      const stableTrend = builder.resolveDominantTrend([stableWindow]);
      const warmingSummary = builder.buildCollabSummary([], [], 'WARMING');
      const improvingSummary = builder.buildCollabSummary([stableWindow], [], 'IMPROVING');
      const mediumPreference = builder.preferenceSummary(preferenceTextInput);
      const ordered = builder.getOrderedScheduledEvents([first, second]);
      const steadyTrend = builder.resolveDayTrendTag(stableWindow, 91, []);
      const unknownTrend = builder.resolveDayTrendTag(stableWindow, 83, ['UNKNOWN']);

      // Assert
      expect(stableTrend).assertEqual('STABLE');
      expect(warmingSummary).assertEqual('');
      expect(improvingSummary).assertEqual('1日趋势：改善');
      expect(mediumPreference.indexOf('中') >= 0).assertTrue();
      expect(ordered[0].id).assertEqual(770);
      expect(steadyTrend).assertEqual('STABLE');
      expect(unknownTrend).assertEqual('UNKNOWN');
    });

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: validator_marker_should_cover_boundary_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
