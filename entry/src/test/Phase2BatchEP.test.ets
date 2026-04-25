import { describe, expect, it } from '@ohos/hypium';
import {
  PlanJsonExportDialog,
  canCopyPlanJsonText
} from '../main/ets/pages/components/dialogs/PlanJsonExportDialog';

interface PlanJsonExportDialogPrivateEP {
  jsonText: string;
  initialRender(): void;
}

export default function phase2BatchEPTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEP_plan_json_export_extra', () => {
    it('normal: plan_json_export_should_allow_copy_for_multiline_json_text', 0, () => {
      // Arrange
      const jsonText = '{\n  "schemaVersion": 1\n}';

      // Act
      const canCopy = canCopyPlanJsonText(jsonText);

      // Assert
      expect(canCopy).assertTrue();
    });

    it('boundary: plan_json_export_should_allow_copy_for_tab_or_newline_when_length_positive', 0, () => {
      // Arrange
      const tabText = '\t';
      const newlineText = '\n';

      // Act
      const tabCanCopy = canCopyPlanJsonText(tabText);
      const newlineCanCopy = canCopyPlanJsonText(newlineText);

      // Assert
      expect(tabCanCopy).assertTrue();
      expect(newlineCanCopy).assertTrue();
    });

    it('invalid: plan_json_export_should_reject_only_empty_string', 0, () => {
      // Arrange
      const jsonText = '';

      // Act
      const canCopy = canCopyPlanJsonText(jsonText);

      // Assert
      expect(canCopy).assertFalse();
    });

    it('conflict: plan_json_export_should_distinguish_empty_and_single_space_payloads', 0, () => {
      // Arrange
      const emptyText = '';
      const spaceText = ' ';

      // Act
      const emptyCanCopy = canCopyPlanJsonText(emptyText);
      const spaceCanCopy = canCopyPlanJsonText(spaceText);

      // Assert
      expect(emptyCanCopy).assertFalse();
      expect(spaceCanCopy).assertTrue();
    });

    it('regression: plan_json_export_copy_guard_should_remain_length_based_for_zero_like_text', 0, () => {
      // Arrange
      const zeroText = '0';

      // Act
      const canCopy = canCopyPlanJsonText(zeroText);

      // Assert
      expect(canCopy).assertTrue();
    });

    it('combined: plan_json_export_dialog_should_render_empty_and_non_empty_json_states', 0, () => {
      // Arrange
      const page = new PlanJsonExportDialog(undefined, {} as LocalStorage) as Object as PlanJsonExportDialogPrivateEP;
      let threw = false;

      // Act
      page.jsonText = '';
      try {
        page.initialRender();
        page.jsonText = '{"schemaVersion":1}';
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(canCopyPlanJsonText(page.jsonText)).assertTrue();
    });
  });
}
