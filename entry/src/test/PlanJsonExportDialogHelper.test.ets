import { describe, it, expect } from '@ohos/hypium';
import { canCopyPlanJsonText } from '../main/ets/pages/components/dialogs/PlanJsonExportDialog';

export default function planJsonExportDialogHelperTest() {
  describe('unit_test_case_generator_autofill_PlanJsonExportDialogHelper', () => {
    it('normal: plan_json_export_should_allow_copy_for_non_empty_text', 0, () => {
      // Arrange
      const jsonText = '{"schemaVersion":1}';
      // Act
      const canCopy = canCopyPlanJsonText(jsonText);
      // Assert
      expect(canCopy).assertTrue();
    });

    it('boundary: plan_json_export_should_allow_whitespace_text_with_current_rule', 0, () => {
      // Arrange
      const jsonText = ' ';
      // Act
      const canCopy = canCopyPlanJsonText(jsonText);
      // Assert
      expect(canCopy).assertTrue();
    });

    it('invalid: plan_json_export_should_reject_empty_text', 0, () => {
      // Arrange
      const jsonText = '';
      // Act
      const canCopy = canCopyPlanJsonText(jsonText);
      // Assert
      expect(canCopy).assertFalse();
    });

    it('conflict: plan_json_export_should_distinguish_empty_and_non_empty', 0, () => {
      // Arrange
      const emptyText = '';
      const validText = '{}';
      // Act
      const emptyResult = canCopyPlanJsonText(emptyText);
      const validResult = canCopyPlanJsonText(validText);
      // Assert
      expect(emptyResult).assertFalse();
      expect(validResult).assertTrue();
    });

    it('regression: td-20260412-plan-json-export-copy-guard-should-stay-length-based', 0, () => {
      // Arrange
      const jsonText = '\n';
      // Act
      const canCopy = canCopyPlanJsonText(jsonText);
      // Assert
      expect(canCopy).assertTrue();
    });

    it('combined: plan_json_export_copy_guard_should_match_length-check', 0, () => {
      // Arrange
      const jsonText = 'abc';
      // Act
      const canCopy = canCopyPlanJsonText(jsonText);
      const nonEmpty = jsonText.length > 0;
      // Assert
      expect(canCopy).assertEqual(nonEmpty);
    });
  });
}
