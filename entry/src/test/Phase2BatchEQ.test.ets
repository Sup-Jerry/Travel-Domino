import { describe, expect, it } from '@ohos/hypium';
import {
  TipDialog,
  shouldPersistTipDialogChoice,
  toggleTipDialogChecked
} from '../main/ets/pages/components/dialogs/TipDialog';

interface TipDialogPrivateEQ {
  title: string;
  message: string;
  storageKey: string;
  isChecked: boolean;
  onConfirm: () => void;
  initialRender(): void;
}

export default function phase2BatchEQTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEQ_tip_dialog_extra', () => {
    it('normal: tip_dialog_toggle_should_flip_false_true_false_over_two_steps', 0, () => {
      // Arrange
      const start = false;

      // Act
      const first = toggleTipDialogChecked(start);
      const second = toggleTipDialogChecked(first);

      // Assert
      expect(first).assertTrue();
      expect(second).assertFalse();
    });

    it('boundary: tip_dialog_persist_should_track_checked_boolean_exactly', 0, () => {
      // Arrange
      const checked = true;
      const unchecked = false;

      // Act
      const checkedPersist = shouldPersistTipDialogChoice(checked);
      const uncheckedPersist = shouldPersistTipDialogChoice(unchecked);

      // Assert
      expect(checkedPersist).assertTrue();
      expect(uncheckedPersist).assertFalse();
    });

    it('invalid: tip_dialog_double_toggle_should_restore_original_state_for_both_booleans', 0, () => {
      // Arrange
      const trueStart = true;
      const falseStart = false;

      // Act
      const trueEnd = toggleTipDialogChecked(toggleTipDialogChecked(trueStart));
      const falseEnd = toggleTipDialogChecked(toggleTipDialogChecked(falseStart));

      // Assert
      expect(trueEnd).assertEqual(trueStart);
      expect(falseEnd).assertEqual(falseStart);
    });

    it('conflict: tip_dialog_persist_should_change_after_toggle_from_false_to_true', 0, () => {
      // Arrange
      const start = false;

      // Act
      const next = toggleTipDialogChecked(start);
      const shouldPersist = shouldPersistTipDialogChoice(next);

      // Assert
      expect(next).assertTrue();
      expect(shouldPersist).assertTrue();
    });

    it('regression: tip_dialog_persist_should_change_after_toggle_from_true_to_false', 0, () => {
      // Arrange
      const start = true;

      // Act
      const next = toggleTipDialogChecked(start);
      const shouldPersist = shouldPersistTipDialogChoice(next);

      // Assert
      expect(next).assertFalse();
      expect(shouldPersist).assertFalse();
    });

    it('combined: tip_dialog_should_render_unchecked_and_checked_states_without_throwing', 0, () => {
      // Arrange
      const page = new TipDialog(undefined, {} as LocalStorage) as Object as TipDialogPrivateEQ;
      let confirmed = false;
      let threw = false;

      // Act
      page.title = 'Title';
      page.message = 'Message';
      page.storageKey = 'tip_key_eq';
      page.onConfirm = (): void => {
        confirmed = true;
      };
      page.isChecked = false;
      try {
        page.initialRender();
        page.isChecked = true;
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.isChecked).assertTrue();
      expect(confirmed).assertFalse();
    });
  });
}
