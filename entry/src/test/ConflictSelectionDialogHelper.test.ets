import { describe, it, expect } from '@ohos/hypium';
import {
  ConflictSelectionDialog,
  getConflictSelectionGapPrompt,
  shouldUseConflictAdvanceAdjust
} from '../main/ets/pages/components/dialogs/ConflictSelectionDialog';

class DialogControllerMockConflictSelection {
  close(): void {
  }
}

interface ConflictSelectionDialogPrivateTest {
  controller?: DialogControllerMockConflictSelection;
  gapMinutes: number;
  initialRender(): void;
  setController(controller: DialogControllerMockConflictSelection): void;
}

export default function conflictSelectionDialogHelperTest() {
  describe('unit_test_case_generator_autofill_ConflictSelectionDialogHelper', () => {
    it('combined: conflict_selection_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new ConflictSelectionDialog(undefined, {} as LocalStorage) as Object as ConflictSelectionDialogPrivateTest;
      const first = new DialogControllerMockConflictSelection();
      const second = new DialogControllerMockConflictSelection();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('normal: conflict_selection_gap_prompt_should_include_minutes', 0, () => {
      // Arrange
      const gapMinutes = 25;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      // Assert
      expect(prompt.indexOf('25') >= 0).assertTrue();
    });

    it('boundary: conflict_selection_gap_prompt_should_support_zero_gap', 0, () => {
      // Arrange
      const gapMinutes = 0;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      // Assert
      expect(prompt.indexOf('0') >= 0).assertTrue();
    });

    it('invalid: conflict_selection_should_not_use_advance_when_callback_missing', 0, () => {
      // Arrange
      const hasAdvanceAdjust = false;
      // Act
      const useAdvance = shouldUseConflictAdvanceAdjust(hasAdvanceAdjust);
      // Assert
      expect(useAdvance).assertFalse();
    });

    it('conflict: conflict_selection_should_use_advance_when_callback_present', 0, () => {
      // Arrange
      const hasAdvanceAdjust = true;
      // Act
      const useAdvance = shouldUseConflictAdvanceAdjust(hasAdvanceAdjust);
      // Assert
      expect(useAdvance).assertTrue();
    });

    it('regression: td-20260412-conflict-selection-prompt-should-change-with-gap', 0, () => {
      // Arrange
      const gapMinutesA = 10;
      const gapMinutesB = 11;
      // Act
      const promptA = getConflictSelectionGapPrompt(gapMinutesA);
      const promptB = getConflictSelectionGapPrompt(gapMinutesB);
      // Assert
      expect(promptA.indexOf('10') >= 0).assertTrue();
      expect(promptB.indexOf('11') >= 0).assertTrue();
      expect(promptA === promptB).assertFalse();
    });

    it('combined: conflict_selection_prompt_and_advance_flag_should_be_consistent', 0, () => {
      // Arrange
      const gapMinutes = 12;
      const hasAdvanceAdjust = true;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      const useAdvance = shouldUseConflictAdvanceAdjust(hasAdvanceAdjust);
      // Assert
      expect(prompt.indexOf('12') >= 0).assertTrue();
      expect(useAdvance).assertTrue();
    });
    it('normal: conflict_selection_dialog_initial_render_should_support_three_resolution_options', 0, () => {
      // Arrange
      const page = new ConflictSelectionDialog(undefined, {} as LocalStorage) as Object as ConflictSelectionDialogPrivateTest;
      let threw = false;

      // Act
      page.gapMinutes = 25;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: conflict_selection_gap_prompt_should_preserve_negative_gap_value', 0, () => {
      // Arrange
      const gapMinutes = -5;
      // Act
      const prompt = getConflictSelectionGapPrompt(gapMinutes);
      // Assert
      expect(prompt.indexOf('-5') >= 0).assertTrue();
    });

    it('combined: conflict_selection_advance_flag_should_be_direct_boolean_passthrough', 0, () => {
      // Arrange
      const enabled = true;
      const disabled = false;
      // Act
      const useEnabled = shouldUseConflictAdvanceAdjust(enabled);
      const useDisabled = shouldUseConflictAdvanceAdjust(disabled);
      // Assert
      expect(useEnabled).assertTrue();
      expect(useDisabled).assertFalse();
    });

    it('combined: conflict_selection_dialog_initial_render_should_support_zero_and_negative_gap_matrix', 0, () => {
      // Arrange
      const page = new ConflictSelectionDialog(undefined, {} as LocalStorage) as Object as ConflictSelectionDialogPrivateTest;
      let threw = false;

      // Act
      try {
        page.gapMinutes = 0;
        page.initialRender();
        page.gapMinutes = -15;
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: conflict_selection_dialog_initial_render_should_support_large_gap_and_controller_replacement_matrix', 0, () => {
      // Arrange
      const page = new ConflictSelectionDialog(undefined, {} as LocalStorage) as Object as ConflictSelectionDialogPrivateTest;
      const controller = new DialogControllerMockConflictSelection();
      let threw = false;

      // Act
      page.setController(controller);
      page.gapMinutes = 180;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const prompt = getConflictSelectionGapPrompt(page.gapMinutes);

      // Assert
      expect(threw).assertFalse();
      expect(page.controller === controller).assertTrue();
      expect(prompt.indexOf('180') >= 0).assertTrue();
      expect(shouldUseConflictAdvanceAdjust(true)).assertTrue();
    });
  });
}
