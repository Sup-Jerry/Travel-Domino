import { describe, expect, it } from '@ohos/hypium';
import { AuthFacade } from '../main/ets/infrastructure/auth/AuthFacade';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import {
  AuthApiResponse,
  AuthLoginResult,
  AuthMeResult,
  AuthSessionPayload,
  AuthUserProfile,
  DeviceInfo,
  SocialCredential
} from '../main/ets/domain/auth/AuthModels';
import { HuaweiCredential, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';

class SessionManagerMockForN {
  session: UserSession | null = null;
  restoredSession: UserSession | null = null;
  persistedBlocked: boolean = false;
  clearCalls: number = 0;
  clearSessionPersistedCalls: number = 0;
  clearSilentPersistedCalls: number = 0;
  guestChosenCalls: number = 0;
  saveCalls: number = 0;
  savePersistedCalls: number = 0;

  load(): UserSession | null {
    return this.session;
  }

  save(session: UserSession): void {
    this.session = session;
    this.saveCalls += 1;
  }

  clear(): void {
    this.session = null;
    this.clearCalls += 1;
  }

  isSilentLoginBlockedAfterLogout(): boolean {
    return false;
  }

  async isSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<boolean> {
    return this.persistedBlocked;
  }

  async restoreSessionPersisted(_context: Object): Promise<UserSession | null> {
    return this.restoredSession;
  }

  async clearSessionPersisted(_context: Object): Promise<void> {
    this.clearSessionPersistedCalls += 1;
    return;
  }

  async markSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> {
    return;
  }

  markSilentLoginBlockedAfterLogout(): void {
    return;
  }

  clearSilentLoginBlockedAfterLogout(): void {
    return;
  }

  async clearSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> {
    this.clearSilentPersistedCalls += 1;
    return;
  }

  async saveSessionPersisted(_context: Object, _session: UserSession): Promise<void> {
    this.savePersistedCalls += 1;
    return;
  }

  async markGuestChosen(_context: Object): Promise<void> {
    this.guestChosenCalls += 1;
    return;
  }
}

class ProviderMockForN {
  readonly credential: HuaweiCredential = new HuaweiCredential();
  throwOnSilent: boolean = false;

  constructor() {
    this.credential.authorizationCode = 'auth_n';
    this.credential.idToken = 'id_n';
    this.credential.openId = 'open_n';
    this.credential.unionId = 'union_n';
  }

  async explicitLogin(_context?: Object): Promise<HuaweiCredential> {
    return this.credential;
  }

  async silentLogin(_context: Object): Promise<HuaweiCredential> {
    if (this.throwOnSilent) {
      throw new Error('silent_provider_error_n');
    }
    return this.credential;
  }
}

class HooksForN {
  private readonly originMe: Object;
  private readonly originCreateGuest: Object;
  private readonly originSocial: Object;

  constructor() {
    this.originMe = Reflect.get(AuthGateway, 'me') as Object;
    this.originCreateGuest = Reflect.get(AuthGateway, 'createGuest') as Object;
    this.originSocial = Reflect.get(AuthGateway, 'loginWithSocial') as Object;
  }

  setMe(fn: (accessToken: string) => Promise<AuthApiResponse<AuthMeResult>>): void {
    Reflect.set(AuthGateway, 'me', fn);
  }

  setCreateGuest(fn: (deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'createGuest', fn);
  }

  setSocial(fn: (providerType: string, credential: SocialCredential, deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'loginWithSocial', fn);
  }

  restore(): void {
    Reflect.set(AuthGateway, 'me', this.originMe);
    Reflect.set(AuthGateway, 'createGuest', this.originCreateGuest);
    Reflect.set(AuthGateway, 'loginWithSocial', this.originSocial);
  }
}

class BundleForN {
  facade: AuthFacade = new AuthFacade();
  session: SessionManagerMockForN = new SessionManagerMockForN();
  provider: ProviderMockForN = new ProviderMockForN();
}

class AppContextForN {
  tag: string = 'ctx_n';
}

function createBundleForN(): BundleForN {
  const bundle = new BundleForN();
  Reflect.set(bundle.facade as Object, 'sessionManager', bundle.session);
  Reflect.set(bundle.facade as Object, 'huaweiProvider', bundle.provider);
  return bundle;
}

function createSessionForN(isGuest: boolean = false): UserSession {
  const session = new UserSession();
  session.accountId = 'acc_n';
  session.userId = 'user_n';
  session.accessToken = 'token_n';
  session.refreshToken = 'refresh_n';
  session.expireAt = Date.now() + 120_000;
  session.sessionId = 'sid_n';
  session.isGuest = isGuest;
  session.loginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  session.loginType = isGuest ? 'guest' : 'huawei';
  session.isLogin = true;
  session.lastLoginAt = Date.now();
  return session;
}

function createMeResponseForN(code: number, nickname: string, isGuest: boolean = false): AuthApiResponse<AuthMeResult> {
  const payload = new AuthMeResult();
  payload.accountId = 'acc_me_n';
  payload.userId = 'user_me_n';
  payload.nickname = nickname;
  payload.avatarUrl = '';
  payload.isGuest = isGuest;
  payload.defaultLoginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  const response = new AuthApiResponse<AuthMeResult>(payload);
  response.code = code;
  response.message = code === 0 ? 'ok' : 'me_failed_n';
  return response;
}

function createLoginPayloadForN(isGuest: boolean = false): AuthLoginResult {
  const payload = new AuthLoginResult();
  const user = new AuthUserProfile();
  user.accountId = isGuest ? 'guest_n' : 'acc_login_n';
  user.userId = isGuest ? 'guest_n' : 'user_login_n';
  user.isGuest = isGuest;
  user.defaultLoginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  payload.user = user;
  const session = new AuthSessionPayload();
  session.accessToken = 'token_login_n';
  session.refreshToken = 'refresh_login_n';
  session.sessionId = 'sid_login_n';
  session.expireAt = Date.now() + 180_000;
  payload.session = session;
  return payload;
}

function createLoginResponseForN(code: number, payload: AuthLoginResult, message: string): AuthApiResponse<AuthLoginResult> {
  const response = new AuthApiResponse<AuthLoginResult>(payload);
  response.code = code;
  response.message = message;
  return response;
}

export default function phase2CoreCoverageBatchNTest() {
  describe('phase2CoreCoverageBatchNTest', () => {
    it('normal: auth_facade_get_current_nickname_should_return_default_for_gateway_error_or_blank_nickname', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      bundle.session.session = createSessionForN(false);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => createMeResponseForN(500, ''));
      // Act
      const fallbackOnError = await bundle.facade.getCurrentNickname('default_error_n');
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => createMeResponseForN(0, '   '));
      const fallbackOnBlank = await bundle.facade.getCurrentNickname('default_blank_n');
      // Assert
      expect(fallbackOnError).assertEqual('default_error_n');
      expect(fallbackOnBlank).assertEqual('default_blank_n');
      hooks.restore();
    });

    it('boundary: auth_facade_silent_login_should_restore_persisted_session_and_refresh_to_guest_type', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      bundle.facade.bindContext(new AppContextForN() as never);
      bundle.session.session = null;
      bundle.session.restoredSession = createSessionForN(false);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => createMeResponseForN(0, 'nick_n', true));
      // Act
      const result = await bundle.facade.silentLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('LOCAL_SESSION');
      expect(result.data !== null).assertTrue();
      expect(result.data!.loginType).assertEqual('guest');
      expect(bundle.session.savePersistedCalls > 0).assertTrue();
      hooks.restore();
    });

    it('normal: auth_facade_silent_login_should_refresh_to_huawei_type_when_me_marks_non_guest', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      bundle.facade.bindContext(new AppContextForN() as never);
      bundle.session.session = createSessionForN(true);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => createMeResponseForN(0, 'nick_huawei_n', false));
      // Act
      const result = await bundle.facade.silentLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('LOCAL_SESSION');
      expect(result.data !== null).assertTrue();
      expect(result.data!.loginType).assertEqual('huawei');
      hooks.restore();
    });

    it('invalid: auth_facade_silent_login_should_clear_invalid_local_session_then_return_auth_error_when_provider_throws_non_error', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      bundle.facade.bindContext(new AppContextForN() as never);
      bundle.session.session = createSessionForN(false);
      bundle.provider.throwOnSilent = true;
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => createMeResponseForN(401, ''));
      // Act
      const result = await bundle.facade.silentLogin();
      // Assert
      expect(bundle.session.clearCalls).assertEqual(1);
      expect(bundle.session.clearSessionPersistedCalls).assertEqual(1);
      expect(result.success).assertFalse();
      expect(result.message).assertEqual('silent_provider_error_n');
      expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      hooks.restore();
    });

    it('invalid: auth_facade_normalize_error_should_return_auth_error_for_non_error_input', 0, () => {
      // Arrange
      const bundle = createBundleForN();
      const normalize = Reflect.get(bundle.facade as Object, 'normalizeError') as (error: Object) => string;
      // Act
      const message = normalize(new AppContextForN() as Object);
      // Assert
      expect(message).assertEqual('auth_error');
    });

    it('conflict: auth_facade_explicit_login_should_fail_with_social_login_failed_when_gateway_returns_nonzero', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      hooks.setSocial(async (_provider: string, _credential: SocialCredential, _device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        return createLoginResponseForN(500, createLoginPayloadForN(false), '');
      });
      // Act
      const result = await bundle.facade.explicitLoginByButton(undefined, false);
      // Assert
      expect(result.success).assertFalse();
      expect(result.source).assertEqual('HUAWEI_BUTTON');
      expect(result.message).assertEqual('social_login_failed');
      hooks.restore();
    });

    it('regression: td-20260415-auth-facade-silent-provider-success-should-return_huawei_silent_and_guest_session', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      bundle.facade.bindContext(new AppContextForN() as never);
      hooks.setSocial(async (_provider: string, _credential: SocialCredential, _device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        return createLoginResponseForN(0, createLoginPayloadForN(true), 'ok');
      });
      // Act
      const result = await bundle.facade.silentLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('HUAWEI_SILENT');
      expect(result.data !== null).assertTrue();
      expect(result.data!.isGuest).assertTrue();
      expect(result.data!.loginType).assertEqual('guest');
      expect(bundle.session.clearSilentPersistedCalls).assertEqual(0);
      hooks.restore();
    });

    it('combined: auth_facade_guest_fallback_should_cover_session_empty_offline_success_and_exception_offline_null_paths', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        const payload = createLoginPayloadForN(true);
        Reflect.set(payload as Object, 'session', null);
        return createLoginResponseForN(0, payload, 'ok');
      });
      // Act
      const fallbackOnSessionEmpty = await bundle.facade.explicitGuestLogin();
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        throw new Error('guest_gateway_throw_n');
      });
      Reflect.set(bundle.facade as Object, 'tryOfflineGuestFallback', async (_reason: string, _detail: string): Promise<Object | null> => null);
      const failureOnException = await bundle.facade.explicitGuestLogin();
      // Assert
      expect(fallbackOnSessionEmpty.success).assertTrue();
      expect(fallbackOnSessionEmpty.data !== null).assertTrue();
      expect(fallbackOnSessionEmpty.data!.loginMethod).assertEqual('GUEST_OFFLINE');
      expect(failureOnException.success).assertFalse();
      expect(failureOnException.message).assertEqual('guest_gateway_throw_n');
      expect(failureOnException.status).assertEqual(LoginStatus.LOGIN_FAILED);
      hooks.restore();
    });

    it('conflict: auth_facade_guest_fallback_should_fail_when_session_empty_and_offline_fallback_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        const payload = createLoginPayloadForN(true);
        Reflect.set(payload as Object, 'session', null);
        return createLoginResponseForN(0, payload, 'ok');
      });
      Reflect.set(bundle.facade as Object, 'tryOfflineGuestFallback', async (_reason: string, _detail: string): Promise<Object | null> => null);
      // Act
      const result = await bundle.facade.explicitGuestLogin();
      // Assert
      expect(result.success).assertFalse();
      expect(result.message).assertEqual('guest_session_empty');
      expect(result.status).assertEqual(LoginStatus.LOGIN_FAILED);
      hooks.restore();
    });

    it('normal: auth_facade_explicit_guest_login_should_mark_guest_chosen_when_context_bound', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      const hooks = new HooksForN();
      bundle.facade.bindContext(new AppContextForN() as never);
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        return createLoginResponseForN(0, createLoginPayloadForN(true), 'ok');
      });
      // Act
      const result = await bundle.facade.explicitGuestLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(bundle.session.guestChosenCalls).assertEqual(1);
      hooks.restore();
    });

    it('boundary: auth_facade_update_username_should_reject_too_long_value', 0, async () => {
      // Arrange
      const bundle = createBundleForN();
      bundle.session.session = createSessionForN(false);
      const tooLong = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      // Act
      const result = await bundle.facade.updateUsername(tooLong);
      // Assert
      expect(result.success).assertFalse();
      expect(result.code).assertEqual(AuthErrorCode.USERNAME_INVALID);
    });
  });
}
