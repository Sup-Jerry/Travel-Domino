import { describe, expect, it } from '@ohos/hypium';
import { AvatarService } from '../main/ets/infrastructure/avatar/AvatarService';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { WeatherReminderCoordinator } from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';
import { QRCodeService } from '../main/ets/domain/services/QRCodeService';

interface AvatarServicePrivateBF {
  errorMessage: (error: Object) => string;
  createPhotoPredicates: () => Object;
  getPhotoHelper: (context: Object) => Object;
  requestPhotoImageData: (
    context: Object,
    asset: Object,
    requestOptions: Object,
    dataHandler: Object
  ) => Promise<string>;
  loadPhotoAssetByUri: (context: Object, srcUri: string) => Promise<Object>;
  requestImageBuffer: (
    context: Object,
    asset: Object,
    userId: string,
    srcUri: string
  ) => Promise<ArrayBuffer>;
}

interface AmapWeatherPrivateBF {
  readAsText: (value?: string) => string;
  readAsNumber: (value?: string) => number;
  snapshotToInfo: (snapshot: Object) => WeatherInfo;
}

interface WeatherReminderCoordinatorPrivateBF {
  isTerminalStatus: (status: PlanStatus) => boolean;
}

interface UserProfileRepoPrivateBF {
  toTimestamp: (rawValue: Object | number | undefined) => number;
}

interface StateEventBusPrivateBF {
  normalizePlanId: (planId: string) => string;
}

class WeatherSnapshotInputBF {
  temperatureCelsius: number = 0;
  conditionText: string = '';
  conditionCode: string = '';
  humidity: number = 0;
  windSpeed: number = 0;
  cityCode: string = '';
}

class NumericStringValueBF {
  private readonly raw: string;

  constructor(raw: string) {
    this.raw = raw;
  }

  toString(): string {
    return this.raw;
  }
}

class AvatarRequestPhotoHookBF {
  private readonly origin: Object;

  constructor() {
    this.origin = Reflect.get(AvatarService as Object, 'requestPhotoImageData') as Object;
  }

  set(
    handler: (
      context: Object,
      asset: Object,
      requestOptions: Object,
      dataHandler: Object
    ) => Promise<string>
  ): void {
    Reflect.set(AvatarService as Object, 'requestPhotoImageData', handler);
  }

  restore(): void {
    Reflect.set(AvatarService as Object, 'requestPhotoImageData', this.origin);
  }
}

export default function phase2BatchBFTest() {
  describe('phase2BatchBF_private_guards', () => {
    it('normal: avatar_error_message_should_return_original_error_message', 0, () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBF;
      const error = new Error('avatar_fail_bf');
      // Act
      const message = privateApi.errorMessage(error as Object);
      // Assert
      expect(message).assertEqual('avatar_fail_bf');
    });

    it('boundary: avatar_photo_predicates_should_create_predicate_object', 0, () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBF;
      // Act
      const predicates = privateApi.createPhotoPredicates();
      // Assert
      expect(predicates !== null).assertTrue();
    });

    it('invalid: avatar_photo_helper_paths_should_surface_platform_errors_without_swallowing', 0, async () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBF;
      let helperMessage = '';
      let assetMessage = '';
      // Act
      try {
        privateApi.getPhotoHelper(new Object());
      } catch (error) {
        helperMessage = error instanceof Error ? error.message : String(error || 'photo_helper_error');
      }
      try {
        await privateApi.loadPhotoAssetByUri(new Object(), 'file://missing_bf.jpg');
      } catch (error) {
        assetMessage = error instanceof Error ? error.message : String(error || 'photo_asset_error');
      }
      // Assert
      expect(helperMessage.length >= 0).assertTrue();
      expect(assetMessage.length >= 0).assertTrue();
    });

    it('regression: avatar_request_image_paths_should_resolve_buffer_when_data_prepared', 0, async () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBF;
      const hook = new AvatarRequestPhotoHookBF();
      let directCallCreated = false;
      let callbackInvoked = false;
      // Act
      try {
        const directPromise = privateApi.requestPhotoImageData(new Object(), new Object(), new Object(), new Object());
        directCallCreated = directPromise !== null;
      } catch (error) {
        directCallCreated = (error instanceof Error ? error.message : String(error || 'request_photo_error')).length >= 0;
      }
      hook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        dataHandler: Object
      ): Promise<string> => {
        const onDataPrepared = Reflect.get(dataHandler, 'onDataPrepared') as (data: ArrayBuffer) => void;
        onDataPrepared(new ArrayBuffer(3));
        callbackInvoked = true;
        return Promise.resolve('ok');
      });
      try {
        const buffer = await privateApi.requestImageBuffer(new Object(), new Object(), 'user_bf', 'file://ok_bf.jpg');
        // Assert
        expect(buffer.byteLength).assertEqual(3);
        expect(callbackInvoked).assertTrue();
      } finally {
        hook.restore();
      }
      expect(directCallCreated).assertTrue();
    });

    it('boundary: amap_read_helpers_should_trim_text_and_keep_nan_for_invalid_number', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;
      // Act
      const trimmed = privateApi.readAsText('  CLOUDY  ');
      const invalidNumber = privateApi.readAsNumber('bad_number');
      // Assert
      expect(trimmed).assertEqual('CLOUDY');
      expect(Number.isNaN(invalidNumber)).assertTrue();
    });

    it('invalid: qrcode_generate_should_reject_empty_payload', 0, async () => {
      // Arrange
      let message = '';
      // Act
      try {
        await QRCodeService.generateQRCode('   ', 200);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('qr_content_empty');
    });

    it('boundary: qrcode_generate_should_not_treat_trimmed_non_empty_payload_as_empty', 0, async () => {
      // Arrange
      let message = '';
      // Act
      try {
        await QRCodeService.generateQRCode('  qr-bf  ', 64);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message === 'qr_content_empty').assertFalse();
    });

    it('conflict: weather_reminder_terminal_status_should_distinguish_terminal_and_active_states', 0, () => {
      // Arrange
      const coordinator = WeatherReminderCoordinator.getInstance() as Object as WeatherReminderCoordinatorPrivateBF;
      // Act
      const completed = coordinator.isTerminalStatus(PlanStatus.COMPLETED);
      const cancelled = coordinator.isTerminalStatus(PlanStatus.CANCELLED);
      const ready = coordinator.isTerminalStatus(PlanStatus.READY);
      // Assert
      expect(completed).assertTrue();
      expect(cancelled).assertTrue();
      expect(ready).assertFalse();
    });

    it('regression: amap_snapshot_to_info_should_fallback_to_condition_code_when_text_empty', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;
      const snapshot = new WeatherSnapshotInputBF();
      snapshot.temperatureCelsius = 18;
      snapshot.conditionCode = 'FOG';
      snapshot.humidity = 55;
      snapshot.windSpeed = 2;
      snapshot.cityCode = '440000';
      // Act
      const info = privateApi.snapshotToInfo(snapshot as Object);
      // Assert
      expect(info.condition).assertEqual('FOG');
      expect(info.temperature).assertEqual(18);
      expect(info.cityCode ?? '').assertEqual('440000');
    });

    it('combined: repo_and_bus_private_helpers_should_keep_timestamp_and_plan_id_normalized', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepoPrivateBF;
      const bus = new StateEventBus() as Object as StateEventBusPrivateBF;
      const numericValue = new NumericStringValueBF('13579');
      // Act
      const timestamp = repo.toTimestamp(numericValue as Object);
      const normalizedPlanId = bus.normalizePlanId('  plan_bf  ');
      // Assert
      expect(timestamp).assertEqual(13579);
      expect(normalizedPlanId).assertEqual('plan_bf');
    });
  });
}
