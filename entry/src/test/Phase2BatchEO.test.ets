import { describe, expect, it } from '@ohos/hypium';
import {
  DateFilterDialog,
  getDateFilterDialogActions,
  getDateFilterDialogOptions,
  isDateFilterDialogActionSupported
} from '../main/ets/pages/components/dialogs/DateFilterDialog';

interface DateFilterDialogPrivateEO {
  initialRender(): void;
}

export default function phase2BatchEOTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEO_date_filter_dialog_extra', () => {
    it('normal: date_filter_options_should_keep_actions_in_same_order_as_action_list', 0, () => {
      // Arrange
      const actions = getDateFilterDialogActions();

      // Act
      const options = getDateFilterDialogOptions();

      // Assert
      expect(options.length).assertEqual(actions.length);
      expect(options[0].action).assertEqual(actions[0]);
      expect(options[1].action).assertEqual(actions[1]);
      expect(options[2].action).assertEqual(actions[2]);
    });

    it('boundary: date_filter_options_should_keep_non_empty_titles_and_descriptions', 0, () => {
      // Arrange
      // Act
      const options = getDateFilterDialogOptions();
      const allReady = options.every((option) => option.title.trim().length > 0 && option.description.trim().length > 0);

      // Assert
      expect(allReady).assertTrue();
    });

    it('invalid: date_filter_supported_check_should_reject_case_changed_and_blank_actions', 0, () => {
      // Arrange
      const upper = 'SHOW_ALL';
      const blank = ' ';

      // Act
      const upperSupported = isDateFilterDialogActionSupported(upper);
      const blankSupported = isDateFilterDialogActionSupported(blank);

      // Assert
      expect(upperSupported).assertFalse();
      expect(blankSupported).assertFalse();
    });

    it('conflict: date_filter_actions_should_distinguish_single_date_and_range_actions', 0, () => {
      // Arrange
      const selectDate = 'select_date';
      const selectRange = 'select_range';

      // Act
      const dateSupported = isDateFilterDialogActionSupported(selectDate);
      const rangeSupported = isDateFilterDialogActionSupported(selectRange);

      // Assert
      expect(dateSupported).assertTrue();
      expect(rangeSupported).assertTrue();
      expect(selectDate === selectRange).assertFalse();
    });

    it('regression: date_filter_action_list_should_keep_show_all_first_and_range_last', 0, () => {
      // Arrange
      // Act
      const actions = getDateFilterDialogActions();

      // Assert
      expect(actions[0]).assertEqual('show_all');
      expect(actions[actions.length - 1]).assertEqual('select_range');
    });

    it('combined: date_filter_dialog_should_render_without_throwing_for_all_actions_layout', 0, () => {
      // Arrange
      const page = new DateFilterDialog(undefined, {} as LocalStorage) as Object as DateFilterDialogPrivateEO;
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(getDateFilterDialogActions().length).assertEqual(3);
    });
  });
}
