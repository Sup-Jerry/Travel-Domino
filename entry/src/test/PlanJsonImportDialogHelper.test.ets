import { describe, it, expect } from '@ohos/hypium';
import {
  canStartPlanJsonImport,
  normalizePlanJsonImportInput
} from '../main/ets/pages/components/dialogs/PlanJsonImportDialog';

export default function planJsonImportDialogHelperTest() {
  describe('unit_test_case_generator_autofill_PlanJsonImportDialogHelper', () => {
    it('normal: plan_json_import_should_trim_input_before_use', 0, () => {
      // Arrange
      const input = '  {\"schemaVersion\":1}  ';
      // Act
      const normalized = normalizePlanJsonImportInput(input);
      // Assert
      expect(normalized).assertEqual('{\"schemaVersion\":1}');
    });

    it('boundary: plan_json_import_should_reject_all_whitespace', 0, () => {
      // Arrange
      const input = '   ';
      // Act
      const canStart = canStartPlanJsonImport(input);
      // Assert
      expect(canStart).assertFalse();
    });

    it('invalid: plan_json_import_should_reject_empty_input', 0, () => {
      // Arrange
      const input = '';
      // Act
      const canStart = canStartPlanJsonImport(input);
      // Assert
      expect(canStart).assertFalse();
    });

    it('conflict: plan_json_import_should_accept_non_json_text_as_non_empty', 0, () => {
      // Arrange
      const input = 'not-json-but-non-empty';
      // Act
      const canStart = canStartPlanJsonImport(input);
      // Assert
      expect(canStart).assertTrue();
    });

    it('regression: td-20260412-plan-json-import-leading-trailing-space-should-not-block', 0, () => {
      // Arrange
      const input = '  []  ';
      // Act
      const canStart = canStartPlanJsonImport(input);
      // Assert
      expect(canStart).assertTrue();
    });

    it('combined: plan_json_import_normalize_and_start_check_should_be_consistent', 0, () => {
      // Arrange
      const input = '  abc  ';
      // Act
      const normalized = normalizePlanJsonImportInput(input);
      const canStart = canStartPlanJsonImport(input);
      // Assert
      expect(normalized).assertEqual('abc');
      expect(canStart).assertTrue();
    });
  });
}
