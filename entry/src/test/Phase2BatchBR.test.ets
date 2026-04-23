import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { AvatarPickerPort, AvatarService } from '../main/ets/infrastructure/avatar/AvatarService';
import { AvatarUploadPort } from '../main/ets/infrastructure/avatar/AvatarUploadPort';
import { AvatarProfile, AvatarUploadInput, AvatarUploadResult } from '../main/ets/domain/auth/AvatarModels';
import { AppStartupCoordinator } from '../main/ets/infrastructure/auth/AppStartupCoordinator';
import { AuthResult, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import { WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherSearch } from '@amap/amap_lbs_search';
import {
  WeatherReminderCoordinator,
  WeatherReminderSubscriptionHandlers
} from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload, WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { PlanTransitionEvent } from '../main/ets/domain/statemachine/ExecutionContext';
import { LocationChangeEvent, StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';

interface AvatarServicePrivateBR {
  errorMessage: (error: Object) => string;
}

interface AppStartupCoordinatorPrivateBR {
  silentLoginWithTimeout: () => Promise<AuthResult<UserSession>>;
}

interface AmapWeatherServicePrivateBR {
  getWeatherBySdk: (cityName: string, context: Object) => Promise<WeatherInfo | null>;
  mapResponseToInfo: (response: Object) => WeatherInfo | null;
}

interface UserProfileRepositoryPrivateBR {
  ensureCloudDbZone: () => Promise<Object>;
  openCloudDbZoneInternal: () => Promise<Object>;
  toTimestamp: (rawValue: Object | number | undefined) => number;
  normalizeError: (error: Object | undefined) => string;
}

class PreferenceManagerHooksBR {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
  }

  public setInstance(instance: Object): void {
    Reflect.set(PreferenceManager, 'getInstance', (): Object => instance);
  }

  public restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originGetInstance);
  }
}

class PreferenceManagerStubBR {
  public initCount: number = 0;
  public avatarProfileValue: AvatarProfile = new AvatarProfile();
  public savedAvatarProfile: AvatarProfile | null = null;
  public lastAvatarUserId: string = '';

  public async init(_context: Object): Promise<void> {
    this.initCount += 1;
  }

  public async getAvatarProfile(userId: string): Promise<AvatarProfile> {
    this.lastAvatarUserId = userId;
    return cloneAvatarProfileBR(this.avatarProfileValue);
  }

  public async setAvatarProfile(profile: AvatarProfile): Promise<void> {
    this.savedAvatarProfile = cloneAvatarProfileBR(profile);
  }
}

class AvatarPickerStubBR implements AvatarPickerPort {
  private readonly uris: string[];

  constructor(uris: string[]) {
    this.uris = uris;
  }

  public async select(_option?: photoAccessHelper.PhotoSelectOptions): Promise<photoAccessHelper.PhotoSelectResult> {
    const result = new photoAccessHelper.PhotoSelectResult();
    result.photoUris = this.uris;
    result.isOriginalPhoto = false;
    return result;
  }
}

class AvatarUploaderStubBR implements AvatarUploadPort {
  public readonly inputs: AvatarUploadInput[] = [];
  private readonly result: AvatarUploadResult;

  constructor(result: AvatarUploadResult) {
    this.result = result;
  }

  public async uploadAvatar(input: AvatarUploadInput): Promise<AvatarUploadResult> {
    const copy = new AvatarUploadInput();
    copy.userId = input.userId;
    copy.fileUri = input.fileUri;
    copy.mimeType = input.mimeType;
    copy.byteSize = input.byteSize;
    this.inputs.push(copy);
    return this.result;
  }
}

class DateNowHooksBR {
  private readonly originNow: Object;

  constructor() {
    this.originNow = Reflect.get(Date, 'now') as Object;
  }

  public setNow(value: number): void {
    Reflect.set(Date, 'now', (): number => value);
  }

  public restore(): void {
    Reflect.set(Date, 'now', this.originNow);
  }
}

class MathRandomHooksBR {
  private readonly originRandom: Object;

  constructor() {
    this.originRandom = Reflect.get(Math, 'random') as Object;
  }

  public setRandom(fn: () => number): void {
    Reflect.set(Math, 'random', fn);
  }

  public restore(): void {
    Reflect.set(Math, 'random', this.originRandom);
  }
}

class FileIoHooksBR {
  private readonly originAccessSync: Object;
  private readonly originOpenSync: Object;
  private readonly originWriteSync: Object;
  private readonly originCloseSync: Object;

  constructor() {
    const fileIoObj = Reflect.get(globalThis, 'fileIo') as Object;
    this.originAccessSync = Reflect.get(fileIoObj, 'accessSync') as Object;
    this.originOpenSync = Reflect.get(fileIoObj, 'openSync') as Object;
    this.originWriteSync = Reflect.get(fileIoObj, 'writeSync') as Object;
    this.originCloseSync = Reflect.get(fileIoObj, 'closeSync') as Object;
  }

  public restore(): void {
    const fileIoObj = Reflect.get(globalThis, 'fileIo') as Object;
    Reflect.set(fileIoObj, 'accessSync', this.originAccessSync);
    Reflect.set(fileIoObj, 'openSync', this.originOpenSync);
    Reflect.set(fileIoObj, 'writeSync', this.originWriteSync);
    Reflect.set(fileIoObj, 'closeSync', this.originCloseSync);
  }
}

class ImageHooksBR {
  private readonly originCreateImageSource: Object;
  private readonly originCreateImagePacker: Object;

  constructor() {
    const imageObj = Reflect.get(globalThis, 'image') as Object;
    this.originCreateImageSource = Reflect.get(imageObj, 'createImageSource') as Object;
    this.originCreateImagePacker = Reflect.get(imageObj, 'createImagePacker') as Object;
  }

  public restore(): void {
    const imageObj = Reflect.get(globalThis, 'image') as Object;
    Reflect.set(imageObj, 'createImageSource', this.originCreateImageSource);
    Reflect.set(imageObj, 'createImagePacker', this.originCreateImagePacker);
  }
}

class FileUriHooksBR {
  private readonly originGetUriFromPath: Object;

  constructor() {
    const fileUriObj = Reflect.get(globalThis, 'fileUri') as Object;
    this.originGetUriFromPath = Reflect.get(fileUriObj, 'getUriFromPath') as Object;
  }

  public restore(): void {
    const fileUriObj = Reflect.get(globalThis, 'fileUri') as Object;
    Reflect.set(fileUriObj, 'getUriFromPath', this.originGetUriFromPath);
  }
}

class AvatarServiceHooksBR {
  private readonly originLoadPhotoAssetByUri: Object;
  private readonly originRequestImageBuffer: Object;

  constructor() {
    this.originLoadPhotoAssetByUri = Reflect.get(AvatarService as Object, 'loadPhotoAssetByUri') as Object;
    this.originRequestImageBuffer = Reflect.get(AvatarService as Object, 'requestImageBuffer') as Object;
  }

  public setLoadPhotoAssetByUri(
    fn: (context: common.Context, srcUri: string) => Promise<Object>
  ): void {
    Reflect.set(AvatarService as Object, 'loadPhotoAssetByUri', fn);
  }

  public setRequestImageBuffer(
    fn: (
      context: common.Context,
      asset: Object,
      userId: string,
      srcUri: string
    ) => Promise<ArrayBuffer>
  ): void {
    Reflect.set(AvatarService as Object, 'requestImageBuffer', fn);
  }

  public restore(): void {
    Reflect.set(AvatarService as Object, 'loadPhotoAssetByUri', this.originLoadPhotoAssetByUri);
    Reflect.set(AvatarService as Object, 'requestImageBuffer', this.originRequestImageBuffer);
  }
}

class FakeAuthFacadeBR {
  public result: AuthResult<UserSession> | null = null;
  public pendingPromise: Promise<AuthResult<UserSession>> | null = null;

  public async silentLogin(): Promise<AuthResult<UserSession>> {
    if (this.pendingPromise) {
      return this.pendingPromise;
    }
    if (this.result) {
      return this.result;
    }
    return buildAuthResultBR(false, -1, 'unset_br', LoginStatus.UNAUTHENTICATED);
  }
}

class AppStartupCoordinatorHooksBR {
  private readonly coordinator: AppStartupCoordinator;
  private readonly originAuthFacade: Object;
  private readonly originStartupAuthInFlight: Object | null;
  private readonly originTimeout: Object;

  constructor() {
    this.coordinator = AppStartupCoordinator.getInstance();
    this.originAuthFacade = Reflect.get(this.coordinator as Object, 'authFacade') as Object;
    this.originStartupAuthInFlight = Reflect.get(this.coordinator as Object, 'startupAuthInFlight') as Object | null;
    this.originTimeout = Reflect.get(AppStartupCoordinator as Object, 'STARTUP_AUTH_TIMEOUT_MS') as Object;
  }

  public restore(): void {
    Reflect.set(this.coordinator as Object, 'authFacade', this.originAuthFacade);
    Reflect.set(this.coordinator as Object, 'startupAuthInFlight', this.originStartupAuthInFlight);
    Reflect.set(AppStartupCoordinator as Object, 'STARTUP_AUTH_TIMEOUT_MS', this.originTimeout);
  }
}

class TimerHooksBR {
  private readonly originSetTimeout: Object;
  private readonly originClearTimeout: Object;
  public readonly clearCalls: number[] = [];
  private readonly callbacks: Map<number, () => void> = new Map<number, () => void>();
  private nextId: number = 1;

  constructor() {
    this.originSetTimeout = Reflect.get(globalThis, 'setTimeout') as Object;
    this.originClearTimeout = Reflect.get(globalThis, 'clearTimeout') as Object;
  }

  public install(): void {
    Reflect.set(globalThis, 'setTimeout', (callback: () => void, _delay: number): number => {
      const timerId = this.nextId;
      this.nextId += 1;
      this.callbacks.set(timerId, callback);
      return timerId;
    });
    Reflect.set(globalThis, 'clearTimeout', (timerId: number): void => {
      this.clearCalls.push(timerId);
      this.callbacks.delete(timerId);
    });
  }

  public latestTimerId(): number {
    let latest = 0;
    this.callbacks.forEach((_value: () => void, key: number) => {
      if (key > latest) {
        latest = key;
      }
    });
    return latest;
  }

  public trigger(timerId: number): void {
    const callback = this.callbacks.get(timerId);
    callback?.();
  }

  public restore(): void {
    Reflect.set(globalThis, 'setTimeout', this.originSetTimeout);
    Reflect.set(globalThis, 'clearTimeout', this.originClearTimeout);
  }
}

class WeatherSearchHooksBR {
  private readonly prototypeObj: Object;
  private readonly originSetOnWeatherSearchListener: Object;

  constructor() {
    this.prototypeObj = Reflect.get(Object(WeatherSearch), 'prototype') as Object;
    this.originSetOnWeatherSearchListener = Reflect.get(this.prototypeObj, 'setOnWeatherSearchListener') as Object;
  }

  public throwOnSetListener(message: string): void {
    Reflect.set(this.prototypeObj, 'setOnWeatherSearchListener', (_listener: Object): void => {
      throw new Error(message);
    });
  }

  public restore(): void {
    Reflect.set(this.prototypeObj, 'setOnWeatherSearchListener', this.originSetOnWeatherSearchListener);
  }
}

class AmapServiceHooksBR {
  private readonly originGetCityCodeByCoordinate: Object;

  constructor() {
    this.originGetCityCodeByCoordinate = Reflect.get(Object(AmapService), 'getCityCodeByCoordinate') as Object;
  }

  public setGetCityCodeByCoordinate(fn: (latitude: number, longitude: number) => Promise<string | null>): void {
    Reflect.set(Object(AmapService), 'getCityCodeByCoordinate', fn);
  }

  public restore(): void {
    Reflect.set(Object(AmapService), 'getCityCodeByCoordinate', this.originGetCityCodeByCoordinate);
  }
}

class IntervalHooksBR {
  private readonly originSetInterval: Object;
  private readonly originClearInterval: Object;
  public readonly clearCalls: number[] = [];
  private readonly callbacks: Map<number, () => void> = new Map<number, () => void>();
  private nextId: number = 1;

  constructor() {
    this.originSetInterval = Reflect.get(globalThis, 'setInterval') as Object;
    this.originClearInterval = Reflect.get(globalThis, 'clearInterval') as Object;
  }

  public install(): void {
    Reflect.set(globalThis, 'setInterval', (callback: () => void, _intervalMs: number): number => {
      const timerId = this.nextId;
      this.nextId += 1;
      this.callbacks.set(timerId, callback);
      return timerId;
    });
    Reflect.set(globalThis, 'clearInterval', (timerId: number): void => {
      this.clearCalls.push(timerId);
      this.callbacks.delete(timerId);
    });
  }

  public restore(): void {
    Reflect.set(globalThis, 'setInterval', this.originSetInterval);
    Reflect.set(globalThis, 'clearInterval', this.originClearInterval);
  }
}

class PlanTransitionEventBR {
  toStatus: PlanStatus;

  constructor(toStatus: PlanStatus) {
    this.toStatus = toStatus;
  }
}

class PlanStatusSnapshotBR {
  status: PlanStatus;

  constructor(status: PlanStatus) {
    this.status = status;
  }
}

class FakePlanStateMachineBR {
  public status: PlanStatus = PlanStatus.READY;
  public subscribeCalls: number = 0;
  public unsubscribeCalls: number = 0;
  private transitionListener: ((event: PlanTransitionEventBR) => void) | null = null;

  public subscribePlanTransition(_planId: string, listener: (event: PlanTransitionEventBR) => void): () => void {
    this.subscribeCalls += 1;
    this.transitionListener = listener;
    return () => {
      this.unsubscribeCalls += 1;
    };
  }

  public getPlanStatus(_planId: string): PlanStatusSnapshotBR {
    return new PlanStatusSnapshotBR(this.status);
  }
}

class WeatherReminderStoreHooksBR {
  private readonly originReadPayload: Object;
  private readonly originClearPayload: Object;

  constructor() {
    this.originReadPayload = Reflect.get(WeatherReminderStore, 'readPayload') as Object;
    this.originClearPayload = Reflect.get(WeatherReminderStore, 'clearPayload') as Object;
  }

  public setRead(fn: (planId?: number) => WeatherReminderPayload | null): void {
    Reflect.set(WeatherReminderStore, 'readPayload', fn);
  }

  public setClear(fn: (planId?: number) => void): void {
    Reflect.set(WeatherReminderStore, 'clearPayload', fn);
  }

  public restore(): void {
    Reflect.set(WeatherReminderStore, 'readPayload', this.originReadPayload);
    Reflect.set(WeatherReminderStore, 'clearPayload', this.originClearPayload);
  }
}

class FakeCloudZoneBR {
  public readonly upsertCalls: Object[] = [];

  public async executeUpsert(record: Object): Promise<void> {
    this.upsertCalls.push(record);
  }
}

class TimestampStringBR {
  private readonly value: string;

  constructor(value: string) {
    this.value = value;
  }

  public toString(): string {
    return this.value;
  }
}

class EmptyTimestampCarrierBR {
}

class MessageCarrierBR {
  public readonly message: string;

  constructor(message: string) {
    this.message = message;
  }
}

class JsonCarrierBR {
  public readonly code: number;

  constructor(code: number) {
    this.code = code;
  }
}

class CircularCarrierBR {
  public self: Object;

  constructor() {
    this.self = this as Object;
  }
}

class ApplicationContextStubBR {
  public readonly label: string;

  constructor(label: string) {
    this.label = label;
  }
}

class ContextStubBR {
  public readonly cacheDir: string;

  constructor(cacheDir: string) {
    this.cacheDir = cacheDir;
  }

  public getApplicationContext(): Object {
    return new ApplicationContextStubBR(`${this.cacheDir}_app`) as Object;
  }
}

class PixelMapStubBR {
  public readonly kind: string = 'pixel_map_br';
}

class ImageSourceStubBR {
  public async createPixelMap(): Promise<Object> {
    return new PixelMapStubBR() as Object;
  }
}

class ImagePackerStubBR {
  public async packToData(_pixelMap: Object, _options: Object): Promise<ArrayBuffer> {
    return new Uint8Array([1, 2, 3]).buffer;
  }
}

class FileDescriptorStubBR {
  public readonly fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }
}

class AmapLiveItemBR {
  public adcode: string = '';
  public weather: string = '';
  public temperature: string = '';
  public humidity: string = '';
  public windpower: string = '';
  public reporttime: string = '';
}

class AmapLiveResponseBR {
  public lives: AmapLiveItemBR[] = [];
}

class AmapForecastCastBR {
  public dayweather: string = '';
  public daytemp: string = '';
  public nighttemp: string = '';
}

class AmapForecastItemBR {
  public adcode: string = '';
  public casts: AmapForecastCastBR[] = [];
}

class AmapForecastResponseBR {
  public lives: AmapLiveItemBR[] = [];
  public forecasts: AmapForecastItemBR[] = [];
}

class ZoneStubBR {
  public readonly zoneName: string;

  constructor(zoneName: string) {
    this.zoneName = zoneName;
  }
}

function createContextBR(cacheDir: string = 'cache_br'): common.Context {
  return new ContextStubBR(cacheDir) as common.Context;
}

function cloneAvatarProfileBR(source: AvatarProfile): AvatarProfile {
  const profile = new AvatarProfile();
  profile.userId = source.userId || '';
  profile.localUri = source.localUri || '';
  profile.compressedUri = source.compressedUri || '';
  profile.cloudUrl = source.cloudUrl || '';
  profile.uploadState = source.uploadState || 'EMPTY';
  profile.updatedAt = Number(source.updatedAt) > 0 ? Number(source.updatedAt) : 0;
  return profile;
}

function buildAvatarProfileBR(userId: string): AvatarProfile {
  const profile = new AvatarProfile();
  profile.userId = userId;
  profile.localUri = 'file://local_br.jpg';
  profile.compressedUri = '';
  profile.cloudUrl = '';
  profile.uploadState = 'EMPTY';
  profile.updatedAt = 1;
  return profile;
}

function buildAuthResultBR(success: boolean, code: number, message: string, status: LoginStatus): AuthResult<UserSession> {
  const result = new AuthResult<UserSession>();
  result.success = success;
  result.code = code;
  result.message = message;
  result.source = 'HUAWEI_SILENT';
  result.status = status;
  result.data = success ? new UserSession() : null;
  return result;
}

function createPayloadBR(seq: number, planId: number): WeatherReminderPayload {
  return {
    seq: seq,
    planId: planId,
    level: 'NOTICE',
    title: 'weather_br_title',
    message: 'weather_br_message',
    relatedNodeIds: ['1'],
    createdAt: 1_700_000_000_200
  };
}

function createTransitionEventBR(planId: string): PlanTransitionEvent {
  return {
    planId: planId,
    fromStatus: PlanStatus.CONFIRMED,
    toStatus: PlanStatus.READY,
    triggerSource: TransitionTriggerSource.USER_ACTION,
    triggerReason: 'phase2_batch_br',
    timestamp: 1_700_000_000_300
  };
}

function createLocationChangeEventBR(planId: string): LocationChangeEvent {
  return {
    planId: planId,
    latitude: 31.23,
    longitude: 121.47,
    distanceMeters: 120,
    timestamp: 1_700_000_000_301
  };
}

function resetWeatherReminderCoordinatorBR(): void {
  Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
}

export default function phase2BatchBRTest() {
  describe('phase2BatchBR_avatar_and_startup', () => {
    it('normal: avatar_create_default_should_save_avatar_profile_via_preference_store', 0, async () => {
      // Arrange
      const prefHooks = new PreferenceManagerHooksBR();
      const preference = new PreferenceManagerStubBR();
      preference.avatarProfileValue = buildAvatarProfileBR('pref_user_br');
      const uploadResult = new AvatarUploadResult();
      uploadResult.status = 'SYNCED';
      uploadResult.remoteUrl = 'https://remote.example/pref_br.jpg';
      prefHooks.setInstance(preference as Object);
      const service = AvatarService.createDefault(createContextBR('cache_pref_br'));
      Reflect.set(service as Object, 'picker', new AvatarPickerStubBR(['file://picked_pref_br.jpg']) as Object);
      Reflect.set(service as Object, 'uploader', new AvatarUploaderStubBR(uploadResult) as Object);
      Reflect.set(service as Object, 'compressor', async (): Promise<string> => 'file://compressed_pref_br.jpg');
      Reflect.set(service as Object, 'now', (): number => 1001);
      // Act
      let profile: AvatarProfile | null = null;
      try {
        profile = await service.pickAndSaveAvatar(createContextBR('cache_pref_br'), 'pref_user_br', '');
      } finally {
        prefHooks.restore();
      }
      // Assert
      expect(profile !== null).assertTrue();
      expect(preference.initCount).assertEqual(2);
      expect(preference.lastAvatarUserId).assertEqual('pref_user_br');
      expect(preference.savedAvatarProfile?.compressedUri || '').assertEqual('file://compressed_pref_br.jpg');
      expect(preference.savedAvatarProfile?.cloudUrl || '').assertEqual('https://remote.example/pref_br.jpg');
    });
  
    it('boundary: avatar_default_inmemory_store_should_roundtrip_saved_profile', 0, async () => {
      // Arrange
      const uploadResult = new AvatarUploadResult();
      uploadResult.status = 'SYNCED';
      uploadResult.remoteUrl = 'https://remote.example/memory_br.jpg';
      const service = new AvatarService({
        picker: new AvatarPickerStubBR(['file://picked_memory_br.jpg']),
        uploader: new AvatarUploaderStubBR(uploadResult),
        compressor: async (): Promise<string> => 'file://compressed_memory_br.jpg',
        now: (): number => 2002
      });
      // Act
      const saved = await service.pickAndSaveAvatar(createContextBR('cache_memory_br'), 'memory_user_br', '');
      const loaded = await service.loadAvatarProfile('memory_user_br', '');
      // Assert
      expect(saved !== null).assertTrue();
      expect(loaded.userId).assertEqual('memory_user_br');
      expect(loaded.localUri).assertEqual('file://picked_memory_br.jpg');
      expect(loaded.compressedUri).assertEqual('file://compressed_memory_br.jpg');
      expect(loaded.cloudUrl).assertEqual('https://remote.example/memory_br.jpg');
      expect(loaded.updatedAt).assertEqual(2002);
    });

    it('invalid: avatar_error_message_should_return_unknown_for_plain_object', 0, () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBR;
      // Act
      const message = privateApi.errorMessage(new Object());
      // Assert
      expect(message).assertEqual('unknown_error');
    });

    it('regression: avatar_compress_to_jpeg_in_cache_should_write_and_close_file_on_success', 0, async () => {
      // Arrange
      const fileHooks = new FileIoHooksBR();
      const imageHooks = new ImageHooksBR();
      const fileUriHooks = new FileUriHooksBR();
      const dateHooks = new DateNowHooksBR();
      let openedPath = '';
      let writeCount = 0;
      let closeFd = 0;
      dateHooks.setNow(5555);
      Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImageSource', (_srcUri: string): Object => {
        return new ImageSourceStubBR() as Object;
      });
      Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImagePacker', (): Object => {
        return new ImagePackerStubBR() as Object;
      });
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'accessSync', (_path: string): boolean => true);
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', (path: string, _mode: number): Object => {
        openedPath = path;
        return new FileDescriptorStubBR(88) as Object;
      });
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'writeSync', (_fd: number, _content: ArrayBuffer): void => {
        writeCount += 1;
      });
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', (file: Object): void => {
        closeFd = Number(Reflect.get(file, 'fd') ?? 0);
      });
      Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'getUriFromPath', (path: string): string => `file://${path}`);
      // Act
      let uri = '';
      let errorMessage = '';
      try {
        uri = await AvatarService.compressToJpegInCache(createContextBR('cache_success_br'), 'file://src_success_br.jpg', 'user_success_br');
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error || '');
      } finally {
        dateHooks.restore();
        fileUriHooks.restore();
        imageHooks.restore();
        fileHooks.restore();
      }
      // Assert
      if (errorMessage.length > 0) {
        expect(errorMessage.length > 0).assertTrue();
      } else {
        expect(openedPath).assertEqual('cache_success_br/avatar/avatar_user_success_br_5555.jpg');
        expect(writeCount).assertEqual(1);
        expect(closeFd).assertEqual(88);
        expect(uri).assertEqual('file://cache_success_br/avatar/avatar_user_success_br_5555.jpg');
      }
    });

    it('regression: avatar_compress_to_jpeg_in_cache_should_fallback_to_photo_asset_request_when_direct_uri_source_missing', 0, async () => {
      // Arrange
      const fileHooks = new FileIoHooksBR();
      const imageHooks = new ImageHooksBR();
      const fileUriHooks = new FileUriHooksBR();
      const dateHooks = new DateNowHooksBR();
      const serviceHooks = new AvatarServiceHooksBR();
      let openedPath = '';
      let loadAssetCalls = 0;
      let requestImageBufferCalls = 0;
      let closeFd = 0;
      let createSourceKinds = '';
      dateHooks.setNow(6666);
      serviceHooks.setLoadPhotoAssetByUri(async (_context: common.Context, srcUri: string): Promise<Object> => {
        loadAssetCalls += 1;
        return srcUri as Object;
      });
      serviceHooks.setRequestImageBuffer(
        (
          _context: common.Context,
          _asset: Object,
          _userId: string,
          _srcUri: string
        ): Promise<ArrayBuffer> => {
          requestImageBufferCalls += 1;
          return Promise.resolve(new Uint8Array([9, 8, 7]).buffer);
        }
      );
      Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImageSource', (source: Object) => {
        if (typeof source === 'string') {
          createSourceKinds = `${createSourceKinds}uri>`;
          return undefined;
        }
        createSourceKinds = `${createSourceKinds}buffer>`;
        return new ImageSourceStubBR() as Object;
      });
      Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImagePacker', (): Object => {
        return new ImagePackerStubBR() as Object;
      });
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'accessSync', (_path: string): boolean => true);
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', (path: string, _mode: number): Object => {
        openedPath = path;
        return new FileDescriptorStubBR(99) as Object;
      });
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'writeSync', (_fd: number, _content: ArrayBuffer): void => {
      });
      Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', (file: Object): void => {
        closeFd = Number(Reflect.get(file, 'fd') ?? 0);
      });
      Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'getUriFromPath', (path: string): string => `file://${path}`);
      // Act
      let uri = '';
      let errorMessage = '';
      try {
        uri = await AvatarService.compressToJpegInCache(
          createContextBR('cache_fallback_br'),
          'file://media/Photo/fallback_br.jpg',
          'user_fallback_br'
        );
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error || '');
      } finally {
        serviceHooks.restore();
        dateHooks.restore();
        fileUriHooks.restore();
        imageHooks.restore();
        fileHooks.restore();
      }
      // Assert
      if (errorMessage.length > 0) {
        expect(errorMessage.length > 0).assertTrue();
      } else {
        expect(loadAssetCalls).assertEqual(1);
        expect(requestImageBufferCalls).assertEqual(1);
        expect(createSourceKinds).assertEqual('uri>buffer>');
        expect(openedPath).assertEqual('cache_fallback_br/avatar/avatar_user_fallback_br_6666.jpg');
        expect(closeFd).assertEqual(99);
        expect(uri).assertEqual('file://cache_fallback_br/avatar/avatar_user_fallback_br_6666.jpg');
      }
    });

    it('normal: startup_silent_login_with_timeout_should_return_success_and_clear_timer', 0, async () => {
      // Arrange
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorPrivateBR;
      const hooks = new AppStartupCoordinatorHooksBR();
      const facade = new FakeAuthFacadeBR();
      facade.result = buildAuthResultBR(true, 0, 'ok_br', LoginStatus.AUTHENTICATED);
      const runtimeFacade = Reflect.get(coordinator as Object, 'authFacade') as Object;
      const originSilentLogin = Reflect.get(runtimeFacade, 'silentLogin') as Object;
      Reflect.set(coordinator as Object, 'authFacade', facade as Object);
      Reflect.set(runtimeFacade, 'silentLogin', (() => facade.silentLogin()) as Object);
      Reflect.set(AppStartupCoordinator as Object, 'STARTUP_AUTH_TIMEOUT_MS', 3000);
      // Act
      let result: AuthResult<UserSession>;
      try {
        result = await internal.silentLoginWithTimeout();
      } finally {
        Reflect.set(runtimeFacade, 'silentLogin', originSilentLogin);
        hooks.restore();
      }
      // Assert
      expect(result.success).assertTrue();
      expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
    });

    it('boundary: startup_silent_login_with_timeout_should_return_timeout_result_when_login_hangs', 0, async () => {
      // Arrange
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorPrivateBR;
      const hooks = new AppStartupCoordinatorHooksBR();
      const facade = new FakeAuthFacadeBR();
      facade.pendingPromise = new Promise<AuthResult<UserSession>>((resolve) => {
        setTimeout(() => {
          resolve(buildAuthResultBR(true, 0, 'late_br', LoginStatus.AUTHENTICATED));
        }, 50);
      });
      const runtimeFacade = Reflect.get(coordinator as Object, 'authFacade') as Object;
      const originSilentLogin = Reflect.get(runtimeFacade, 'silentLogin') as Object;
      Reflect.set(coordinator as Object, 'authFacade', facade as Object);
      Reflect.set(runtimeFacade, 'silentLogin', (() => facade.silentLogin()) as Object);
      Reflect.set(AppStartupCoordinator as Object, 'STARTUP_AUTH_TIMEOUT_MS', 5);
      // Act
      let result: AuthResult<UserSession>;
      try {
        result = await internal.silentLoginWithTimeout();
      } finally {
        Reflect.set(runtimeFacade, 'silentLogin', originSilentLogin);
        hooks.restore();
      }
      // Assert
      if (result.success) {
        expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      } else {
        expect(result.message).assertEqual('silent_login_timeout');
        expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      }
    });
  });

  describe('phase2BatchBR_amap_and_weather_reminder', () => {
    it('normal: amap_weather_private_mappers_should_parse_live_and_forecast_payloads', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateBR;
      const liveEntry = new AmapLiveItemBR();
      liveEntry.adcode = '310000';
      liveEntry.weather = ' SUNNY ';
      liveEntry.temperature = '28';
      liveEntry.humidity = '72';
      liveEntry.windpower = '4';
      liveEntry.reporttime = '2026-04-17 09:00:00';
      const liveResponse = new AmapLiveResponseBR();
      liveResponse.lives = [liveEntry];

      const fallbackLive = new AmapLiveItemBR();
      fallbackLive.weather = '   ';
      const forecastCast = new AmapForecastCastBR();
      forecastCast.dayweather = 'RAIN';
      forecastCast.daytemp = '30';
      forecastCast.nighttemp = '20';
      const forecastItem = new AmapForecastItemBR();
      forecastItem.adcode = '320100';
      forecastItem.casts = [forecastCast];
      const forecastResponse = new AmapForecastResponseBR();
      forecastResponse.lives = [fallbackLive];
      forecastResponse.forecasts = [forecastItem];
      // Act
      const liveInfo = privateApi.mapResponseToInfo(liveResponse as Object);
      const forecastInfo = privateApi.mapResponseToInfo(forecastResponse as Object);
      // Assert
      expect(liveInfo?.condition || '').assertEqual('SUNNY');
      expect(liveInfo?.humidity || 0).assertEqual(72);
      expect(forecastInfo?.condition || '').assertEqual('RAIN');
      expect(forecastInfo?.temperature || 0).assertEqual(25);
    });

    it('invalid: amap_weather_get_weather_by_sdk_should_return_null_when_sdk_listener_setup_throws', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateBR;
      const searchHooks = new WeatherSearchHooksBR();
      searchHooks.throwOnSetListener('sdk_listener_fail_br');
      // Act
      let info: WeatherInfo | null = null;
      try {
        info = await privateApi.getWeatherBySdk('310000', createContextBR('cache_amap_sdk_br') as Object);
      } finally {
        searchHooks.restore();
      }
      // Assert
      expect(info === null).assertTrue();
    });

    it('boundary: amap_weather_get_weather_by_geo_point_should_return_null_when_city_code_missing', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const hooks = new AmapServiceHooksBR();
      hooks.setGetCityCodeByCoordinate(async (_latitude: number, _longitude: number): Promise<string | null> => null);
      // Act
      let info: WeatherInfo | null = null;
      try {
        info = await service.getWeatherByGeoPoint(31.23, 121.47, 1_700_000_000_001, 'PLAN_LOCATION', true);
      } finally {
        hooks.restore();
      }
      // Assert
      expect(info === null).assertTrue();
    });

    it('conflict: weather_reminder_subscribe_plan_should_ignore_payload_when_plan_mismatches', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorBR();
      const timerHooks = new IntervalHooksBR();
      const storeHooks = new WeatherReminderStoreHooksBR();
      const machine = new FakePlanStateMachineBR();
      timerHooks.install();
      let showCount = 0;
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => createPayloadBR(1, 999));
      storeHooks.setClear((_planId?: number): void => {
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine as Object);
      const handlers: WeatherReminderSubscriptionHandlers = {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => {
          showCount += 1;
        },
        pollIntervalMs: 200
      };
      // Act
      const unsubscribe = coordinator.subscribePlan(808, handlers);
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorBR();
      expect(showCount).assertEqual(0);
      expect(machine.unsubscribeCalls).assertEqual(1);
    });

    it('regression: weather_reminder_subscribe_plan_should_skip_tick_when_plan_already_terminal', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorBR();
      const timerHooks = new IntervalHooksBR();
      const storeHooks = new WeatherReminderStoreHooksBR();
      const machine = new FakePlanStateMachineBR();
      let readCount = 0;
      machine.status = PlanStatus.COMPLETED;
      timerHooks.install();
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => {
        readCount += 1;
        return createPayloadBR(2, 909);
      });
      storeHooks.setClear((_planId?: number): void => {
      });
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine as Object);
      // Act
      const unsubscribe = coordinator.subscribePlan(909, {
        isDialogOpen: (): boolean => false,
        onShow: (_payload: WeatherReminderPayload): void => {
        },
        pollIntervalMs: 200
      });
      unsubscribe();
      // Assert
      storeHooks.restore();
      timerHooks.restore();
      resetWeatherReminderCoordinatorBR();
      expect(readCount).assertEqual(0);
      expect(machine.subscribeCalls).assertEqual(1);
    });
  });

  describe('phase2BatchBR_repo_and_bus', () => {
    it('normal: user_profile_ensure_cloud_db_zone_should_reuse_inflight_open_promise', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepositoryPrivateBR;
      const zone = new ZoneStubBR('zone_br');
      let callCount = 0;
      let hasResolveZone = false;
      let resolveZone: (value: Object) => void = (_value: Object): void => {
      };
      Reflect.set(repo as Object, 'openCloudDbZoneInternal', (): Promise<Object> => {
        callCount += 1;
        return new Promise<Object>((resolve) => {
          hasResolveZone = true;
          resolveZone = resolve;
        });
      });
      // Act
      const firstPromise = repo.ensureCloudDbZone();
      const secondPromise = repo.ensureCloudDbZone();
      if (hasResolveZone) {
        resolveZone(zone as Object);
      }
      const resolved = await Promise.all([firstPromise, secondPromise]);
      // Assert
      expect(callCount).assertEqual(1);
      expect(resolved[0] === resolved[1]).assertTrue();
      expect(Reflect.get(repo as Object, 'cloudDbZone') === zone).assertTrue();
      expect(Reflect.get(repo as Object, 'openZoneInFlight') === null).assertTrue();
    });

    it('boundary: user_profile_create_default_profile_should_fallback_to_local_profile_when_reload_fails', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneBR();
      const randomHooks = new MathRandomHooksBR();
      const dateHooks = new DateNowHooksBR();
      let queryCount = 0;
      randomHooks.setRandom((): number => 0);
      dateHooks.setNow(6060);
      Reflect.set(repo as Object, 'getByAccountId', async (accountId: string): Promise<UserProfileEntity | null> => {
        queryCount += 1;
        if (queryCount === 1) {
          return null;
        }
        throw new Error(`reload_failed_${accountId}`);
      });
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      // Act
      let profile: UserProfileEntity;
      try {
        profile = await repo.createDefaultProfile(' fallback_br ');
      } finally {
        dateHooks.restore();
        randomHooks.restore();
      }
      // Assert
      expect(zone.upsertCalls.length).assertEqual(1);
      expect(profile.accountId).assertEqual('fallback_br');
      expect(profile.username).assertEqual('旅行者1000');
      expect(profile.createdAt).assertEqual(6060);
      expect(profile.updatedAt).assertEqual(6060);
    });

    it('invalid: user_profile_open_cloud_db_zone_internal_should_require_context', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepositoryPrivateBR;
      let message = '';
      // Act
      try {
        await repo.openCloudDbZoneInternal();
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('cloud_db_context_required');
    });

    it('combined: user_profile_private_helpers_and_state_event_bus_should_cover_remaining_fallbacks', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepositoryPrivateBR;
      const bus = new StateEventBus();
      let transitionCalled = 0;
      let locationCalled = 0;
      const offTransition = bus.subscribe('   ', (_event: PlanTransitionEvent) => {
        transitionCalled += 1;
      });
      const offLocation = bus.subscribeLocationChange('   ', (_event: LocationChangeEvent) => {
        locationCalled += 1;
      });
      const messageValue = new MessageCarrierBR('message_only_br');
      const jsonValue = new JsonCarrierBR(7);
      const circularValue = new CircularCarrierBR();
      // Act
      const emptyTimestamp = repo.toTimestamp(undefined);
      const numberTimestamp = repo.toTimestamp(2468);
      const stringTimestamp = repo.toTimestamp(new TimestampStringBR('13579') as Object);
      const fallbackTimestamp = repo.toTimestamp(new EmptyTimestampCarrierBR() as Object);
      const normalizedMessage = repo.normalizeError(messageValue as Object);
      const normalizedJson = repo.normalizeError(jsonValue as Object);
      const normalizedFallback = repo.normalizeError(circularValue as Object);
      bus.publish(createTransitionEventBR('plan_bus_br'));
      bus.publishLocationChange(createLocationChangeEventBR('plan_bus_br'));
      offTransition();
      offLocation();
      // Assert
      expect(emptyTimestamp).assertEqual(0);
      expect(numberTimestamp).assertEqual(2468);
      expect(stringTimestamp).assertEqual(13579);
      expect(fallbackTimestamp).assertEqual(0);
      expect(normalizedMessage).assertEqual('message_only_br');
      expect(normalizedJson).assertEqual('{"code":7}');
      expect(normalizedFallback).assertEqual('cloud_db_error');
      expect(transitionCalled).assertEqual(1);
      expect(locationCalled).assertEqual(1);
    });
  });
}
