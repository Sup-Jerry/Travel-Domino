import { describe, expect, it } from '@ohos/hypium';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherGeoPointRequest, WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import { WeatherSnapshot } from '../main/ets/domain/services/WeatherModels';

class LiveNodeForY {
  adcode?: string = '';
  weather?: string = '';
  temperature?: string = '';
  humidity?: string = '';
  windpower?: string = '';
  reporttime?: string = '';
}

class ForecastCastNodeForY {
  dayweather?: string = '';
  daytemp?: string = '';
  nighttemp?: string = '';
}

class ForecastNodeForY {
  adcode?: string = '';
  casts?: ForecastCastNodeForY[] = [];
}

class LiveResponseForY {
  lives?: LiveNodeForY[] = [];
  forecasts?: ForecastNodeForY[] = [];
}

class TestableAmapWeatherServiceForY extends AmapWeatherService {
  weatherByCity: Map<string, WeatherInfo> = new Map<string, WeatherInfo>();
  getWeatherCallCount: number = 0;

  public async getWeather(cityName: string): Promise<WeatherInfo | null> {
    this.getWeatherCallCount++;
    return this.weatherByCity.get(cityName) ?? null;
  }
}

class StaticHooksForY {
  private readonly originGetCityCodeByCoordinate: Object;
  private readonly originGetRuntimeContext: Object;

  constructor() {
    this.originGetCityCodeByCoordinate = Reflect.get(AmapService, 'getCityCodeByCoordinate') as Object;
    this.originGetRuntimeContext = Reflect.get(AmapService, 'getRuntimeContext') as Object;
  }

  setGetCityCodeByCoordinate(
    fn: (latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(AmapService, 'getCityCodeByCoordinate', fn);
  }

  setGetRuntimeContext(fn: () => Object | null): void {
    Reflect.set(AmapService, 'getRuntimeContext', fn);
  }

  restore(): void {
    Reflect.set(AmapService, 'getCityCodeByCoordinate', this.originGetCityCodeByCoordinate);
    Reflect.set(AmapService, 'getRuntimeContext', this.originGetRuntimeContext);
  }
}

function createPointForY(
  latitude: number,
  longitude: number,
  sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION',
  forceRefresh: boolean = false,
  targetTime: number = 1700000000000
): WeatherGeoPointRequest {
  const point = {} as WeatherGeoPointRequest;
  point.latitude = latitude;
  point.longitude = longitude;
  point.sourceType = sourceType;
  point.forceRefresh = forceRefresh;
  point.targetTime = targetTime;
  return point;
}

function createWeatherForY(city: string, temp: number, condition: string): WeatherInfo {
  const info = {} as WeatherInfo;
  info.temperature = temp;
  info.condition = condition;
  info.humidity = 50;
  info.windSpeed = 2;
  info.reportTime = '2026-04-15 10:00:00';
  info.cityCode = city;
  return info;
}

export default function phase2CoreCoverageBatchYTest() {
  describe('phase2CoreCoverageBatchYTest', () => {
    it('normal: amap_weather_batch_should_dedup_points_and_write_result_by_point_key', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (lat: number, _lng: number): Promise<string | null> => {
        return `CITY_${Math.floor(lat)}`;
      });
      service.weatherByCity.set('CITY_30', createWeatherForY('CITY_30', 24, 'SUNNY'));
      const p1 = createPointForY(30.1, 120.1, 'PLAN_LOCATION', false, 1700000000000);
      const p1Dup = createPointForY(30.1, 120.1, 'PLAN_LOCATION', false, 1700000000000);
      const p2 = createPointForY(30.2, 120.2);
      // Act
      const map = await service.batchGetWeather([p1, p1Dup, p2]);
      hooks.restore();
      // Assert
      expect(map.size).assertEqual(2);
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('boundary: amap_weather_get_weather_by_geo_point_should_use_cache_when_not_force_refresh', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      let geocodeCount = 0;
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => {
        geocodeCount++;
        return 'CITY_CACHE';
      });
      service.weatherByCity.set('CITY_CACHE', createWeatherForY('CITY_CACHE', 26, 'CLOUDY'));
      // Act
      const first = await service.getWeatherByGeoPoint(31.2, 121.5, 1700000000001, 'PLAN_LOCATION', false);
      const second = await service.getWeatherByGeoPoint(31.2, 121.5, 1700000000001, 'PLAN_LOCATION', false);
      hooks.restore();
      // Assert
      expect(first !== null).assertTrue();
      expect(second !== null).assertTrue();
      expect(geocodeCount).assertEqual(1);
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('invalid: amap_weather_get_weather_by_geo_point_should_return_null_for_invalid_coordinate', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      // Act
      const info = await service.getWeatherByGeoPoint(0, 0);
      // Assert
      expect(info === null).assertTrue();
    });

    it('boundary: amap_weather_get_weather_by_geo_point_should_return_null_when_city_weather_missing', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => {
        return 'CITY_EMPTY';
      });

      // Act
      const info = await service.getWeatherByGeoPoint(31.25, 121.45, 1700000000002, 'CURRENT_LOCATION', true);
      hooks.restore();

      // Assert
      expect(info === null).assertTrue();
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('conflict: amap_weather_batch_should_limit_city_groups_when_current_location_exists', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (lat: number, _lng: number): Promise<string | null> => {
        return `CITY_${Math.floor(lat)}`;
      });
      for (let i = 1; i <= 6; i++) {
        service.weatherByCity.set(`CITY_${i}`, createWeatherForY(`CITY_${i}`, 20 + i, 'SUNNY'));
      }
      const points: WeatherGeoPointRequest[] = [];
      points.push(createPointForY(1.1, 120.1, 'CURRENT_LOCATION', false, 1700000001000));
      for (let i = 2; i <= 6; i++) {
        points.push(createPointForY(i + 0.1, 120.1, 'PLAN_LOCATION', false, 1700000001000 + i));
      }
      // Act
      const map = await service.batchGetWeather(points);
      hooks.restore();
      // Assert
      expect(map.size).assertEqual(5);
      expect(service.getWeatherCallCount).assertEqual(5);
    });

    it('boundary: amap_weather_batch_should_keep_all_city_groups_when_no_current_location_exists', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (lat: number, _lng: number): Promise<string | null> => {
        return `CITY_${Math.floor(lat)}`;
      });
      const points: WeatherGeoPointRequest[] = [];
      for (let i = 1; i <= 6; i++) {
        service.weatherByCity.set(`CITY_${i}`, createWeatherForY(`CITY_${i}`, 18 + i, 'SUNNY'));
        points.push(createPointForY(i + 0.01, 120.5, 'PLAN_LOCATION', false, 1700000002000 + i));
      }

      // Act
      const map = await service.batchGetWeather(points);
      hooks.restore();

      // Assert
      expect(map.size).assertEqual(6);
      expect(service.getWeatherCallCount).assertEqual(6);
    });

    it('regression: td-20260415-amap-weather-force-refresh-should-bypass-cache', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      let geocodeCount = 0;
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => {
        geocodeCount++;
        return 'CITY_REFRESH';
      });
      service.weatherByCity.set('CITY_REFRESH', createWeatherForY('CITY_REFRESH', 20, 'SUNNY'));
      // Act
      const first = await service.getWeatherByGeoPoint(30.3, 120.3, 1700000000200, 'PLAN_LOCATION', false);
      const second = await service.getWeatherByGeoPoint(30.3, 120.3, 1700000000200, 'PLAN_LOCATION', true);
      hooks.restore();
      // Assert
      expect(first !== null).assertTrue();
      expect(second !== null).assertTrue();
      expect(geocodeCount).assertEqual(2);
      expect(service.getWeatherCallCount).assertEqual(2);
    });

    it('combined: amap_weather_batch_should_skip_invalid_and_city_miss_points_but_keep_valid_weather', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (lat: number, _lng: number): Promise<string | null> => {
        if (lat < 0) {
          return null;
        }
        return lat > 40 ? 'CITY_OK' : 'CITY_MISS_WEATHER';
      });
      service.weatherByCity.set('CITY_OK', createWeatherForY('CITY_OK', 29, 'RAIN'));
      const invalid = createPointForY(Number.NaN, 120.1, 'PLAN_LOCATION', false, 1700000003001);
      const cityMiss = createPointForY(-1.2, 120.2, 'PLAN_LOCATION', false, 1700000003002);
      const weatherMiss = createPointForY(30.3, 120.3, 'PLAN_LOCATION', false, 1700000003003);
      const valid = createPointForY(41.4, 120.4, 'PLAN_LOCATION', false, 1700000003004);

      // Act
      const map = await service.batchGetWeather([invalid, cityMiss, weatherMiss, valid]);
      hooks.restore();

      // Assert
      expect(map.size).assertEqual(1);
      expect(service.getWeatherCallCount).assertEqual(2);
      expect(map.values().next().value.condition).assertEqual('RAIN');
    });

    it('boundary: amap_weather_batch_should_return_empty_map_when_input_is_empty', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();

      // Act
      const map = await service.batchGetWeather([]);

      // Assert
      expect(map.size).assertEqual(0);
      expect(service.getWeatherCallCount).assertEqual(0);
    });

    it('boundary: amap_weather_batch_should_reuse_cached_result_when_force_refresh_is_false', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => {
        return 'CITY_BATCH_CACHE';
      });
      service.weatherByCity.set('CITY_BATCH_CACHE', createWeatherForY('CITY_BATCH_CACHE', 28, 'CLOUDY'));
      const point = createPointForY(31.11, 121.22, 'PLAN_LOCATION', false, 1700000004001);

      // Act
      const first = await service.batchGetWeather([point]);
      const second = await service.batchGetWeather([point]);
      hooks.restore();

      // Assert
      expect(first.size).assertEqual(1);
      expect(second.size).assertEqual(1);
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('regression: amap_weather_batch_should_bypass_cached_result_when_force_refresh_is_true', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceForY();
      const hooks = new StaticHooksForY();
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => {
        return 'CITY_BATCH_REFRESH';
      });
      service.weatherByCity.set('CITY_BATCH_REFRESH', createWeatherForY('CITY_BATCH_REFRESH', 30, 'SUNNY'));
      const point = createPointForY(31.33, 121.44, 'PLAN_LOCATION', false, 1700000004002);
      const refreshPoint = createPointForY(31.33, 121.44, 'PLAN_LOCATION', true, 1700000004002);

      // Act
      const first = await service.batchGetWeather([point]);
      const second = await service.batchGetWeather([refreshPoint]);
      hooks.restore();

      // Assert
      expect(first.size).assertEqual(1);
      expect(second.size).assertEqual(1);
      expect(service.getWeatherCallCount).assertEqual(2);
    });

    it('combined: amap_weather_snapshot_roundtrip_and_get_weather_without_runtime_context_should_keep_safe_defaults', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const hooks = new StaticHooksForY();
      hooks.setGetRuntimeContext((): Object | null => {
        return null;
      });
      const weather = createWeatherForY('320100', 23, 'CLEAR');
      // Act
      const snapshot = service.toSnapshotByPoint('k_y', weather);
      const toInfo = Reflect.get(service as Object, 'snapshotToInfo') as (snapshot: WeatherSnapshot) => WeatherInfo;
      const info = toInfo(snapshot);
      const byCity = await service.getWeather('Nanjing');
      hooks.restore();
      // Assert
      expect(snapshot.locationKey).assertEqual('k_y');
      expect(info.condition).assertEqual('CLEAR');
      expect(info.cityCode ?? '').assertEqual('320100');
      expect(byCity === null).assertTrue();
    });
  });
}


