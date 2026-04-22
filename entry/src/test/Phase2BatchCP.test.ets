import { describe, expect, it } from '@ohos/hypium';
import { TrafficEngine } from '../main/ets/infrastructure/services/TrafficEngine';
import { DriveStrategy, IMapService, LocationInfo } from '../main/ets/model/interface/IMapService';

interface TrafficEnginePrivateCP {
  fetchAmapTrafficAsync(from: LocationInfo, to: LocationInfo, strategy: DriveStrategy, key: string): Promise<void>;
  markTransientFailure(key: string, reason: string): void;
}

class MapServiceStubCP implements IMapService {
  public driveDuration: number = 16;
  public driveError: string = '';
  public driveCalls: number = 0;

  public async getLocationInfo(_keyword: string): Promise<LocationInfo[]> {
    return [];
  }

  public async calculateCommute(_from: string, _to: string): Promise<number> {
    return 0;
  }

  public async getDriveDuration(
    _origin: LocationInfo,
    _destination: LocationInfo,
    _strategy: DriveStrategy
  ): Promise<number> {
    this.driveCalls += 1;
    if (this.driveError.length > 0) {
      throw new Error(this.driveError);
    }
    return this.driveDuration;
  }

  public async getDurationByMode(
    _origin: LocationInfo,
    _destination: LocationInfo,
    _mode: number,
    _startTime?: string
  ): Promise<number> {
    return 0;
  }
}

function resetTrafficEngineCP(): TrafficEngine {
  Reflect.set(Object(TrafficEngine), 'instance', null);
  return TrafficEngine.getInstance();
}

function locationCP(name: string): LocationInfo {
  return {
    name: name,
    latitude: 31.23,
    longitude: 121.47
  };
}

export default function phase2BatchCPTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCP_traffic_engine_drive_fetch', () => {
    it('normal: traffic_drive_fetch_should_cache_duration_and_clear_transient_failure', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineCP();
      const service = new MapServiceStubCP();
      const key = 'drive_success_cp';
      Reflect.set(engine as Object, 'mapService', service as Object);
      (Reflect.get(engine as Object, 'transientFailureUntil') as Map<string, number>).set(key, Date.now() + 10_000);

      // Act
      await (engine as Object as TrafficEnginePrivateCP).fetchAmapTrafficAsync(locationCP('A'), locationCP('B'), DriveStrategy.FASTEST, key);

      // Assert
      expect(service.driveCalls).assertEqual(1);
      expect((Reflect.get(engine as Object, 'cache') as Map<string, number>).get(key)).assertEqual(16);
      expect((Reflect.get(engine as Object, 'transientFailureUntil') as Map<string, number>).has(key)).assertFalse();
    });

    it('boundary: traffic_drive_fetch_should_skip_when_same_key_is_inflight', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineCP();
      const service = new MapServiceStubCP();
      const key = 'drive_inflight_cp';
      Reflect.set(engine as Object, 'mapService', service as Object);
      (Reflect.get(engine as Object, 'cache') as Map<string, number>).set(key, -1);

      // Act
      await (engine as Object as TrafficEnginePrivateCP).fetchAmapTrafficAsync(locationCP('A'), locationCP('B'), DriveStrategy.FASTEST, key);

      // Assert
      expect(service.driveCalls).assertEqual(0);
      expect((Reflect.get(engine as Object, 'cache') as Map<string, number>).get(key)).assertEqual(-1);
    });

    it('invalid: traffic_drive_fetch_should_mark_transient_failure_when_service_missing', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineCP();
      const key = 'drive_no_service_cp';
      Reflect.set(engine as Object, 'mapService', null);

      // Act
      await (engine as Object as TrafficEnginePrivateCP).fetchAmapTrafficAsync(locationCP('A'), locationCP('B'), DriveStrategy.FASTEST, key);

      // Assert
      expect((Reflect.get(engine as Object, 'cache') as Map<string, number>).has(key)).assertFalse();
      const blockedUntil = (Reflect.get(engine as Object, 'transientFailureUntil') as Map<string, number>).get(key) ?? 0;
      expect(blockedUntil > Date.now()).assertTrue();
    });

    it('regression: traffic_drive_fetch_should_delete_loading_cache_and_mark_failure_on_exception', 0, async () => {
      // Arrange
      const engine = resetTrafficEngineCP();
      const service = new MapServiceStubCP();
      service.driveError = 'drive_failed_cp';
      const key = 'drive_throw_cp';
      Reflect.set(engine as Object, 'mapService', service as Object);

      // Act
      await (engine as Object as TrafficEnginePrivateCP).fetchAmapTrafficAsync(locationCP('A'), locationCP('B'), DriveStrategy.AVOID_CONGESTION, key);

      // Assert
      expect(service.driveCalls).assertEqual(1);
      expect((Reflect.get(engine as Object, 'cache') as Map<string, number>).has(key)).assertFalse();
      const blockedUntil = (Reflect.get(engine as Object, 'transientFailureUntil') as Map<string, number>).get(key) ?? 0;
      expect(blockedUntil > Date.now()).assertTrue();
    });

    it('combined: traffic_mark_transient_failure_should_set_future_block_window', 0, () => {
      // Arrange
      const engine = resetTrafficEngineCP();
      const key = 'manual_mark_cp';

      // Act
      (engine as Object as TrafficEnginePrivateCP).markTransientFailure(key, 'manual_test');

      // Assert
      const blockedUntil = (Reflect.get(engine as Object, 'transientFailureUntil') as Map<string, number>).get(key) ?? 0;
      expect(blockedUntil > Date.now()).assertTrue();
    });
  });
}
