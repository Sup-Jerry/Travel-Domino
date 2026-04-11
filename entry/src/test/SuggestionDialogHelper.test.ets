import { describe, it, expect } from '@ohos/hypium';
import {
  getSuggestionApplyButtonLabel,
  shouldShowSuggestionSummary
} from '../main/ets/pages/components/dialogs/SuggestionDialog';

export default function suggestionDialogHelperTest() {
  describe('unit_test_case_generator_autofill_SuggestionDialogHelper', () => {
    it('normal: suggestion_dialog_should_show_summary_when_non_empty', 0, () => {
      // Arrange
      const summaryText = 'plan adjust 10:30';
      // Act
      const show = shouldShowSuggestionSummary(summaryText);
      // Assert
      expect(show).assertTrue();
    });

    it('boundary: suggestion_dialog_should_hide_summary_when_spaces_only', 0, () => {
      // Arrange
      const summaryText = '   ';
      // Act
      const show = shouldShowSuggestionSummary(summaryText);
      // Assert
      expect(show).assertFalse();
    });

    it('invalid: suggestion_dialog_should_hide_summary_when_empty', 0, () => {
      // Arrange
      const summaryText = '';
      // Act
      const show = shouldShowSuggestionSummary(summaryText);
      // Assert
      expect(show).assertFalse();
    });

    it('conflict: suggestion_dialog_apply_label_should_be_non_empty', 0, () => {
      // Arrange
      // Act
      const label = getSuggestionApplyButtonLabel();
      // Assert
      expect(label.length > 0).assertTrue();
    });

    it('regression: td-20260412-suggestion-summary-trim-should-stay-enabled', 0, () => {
      // Arrange
      const summaryText = '  executable  ';
      // Act
      const show = shouldShowSuggestionSummary(summaryText);
      // Assert
      expect(show).assertTrue();
    });

    it('combined: suggestion_dialog_label_and_summary_decision_should_be_independent', 0, () => {
      // Arrange
      const summaryText = '';
      // Act
      const labelA = getSuggestionApplyButtonLabel();
      const labelB = getSuggestionApplyButtonLabel();
      const show = shouldShowSuggestionSummary(summaryText);
      // Assert
      expect(labelA).assertEqual(labelB);
      expect(show).assertFalse();
    });
  });
}
