import { describe, it, expect } from '@ohos/hypium';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherGeoPointRequest, WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';

class MockCityWeatherService extends AmapWeatherService {
  public async batchGetWeather(points: WeatherGeoPointRequest[]): Promise<Map<string, WeatherInfo>> {
    const result = new Map<string, WeatherInfo>();
    points.forEach((point: WeatherGeoPointRequest) => {
      const key = AmapWeatherService.toPointKey(point.latitude, point.longitude, point.targetTime);
      const cityCode = `CITY_${Math.floor(point.latitude)}`;
      result.set(key, {
        temperature: 24,
        condition: '晴',
        humidity: 40,
        windSpeed: 1,
        cityCode: cityCode
      });
    });
    return result;
  }
}

class MockAddressFallbackWeatherService extends AmapWeatherService {
  public async batchGetWeather(points: WeatherGeoPointRequest[]): Promise<Map<string, WeatherInfo>> {
    const result = new Map<string, WeatherInfo>();
    points.forEach((point: WeatherGeoPointRequest) => {
      const key = AmapWeatherService.toPointKey(point.latitude, point.longitude, point.targetTime);
      result.set(key, {
        temperature: 26,
        condition: '多云',
        humidity: 45,
        windSpeed: 2,
        cityCode: ''
      });
    });
    return result;
  }
}

function buildEvent(id: number, lat: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.dynamic_start_time = 1_700_000_000_000 + id * 60_000;
  event.latitude = lat;
  event.longitude = 120.11;
  event.name = `节点_${id}`;
  return event;
}

function buildAddressEvent(id: number, lat: number, address: string, dayOffset: number = 0): EventEntity {
  const event = buildEvent(id, lat);
  event.address = address;
  event.dynamic_day_offset = dayOffset;
  return event;
}

export default function weatherCityCapTest() {
  describe('weatherCityCapTest', () => {
    it('boundary: weather_city_bucket_should_cap_to_five_groups', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const builder = new WeatherContextBuilder(new MockCityWeatherService());
      const events: EventEntity[] = [];
      for (let i = 1; i <= 6; i++) {
        events.push(buildEvent(i, i));
      }
      const result = await builder.buildPlanningContext(events, undefined, { enableMultiDay: false, enableMultiCity: true }, 'CONFIRMED');
      const collab = result.context.collabContext;
      expect(!!collab).assertEqual(true);
      expect((collab?.cityGroupCount ?? 0) <= 5).assertEqual(true);
      expect(collab?.cityCappedCount).assertEqual(1);
      done();
    });
  });
  describe('unit_test_case_generator_autofill_WeatherCityCap', () => {
    it('normal: weather_context_should_group_same_city_codes_into_shared_bucket', 0, async (done: () => void) => {
      // Arrange
      const builder = new WeatherContextBuilder(new MockCityWeatherService());
      const events: EventEntity[] = [
        buildEvent(11, 31.1),
        buildEvent(12, 31.8),
        buildEvent(13, 32.4)
      ];

      // Act
      const result = await builder.buildPlanningContext(events, undefined, { enableMultiDay: false, enableMultiCity: true }, 'PLANNING');
      const collab = result.context.collabContext;

      // Assert
      expect(collab?.cityGroupCount).assertEqual(2);
      expect(collab?.cityBuckets.length).assertEqual(2);
      expect(collab?.cityBuckets[0].nodeIds.length).assertEqual(2);
      expect(collab?.fallbackPath).assertEqual('DAY_DISABLED');
      done();
    });

    it('invalid: weather_context_should_ignore_events_with_invalid_geo_or_status', 0, async (done: () => void) => {
      // Arrange
      const builder = new WeatherContextBuilder(new MockCityWeatherService());
      const disabled = buildEvent(21, 21.1);
      disabled.status = 0;
      const zeroPoint = buildEvent(22, 0);
      zeroPoint.longitude = 0;
      const missingLat = buildEvent(23, Number.NaN);

      // Act
      const result = await builder.buildPlanningContext([disabled, zeroPoint, missingLat], undefined,
        { enableMultiDay: false, enableMultiCity: true }, 'PLANNING');
      const collab = result.context.collabContext;

      // Assert
      expect(result.sourceEvents.length).assertEqual(0);
      expect(result.context.bindings.length).assertEqual(0);
      expect(collab?.cityGroupCount).assertEqual(0);
      expect(collab?.collabSummary).assertEqual('');
      done();
    });

    it('conflict: weather_context_should_fallback_to_city_name_from_address_when_city_code_missing', 0,
      async (done: () => void) => {
      // Arrange
      const builder = new WeatherContextBuilder(new MockAddressFallbackWeatherService());
      const events: EventEntity[] = [
        buildAddressEvent(31, 31.1, '上海市徐汇区漕溪北路'),
        buildAddressEvent(32, 31.2, '上海市浦东新区世纪大道')
      ];

      // Act
      const result = await builder.buildPlanningContext(events, undefined, { enableMultiDay: false, enableMultiCity: true }, 'CONFIRMED');
      const collab = result.context.collabContext;

      // Assert
      expect(collab?.cityGroupCount).assertEqual(1);
      expect(collab?.cityMissCount).assertEqual(0);
      expect(collab?.cityBuckets[0].cityKey).assertEqual('上海市');
      done();
    });

    it('regression: weather_context_should_mark_city_fallback_point_when_city_code_and_address_are_missing', 0,
      async (done: () => void) => {
      // Arrange
      const builder = new WeatherContextBuilder(new MockAddressFallbackWeatherService());
      const unnamedCityEvent = buildAddressEvent(41, 41.3, '   ');

      // Act
      const result = await builder.buildPlanningContext([unnamedCityEvent], undefined,
        { enableMultiDay: false, enableMultiCity: true }, 'CONFIRMED');
      const collab = result.context.collabContext;

      // Assert
      expect(collab?.cityMissCount).assertEqual(1);
      expect(collab?.cityBuckets[0].cityKey).assertEqual('POINT_41');
      expect(collab?.fallbackPath).assertEqual('DAY_DISABLED|CITY_FALLBACK_POINT');
      done();
    });

    it('combined: weather_context_should_coordinate_multi_day_and_multi_city_collab_summary', 0,
      async (done: () => void) => {
      // Arrange
      const builder = new WeatherContextBuilder(new MockCityWeatherService());
      const events: EventEntity[] = [
        buildAddressEvent(51, 31.1, '上海市黄浦区', 0),
        buildAddressEvent(52, 32.2, '南京市玄武区', 1)
      ];

      // Act
      const result = await builder.buildPlanningContext(events, undefined, { enableMultiDay: true, enableMultiCity: true }, 'CONFIRMED');
      const collab = result.context.collabContext;

      // Assert
      expect(collab?.dayWindowCount).assertEqual(2);
      expect(collab?.cityGroupCount).assertEqual(2);
      expect(collab?.trendTag).assertEqual('STABLE');
      expect(collab?.collabSummary).assertEqual('2城2日：平稳');
      expect(collab?.fallbackPath).assertEqual('');
      done();
    });
  });
}

