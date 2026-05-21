import { describe, expect, it } from '@ohos/hypium';
import { AuthFacade, CurrentUserBasicProfile } from '../main/ets/infrastructure/auth/AuthFacade';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import {
  AuthApiResponse,
  AuthLoginResult,
  AuthMeResult,
  AuthSessionPayload,
  AuthUserProfile,
  DeviceInfo,
  UpdateUsernameResult
} from '../main/ets/domain/auth/AuthModels';
import { AuthResult, HuaweiCredential, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';

class SessionManagerMockForM {
  session: UserSession | null = null;
  memoryBlocked: boolean = false;
  persistedBlocked: boolean = false;
  appClearCalls: number = 0;
  appBlockCalls: number = 0;
  memClearCalls: number = 0;
  memBlockCalls: number = 0;
  saveCalls: number = 0;
  savePersistedCalls: number = 0;
  guestChosenCalls: number = 0;
  savePersistedError: string = '';
  guestChosenError: string = '';

  load(): UserSession | null { return this.session; }
  save(session: UserSession): void { this.session = session; this.saveCalls += 1; }
  clear(): void { this.session = null; }
  isSilentLoginBlockedAfterLogout(): boolean { return this.memoryBlocked; }
  async isSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<boolean> { return this.persistedBlocked; }
  async restoreSessionPersisted(_context: Object): Promise<UserSession | null> { return null; }
  async clearSessionPersisted(_context: Object): Promise<void> { this.appClearCalls += 1; return; }
  async markSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> { this.appBlockCalls += 1; return; }
  markSilentLoginBlockedAfterLogout(): void { this.memBlockCalls += 1; this.memoryBlocked = true; }
  clearSilentLoginBlockedAfterLogout(): void { this.memClearCalls += 1; this.memoryBlocked = false; }
  async clearSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> { this.appClearCalls += 1; return; }
  async saveSessionPersisted(_context: Object, _session: UserSession): Promise<void> {
    this.savePersistedCalls += 1;
    if (this.savePersistedError.length > 0) {
      throw new Error(this.savePersistedError);
    }
    return;
  }
  async markGuestChosen(_context: Object): Promise<void> {
    this.guestChosenCalls += 1;
    if (this.guestChosenError.length > 0) {
      throw new Error(this.guestChosenError);
    }
    return;
  }
}

class ProviderMockForM {
  throwOnExplicit: boolean = false;
  credential: HuaweiCredential = new HuaweiCredential();

  constructor() {
    this.credential.authorizationCode = 'auth_m';
    this.credential.idToken = 'id_m';
    this.credential.openId = 'open_m';
    this.credential.unionId = 'union_m';
  }

  async explicitLogin(_context?: Object): Promise<HuaweiCredential> {
    if (this.throwOnExplicit) {
      throw new Error('provider_fail_m');
    }
    return this.credential;
  }

  async silentLogin(_context: Object): Promise<HuaweiCredential> {
    return this.credential;
  }
}

class AppContextForM {
  tag: string = 'ctx_m';
}

class BundleForM {
  facade: AuthFacade = new AuthFacade();
  session: SessionManagerMockForM = new SessionManagerMockForM();
  provider: ProviderMockForM = new ProviderMockForM();
}

class HooksForM {
  private readonly originMe: Object;
  private readonly originUpdateUsername: Object;
  private readonly originCreateGuest: Object;
  private readonly originSocial: Object;

  constructor() {
    this.originMe = Reflect.get(AuthGateway, 'me') as Object;
    this.originUpdateUsername = Reflect.get(AuthGateway, 'updateUsername') as Object;
    this.originCreateGuest = Reflect.get(AuthGateway, 'createGuest') as Object;
    this.originSocial = Reflect.get(AuthGateway, 'loginWithSocial') as Object;
  }

  setMe(fn: (accessToken: string) => Promise<AuthApiResponse<AuthMeResult>>): void {
    Reflect.set(AuthGateway, 'me', fn);
  }

  setUpdateUsername(fn: (accessToken: string, username: string) => Promise<AuthApiResponse<UpdateUsernameResult>>): void {
    Reflect.set(AuthGateway, 'updateUsername', fn);
  }

  setCreateGuest(fn: (deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'createGuest', fn);
  }

  setSocial(fn: (providerType: string, credential: Object, deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'loginWithSocial', fn);
  }

  restore(): void {
    Reflect.set(AuthGateway, 'me', this.originMe);
    Reflect.set(AuthGateway, 'updateUsername', this.originUpdateUsername);
    Reflect.set(AuthGateway, 'createGuest', this.originCreateGuest);
    Reflect.set(AuthGateway, 'loginWithSocial', this.originSocial);
  }
}

function createBundleForM(): BundleForM {
  const bundle = new BundleForM();
  Reflect.set(bundle.facade as Object, 'sessionManager', bundle.session);
  Reflect.set(bundle.facade as Object, 'huaweiProvider', bundle.provider);
  return bundle;
}

function createSessionForM(token: string, isGuest: boolean = false): UserSession {
  const session = new UserSession();
  session.accountId = 'acc_m';
  session.userId = 'user_m';
  session.accessToken = token;
  session.refreshToken = 'refresh_m';
  session.expireAt = Date.now() + 3600_000;
  session.sessionId = 'sid_m';
  session.isGuest = isGuest;
  session.loginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  session.loginType = isGuest ? 'guest' : 'huawei';
  session.isLogin = true;
  session.lastLoginAt = Date.now();
  return session;
}

function createGuestPayloadForM(): AuthLoginResult {
  const payload = new AuthLoginResult();
  const user = new AuthUserProfile();
  user.accountId = 'guest_local';
  user.userId = 'guest_local';
  user.isGuest = true;
  user.defaultLoginMethod = 'GUEST';
  payload.user = user;
  const session = new AuthSessionPayload();
  session.accessToken = '';
  session.refreshToken = '';
  session.sessionId = 'sid_guest_m';
  Reflect.set(session as Object, 'expireAt', Date.now() + 60_000);
  payload.session = session;
  return payload;
}

function createMeResponseForM(): AuthApiResponse<AuthMeResult> {
  const data = new AuthMeResult();
  data.accountId = 'acc_remote_m';
  data.userId = 'user_remote_m';
  data.nickname = 'NeoM';
  data.avatarUrl = 'http://avatar.m';
  data.isGuest = false;
  const response = new AuthApiResponse<AuthMeResult>(data);
  response.code = 0;
  response.message = 'ok';
  return response;
}

function createUpdateUsernameResponseForM(username: string): AuthApiResponse<UpdateUsernameResult> {
  const data = new UpdateUsernameResult();
  data.accountId = 'acc_update_m';
  data.userId = 'user_update_m';
  data.nickname = username;
  data.avatarUrl = '';
  data.isGuest = false;
  const response = new AuthApiResponse<UpdateUsernameResult>(data);
  response.code = 0;
  response.message = 'ok';
  return response;
}

export default function phase2CoreCoverageBatchMTest() {
  describe('phase2CoreCoverageBatchMTest', () => {
    it('normal: auth_facade_get_profile_should_map_remote_user_fields_when_me_success', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      bundle.session.session = createSessionForM('token_profile_m');
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => createMeResponseForM());
      // Act
      const profile = await bundle.facade.getCurrentUserProfile('default_m');
      // Assert
      expect(profile.userId).assertEqual('acc_remote_m');
      expect(profile.nickname).assertEqual('NeoM');
      expect(profile.avatarUrl).assertEqual('http://avatar.m');
      hooks.restore();
    });

    it('regression: auth_facade_get_profile_should_return_local_guest_without_me_request', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      let meCalls = 0;
      bundle.session.session = createSessionForM('', true);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => {
        meCalls += 1;
        return createMeResponseForM();
      });
      // Act
      const profile = await bundle.facade.getCurrentUserProfile('default_guest_m');
      // Assert
      expect(profile.isGuest).assertTrue();
      expect(profile.userId).assertEqual('acc_m');
      expect(profile.nickname).assertEqual('default_guest_m');
      expect(meCalls).assertEqual(0);
      hooks.restore();
    });

    it('boundary: auth_facade_get_profile_should_fallback_to_default_name_when_remote_nickname_blank', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      const session = createSessionForM('token_profile_blank_m');
      session.accountId = '';
      session.userId = 'user_session_blank_m';
      bundle.session.session = session;
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => {
        const data = new AuthMeResult();
        data.accountId = '';
        data.userId = '';
        data.nickname = '   ';
        data.avatarUrl = 'http://avatar.blank.m';
        data.isGuest = false;
        const response = new AuthApiResponse<AuthMeResult>(data);
        response.code = 0;
        response.message = 'ok';
        return response;
      });
      // Act
      const profile = await bundle.facade.getCurrentUserProfile('default_profile_m');
      // Assert
      expect(profile.accountId).assertEqual('');
      expect(profile.userId).assertEqual('user_session_blank_m');
      expect(profile.nickname).assertEqual('default_profile_m');
      expect(profile.avatarUrl).assertEqual('http://avatar.blank.m');
      expect(profile.isGuest).assertFalse();
      hooks.restore();
    });

    it('invalid: auth_facade_get_profile_should_fallback_to_session_when_remote_me_failed', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      const session = createSessionForM('token_profile_fail_m');
      session.accountId = '';
      session.userId = 'user_session_fail_m';
      session.isGuest = false;
      bundle.session.session = session;
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => {
        const response = new AuthApiResponse<AuthMeResult>(new AuthMeResult());
        response.code = 503;
        response.message = 'me_failed_profile_m';
        return response;
      });
      // Act
      const profile = await bundle.facade.getCurrentUserProfile('default_failed_profile_m');
      // Assert
      expect(profile.accountId).assertEqual('');
      expect(profile.userId).assertEqual('user_session_fail_m');
      expect(profile.nickname).assertEqual('default_failed_profile_m');
      expect(profile.isGuest).assertFalse();
      hooks.restore();
    });

    it('boundary: auth_facade_update_username_should_return_profile_when_gateway_success', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      bundle.session.session = createSessionForM('token_update_m');
      hooks.setUpdateUsername(
        async (_token: string, username: string): Promise<AuthApiResponse<UpdateUsernameResult>> =>
          createUpdateUsernameResponseForM(username)
      );
      // Act
      const result = await bundle.facade.updateUsername('用户名M');
      // Assert
      expect(result.success).assertTrue();
      expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      expect(result.data !== null).assertTrue();
      expect((result.data as CurrentUserBasicProfile).nickname).assertEqual('用户名M');
      hooks.restore();
    });

    it('invalid: auth_facade_silent_login_should_fail_when_persisted_blocked', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const ctx = new AppContextForM();
      bundle.facade.bindContext(ctx as never);
      bundle.session.persistedBlocked = true;
      // Act
      const result = await bundle.facade.silentLogin();
      // Assert
      expect(result.success).assertFalse();
      expect(result.message).assertEqual('silent_login_blocked_after_logout');
      expect(result.source).assertEqual('HUAWEI_SILENT');
    });

    it('conflict: auth_facade_explicit_login_should_fail_when_guest_fallback_chain_returns_failure', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      bundle.provider.throwOnExplicit = true;
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        const response = new AuthApiResponse<AuthLoginResult>(createGuestPayloadForM());
        response.code = 500;
        response.message = 'guest_fail_m';
        return response;
      });
      Reflect.set(bundle.facade as Object, 'tryOfflineGuestFallback', async (_reason: string, _detail: string): Promise<AuthResult<UserSession> | null> => null);
      // Act
      const result = await bundle.facade.explicitLoginByButton(undefined, true);
      // Assert
      expect(result.success).assertFalse();
      expect(result.source).assertEqual('HUAWEI_BUTTON');
      expect(result.status).assertEqual(LoginStatus.LOGIN_FAILED);
      hooks.restore();
    });

    it('regression: td-20260415-auth-facade-button-success-with-context-should-clear_persisted_block', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      const ctx = new AppContextForM();
      bundle.facade.bindContext(ctx as never);
      hooks.setSocial(async (_provider: string, _credential: Object, _device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        const payload = new AuthLoginResult();
        const user = new AuthUserProfile();
        user.accountId = 'acc_btn_m';
        user.userId = 'user_btn_m';
        user.isGuest = false;
        user.defaultLoginMethod = 'HUAWEI';
        payload.user = user;
        const session = new AuthSessionPayload();
        session.accessToken = 'token_btn_m';
        session.refreshToken = 'refresh_btn_m';
        session.sessionId = 'sid_btn_m';
        Reflect.set(session as Object, 'expireAt', Date.now() + 120_000);
        payload.session = session;
        const response = new AuthApiResponse<AuthLoginResult>(payload);
        response.code = 0;
        response.message = 'ok';
        return response;
      });
      // Act
      const result = await bundle.facade.explicitLoginByButton(bundle.provider.credential, false);
      // Assert
      expect(result.success).assertTrue();
      expect(bundle.session.appClearCalls > 0).assertTrue();
      expect(bundle.session.savePersistedCalls > 0).assertTrue();
      hooks.restore();
    });

    it('combined: auth_facade_explicit_guest_login_should_return_local_guest_and_mark_guest_chosen', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      const ctx = new AppContextForM();
      bundle.facade.bindContext(ctx as never);
      // Act
      const result = await bundle.facade.explicitGuestLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(result.data !== null).assertTrue();
      expect(result.data!.isGuest).assertTrue();
      expect(result.data!.loginMethod).assertEqual('GUEST_LOCAL_FIRST');
      expect(bundle.session.guestChosenCalls).assertEqual(1);
      hooks.restore();
    });

    it('regression: explicit_guest_login_should_keep_success_when_persisted_steps_throw', 0, async () => {
      // Arrange
      const bundle = createBundleForM();
      const hooks = new HooksForM();
      const ctx = new AppContextForM();
      bundle.facade.bindContext(ctx as never);
      bundle.session.savePersistedError = 'persist_guest_failed_m';
      bundle.session.guestChosenError = 'mark_guest_failed_m';
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        throw new Error('guest_gateway_exception_force_m');
      });
      // Act
      const result = await bundle.facade.explicitGuestLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(result.data !== null).assertTrue();
      expect(result.data!.isGuest).assertTrue();
      expect(result.data!.loginMethod).assertEqual('GUEST_LOCAL_FIRST');
      expect(bundle.session.saveCalls > 0).assertTrue();
      expect(bundle.session.savePersistedCalls).assertEqual(1);
      expect(bundle.session.guestChosenCalls).assertEqual(1);
      hooks.restore();
    });
  });
}
