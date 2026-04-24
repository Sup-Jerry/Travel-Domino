import { describe, expect, it } from '@ohos/hypium';
import { PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
import { PlanJsonImportDialog } from '../main/ets/pages/components/dialogs/PlanJsonImportDialog';

class DialogControllerMockEB {
  public closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

interface PlanJsonImportDialogPrivateEB {
  controller: DialogControllerMockEB;
  inputJson: string;
  importing: boolean;
  importCancelToken: PlanJsonImportCancelToken | null;
  onImport: (jsonText: string, cancelToken: PlanJsonImportCancelToken) => Promise<void>;
  safeShowToast(message: string): void;
  doImport(): Promise<void>;
  setController(controller: DialogControllerMockEB): void;
}

function createPlanJsonImportDialogEB(controller: DialogControllerMockEB): PlanJsonImportDialogPrivateEB {
  const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateEB;
  page.controller = controller;
  return page;
}

export default function phase2BatchEBTest() {
  describe('phase2BatchEBTest', () => {
    it('combined: plan_json_import_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const first = new DialogControllerMockEB();
      const second = new DialogControllerMockEB();
      const page = createPlanJsonImportDialogEB(first);

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('normal: plan_json_import_safe_show_toast_should_swallow_runtime_toast_result', 0, () => {
      // Arrange
      const page = createPlanJsonImportDialogEB(new DialogControllerMockEB());

      // Act
      page.safeShowToast('eb_import_toast_message');

      // Assert
      expect(true).assertTrue();
    });

    it('boundary: plan_json_import_do_import_should_stop_on_blank_input', 0, async () => {
      // Arrange
      const controller = new DialogControllerMockEB();
      const page = createPlanJsonImportDialogEB(controller);
      page.inputJson = '   ';

      // Act
      await page.doImport();

      // Assert
      expect(page.importing).assertFalse();
      expect(controller.closeCount).assertEqual(0);
    });

    it('combined: plan_json_import_do_import_should_trim_input_and_close_after_success', 0, async () => {
      // Arrange
      const controller = new DialogControllerMockEB();
      const page = createPlanJsonImportDialogEB(controller);
      const importedTexts: string[] = [];
      let tokenWasProvided = false;
      page.inputJson = '  {"schemaVersion":1}  ';
      page.onImport = async (jsonText: string, cancelToken: PlanJsonImportCancelToken): Promise<void> => {
        importedTexts.push(jsonText);
        tokenWasProvided = cancelToken !== null && cancelToken !== undefined;
      };

      // Act
      await page.doImport();

      // Assert
      expect(importedTexts[0]).assertEqual('{"schemaVersion":1}');
      expect(tokenWasProvided).assertTrue();
      expect(page.importing).assertFalse();
      expect(page.importCancelToken === null).assertTrue();
      expect(controller.closeCount).assertEqual(1);
    });
  });
}
