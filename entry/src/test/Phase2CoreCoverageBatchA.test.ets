import { describe, expect, it } from '@ohos/hypium';
import { AuthFacade } from '../main/ets/infrastructure/auth/AuthFacade';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import { HuaweiCredential, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';

class SessionManagerMock {
  session: UserSession | null = null;
  blockedMemory: boolean = false;

  load(): UserSession | null {
    return this.session;
  }

  save(_session: UserSession): void {
    return;
  }

  clear(): void {
    this.session = null;
  }

  isSilentLoginBlockedAfterLogout(): boolean {
    return this.blockedMemory;
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
    this.blockedMemory = true;
  }

  clearSilentLoginBlockedAfterLogout(): void {
    this.blockedMemory = false;
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

class HuaweiProviderMock {
  explicitErrorMessage: string = 'provider_failed';

  async explicitLogin(_context?: Object): Promise<HuaweiCredential> {
    throw new Error(this.explicitErrorMessage);
  }

  async silentLogin(_context: Object): Promise<HuaweiCredential> {
    throw new Error('silent_not_used');
  }
}

class FacadeMocksBundle {
  facade: AuthFacade = new AuthFacade();
  session: SessionManagerMock = new SessionManagerMock();
  provider: HuaweiProviderMock = new HuaweiProviderMock();
}

function createFacadeWithMocks(): FacadeMocksBundle {
  const bundle = new FacadeMocksBundle();
  Reflect.set(bundle.facade, 'sessionManager', bundle.session);
  Reflect.set(bundle.facade, 'huaweiProvider', bundle.provider);
  return bundle;
}

function createSession(isGuest: boolean): UserSession {
  const session = new UserSession();
  session.isLogin = true;
  session.accountId = 'acc_local';
  session.userId = 'user_local';
  session.accessToken = 'token_local';
  session.isGuest = isGuest;
  session.loginType = isGuest ? 'guest' : 'huawei';
  session.loginMethod = isGuest ? 'GUEST' : 'HUAWEI';
  return session;
}

export default function phase2CoreCoverageBatchATest() {
  describe('phase2CoreCoverageBatchATest', () => {
    it('normal: auth_facade_get_current_session_should_return_loaded_session', 0, () => {
      // Arrange
      const bundle = createFacadeWithMocks();
      bundle.session.session = createSession(false);

      // Act
      const current = bundle.facade.getCurrentSession();

      // Assert
      expect(current !== null).assertTrue();
      expect(current!.accountId).assertEqual('acc_local');
      expect(current!.isGuest).assertFalse();
    });

    it('boundary: auth_facade_get_current_user_profile_should_fallback_to_guest_when_session_missing', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocks();

      // Act
      const profile = await bundle.facade.getCurrentUserProfile('访客');

      // Assert
      expect(profile.userId).assertEqual('guest_local');
      expect(profile.nickname).assertEqual('访客');
      expect(profile.isGuest).assertTrue();
    });

    it('invalid: auth_facade_update_username_should_reject_session_missing_guest_and_illegal_username', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocks();

      // Act
      bundle.session.session = null;
      const noSessionResult = await bundle.facade.updateUsername('new_name');

      bundle.session.session = createSession(true);
      const guestResult = await bundle.facade.updateUsername('new_name');

      bundle.session.session = createSession(false);
      const invalidResult = await bundle.facade.updateUsername('@@@');

      // Assert
      expect(noSessionResult.success).assertFalse();
      expect(noSessionResult.code).assertEqual(AuthErrorCode.SESSION_EXPIRED);
      expect(guestResult.success).assertFalse();
      expect(guestResult.code).assertEqual(AuthErrorCode.GUEST_USERNAME_UNSUPPORTED);
      expect(invalidResult.success).assertFalse();
      expect(invalidResult.code).assertEqual(AuthErrorCode.USERNAME_INVALID);
    });

    it('conflict: auth_facade_get_current_nickname_should_return_default_when_local_session_exists_but_gateway_not_called', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocks();
      bundle.session.session = null;

      // Act
      const nickname = await bundle.facade.getCurrentNickname('默认昵称');

      // Assert
      expect(nickname).assertEqual('默认昵称');
    });

    it('regression: td-20260413-phase2-auth-facade-silent-login_should_return_expected_failure_codes', 0, async () => {
      // Arrange
      const blockedBundle = createFacadeWithMocks();
      blockedBundle.session.blockedMemory = true;

      const contextMissingBundle = createFacadeWithMocks();
      contextMissingBundle.session.blockedMemory = false;
      contextMissingBundle.session.session = null;

      // Act
      const blockedResult = await blockedBundle.facade.silentLogin();
      const contextMissingResult = await contextMissingBundle.facade.silentLogin();

      // Assert
      expect(blockedResult.success).assertFalse();
      expect(blockedResult.message).assertEqual('silent_login_blocked_after_logout');
      expect(blockedResult.status).assertEqual(LoginStatus.UNAUTHENTICATED);

      expect(contextMissingResult.success).assertFalse();
      expect(contextMissingResult.message).assertEqual('silent_login_context_unavailable');
      expect(contextMissingResult.status).assertEqual(LoginStatus.UNAUTHENTICATED);
    });

    it('combined: auth_facade_explicit_login_without_guest_fallback_should_keep_provider_error_and_login_failed_status', 0, async () => {
      // Arrange
      const bundle = createFacadeWithMocks();
      bundle.provider.explicitErrorMessage = 'provider_explicit_failed';

      // Act
      const result = await bundle.facade.explicitLoginByButton(undefined, false);

      // Assert
      expect(result.success).assertFalse();
      expect(result.source).assertEqual('HUAWEI_BUTTON');
      expect(result.status).assertEqual(LoginStatus.LOGIN_FAILED);
      expect(result.message).assertEqual('provider_explicit_failed');
    });
  });
}
