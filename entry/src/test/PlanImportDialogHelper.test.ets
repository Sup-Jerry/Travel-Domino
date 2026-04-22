import { describe, it, expect } from '@ohos/hypium';
import {
  canStartPlanImport,
  classifyPlanImportPayload,
  PlanImportDialog
} from '../main/ets/pages/components/dialogs/PlanImportDialog';

interface PlanImportDialogPrivateTest {
  inputJson: string;
  importing: boolean;
  initialRender(): void;
}

export default function planImportDialogHelperTest() {
  describe('unit_test_case_generator_autofill_PlanImportDialogHelper', () => {
    it('normal: plan_import_should_classify_deep_link_payload', 0, () => {
      // Arrange
      const payload = 'travelapp://import?data=abc';
      // Act
      const kind = classifyPlanImportPayload(payload);
      // Assert
      expect(kind).assertEqual('deep_link');
    });

    it('boundary: plan_import_should_treat_whitespace_as_empty', 0, () => {
      // Arrange
      const payload = '   ';
      // Act
      const kind = classifyPlanImportPayload(payload);
      // Assert
      expect(kind).assertEqual('empty');
    });

    it('invalid: plan_import_should_not_start_when_payload_empty', 0, () => {
      // Arrange
      const payload = '';
      // Act
      const canStart = canStartPlanImport(payload);
      // Assert
      expect(canStart).assertFalse();
    });

    it('conflict: plan_import_should_distinguish_plain_and_compressed_payload', 0, () => {
      // Arrange
      const plainPayload = '{"schemaVersion":1}';
      const compressedPayload = '{"v":1,"p":"abc"}';
      // Act
      const plainKind = classifyPlanImportPayload(plainPayload);
      const compressedKind = classifyPlanImportPayload(compressedPayload);
      // Assert
      expect(plainKind).assertEqual('plain');
      expect(compressedKind).assertEqual('compressed');
    });

    it('regression: td-20260412-plan-import-compressed-prefix-should-remain-v1', 0, () => {
      // Arrange
      const payload = '{"v":1}';
      // Act
      const kind = classifyPlanImportPayload(payload);
      // Assert
      expect(kind).assertEqual('compressed');
    });

    it('combined: plan_import_start_check_should_follow_kind_classification', 0, () => {
      // Arrange
      const payload = 'travelapp://import?data=xyz';
      // Act
      const kind = classifyPlanImportPayload(payload);
      const canStart = canStartPlanImport(payload);
      // Assert
      expect(kind).assertEqual('deep_link');
      expect(canStart).assertTrue();
    });

    it('normal: plan_import_dialog_initial_render_should_support_plain_payload_branch', 0, () => {
      // Arrange
      const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateTest;
      let threw = false;

      // Act
      page.inputJson = '{\"schemaVersion\":1}';
      page.importing = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: plan_import_dialog_initial_render_should_support_importing_deep_link_branch', 0, () => {
      // Arrange
      const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateTest;
      let threw = false;

      // Act
      page.inputJson = 'travelapp://import?data=abc';
      page.importing = true;
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
