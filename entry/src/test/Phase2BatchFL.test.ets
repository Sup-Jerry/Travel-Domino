import { describe, it, expect } from '@ohos/hypium';
import {
  normalizeMyPageUsername,
  resolveMyPageAvatarSyncPendingHint,
  resolveMyPageAvatarUpdateToast,
  resolveMyPageProfileBootstrapHint,
  resolveMyPageRemoteAvatarUrl,
  shouldMyPageEmitLightHint
} from '../main/ets/pages/MyPage';
import {
  isPlanSearchCacheFresh,
  resolvePlanSearchResultText,
  resolvePlanSearchStateColor,
  resolvePlanSearchStateLabel,
  shouldPlanSearchLoadMore
} from '../main/ets/pages/PlanSearchPage';
import {
  formatMapPickerDistance,
  isMapPickerAddressResolving,
  resolveMapPickerCenterHint,
  resolveMapPickerSelectionAddress,
  resolveMapPickerStorageKey
} from '../main/ets/pages/MapPickerPage';

export default function phase2BatchFLTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFL_my_page_helpers', () => {
    it('boundary: my_page_username_should_respect_custom_max_length', 0, () => {
      expect(normalizeMyPageUsername('Alice', 5)).assertEqual('Alice');
      expect(normalizeMyPageUsername('Alice1', 5)).assertEqual('');
    });

    it('boundary: my_page_light_hint_should_reject_blank_key_and_allow_expired_duplicate', 0, () => {
      expect(shouldMyPageEmitLightHint('profile_offline:user1', 1000, '   ', 2000, 2000)).assertFalse();
      expect(shouldMyPageEmitLightHint('profile_offline:user1', 1000, 'profile_offline:user1', 4000, 2000)).assertTrue();
    });

    it('normal: my_page_profile_bootstrap_hint_should_return_null_for_ready_state', 0, () => {
      const payload = resolveMyPageProfileBootstrapHint('user_ready', 'ready');
      expect(payload === null).assertTrue();
    });

    it('boundary: my_page_avatar_sync_pending_hint_should_fallback_to_guest_local', 0, () => {
      const payload = resolveMyPageAvatarSyncPendingHint('   ');
      expect(payload.key).assertEqual('avatar_cloud_sync_pending:guest_local');
      expect(payload.message.length > 0).assertTrue();
    });

    it('combined: my_page_remote_avatar_should_prefer_cloud_path_and_toast_should_handle_trimmed_synced_state', 0, () => {
      const remoteAvatar = resolveMyPageRemoteAvatarUrl(
        'https://auth.example/avatar.png',
        '/data/cloud/avatar.png',
        'app.media.headphoto'
      );
      const syncedToast = resolveMyPageAvatarUpdateToast('  SYNCED ');
      const localToast = resolveMyPageAvatarUpdateToast('');

      expect(remoteAvatar).assertEqual('/data/cloud/avatar.png');
      expect(syncedToast !== localToast).assertTrue();
    });
  });

  describe('unit_test_case_generator_autofill_Phase2BatchFL_plan_search_helpers', () => {
    it('normal: plan_search_state_should_return_archive_label_and_gray_color', 0, () => {
      expect(resolvePlanSearchStateLabel(2, 0)).assertEqual('\u5f52\u6863');
      expect(resolvePlanSearchStateColor(2, 0)).assertEqual('#7A8699');
    });

    it('boundary: plan_search_cache_fresh_should_accept_exact_ttl_and_reject_invalid_now', 0, () => {
      expect(isPlanSearchCacheFresh(1000, 4000, 3000)).assertTrue();
      expect(isPlanSearchCacheFresh(1000, Number.NaN, 3000)).assertFalse();
    });

    it('boundary: plan_search_result_text_should_floor_decimal_count_and_fallback_zero', 0, () => {
      const loadingText = resolvePlanSearchResultText(false, true, 8.9);
      const fallbackText = resolvePlanSearchResultText(false, false, Number.NaN);

      expect(loadingText.indexOf('8') >= 0).assertTrue();
      expect(fallbackText.indexOf('0') >= 0).assertTrue();
    });

    it('combined: plan_search_load_more_should_stay_blocked_when_any_runtime_guard_is_false', 0, () => {
      expect(shouldPlanSearchLoadMore(true, false, false, true)).assertTrue();
      expect(shouldPlanSearchLoadMore(true, true, false, true)).assertFalse();
      expect(shouldPlanSearchLoadMore(true, false, true, true)).assertFalse();
      expect(shouldPlanSearchLoadMore(true, false, false, false)).assertFalse();
    });
  });

  describe('unit_test_case_generator_autofill_Phase2BatchFL_map_picker_helpers', () => {
    it('normal: map_picker_center_hint_should_cover_existing_and_current_sources', 0, () => {
      const existingHint = resolveMapPickerCenterHint('existing', '');
      const currentHint = resolveMapPickerCenterHint('', '');

      expect(existingHint.length > 0).assertTrue();
      expect(currentHint.length > 0).assertTrue();
      expect(existingHint === currentHint).assertFalse();
    });

    it('boundary: map_picker_selection_address_should_fallback_for_unknown_or_blank_address', 0, () => {
      const unknownAddress = resolveMapPickerSelectionAddress('\u672a\u77e5\u5750\u6807\u70b9', 31.2304, 121.4737);
      const blankAddress = resolveMapPickerSelectionAddress('   ', 30.2741, 120.1551);

      expect(unknownAddress.indexOf('31.23040') >= 0).assertTrue();
      expect(blankAddress.indexOf('30.27410') >= 0).assertTrue();
    });

    it('normal: map_picker_selection_address_should_keep_custom_address', 0, () => {
      const address = resolveMapPickerSelectionAddress('West Lake Scenic Area', 30.0, 120.0);
      expect(address).assertEqual('West Lake Scenic Area');
    });

    it('boundary: map_picker_storage_key_should_floor_positive_plan_id_and_fallback_for_zero', 0, () => {
      expect(resolveMapPickerStorageKey(9.8)).assertEqual('pickedLocationStr_9');
      expect(resolveMapPickerStorageKey(0)).assertEqual('pickedLocationStr');
    });

    it('combined: map_picker_address_resolving_and_distance_should_handle_ready_text_and_kilometer_value', 0, () => {
      expect(isMapPickerAddressResolving('Hangzhou Xihu District')).assertFalse();
      expect(formatMapPickerDistance(1520)).assertEqual('1.5km');
    });
  });
}
