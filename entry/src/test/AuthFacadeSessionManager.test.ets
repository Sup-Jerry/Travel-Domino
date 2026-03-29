import { describe, expect, it } from '@ohos/hypium';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';

export default function authFacadeSessionManagerTest() {
  describe('authFacadeSessionManagerTest', () => {
    it('session_manager_should_save_and_load_user_session', 0, () => {
      const manager = SessionManager.getInstance();
      manager.clear();

      const session = new UserSession();
      session.userId = 'u1';
      session.accessToken = 'token_1';
      session.refreshToken = 'refresh_1';
      session.sessionId = 's_1';
      session.expireAt = Date.now() + 60_000;
      manager.save(session);

      const loaded = manager.load();
      expect(loaded !== null).assertTrue();
      expect(String(loaded?.accessToken || '')).assertEqual('token_1');
      expect(String(loaded?.sessionId || '')).assertEqual('s_1');
    });
  });
}

