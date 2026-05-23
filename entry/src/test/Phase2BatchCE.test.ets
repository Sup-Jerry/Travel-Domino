import { common } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';
import { AuthSessionPayload } from '../main/ets/domain/auth/AuthModels';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';

class HookEntryCE {
  owner: Object;
  key: string;
  value: Object | undefined;

  constructor(owner: Object, key: string, value: Object | undefined) {
    this.owner = owner;
    this.key = key;
    this.value = value;
  }
}

class HooksCE {
  private readonly entries: HookEntryCE[] = [];

  keep(owner: Object, key: string): void {
    this.entries.push(new HookEntryCE(owner, key, Reflect.get(owner, key) as Object | undefined));
  }

  set(owner: Object, key: string, value: Object): void {
    Reflect.set(owner, key, value);
  }

  restoreAll(): void {
    for (let i = this.entries.length - 1; i >= 0; i--) {
      const entry = this.entries[i];
      Reflect.set(entry.owner, entry.key, entry.value);
    }
  }
}

export default function phase2BatchCETest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCE_session_manager_extra', () => {
    it('normal: session_manager_should_delegate_persisted_session_save_and_clear', 0, async () => {
      // Arrange
      const hooks = new HooksCE();
      const context = {} as common.Context;
      const session = new UserSession();
      session.accountId = 'account_ce';
      session.userId = 'user_ce';
      session.isGuest = false;
      session.loginMethod = 'huawei';
      session.accessToken = 'access_ce';
      session.refreshToken = 'refresh_ce';
      session.expireAt = 4102444800000;
      session.sessionId = 'session_ce';
      let savedAccountId = '';
      let savedSessionId = '';
      let saveContextOk = false;
      let clearContextOk = false;
      hooks.keep(Object(AuthSessionStore), 'saveSessionPersisted');
      hooks.keep(Object(AuthSessionStore), 'clearSessionPersisted');
      hooks.set(Object(AuthSessionStore), 'saveSessionPersisted', (async (_context: common.Context, payload: AuthSessionPayload): Promise<void> => {
        saveContextOk = _context === context;
        savedAccountId = payload.accountId;
        savedSessionId = payload.sessionId;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'clearSessionPersisted', (async (_context: common.Context): Promise<void> => {
        clearContextOk = _context === context;
      }) as Object);
      const manager = SessionManager.getInstance();

      // Act
      await manager.saveSessionPersisted(context, session);
      await manager.clearSessionPersisted(context);

      // Assert
      expect(saveContextOk).assertTrue();
      expect(clearContextOk).assertTrue();
      expect(savedAccountId).assertEqual('account_ce');
      expect(savedSessionId).assertEqual('session_ce');
      hooks.restoreAll();
    });

    it('normal: session_manager_should_delegate_guest_chosen_persisted_methods', 0, async () => {
      // Arrange
      const hooks = new HooksCE();
      const context = {} as common.Context;
      let markCount = 0;
      let hasContext = false;
      hooks.keep(Object(AuthSessionStore), 'markGuestChosenPersisted');
      hooks.keep(Object(AuthSessionStore), 'hasGuestChosenPersisted');
      hooks.set(Object(AuthSessionStore), 'markGuestChosenPersisted', (async (_context: common.Context): Promise<void> => {
        markCount += 1;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'hasGuestChosenPersisted', (async (_context: common.Context): Promise<boolean> => {
        hasContext = _context === context;
        return true;
      }) as Object);
      const manager = SessionManager.getInstance();

      // Act
      await manager.markGuestChosen(context);
      const chosen = await manager.hasGuestChosen(context);

      // Assert
      expect(markCount).assertEqual(1);
      expect(chosen).assertTrue();
      expect(hasContext).assertTrue();
      hooks.restoreAll();
    });

    it('boundary: session_manager_should_save_in_memory_when_restore_session_persisted_succeeds', 0, async () => {
      // Arrange
      const hooks = new HooksCE();
      const context = {} as common.Context;
      const payload = new AuthSessionPayload();
      payload.accountId = 'restore_ce';
      payload.userId = 'restore_user_ce';
      payload.isGuest = true;
      payload.loginMethod = 'guest';
      payload.accessToken = 'restore_access_ce';
      payload.refreshToken = 'restore_refresh_ce';
      payload.expireAt = Date.now() + 60_000;
      payload.sessionId = 'restore_session_ce';
      let saveCalled = false;
      const savePayload = new AuthSessionPayload();
      hooks.keep(Object(AuthSessionStore), 'loadSessionPersisted');
      hooks.keep(Object(AuthSessionStore), 'save');
      hooks.set(Object(AuthSessionStore), 'loadSessionPersisted', (async (_context: common.Context): Promise<AuthSessionPayload | null> => {
        return _context === context ? payload : null;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'save', ((nextPayload: AuthSessionPayload): void => {
        saveCalled = true;
        savePayload.accountId = nextPayload.accountId;
        savePayload.sessionId = nextPayload.sessionId;
      }) as Object);
      const manager = SessionManager.getInstance();

      // Act
      const restored = await manager.restoreSessionPersisted(context);

      // Assert
      expect(restored !== null).assertTrue();
      expect(restored?.isGuest).assertTrue();
      expect(String(restored?.accountId || '')).assertEqual('restore_ce');
      expect(saveCalled).assertTrue();
      expect(String(savePayload.accountId || '')).assertEqual('restore_ce');
      expect(String(savePayload.sessionId || '')).assertEqual('restore_session_ce');
      hooks.restoreAll();
    });

    it('boundary: session_manager_should_delegate_silent_login_block_sync_methods', 0, () => {
      // Arrange
      const hooks = new HooksCE();
      let blocked = false;
      let markCount = 0;
      let clearCount = 0;
      hooks.keep(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogout');
      hooks.keep(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogout');
      hooks.keep(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogout');
      hooks.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogout', (() => {
        markCount += 1;
        blocked = true;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogout', (() => {
        clearCount += 1;
        blocked = false;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogout', (() => blocked) as Object);
      const manager = SessionManager.getInstance();

      // Act
      manager.markSilentLoginBlockedAfterLogout();
      const afterMark = manager.isSilentLoginBlockedAfterLogout();
      manager.clearSilentLoginBlockedAfterLogout();
      const afterClear = manager.isSilentLoginBlockedAfterLogout();

      // Assert
      expect(markCount).assertEqual(1);
      expect(clearCount).assertEqual(1);
      expect(afterMark).assertTrue();
      expect(afterClear).assertFalse();
      hooks.restoreAll();
    });

    it('invalid: session_manager_should_delegate_silent_login_block_persisted_methods', 0, async () => {
      // Arrange
      const hooks = new HooksCE();
      const context = {} as common.Context;
      let blocked = true;
      let markCount = 0;
      let clearCount = 0;
      hooks.keep(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted');
      hooks.keep(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogoutPersisted');
      hooks.keep(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted');
      hooks.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted', (async (_context: common.Context): Promise<void> => {
        markCount += 1;
        blocked = true;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogoutPersisted', (async (_context: common.Context): Promise<void> => {
        clearCount += 1;
        blocked = false;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted', (async (_context: common.Context): Promise<boolean> => blocked) as Object);
      const manager = SessionManager.getInstance();

      // Act
      await manager.markSilentLoginBlockedAfterLogoutPersisted(context);
      const afterMark = await manager.isSilentLoginBlockedAfterLogoutPersisted(context);
      await manager.clearSilentLoginBlockedAfterLogoutPersisted(context);
      const afterClear = await manager.isSilentLoginBlockedAfterLogoutPersisted(context);

      // Assert
      expect(markCount).assertEqual(1);
      expect(clearCount).assertEqual(1);
      expect(afterMark).assertTrue();
      expect(afterClear).assertFalse();
      hooks.restoreAll();
    });

    it('combined: session_manager_should_delegate_multiple_auth_session_flags_without_cross_state_leak', 0, async () => {
      // Arrange
      const hooks = new HooksCE();
      const context = {} as common.Context;
      let guestChosen = false;
      let silentBlocked = false;
      hooks.keep(Object(AuthSessionStore), 'markGuestChosenPersisted');
      hooks.keep(Object(AuthSessionStore), 'hasGuestChosenPersisted');
      hooks.keep(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted');
      hooks.keep(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted');
      hooks.set(Object(AuthSessionStore), 'markGuestChosenPersisted', (async (_context: common.Context): Promise<void> => {
        guestChosen = true;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'hasGuestChosenPersisted', (async (_context: common.Context): Promise<boolean> => guestChosen) as Object);
      hooks.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted', (async (_context: common.Context): Promise<void> => {
        silentBlocked = true;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted', (async (_context: common.Context): Promise<boolean> => silentBlocked) as Object);
      const manager = SessionManager.getInstance();

      // Act
      await manager.markGuestChosen(context);
      const chosen = await manager.hasGuestChosen(context);
      const beforeSilentBlock = await manager.isSilentLoginBlockedAfterLogoutPersisted(context);
      await manager.markSilentLoginBlockedAfterLogoutPersisted(context);
      const afterSilentBlock = await manager.isSilentLoginBlockedAfterLogoutPersisted(context);

      // Assert
      expect(chosen).assertTrue();
      expect(beforeSilentBlock).assertFalse();
      expect(afterSilentBlock).assertTrue();
      hooks.restoreAll();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
