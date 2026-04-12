import { describe, it, expect } from '@ohos/hypium';
import {
  canConflictCompressConfirm,
  shouldShowConflictCompressOverload
} from '../main/ets/pages/components/dialogs/ConflictCompressDialog';

export default function conflictCompressDialogHelperTest() {
  describe('unit_test_case_generator_autofill_ConflictCompressDialogHelper', () => {
    it('normal: conflict_compress_confirm_should_pass_with_positive_selection', 0, () => {
      // Arrange
      const selectedCount = 2;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertTrue();
    });

    it('boundary: conflict_compress_confirm_should_fail_with_zero_selection', 0, () => {
      // Arrange
      const selectedCount = 0;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertFalse();
    });

    it('invalid: conflict_compress_overload_should_hide_when_status_not_overload', 0, () => {
      // Arrange
      const status = 'OK';
      const remaining = 10;
      // Act
      const show = shouldShowConflictCompressOverload(status, remaining);
      // Assert
      expect(show).assertFalse();
    });

    it('conflict: conflict_compress_overload_should_show_when_overload_and_remaining_positive', 0, () => {
      // Arrange
      const status = 'OVERLOAD';
      const remaining = 5;
      // Act
      const show = shouldShowConflictCompressOverload(status, remaining);
      // Assert
      expect(show).assertTrue();
    });

    it('regression: td-20260412-conflict-compress-overload-zero-remaining-should-hide', 0, () => {
      // Arrange
      const status = 'OVERLOAD';
      const remaining = 0;
      // Act
      const show = shouldShowConflictCompressOverload(status, remaining);
      // Assert
      expect(show).assertFalse();
    });

    it('combined: conflict_compress_confirm_and_overload_checks_should_be_independent', 0, () => {
      // Arrange
      const selectedCount = 1;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      const showOverload = shouldShowConflictCompressOverload('OVERLOAD', 8);
      // Assert
      expect(canConfirm).assertTrue();
      expect(showOverload).assertTrue();
    });
  });
}
