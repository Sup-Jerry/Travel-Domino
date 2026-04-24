import { describe, expect, it } from '@ohos/hypium';
import {
  isAddItemCoordinateValid,
  isAddItemMapPickerEnabled,
  resolveAddItemDuration,
  resolveAddItemMode,
  resolveAddItemScopedStorageKey
} from '../main/ets/pages/components/dialogs/AddItemDialog';
import {
  canCreatePlanWithTitle,
  formatCreatePlanDateText
} from '../main/ets/pages/components/dialogs/CreatePlanDialog';
import {
  canStartPlanImport,
  classifyPlanImportPayload
} from '../main/ets/pages/components/dialogs/PlanImportDialog';
import {
  normalizeMyPageLightHintKey,
  normalizeMyPageUsername,
  resolveMyPageAvatarSyncPendingHint,
  resolveMyPageAvatarUpdateToast,
  resolveMyPageRemoteAvatarUrl,
  resolveMyPageProfileBootstrapHint,
  shouldMyPageEmitLightHint,
  shouldMyPageUseImmediateGuestProfile
} from '../main/ets/pages/MyPage';

export default function phase2BatchGHTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGH_dialogs_and_my_page_branches', () => {
    it('combined: my_page_should_cover_custom_length_blank_hint_key_and_expired_dedup_cases', 0, () => {
      expect(normalizeMyPageUsername('ABCDE', 5)).assertEqual('ABCDE');
      expect(normalizeMyPageUsername('ABCDEF', 5)).assertEqual('');
      expect(normalizeMyPageLightHintKey('   ')).assertEqual('');
      expect(shouldMyPageEmitLightHint('profile_offline:user1', 1000, 'profile_offline:user1', 15050, 12000)).assertTrue();
      expect(shouldMyPageEmitLightHint('profile_offline:user1', 1000, '   ', 2000, 12000)).assertFalse();
    });

    it('combined: my_page_should_cover_ready_state_avatar_fallbacks_and_guest_combinations', 0, () => {
      const syncedToast = resolveMyPageAvatarUpdateToast('  SYNCED  ');
      const localToast = resolveMyPageAvatarUpdateToast('');
      expect(resolveMyPageProfileBootstrapHint('user_1', 'ready')).assertEqual(null);
      expect(resolveMyPageRemoteAvatarUrl('', 'cloud/avatar.png', 'app.media.headphoto')).assertEqual('cloud/avatar.png');
      expect(resolveMyPageRemoteAvatarUrl('https://avatar/auth.png', 'app.media.headphoto', 'app.media.headphoto')).assertEqual('https://avatar/auth.png');
      expect(resolveMyPageAvatarSyncPendingHint('').key).assertEqual('avatar_cloud_sync_pending:guest_local');
      expect(shouldMyPageUseImmediateGuestProfile(false, true)).assertFalse();
      expect(shouldMyPageUseImmediateGuestProfile(true, false)).assertFalse();
      expect(syncedToast.length > 0).assertTrue();
      expect(localToast.length > 0).assertTrue();
      expect(syncedToast !== localToast).assertTrue();
    });

    it('combined: add_item_should_cover_duration_mode_coordinate_and_storage_fallback_edges', 0, () => {
      expect(resolveAddItemMode('   ', true)).assertEqual(1);
      expect(resolveAddItemDuration(15, 30)).assertEqual(15);
      expect(resolveAddItemDuration(-1, -5)).assertEqual(60);
      expect(isAddItemCoordinateValid(-90, 180)).assertTrue();
      expect(isAddItemCoordinateValid(90.1, 180)).assertFalse();
      expect(resolveAddItemScopedStorageKey('pickedLocation', -1)).assertEqual('pickedLocation');
      expect(isAddItemMapPickerEnabled('')).assertFalse();
    });

    it('combined: plan_import_should_cover_trimmed_plain_payload_and_empty_start_guard', 0, () => {
      expect(classifyPlanImportPayload('  {"schemaVersion":1}  ')).assertEqual('plain');
      expect(classifyPlanImportPayload('  travelapp://import?data=abc  ')).assertEqual('deep_link');
      expect(classifyPlanImportPayload('\n{"v":1,"p":"abc"}\n')).assertEqual('compressed');
      expect(canStartPlanImport('   ')).assertFalse();
      expect(canStartPlanImport('  {"schemaVersion":1}  ')).assertTrue();
    });

    it('combined: create_plan_should_cover_trimmed_titles_and_date_boundaries', 0, () => {
      expect(canCreatePlanWithTitle('  Weekend Plan  ')).assertTrue();
      expect(canCreatePlanWithTitle('')).assertFalse();
      expect(formatCreatePlanDateText(new Date(2024, 1, 29))).assertEqual('2024/2/29');
      expect(formatCreatePlanDateText(new Date(2026, 0, 1))).assertEqual('2026/1/1');
    });
  });
}

