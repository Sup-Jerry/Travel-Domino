import { describe, it, expect } from '@ohos/hypium';
import {
  getSuggestionApplyButtonLabel,
  getSuggestionBackButtonLabel,
  SuggestionDialog,
  shouldShowSuggestionSummary
} from '../main/ets/pages/components/dialogs/SuggestionDialog';

class DialogControllerMockSuggestion {
  close(): void {
  }
}

interface SuggestionDialogPrivateTest {
  controller?: DialogControllerMockSuggestion;
  itemName: string;
  conflictName: string;
  targetTime: string;
  suggestedTime: string;
  detailMsg: string;
  summaryText: string;
  initialRender(): void;
  setController(controller: DialogControllerMockSuggestion): void;
}

export default function suggestionDialogHelperTest() {
  describe('unit_test_case_generator_autofill_SuggestionDialogHelper', () => {
    it('combined: suggestion_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new SuggestionDialog(undefined, {} as LocalStorage) as Object as SuggestionDialogPrivateTest;
      const first = new DialogControllerMockSuggestion();
      const second = new DialogControllerMockSuggestion();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

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
    it('normal: suggestion_dialog_back_label_should_stay_non_empty', 0, () => {
      // Arrange
      // Act
      const label = getSuggestionBackButtonLabel();
      // Assert
      expect(label.length > 0).assertTrue();
    });

    it('combined: suggestion_dialog_initial_render_should_support_summary_branch', 0, () => {
      // Arrange
      const page = new SuggestionDialog(undefined, {} as LocalStorage) as Object as SuggestionDialogPrivateTest;
      let threw = false;

      // Act
      page.itemName = 'museum';
      page.conflictName = 'breakfast';
      page.targetTime = '10:00';
      page.suggestedTime = '10:30';
      page.detailMsg = 'delay preview';
      page.summaryText = 'summary preview';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: suggestion_dialog_initial_render_should_support_generated_text_branch', 0, () => {
      // Arrange
      const page = new SuggestionDialog(undefined, {} as LocalStorage) as Object as SuggestionDialogPrivateTest;
      let threw = false;

      // Act
      page.itemName = 'museum';
      page.conflictName = 'breakfast';
      page.targetTime = '10:00';
      page.suggestedTime = '10:30';
      page.detailMsg = 'detail preview';
      page.summaryText = '';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}
