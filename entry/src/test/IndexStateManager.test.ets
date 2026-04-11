import { describe, it, expect } from '@ohos/hypium';
import { IndexStateManager } from '../main/ets/pages/index/IndexStateManager';

export default function indexStateManagerTest() {
  describe('unit_test_case_generator_autofill_IndexStateManager', () => {
    it('normal: scoped_storage_key_should_append_plan_id_when_positive', 0, () => {
      // Arrange
      const baseKey = 'draft_key';
      // Act
      const scoped = IndexStateManager.scopedStorageKey(baseKey, 12);
      // Assert
      expect(scoped).assertEqual('draft_key_12');
    });

    it('boundary: scoped_storage_key_should_keep_base_when_plan_id_not_positive', 0, () => {
      // Arrange
      const baseKey = 'draft_key';
      // Act
      const scoped = IndexStateManager.scopedStorageKey(baseKey, 0);
      // Assert
      expect(scoped).assertEqual('draft_key');
    });

    it('invalid: is_day_collapsed_should_return_false_when_day_missing', 0, () => {
      // Arrange
      const collapsed: number[] = [0, 2, 4];
      // Act
      const isCollapsed = IndexStateManager.isDayCollapsed(collapsed, 3);
      // Assert
      expect(isCollapsed).assertFalse();
    });

    it('conflict: toggle_day_collapse_should_remove_existing_day_offset', 0, () => {
      // Arrange
      const collapsed: number[] = [1, 3, 5];
      // Act
      const next = IndexStateManager.toggleDayCollapse(collapsed, 3);
      // Assert
      expect(next.length).assertEqual(2);
      expect(next.indexOf(3)).assertEqual(-1);
    });

    it('regression: toggle_day_collapse_should_add_missing_day_offset', 0, () => {
      // Arrange
      const collapsed: number[] = [1, 2];
      // Act
      const next = IndexStateManager.toggleDayCollapse(collapsed, 4);
      // Assert
      expect(next.length).assertEqual(3);
      expect(next.indexOf(4) >= 0).assertTrue();
    });

    it('combined: backlog_storage_keys_should_remain_plan_scoped', 0, () => {
      // Arrange
      const planId = 20;
      // Act
      const expandedKey = IndexStateManager.getBacklogExpandedKey(planId);
      const initializedKey = IndexStateManager.getBacklogInitializedKey(planId);
      // Assert
      expect(expandedKey).assertContain('plan_20');
      expect(initializedKey).assertContain('plan_20');
      expect(expandedKey === initializedKey).assertFalse();
    });
  });
}
