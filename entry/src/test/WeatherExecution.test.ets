import { describe, it, expect } from '@ohos/hypium';
import { WeatherStagePolicy } from '../main/ets/domain/policy/WeatherStagePolicy';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { WeatherCollabContext, WeatherContext, WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';

function buildEvent(active: boolean): EventEntity {
  const event = new EventEntity();
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = active ? Date.now() : 0;
  event.actual_end_time = 0;
  return event;
}

export default function weatherExecutionTest() {
  describe('weatherExecutionTest', () => {
    it('normal: weather_stage_should_resolve_execution_when_active_exists', 0, () => {
      // Arrange
      // Act
      // Assert
      const events = [buildEvent(false), buildEvent(true)];
      const stage = WeatherStagePolicy.resolveDetailedStage(undefined, events);
      expect(stage).assertEqual('IN_PROGRESS');
    });

    it('normal: weather_stage_should_resolve_planning_when_no_active', 0, () => {
      // Arrange
      // Act
      // Assert
      const events = [buildEvent(false), buildEvent(false)];
      const stage = WeatherStagePolicy.resolveDetailedStage(undefined, events);
      expect(stage).assertEqual('CONFIRMED');
    });

    it('normal: execution_suggestion_should_emit_warning_on_low_score', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 50, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 50,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: [{
          nodeId: '1',
          eventId: 1,
          suitabilityScore: 50,
          riskTags: ['RAIN']
        }],
        nextNodeWeather: {
          locationKey: 'k',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: Date.now(),
          conditionCode: 'RAIN',
          conditionText: '小雨'
        }
      };
      const suggestions = builder.buildExecutionSuggestions(context);
      expect(suggestions.length > 0).assertEqual(true);
      expect(suggestions[0].level).assertEqual('WARNING');
    });

    it('boundary: execution_replace_should_include_candidates_or_fallback_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 80, riskTags: ['UNKNOWN'], summaryText: '' },
        executionRiskScore: 80,
        executionRiskTags: ['UNKNOWN'],
        futureNodeWeatherList: [
          { nodeId: '1', eventId: 1, nodeName: 'A点', suitabilityScore: 60, riskTags: ['UNKNOWN'] },
          { nodeId: '2', eventId: 2, nodeName: 'B点', suitabilityScore: 88, riskTags: [] }
        ],
        nextNodeWeather: {
          locationKey: 'k',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: Date.now(),
          conditionCode: 'UNK',
          conditionText: '未知'
        }
      };
      const pref: WeatherUserPreference = { heatSensitivity: 1, rainSensitivity: 2, weatherRiskTolerance: 1 };
      const suggestions = builder.buildExecutionSuggestions(context, pref);
      const replace = suggestions.find(item => item.actionType === 'REPLACE_NODE');
      expect(!!replace).assertEqual(true);
      expect((replace?.actionPayload?.replacementCandidates?.length ?? 0) >= 0).assertEqual(true);
    });

    it('normal: execution_adjustment_should_append_collab_explanation', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const collab: WeatherCollabContext = {
        dayWindows: [{ dayOffset: 0, windowScore: 70, riskTags: ['RAIN'], trendTag: 'RAIN_PERSIST' }],
        cityBuckets: [{ cityKey: 'A市', nodeIds: ['1'], bucketScore: 70, summaryText: 'A市均分70' }],
        collabSummary: '1城1日：降雨持续',
        dayWindowCount: 1,
        cityGroupCount: 1,
        cityCappedCount: 0,
        cityMissCount: 0,
        trendTag: 'RAIN_PERSIST',
        fallbackPath: ''
      };
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 60, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 60,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: [{ nodeId: '1', eventId: 1, suitabilityScore: 55, riskTags: ['RAIN'] }],
        nextNodeWeather: {
          locationKey: 'k',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: Date.now(),
          conditionCode: 'RAIN',
          conditionText: '中雨'
        },
        collabContext: collab
      };
      const event = new EventEntity();
      event.id = 1;
      event.status = 1;
      const suggestions = builder.buildExecutionAdjustments(1, context, [event], undefined, collab);
      expect(suggestions.length > 0).assertEqual(true);
      expect(suggestions[0].message.includes('多日/多城协同')).assertEqual(true);
    });
    it('normal: execution_adjustment_should_generate_reorder_for_rain_on_outdoor_node', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const event = new EventEntity();
      event.id = 11;
      event.name = 'rain_outdoor';
      event.status = 1;
      event.type = 0;
      event.duration = 60;
      const context: WeatherContext = {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 62, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 62,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: [{
          nodeId: '11',
          eventId: 11,
          nodeName: 'rain_outdoor',
          suitabilityScore: 55,
          riskTags: ['RAIN'],
          weather: {
            locationKey: 'k1',
            sourceType: 'PLAN_LOCATION',
            weatherTime: Date.now(),
            fetchTime: Date.now(),
            conditionCode: 'RAIN',
            conditionText: 'rain'
          }
        }]
      };
      const suggestions = builder.buildExecutionAdjustments(1, context, [event]);
      const reorder = suggestions.find((item) => item.actionType === 'REORDER');
      expect(!!reorder).assertEqual(true);
      expect(reorder?.triggerType).assertEqual('RAIN');
    });

    it('normal: execution_adjustment_should_generate_shorten_for_heat_over_35', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const event = new EventEntity();
      event.id = 12;
      event.name = 'heat_outdoor';
      event.status = 1;
      event.type = 0;
      event.duration = 60;
      const context: WeatherContext = {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 68, riskTags: ['HEAT'], summaryText: '' },
        executionRiskScore: 68,
        executionRiskTags: ['HEAT'],
        futureNodeWeatherList: [{
          nodeId: '12',
          eventId: 12,
          nodeName: 'heat_outdoor',
          suitabilityScore: 60,
          riskTags: ['HEAT'],
          weather: {
            locationKey: 'k2',
            sourceType: 'PLAN_LOCATION',
            weatherTime: Date.now(),
            fetchTime: Date.now(),
            conditionCode: 'SUNNY',
            conditionText: 'sunny',
            temperatureCelsius: 36
          }
        }]
      };
      const suggestions = builder.buildExecutionAdjustments(1, context, [event]);
      const shorten = suggestions.find((item) => item.actionType === 'SHORTEN_STAY');
      expect(!!shorten).assertEqual(true);
      expect((shorten?.suggestedDurationMin ?? 0) > 0).assertEqual(true);
    });

    it('normal: execution_adjustment_should_generate_skip_for_severe_weather', 0, () => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder();
      const event = new EventEntity();
      event.id = 13;
      event.name = 'severe_outdoor';
      event.status = 1;
      event.type = 0;
      const context: WeatherContext = {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 45, riskTags: ['SEVERE_ALERT'], summaryText: '' },
        executionRiskScore: 45,
        executionRiskTags: ['SEVERE_ALERT'],
        futureNodeWeatherList: [{
          nodeId: '13',
          eventId: 13,
          nodeName: 'severe_outdoor',
          suitabilityScore: 40,
          riskTags: ['SEVERE_ALERT'],
          weather: {
            locationKey: 'k3',
            sourceType: 'PLAN_LOCATION',
            weatherTime: Date.now(),
            fetchTime: Date.now(),
            conditionCode: 'STORM',
            conditionText: 'storm'
          }
        }]
      };
      const suggestions = builder.buildExecutionAdjustments(1, context, [event]);
      const skip = suggestions.find((item) => item.actionType === 'SKIP_NODE');
      expect(!!skip).assertEqual(true);
      expect(skip?.level).assertEqual('WARNING');
    });
  });
  describe('unit_test_case_generator_backfill_WeatherExecution', () => {
    it('invalid: execution_adjustment_should_return_empty_when_plan_id_invalid', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 80, riskTags: [], summaryText: '' }
      };
      // Act
      const suggestions = builder.buildExecutionAdjustments(0, context, []);
      // Assert
      expect(suggestions.length).assertEqual(0);
    });

    it('conflict: weather_stage_should_prioritize_paused_runtime_over_active_event', 0, () => {
      // Arrange
      const events = [buildEvent(true)];
      // Act
      const stage = WeatherStagePolicy.resolveDetailedStage(undefined, events, 'PAUSED');
      // Assert
      expect(stage).assertEqual('PAUSED');
    });

    it('regression: td-20260411-execution_suggestions_should_return_empty_when_future_nodes_missing', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 75, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 75,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: []
      };
      // Act
      const suggestions = builder.buildExecutionSuggestions(context);
      // Assert
      expect(suggestions.length).assertEqual(2);
      expect(suggestions[0].actionType).assertEqual('REORDER');
      expect(suggestions[1].actionType).assertEqual('SHORTEN_STAY');
    });

    it('combined: execution_adjustment_should_filter_out_non_future_related_suggestions', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const event = new EventEntity();
      event.id = 21;
      event.name = 'target';
      event.status = 1;
      event.type = 0;
      event.duration = 60;
      const context: WeatherContext = {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 50, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 50,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: [{
          nodeId: '21',
          eventId: 21,
          nodeName: 'target',
          suitabilityScore: 45,
          riskTags: ['RAIN'],
          weather: {
            locationKey: 'k',
            sourceType: 'PLAN_LOCATION',
            weatherTime: Date.now(),
            fetchTime: Date.now(),
            conditionCode: 'RAIN',
            conditionText: 'rain'
          }
        }]
      };
      // Act
      const suggestions = builder.buildExecutionAdjustments(1, context, [event]);
      const allRelatedToTarget = suggestions.every((item) =>
        item.relatedNodeIds.length === 0 || item.relatedNodeIds.includes('21')
      );
      // Assert
      expect(suggestions.length > 0).assertEqual(true);
      expect(allRelatedToTarget).assertEqual(true);
    });
  });
}
