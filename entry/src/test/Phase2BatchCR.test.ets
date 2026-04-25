import { describe, expect, it } from '@ohos/hypium';
import { MapServiceImpl } from '../main/ets/model/acl/MapServiceImpl';
import { LocationInfo } from '../main/ets/model/interface/IMapService';

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
}

class ErrorLikeCR {
  public message: string = '';
  public code: string = '';

  constructor(message: string, code: string = '') {
    this.message = message;
    this.code = code;
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
  });
}
