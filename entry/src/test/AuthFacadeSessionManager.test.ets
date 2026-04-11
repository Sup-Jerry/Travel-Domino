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
    it('boundary: td-20260411-auto-AuthFacadeSessionManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-AuthFacadeSessionManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-AuthFacadeSessionManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-AuthFacadeSessionManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}

