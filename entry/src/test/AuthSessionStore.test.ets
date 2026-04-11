import { describe, expect, it } from '@ohos/hypium';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { AuthSessionPayload } from '../main/ets/domain/auth/AuthModels';

function resetAuthStorage(): void {
  AppStorage.setOrCreate(AppStorageKeys.AUTH_SESSION_JSON, '');
  AppStorage.setOrCreate(AppStorageKeys.AUTH_GUEST_CHOSEN, false);
  AppStorage.setOrCreate(AppStorageKeys.AUTH_BLOCK_SILENT_AFTER_LOGOUT, false);
}

function buildPayload(expireAt: number): AuthSessionPayload {
  const payload = new AuthSessionPayload();
  payload.accountId = 'acc_auth_store';
  payload.userId = 'user_auth_store';
  payload.isGuest = false;
  payload.loginMethod = 'HUAWEI';
  payload.accessToken = 'access_token';
  payload.refreshToken = 'refresh_token';
  payload.sessionId = 'session_auth_store';
  payload.expireAt = expireAt;
  return payload;
}

export default function authSessionStoreTest() {
  describe('authSessionStoreTest', () => {
    it('normal: save_and_load_should_roundtrip_core_session_fields', 0, () => {
      // Arrange
      resetAuthStorage();
      const payload = buildPayload(Date.now() + 60_000);
      // Act
      AuthSessionStore.save(payload);
      const loaded = AuthSessionStore.load();
      // Assert
      expect(loaded !== null).assertTrue();
      expect(loaded?.accountId || '').assertEqual('acc_auth_store');
      expect(loaded?.sessionId || '').assertEqual('session_auth_store');
      expect(loaded?.loginMethod || '').assertEqual('HUAWEI');
    });

    it('boundary: get_access_token_should_return_empty_when_expire_at_reached', 0, () => {
      // Arrange
      resetAuthStorage();
      const expired = buildPayload(Date.now() - 1);
      AuthSessionStore.save(expired);
      // Act
      const token = AuthSessionStore.getAccessToken();
      // Assert
      expect(token).assertEqual('');
    });

    it('invalid: load_should_return_null_when_required_fields_missing', 0, () => {
      // Arrange
      resetAuthStorage();
      AppStorage.setOrCreate(
        AppStorageKeys.AUTH_SESSION_JSON,
        JSON.stringify({ accountId: 'acc_x', accessToken: '', refreshToken: '', sessionId: '' })
      );
      // Act
      const loaded = AuthSessionStore.load();
      // Assert
      expect(loaded === null).assertTrue();
    });

    it('conflict: guest_and_silent_block_flags_should_not_affect_each_other', 0, () => {
      // Arrange
      resetAuthStorage();
      // Act
      AuthSessionStore.markGuestChosen();
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      const guestChosen = AuthSessionStore.hasGuestChosen();
      const silentBlocked = AuthSessionStore.isSilentLoginBlockedAfterLogout();
      AuthSessionStore.clearSilentLoginBlockedAfterLogout();
      const silentBlockedAfterClear = AuthSessionStore.isSilentLoginBlockedAfterLogout();
      // Assert
      expect(guestChosen).assertTrue();
      expect(silentBlocked).assertTrue();
      expect(silentBlockedAfterClear).assertFalse();
      expect(AuthSessionStore.hasGuestChosen()).assertTrue();
    });

    it('regression: td-20260411-c4-auth-session-clear-should-remove-token-surface', 0, () => {
      // Arrange
      resetAuthStorage();
      AuthSessionStore.save(buildPayload(Date.now() + 120_000));
      // Act
      AuthSessionStore.clear();
      const loaded = AuthSessionStore.load();
      const token = AuthSessionStore.getAccessToken();
      // Assert
      expect(loaded === null).assertTrue();
      expect(token).assertEqual('');
    });

    it('combined: save_then_mark_flags_then_replace_session_should_keep_latest_payload_and_flags', 0, () => {
      // Arrange
      resetAuthStorage();
      const first = buildPayload(Date.now() + 60_000);
      const second = buildPayload(Date.now() + 120_000);
      second.accountId = 'acc_auth_store_v2';
      second.accessToken = 'access_token_v2';
      // Act
      AuthSessionStore.save(first);
      AuthSessionStore.markGuestChosen();
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
      AuthSessionStore.save(second);
      const loaded = AuthSessionStore.load();
      const token = AuthSessionStore.getAccessToken();
      // Assert
      expect(loaded !== null).assertTrue();
      expect(loaded?.accountId || '').assertEqual('acc_auth_store_v2');
      expect(token).assertEqual('access_token_v2');
      expect(AuthSessionStore.hasGuestChosen()).assertTrue();
      expect(AuthSessionStore.isSilentLoginBlockedAfterLogout()).assertTrue();
    });
  });
}
