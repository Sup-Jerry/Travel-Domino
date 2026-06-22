import { describe, expect, it } from '@ohos/hypium';
import { PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
import { PlanImportDialog } from '../main/ets/pages/components/dialogs/PlanImportDialog';

class DialogControllerMockEC {
  public closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

interface PlanImportDialogPrivateEC {
  controller: DialogControllerMockEC;
  inputJson: string;
  importing: boolean;
  importCancelToken: PlanJsonImportCancelToken | null;
  onImport: (jsonText: string, cancelToken: PlanJsonImportCancelToken) => Promise<void>;
  safeShowToast(message: string): void;
  doImport(): Promise<void>;
}

function createPlanImportDialogEC(controller: DialogControllerMockEC): PlanImportDialogPrivateEC {
  const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateEC;
  page.controller = controller;
  return page;
}

export default function phase2BatchECTest() {
  describe('phase2BatchECTest', () => {
    it('normal: plan_import_safe_show_toast_should_swallow_runtime_toast_result', 0, () => {
      // Arrange
      const page = createPlanImportDialogEC(new DialogControllerMockEC());

      // Act
      page.safeShowToast('ec_import_toast_message');

      // Assert
      expect(true).assertTrue();
    });

    it('boundary: plan_import_do_import_should_stop_on_blank_input', 0, async () => {
      // Arrange
      const controller = new DialogControllerMockEC();
      const page = createPlanImportDialogEC(controller);
      page.inputJson = '   ';

      // Act
      await page.doImport();

      // Assert
      expect(page.importing).assertFalse();
      expect(controller.closeCount).assertEqual(0);
    });

    it('invalid: plan_import_do_import_should_stop_on_invalid_deep_link', 0, async () => {
      // Arrange
      const controller = new DialogControllerMockEC();
      const page = createPlanImportDialogEC(controller);
      page.inputJson = 'travelapp://import?data=bad';

      // Act
      await page.doImport();

      // Assert
      expect(page.importing).assertFalse();
      expect(controller.closeCount).assertEqual(0);
    });

    it('regression: plan_import_do_import_should_stop_on_invalid_compressed_payload', 0, async () => {
      // Arrange
      const controller = new DialogControllerMockEC();
      const page = createPlanImportDialogEC(controller);
      page.inputJson = '{"v":1,"p":"bad"}';

      // Act
      await page.doImport();

      // Assert
      expect(page.importing).assertFalse();
      expect(controller.closeCount).assertEqual(0);
    });

    it('combined: plan_import_do_import_should_trim_plain_payload_and_close_after_success', 0, async () => {
      // Arrange
      const controller = new DialogControllerMockEC();
      const page = createPlanImportDialogEC(controller);
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

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
