import { describe, expect, it } from '@ohos/hypium';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';

export default function authFacadeSessionManagerTest() {
  describe('authFacadeSessionManagerTest', () => {
    it('normal: session_manager_should_save_and_load_user_session', 0, () => {
      // Arrange
      // Act
      // Assert
      const manager = SessionManager.getInstance();
      manager.clear();

      const session = new UserSession();
      session.accountId = 'acc_1';
      session.userId = 'u1';
      session.accessToken = 'token_1';
      session.refreshToken = 'refresh_1';
      session.sessionId = 's_1';
      session.expireAt = Date.now() + 60_000;
      manager.saveSession(session);

      const loaded = manager.restoreSession();
      expect(loaded !== null).assertTrue();
      expect(String(loaded?.accountId || '')).assertEqual('acc_1');
      expect(String(loaded?.accessToken || '')).assertEqual('token_1');
      expect(String(loaded?.sessionId || '')).assertEqual('s_1');
      expect(manager.isLoggedIn()).assertTrue();
      expect(manager.getCurrentAccountId()).assertEqual('acc_1');

      manager.clearSession();
      expect(manager.isLoggedIn()).assertFalse();
      expect(manager.getCurrentAccountId()).assertEqual('');
    });

    it('invalid: session_manager_should_fallback_expire_at_when_invalid', 0, () => {
      // Arrange
      // Act
      // Assert
      const manager = SessionManager.getInstance();
      manager.clear();

      const session = new UserSession();
      session.accountId = 'acc_expire_fallback';
      session.userId = 'u_expire_fallback';
      session.accessToken = 'token_expire_fallback';
      session.refreshToken = 'refresh_expire_fallback';
      session.sessionId = 's_expire_fallback';
      session.expireAt = Number.NaN;
      manager.saveSession(session);

      const loaded = manager.restoreSession();
      expect(loaded !== null).assertTrue();
      expect(String(loaded?.accountId || '')).assertEqual('acc_expire_fallback');
      expect(manager.isLoggedIn()).assertTrue();
    });
  });
  describe('unit_test_case_generator_autofill_AuthFacadeSessionManager', () => {
    it('boundary: session_manager_should_trim_current_account_id_and_preserve_guest_session', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      manager.clear();

      const session = new UserSession();
      session.accountId = '  guest_acc  ';
      session.userId = 'guest_user';
      session.isGuest = true;
      session.loginMethod = 'guest';
      session.accessToken = '';
      session.refreshToken = '';
      session.sessionId = '';
      session.expireAt = Date.now() + 60_000;

      // Act
      manager.saveSession(session);
      const loaded = manager.restoreSession();

      // Assert
      expect(loaded !== null).assertTrue();
      expect(loaded?.isGuest).assertTrue();
      expect(String(loaded?.loginType || '')).assertEqual('guest');
      expect(manager.getCurrentAccountId()).assertEqual('guest_acc');
      manager.clearSession();
    });

    it('conflict: session_manager_should_hide_expired_session_even_when_payload_exists', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      manager.clear();

      const session = new UserSession();
      session.accountId = 'expired_acc';
      session.userId = 'expired_user';
      session.accessToken = 'expired_token';
      session.refreshToken = 'expired_refresh';
      session.sessionId = 'expired_session';
      session.expireAt = Date.now() - 1_000;
      manager.saveSession(session);

      // Act
      const loaded = manager.restoreSession();

      // Assert
      expect(loaded === null).assertTrue();
      expect(manager.isLoggedIn()).assertFalse();
      expect(manager.getCurrentAccountId()).assertEqual('');
      manager.clearSession();
    });

    it('regression: session_manager_should_keep_latest_session_after_overwrite', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      manager.clear();

      const first = new UserSession();
      first.accountId = 'first_acc';
      first.userId = 'first_user';
      first.accessToken = 'first_token';
      first.refreshToken = 'first_refresh';
      first.sessionId = 'first_session';
      first.expireAt = Date.now() + 60_000;

      const second = new UserSession();
      second.accountId = 'second_acc';
      second.userId = 'second_user';
      second.accessToken = 'second_token';
      second.refreshToken = 'second_refresh';
      second.sessionId = 'second_session';
      second.expireAt = Date.now() + 120_000;

      // Act
      manager.saveSession(first);
      manager.saveSession(second);
      const loaded = manager.restoreSession();

      // Assert
      expect(loaded !== null).assertTrue();
      expect(String(loaded?.accountId || '')).assertEqual('second_acc');
      expect(String(loaded?.accessToken || '')).assertEqual('second_token');
      expect(String(loaded?.sessionId || '')).assertEqual('second_session');
      manager.clearSession();
    });

    it('combined: session_manager_should_reset_login_state_after_save_and_clear_sequence', 0, () => {
      // Arrange
      const manager = SessionManager.getInstance();
      manager.clear();

      const session = new UserSession();
      session.accountId = 'combo_acc';
      session.userId = 'combo_user';
      session.accessToken = 'combo_token';
      session.refreshToken = 'combo_refresh';
      session.sessionId = 'combo_session';
      session.expireAt = Date.now() + 60_000;

      // Act
      manager.saveSession(session);
      const loggedInBeforeClear = manager.isLoggedIn();
      const accountBeforeClear = manager.getCurrentAccountId();
      manager.clearSession();
      const loggedInAfterClear = manager.isLoggedIn();
      const accountAfterClear = manager.getCurrentAccountId();

      // Assert
      expect(loggedInBeforeClear).assertTrue();
      expect(accountBeforeClear).assertEqual('combo_acc');
      expect(loggedInAfterClear).assertFalse();
      expect(accountAfterClear).assertEqual('');
    });
  });
}

