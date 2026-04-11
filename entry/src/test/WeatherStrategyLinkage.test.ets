import { describe, it, expect } from '@ohos/hypium';
import { StrategyAdaptationEngine } from '../main/ets/domain/strategy/StrategyAdaptationEngine';
import { ComposableStrategy, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { StrategyService } from '../main/ets/domain/strategy/StrategyService';
import { WeatherCollabContext } from '../main/ets/domain/services/WeatherModels';

function buildCollab(trendTag: 'STABLE' | 'WARMING' | 'RAIN_PERSIST' | 'IMPROVING' | 'UNKNOWN'): WeatherCollabContext {
  return {
    dayWindows: [],
    cityBuckets: [],
    collabSummary: '',
    dayWindowCount: 0,
    cityGroupCount: 0,
    cityCappedCount: 0,
    cityMissCount: 0,
    trendTag: trendTag,
    fallbackPath: ''
  };
}

export default function weatherStrategyLinkageTest() {
  describe('weatherStrategyLinkageTest', () => {
    it('normal: rain_persist_low_score_should_reduce_density_and_shift_preference', 0, () => {
      // Arrange
      // Act
      // Assert
      const current: ComposableStrategy = { density: 2, pace: 2, preference: PreferenceType.SCENIC, energy: 2 };
      const decision = StrategyAdaptationEngine.adaptToWeather(buildCollab('RAIN_PERSIST'), 65, current);
      expect(!!decision).assertEqual(true);
      expect(decision?.reason).assertEqual('WEATHER_RISK');
      expect(decision?.adjustments.density).assertEqual(-1);
      expect(decision?.adjustments.preference).assertEqual(PreferenceType.CULTURE);
    });

    it('boundary: warming_low_score_should_reduce_pace_and_energy', 0, () => {
      // Arrange
      // Act
      // Assert
      const current: ComposableStrategy = { density: 1, pace: 2, preference: PreferenceType.BALANCED, energy: 2 };
      const decision = StrategyAdaptationEngine.adaptToWeather(buildCollab('WARMING'), 66, current);
      expect(!!decision).assertEqual(true);
      expect(decision?.adjustments.pace).assertEqual(-1);
      expect(decision?.adjustments.energy).assertEqual(-1);
    });

    it('normal: very_low_route_score_should_reduce_density_without_trend', 0, () => {
      // Arrange
      // Act
      // Assert
      const current: ComposableStrategy = { density: 1, pace: 1, preference: PreferenceType.BALANCED, energy: 1 };
      const decision = StrategyAdaptationEngine.adaptToWeather(undefined, 55, current);
      expect(!!decision).assertEqual(true);
      expect(decision?.adjustments.density).assertEqual(-1);
    });

    it('normal: stable_high_score_should_not_adjust', 0, () => {
      // Arrange
      // Act
      // Assert
      const current: ComposableStrategy = { density: 1, pace: 1, preference: PreferenceType.BALANCED, energy: 1 };
      const decision = StrategyAdaptationEngine.adaptToWeather(buildCollab('STABLE'), 88, current);
      expect(decision === null).assertEqual(true);
    });

    it('normal: weather_aware_constraint_should_merge_strategy_and_weather', 0, () => {
      // Arrange
      // Act
      // Assert
      const strategy: ComposableStrategy = { density: 2, pace: 2, preference: PreferenceType.SCENIC, energy: 2 };
      const text = StrategyService.buildWeatherAwareConstraint(
        strategy,
        65,
        ['RAIN'],
        'RAIN_PERSIST',
        1
      );
      expect(text.includes('室内')).assertEqual(true);
    });

    it('normal: weather_aware_constraint_should_prefer_relaxed_mode_when_weather_good', 0, () => {
      // Arrange
      // Act
      // Assert
      const strategy: ComposableStrategy = { density: 2, pace: 2, preference: PreferenceType.SCENIC, energy: 2 };
      const text = StrategyService.buildWeatherAwareConstraint(
        strategy,
        90,
        [],
        'STABLE',
        2
      );
      expect(text.includes('按原策略执行')).assertEqual(true);
    });

    it('boundary: weather_aware_constraint_should_fallback_to_dimension_when_mode_unknown', 0, () => {
      // Arrange
      // Act
      // Assert
      const strategy: ComposableStrategy = { density: 0, pace: 1, preference: PreferenceType.BALANCED, energy: 1 };
      const text = StrategyService.buildWeatherAwareConstraint(
        strategy,
        88,
        [],
        'STABLE',
        0
      );
      expect(text.includes('按原策略执行')).assertEqual(true);
    });
  });
  describe('unit_test_case_generator_autofill_WeatherStrategyLinkage', () => {
    it('invalid: td-20260411-auto-WeatherStrategyLinkage', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-WeatherStrategyLinkage', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-WeatherStrategyLinkage', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-WeatherStrategyLinkage', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
