import { describe, it, expect } from '@ohos/hypium';
import { WeatherCache } from '../main/ets/infrastructure/services/WeatherCache';
import { WeatherSnapshot } from '../main/ets/domain/services/WeatherModels';

export default function weatherCacheTest() {
  describe('weatherCacheTest', () => {
    it('weather_cache_should_hit_before_ttl', 0, () => {
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

    it('weather_cache_should_expire_after_ttl', 0, () => {
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
}
