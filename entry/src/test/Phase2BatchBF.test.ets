import { describe, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import image from '@ohos.multimedia.image';
import { MultiFormatWriter, BitMatrix, EncodeHintType, BarcodeFormat } from '@ohos/zxing';
import { AvatarService } from '../main/ets/infrastructure/avatar/AvatarService';
import { AppStartupCoordinator } from '../main/ets/infrastructure/auth/AppStartupCoordinator';
import { AuthResult, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import { WeatherInfo, WeatherGeoPointRequest } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { WeatherReminderCoordinator } from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderStore, WeatherReminderPayload } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanTransitionEvent } from '../main/ets/domain/statemachine/ExecutionContext';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';
import { QRCodeService } from '../main/ets/domain/services/QRCodeService';

class FakeContextBF {
  cacheDir: string = '/cache_bf';
}

interface StartupInternalBF {
  authFacade: { silentLogin: () => Promise<AuthResult<UserSession>> };
  silentLoginWithTimeout: () => Promise<AuthResult<UserSession>>;
  doCheckStartupAuth: () => Promise<AuthResult<UserSession>>;
}

interface AvatarServicePrivateBF {
  errorMessage: (error: Object) => string;
}

interface AmapWeatherPrivateBF {
  readAsText: (value?: string) => string;
  readAsNumber: (value?: string) => number;
  mapLiveNodeToInfo: (node?: Object) => WeatherInfo | null;
  mapForecastNodeToInfo: (node?: Object) => WeatherInfo | null;
  mapResponseToInfo: (response: Object) => WeatherInfo | null;
  snapshotToInfo: (snapshot: Object) => WeatherInfo;
}

interface UserProfileRepoPrivateBF {
  toTimestamp: (rawValue: Object | number | undefined) => number;
  normalizeError: (error: Object | undefined) => string;
  ensureCloudDbZone: () => Promise<Object>;
}

interface StateEventBusPrivateBF {
  normalizePlanId: (planId: string) => string;
}

class FakeStateMachineBF {
  public currentStatus: PlanStatus = PlanStatus.CONFIRMED;
  public listener: ((event: PlanTransitionEvent) => void) | null = null;
  public unsubscribedCount: number = 0;

  public subscribePlanTransition(_planId: string, listener: (event: PlanTransitionEvent) => void): () => void {
    this.listener = listener;
    return () => {
      this.unsubscribedCount += 1;
    };
  }

  public getPlanStatus(_planId: string): { status: PlanStatus } {
    return { status: this.currentStatus };
  }
}

class TestableAmapWeatherServiceBF extends AmapWeatherService {
  public weatherByCity: Map<string, WeatherInfo> = new Map<string, WeatherInfo>();
  public getWeatherCalls: number = 0;

  public async getWeather(cityName: string): Promise<WeatherInfo | null> {
    this.getWeatherCalls += 1;
    return this.weatherByCity.get(cityName) ?? null;
  }
}

function createAuthResultBF(success: boolean, code: number, message: string, status: LoginStatus): AuthResult<UserSession> {
  const result = new AuthResult<UserSession>();
  result.success = success;
  result.code = code;
  result.message = message;
  result.source = 'HUAWEI_SILENT';
  result.status = status;
  result.data = success ? new UserSession() : null;
  return result;
}

function createPointBF(
  latitude: number,
  longitude: number,
  sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION',
  targetTime: number = 1_700_000_000_000
): WeatherGeoPointRequest {
  const point = {} as WeatherGeoPointRequest;
  point.latitude = latitude;
  point.longitude = longitude;
  point.sourceType = sourceType;
  point.targetTime = targetTime;
  point.forceRefresh = false;
  return point;
}

function createWeatherBF(cityCode: string, condition: string, temp: number): WeatherInfo {
  const info = {} as WeatherInfo;
  info.temperature = temp;
  info.condition = condition;
  info.humidity = 40;
  info.windSpeed = 3;
  info.reportTime = '2026-04-17 10:00:00';
  info.cityCode = cityCode;
  return info;
}

export default function phase2BatchBFTest() {
  describe('phase2BatchBF_avatar_service', () => {
    it('normal: avatar_compress_to_jpeg_should_write_file_and_return_uri_when_dependencies_success', 0, async () => {
      // Arrange
      const originCreateImageSource = Reflect.get(image as Object, 'createImageSource') as Object;
      const originCreateImagePacker = Reflect.get(image as Object, 'createImagePacker') as Object;
      const originAccessSync = Reflect.get(fileIo as Object, 'accessSync') as Object;
      const originMkdirSync = Reflect.get(fileIo as Object, 'mkdirSync') as Object;
      const originOpenSync = Reflect.get(fileIo as Object, 'openSync') as Object;
      const originWriteSync = Reflect.get(fileIo as Object, 'writeSync') as Object;
      const originCloseSync = Reflect.get(fileIo as Object, 'closeSync') as Object;
      const originGetUriFromPath = Reflect.get(fileUri as Object, 'getUriFromPath') as Object;
      let writeBytes = 0;
      try {
        Reflect.set(image as Object, 'createImageSource', (_src: string): Object => {
          return { createPixelMap: async (): Promise<Object> => ({ marker: 'pixel_map' } as Object) } as Object;
        });
        Reflect.set(image as Object, 'createImagePacker', (): Object => {
          return { packToData: async (_pixelMap: Object, _options: Object): Promise<ArrayBuffer> => new Uint8Array([1, 2, 3, 4]).buffer } as Object;
        });
        Reflect.set(fileIo as Object, 'accessSync', (_path: string): boolean => false);
        Reflect.set(fileIo as Object, 'mkdirSync', (_path: string, _recursive: boolean): void => {});
        Reflect.set(fileIo as Object, 'openSync', (_path: string, _mode: number): Object => ({ fd: 9 } as Object));
        Reflect.set(fileIo as Object, 'writeSync', (_fd: number, packed: ArrayBuffer): void => {
          writeBytes = packed.byteLength;
        });
        Reflect.set(fileIo as Object, 'closeSync', (_file: Object): void => {});
        Reflect.set(fileUri as Object, 'getUriFromPath', (path: string): string => `file://${path}`);

        // Act
        const uri = await AvatarService.compressToJpegInCache(new FakeContextBF() as Object as common.Context, 'file://picked.jpg', 'u_bf');

        // Assert
        expect(uri.indexOf('file:///cache_bf/avatar/avatar_u_bf_') === 0).assertTrue();
        expect(writeBytes).assertEqual(4);
      } finally {
        Reflect.set(image as Object, 'createImageSource', originCreateImageSource);
        Reflect.set(image as Object, 'createImagePacker', originCreateImagePacker);
        Reflect.set(fileIo as Object, 'accessSync', originAccessSync);
        Reflect.set(fileIo as Object, 'mkdirSync', originMkdirSync);
        Reflect.set(fileIo as Object, 'openSync', originOpenSync);
        Reflect.set(fileIo as Object, 'writeSync', originWriteSync);
        Reflect.set(fileIo as Object, 'closeSync', originCloseSync);
        Reflect.set(fileUri as Object, 'getUriFromPath', originGetUriFromPath);
      }
    });

    it('invalid: avatar_error_message_should_fallback_to_unknown_error_for_non_error_input', 0, () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBF;
      // Act
      const message = privateApi.errorMessage({ code: 1 } as Object);
      // Assert
      expect(message).assertEqual('unknown_error');
    });
  });

  describe('phase2BatchBF_app_startup_coordinator', () => {
    it('normal: startup_do_check_should_keep_silent_success_result', 0, async () => {
      // Arrange
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as StartupInternalBF;
      const originSilent = internal.silentLoginWithTimeout;
      try {
        internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> =>
          createAuthResultBF(true, 0, 'ok', LoginStatus.AUTHENTICATED);

        // Act
        const result = await internal.doCheckStartupAuth();

        // Assert
        expect(result.success).assertTrue();
        expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      } finally {
        internal.silentLoginWithTimeout = originSilent;
      }
    });

    it('invalid: startup_do_check_should_normalize_failed_status_to_unauthenticated', 0, async () => {
      // Arrange
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as StartupInternalBF;
      const originSilent = internal.silentLoginWithTimeout;
      try {
        internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> =>
          createAuthResultBF(false, 401, 'expired', LoginStatus.LOGIN_FAILED);

        // Act
        const result = await internal.doCheckStartupAuth();

        // Assert
        expect(result.success).assertEqual(false);
        expect(result.code).assertEqual(401);
        expect(result.message).assertEqual('expired');
        expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      } finally {
        internal.silentLoginWithTimeout = originSilent;
      }
    });
  });

  describe('phase2BatchBF_amap_weather_service', () => {
    it('normal: amap_private_mappers_should_parse_live_and_forecast_payload', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;

      // Act
      const liveInfo = privateApi.mapLiveNodeToInfo({
        adcode: '310000',
        weather: ' SUNNY ',
        temperature: '26.5',
        humidity: '45',
        windpower: '3',
        reporttime: '2026-04-17 10:00:00'
      } as Object);
      const forecastInfo = privateApi.mapForecastNodeToInfo({
        adcode: '320000',
        casts: [{ dayweather: 'RAIN', daytemp: '24', nighttemp: '20' }]
      } as Object);

      // Assert
      expect(liveInfo?.condition ?? '').assertEqual('SUNNY');
      expect(liveInfo?.temperature ?? 0).assertEqual(26.5);
      expect(forecastInfo?.condition ?? '').assertEqual('RAIN');
      expect(forecastInfo?.temperature ?? 0).assertEqual(22);
    });

    it('boundary: amap_response_mapper_should_fallback_to_forecast_when_live_missing', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;

      // Act
      const info = privateApi.mapResponseToInfo({
        lives: [],
        forecasts: [{ adcode: '330000', casts: [{ dayweather: 'CLOUDY', daytemp: '21', nighttemp: '19' }] }]
      } as Object);

      // Assert
      expect(info?.condition ?? '').assertEqual('CLOUDY');
      expect(info?.cityCode ?? '').assertEqual('330000');
    });

    it('invalid: amap_read_helpers_should_return_empty_and_nan_for_invalid_inputs', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;

      // Act
      const text = privateApi.readAsText(undefined);
      const numberValue = privateApi.readAsNumber('not_number');

      // Assert
      expect(text).assertEqual('');
      expect(Number.isNaN(numberValue)).assertTrue();
    });

    it('boundary: amap_batch_should_not_apply_city_cap_when_no_current_location_point', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceBF();
      const originCityCode = Reflect.get(AmapService as Object, 'getCityCodeByCoordinate') as Object;
      try {
        Reflect.set(AmapService as Object, 'getCityCodeByCoordinate', async (lat: number, _lng: number): Promise<string | null> => `CITY_${Math.floor(lat)}`);
        for (let i = 1; i <= 6; i++) {
          service.weatherByCity.set(`CITY_${i}`, createWeatherBF(`CITY_${i}`, 'SUNNY', 20 + i));
        }
        const points: WeatherGeoPointRequest[] = [];
        for (let i = 1; i <= 6; i++) {
          points.push(createPointBF(i + 0.1, 120.1, 'PLAN_LOCATION', 1_700_000_000_100 + i));
        }

        // Act
        const result = await service.batchGetWeather(points);

        // Assert
        expect(result.size).assertEqual(6);
        expect(service.getWeatherCalls).assertEqual(6);
      } finally {
        Reflect.set(AmapService as Object, 'getCityCodeByCoordinate', originCityCode);
      }
    });

    it('regression: amap_snapshot_to_info_should_fallback_condition_from_code_when_text_empty', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;

      // Act
      const info = privateApi.snapshotToInfo({
        temperatureCelsius: 18,
        conditionText: '',
        conditionCode: 'FOG',
        humidity: 55,
        windSpeed: 2,
        cityCode: '440000'
      } as Object);

      // Assert
      expect(info.condition).assertEqual('FOG');
      expect(info.temperature).assertEqual(18);
      expect(info.cityCode ?? '').assertEqual('440000');
    });
  });

  describe('phase2BatchBF_weather_reminder_coordinator', () => {
    it('normal: weather_reminder_private_terminal_status_should_match_completed_cancelled_expired', 0, () => {
      // Arrange
      const coordinator = WeatherReminderCoordinator.getInstance() as Object as { isTerminalStatus: (status: PlanStatus) => boolean };

      // Act
      const completed = coordinator.isTerminalStatus(PlanStatus.COMPLETED);
      const cancelled = coordinator.isTerminalStatus(PlanStatus.CANCELLED);
      const expired = coordinator.isTerminalStatus(PlanStatus.EXPIRED);
      const ready = coordinator.isTerminalStatus(PlanStatus.READY);

      // Assert
      expect(completed).assertTrue();
      expect(cancelled).assertTrue();
      expect(expired).assertTrue();
      expect(ready).assertEqual(false);
    });

    it('boundary: weather_reminder_subscribe_should_clear_when_terminal_transition_received', 0, () => {
      // Arrange
      const fakeMachine = new FakeStateMachineBF();
      const originGetInstance = Reflect.get(PlanStateMachine as Object, 'getInstance') as Object;
      const originReadPayload = Reflect.get(WeatherReminderStore as Object, 'readPayload') as Object;
      const originClearPayload = Reflect.get(WeatherReminderStore as Object, 'clearPayload') as Object;
      let clearPlanId = -1;
      let onClearCount = 0;
      try {
        Reflect.set(PlanStateMachine as Object, 'getInstance', (): Object => fakeMachine as Object);
        Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
        Reflect.set(WeatherReminderStore as Object, 'readPayload', (_planId?: number): WeatherReminderPayload | null => null);
        Reflect.set(WeatherReminderStore as Object, 'clearPayload', (planId?: number): void => {
          clearPlanId = Number(planId ?? -1);
        });

        const coordinator = WeatherReminderCoordinator.getInstance();
        const off = coordinator.subscribePlan(9001, {
          isDialogOpen: (): boolean => false,
          onShow: (_payload: WeatherReminderPayload): void => {},
          onClear: (): void => { onClearCount += 1; },
          pollIntervalMs: 5000
        });

        // Act
        fakeMachine.listener?.({
          planId: '9001',
          fromStatus: PlanStatus.READY,
          toStatus: PlanStatus.COMPLETED,
          triggerSource: 'USER_ACTION' as never,
          triggerReason: 'finish',
          timestamp: Date.now()
        });
        off();

        // Assert
        expect(clearPlanId).assertEqual(9001);
        expect(onClearCount).assertEqual(1);
      } finally {
        Reflect.set(PlanStateMachine as Object, 'getInstance', originGetInstance);
        Reflect.set(WeatherReminderStore as Object, 'readPayload', originReadPayload);
        Reflect.set(WeatherReminderStore as Object, 'clearPayload', originClearPayload);
        Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
      }
    });
  });

  describe('phase2BatchBF_user_profile_repository', () => {
    it('normal: user_profile_to_timestamp_should_support_number_to_number_and_to_string_paths', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepoPrivateBF;

      // Act
      const fromNumber = repo.toTimestamp(12345);
      const fromToNumber = repo.toTimestamp({ toNumber: (): number => 67890 } as Object);
      const fromToString = repo.toTimestamp({ toString: (): string => '13579' } as Object);

      // Assert
      expect(fromNumber).assertEqual(12345);
      expect(fromToNumber).assertEqual(67890);
      expect(fromToString).assertEqual(13579);
    });

    it('invalid: user_profile_normalize_error_should_fallback_to_cloud_db_error_when_stringify_fails', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepoPrivateBF;
      const circular: Record<string, Object> = {};
      circular.self = circular as Object;

      // Act
      const message = repo.normalizeError(circular as Object);

      // Assert
      expect(message).assertEqual('cloud_db_error');
    });

    it('boundary: user_profile_ensure_cloud_db_zone_should_reuse_inflight_promise', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepoPrivateBF;
      let callCount = 0;
      const deferred = new Promise<Object>((resolve) => {
        setTimeout(() => {
          resolve({ zone: 'bf' } as Object);
        }, 0);
      });
      Reflect.set(repo as Object, 'cloudDbZone', null);
      Reflect.set(repo as Object, 'openZoneInFlight', null);
      Reflect.set(repo as Object, 'openCloudDbZoneInternal', async (): Promise<Object> => {
        callCount += 1;
        return deferred;
      });

      // Act
      const p1 = repo.ensureCloudDbZone();
      const p2 = repo.ensureCloudDbZone();
      const zone1 = await p1;
      const zone2 = await p2;

      // Assert
      expect(callCount).assertEqual(1);
      expect(zone1 === zone2).assertTrue();
    });

    it('regression: user_profile_update_avatar_should_auto_increment_version_when_input_invalid', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl();
      const base = new UserProfileEntity();
      base.accountId = 'acc_bf';
      base.profileId = 'acc_bf';
      base.username = 'name';
      base.avatarPath = 'old.png';
      base.avatarVersion = 7;
      base.isInitialized = true;
      base.createdAt = 1;
      base.updatedAt = 1;
      let upsertCount = 0;
      Reflect.set(repo as Object, 'createDefaultProfile', async (_accountId: string): Promise<UserProfileEntity> => base);
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => {
        return {
          executeUpsert: async (_record: Object): Promise<void> => {
            upsertCount += 1;
          }
        } as Object;
      });

      // Act
      const profile = await repo.updateAvatar('acc_bf', 'new.png', 0);

      // Assert
      expect(profile.avatarVersion).assertEqual(8);
      expect(upsertCount).assertEqual(1);
    });
  });

  describe('phase2BatchBF_state_event_bus', () => {
    it('normal: state_event_bus_private_normalize_should_trim_and_fallback_to_wildcard', 0, () => {
      // Arrange
      const bus = new StateEventBus() as Object as StateEventBusPrivateBF;

      // Act
      const trimmed = bus.normalizePlanId('  p_bf  ');
      const wildcard = bus.normalizePlanId('   ');

      // Assert
      expect(trimmed).assertEqual('p_bf');
      expect(wildcard).assertEqual('*');
    });
  });

  describe('phase2BatchBF_qrcode_service', () => {
    it('normal: qrcode_generate_should_clamp_size_and_build_rgba_pixel_map', 0, async () => {
      // Arrange
      const originEncode = Reflect.get(MultiFormatWriter.prototype as Object, 'encode') as Object;
      const originCreatePixelMap = Reflect.get(image as Object, 'createPixelMap') as Object;
      let encodedWidth = 0;
      let encodedHeight = 0;
      let encodedFormat = '';
      let marginValue: number | undefined = undefined;
      let charsetValue = '';
      let pixelBytes = 0;
      try {
        Reflect.set(MultiFormatWriter.prototype as Object, 'encode', (
          _content: string,
          format: BarcodeFormat,
          width: number,
          height: number,
          hints: Map<EncodeHintType, number | string>
        ): BitMatrix => {
          encodedWidth = width;
          encodedHeight = height;
          encodedFormat = `${format}`;
          marginValue = Number(hints.get(EncodeHintType.MARGIN));
          charsetValue = String(hints.get(EncodeHintType.CHARACTER_SET));
          return {
            getWidth: (): number => 2,
            getHeight: (): number => 1,
            get: (x: number, _y: number): boolean => x === 0
          } as Object as BitMatrix;
        });
        Reflect.set(image as Object, 'createPixelMap', (buffer: ArrayBuffer, _options: Object): Object => {
          pixelBytes = buffer.byteLength;
          return { pixelMap: true } as Object;
        });

        // Act
        const pixelMap = await QRCodeService.generateQRCode('bf_content', 16);

        // Assert
        expect(pixelMap !== null).assertTrue();
        expect(encodedWidth).assertEqual(64);
        expect(encodedHeight).assertEqual(64);
        expect(encodedFormat.indexOf('QR_CODE') >= 0).assertTrue();
        expect(marginValue).assertEqual(0);
        expect(charsetValue).assertEqual('UTF-8');
        expect(pixelBytes).assertEqual(8);
      } finally {
        Reflect.set(MultiFormatWriter.prototype as Object, 'encode', originEncode);
        Reflect.set(image as Object, 'createPixelMap', originCreatePixelMap);
      }
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
  });
}
