import { describe, it, expect } from '@ohos/hypium';
import {
  canRenameDialogSubmit,
  confirmRenameDialog,
  normalizeRenameDialogName
} from '../main/ets/pages/components/dialogs/RenameDialog';

export default function renameDialogHelperTest() {
  describe('unit_test_case_generator_autofill_RenameDialogHelper', () => {
    it('normal: rename_dialog_should_accept_regular_name', 0, () => {
      // Arrange
      const input = '东京行程';
      // Act
      const canSubmit = canRenameDialogSubmit(input);
      // Assert
      expect(canSubmit).assertTrue();
    });

    it('boundary: rename_dialog_should_trim_surrounding_spaces', 0, () => {
      // Arrange
      const input = '  Osaka Plan  ';
      // Act
      const normalized = normalizeRenameDialogName(input);
      // Assert
      expect(normalized).assertEqual('Osaka Plan');
    });

    it('invalid: rename_dialog_should_reject_empty_input', 0, () => {
      // Arrange
      const input = '';
      // Act
      const canSubmit = canRenameDialogSubmit(input);
      // Assert
      expect(canSubmit).assertFalse();
    });

    it('conflict: rename_dialog_should_reject_whitespace_only_input', 0, () => {
      // Arrange
      const input = '    ';
      // Act
      const canSubmit = canRenameDialogSubmit(input);
      // Assert
      expect(canSubmit).assertFalse();
    });

    it('regression: td-20260412-rename-normalize-should-remain-stable', 0, () => {
      // Arrange
      const input = '  Plan A';
      // Act
      const normalized = normalizeRenameDialogName(input);
      // Assert
      expect(normalized).assertEqual('Plan A');
    });

    it('combined: rename_dialog_should_accept_trimmed_non_empty_name', 0, () => {
      // Arrange
      const input = '  N4 Batch  ';
      // Act
      const normalized = normalizeRenameDialogName(input);
      const canSubmit = canRenameDialogSubmit(input);
      // Assert
      expect(normalized).assertEqual('N4 Batch');
      expect(canSubmit).assertTrue();
    });

    it('normal: rename_dialog_confirm_should_submit_and_close_when_name_valid', 0, () => {
      // Arrange
      let confirmedName = '';
      let closeCount = 0;

      // Act
      const submitted = confirmRenameDialog('Kyoto Plan', (newName: string) => {
        confirmedName = newName;
      }, () => {
        closeCount += 1;
      });

      // Assert
      expect(submitted).assertTrue();
      expect(confirmedName).assertEqual('Kyoto Plan');
      expect(closeCount).assertEqual(1);
    });

    it('invalid: rename_dialog_confirm_should_skip_submit_and_close_when_name_blank', 0, () => {
      // Arrange
      let confirmedName = '';
      let closeCount = 0;

      // Act
      const submitted = confirmRenameDialog('   ', (newName: string) => {
        confirmedName = newName;
      }, () => {
        closeCount += 1;
      });

      // Assert
      expect(submitted).assertFalse();
      expect(confirmedName).assertEqual('');
      expect(closeCount).assertEqual(0);
    });
  });
}
