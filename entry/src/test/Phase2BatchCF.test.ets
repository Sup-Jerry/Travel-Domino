import { describe, expect, it } from '@ohos/hypium';
import {
  createMyPageForTest,
  normalizeMyPageLightHintKey,
  normalizeMyPageUsername,
  resolveMyPageAvatarSyncPendingHint,
  resolveMyPageAvatarUpdateToast,
  resolveMyPageRemoteAvatarUrl,
  resolveMyPageProfileBootstrapHint,
  shouldMyPageEmitLightHint,
  shouldMyPageUseImmediateGuestProfile
} from '../main/ets/pages/MyPage';

interface MyPagePrivateCF {
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
  initialRender(): void;
  getThemePalette(): Object;
  normalizeAndValidateUsername(rawValue: string): string;
  openUsernameEditor(): void;
}

function createMyPageCF(): MyPagePrivateCF {
  return createMyPageForTest() as MyPagePrivateCF;
}

export default function phase2BatchCFTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCF_my_page_extra', () => {
    it('normal: my_page_username_should_accept_exact_custom_max_length', 0, () => {
      // Arrange
      const input = 'User_2026';

      // Act
      const username = normalizeMyPageUsername(input, 9);

      // Assert
      expect(username).assertEqual('User_2026');
    });

    it('boundary: my_page_username_should_reject_when_custom_max_length_is_exceeded_after_trim', 0, () => {
      // Arrange
      const input = '  User_2026  ';

      // Act
      const username = normalizeMyPageUsername(input, 8);

      // Assert
      expect(username).assertEqual('');
    });

    it('invalid: my_page_username_should_reject_blank_and_hyphen_input', 0, () => {
      // Arrange
      const blankInput = '   ';
      const hyphenInput = 'User-2026';

      // Act
      const blankUsername = normalizeMyPageUsername(blankInput);
      const hyphenUsername = normalizeMyPageUsername(hyphenInput);

      // Assert
      expect(blankUsername).assertEqual('');
      expect(hyphenUsername).assertEqual('');
    });

    it('conflict: my_page_light_hint_should_allow_same_key_at_dedup_boundary', 0, () => {
      // Arrange
      const key = 'profile_cloud_fail:user_cf';

      // Act
      const shouldEmit = shouldMyPageEmitLightHint(key, 1000, key, 13000, 12000);

      // Assert
      expect(shouldEmit).assertTrue();
    });

    it('regression: my_page_light_hint_should_reject_empty_key_after_normalization', 0, () => {
      // Arrange
      const rawKey = '   ';

      // Act
      const normalized = normalizeMyPageLightHintKey(rawKey);
      const shouldEmit = shouldMyPageEmitLightHint('', 0, normalized, 1000, 12000);

      // Assert
      expect(normalized).assertEqual('');
      expect(shouldEmit).assertFalse();
    });

    it('normal: my_page_remote_avatar_should_prefer_trimmed_cloud_path_over_auth_avatar', 0, () => {
      // Arrange
      const authAvatarUrl = 'https://cdn.example.com/auth.jpg';
      const cloudAvatarPath = '  file://cloud/avatar_cf.png  ';

      // Act
      const resolved = resolveMyPageRemoteAvatarUrl(authAvatarUrl, cloudAvatarPath, 'app.media.headphoto');

      // Assert
      expect(resolved).assertEqual('file://cloud/avatar_cf.png');
    });

    it('boundary: my_page_remote_avatar_should_trim_auth_url_when_cloud_is_default_or_empty', 0, () => {
      // Arrange
      const authAvatarUrl = '  https://cdn.example.com/auth_cf.jpg  ';

      // Act
      const defaultCloud = resolveMyPageRemoteAvatarUrl(authAvatarUrl, 'app.media.headphoto', 'app.media.headphoto');
      const emptyCloud = resolveMyPageRemoteAvatarUrl(authAvatarUrl, '   ', 'app.media.headphoto');

      // Assert
      expect(defaultCloud).assertEqual('https://cdn.example.com/auth_cf.jpg');
      expect(emptyCloud).assertEqual('https://cdn.example.com/auth_cf.jpg');
    });

    it('combined: my_page_profile_and_avatar_hints_should_fallback_to_guest_local_for_blank_ids', 0, () => {
      // Arrange
      const blankAccountId = '   ';
      const blankUserId = '';

      // Act
      const offlineHint = resolveMyPageProfileBootstrapHint(blankAccountId, 'offline');
      const avatarHint = resolveMyPageAvatarSyncPendingHint(blankUserId);

      // Assert
      expect(offlineHint !== null).assertTrue();
      expect(offlineHint?.key).assertEqual('profile_offline:guest_local');
      expect(avatarHint.key).assertEqual('avatar_cloud_sync_pending:guest_local');
    });

    it('boundary: my_page_profile_bootstrap_hint_should_return_null_for_ready_state', 0, () => {
      // Arrange
      const accountId = 'account_cf_ready';

      // Act
      const hint = resolveMyPageProfileBootstrapHint(accountId, 'ready');

      // Assert
      expect(hint === null).assertTrue();
    });

    it('normal: my_page_avatar_update_toast_should_distinguish_synced_and_local_states', 0, () => {
      // Arrange
      const syncedState = 'SYNCED';
      const pendingState = 'PENDING';

      // Act
      const syncedToast = resolveMyPageAvatarUpdateToast(syncedState);
      const pendingToast = resolveMyPageAvatarUpdateToast(pendingState);
      const blankToast = resolveMyPageAvatarUpdateToast('   ');

      // Assert
      expect(syncedToast.length > 0).assertTrue();
      expect(pendingToast.length > 0).assertTrue();
      expect(blankToast).assertEqual(pendingToast);
      expect(syncedToast === pendingToast).assertFalse();
    });

    it('conflict: my_page_light_hint_should_dedupe_same_key_before_boundary', 0, () => {
      // Arrange
      const key = 'avatar_cloud_sync_pending:account_cf';

      // Act
      const beforeBoundary = shouldMyPageEmitLightHint(key, 1000, ` ${key} `, 12999, 12000);
      const differentKey = shouldMyPageEmitLightHint(key, 1000, 'profile_cloud_fail:account_cf', 1001, 12000);

      // Assert
      expect(beforeBoundary).assertFalse();
      expect(differentKey).assertTrue();
    });

    it('invalid: my_page_remote_avatar_should_return_empty_when_all_sources_empty_or_default', 0, () => {
      // Arrange
      const defaultAvatarPath = 'app.media.headphoto';

      // Act
      const resolved = resolveMyPageRemoteAvatarUrl('   ', defaultAvatarPath, defaultAvatarPath);

      // Assert
      expect(resolved).assertEqual('');
    });

    it('regression: my_page_guest_immediate_profile_should_require_session_and_guest_flag', 0, () => {
      // Arrange
      const noSession = false;
      const hasSession = true;

      // Act
      const missingSession = shouldMyPageUseImmediateGuestProfile(noSession, true);
      const nonGuestSession = shouldMyPageUseImmediateGuestProfile(hasSession, false);
      const guestSession = shouldMyPageUseImmediateGuestProfile(hasSession, true);

      // Assert
      expect(missingSession).assertFalse();
      expect(nonGuestSession).assertFalse();
      expect(guestSession).assertTrue();
    });

    it('combined: my_page_should_render_non_guest_busy_editor_with_remote_avatar', 0, () => {
      // Arrange
      const page = createMyPageCF();
      page.profileReady = true;
      page.isGuestUser = false;
      page.userName = 'Carol';
      page.currentUserId = 'account_cf';
      page.avatarDisplayUri = 'file://avatar/account_cf.png';
      page.useDefaultAvatar = false;
      page.showUsernameEditor = true;
      page.usernameDraft = 'Carol_2';
      page.avatarBusy = true;
      page.effectiveTheme = 'dark';

      // Act
      const normalized = page.normalizeAndValidateUsername(page.usernameDraft);
      const palette = page.getThemePalette();
      page.initialRender();

      // Assert
      expect(normalized).assertEqual('Carol_2');
      expect(palette !== null).assertTrue();
      expect(page.avatarBusy).assertTrue();
      expect(page.isGuestUser).assertFalse();
    });

    it('combined: my_page_should_render_loading_guest_empty_avatar_state', 0, () => {
      // Arrange
      const page = createMyPageCF();
      page.profileReady = false;
      page.loadingProfile = true;
      page.actionLoading = true;
      page.isGuestUser = true;
      page.avatarDisplayUri = '';
      page.useDefaultAvatar = false;
      page.avatarBusy = false;
      page.effectiveTheme = 'light';

      // Act
      page.initialRender();

      // Assert
      expect(page.loadingProfile).assertTrue();
      expect(page.actionLoading).assertTrue();
      expect(page.isGuestUser).assertTrue();
    });

    it('combined: my_page_open_username_editor_should_copy_name_and_keep_theme_palette_available', 0, () => {
      // Arrange
      const page = createMyPageCF();
      page.profileReady = true;
      page.isGuestUser = false;
      page.userName = 'Dana';
      page.showUsernameEditor = false;
      page.effectiveTheme = 'light';

      // Act
      page.openUsernameEditor();
      const palette = page.getThemePalette();
      page.initialRender();

      // Assert
      expect(page.showUsernameEditor).assertTrue();
      expect(page.usernameDraft).assertEqual('Dana');
      expect(palette !== null).assertTrue();
    });
  });
}
