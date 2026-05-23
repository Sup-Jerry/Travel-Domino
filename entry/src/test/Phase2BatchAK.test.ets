import { describe, expect, it } from '@ohos/hypium';
import { AuthFacade } from '../main/ets/infrastructure/auth/AuthFacade';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import { AuthStateMachine } from '../main/ets/domain/auth/AuthStateMachine';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';
import { AuthApiResponse, AuthLoginResult, AuthMeResult, AuthSessionPayload, AuthUserProfile, DeviceInfo, SocialCredential, UpdateUsernameResult } from '../main/ets/domain/auth/AuthModels';
import { HuaweiCredential, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';

class FakeContextAK {
  tag: string = 'ctx_ak';
}

class SessionManagerMockAK {
  session: UserSession | null = null;
  blockedMemory: boolean = false;
  blockedPersisted: boolean = false;
  saveCalls: number = 0;
  clearCalls: number = 0;
  clearPersistedCalls: number = 0;
  markPersistedBlockCalls: number = 0;
  markMemoryBlockCalls: number = 0;
  guestChosenCalls: number = 0;

  load(): UserSession | null { return this.session; }
  save(session: UserSession): void { this.session = session; this.saveCalls += 1; }
  clear(): void { this.session = null; this.clearCalls += 1; }
  isSilentLoginBlockedAfterLogout(): boolean { return this.blockedMemory; }
  async isSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<boolean> { return this.blockedPersisted; }
  async restoreSessionPersisted(_context: Object): Promise<UserSession | null> { return null; }
  async clearSessionPersisted(_context: Object): Promise<void> { this.clearPersistedCalls += 1; return; }
  async markSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> { this.markPersistedBlockCalls += 1; return; }
  markSilentLoginBlockedAfterLogout(): void { this.markMemoryBlockCalls += 1; this.blockedMemory = true; }
  clearSilentLoginBlockedAfterLogout(): void { this.blockedMemory = false; }
  async clearSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> { this.blockedPersisted = false; return; }
  async saveSessionPersisted(_context: Object, _session: UserSession): Promise<void> { return; }
  async markGuestChosen(_context: Object): Promise<void> { this.guestChosenCalls += 1; return; }
}

class HuaweiProviderMockAK {
  explicitErrorMessage: string = '';
  explicitCalls: number = 0;
  readonly credential: HuaweiCredential = new HuaweiCredential();

  constructor() {
    this.credential.authorizationCode = 'auth_ak';
    this.credential.idToken = 'id_ak';
    this.credential.openId = 'open_ak';
    this.credential.unionId = 'union_ak';
  }

  async explicitLogin(_context?: Object): Promise<HuaweiCredential> {
    this.explicitCalls += 1;
    if (this.explicitErrorMessage.length > 0) {
      throw new Error(this.explicitErrorMessage);
    }
    return this.credential;
  }

  async silentLogin(_context?: Object): Promise<HuaweiCredential> {
    return this.credential;
  }
}

class AuthGatewayHooksAK {
  private readonly originMe: Object;
  private readonly originCreateGuest: Object;
  private readonly originSocial: Object;
  private readonly originUpdateUsername: Object;

  constructor() {
    this.originMe = Reflect.get(AuthGateway, 'me') as Object;
    this.originCreateGuest = Reflect.get(AuthGateway, 'createGuest') as Object;
    this.originSocial = Reflect.get(AuthGateway, 'loginWithSocial') as Object;
    this.originUpdateUsername = Reflect.get(AuthGateway, 'updateUsername') as Object;
  }

  setMe(fn: (accessToken: string) => Promise<AuthApiResponse<AuthMeResult>>): void { Reflect.set(AuthGateway, 'me', fn); }
  setCreateGuest(fn: (deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void { Reflect.set(AuthGateway, 'createGuest', fn); }
  setSocial(fn: (providerType: string, credential: SocialCredential, deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'loginWithSocial', fn);
  }
  setUpdateUsername(fn: (accessToken: string, username: string) => Promise<AuthApiResponse<UpdateUsernameResult>>): void {
    Reflect.set(AuthGateway, 'updateUsername', fn);
  }

  restore(): void {
    Reflect.set(AuthGateway, 'me', this.originMe);
    Reflect.set(AuthGateway, 'createGuest', this.originCreateGuest);
    Reflect.set(AuthGateway, 'loginWithSocial', this.originSocial);
    Reflect.set(AuthGateway, 'updateUsername', this.originUpdateUsername);
  }
}

class AuthSessionStoreHooksAK {
  private readonly originLoad: Object;
  private readonly originSave: Object;
  private readonly originClear: Object;

  constructor() {
    this.originLoad = Reflect.get(AuthSessionStore, 'load') as Object;
    this.originSave = Reflect.get(AuthSessionStore, 'save') as Object;
    this.originClear = Reflect.get(AuthSessionStore, 'clear') as Object;
  }

  setLoad(fn: () => AuthSessionPayload | null): void { Reflect.set(AuthSessionStore, 'load', fn); }
  setSave(fn: (payload: AuthSessionPayload) => void): void { Reflect.set(AuthSessionStore, 'save', fn); }
  setClear(fn: () => void): void { Reflect.set(AuthSessionStore, 'clear', fn); }

  restore(): void {
    Reflect.set(AuthSessionStore, 'load', this.originLoad);
    Reflect.set(AuthSessionStore, 'save', this.originSave);
    Reflect.set(AuthSessionStore, 'clear', this.originClear);
  }
}

interface FacadeBundleAK {
  facade: AuthFacade;
  session: SessionManagerMockAK;
  provider: HuaweiProviderMockAK;
}

function createFacadeAK(): FacadeBundleAK {
  const facade = new AuthFacade();
  const session = new SessionManagerMockAK();
  const provider = new HuaweiProviderMockAK();
  Reflect.set(facade as Object, 'sessionManager', session);
  Reflect.set(facade as Object, 'huaweiProvider', provider);
  const bundle: FacadeBundleAK = { facade, session, provider };
  return bundle;
}

function createSessionAK(isGuest: boolean = false): UserSession {
  const s = new UserSession();
  s.isLogin = true;
  s.accountId = isGuest ? 'guest_acc_ak' : 'acc_ak';
  s.userId = isGuest ? 'guest_user_ak' : 'user_ak';
  s.accessToken = 'token_ak';
  s.refreshToken = 'refresh_ak';
  s.expireAt = Date.now() + 60_000;
  s.sessionId = 'sid_ak';
  s.isGuest = isGuest;
  s.loginType = isGuest ? 'guest' : 'huawei';
  s.loginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  s.lastLoginAt = Date.now();
  return s;
}

function meResp(code: number, nickname: string): AuthApiResponse<AuthMeResult> {
  const payload = new AuthMeResult();
  payload.accountId = 'acc_me_ak';
  payload.userId = 'user_me_ak';
  payload.nickname = nickname;
  payload.isGuest = false;
  payload.defaultLoginMethod = 'HUAWEI';
  const r = new AuthApiResponse<AuthMeResult>(payload);
  r.code = code;
  r.message = code === 0 ? 'ok' : 'me_failed';
  return r;
}

function loginResp(code: number, isGuest: boolean): AuthApiResponse<AuthLoginResult> {
  const payload = new AuthLoginResult();
  const user = new AuthUserProfile();
  user.accountId = isGuest ? 'guest_acc_login_ak' : 'acc_login_ak';
  user.userId = isGuest ? 'guest_user_login_ak' : 'user_login_ak';
  user.isGuest = isGuest;
  user.defaultLoginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  payload.user = user;
  const session = new AuthSessionPayload();
  session.accessToken = 'token_login_ak';
  session.refreshToken = 'refresh_login_ak';
  session.sessionId = 'sid_login_ak';
  session.expireAt = Date.now() + 120_000;
  payload.session = session;
  const r = new AuthApiResponse<AuthLoginResult>(payload);
  r.code = code;
  r.message = code === 0 ? 'ok' : 'failed';
  return r;
}

export default function phase2BatchAKTest() {
  describe('phase2BatchAKTest_auth_facade', () => {
    it('normal: auth_facade_get_current_nickname_should_return_trimmed_name', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      const hooks = new AuthGatewayHooksAK();
      bundle.session.session = createSessionAK(false);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => meResp(0, '  鏄电ОAK  '));
      // Act
      let nickname = '';
      try {
        nickname = await bundle.facade.getCurrentNickname('default_name_ak');
      } finally {
        hooks.restore();
      }
      // Assert
      expect(nickname).assertEqual('鏄电ОAK');
    });

    it('boundary: auth_facade_get_current_nickname_should_return_default_when_no_session', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      // Act
      const nickname = await bundle.facade.getCurrentNickname('default_name_ak');
      // Assert
      expect(nickname).assertEqual('default_name_ak');
    });

    it('boundary: auth_facade_get_current_nickname_should_return_default_when_session_is_guest', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      bundle.session.session = createSessionAK(true);
      // Act
      const nickname = await bundle.facade.getCurrentNickname('default_guest_ak');
      // Assert
      expect(nickname).assertEqual('default_guest_ak');
    });

    it('invalid: auth_facade_get_current_nickname_should_return_default_when_gateway_failed', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      const hooks = new AuthGatewayHooksAK();
      bundle.session.session = createSessionAK(false);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => meResp(500, ''));
      // Act
      let nickname = '';
      try {
        nickname = await bundle.facade.getCurrentNickname('default_name_ak');
      } finally {
        hooks.restore();
      }
      // Assert
      expect(nickname).assertEqual('default_name_ak');
    });

    it('normal: auth_facade_explicit_login_should_success_with_given_credential', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      const hooks = new AuthGatewayHooksAK();
      hooks.setSocial(async (_p: string, _c: SocialCredential, _d: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => loginResp(0, false));
      const cred = new HuaweiCredential();
      cred.authorizationCode = 'a';
      cred.idToken = 'b';
      cred.openId = 'c';
      cred.unionId = 'd';
      // Act
      let resultSource = '';
      try {
        const result = await bundle.facade.explicitLoginByButton(cred, false);
        resultSource = result.source;
      } finally {
        hooks.restore();
      }
      // Assert
      expect(resultSource).assertEqual('HUAWEI_BUTTON');
    });

    it('boundary: auth_facade_explicit_login_should_fallback_guest_when_provider_error', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      const hooks = new AuthGatewayHooksAK();
      bundle.provider.explicitErrorMessage = 'provider_failed';
      hooks.setCreateGuest(async (_d: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => loginResp(0, true));
      // Act
      let guest = false;
      try {
        const result = await bundle.facade.explicitLoginByButton(undefined, true);
        guest = Boolean(result.data?.isGuest);
      } finally {
        hooks.restore();
      }
      // Assert
      expect(guest).assertTrue();
    });

    it('invalid: auth_facade_explicit_login_should_fail_when_fallback_disabled', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      bundle.provider.explicitErrorMessage = 'provider_failed';
      // Act
      const result = await bundle.facade.explicitLoginByButton(undefined, false);
      // Assert
      expect(result.success).assertFalse();
      expect(result.status).assertEqual(LoginStatus.LOGIN_FAILED);
    });

    it('conflict: auth_facade_update_username_should_reject_guest', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      bundle.session.session = createSessionAK(true);
      // Act
      const result = await bundle.facade.updateUsername('guest_name');
      // Assert
      expect(result.code).assertEqual(AuthErrorCode.GUEST_USERNAME_UNSUPPORTED);
    });

    it('regression: td-20260416-auth_facade-logout-should-mark-memory-when-no-context', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      // Act
      await bundle.facade.logout();
      // Assert
      expect(bundle.session.markMemoryBlockCalls).assertEqual(1);
      expect(bundle.session.markPersistedBlockCalls).assertEqual(0);
    });

    it('combined: auth_facade_silent_login_should_clear_expired_session_then_fail_without_context', 0, async () => {
      // Arrange
      const bundle = createFacadeAK();
      const hooks = new AuthGatewayHooksAK();
      bundle.session.session = createSessionAK(false);
      hooks.setMe(async (_token: string): Promise<AuthApiResponse<AuthMeResult>> => meResp(AuthErrorCode.SESSION_EXPIRED, ''));
      // Act
      let message = '';
      try {
        const result = await bundle.facade.silentLogin();
        message = result.message;
      } finally {
        hooks.restore();
      }
      // Assert
      expect(bundle.session.clearCalls).assertEqual(1);
      expect(message).assertEqual('silent_login_context_unavailable');
    });
  });

  describe('phase2BatchAKTest_session_manager', () => {
    it('normal: session_manager_load_should_map_payload_to_session', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      const hooks = new AuthSessionStoreHooksAK();
      hooks.setLoad((): AuthSessionPayload | null => {
        const payload = new AuthSessionPayload();
        payload.accountId = 'acc_store_ak';
        payload.userId = 'user_store_ak';
        payload.isGuest = false;
        payload.loginMethod = 'HUAWEI';
        payload.accessToken = 'token_store_ak';
        payload.refreshToken = 'refresh_store_ak';
        payload.sessionId = 'sid_store_ak';
        payload.expireAt = Date.now() + 60_000;
        return payload;
      });
      // Act
      let session: UserSession | null = null;
      try {
        session = manager.load();
      } finally {
        hooks.restore();
      }
      // Assert
      expect(session !== null).assertTrue();
      expect(String(session?.accountId || '')).assertEqual('acc_store_ak');
    });

    it('boundary: session_manager_save_should_fallback_expire_at_for_nan', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      const hooks = new AuthSessionStoreHooksAK();
      let capturedExpireAt = 0;
      hooks.setSave((payload: AuthSessionPayload): void => {
        capturedExpireAt = payload.expireAt;
      });
      const session = createSessionAK(false);
      session.expireAt = Number.NaN;
      // Act
      try {
        manager.save(session);
      } finally {
        hooks.restore();
      }
      // Assert
      expect(capturedExpireAt > Date.now()).assertTrue();
    });

    it('invalid: session_manager_load_should_return_null_when_payload_missing', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      const hooks = new AuthSessionStoreHooksAK();
      hooks.setLoad((): AuthSessionPayload | null => null);
      // Act
      let session: UserSession | null = createSessionAK(false);
      try {
        session = manager.load();
      } finally {
        hooks.restore();
      }
      // Assert
      expect(session === null).assertTrue();
    });

    it('conflict: session_manager_alias_save_restore_clear_should_delegate', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      const hooks = new AuthSessionStoreHooksAK();
      let saved: AuthSessionPayload | null = null;
      hooks.setSave((payload: AuthSessionPayload): void => { saved = payload; });
      hooks.setLoad((): AuthSessionPayload | null => saved);
      hooks.setClear((): void => { saved = null; });
      // Act
      let beforeClear: UserSession | null = null;
      let afterClear: UserSession | null = createSessionAK(false);
      try {
        manager.saveSession(createSessionAK(false));
        beforeClear = manager.restoreSession();
        manager.clearSession();
        afterClear = manager.restoreSession();
      } finally {
        hooks.restore();
      }
      // Assert
      expect(beforeClear !== null).assertTrue();
      expect(afterClear === null).assertTrue();
    });

    it('regression: td-20260416-session_manager-is_logged_in-should-follow-load', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      const hooks = new AuthSessionStoreHooksAK();
      let empty = false;
      hooks.setLoad((): AuthSessionPayload | null => {
        if (empty) {
          return null;
        }
        const payload = new AuthSessionPayload();
        payload.accessToken = 't';
        payload.refreshToken = 'r';
        payload.sessionId = 's';
        payload.expireAt = Date.now() + 60_000;
        return payload;
      });
      // Act
      let first = false;
      let second = true;
      try {
        first = manager.isLoggedIn();
        empty = true;
        second = manager.isLoggedIn();
      } finally {
        hooks.restore();
      }
      // Assert
      expect(first).assertTrue();
      expect(second).assertFalse();
    });

    it('combined: session_manager_get_current_account_id_should_trim_or_empty', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      const hooks = new AuthSessionStoreHooksAK();
      let hasPayload = true;
      hooks.setLoad((): AuthSessionPayload | null => {
        if (!hasPayload) {
          return null;
        }
        const payload = new AuthSessionPayload();
        payload.accountId = '  acc_trim_ak  ';
        payload.accessToken = 't';
        payload.refreshToken = 'r';
        payload.sessionId = 's';
        payload.expireAt = Date.now() + 60_000;
        return payload;
      });
      // Act
      let first = '';
      let second = 'x';
      try {
        first = manager.getCurrentAccountId();
        hasPayload = false;
        second = manager.getCurrentAccountId();
      } finally {
        hooks.restore();
      }
      // Assert
      expect(first).assertEqual('acc_trim_ak');
      expect(second).assertEqual('');
    });
  });

  describe('phase2BatchAKTest_state_machine_and_error_code', () => {
    it('normal: auth_state_machine_should_resolve_authenticated_and_active', 0, () => {
      // Arrange
      const expireAt = Date.now() + 60_000;
      // Act
      const userState = AuthStateMachine.resolveUserRuntimeState(false, true, false, false);
      const sessionState = AuthStateMachine.resolveSessionRuntimeState(expireAt, false);
      // Assert
      expect(userState).assertEqual('AUTHENTICATED');
      expect(sessionState).assertEqual('ACTIVE');
    });

    it('boundary: auth_state_machine_should_prioritize_blocked_and_revoked', 0, () => {
      // Arrange
      const expireAt = Date.now() - 1;
      // Act
      const userState = AuthStateMachine.resolveUserRuntimeState(true, true, true, true);
      const sessionState = AuthStateMachine.resolveSessionRuntimeState(expireAt, true);
      // Assert
      expect(userState).assertEqual('BLOCKED');
      expect(sessionState).assertEqual('REVOKED');
    });

    it('invalid: auth_state_machine_should_output_unauthenticated_and_expired', 0, () => {
      // Arrange
      const expireAt = Date.now() - 1;
      // Act
      const userState = AuthStateMachine.resolveUserRuntimeState(false, false, false, false);
      const sessionState = AuthStateMachine.resolveSessionRuntimeState(expireAt, false);
      // Assert
      expect(userState).assertEqual('UNAUTHENTICATED');
      expect(sessionState).assertEqual('EXPIRED');
    });

    it('conflict: auth_state_machine_should_prioritize_pending_before_guest_and_authenticated', 0, () => {
      // Arrange
      const expireAt = Date.now() + 60_000;
      // Act
      const userState = AuthStateMachine.resolveUserRuntimeState(true, true, false, true);
      const sessionState = AuthStateMachine.resolveSessionRuntimeState(expireAt, false);
      // Assert
      expect(userState).assertEqual('AUTH_PENDING');
      expect(sessionState).assertEqual('ACTIVE');
    });

    it('regression: auth_state_machine_should_output_guest_when_authenticated_guest_not_blocked_or_pending', 0, () => {
      // Arrange
      const expireAt = Date.now() + 60_000;
      // Act
      const userState = AuthStateMachine.resolveUserRuntimeState(true, true, false, false);
      const sessionState = AuthStateMachine.resolveSessionRuntimeState(expireAt, false);
      // Assert
      expect(userState).assertEqual('GUEST');
      expect(sessionState).assertEqual('ACTIVE');
    });

    it('normal: auth_error_code_should_keep_core_values', 0, () => {
      // Arrange
      // Act
      const ok = AuthErrorCode.OK;
      const expired = AuthErrorCode.SESSION_EXPIRED;
      const invalidName = AuthErrorCode.USERNAME_INVALID;
      // Assert
      expect(ok).assertEqual(0);
      expect(expired).assertEqual(10010);
      expect(invalidName).assertEqual(10015);
    });

    it('boundary: auth_error_code_should_keep_values_unique_and_non_negative', 0, () => {
      // Arrange
      const values: number[] = [
        AuthErrorCode.OK,
        AuthErrorCode.INVALID_PARAM,
        AuthErrorCode.SESSION_EXPIRED,
        AuthErrorCode.USERNAME_INVALID,
        AuthErrorCode.AVATAR_INVALID
      ];
      // Act
      const hasNegative = values.some((value: number) => value < 0);
      const uniqueCount = new Set<number>(values).size;
      // Assert
      expect(hasNegative).assertFalse();
      expect(uniqueCount).assertEqual(values.length);
    });

    it('invalid: auth_error_code_should_not_match_unknown_number', 0, () => {
      // Arrange
      const knownCodes: number[] = [
        AuthErrorCode.OK,
        AuthErrorCode.INVALID_PARAM,
        AuthErrorCode.SESSION_EXPIRED,
        AuthErrorCode.USERNAME_INVALID,
        AuthErrorCode.AVATAR_INVALID
      ];
      // Act
      const matched = knownCodes.indexOf(99999) >= 0;
      // Assert
      expect(matched).assertFalse();
    });
  });
}
