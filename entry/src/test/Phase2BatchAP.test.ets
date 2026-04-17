import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import image from '@ohos.multimedia.image';
import util from '@ohos.util';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { AuthApiResponse, AuthSessionPayload, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { AvatarProfile, AvatarUploadInput, AvatarUploadResult } from '../main/ets/domain/auth/AvatarModels';
import { AuthResult, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';
import { AppStartupCoordinator } from '../main/ets/infrastructure/auth/AppStartupCoordinator';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';
import { HuaweiAccountProvider } from '../main/ets/infrastructure/auth/HuaweiAccountProvider';
import { AvatarPickerPort, AvatarService, AvatarStorePort } from '../main/ets/infrastructure/avatar/AvatarService';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AvatarUploadPort } from '../main/ets/infrastructure/avatar/AvatarUploadPort';
import photoAccessHelper from '@ohos.file.photoAccessHelper';

interface AuthErrorAP { code: number }
interface InvalidCredentialAP {
  authorizationCode: null;
  idToken: undefined;
  openID: number;
  unionID: boolean;
}
interface FdObjectAP { fd: number }
interface StatObjectAP { size: number }
interface ImageSourceInlineAP { createPixelMap: () => Promise<Object> }
interface ImagePackerInlineAP { packToData: () => Promise<ArrayBuffer> }

class FakeContextAP {
  cacheDir: string = '/cache_ap';
}

function fakeContextAP(): common.Context {
  return new FakeContextAP() as Object as common.Context;
}

function resetAuthStorageAP(): void {
  AppStorage.setOrCreate(AppStorageKeys.AUTH_SESSION_JSON, '');
  AppStorage.setOrCreate(AppStorageKeys.AUTH_GUEST_CHOSEN, false);
  AppStorage.setOrCreate(AppStorageKeys.AUTH_BLOCK_SILENT_AFTER_LOGOUT, false);
}

function buildSessionPayloadAP(expireAt: number): AuthSessionPayload {
  const payload = new AuthSessionPayload();
  payload.accountId = 'acc_ap';
  payload.userId = 'user_ap';
  payload.isGuest = false;
  payload.loginMethod = 'HUAWEI';
  payload.accessToken = 'access_ap';
  payload.refreshToken = 'refresh_ap';
  payload.sessionId = 'session_ap';
  payload.expireAt = expireAt;
  return payload;
}

function cloneAvatarProfileAP(source: AvatarProfile): AvatarProfile {
  const profile = new AvatarProfile();
  profile.userId = source.userId || '';
  profile.localUri = source.localUri || '';
  profile.compressedUri = source.compressedUri || '';
  profile.cloudUrl = source.cloudUrl || '';
  profile.uploadState = source.uploadState || 'EMPTY';
  profile.updatedAt = Number(source.updatedAt) > 0 ? Number(source.updatedAt) : 0;
  return profile;
}

function buildAvatarProfileAP(userId: string): AvatarProfile {
  const profile = new AvatarProfile();
  profile.userId = userId;
  profile.localUri = 'file://local_ap.jpg';
  profile.compressedUri = '';
  profile.cloudUrl = '';
  profile.uploadState = 'EMPTY';
  profile.updatedAt = 1;
  return profile;
}

function buildAuthResultAP(
  success: boolean,
  code: number,
  message: string,
  status: LoginStatus
): AuthResult<UserSession> {
  const result = new AuthResult<UserSession>();
  result.success = success;
  result.code = code;
  result.message = message;
  result.source = 'HUAWEI_SILENT';
  result.status = status;
  result.data = success ? new UserSession() : null;
  return result;
}

class PreferenceManagerHooksAP {
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

class PreferenceManagerStubAP {
  public initCount: number = 0;
  public lastContext: Object | null = null;
  public guestChosenValue: boolean = false;
  public blockedValue: boolean = false;
  public sessionCacheJsonValue: string = '';
  public avatarProfileValue: AvatarProfile = new AvatarProfile();
  public savedAvatarProfile: AvatarProfile | null = null;
  public lastAvatarUserId: string = '';
  public setGuestChosenCalls: boolean[] = [];
  public setBlockedCalls: boolean[] = [];
  public setSessionCalls: string[] = [];
  public initError: string = '';
  public getGuestChosenError: string = '';
  public setGuestChosenError: string = '';
  public getBlockedError: string = '';
  public setBlockedError: string = '';
  public getSessionError: string = '';
  public setSessionError: string = '';
  public getAvatarProfileError: string = '';
  public setAvatarProfileError: string = '';

  public async init(context: Object): Promise<void> {
    this.initCount += 1;
    this.lastContext = context;
    if (this.initError) {
      throw new Error(this.initError);
    }
  }

  public async isGuestChosen(): Promise<boolean> {
    if (this.getGuestChosenError) {
      throw new Error(this.getGuestChosenError);
    }
    return this.guestChosenValue;
  }

  public async setGuestChosen(chosen: boolean): Promise<void> {
    if (this.setGuestChosenError) {
      throw new Error(this.setGuestChosenError);
    }
    this.guestChosenValue = chosen;
    this.setGuestChosenCalls.push(chosen);
  }

  public async isSilentLoginBlockedAfterLogout(): Promise<boolean> {
    if (this.getBlockedError) {
      throw new Error(this.getBlockedError);
    }
    return this.blockedValue;
  }

  public async setSilentLoginBlockedAfterLogout(blocked: boolean): Promise<void> {
    if (this.setBlockedError) {
      throw new Error(this.setBlockedError);
    }
    this.blockedValue = blocked;
    this.setBlockedCalls.push(blocked);
  }

  public async getSessionCacheJson(): Promise<string> {
    if (this.getSessionError) {
      throw new Error(this.getSessionError);
    }
    return this.sessionCacheJsonValue;
  }

  public async setSessionCacheJson(raw: string): Promise<void> {
    if (this.setSessionError) {
      throw new Error(this.setSessionError);
    }
    this.sessionCacheJsonValue = raw;
    this.setSessionCalls.push(raw);
  }

  public async getAvatarProfile(userId: string): Promise<AvatarProfile> {
    if (this.getAvatarProfileError) {
      throw new Error(this.getAvatarProfileError);
    }
    this.lastAvatarUserId = userId;
    return cloneAvatarProfileAP(this.avatarProfileValue);
  }

  public async setAvatarProfile(profile: AvatarProfile): Promise<void> {
    if (this.setAvatarProfileError) {
      throw new Error(this.setAvatarProfileError);
    }
    this.savedAvatarProfile = cloneAvatarProfileAP(profile);
  }
}

class FakeAuthFacadeAP {
  public callCount: number = 0;
  public result: AuthResult<UserSession> | null = null;
  public pendingPromise: Promise<AuthResult<UserSession>> | null = null;

  public async silentLogin(): Promise<AuthResult<UserSession>> {
    this.callCount += 1;
    if (this.pendingPromise) {
      return this.pendingPromise;
    }
    if (this.result) {
      return this.result;
    }
    return buildAuthResultAP(false, -1, 'unset', LoginStatus.UNAUTHENTICATED);
  }
}

class DeferredAuthResultAP {
  public promise: Promise<AuthResult<UserSession>>;
  private resolver: ((value: AuthResult<UserSession>) => void) | null = null;

  constructor() {
    this.promise = new Promise<AuthResult<UserSession>>((resolve) => {
      this.resolver = resolve;
    });
  }

  public resolve(value: AuthResult<UserSession>): void {
    if (this.resolver) {
      this.resolver(value);
    }
  }
}

interface AppStartupCoordinatorInternalAP {
  authFacade: FakeAuthFacadeAP;
  startupAuthInFlight: Promise<AuthResult<UserSession>> | null;
  silentLoginWithTimeout: () => Promise<AuthResult<UserSession>>;
}

class AppStartupCoordinatorHooksAP {
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

class LoginRequestMockAP {
  forceLogin: boolean = false;
}

class LoginCredentialMockAP {
  authorizationCode: string = '';
  idToken: string = '';
  openID: string = '';
  unionID: string = '';
}

class LoginResponseMockAP {
  data: LoginCredentialMockAP | null = null;
}

class HuaweiIDProviderStubAP {
  public createLoginWithHuaweiIDRequest(): LoginRequestMockAP {
    const request = new LoginRequestMockAP();
    AuthenticationControllerStubAP.lastCreatedRequest = request;
    return request;
  }
}

class AuthenticationControllerStubAP {
  public static response: LoginResponseMockAP | null = null;
  public static error: Object | null = null;
  public static lastContext: Object | null = null;
  public static lastRequest: Object | null = null;
  public static lastCreatedRequest: LoginRequestMockAP | null = null;

  constructor(context?: Object) {
    AuthenticationControllerStubAP.lastContext = context ?? null;
  }

  public async executeRequest(request: Object): Promise<Object> {
    AuthenticationControllerStubAP.lastRequest = request;
    if (AuthenticationControllerStubAP.error) {
      throw new Error(String(AuthenticationControllerStubAP.error));
    }
    return AuthenticationControllerStubAP.response as Object;
  }

  public static reset(): void {
    AuthenticationControllerStubAP.response = null;
    AuthenticationControllerStubAP.error = null;
    AuthenticationControllerStubAP.lastContext = null;
    AuthenticationControllerStubAP.lastRequest = null;
    AuthenticationControllerStubAP.lastCreatedRequest = null;
  }
}

class AccountKitHooksAP {
  private readonly originProvider: Object;
  private readonly originController: Object;

  constructor() {
    const authObj: Object = Reflect.get(globalThis, 'authentication') as Object;
    this.originProvider = Reflect.get(authObj, 'HuaweiIDProvider') as Object;
    this.originController = Reflect.get(authObj, 'AuthenticationController') as Object;
  }

  public useStubs(): void {
    const authObj: Object = Reflect.get(globalThis, 'authentication') as Object;
    Reflect.set(authObj, 'HuaweiIDProvider', HuaweiIDProviderStubAP as Object);
    Reflect.set(authObj, 'AuthenticationController', AuthenticationControllerStubAP as Object);
    AuthenticationControllerStubAP.reset();
  }

  public restore(): void {
    const authObj: Object = Reflect.get(globalThis, 'authentication') as Object;
    Reflect.set(authObj, 'HuaweiIDProvider', this.originProvider);
    Reflect.set(authObj, 'AuthenticationController', this.originController);
    AuthenticationControllerStubAP.reset();
  }
}

class AvatarStoreStubAP implements AvatarStorePort {
  public profileToLoad: AvatarProfile = new AvatarProfile();
  public loadCalls: string[] = [];
  public savedProfiles: AvatarProfile[] = [];
  public loadError: string = '';
  public saveError: string = '';

  public async loadAvatarProfile(userId: string): Promise<AvatarProfile> {
    this.loadCalls.push(userId);
    if (this.loadError) {
      throw new Error(this.loadError);
    }
    return cloneAvatarProfileAP(this.profileToLoad);
  }

  public async saveAvatarProfile(profile: AvatarProfile): Promise<void> {
    if (this.saveError) {
      throw new Error(this.saveError);
    }
    this.savedProfiles.push(cloneAvatarProfileAP(profile));
  }
}

class AvatarPickerStubAP implements AvatarPickerPort {
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

class AvatarUploaderStubAP implements AvatarUploadPort {
  public inputs: AvatarUploadInput[] = [];
  public result: AvatarUploadResult = new AvatarUploadResult();
  public errorMessage: string = '';

  public async uploadAvatar(input: AvatarUploadInput): Promise<AvatarUploadResult> {
    const copy = new AvatarUploadInput();
    copy.userId = input.userId;
    copy.fileUri = input.fileUri;
    copy.mimeType = input.mimeType;
    copy.byteSize = input.byteSize;
    this.inputs.push(copy);
    if (this.errorMessage) {
      throw new Error(this.errorMessage);
    }
    return this.result;
  }
}

interface PixelMapStubAP {
  kind: string;
}

class ImageSourceStubAP {
  public async createPixelMap(): Promise<Object> {
    const result: PixelMapStubAP = { kind: 'pixel_map_ap' };
    return result as Object;
  }
}

class ImagePackerStubAP {
  public async packToData(_pixelMap: Object, _options: Object): Promise<ArrayBuffer> {
    return new Uint8Array([1, 2, 3]).buffer;
  }
}

class Base64HelperStubAP {
  public encodeToStringSync(_content: Uint8Array, _type: Object): string {
    return 'QUJD';
  }
}

class FileUriCtorStubAP {
  path: string;

  constructor(raw: string) {
    this.path = raw.replace('file://', '');
  }
}

class FileIoHooksAP {
  private readonly originAccessSync: Object;
  private readonly originMkdirSync: Object;
  private readonly originOpenSync: Object;
  private readonly originWriteSync: Object;
  private readonly originCloseSync: Object;
  private readonly originStatSync: Object;
  private readonly originReadSync: Object;
  private readonly originOpenMode: Object;

  constructor() {
    const fileIoObj: Object = Reflect.get(globalThis, 'fileIo') as Object;
    this.originAccessSync = Reflect.get(fileIoObj, 'accessSync') as Object;
    this.originMkdirSync = Reflect.get(fileIoObj, 'mkdirSync') as Object;
    this.originOpenSync = Reflect.get(fileIoObj, 'openSync') as Object;
    this.originWriteSync = Reflect.get(fileIoObj, 'writeSync') as Object;
    this.originCloseSync = Reflect.get(fileIoObj, 'closeSync') as Object;
    this.originStatSync = Reflect.get(fileIoObj, 'statSync') as Object;
    this.originReadSync = Reflect.get(fileIoObj, 'readSync') as Object;
    this.originOpenMode = Reflect.get(fileIoObj, 'OpenMode') as Object;
  }

  public restore(): void {
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'accessSync', this.originAccessSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'mkdirSync', this.originMkdirSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', this.originOpenSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'writeSync', this.originWriteSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', this.originCloseSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'statSync', this.originStatSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'readSync', this.originReadSync);
    Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'OpenMode', this.originOpenMode);
  }
}

class ImageHooksAP {
  private readonly originCreateImageSource: Object;
  private readonly originCreateImagePacker: Object;

  constructor() {
    this.originCreateImageSource = Reflect.get(Reflect.get(globalThis, 'image') as Object, 'createImageSource') as Object;
    this.originCreateImagePacker = Reflect.get(Reflect.get(globalThis, 'image') as Object, 'createImagePacker') as Object;
  }

  public restore(): void {
    Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImageSource', this.originCreateImageSource);
    Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImagePacker', this.originCreateImagePacker);
  }
}

class FileUriHooksAP {
  private readonly originFileUri: Object;
  private readonly originGetUriFromPath: Object;

  constructor() {
    this.originFileUri = Reflect.get(Reflect.get(globalThis, 'fileUri') as Object, 'FileUri') as Object;
    this.originGetUriFromPath = Reflect.get(Reflect.get(globalThis, 'fileUri') as Object, 'getUriFromPath') as Object;
  }

  public restore(): void {
    Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'FileUri', this.originFileUri);
    Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'getUriFromPath', this.originGetUriFromPath);
  }
}

class UtilHooksAP {
  private readonly originBase64Helper: Object;

  constructor() {
    this.originBase64Helper = Reflect.get(Reflect.get(globalThis, 'util') as Object, 'Base64Helper') as Object;
  }

  public restore(): void {
    Reflect.set(Reflect.get(globalThis, 'util') as Object, 'Base64Helper', this.originBase64Helper);
  }
}

export default function phase2BatchAPTest() {
  describe('phase2BatchAP_auth_session_store_memory', () => {
    it('normal: save_and_load_should_roundtrip_and_keep_token_available', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const payload = buildSessionPayloadAP(Date.now() + 60_000);

      AuthSessionStore.save(payload);
      const loaded = AuthSessionStore.load();
      const token = AuthSessionStore.getAccessToken();

      expect(loaded !== null).assertTrue();
      expect(loaded?.accountId || '').assertEqual('acc_ap');
      expect(token).assertEqual('access_ap');
    });

    it('boundary: load_and_flags_should_fallback_when_storage_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();

      const loaded = AuthSessionStore.load();
      const guestChosen = AuthSessionStore.hasGuestChosen();
      const blocked = AuthSessionStore.isSilentLoginBlockedAfterLogout();

      expect(loaded === null).assertTrue();
      expect(guestChosen).assertFalse();
      expect(blocked).assertFalse();
    });

    it('invalid: malformed_raw_session_should_return_null_and_empty_token', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      AppStorage.setOrCreate(AppStorageKeys.AUTH_SESSION_JSON, '{bad_json');

      const loaded = AuthSessionStore.load();
      const token = AuthSessionStore.getAccessToken();

      expect(loaded === null).assertTrue();
      expect(token).assertEqual('');
    });

    it('normal: guest_flag_methods_should_set_and_read_true', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();

      AuthSessionStore.markGuestChosen();
      const chosen = AuthSessionStore.hasGuestChosen();

      expect(chosen).assertTrue();
    });

    it('boundary: guest_flag_should_remain_true_after_repeat_mark', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();

      AuthSessionStore.markGuestChosen();
      AuthSessionStore.markGuestChosen();

      expect(AuthSessionStore.hasGuestChosen()).assertTrue();
    });

    it('invalid: saving_empty_required_fields_should_make_followup_load_unavailable', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const payload = buildSessionPayloadAP(Date.now() + 60_000);
      payload.accessToken = '';
      payload.refreshToken = '';
      payload.sessionId = '';

      AuthSessionStore.save(payload);
      const loaded = AuthSessionStore.load();

      expect(loaded === null).assertTrue();
    });

    it('normal: silent_block_methods_should_set_read_and_clear_flag', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();

      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      const blocked = AuthSessionStore.isSilentLoginBlockedAfterLogout();
      AuthSessionStore.clearSilentLoginBlockedAfterLogout();
      const cleared = AuthSessionStore.isSilentLoginBlockedAfterLogout();

      expect(blocked).assertTrue();
      expect(cleared).assertFalse();
    });

    it('boundary: clear_should_be_safe_when_session_absent_and_block_not_set', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();

      AuthSessionStore.clear();
      AuthSessionStore.clearSilentLoginBlockedAfterLogout();

      expect(AuthSessionStore.load() === null).assertTrue();
      expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertFalse();
    });
  });

  describe('phase2BatchAP_auth_session_store_persisted', () => {
    it('normal: mark_guest_chosen_persisted_should_update_memory_and_preference', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.markGuestChosenPersisted(fakeContextAP());

        expect(AuthSessionStore.hasGuestChosen()).assertTrue();
        expect(pref.guestChosenValue).assertTrue();
        expect(pref.setGuestChosenCalls.length).assertEqual(1);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: has_guest_chosen_persisted_should_short_circuit_when_memory_flag_already_true', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      AuthSessionStore.markGuestChosen();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      try {
        const chosen = await AuthSessionStore.hasGuestChosenPersisted(fakeContextAP());

        expect(chosen).assertTrue();
        expect(pref.initCount).assertEqual(0);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: has_guest_chosen_persisted_should_throw_when_preference_read_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.getGuestChosenError = 'guest_pref_read_failed';
      hooks.setInstance(pref);
      let message = '';
      try {
        await AuthSessionStore.hasGuestChosenPersisted(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('guest_pref_read_failed');
      done();
    });

    it('normal: has_guest_chosen_persisted_should_hydrate_memory_from_preference', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.guestChosenValue = true;
      hooks.setInstance(pref);
      try {
        const chosen = await AuthSessionStore.hasGuestChosenPersisted(fakeContextAP());

        expect(chosen).assertTrue();
        expect(AuthSessionStore.hasGuestChosen()).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: mark_guest_chosen_persisted_should_keep_memory_flag_when_init_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.initError = 'pref_init_failed_guest';
      hooks.setInstance(pref);
      let message = '';
      try {
        await AuthSessionStore.markGuestChosenPersisted(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('pref_init_failed_guest');
      expect(AuthSessionStore.hasGuestChosen()).assertTrue();
      done();
    });

    it('normal: mark_silent_block_persisted_should_update_memory_and_preference', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.markSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());

        expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertTrue();
        expect(pref.blockedValue).assertTrue();
        expect(pref.setBlockedCalls.length).assertEqual(1);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: is_silent_block_persisted_should_short_circuit_when_memory_flag_already_true', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      try {
        const blocked = await AuthSessionStore.isSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());

        expect(blocked).assertTrue();
        expect(pref.initCount).assertEqual(0);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: is_silent_block_persisted_should_throw_when_preference_read_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.getBlockedError = 'silent_block_read_failed';
      hooks.setInstance(pref);
      let message = '';
      try {
        await AuthSessionStore.isSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('silent_block_read_failed');
      done();
    });

    it('normal: is_silent_block_persisted_should_hydrate_memory_from_preference', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.blockedValue = true;
      hooks.setInstance(pref);
      try {
        const blocked = await AuthSessionStore.isSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());

        expect(blocked).assertTrue();
        expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('normal: clear_silent_block_persisted_should_reset_memory_and_preference', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.blockedValue = true;
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.clearSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());

        expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertFalse();
        expect(pref.blockedValue).assertFalse();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: clear_silent_block_persisted_should_keep_false_when_already_cleared', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.clearSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());

        expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertFalse();
        expect(pref.setBlockedCalls[0]).assertFalse();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: clear_silent_block_persisted_should_keep_memory_false_when_init_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.initError = 'pref_init_failed_clear';
      hooks.setInstance(pref);
      let message = '';
      try {
        await AuthSessionStore.clearSilentLoginBlockedAfterLogoutPersisted(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('pref_init_failed_clear');
      expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertFalse();
      done();
    });

    it('normal: save_and_load_session_persisted_should_roundtrip_payload', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      const payload = buildSessionPayloadAP(Date.now() + 120_000);
      try {
        await AuthSessionStore.saveSessionPersisted(fakeContextAP(), payload);
        const loaded = await AuthSessionStore.loadSessionPersisted(fakeContextAP());

        expect(pref.setSessionCalls.length).assertEqual(1);
        expect(loaded !== null).assertTrue();
        expect(loaded?.sessionId || '').assertEqual('session_ap');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: load_session_persisted_should_return_null_when_cache_empty', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.sessionCacheJsonValue = '';
      hooks.setInstance(pref);
      try {
        const loaded = await AuthSessionStore.loadSessionPersisted(fakeContextAP());

        expect(loaded === null).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: load_session_persisted_should_return_null_when_cache_json_invalid', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.sessionCacheJsonValue = '{bad_json';
      hooks.setInstance(pref);
      try {
        const loaded = await AuthSessionStore.loadSessionPersisted(fakeContextAP());

        expect(loaded === null).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: save_session_persisted_should_sanitize_optional_fields_to_empty_strings', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      const payload = buildSessionPayloadAP(Date.now() + 60_000);
      payload.accountId = '';
      payload.userId = '';
      payload.loginMethod = '';
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.saveSessionPersisted(fakeContextAP(), payload);
        const parsed = JSON.parse(pref.sessionCacheJsonValue) as Record<string, Object>;

        expect(String(parsed['accountId'] || '')).assertEqual('');
        expect(String(parsed['userId'] || '')).assertEqual('');
        expect(String(parsed['loginMethod'] || '')).assertEqual('');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: save_session_persisted_should_throw_when_preference_write_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.setSessionError = 'session_write_failed';
      hooks.setInstance(pref);
      let message = '';
      try {
        await AuthSessionStore.saveSessionPersisted(fakeContextAP(), buildSessionPayloadAP(Date.now() + 60_000));
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('session_write_failed');
      done();
    });

    it('normal: clear_session_persisted_should_write_empty_cache', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.sessionCacheJsonValue = 'non_empty';
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.clearSessionPersisted(fakeContextAP());

        expect(pref.sessionCacheJsonValue).assertEqual('');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: clear_session_persisted_should_stay_empty_on_repeat_calls', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      try {
        await AuthSessionStore.clearSessionPersisted(fakeContextAP());
        await AuthSessionStore.clearSessionPersisted(fakeContextAP());

        expect(pref.setSessionCalls.length).assertEqual(2);
        expect(pref.sessionCacheJsonValue).assertEqual('');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: clear_session_persisted_should_throw_when_preference_write_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.setSessionError = 'clear_session_failed';
      hooks.setInstance(pref);
      let message = '';
      try {
        await AuthSessionStore.clearSessionPersisted(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('clear_session_failed');
      done();
    });
  });

  describe('phase2BatchAP_app_startup_coordinator', () => {
    it('normal: get_instance_should_return_singleton', 0, () => {
      // Arrange
      // Act
      // Assert
      const first = AppStartupCoordinator.getInstance();
      const second = AppStartupCoordinator.getInstance();

      expect(first === second).assertTrue();
    });

    it('normal: check_startup_auth_should_return_authenticated_when_silent_login_succeeds', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AppStartupCoordinatorHooksAP();
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorInternalAP;
      const fake = new FakeAuthFacadeAP();
      fake.result = buildAuthResultAP(true, 0, 'ok', LoginStatus.AUTHENTICATED);
      Reflect.set(coordinator as Object, 'authFacade', fake);
      internal.startupAuthInFlight = null;
      try {
        const result = await coordinator.checkStartupAuth();

        expect(result.success).assertTrue();
        expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: check_startup_auth_should_reuse_single_inflight_promise', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AppStartupCoordinatorHooksAP();
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorInternalAP;
      const fake = new FakeAuthFacadeAP();
      const deferred = new DeferredAuthResultAP();
      fake.pendingPromise = deferred.promise;
      Reflect.set(coordinator as Object, 'authFacade', fake);
      internal.startupAuthInFlight = null;
      try {
        const p1 = coordinator.checkStartupAuth();
        const p2 = coordinator.checkStartupAuth();
        deferred.resolve(buildAuthResultAP(true, 0, 'ok', LoginStatus.AUTHENTICATED));
        const results = await Promise.all([p1, p2]);

        expect(fake.callCount).assertEqual(1);
        expect(results[0].success).assertTrue();
        expect(results[1].success).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: check_startup_auth_should_normalize_failed_login_to_unauthenticated', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AppStartupCoordinatorHooksAP();
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorInternalAP;
      const fake = new FakeAuthFacadeAP();
      fake.result = buildAuthResultAP(false, 401, 'expired', LoginStatus.LOGIN_FAILED);
      Reflect.set(coordinator as Object, 'authFacade', fake);
      internal.startupAuthInFlight = null;
      try {
        const result = await coordinator.checkStartupAuth();

        expect(result.success).assertFalse();
        expect(result.code).assertEqual(401);
        expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: silent_login_with_timeout_should_return_timeout_result_when_promise_never_resolves', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AppStartupCoordinatorHooksAP();
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorInternalAP;
      const fake = new FakeAuthFacadeAP();
      fake.pendingPromise = new Promise<AuthResult<UserSession>>((_resolve) => {
        return;
      });
      Reflect.set(coordinator as Object, 'authFacade', fake);
      Reflect.set(AppStartupCoordinator as Object, 'STARTUP_AUTH_TIMEOUT_MS', 1);
      try {
        const result = await internal.silentLoginWithTimeout();

        expect(result.success).assertFalse();
        expect(result.message).assertEqual('silent_login_timeout');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('normal: silent_login_with_timeout_should_return_auth_result_before_timeout', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AppStartupCoordinatorHooksAP();
      const coordinator = AppStartupCoordinator.getInstance();
      const internal = coordinator as Object as AppStartupCoordinatorInternalAP;
      const fake = new FakeAuthFacadeAP();
      fake.result = buildAuthResultAP(true, 0, 'ok', LoginStatus.AUTHENTICATED);
      Reflect.set(coordinator as Object, 'authFacade', fake);
      Reflect.set(AppStartupCoordinator as Object, 'STARTUP_AUTH_TIMEOUT_MS', 1000);
      try {
        const result = await internal.silentLoginWithTimeout();

        expect(result.success).assertTrue();
        expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      } finally {
        hooks.restore();
      }
      done();
    });
  });

  describe('phase2BatchAP_huawei_account_provider', () => {
    it('normal: get_instance_should_return_singleton_instance', 0, () => {
      // Arrange
      // Act
      // Assert
      const first = HuaweiAccountProvider.getInstance();
      const second = HuaweiAccountProvider.getInstance();

      expect(first === second).assertTrue();
    });

    it('normal: explicit_login_should_execute_force_login_request', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AccountKitHooksAP();
      hooks.useStubs();
      const credential = new LoginCredentialMockAP();
      credential.authorizationCode = 'code_explicit';
      credential.idToken = 'token_explicit';
      credential.openID = 'open_explicit';
      credential.unionID = 'union_explicit';
      const response = new LoginResponseMockAP();
      response.data = credential;
      AuthenticationControllerStubAP.response = response;
      const provider = HuaweiAccountProvider.getInstance();
      try {
        const normalized = await provider.explicitLogin(fakeContextAP());

        expect(normalized.authorizationCode).assertEqual('code_explicit');
        expect(AuthenticationControllerStubAP.lastCreatedRequest?.forceLogin === true).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: explicit_login_should_allow_undefined_context', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AccountKitHooksAP();
      hooks.useStubs();
      const response = new LoginResponseMockAP();
      response.data = new LoginCredentialMockAP();
      AuthenticationControllerStubAP.response = response;
      const provider = HuaweiAccountProvider.getInstance();
      try {
        const normalized = await provider.explicitLogin();

        expect(AuthenticationControllerStubAP.lastContext === null).assertTrue();
        expect(normalized.authorizationCode).assertEqual('');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: explicit_login_should_throw_when_credential_missing', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AccountKitHooksAP();
      hooks.useStubs();
      const response = new LoginResponseMockAP();
      response.data = null;
      AuthenticationControllerStubAP.response = response;
      const provider = HuaweiAccountProvider.getInstance();
      let message = '';
      try {
        await provider.explicitLogin(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('HUAWEI_CREDENTIAL_EMPTY');
      done();
    });

    it('normal: silent_login_should_execute_non_force_request', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AccountKitHooksAP();
      hooks.useStubs();
      const credential = new LoginCredentialMockAP();
      credential.authorizationCode = 'code_silent';
      credential.openID = 'open_silent';
      const response = new LoginResponseMockAP();
      response.data = credential;
      AuthenticationControllerStubAP.response = response;
      const provider = HuaweiAccountProvider.getInstance();
      try {
        const normalized = await provider.silentLogin(fakeContextAP());

        expect(normalized.authorizationCode).assertEqual('code_silent');
        expect(AuthenticationControllerStubAP.lastCreatedRequest?.forceLogin === false).assertTrue();
      } finally {
        hooks.restore();
      }
      done();
    });

    it('boundary: silent_login_should_normalize_missing_fields_to_empty_strings', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AccountKitHooksAP();
      hooks.useStubs();
      const response = new LoginResponseMockAP();
      response.data = new LoginCredentialMockAP();
      AuthenticationControllerStubAP.response = response;
      const provider = HuaweiAccountProvider.getInstance();
      try {
        const normalized = await provider.silentLogin(fakeContextAP());

        expect(normalized.authorizationCode).assertEqual('');
        expect(normalized.openId).assertEqual('');
      } finally {
        hooks.restore();
      }
      done();
    });

    it('invalid: silent_login_should_map_non_error_throwable_to_provider_error', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new AccountKitHooksAP();
      hooks.useStubs();
      const authErr: AuthErrorAP = { code: 7001 };
      AuthenticationControllerStubAP.error = authErr as Object;
      const provider = HuaweiAccountProvider.getInstance();
      let message = '';
      try {
        await provider.silentLogin(fakeContextAP());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('auth_provider_error');
      done();
    });

    it('normal: from_authentication_credential_should_map_all_fields', 0, () => {
      // Arrange
      // Act
      // Assert
      const provider = HuaweiAccountProvider.getInstance();
      const credential = new LoginCredentialMockAP();
      credential.authorizationCode = 'code_map';
      credential.idToken = 'token_map';
      credential.openID = 'open_map';
      credential.unionID = 'union_map';

      const normalized = provider.fromAuthenticationCredential(credential as never);

      expect(normalized.authorizationCode).assertEqual('code_map');
      expect(normalized.idToken).assertEqual('token_map');
      expect(normalized.openId).assertEqual('open_map');
      expect(normalized.unionId).assertEqual('union_map');
    });

    it('boundary: from_authentication_credential_should_keep_openid_and_unionid_independent', 0, () => {
      // Arrange
      // Act
      // Assert
      const provider = HuaweiAccountProvider.getInstance();
      const credential = new LoginCredentialMockAP();
      credential.openID = 'open_only';
      credential.unionID = 'union_only';

      const normalized = provider.fromAuthenticationCredential(credential as never);

      expect(normalized.openId).assertEqual('open_only');
      expect(normalized.unionId).assertEqual('union_only');
    });

    it('invalid: from_authentication_credential_should_fallback_for_invalid_runtime_values', 0, () => {
      // Arrange
      // Act
      // Assert
      const provider = HuaweiAccountProvider.getInstance();
      const invalidCredential: InvalidCredentialAP = {
        authorizationCode: null,
        idToken: undefined,
        openID: 0,
        unionID: false
      };

      const normalized = provider.fromAuthenticationCredential(invalidCredential as never);

      expect(normalized.authorizationCode).assertEqual('');
      expect(normalized.idToken).assertEqual('');
      expect(normalized.openId).assertEqual('');
      expect(normalized.unionId).assertEqual('');
    });
  });

  describe('phase2BatchAP_avatar_service', () => {
    it('normal: create_default_should_use_preference_store_for_load', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const prefHooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      const stored = buildAvatarProfileAP('u_default_ap');
      stored.cloudUrl = 'https://stored.example/avatar.jpg';
      pref.avatarProfileValue = stored;
      prefHooks.setInstance(pref);
      try {
        const service = AvatarService.createDefault(fakeContextAP());
        const profile = await service.loadAvatarProfile('u_default_ap', 'https://remote.example/avatar.jpg');

        expect(pref.lastAvatarUserId).assertEqual('u_default_ap');
        expect(profile.cloudUrl).assertEqual('https://stored.example/avatar.jpg');
      } finally {
        prefHooks.restore();
      }
      done();
    });

    it('boundary: create_default_should_fallback_blank_user_to_guest_local', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const prefHooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      prefHooks.setInstance(pref);
      try {
        const service = AvatarService.createDefault(fakeContextAP());
        const profile = await service.loadAvatarProfile('', 'https://remote.example/fallback.jpg');

        expect(pref.lastAvatarUserId).assertEqual('guest_local');
        expect(profile.userId).assertEqual('guest_local');
        expect(profile.cloudUrl).assertEqual('https://remote.example/fallback.jpg');
      } finally {
        prefHooks.restore();
      }
      done();
    });

    it('invalid: create_default_should_surface_preference_load_failures', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const prefHooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      pref.getAvatarProfileError = 'avatar_pref_load_failed';
      prefHooks.setInstance(pref);
      let message = '';
      try {
        const service = AvatarService.createDefault(fakeContextAP());
        await service.loadAvatarProfile('u_fail_ap', '');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        prefHooks.restore();
      }
      expect(message).assertEqual('avatar_pref_load_failed');
      done();
    });

    it('normal: load_avatar_profile_should_merge_store_profile_and_keep_existing_cloud_url', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      const stored = buildAvatarProfileAP('u_load_ap');
      stored.compressedUri = 'file://compressed_ap.jpg';
      stored.cloudUrl = 'https://stored.example/cloud.jpg';
      stored.uploadState = 'SYNCED';
      stored.updatedAt = 99;
      store.profileToLoad = stored;
      const service = new AvatarService({ store });

      const profile = await service.loadAvatarProfile('u_load_ap', 'https://remote.example/ignored.jpg');

      expect(profile.userId).assertEqual('u_load_ap');
      expect(profile.cloudUrl).assertEqual('https://stored.example/cloud.jpg');
      expect(profile.uploadState).assertEqual('SYNCED');
      done();
    });

    it('boundary: load_avatar_profile_should_use_remote_url_when_store_cloud_url_empty', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      store.profileToLoad = buildAvatarProfileAP('u_remote_ap');
      store.profileToLoad.cloudUrl = '';
      const service = new AvatarService({ store });

      const profile = await service.loadAvatarProfile('u_remote_ap', 'https://remote.example/avatar.jpg');

      expect(profile.cloudUrl).assertEqual('https://remote.example/avatar.jpg');
      done();
    });

    it('invalid: load_avatar_profile_should_sanitize_invalid_store_values', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      const invalid = new AvatarProfile();
      invalid.userId = '';
      invalid.localUri = '';
      invalid.compressedUri = '';
      invalid.cloudUrl = '';
      invalid.uploadState = '' as never;
      invalid.updatedAt = Number('bad') as never;
      store.profileToLoad = invalid;
      const service = new AvatarService({ store });

      const profile = await service.loadAvatarProfile('u_invalid_ap', '');

      expect(profile.userId).assertEqual('u_invalid_ap');
      expect(profile.uploadState).assertEqual('EMPTY');
      expect(profile.updatedAt).assertEqual(0);
      done();
    });

    it('normal: resolve_display_uri_should_prefer_compressed_uri', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = new AvatarService({});
      const profile = buildAvatarProfileAP('u_display_ap');
      profile.compressedUri = 'file://compressed_display.jpg';
      profile.localUri = 'file://local_display.jpg';
      profile.cloudUrl = 'https://cloud.example/display.jpg';

      const uri = service.resolveDisplayUri(profile);

      expect(uri).assertEqual('file://compressed_display.jpg');
    });

    it('boundary: resolve_display_uri_should_fallback_to_local_uri', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = new AvatarService({});
      const profile = buildAvatarProfileAP('u_local_ap');
      profile.compressedUri = '';
      profile.localUri = 'file://local_display.jpg';
      profile.cloudUrl = 'https://cloud.example/display.jpg';

      const uri = service.resolveDisplayUri(profile);

      expect(uri).assertEqual('file://local_display.jpg');
    });

    it('invalid: resolve_display_uri_should_return_empty_when_all_sources_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = new AvatarService({});
      const profile = new AvatarProfile();

      const uri = service.resolveDisplayUri(profile);

      expect(uri).assertEqual('');
    });

    it('normal: pick_and_save_avatar_should_upload_compressed_file_and_persist_profile', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      store.profileToLoad = buildAvatarProfileAP('u_pick_ap');
      const uploader = new AvatarUploaderStubAP();
      const uploadResult = new AvatarUploadResult();
      uploadResult.status = 'SYNCED';
      uploadResult.requestId = 'req_pick_ap';
      uploadResult.remoteUrl = 'https://remote.example/synced.jpg';
      uploader.result = uploadResult;
      const service = new AvatarService({
        picker: new AvatarPickerStubAP(['file://picked_ap.jpg']),
        store,
        uploader,
        compressor: async (): Promise<string> => 'file://compressed_ap.jpg',
        now: (): number => 123
      });

      const profile = await service.pickAndSaveAvatar(fakeContextAP(), 'u_pick_ap', 'https://remote.example/old.jpg');

      expect(profile !== null).assertTrue();
      expect(profile?.compressedUri || '').assertEqual('file://compressed_ap.jpg');
      expect(profile?.cloudUrl || '').assertEqual('https://remote.example/synced.jpg');
      expect(uploader.inputs[0].userId).assertEqual('u_pick_ap');
      expect(store.savedProfiles.length).assertEqual(1);
      done();
    });

    it('boundary: pick_and_save_avatar_should_return_null_when_user_cancels_picker', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      const service = new AvatarService({
        picker: new AvatarPickerStubAP([]),
        store
      });

      const profile = await service.pickAndSaveAvatar(fakeContextAP(), 'u_cancel_ap', '');

      expect(profile === null).assertTrue();
      expect(store.savedProfiles.length).assertEqual(0);
      done();
    });

    it('invalid: pick_and_save_avatar_should_fallback_to_local_only_when_upload_throws', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      const uploader = new AvatarUploaderStubAP();
      uploader.errorMessage = 'upload_failed_ap';
      const service = new AvatarService({
        picker: new AvatarPickerStubAP(['file://picked_ap.jpg']),
        store,
        uploader,
        compressor: async (): Promise<string> => 'file://compressed_ap.jpg',
        now: (): number => 456
      });

      const profile = await service.pickAndSaveAvatar(fakeContextAP(), 'u_upload_fail_ap', 'https://remote.example/original.jpg');

      expect(profile !== null).assertTrue();
      expect(profile?.uploadState || '').assertEqual('LOCAL_ONLY');
      expect(profile?.compressedUri || '').assertEqual('');
      expect(profile?.cloudUrl || '').assertEqual('https://remote.example/original.jpg');
      done();
    });

    it('boundary: pick_and_save_avatar_should_use_guest_local_for_blank_user_id', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new AvatarStoreStubAP();
      const uploader = new AvatarUploaderStubAP();
      const uploadResult = new AvatarUploadResult();
      uploadResult.status = 'SYNCED';
      uploadResult.requestId = 'req_guest_ap';
      uploader.result = uploadResult;
      const service = new AvatarService({
        picker: new AvatarPickerStubAP(['file://picked_guest.jpg']),
        store,
        uploader,
        compressor: async (_context: common.Context, _srcUri: string, userId: string): Promise<string> => `file://compressed_${userId}.jpg`,
        now: (): number => 789
      });

      const profile = await service.pickAndSaveAvatar(fakeContextAP(), '   ', '');

      expect(profile?.userId || '').assertEqual('guest_local');
      expect(uploader.inputs[0].userId).assertEqual('guest_local');
      done();
    });

    it('normal: compress_to_jpeg_in_cache_should_create_cache_dir_and_return_uri', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const fileHooks = new FileIoHooksAP();
      const imageHooks = new ImageHooksAP();
      const uriHooks = new FileUriHooksAP();
      const mkdirCalls: string[] = [];
      const writeCalls: number[] = [];
      try {
        Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImageSource', (_srcUri: string): Object => new ImageSourceStubAP());
        Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImagePacker', (): Object => new ImagePackerStubAP());
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'accessSync', (_path: string): boolean => false);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'mkdirSync', (path: string): void => { mkdirCalls.push(path); });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', (_path: string, _mode: number): Object => { const o: FdObjectAP = { fd: 7 }; return o; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'writeSync', (_fd: number, data: ArrayBuffer): number => {
          writeCalls.push(data.byteLength);
          return data.byteLength;
        });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', (_file: Object): void => {});
        Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'getUriFromPath', (path: string): string => `file://${path}`);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'OpenMode', { READ_WRITE: 1, CREATE: 2, TRUNC: 4 });

        const uri = await AvatarService.compressToJpegInCache(fakeContextAP(), 'file://source_ap.jpg', 'u_cache_ap');

        expect(uri.includes('avatar_u_cache_ap_')).assertTrue();
        expect(mkdirCalls.length).assertEqual(1);
        expect(writeCalls[0] > 0).assertTrue();
      } finally {
        fileHooks.restore();
        imageHooks.restore();
        uriHooks.restore();
      }
      done();
    });

    it('boundary: compress_to_jpeg_in_cache_should_skip_mkdir_when_cache_dir_exists', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const fileHooks = new FileIoHooksAP();
      const imageHooks = new ImageHooksAP();
      const uriHooks = new FileUriHooksAP();
      let mkdirCount = 0;
      try {
        Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImageSource', (_srcUri: string): Object => new ImageSourceStubAP());
        Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImagePacker', (): Object => new ImagePackerStubAP());
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'accessSync', (_path: string): boolean => true);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'mkdirSync', (_path: string): void => { mkdirCount += 1; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', (_path: string, _mode: number): Object => { const o: FdObjectAP = { fd: 8 }; return o; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'writeSync', (_fd: number, data: ArrayBuffer): number => data.byteLength);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', (_file: Object): void => {});
        Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'getUriFromPath', (path: string): string => `file://${path}`);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'OpenMode', { READ_WRITE: 1, CREATE: 2, TRUNC: 4 });

        const uri = await AvatarService.compressToJpegInCache(fakeContextAP(), 'file://source_ap.jpg', 'u_exists_ap');

        expect(uri.includes('u_exists_ap')).assertTrue();
        expect(mkdirCount).assertEqual(0);
      } finally {
        fileHooks.restore();
        imageHooks.restore();
        uriHooks.restore();
      }
      done();
    });

    it('invalid: compress_to_jpeg_in_cache_should_throw_when_image_pack_fails', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const fileHooks = new FileIoHooksAP();
      const imageHooks = new ImageHooksAP();
      const uriHooks = new FileUriHooksAP();
      let message = '';
      try {
        Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImageSource', (_srcUri: string): Object => { const o: ImageSourceInlineAP = { createPixelMap: async (): Promise<Object> => new Object() }; return o; });
        Reflect.set(Reflect.get(globalThis, 'image') as Object, 'createImagePacker', (): Object => { const o: ImagePackerInlineAP = { packToData: async (): Promise<ArrayBuffer> => { throw new Error('pack_failed_ap'); } }; return o; });
        await AvatarService.compressToJpegInCache(fakeContextAP(), 'file://source_ap.jpg', 'u_fail_ap');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        fileHooks.restore();
        imageHooks.restore();
        uriHooks.restore();
      }
      expect(message).assertEqual('pack_failed_ap');
      done();
    });
  });

  describe('phase2BatchAP_avatar_upload_api', () => {
    it('normal: upload_avatar_should_return_synced_when_gateway_success', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_ap',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,AA==',
        updateAvatar: async (_token: string, _dataUrl: string, _mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const data = new UpdateAvatarResult();
          data.avatarUrl = 'https://remote.example/avatar_ap.jpg';
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (): number => 321
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_upload_ap';
      input.fileUri = 'file://avatar_ap.jpg';

      const result = await uploader.uploadAvatar(input);

      expect(result.status).assertEqual('SYNCED');
      expect(result.remoteUrl || '').assertEqual('https://remote.example/avatar_ap.jpg');
      expect(result.requestId).assertEqual('avatar_req_321');
      done();
    });

    it('boundary: upload_avatar_should_return_local_only_when_session_missing', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => '',
        now: (): number => 654
      });
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar_ap.jpg';

      const result = await uploader.uploadAvatar(input);

      expect(result.status).assertEqual('LOCAL_ONLY');
      expect(result.errorCode || '').assertEqual('NO_SESSION');
      expect(result.requestId).assertEqual('avatar_req_654');
      done();
    });

    it('invalid: upload_avatar_should_return_local_only_when_gateway_returns_non_zero_code', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      let passedMimeType = '';
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_ap',
        encodeFileToDataUrl: (_fileUriText: string, mimeType: string): string => {
          passedMimeType = mimeType;
          return 'data:image/jpeg;base64,AA==';
        },
        updateAvatar: async (_token: string, _dataUrl: string, _mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const response = new AuthApiResponse<UpdateAvatarResult>(new UpdateAvatarResult());
          response.code = 403;
          return response;
        }
      });
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar_ap.jpg';
      input.mimeType = '';

      const result = await uploader.uploadAvatar(input);

      expect(result.status).assertEqual('LOCAL_ONLY');
      expect(result.errorCode || '').assertEqual('403');
      expect(passedMimeType).assertEqual('image/jpeg');
      done();
    });

    it('invalid: upload_avatar_should_map_exception_to_upload_exception', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_ap',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => {
          throw new Error('encode_failed_ap');
        }
      });
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar_ap.jpg';

      const result = await uploader.uploadAvatar(input);

      expect(result.status).assertEqual('LOCAL_ONLY');
      expect(result.errorCode || '').assertEqual('UPLOAD_EXCEPTION');
      done();
    });

    it('normal: read_file_as_data_url_should_decode_file_uri_and_encode_content', 0, () => {
      // Arrange
      // Act
      // Assert
      const fileHooks = new FileIoHooksAP();
      const uriHooks = new FileUriHooksAP();
      const utilHooks = new UtilHooksAP();
      try {
        Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'FileUri', FileUriCtorStubAP as Object);
        Reflect.set(Reflect.get(globalThis, 'util') as Object, 'Base64Helper', Base64HelperStubAP as Object);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'statSync', (_path: string): Object => { const o: StatObjectAP = { size: 3 }; return o; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', (_path: string, _mode: number): Object => { const o: FdObjectAP = { fd: 11 }; return o; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'readSync', (_fd: number, buffer: ArrayBuffer): number => {
          const view = new Uint8Array(buffer);
          view[0] = 65;
          view[1] = 66;
          view[2] = 67;
          return 3;
        });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', (_file: Object): void => {});
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'OpenMode', { READ_ONLY: 1 });

        const dataUrl = AvatarUploadApi.readFileAsDataUrl('file://C:/avatar%20space.jpg', 'image/png');

        expect(dataUrl).assertEqual('data:image/png;base64,QUJD');
      } finally {
        fileHooks.restore();
        uriHooks.restore();
        utilHooks.restore();
      }
    });

    it('boundary: read_file_as_data_url_should_fallback_blank_mime_type_to_image_jpeg', 0, () => {
      // Arrange
      // Act
      // Assert
      const fileHooks = new FileIoHooksAP();
      const uriHooks = new FileUriHooksAP();
      const utilHooks = new UtilHooksAP();
      try {
        Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'FileUri', FileUriCtorStubAP as Object);
        Reflect.set(Reflect.get(globalThis, 'util') as Object, 'Base64Helper', Base64HelperStubAP as Object);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'statSync', (_path: string): Object => { const o: StatObjectAP = { size: 2 }; return o; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'openSync', (_path: string, _mode: number): Object => { const o: FdObjectAP = { fd: 12 }; return o; });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'readSync', (_fd: number, buffer: ArrayBuffer): number => {
          const view = new Uint8Array(buffer);
          view[0] = 1;
          view[1] = 2;
          return 2;
        });
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'closeSync', (_file: Object): void => {});
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'OpenMode', { READ_ONLY: 1 });

        const dataUrl = AvatarUploadApi.readFileAsDataUrl('C:/plain_path.jpg', '   ');

        expect(dataUrl.startsWith('data:image/jpeg;base64,')).assertTrue();
      } finally {
        fileHooks.restore();
        uriHooks.restore();
        utilHooks.restore();
      }
    });

    it('invalid: read_file_as_data_url_should_throw_when_uri_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      let message = '';
      try {
        AvatarUploadApi.readFileAsDataUrl('', 'image/jpeg');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('avatar_uri_empty');
    });

    it('invalid: read_file_as_data_url_should_throw_when_file_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const fileHooks = new FileIoHooksAP();
      const uriHooks = new FileUriHooksAP();
      const utilHooks = new UtilHooksAP();
      let message = '';
      try {
        Reflect.set(Reflect.get(globalThis, 'fileUri') as Object, 'FileUri', FileUriCtorStubAP as Object);
        Reflect.set(Reflect.get(globalThis, 'util') as Object, 'Base64Helper', Base64HelperStubAP as Object);
        Reflect.set(Reflect.get(globalThis, 'fileIo') as Object, 'statSync', (_path: string): Object => { const o: StatObjectAP = { size: 0 }; return o; });

        AvatarUploadApi.readFileAsDataUrl('file://C:/empty.jpg', 'image/jpeg');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        fileHooks.restore();
        uriHooks.restore();
        utilHooks.restore();
      }
      expect(message).assertEqual('avatar_file_empty');
    });
  });

  describe('phase2BatchAP_meta_categories', () => {
    it('conflict: memory_flags_should_not_mutate_saved_session_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const payload = buildSessionPayloadAP(Date.now() + 60_000);

      AuthSessionStore.save(payload);
      const before = AppStorage.get<string>(AppStorageKeys.AUTH_SESSION_JSON) || '';
      AuthSessionStore.markGuestChosen();
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      const after = AppStorage.get<string>(AppStorageKeys.AUTH_SESSION_JSON) || '';

      expect(before).assertEqual(after);
    });

    it('regression: persisted_session_roundtrip_should_keep_numeric_expire_at', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAP();
      const pref = new PreferenceManagerStubAP();
      hooks.setInstance(pref);
      const expireAt = Date.now() + 90_000;
      try {
        await AuthSessionStore.saveSessionPersisted(fakeContextAP(), buildSessionPayloadAP(expireAt));
        const loaded = await AuthSessionStore.loadSessionPersisted(fakeContextAP());

        expect(loaded?.expireAt || 0).assertEqual(expireAt);
      } finally {
        hooks.restore();
      }
      done();
    });

    it('combined: auth_and_avatar_helpers_should_keep_independent_state', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      resetAuthStorageAP();
      const store = new AvatarStoreStubAP();
      store.profileToLoad = buildAvatarProfileAP('u_combo_ap');
      const service = new AvatarService({
        picker: new AvatarPickerStubAP([]),
        store
      });

      AuthSessionStore.markGuestChosen();
      const profile = await service.loadAvatarProfile('u_combo_ap', '');

      expect(AuthSessionStore.hasGuestChosen()).assertTrue();
      expect(profile.userId).assertEqual('u_combo_ap');
      expect(store.loadCalls.length).assertEqual(1);
      done();
    });
  });
}
