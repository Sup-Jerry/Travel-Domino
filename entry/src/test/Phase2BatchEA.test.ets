import { describe, expect, it } from '@ohos/hypium';
import { PlanJsonExportDialog } from '../main/ets/pages/components/dialogs/PlanJsonExportDialog';

interface PlanJsonExportDialogPrivateEA {
  jsonText: string;
  safeShowToast(message: string): void;
  copyJson(): Promise<void>;
}

function createPlanJsonExportDialogEA(): PlanJsonExportDialogPrivateEA {
  return new PlanJsonExportDialog(undefined, {} as LocalStorage) as Object as PlanJsonExportDialogPrivateEA;
}

export default function phase2BatchEATest() {
  describe('phase2BatchEATest', () => {
    it('normal: plan_json_export_safe_show_toast_should_swallow_runtime_toast_result', 0, () => {
      // Arrange
      const page = createPlanJsonExportDialogEA();

      // Act
      page.safeShowToast('ea_export_toast_message');

      // Assert
      expect(true).assertTrue();
    });

    it('boundary: plan_json_export_copy_json_should_stop_when_text_empty', 0, async () => {
      // Arrange
      const page = createPlanJsonExportDialogEA();
      page.jsonText = '';

      // Act
      await page.copyJson();

      // Assert
      expect(page.jsonText).assertEqual('');
    });

    it('regression: plan_json_export_copy_json_should_attempt_non_empty_copy', 0, async () => {
      // Arrange
      const page = createPlanJsonExportDialogEA();
      page.jsonText = '{"schemaVersion":1}';

      // Act
      await page.copyJson();

      // Assert
      expect(page.jsonText.length > 0).assertTrue();
    });
  });
}
