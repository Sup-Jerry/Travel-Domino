import { describe, expect, it } from '@ohos/hypium';
import { IndexStateManager } from '../main/ets/pages/index/IndexStateManager';

export default function phase2BatchHFTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHF_index_state_manager_clear_storage', () => {
    it('combined: index_state_manager_should_clear_scoped_and_global_dialog_storage_for_positive_plan', 0, () => {
      const planId = 401;
      const tempKey = 'phase2_hf_temp';
      const pickedKey = 'phase2_hf_picked';
      const scopedTempKey = IndexStateManager.scopedStorageKey(tempKey, planId);
      const scopedPickedKey = IndexStateManager.scopedStorageKey(pickedKey, planId);

      AppStorage.setOrCreate(scopedTempKey, 'scoped_temp');
      AppStorage.setOrCreate(scopedPickedKey, 'scoped_picked');
      AppStorage.setOrCreate(tempKey, 'global_temp');
      AppStorage.setOrCreate(pickedKey, 'global_picked');

      IndexStateManager.clearDialogDraftStorage(planId, tempKey, pickedKey);

      expect(AppStorage.get<string>(scopedTempKey)).assertEqual('');
      expect(AppStorage.get<string>(scopedPickedKey)).assertEqual('');
      expect(AppStorage.get<string>(tempKey)).assertEqual('');
      expect(AppStorage.get<string>(pickedKey)).assertEqual('');
    });

    it('combined: index_state_manager_should_clear_base_keys_when_plan_id_is_non_positive', 0, () => {
      const planId = 0;
      const tempKey = 'phase2_hf_temp_zero';
      const pickedKey = 'phase2_hf_picked_zero';

      AppStorage.setOrCreate(tempKey, 'temp_value');
      AppStorage.setOrCreate(pickedKey, 'picked_value');

      IndexStateManager.clearDialogDraftStorage(planId, tempKey, pickedKey);

      expect(AppStorage.get<string>(tempKey)).assertEqual('');
      expect(AppStorage.get<string>(pickedKey)).assertEqual('');
    });

    it('combined: index_state_manager_should_toggle_duplicate_day_offset_by_removing_only_one_match_path', 0, () => {
      const collapsed = [2, 2, 5];

      const next = IndexStateManager.toggleDayCollapse(collapsed, 2);

      expect(next.length).assertEqual(2);
      expect(next[0]).assertEqual(2);
      expect(next[1]).assertEqual(5);
      expect(collapsed.length).assertEqual(3);
    });
  });
}
