import { describe, it, expect } from '@ohos/hypium';
import { MapServiceImpl } from '../main/ets/model/acl/MapServiceImpl';
import { DriveStrategy, LocationInfo } from '../main/ets/model/interface/IMapService';
import { AmapService, GeoCoordinate } from '../main/ets/infrastructure/services/AmapService';

function buildLocation(name: string, lat: number, lng: number, address: string = ''): LocationInfo {
  return {
    name: name,
    address: address,
    latitude: lat,
    longitude: lng
  };
}

class RouteCostStub {
  private durationSeconds: number;

  constructor(durationSeconds: number) {
    this.durationSeconds = durationSeconds;
  }

  getDuration(): number {
    return this.durationSeconds;
  }
}

class RoutePathStub {
  private durationSeconds: number;
  private cost: RouteCostStub | null;

  constructor(durationSeconds: number, costDurationSeconds?: number) {
    this.durationSeconds = durationSeconds;
    this.cost = typeof costDurationSeconds === 'number' ? new RouteCostStub(costDurationSeconds) : null;
  }

  getDuration(): number {
    return this.durationSeconds;
  }

  getCost(): RouteCostStub | null {
    return this.cost;
  }
}

class RouteResultStub {
  private paths: RoutePathStub[];

  constructor(paths: RoutePathStub[]) {
    this.paths = paths;
  }

  getPaths(): RoutePathStub[] {
    return this.paths;
  }
}

class RouteSearchStub {
  walkResult: RouteResultStub = new RouteResultStub([]);
  rideResult: RouteResultStub = new RouteResultStub([]);
  busResult: RouteResultStub = new RouteResultStub([]);
  driveResult: RouteResultStub = new RouteResultStub([]);

  async calculateWalkRoute(_query: Object): Promise<RouteResultStub> {
    return this.walkResult;
  }

  async calculateRideRoute(_query: Object): Promise<RouteResultStub> {
    return this.rideResult;
  }

  async calculateBusRoute(_query: Object): Promise<RouteResultStub> {
    return this.busResult;
  }

  async calculateDriveRoute(_query: Object): Promise<RouteResultStub> {
    return this.driveResult;
  }
}

class GeoCoordinateStub {
  lat: number = 0;
  lng: number = 0;
}

class StaticHooksForMapServiceTest {
  private readonly target: Object;
  private readonly keys: string[];
  private readonly originals: Object[] = [];

  constructor(target: Object, keys: string[]) {
    this.target = target;
    this.keys = keys;
    for (let i = 0; i < keys.length; i++) {
      this.originals.push(Reflect.get(target, keys[i]) as Object);
    }
  }

  set(key: string, value: Object): void {
    Reflect.set(this.target, key, value);
  }

  restore(): void {
    for (let i = 0; i < this.keys.length; i++) {
      Reflect.set(this.target, this.keys[i], this.originals[i]);
    }
  }
}

class Md5FallbackError extends Error {
  code: number = 401;
  detail: string = 'MD5 auth failed';

  constructor() {
    super('MD5 auth failed');
  }
}

class ThrowDriveSearchStub {
  async calculateDriveRoute(_query: Object): Promise<RouteResultStub> {
    throw new Md5FallbackError();
  }
}

function attachSearchStub(service: MapServiceImpl, searchStub: RouteSearchStub): void {
  Reflect.set(service as Object, 'getSearch', (): RouteSearchStub => searchStub);
}

export default function mapServiceImplTest() {
  describe('mapServiceImplTest', () => {
    it('boundary: route_should_fallback_when_api_disabled', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => false
      });
      const service = new MapServiceImpl(null);
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('invalid: route_should_fallback_when_coordinate_invalid_and_geocode_miss', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        geocodeResolver: async (_address: string): Promise<GeoCoordinate | null> => null
      });
      const service = new MapServiceImpl(null);
      const minutes = await service.getDurationByMode(
        buildLocation('A', 0, 0, 'origin'),
        buildLocation('B', 0, 0, 'destination'),
        2,
        '09:00'
      );
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('boundary: bus_should_fallback_when_city_code_missing', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        cityCodeResolver: async (_lat: number, _lng: number): Promise<string | null> => null
      });
      const service = new MapServiceImpl(null);
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        3,
        '09:00'
      );
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('boundary: route_should_return_positive_minutes_when_mode_seconds_resolved', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        modeSecondsResolver: async (
          _mode: number,
          _fromLat: number,
          _fromLng: number,
          _toLat: number,
          _toLng: number,
          _startTime: string
        ): Promise<number> => 95
      });
      const service = new MapServiceImpl(null);
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(2);
      done();
    });

    it('invalid: route_should_fallback_when_mode_seconds_hook_returns_zero', 0, async (done: () => void) => {
      // Arrange
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        modeSecondsResolver: async (): Promise<number> => 0
      });
      const service = new MapServiceImpl(null);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('normal: route_should_use_geocode_success_before_mode_seconds_hook', 0, async (done: () => void) => {
      // Arrange
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        geocodeResolver: async (address: string): Promise<GeoCoordinate | null> => {
          if (address === 'origin-address') {
            const coordinate = new GeoCoordinateStub();
            coordinate.lat = 30.1111;
            coordinate.lng = 120.2222;
            return coordinate as GeoCoordinate;
          }
          return null;
        },
        modeSecondsResolver: async (
          _mode: number,
          fromLat: number,
          fromLng: number,
          _toLat: number,
          _toLng: number,
          _startTime: string
        ): Promise<number> => {
          expect(fromLat).assertEqual(30.1111);
          expect(fromLng).assertEqual(120.2222);
          return 61;
        }
      });
      const service = new MapServiceImpl(null);
      const origin = buildLocation('A', 0, 0, 'origin-address');
      const destination = buildLocation('B', 31.2200, 121.4900);

      // Act
      const minutes = await service.getDurationByMode(origin, destination, 2, '09:00');

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(origin.latitude ?? 0).assertEqual(30.1111);
      expect(origin.longitude ?? 0).assertEqual(120.2222);
      expect(minutes).assertEqual(2);
      done();
    });

    it('boundary: walk_mode_should_return_minutes_when_walk_path_exists', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.walkResult = new RouteResultStub([new RoutePathStub(301)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2310, 121.4745),
        0,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(6);
      done();
    });

    it('conflict: bus_mode_should_fallback_when_path_empty_even_with_city_codes', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.busResult = new RouteResultStub([]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        cityCodeResolver: async (_lat: number, _lng: number): Promise<string | null> => '310000'
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        3,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('regression: drive_mode_should_use_cost_duration_when_primary_duration_is_zero', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([new RoutePathStub(0, 181)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(4);
      done();
    });

    it('invalid: get_drive_duration_should_fallback_when_resolved_coordinates_remain_invalid', 0, async (done: () => void) => {
      // Arrange
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        geocodeResolver: async (_address: string): Promise<GeoCoordinate | null> => null
      });
      const service = new MapServiceImpl(null);

      // Act
      const minutes = await service.getDriveDuration(
        buildLocation('A', 0, 0, 'origin'),
        buildLocation('B', 0, 0, 'destination'),
        DriveStrategy.FASTEST
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('combined: get_drive_duration_should_map_strategy_and_use_cost_duration_fallback', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([new RoutePathStub(0, 120)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDriveDuration(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        DriveStrategy.ECONOMICAL
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(2);
      done();
    });

    it('normal: ride_mode_should_return_minutes_when_ride_path_exists', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.rideResult = new RouteResultStub([new RoutePathStub(421)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2310, 121.4745),
        1,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(8);
      done();
    });

    it('normal: bus_mode_should_return_minutes_when_bus_path_exists', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.busResult = new RouteResultStub([new RoutePathStub(901)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        cityCodeResolver: async (_lat: number, _lng: number): Promise<string | null> => '310000'
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        3,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(16);
      done();
    });

    it('boundary: drive_mode_should_fallback_when_drive_path_is_empty', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('boundary: get_drive_duration_should_fallback_when_api_is_disabled', 0, async (done: () => void) => {
      // Arrange
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => false
      });
      const service = new MapServiceImpl(null);

      // Act
      const minutes = await service.getDriveDuration(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        DriveStrategy.AVOID_CONGESTION
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('regression: get_drive_duration_should_return_minutes_when_drive_path_duration_exists', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([new RoutePathStub(301)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDriveDuration(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        DriveStrategy.AVOID_CONGESTION
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(6);
      done();
    });

    it('invalid: route_should_fallback_when_invalid_coordinate_has_no_keyword', 0, async (done: () => void) => {
      // Arrange
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('', 0, 0, ''),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('normal: route_should_use_amap_geocode_when_test_hook_missing', 0, async (done: () => void) => {
      // Arrange
      const amapHooks = new StaticHooksForMapServiceTest(AmapService as Object, ['getGeocode']);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        modeSecondsResolver: async (
          _mode: number,
          fromLat: number,
          fromLng: number,
          _toLat: number,
          _toLng: number,
          _startTime: string
        ): Promise<number> => {
          expect(fromLat).assertEqual(30.2222);
          expect(fromLng).assertEqual(120.3333);
          return 121;
        }
      });
      amapHooks.set('getGeocode', async (keyword: string): Promise<GeoCoordinate | null> => {
        expect(keyword).assertEqual('origin-by-amap');
        const coordinate = new GeoCoordinateStub();
        coordinate.lat = 30.2222;
        coordinate.lng = 120.3333;
        return coordinate as GeoCoordinate;
      });
      const service = new MapServiceImpl(null);
      const origin = buildLocation('A', 0, 0, 'origin-by-amap');

      // Act
      const minutes = await service.getDurationByMode(
        origin,
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      amapHooks.restore();
      MapServiceImpl.setTestHooks(null);
      expect(origin.latitude ?? 0).assertEqual(30.2222);
      expect(minutes).assertEqual(3);
      done();
    });

    it('normal: bus_should_use_amap_city_code_when_test_hook_missing', 0, async (done: () => void) => {
      // Arrange
      const amapHooks = new StaticHooksForMapServiceTest(AmapService as Object, ['getCityCodeByCoordinate']);
      const searchStub = new RouteSearchStub();
      searchStub.busResult = new RouteResultStub([new RoutePathStub(601)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      amapHooks.set('getCityCodeByCoordinate', async (): Promise<string | null> => '310000');
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        3,
        '09:00'
      );

      // Assert
      amapHooks.restore();
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(11);
      done();
    });

    it('boundary: walk_mode_should_fallback_when_walk_path_is_empty', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.walkResult = new RouteResultStub([]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2310, 121.4745),
        4,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('boundary: ride_mode_should_fallback_when_ride_path_is_empty', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.rideResult = new RouteResultStub([]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2310, 121.4745),
        1,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('boundary: drive_mode_should_return_minutes_when_primary_duration_is_positive_without_cost_fallback', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([new RoutePathStub(241)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(5);
      done();
    });

    it('regression: drive_mode_should_use_positive_web_fallback_when_sdk_seconds_are_zero', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([new RoutePathStub(0)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);
      Reflect.set(service as Object, 'tryDrivingWebFallback', async (): Promise<number | null> => 9);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        2,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(9);
      done();
    });

    it('invalid: route_should_fallback_when_context_missing_and_search_must_be_created', 0, async (done: () => void) => {
      // Arrange
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);

      // Act
      const minutes = await service.getDurationByMode(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2310, 121.4745),
        4,
        '09:00'
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('boundary: get_drive_duration_should_fallback_when_path_duration_zero_and_cost_missing', 0, async (done: () => void) => {
      // Arrange
      const searchStub = new RouteSearchStub();
      searchStub.driveResult = new RouteResultStub([new RoutePathStub(0)]);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      const service = new MapServiceImpl(null);
      attachSearchStub(service, searchStub);

      // Act
      const minutes = await service.getDriveDuration(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        DriveStrategy.FASTEST
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(60);
      done();
    });

    it('regression: get_drive_duration_should_use_web_fallback_when_md5_error_occurs', 0, async (done: () => void) => {
      // Arrange
      const service = new MapServiceImpl(null);
      Reflect.set(service as Object, 'getSearch', (): ThrowDriveSearchStub => new ThrowDriveSearchStub());
      Reflect.set(service as Object, 'tryDrivingWebFallback', async (): Promise<number | null> => 8);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });

      // Act
      const minutes = await service.getDriveDuration(
        buildLocation('A', 31.2304, 121.4737),
        buildLocation('B', 31.2200, 121.4900),
        DriveStrategy.FASTEST
      );

      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(8);
      done();
    });
  });
}
