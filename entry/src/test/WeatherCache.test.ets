import { describe, it, expect } from '@ohos/hypium';
import { WeatherCache } from '../main/ets/infrastructure/services/WeatherCache';
import { WeatherSnapshot } from '../main/ets/domain/services/WeatherModels';

export default function weatherCacheTest() {
  describe('weatherCacheTest', () => {
    it('boundary: weather_cache_should_hit_before_ttl', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const key = cache.buildCacheKey('PLAN_LOCATION', '31.230:121.470:123');
      const snapshot: WeatherSnapshot = {
        locationKey: '31.230:121.470:123',
        sourceType: 'PLAN_LOCATION',
        weatherTime: Date.now(),
        fetchTime: Date.now(),
        conditionCode: 'SUNNY',
        conditionText: '晴',
        temperatureCelsius: 26
      };

      cache.set(key, snapshot);
      const hit = cache.get(key, 60_000);
      expect(!!hit).assertEqual(true);
      expect(hit?.conditionText).assertEqual('晴');
    });

    it('boundary: weather_cache_should_expire_after_ttl', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const key = cache.buildCacheKey('PLAN_LOCATION', '31.230:121.470:123');
      const snapshot: WeatherSnapshot = {
        locationKey: '31.230:121.470:123',
        sourceType: 'PLAN_LOCATION',
        weatherTime: Date.now(),
        fetchTime: Date.now(),
        conditionCode: 'SUNNY',
        conditionText: '晴',
        temperatureCelsius: 26
      };

      cache.set(key, snapshot);
      const expired = cache.get(key, -1);
      expect(expired === null).assertEqual(true);
    });
  });
  describe('unit_test_case_generator_autofill_WeatherCache', () => {
    it('normal: weather_cache_should_build_cache_key_with_source_prefix', 0, () => {
      // Arrange
      const cache = new WeatherCache();

      // Act
      const key = cache.buildCacheKey('CURRENT_LOCATION', '31.230:121.470:123');

      // Assert
      expect(key).assertEqual('weather:CURRENT_LOCATION:31.230:121.470:123');
    });

    it('invalid: build_location_key_should_fallback_for_non_finite_coordinates', 0, () => {
      // Arrange
      const bucketTs = 2 * 60 * 60 * 1000;

      // Act
      const key = WeatherCache.buildLocationKey(Number.NaN, Number.POSITIVE_INFINITY, bucketTs);

      // Assert
      expect(key).assertEqual('0.000:0.000:2');
    });

    it('conflict: weather_cache_should_return_latest_snapshot_when_same_key_is_overwritten', 0, () => {
      // Arrange
      const cache = new WeatherCache();
      const key = cache.buildCacheKey('PLAN_LOCATION', '31.230:121.470:123');
      const firstSnapshot: WeatherSnapshot = {
        locationKey: '31.230:121.470:123',
        sourceType: 'PLAN_LOCATION',
        weatherTime: 1,
        fetchTime: 1,
        conditionCode: 'RAIN',
        conditionText: 'rain',
        temperatureCelsius: 18
      };
      const secondSnapshot: WeatherSnapshot = {
        locationKey: '31.230:121.470:123',
        sourceType: 'PLAN_LOCATION',
        weatherTime: 2,
        fetchTime: 2,
        conditionCode: 'SUNNY',
        conditionText: 'sunny',
        temperatureCelsius: 28
      };

      // Act
      cache.set(key, firstSnapshot);
      cache.set(key, secondSnapshot);
      const hit = cache.get(key, 60_000);

      // Assert
      expect(hit?.conditionCode).assertEqual('SUNNY');
      expect(hit?.temperatureCelsius).assertEqual(28);
    });

    it('regression: weather_cache_should_return_null_for_missing_key_without_throwing', 0, () => {
      // Arrange
      const cache = new WeatherCache();

      // Act
      const missing = cache.get('weather:PLAN_LOCATION:not_found', 60_000);

      // Assert
      expect(missing === null).assertTrue();
    });

    it('combined: weather_cache_cleanup_should_remove_multiple_expired_entries', 0, () => {
      // Arrange
      const cache = new WeatherCache();
      const firstKey = cache.buildCacheKey('PLAN_LOCATION', '31.230:121.470:123');
      const secondKey = cache.buildCacheKey('CURRENT_LOCATION', '30.100:120.200:456');
      const firstSnapshot: WeatherSnapshot = {
        locationKey: '31.230:121.470:123',
        sourceType: 'PLAN_LOCATION',
        weatherTime: 1,
        fetchTime: 1,
        conditionCode: 'CLOUDY',
        conditionText: 'cloudy',
        temperatureCelsius: 20
      };
      const secondSnapshot: WeatherSnapshot = {
        locationKey: '30.100:120.200:456',
        sourceType: 'CURRENT_LOCATION',
        weatherTime: 2,
        fetchTime: 2,
        conditionCode: 'WIND',
        conditionText: 'wind',
        temperatureCelsius: 22
      };

      // Act
      cache.set(firstKey, firstSnapshot);
      cache.set(secondKey, secondSnapshot);
      cache.cleanup(-1);
      const firstHit = cache.get(firstKey, 60_000);
      const secondHit = cache.get(secondKey, 60_000);

      // Assert
      expect(firstHit === null).assertTrue();
      expect(secondHit === null).assertTrue();
    });
  });
}
