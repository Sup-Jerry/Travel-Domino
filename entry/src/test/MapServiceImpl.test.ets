import { describe, it, expect } from '@ohos/hypium';
import { MapServiceImpl } from '../main/ets/model/acl/MapServiceImpl';
import { LocationInfo } from '../main/ets/model/interface/IMapService';
import { GeoCoordinate } from '../main/ets/infrastructure/services/AmapService';

function buildLocation(name: string, lat: number, lng: number, address: string = ''): LocationInfo {
  return {
    name: name,
    address: address,
    latitude: lat,
    longitude: lng
  };
}

export default function mapServiceImplTest() {
  describe('mapServiceImplTest', () => {
    it('route_should_fallback_when_api_disabled', 0, async (done: () => void) => {
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

    it('route_should_fallback_when_coordinate_invalid_and_geocode_miss', 0, async (done: () => void) => {
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

    it('bus_should_fallback_when_city_code_missing', 0, async (done: () => void) => {
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

    it('route_should_return_positive_minutes_when_mode_seconds_resolved', 0, async (done: () => void) => {
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
  });
}
