import { describe, it, expect } from '@ohos/hypium';
import {
  cancelPlanJsonImport,
  canStartPlanJsonImport,
  normalizePlanJsonImportInput,
  PlanJsonImportDialog
} from '../main/ets/pages/components/dialogs/PlanJsonImportDialog';
import { PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';

class DialogControllerMockPlanJsonImport {
  closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

interface PlanJsonImportDialogPrivateTest {
  controller?: DialogControllerMockPlanJsonImport;
  inputJson: string;
  importing: boolean;
  onImport: (jsonText: string, cancelToken: PlanJsonImportCancelToken) => Promise<void>;
  safeShowToast(message: string): void;
  doImport(): Promise<void>;
  initialRender(): void;
  setController(controller: DialogControllerMockPlanJsonImport): void;
}

class CancelTokenStubPlanJsonImport extends PlanJsonImportCancelToken {
  cancelCount: number = 0;

  cancel(): void {
    this.cancelCount += 1;
  }
}

export default function planJsonImportDialogHelperTest() {
  describe('unit_test_case_generator_autofill_PlanJsonImportDialogHelper', () => {
    it('combined: plan_json_import_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateTest;
      const first = new DialogControllerMockPlanJsonImport();
      const second = new DialogControllerMockPlanJsonImport();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

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

    it('combined: plan_json_import_dialog_do_import_should_handle_empty_and_plain_payload', 0, async () => {
      // Arrange
      const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateTest;
      const controller = new DialogControllerMockPlanJsonImport();
      let importedJson = '';
      page.controller = controller;
      page.onImport = async (jsonText: string, _cancelToken: PlanJsonImportCancelToken): Promise<void> => {
        importedJson = jsonText;
      };

      // Act
      page.inputJson = '   ';
      await page.doImport();
      page.inputJson = '  {"schemaVersion":1}  ';
      await page.doImport();

      // Assert
      expect(importedJson).assertEqual('{"schemaVersion":1}');
      expect(controller.closeCount).assertEqual(1);
      expect(page.importing).assertFalse();
    });

    it('boundary: plan_json_import_dialog_safe_show_toast_should_not_throw', 0, () => {
      // Arrange
      const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateTest;
      let threw = false;

      // Act
      try {
        page.safeShowToast('toast');
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('normal: plan_json_import_dialog_initial_render_should_support_idle_input_branch', 0, () => {
      // Arrange
      const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateTest;
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

    it('boundary: plan_json_import_dialog_initial_render_should_support_importing_progress_branch', 0, () => {
      // Arrange
      const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateTest;
      let threw = false;

      // Act
      page.inputJson = '{\"schemaVersion\":1}';
      page.importing = true;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('normal: plan_json_import_cancel_should_abort_active_import_before_close', 0, () => {
      // Arrange
      const token = new CancelTokenStubPlanJsonImport();
      let closeCount = 0;

      // Act
      cancelPlanJsonImport(true, token, (): void => {
        closeCount += 1;
      });

      // Assert
      expect(token.cancelCount).assertEqual(1);
      expect(closeCount).assertEqual(1);
    });

    it('invalid: plan_json_import_cancel_should_close_directly_without_token', 0, () => {
      // Arrange
      let closeCount = 0;

      // Act
      cancelPlanJsonImport(false, null, (): void => {
        closeCount += 1;
      });

      // Assert
      expect(closeCount).assertEqual(1);
    });
  });
}
