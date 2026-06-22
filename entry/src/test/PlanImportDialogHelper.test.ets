import { describe, it, expect } from '@ohos/hypium';
import {
  cancelPlanImport,
  canStartPlanImport,
  classifyPlanImportPayload,
  PlanImportDialog
} from '../main/ets/pages/components/dialogs/PlanImportDialog';
import { PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';

class DialogControllerMockPlanImport {
  closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

interface PlanImportDialogPrivateTest {
  controller?: DialogControllerMockPlanImport;
  inputJson: string;
  importing: boolean;
  onImport: (jsonText: string, cancelToken: PlanJsonImportCancelToken) => Promise<void>;
  safeShowToast(message: string): void;
  doImport(): Promise<void>;
  initialRender(): void;
  setController(controller: DialogControllerMockPlanImport): void;
}

class CancelTokenStubPlanImport extends PlanJsonImportCancelToken {
  cancelCount: number = 0;

  cancel(): void {
    this.cancelCount += 1;
  }
}

export default function planImportDialogHelperTest() {
  describe('unit_test_case_generator_autofill_PlanImportDialogHelper', () => {
    it('combined: plan_import_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateTest;
      const first = new DialogControllerMockPlanImport();
      const second = new DialogControllerMockPlanImport();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('combined: plan_import_dialog_do_import_should_handle_empty_and_plain_payload', 0, async () => {
      // Arrange
      const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateTest;
      let importedJson = '';
      const controller = new DialogControllerMockPlanImport();
      page.controller = controller;
      page.onImport = async (jsonText: string, _cancelToken: PlanJsonImportCancelToken): Promise<void> => {
        importedJson = jsonText;
      };

      // Act
      page.inputJson = '   ';
      await page.doImport();
      page.inputJson = '{"schemaVersion":1}';
      await page.doImport();

      // Assert
      expect(importedJson).assertEqual('{"schemaVersion":1}');
      expect(controller.closeCount).assertEqual(1);
      expect(page.importing).assertFalse();
    });

    it('boundary: plan_import_dialog_safe_show_toast_should_not_throw', 0, () => {
      // Arrange
      const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateTest;
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

    it('boundary: plan_import_should_trim_payload_before_classifying_deep_link_and_compressed', 0, () => {
      // Arrange
      const deepLinkPayload = '  travelapp://import?data=abc  ';
      const compressedPayload = '\n{"v":1,"p":"abc"}\n';
      // Act
      const deepLinkKind = classifyPlanImportPayload(deepLinkPayload);
      const compressedKind = classifyPlanImportPayload(compressedPayload);
      // Assert
      expect(deepLinkKind).assertEqual('deep_link');
      expect(compressedKind).assertEqual('compressed');
    });

    it('invalid: plan_import_should_not_treat_uppercase_deep_link_as_supported_prefix', 0, () => {
      // Arrange
      const payload = 'TRAVELAPP://import?data=abc';
      // Act
      const kind = classifyPlanImportPayload(payload);
      // Assert
      expect(kind).assertEqual('plain');
    });

    it('combined: plan_import_plain_non_empty_payload_should_be_startable', 0, () => {
      // Arrange
      const payload = 'not-json-but-non-empty';
      // Act
      const kind = classifyPlanImportPayload(payload);
      const canStart = canStartPlanImport(payload);
      // Assert
      expect(kind).assertEqual('plain');
      expect(canStart).assertTrue();
    });

    it('normal: plan_import_cancel_should_abort_active_import_before_close', 0, () => {
      // Arrange
      const token = new CancelTokenStubPlanImport();
      let closeCount = 0;

      // Act
      cancelPlanImport(true, token, (): void => {
        closeCount += 1;
      });

      // Assert
      expect(token.cancelCount).assertEqual(1);
      expect(closeCount).assertEqual(1);
    });

    it('invalid: plan_import_cancel_should_close_directly_without_token', 0, () => {
      // Arrange
      let closeCount = 0;

      // Act
      cancelPlanImport(false, null, (): void => {
        closeCount += 1;
      });

      // Assert
      expect(closeCount).assertEqual(1);
    });
  });
}
