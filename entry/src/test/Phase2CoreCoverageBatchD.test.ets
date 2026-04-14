import { describe, expect, it } from '@ohos/hypium';
import { AuthFacade } from '../main/ets/infrastructure/auth/AuthFacade';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import {
  AuthApiResponse,
  AuthLoginResult,
  AuthMeResult,
  SocialCredential,
  UpdateUsernameResult
} from '../main/ets/domain/auth/AuthModels';
import { HuaweiCredential, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';

class SessionManagerMockForD {
  session: UserSession | null = null;
  clearCalls: number = 0;
  saveCalls: number = 0;

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
    return false;
  }

  async restoreSessionPersisted(_context: Object): Promise<UserSession | null> {
    return null;
  }

  async clearSessionPersisted(_context: Object): Promise<void> {
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
    return;
  }

  async saveSessionPersisted(_context: Object, _session: UserSession): Promise<void> {
    return;
  }

  async markGuestChosen(_context: Object): Promise<void> {
    return;
  }
}

class HuaweiProviderMockForD {
  explicitErrorMessage: string = 'provider_failed';

  async explicitLogin(_context?: Object): Promise<HuaweiCredential> {
    throw new Error(this.explicitErrorMessage);
  }

  async silentLogin(_context: Object): Promise<HuaweiCredential> {
    throw new Error('silent_not_used');
  }
}

class FacadeBatchDBundle {
  facade: AuthFacade = new AuthFacade();
  session: SessionManagerMockForD = new SessionManagerMockForD();
  provider: HuaweiProviderMockForD = new HuaweiProviderMockForD();
}

class GatewayHooks {
  private readonly originMe: Object;
  private readonly originCreateGuest: Object;
  private readonly originUpdateUsername: Object;

  constructor() {
    this.originMe = Reflect.get(AuthGateway, 'me') as Object;
    this.originCreateGuest = Reflect.get(AuthGateway, 'createGuest') as Object;
    this.originUpdateUsername = Reflect.get(AuthGateway, 'updateUsername') as Object;
  }

  setMe(fn: (accessToken: string) => Promise<AuthApiResponse<AuthMeResult>>): void {
    Reflect.set(AuthGateway, 'me', fn);
  }

  setCreateGuest(fn: () => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'createGuest', fn);
  }

  setUpdateUsername(fn: (accessToken: string, username: string) => Promise<AuthApiResponse<UpdateUsernameResult>>): void {
    Reflect.set(AuthGateway, 'updateUsername', fn);
  }

  restore(): void {
    Reflect.set(AuthGateway, 'me', this.originMe);
    Reflect.set(AuthGateway, 'createGuest', this.originCreateGuest);
    Reflect.set(AuthGateway, 'updateUsername', this.originUpdateUsername);
  }
}

function createFacadeWithMocksForD(): FacadeBatchDBundle {
  const bundle = new FacadeBatchDBundle();
  Reflect.set(bundle.facade, 'sessionManager', bundle.session);
  Reflect.set(bundle.facade, 'huaweiProvider', bundle.provider);
  return bundle;
}

function createSessionForD(): UserSession {
  const session = new UserSession();
  session.isLogin = true;
  session.accountId = 'acc_local_d';
  session.userId = 'user_local_d';
  session.accessToken = 'token_local_d';
  session.refreshToken = 'refresh_local_d';
  session.expireAt = Date.now() + 60_000;
  session.sessionId = 's_local_d';
  session.isGuest = false;
  session.loginType = 'huawei';
  session.loginMethod = 'HUAWEI';
  session.lastLoginAt = Date.now() - 30_000;
  return session;
}

function makeMeResponse(code: number, nickname: string, userId: string = 'user_me_1'): AuthApiResponse<AuthMeResult> {
  const payload = new AuthMeResult();
  payload.accountId = 'acc_me_1';
  payload.userId = userId;
  payload.nickname = nickname;
  payload.avatarUrl = 'avatar_me_1';
  payload.isGuest = false;
  payload.defaultLoginMethod = 'HUAWEI';
  const response = new AuthApiResponse<AuthMeResult>(payload);
  response.code = code;
  response.message = code === 0 ? 'ok' : 'me_failed';
  return response;
}

function makeUpdateUsernameResponse(code: number, nickname: string): AuthApiResponse<UpdateUsernameResult> {
  const payload = new UpdateUsernameResult();
  payload.accountId = 'acc_name_1';
  payload.userId = 'user_name_1';
  payload.nickname = nickname;
  payload.avatarUrl = 'avatar_name_1';
  payload.isGuest = false;
  payload.defaultLoginMethod = 'HUAWEI';
  const response = new AuthApiResponse<UpdateUsernameResult>(payload);
  response.code = code;
  response.message = code === 0 ? 'ok' : 'update_failed';
  return response;
}

function makeFailedGuestCreateResponse(code: number): AuthApiResponse<AuthLoginResult> {
  const payload = new AuthLoginResult();
  const response = new AuthApiResponse<AuthLoginResult>(payload);
  response.code = code;
  response.message = 'guest_gateway_failed';
  return response;
}

export default function phase2CoreCoverageBatchDTest() {
  describe('phase2CoreCoverageBatchDTest', () => {
    it('normal: auth_facade_get_current_nickname_should_use_gateway_nickname_when_available', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocksForD();
      bundle.session.session = createSessionForD();
      const hooks = new GatewayHooks();
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => makeMeResponse(0, '  昵称A  '));

      // Act
      const nickname = await bundle.facade.getCurrentNickname('默认名');

      // Assert
      expect(nickname).assertEqual('昵称A');
      hooks.restore();
    });

    it('boundary: auth_facade_get_current_user_profile_should_fallback_to_session_when_me_failed', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocksForD();
      const session = createSessionForD();
      session.accountId = '';
      session.userId = 'user_fallback_1';
      session.isGuest = true;
      bundle.session.session = session;
      const hooks = new GatewayHooks();
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => makeMeResponse(401, '')); 

      // Act
      const profile = await bundle.facade.getCurrentUserProfile('默认访客');

      // Assert
      expect(profile.userId).assertEqual('user_fallback_1');
      expect(profile.nickname).assertEqual('默认访客');
      expect(profile.isGuest).assertTrue();
      hooks.restore();
    });

    it('invalid: auth_facade_update_username_should_return_gateway_error_when_update_failed', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocksForD();
      bundle.session.session = createSessionForD();
      const hooks = new GatewayHooks();
      hooks.setUpdateUsername(async (_token: string, _username: string): Promise<AuthApiResponse<UpdateUsernameResult>> =>
        makeUpdateUsernameResponse(502, '')
      );

      // Act
      const result = await bundle.facade.updateUsername('合法昵称');

      // Assert
      expect(result.success).assertFalse();
      expect(result.code).assertEqual(502);
      expect(result.message).assertEqual('update_failed');
      hooks.restore();
    });

    it('conflict: auth_facade_silent_login_should_clear_invalid_local_session_and_return_context_unavailable', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocksForD();
      bundle.session.session = createSessionForD();
      const hooks = new GatewayHooks();
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => makeMeResponse(AuthErrorCode.SESSION_EXPIRED, ''));

      // Act
      const result = await bundle.facade.silentLogin();

      // Assert
      expect(bundle.session.clearCalls).assertEqual(1);
      expect(result.success).assertFalse();
      expect(result.message).assertEqual('silent_login_context_unavailable');
      expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      hooks.restore();
    });

    it('regression: td-20260414-phase2-auth-facade-silent-login_should_keep_local_session_on_non_invalid_me_code', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocksForD();
      const oldSession = createSessionForD();
      oldSession.accountId = 'acc_keep_1';
      bundle.session.session = oldSession;
      const hooks = new GatewayHooks();
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => makeMeResponse(503, ''));

      // Act
      const result = await bundle.facade.silentLogin();

      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('LOCAL_SESSION');
      expect(result.data !== null).assertTrue();
      expect(result.data!.accountId).assertEqual('acc_keep_1');
      expect(bundle.session.clearCalls).assertEqual(0);
      hooks.restore();
    });

    it('combined: auth_facade_explicit_login_should_fallback_to_offline_guest_when_provider_and_guest_gateway_fail', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocksForD();
      bundle.provider.explicitErrorMessage = 'provider_unavailable';
      const hooks = new GatewayHooks();
      hooks.setCreateGuest(async (): Promise<AuthApiResponse<AuthLoginResult>> => makeFailedGuestCreateResponse(500));

      // Act
      const result = await bundle.facade.explicitLoginByButton(undefined, true);

      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('GUEST_FALLBACK');
      expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      expect(result.data !== null).assertTrue();
      expect(result.data!.isGuest).assertTrue();
      expect(result.data!.loginMethod).assertEqual('GUEST_OFFLINE');
      expect(result.data!.accountId).assertEqual('guest_local');
      hooks.restore();
    });
  });
}
