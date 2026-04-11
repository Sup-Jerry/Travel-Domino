import { describe, it, expect } from '@ohos/hypium';
import {
  getDateFilterDialogActions,
  isDateFilterDialogActionSupported
} from '../main/ets/pages/components/dialogs/DateFilterDialog';

export default function dateFilterDialogHelperTest() {
  describe('unit_test_case_generator_autofill_DateFilterDialogHelper', () => {
    it('normal: date_filter_actions_should_include_show_all', 0, () => {
      // Arrange
      // Act
      const actions = getDateFilterDialogActions();
      // Assert
      expect(actions.indexOf('show_all') >= 0).assertTrue();
    });

    it('boundary: date_filter_actions_should_keep_three_entries', 0, () => {
      // Arrange
      // Act
      const actions = getDateFilterDialogActions();
      // Assert
      expect(actions.length).assertEqual(3);
    });

    it('invalid: date_filter_should_reject_unknown_action', 0, () => {
      // Arrange
      const action = 'invalid_action';
      // Act
      const supported = isDateFilterDialogActionSupported(action);
      // Assert
      expect(supported).assertFalse();
    });

    it('conflict: date_filter_should_recognize_select_range_action', 0, () => {
      // Arrange
      const action = 'select_range';
      // Act
      const supported = isDateFilterDialogActionSupported(action);
      // Assert
      expect(supported).assertTrue();
    });

    it('regression: td-20260412-date-filter-order-should-stay-stable', 0, () => {
      // Arrange
      // Act
      const actions = getDateFilterDialogActions();
      // Assert
      expect(actions[0]).assertEqual('show_all');
      expect(actions[1]).assertEqual('select_date');
      expect(actions[2]).assertEqual('select_range');
    });

    it('combined: date_filter_supported_check_should_match_action_list', 0, () => {
      // Arrange
      const actions = getDateFilterDialogActions();
      // Act
      const allSupported = actions.every((action: string) => isDateFilterDialogActionSupported(action));
      // Assert
      expect(allSupported).assertTrue();
    });
  });
}
