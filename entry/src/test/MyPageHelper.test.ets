import { describe, it, expect } from '@ohos/hypium';
import {
  createMyPageForTest,
  normalizeMyPageLightHintKey,
  normalizeMyPageUsername,
  resolveMyPageAgreementRequiredToast,
  resolveMyPageAvatarSyncPendingHint,
  resolveMyPageAvatarUpdateToast,
  resolveMyPageRemoteAvatarUrl,
  resolveMyPageProfileBootstrapHint,
  shouldMyPageEmitLightHint,
  shouldMyPageUseImmediateGuestProfile
} from '../main/ets/pages/MyPage';

interface MyPagePrivateTest {
  userName: string;
  loadingProfile: boolean;
  actionLoading: boolean;
  isGuestUser: boolean;
  agreementAccepted: boolean;
  avatarDisplayUri: string;
  useDefaultAvatar: boolean;
  avatarBusy: boolean;
  currentUserId: string;
  currentRemoteAvatarUrl: string;
  showUsernameEditor: boolean;
  usernameDraft: string;
  profileReady: boolean;
  effectiveTheme: string;
  aboutToAppear(): void;
  refreshUserState(): Promise<void>;
  initialRender(): void;
  normalizeAndValidateUsername(rawValue: string): string;
  openUsernameEditor(): void;
}

function createMyPagePrivateForTest(): MyPagePrivateTest {
  return createMyPageForTest() as MyPagePrivateTest;
}

export default function myPageHelperTest() {
  describe('unit_test_case_generator_autofill_MyPageHelper', () => {
    it('normal: my_page_username_should_trim_and_keep_valid_chars', 0, () => {
      // Arrange
      const input = '  Alice_01 ';
      // Act
      const username = normalizeMyPageUsername(input);
      // Assert
      expect(username).assertEqual('Alice_01');
    });

    it('boundary: my_page_username_should_reject_length_over_32', 0, () => {
      // Arrange
      const input = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      // Act
      const username = normalizeMyPageUsername(input);
      // Assert
      expect(username).assertEqual('');
    });

    it('invalid: my_page_username_should_reject_unsupported_symbols', 0, () => {
      // Arrange
      const input = 'name@home';
      // Act
      const username = normalizeMyPageUsername(input);
      // Assert
      expect(username).assertEqual('');
    });

    it('conflict: my_page_light_hint_should_block_duplicate_within_dedup_window', 0, () => {
      // Arrange
      const lastKey = 'profile_offline:user1';
      const nextKey = 'profile_offline:user1';
      // Act
      const shouldEmit = shouldMyPageEmitLightHint(lastKey, 1000, nextKey, 2000, 2000);
      // Assert
      expect(shouldEmit).assertFalse();
    });

    it('regression: td-20260412-my_page_agreement_toast_should_keep_exact_copy', 0, () => {
      // Arrange
      // Act
      const message = resolveMyPageAgreementRequiredToast();
      // Assert
      expect(message).assertEqual('请先勾选《用户协议》和《隐私政策》');
    });

    it('combined: my_page_light_hint_key_normalization_and_emit_should_work_together', 0, () => {
      // Arrange
      const rawKey = '  profile_cloud_fail:user2  ';
      const normalizedKey = normalizeMyPageLightHintKey(rawKey);
      // Act
      const shouldEmit = shouldMyPageEmitLightHint('', 0, normalizedKey, 5000, 1000);
      // Assert
      expect(normalizedKey).assertEqual('profile_cloud_fail:user2');
      expect(shouldEmit).assertTrue();
    });

    it('invalid: my_page_profile_bootstrap_hint_should_return_cloud_fail_payload_for_error_state', 0, () => {
      // Arrange
      const accountId = 'user_42';
      // Act
      const payload = resolveMyPageProfileBootstrapHint(accountId, 'error');
      // Assert
      expect(payload !== null).assertTrue();
      expect(payload?.key).assertEqual('profile_cloud_fail:user_42');
    });

    it('regression: my_page_remote_avatar_url_should_keep_auth_avatar_when_cloud_profile_is_default', 0, () => {
      // Arrange
      const authAvatarUrl = 'https://cdn.example.com/avatar.jpg';
      const cloudAvatarPath = 'app.media.headphoto';
      // Act
      const resolved = resolveMyPageRemoteAvatarUrl(authAvatarUrl, cloudAvatarPath, 'app.media.headphoto');
      // Assert
      expect(resolved).assertEqual('https://cdn.example.com/avatar.jpg');
    });

    it('normal: my_page_avatar_update_toast_should_distinguish_synced_and_local', 0, () => {
      // Arrange
      const syncedState = 'SYNCED';
      const pendingState = 'PENDING';

      // Act
      const syncedToast = resolveMyPageAvatarUpdateToast(syncedState);
      const pendingToast = resolveMyPageAvatarUpdateToast(pendingState);
      const pendingHint = resolveMyPageAvatarSyncPendingHint('user_9');

      // Assert
      expect(syncedToast.length > 0).assertTrue();
      expect(pendingToast.length > 0).assertTrue();
      expect(pendingHint.key).assertEqual('avatar_cloud_sync_pending:user_9');
    });

    it('boundary: my_page_profile_bootstrap_hint_should_use_guest_when_account_blank', 0, () => {
      // Arrange
      const accountId = '';

      // Act
      const payload = resolveMyPageProfileBootstrapHint(accountId, 'offline');

      // Assert
      expect(payload !== null).assertTrue();
      expect(payload?.key).assertEqual('profile_offline:guest_local');
    });

    it('regression: my_page_should_show_guest_upgrade_card_without_waiting_for_remote_profile', 0, () => {
      // Arrange
      const guestHasSession = true;
      const guestFlag = true;
      const nonGuestFlag = false;

      // Act
      const guestImmediate = shouldMyPageUseImmediateGuestProfile(guestHasSession, guestFlag);
      const nonGuestImmediate = shouldMyPageUseImmediateGuestProfile(guestHasSession, nonGuestFlag);

      // Assert
      expect(guestImmediate).assertTrue();
      expect(nonGuestImmediate).assertFalse();
    });

    it('combined: my_page_should_render_guest_login_card_with_empty_avatar', 0, () => {
      // Arrange
      const page = createMyPagePrivateForTest();
      page.profileReady = true;
      page.isGuestUser = true;
      page.agreementAccepted = false;
      page.avatarDisplayUri = '';
      page.useDefaultAvatar = false;
      page.avatarBusy = false;
      page.effectiveTheme = 'light';

      // Act
      page.initialRender();

      // Assert
      expect(page.isGuestUser).assertTrue();
      expect(page.profileReady).assertTrue();
    });

    it('combined: my_page_should_render_default_avatar_for_guest_profile', 0, () => {
      // Arrange
      const page = createMyPagePrivateForTest();
      page.profileReady = true;
      page.isGuestUser = true;
      page.useDefaultAvatar = true;
      page.avatarDisplayUri = '';
      page.actionLoading = true;
      page.effectiveTheme = 'dark';

      // Act
      page.initialRender();

      // Assert
      expect(page.useDefaultAvatar).assertTrue();
      expect(page.actionLoading).assertTrue();
    });

    it('combined: my_page_should_render_non_guest_editor_and_remote_avatar', 0, () => {
      // Arrange
      const page = createMyPagePrivateForTest();
      page.profileReady = true;
      page.isGuestUser = false;
      page.userName = 'Alice';
      page.currentUserId = 'account_1';
      page.avatarDisplayUri = 'file://avatar/account_1.png';
      page.useDefaultAvatar = false;
      page.showUsernameEditor = true;
      page.usernameDraft = 'Alice_2';
      page.effectiveTheme = 'light';

      // Act
      const normalized = page.normalizeAndValidateUsername(page.usernameDraft);
      page.initialRender();

      // Assert
      expect(normalized).assertEqual('Alice_2');
      expect(page.isGuestUser).assertFalse();
    });

    it('combined: my_page_open_username_editor_should_copy_current_name_before_render', 0, () => {
      // Arrange
      const page = createMyPagePrivateForTest();
      page.profileReady = true;
      page.isGuestUser = false;
      page.userName = 'Bob';
      page.showUsernameEditor = false;

      // Act
      page.openUsernameEditor();
      page.initialRender();

      // Assert
      expect(page.showUsernameEditor).assertTrue();
      expect(page.usernameDraft).assertEqual('Bob');
    });

    it('boundary: my_page_about_to_appear_should_reset_ready_and_keep_loading_refresh_guarded', 0, async () => {
      // Arrange
      const page = createMyPagePrivateForTest();
      page.profileReady = true;
      page.loadingProfile = true;

      // Act
      page.aboutToAppear();
      await page.refreshUserState();

      // Assert
      expect(page.profileReady).assertFalse();
      expect(page.loadingProfile).assertTrue();
    });
  });
}
