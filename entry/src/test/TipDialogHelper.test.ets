import { describe, it, expect } from '@ohos/hypium';
import { shouldPersistTipDialogChoice, toggleTipDialogChecked } from '../main/ets/pages/components/dialogs/TipDialog';

export default function tipDialogHelperTest() {
  describe('unit_test_case_generator_autofill_TipDialogHelper', () => {
    it('normal: tip_dialog_toggle_should_flip_from_false_to_true', 0, () => {
      // Arrange
      const current = false;
      // Act
      const next = toggleTipDialogChecked(current);
      // Assert
      expect(next).assertTrue();
    });

    it('boundary: tip_dialog_toggle_should_flip_from_true_to_false', 0, () => {
      // Arrange
      const current = true;
      // Act
      const next = toggleTipDialogChecked(current);
      // Assert
      expect(next).assertFalse();
    });

    it('invalid: tip_dialog_should_not_persist_when_unchecked', 0, () => {
      // Arrange
      const isChecked = false;
      // Act
      const shouldPersist = shouldPersistTipDialogChoice(isChecked);
      // Assert
      expect(shouldPersist).assertFalse();
    });

    it('conflict: tip_dialog_should_persist_when_checked', 0, () => {
      // Arrange
      const isChecked = true;
      // Act
      const shouldPersist = shouldPersistTipDialogChoice(isChecked);
      // Assert
      expect(shouldPersist).assertTrue();
    });

    it('regression: td-20260412-tip-dialog-toggle-double-flip-should-return-origin', 0, () => {
      // Arrange
      const start = true;
      // Act
      const end = toggleTipDialogChecked(toggleTipDialogChecked(start));
      // Assert
      expect(end).assertEqual(start);
    });

    it('combined: tip_dialog_toggle_and_persist_should_stay_consistent', 0, () => {
      // Arrange
      const start = false;
      // Act
      const checked = toggleTipDialogChecked(start);
      const shouldPersist = shouldPersistTipDialogChoice(checked);
      // Assert
      expect(checked).assertTrue();
      expect(shouldPersist).assertTrue();
    });
  });
}
