import { describe, it, expect } from '@ohos/hypium';
import { WeatherRiskEvaluator } from '../main/ets/domain/services/WeatherRiskEvaluator';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  WeatherCollabContext,
  WeatherSnapshot,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';

function buildEvent(type: number): EventEntity {
  const event = new EventEntity();
  event.type = type;
  event.status = 1;
  return event;
}

export default function weatherRiskEvaluatorTest() {
  describe('weatherRiskEvaluatorTest', () => {
    it('normal: weather_risk_should_penalize_outdoor_rain', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new WeatherRiskEvaluator();
      const event = buildEvent(0);
      const weather: WeatherSnapshot = {
        locationKey: 'k',
        sourceType: 'PLAN_LOCATION',
        weatherTime: Date.now(),
        fetchTime: Date.now(),
        conditionCode: 'RAIN',
        conditionText: '小雨',
        temperatureCelsius: 22
      };
      const result = evaluator.evaluateNodeSuitability(event, weather);
      expect(result.score < 100).assertEqual(true);
      expect(result.riskTags.includes('RAIN')).assertEqual(true);
    });

    it('normal: weather_risk_should_keep_indoor_high_score', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new WeatherRiskEvaluator();
      const event = buildEvent(2);
      const weather: WeatherSnapshot = {
        locationKey: 'k',
        sourceType: 'PLAN_LOCATION',
        weatherTime: Date.now(),
        fetchTime: Date.now(),
        conditionCode: 'RAIN',
        conditionText: '中雨',
        temperatureCelsius: 24
      };
      const result = evaluator.evaluateNodeSuitability(event, weather);
      expect(result.score >= 90).assertEqual(true);
    });

    it('normal: weather_risk_should_penalize_unknown', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new WeatherRiskEvaluator();
      const event = buildEvent(0);
      const result = evaluator.evaluateNodeSuitability(event, undefined);
      expect(result.score).assertEqual(90);
      expect(result.riskTags.includes('UNKNOWN')).assertEqual(true);
    });

    it('normal: weather_risk_should_follow_rain_preference_weight', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new WeatherRiskEvaluator();
      const event = buildEvent(0);
      const weather: WeatherSnapshot = {
        locationKey: 'k',
        sourceType: 'PLAN_LOCATION',
        weatherTime: Date.now(),
        fetchTime: Date.now(),
        conditionCode: 'RAIN',
        conditionText: '小雨',
        temperatureCelsius: 24
      };
      const highRain: WeatherUserPreference = {
        heatSensitivity: 1,
        rainSensitivity: 2,
        weatherRiskTolerance: 1
      };
      const lowRain: WeatherUserPreference = {
        heatSensitivity: 1,
        rainSensitivity: 0,
        weatherRiskTolerance: 1
      };
      const highPenalty = evaluator.evaluateNodeSuitability(event, weather, highRain);
      const lowPenalty = evaluator.evaluateNodeSuitability(event, weather, lowRain);
      expect(highPenalty.score < lowPenalty.score).assertEqual(true);
    });

    it('normal: weather_route_should_apply_city_weight_and_trend_adjustment', 0, () => {
      // Arrange
      // Act
      // Assert
      const evaluator = new WeatherRiskEvaluator();
      const collab: WeatherCollabContext = {
        dayWindows: [
          { dayOffset: 0, windowScore: 82, riskTags: ['RAIN'], trendTag: 'STABLE' },
          { dayOffset: 1, windowScore: 68, riskTags: ['RAIN', 'HEAT'], trendTag: 'RAIN_PERSIST' }
        ],
        cityBuckets: [
          { cityKey: 'A市', nodeIds: ['1', '2'], bucketScore: 80, summaryText: 'A市均分80' },
          { cityKey: 'B市', nodeIds: ['3'], bucketScore: 60, summaryText: 'B市均分60' }
        ],
        collabSummary: '2城2日：降雨持续',
        dayWindowCount: 2,
        cityGroupCount: 2,
        cityCappedCount: 0,
        cityMissCount: 0,
        trendTag: 'RAIN_PERSIST',
        fallbackPath: ''
      };
      const route = evaluator.evaluateRouteSuitability([
        { nodeId: '1', eventId: 1, suitabilityScore: 80, riskTags: ['RAIN'] },
        { nodeId: '2', eventId: 2, suitabilityScore: 80, riskTags: ['RAIN'] },
        { nodeId: '3', eventId: 3, suitabilityScore: 60, riskTags: ['HEAT'] }
      ], undefined, collab);
      expect(route.routeScore < 80).assertEqual(true);
      expect(route.summaryText.includes('2城2日')).assertEqual(true);
    });
  });
  describe('unit_test_case_generator_backfill_WeatherRiskEvaluator', () => {
    it('boundary: route_score_should_return_minus_one_when_bindings_empty', 0, () => {
      // Arrange
      const evaluator = new WeatherRiskEvaluator();
      // Act
      const route = evaluator.evaluateRouteSuitability([]);
      // Assert
      expect(route.routeScore).assertEqual(-1);
      expect(route.riskTags.length).assertEqual(0);
    });

    it('invalid: unknown_weather_for_outdoor_should_add_unknown_risk_tag', 0, () => {
      // Arrange
      const evaluator = new WeatherRiskEvaluator();
      const event = buildEvent(0);
      // Act
      const result = evaluator.evaluateNodeSuitability(event, undefined);
      // Assert
      expect(result.riskTags.includes('UNKNOWN')).assertEqual(true);
      expect(result.score).assertEqual(90);
    });

    it('conflict: same_weather_should_score_lower_when_risk_tolerance_is_low', 0, () => {
      // Arrange
      const evaluator = new WeatherRiskEvaluator();
      const event = buildEvent(0);
      const weather: WeatherSnapshot = {
        locationKey: 'k',
        sourceType: 'PLAN_LOCATION',
        weatherTime: Date.now(),
        fetchTime: Date.now(),
        conditionCode: 'RAIN',
        conditionText: 'snow',
        temperatureCelsius: 36
      };
      const lowTolerance: WeatherUserPreference = {
        heatSensitivity: 1,
        rainSensitivity: 1,
        weatherRiskTolerance: 0
      };
      const highTolerance: WeatherUserPreference = {
        heatSensitivity: 1,
        rainSensitivity: 1,
        weatherRiskTolerance: 2
      };
      // Act
      const lowScore = evaluator.evaluateNodeSuitability(event, weather, lowTolerance);
      const highScore = evaluator.evaluateNodeSuitability(event, weather, highTolerance);
      // Assert
      expect(lowScore.score < highScore.score).assertEqual(true);
      expect(lowScore.riskTags.includes('RAIN')).assertEqual(true);
      expect(lowScore.riskTags.includes('HEAT')).assertEqual(true);
    });

    it('regression: td-20260411-route_score_should_not_exceed_100_after_improving_trend', 0, () => {
      // Arrange
      const evaluator = new WeatherRiskEvaluator();
      const collab: WeatherCollabContext = {
        dayWindows: [
          { dayOffset: 0, windowScore: 100, riskTags: [], trendTag: 'IMPROVING' }
        ],
        cityBuckets: [
          { cityKey: 'A', nodeIds: ['1'], bucketScore: 100, summaryText: 'A=100' }
        ],
        collabSummary: 'improving',
        dayWindowCount: 1,
        cityGroupCount: 1,
        cityCappedCount: 0,
        cityMissCount: 0,
        trendTag: 'IMPROVING',
        fallbackPath: ''
      };
      // Act
      const route = evaluator.evaluateRouteSuitability([
        { nodeId: '1', eventId: 1, suitabilityScore: 100, riskTags: [] }
      ], undefined, collab);
      // Assert
      expect(route.routeScore).assertEqual(100);
    });

    it('combined: route_evaluation_should_merge_binding_tags_and_day_window_tags', 0, () => {
      // Arrange
      const evaluator = new WeatherRiskEvaluator();
      const collab: WeatherCollabContext = {
        dayWindows: [
          { dayOffset: 0, windowScore: 65, riskTags: ['HEAT'], trendTag: 'WARMING' }
        ],
        cityBuckets: [
          { cityKey: 'A', nodeIds: ['1'], bucketScore: 70, summaryText: 'A=70' }
        ],
        collabSummary: 'collab',
        dayWindowCount: 1,
        cityGroupCount: 1,
        cityCappedCount: 0,
        cityMissCount: 0,
        trendTag: 'WARMING',
        fallbackPath: ''
      };
      // Act
      const route = evaluator.evaluateRouteSuitability([
        { nodeId: '1', eventId: 1, suitabilityScore: 80, riskTags: ['RAIN'] }
      ], undefined, collab);
      // Assert
      expect(route.riskTags.includes('RAIN')).assertEqual(true);
      expect(route.riskTags.includes('HEAT')).assertEqual(true);
      expect(route.summaryText.length > 0).assertEqual(true);
    });
  });
}
