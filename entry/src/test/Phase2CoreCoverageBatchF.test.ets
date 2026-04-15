import { describe, expect, it } from '@ohos/hypium';
import { AuthFacade } from '../main/ets/infrastructure/auth/AuthFacade';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import { AuthApiResponse, AuthLoginResult, AuthSessionPayload, AuthUserProfile, DeviceInfo, SocialCredential } from '../main/ets/domain/auth/AuthModels';
import { AuthResult, HuaweiCredential, UserSession } from '../main/ets/domain/auth/AuthTypes';

class SessionManagerMockForF {
  session: UserSession | null = null;
  appClearCalls: number = 0;
  appBlockCalls: number = 0;
  memClearCalls: number = 0;
  memBlockCalls: number = 0;
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
    this.appClearCalls += 1;
    return;
  }

  async markSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> {
    this.appBlockCalls += 1;
    return;
  }

  markSilentLoginBlockedAfterLogout(): void {
    this.memBlockCalls += 1;
  }

  clearSilentLoginBlockedAfterLogout(): void {
    this.memClearCalls += 1;
  }

  async clearSilentLoginBlockedAfterLogoutPersisted(_context: Object): Promise<void> {
    this.appClearCalls += 1;
    return;
  }

  async saveSessionPersisted(_context: Object, _session: UserSession): Promise<void> {
    return;
  }

  async markGuestChosen(_context: Object): Promise<void> {
    return;
  }
}

class ProviderMockForF {
  credential: HuaweiCredential = new HuaweiCredential();

  constructor() {
    this.credential.authorizationCode = 'auth_f';
    this.credential.idToken = 'id_f';
    this.credential.openId = 'open_f';
    this.credential.unionId = 'union_f';
  }

  async explicitLogin(_context?: Object): Promise<HuaweiCredential> {
    return this.credential;
  }

  async silentLogin(_context: Object): Promise<HuaweiCredential> {
    return this.credential;
  }
}

class HooksForF {
  private readonly originCreateGuest: Object;
  private readonly originSocial: Object;

  constructor() {
    this.originCreateGuest = Reflect.get(AuthGateway, 'createGuest') as Object;
    this.originSocial = Reflect.get(AuthGateway, 'loginWithSocial') as Object;
  }

  setCreateGuest(fn: (deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'createGuest', fn);
  }

  setSocial(fn: (providerType: string, credential: SocialCredential, deviceInfo: DeviceInfo) => Promise<AuthApiResponse<AuthLoginResult>>): void {
    Reflect.set(AuthGateway, 'loginWithSocial', fn);
  }

  restore(): void {
    Reflect.set(AuthGateway, 'createGuest', this.originCreateGuest);
    Reflect.set(AuthGateway, 'loginWithSocial', this.originSocial);
  }
}

class BundleForF {
  facade: AuthFacade = new AuthFacade();
  session: SessionManagerMockForF = new SessionManagerMockForF();
  provider: ProviderMockForF = new ProviderMockForF();
}

class AppContextForF {
  tag: string = '';
  name: string = '';
}

function createBundleForF(): BundleForF {
  const bundle = new BundleForF();
  Reflect.set(bundle.facade, 'sessionManager', bundle.session);
  Reflect.set(bundle.facade, 'huaweiProvider', bundle.provider);
  return bundle;
}

function buildLoginPayloadForF(expireAt: number | string): AuthLoginResult {
  const payload = new AuthLoginResult();
  const user = new AuthUserProfile();
  user.accountId = 'acc_f';
  user.userId = 'user_f';
  user.isGuest = false;
  user.defaultLoginMethod = 'HUAWEI';
  payload.user = user;
  const session = new AuthSessionPayload();
  session.accessToken = 'token_f';
  session.refreshToken = 'refresh_f';
  session.sessionId = 'sid_f';
  Reflect.set(session as Object, 'expireAt', expireAt);
  payload.session = session;
  return payload;
}

function buildResponseForF(code: number, payload: AuthLoginResult): AuthApiResponse<AuthLoginResult> {
  const response = new AuthApiResponse<AuthLoginResult>(payload);
  response.code = code;
  response.message = code === 0 ? 'ok' : 'failed';
  return response;
}

export default function phase2CoreCoverageBatchFTest() {
  describe('phase2CoreCoverageBatchFTest', () => {
    it('normal: auth_facade_bind_context_should_store_context_reference', 0, () => {
      // Arrange
      const bundle = createBundleForF();
      const fakeContext = new AppContextForF();
      fakeContext.tag = 'ctx_f_1';
      // Act
      bundle.facade.bindContext(fakeContext as never);
      const saved = Reflect.get(bundle.facade as Object, 'appContext') as Object | null;
      // Assert
      expect(saved !== null).assertTrue();
      expect(Reflect.get(saved as Object, 'tag') as string).assertEqual('ctx_f_1');
    });

    it('boundary: auth_facade_explicit_guest_login_should_convert_session_and_set_guest_flag', 0, async () => {
      // Arrange
      const bundle = createBundleForF();
      const hooks = new HooksForF();
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        const payload = buildLoginPayloadForF('1700000000');
        payload.user.isGuest = true;
        payload.user.defaultLoginMethod = 'GUEST';
        return buildResponseForF(0, payload);
      });
      // Act
      const result = await bundle.facade.explicitGuestLogin();
      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('GUEST_FALLBACK');
      expect(result.data !== null).assertTrue();
      expect(result.data!.isGuest).assertTrue();
      expect(result.data!.loginType).assertEqual('guest');
      expect(result.data!.expireAt > 1_000_000_000_000).assertTrue();
      hooks.restore();
    });

    it('invalid: auth_facade_logout_should_mark_memory_block_when_context_absent', 0, async () => {
      // Arrange
      const bundle = createBundleForF();
      // Act
      await bundle.facade.logout();
      // Assert
      expect(bundle.session.memBlockCalls).assertEqual(1);
      expect(bundle.session.appBlockCalls).assertEqual(0);
      expect(bundle.session.appClearCalls).assertEqual(0);
    });

    it('conflict: auth_facade_logout_should_clear_and_mark_persisted_block_when_context_bound', 0, async () => {
      // Arrange
      const bundle = createBundleForF();
      const fakeContext = new AppContextForF();
      fakeContext.name = 'ctx_f_2';
      bundle.facade.bindContext(fakeContext as never);
      // Act
      await bundle.facade.logout();
      // Assert
      expect(bundle.session.appClearCalls).assertEqual(1);
      expect(bundle.session.appBlockCalls).assertEqual(1);
      expect(bundle.session.memBlockCalls).assertEqual(0);
    });

    it('regression: td-20260415-auth-facade-exchange-should-clear_memory_silent_block_on_button_success', 0, async () => {
      // Arrange
      const bundle = createBundleForF();
      const hooks = new HooksForF();
      hooks.setSocial(async (_provider: string, _credential: SocialCredential, _device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        return buildResponseForF(0, buildLoginPayloadForF('2026-04-15T12:00:00.000Z'));
      });
      // Act
      const result = await bundle.facade.explicitLoginByButton(undefined, false) as AuthResult<UserSession>;
      // Assert
      expect(result.success).assertTrue();
      expect(result.source).assertEqual('HUAWEI_BUTTON');
      expect(result.data !== null).assertTrue();
      expect(result.data!.accountId).assertEqual('acc_f');
      expect(result.data!.loginType).assertEqual('huawei');
      expect(bundle.session.memClearCalls).assertEqual(1);
      expect(bundle.session.saveCalls > 0).assertTrue();
      hooks.restore();
    });

    it('combined: auth_facade_guest_and_exchange_should_cover_invalid_expire_and_empty_session_path', 0, async () => {
      // Arrange
      const bundle = createBundleForF();
      const hooks = new HooksForF();
      hooks.setCreateGuest(async (_device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        return buildResponseForF(0, buildLoginPayloadForF('not-a-time'));
      });
      hooks.setSocial(async (_provider: string, _credential: SocialCredential, _device: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> => {
        const payload = new AuthLoginResult();
        Reflect.set(payload as Object, 'session', null);
        return buildResponseForF(0, payload);
      });
      // Act
      const guestResult = await bundle.facade.explicitGuestLogin();
      const huaweiResult = await bundle.facade.explicitLoginByButton(undefined, false);
      // Assert
      expect(guestResult.success).assertTrue();
      expect(guestResult.data !== null).assertTrue();
      expect(guestResult.data!.expireAt > Date.now()).assertTrue();
      expect(huaweiResult.success).assertFalse();
      expect(huaweiResult.message).assertEqual('session_empty');
      hooks.restore();
    });
  });
}
