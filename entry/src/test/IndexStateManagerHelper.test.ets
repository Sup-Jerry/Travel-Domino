import { describe, it, expect } from '@ohos/hypium';
import { IndexStateManager } from '../main/ets/pages/index/IndexStateManager';

export default function indexStateManagerHelperTest() {
  describe('unit_test_case_generator_autofill_IndexStateManagerHelper', () => {
    it('normal: index_state_manager_should_append_plan_id_for_scoped_key', 0, () => {
      // Arrange
      const base = 'draft_key';
      const planId = 7;
      // Act
      const scoped = IndexStateManager.scopedStorageKey(base, planId);
      // Assert
      expect(scoped).assertEqual('draft_key_7');
    });

    it('boundary: index_state_manager_should_keep_base_key_when_plan_id_is_zero', 0, () => {
      // Arrange
      const base = 'draft_key';
      // Act
      const scoped = IndexStateManager.scopedStorageKey(base, 0);
      // Assert
      expect(scoped).assertEqual('draft_key');
    });

    it('invalid: index_state_manager_day_collapsed_should_be_false_when_not_in_list', 0, () => {
      // Arrange
      const collapsed = [1, 3, 5];
      // Act
      const isCollapsed = IndexStateManager.isDayCollapsed(collapsed, 2);
      // Assert
      expect(isCollapsed).assertFalse();
    });

    it('conflict: index_state_manager_toggle_should_remove_existing_day_offset', 0, () => {
      // Arrange
      const collapsed = [1, 2, 3];
      // Act
      const next = IndexStateManager.toggleDayCollapse(collapsed, 2);
      // Assert
      expect(next.length).assertEqual(2);
      expect(next.indexOf(2)).assertEqual(-1);
    });

    it('regression: td-20260412-index_state_manager_backlog_keys_should_keep_prefix', 0, () => {
      // Arrange
      const planId = 12;
      // Act
      const expandedKey = IndexStateManager.getBacklogExpandedKey(planId);
      const initKey = IndexStateManager.getBacklogInitializedKey(planId);
      // Assert
      expect(expandedKey).assertEqual('backlog_expanded_plan_12');
      expect(initKey).assertEqual('backlog_expanded_initialized_plan_12');
    });

    it('combined: index_state_manager_toggle_should_add_missing_day_and_preserve_old_state', 0, () => {
      // Arrange
      const collapsed = [1, 3];
      // Act
      const next = IndexStateManager.toggleDayCollapse(collapsed, 2);
      // Assert
      expect(collapsed.length).assertEqual(2);
      expect(next.length).assertEqual(3);
      expect(next.indexOf(1) >= 0).assertTrue();
      expect(next.indexOf(2) >= 0).assertTrue();
      expect(next.indexOf(3) >= 0).assertTrue();
    });
  });
}

