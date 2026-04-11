import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionFilterState,
  getCompanionFilterBorderType,
  getCompanionFilterBorderWidth,
  isCompanionFilterSelected,
  shouldShowCompanionFilterPage
} from '../main/ets/pages/components/views/companion/CompanionFilterPage';

export default function companionFilterPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionFilterPageHelper', () => {
    it('normal: filter_page_should_follow_show_flag', 0, () => {
      // Arrange
      const show = true;

      // Act
      const visible = shouldShowCompanionFilterPage(show);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: border_width_should_be_one_for_selected_item', 0, () => {
      // Arrange
      const item: CompanionFilterState = 'ACTIVE';
      const current: CompanionFilterState = 'ACTIVE';

      // Act
      const width = getCompanionFilterBorderWidth(item, current);

      // Assert
      expect(width).assertEqual(1);
    });

    it('invalid: border_type_should_fallback_to_default_for_all', 0, () => {
      // Arrange
      const item: CompanionFilterState = 'ALL';

      // Act
      const borderType = getCompanionFilterBorderType(item);

      // Assert
      expect(borderType).assertEqual('default');
    });

    it('conflict: selected_state_should_be_false_when_item_and_current_mismatch', 0, () => {
      // Arrange
      const item: CompanionFilterState = 'PENDING';
      const current: CompanionFilterState = 'COMPLETED';

      // Act
      const selected = isCompanionFilterSelected(item, current);

      // Assert
      expect(selected).assertFalse();
    });

    it('regression: border_type_mapping_should_keep_pending_completed_skipped_semantics', 0, () => {
      // Arrange
      const pending: CompanionFilterState = 'PENDING';
      const completed: CompanionFilterState = 'COMPLETED';
      const skipped: CompanionFilterState = 'SKIPPED';

      // Act
      const pendingType = getCompanionFilterBorderType(pending);
      const completedType = getCompanionFilterBorderType(completed);
      const skippedType = getCompanionFilterBorderType(skipped);

      // Assert
      expect(pendingType).assertEqual('pending');
      expect(completedType).assertEqual('completed');
      expect(skippedType).assertEqual('skipped');
    });

    it('combined: width_and_selection_matrix_should_be_consistent_for_options', 0, () => {
      // Arrange
      const current: CompanionFilterState = 'SKIPPED';
      const options: CompanionFilterState[] = ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];

      // Act
      const selectedCount = options.filter((item) => isCompanionFilterSelected(item, current)).length;
      const selectedWidth = getCompanionFilterBorderWidth('SKIPPED', current);
      const unselectedWidth = getCompanionFilterBorderWidth('ACTIVE', current);

      // Assert
      expect(selectedCount).assertEqual(1);
      expect(selectedWidth).assertEqual(1);
      expect(unselectedWidth).assertEqual(0);
    });
  });
}
