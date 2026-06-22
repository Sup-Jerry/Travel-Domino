import { describe, expect, it } from '@ohos/hypium';
import { MapServiceImpl } from '../main/ets/model/acl/MapServiceImpl';
import { LocationInfo } from '../main/ets/model/interface/IMapService';
import { GeoCoordinate } from '../main/ets/infrastructure/services/AmapService';

interface MapServicePrivateCR {
  sanitizeError(error: Object): string;
  maskCoordinate(value: number): string;
  calculateAirDistance(lat1: number, lng1: number, lat2: number, lng2: number): number;
  fallbackDurationWithError(message: string): number;
  isAmapMd5AuthError(error: Object): boolean;
  tryDrivingWebFallback(
    traceId: string,
    fromLat: number,
    fromLng: number,
    toLat: number,
    toLng: number,
    strategy?: number
  ): Promise<number | null>;
  pickLocationKeyword(location: LocationInfo): string;
  isValidCoordinate(lat: number, lng: number): boolean;
  resolveCoordinate(location: LocationInfo, role: 'origin' | 'destination'): Promise<ResolvedCoordinateCR>;
  resolveRouteEndpoints(origin: LocationInfo, destination: LocationInfo): Promise<ResolvedRouteEndpointsCR>;
}

class ErrorLikeCR {
  public message: string = '';
  public code: string = '';

  constructor(message: string, code: string = '') {
    this.message = message;
    this.code = code;
  }
}

class ResolvedCoordinateCR {
  lat: number = 0;
  lng: number = 0;
  source: string = '';
  keyword: string = '';
}

class ResolvedRouteEndpointsCR {
  fromLat: number = 0;
  fromLng: number = 0;
  toLat: number = 0;
  toLng: number = 0;
  ok: boolean = false;
}

class FakeRoutePathCR {
  private readonly duration: number;

  constructor(duration: number) {
    this.duration = duration;
  }

  getDuration(): number {
    return this.duration;
  }
}

class FakeRouteResultCR {
  private readonly paths: FakeRoutePathCR[];

  constructor(paths: FakeRoutePathCR[]) {
    this.paths = paths;
  }

  getPaths(): FakeRoutePathCR[] {
    return this.paths;
  }
}

class FakeRouteSearchCR {
  public walkCalls: number = 0;
  public busCalls: number = 0;
  public walkResult: FakeRouteResultCR = new FakeRouteResultCR([]);
  public busResult: FakeRouteResultCR = new FakeRouteResultCR([]);

  public async calculateWalkRoute(_query: Object): Promise<FakeRouteResultCR> {
    this.walkCalls += 1;
    return this.walkResult;
  }

  public async calculateBusRoute(_query: Object): Promise<FakeRouteResultCR> {
    this.busCalls += 1;
    return this.busResult;
  }
}

function locationCR(name: string, address: string = '', lat: number = 0, lng: number = 0): LocationInfo {
  const location: LocationInfo = {
    name: name,
    address: address,
    latitude: lat,
    longitude: lng
  };
  return location;
}

export default function phase2BatchCRTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCR_map_service_helpers', () => {
    it('normal: map_service_sanitize_error_should_return_error_message', 0, () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      // Act
      const message = service.sanitizeError(new Error('route_failed_cr') as Object);
      // Assert
      expect(message).assertEqual('route_failed_cr');
    });

    it('boundary: map_service_mask_coordinate_should_format_finite_and_nan_values', 0, () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      // Act
      const finite = service.maskCoordinate(121.476);
      const nanValue = service.maskCoordinate(Number.NaN);
      // Assert
      expect(finite).assertEqual('121.48');
      expect(nanValue).assertEqual('nan');
    });

    it('invalid: map_service_sanitize_error_should_fallback_for_plain_object', 0, () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      const plain = new ErrorLikeCR('plain_message_cr', 'P01');
      // Act
      const message = service.sanitizeError(plain as Object);
      // Assert
      expect(message).assertEqual('unknown_error');
    });

    it('conflict: map_service_md5_auth_error_should_detect_sdk_auth_failure_text', 0, () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      const md5Error = new ErrorLikeCR('安全码未通过', 'AMAP_AUTH');
      const normalError = new ErrorLikeCR('network_failed', 'NET');
      // Act
      const matched = service.isAmapMd5AuthError(md5Error as Object);
      const missed = service.isAmapMd5AuthError(normalError as Object);
      // Assert
      expect(matched).assertTrue();
      expect(missed).assertFalse();
    });

    it('regression: map_service_pick_location_keyword_should_prefer_trimmed_address', 0, () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      // Act
      const addressKeyword = service.pickLocationKeyword(locationCR('  name_cr  ', '  address_cr  '));
      const nameKeyword = service.pickLocationKeyword(locationCR('  name_cr  ', '   '));
      // Assert
      expect(addressKeyword).assertEqual('address_cr');
      expect(nameKeyword).assertEqual('name_cr');
    });

    it('combined: map_service_distance_coordinate_and_web_fallback_should_stay_deterministic', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      // Act
      const distance = service.calculateAirDistance(31.2304, 121.4737, 31.2304, 121.4737);
      const valid = service.isValidCoordinate(31.2304, 121.4737);
      const zeroInvalid = service.isValidCoordinate(0, 0);
      const fallback = await service.tryDrivingWebFallback('trace_cr', 31.2, 121.4, 31.3, 121.5, 0);
      // Assert
      expect(Math.round(distance)).assertEqual(0);
      expect(valid).assertTrue();
      expect(zeroInvalid).assertFalse();
      expect(fallback === null).assertTrue();
    });

    it('normal: map_service_resolve_coordinate_should_accept_valid_input_without_geocode', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      let geocodeCalls = 0;
      MapServiceImpl.setTestHooks({
        geocodeResolver: async (_address: string): Promise<GeoCoordinate | null> => {
          geocodeCalls += 1;
          return new GeoCoordinate(30.1, 120.1);
        }
      });
      // Act
      const resolved = await service.resolveCoordinate(locationCR('name_cr', 'address_cr', 31.2, 121.4), 'origin');
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(resolved.source).assertEqual('input');
      expect(resolved.lat).assertEqual(31.2);
      expect(geocodeCalls).assertEqual(0);
    });

    it('boundary: map_service_resolve_coordinate_should_geocode_trimmed_name_when_address_blank', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      const location = locationCR('  scenic_cr  ', '   ', 0, 0);
      let keyword = '';
      MapServiceImpl.setTestHooks({
        geocodeResolver: async (address: string): Promise<GeoCoordinate | null> => {
          keyword = address;
          return new GeoCoordinate(30.5, 120.5);
        }
      });
      // Act
      const resolved = await service.resolveCoordinate(location, 'destination');
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(keyword).assertEqual('scenic_cr');
      expect(resolved.source).assertEqual('geocode');
      expect(location.latitude).assertEqual(30.5);
      expect(location.longitude).assertEqual(120.5);
    });

    it('invalid: map_service_resolve_route_endpoints_should_report_not_ok_when_destination_misses_geocode', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null) as Object as MapServicePrivateCR;
      MapServiceImpl.setTestHooks({
        geocodeResolver: async (_address: string): Promise<GeoCoordinate | null> => null
      });
      // Act
      const resolved = await service.resolveRouteEndpoints(
        locationCR('origin_cr', '', 31.2, 121.4),
        locationCR('destination_cr', 'missing_cr', 0, 0)
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(resolved.ok).assertFalse();
      expect(resolved.fromLat).assertEqual(31.2);
      expect(resolved.toLat).assertEqual(0);
    });

    it('normal: map_service_get_duration_by_mode_should_use_walk_route_for_mode_four', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      const search = new FakeRouteSearchCR();
      search.walkResult = new FakeRouteResultCR([new FakeRoutePathCR(181)]);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true
      });
      // Act
      const minutes = await service.getDurationByMode(
        locationCR('walk_a_cr', '', 31.20, 121.40),
        locationCR('walk_b_cr', '', 31.21, 121.41),
        4,
        '12:00'
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(4);
      expect(search.walkCalls).assertEqual(1);
    });

    it('boundary: map_service_get_duration_by_mode_should_use_destination_city_for_bus_when_origin_missing', 0, async () => {
      // Arrange
      const service = new MapServiceImpl(null);
      const search = new FakeRouteSearchCR();
      search.busResult = new FakeRouteResultCR([new FakeRoutePathCR(599)]);
      Reflect.set(service as Object, 'routeSearch', search as Object);
      let cityCalls = 0;
      MapServiceImpl.setTestHooks({
        routeApiEnabledResolver: async (): Promise<boolean> => true,
        cityCodeResolver: async (_lat: number, _lng: number): Promise<string | null> => {
          cityCalls += 1;
          return cityCalls === 1 ? null : '021';
        }
      });
      // Act
      const minutes = await service.getDurationByMode(
        locationCR('bus_a_cr', '', 31.20, 121.40),
        locationCR('bus_b_cr', '', 31.21, 121.41),
        3,
        '13:00'
      );
      // Assert
      MapServiceImpl.setTestHooks(null);
      expect(minutes).assertEqual(10);
      expect(search.busCalls).assertEqual(1);
      expect(cityCalls).assertEqual(2);
    });
  });
}
