import { describe, expect, it } from '@ohos/hypium';
import {
  PlanImportDialog,
  canStartPlanImport,
  classifyPlanImportPayload
} from '../main/ets/pages/components/dialogs/PlanImportDialog';

interface PlanImportDialogPrivateEM {
  inputJson: string;
  importing: boolean;
  initialRender(): void;
}

export default function phase2BatchEMTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEM_plan_import_extra', () => {
    it('normal: plan_import_should_classify_plain_json_payload_as_plain', 0, () => {
      // Arrange
      const payload = '{"schemaVersion":1,"plan":{}}';

      // Act
      const kind = classifyPlanImportPayload(payload);
      const canStart = canStartPlanImport(payload);

      // Assert
      expect(kind).assertEqual('plain');
      expect(canStart).assertTrue();
    });

    it('boundary: plan_import_should_trim_before_detecting_deep_link_payload', 0, () => {
      // Arrange
      const payload = '  travelapp://import?data=abc  ';

      // Act
      const kind = classifyPlanImportPayload(payload);

      // Assert
      expect(kind).assertEqual('deep_link');
    });

    it('invalid: plan_import_should_classify_newline_only_payload_as_empty', 0, () => {
      // Arrange
      const payload = '\n\t  \n';

      // Act
      const kind = classifyPlanImportPayload(payload);
      const canStart = canStartPlanImport(payload);

      // Assert
      expect(kind).assertEqual('empty');
      expect(canStart).assertFalse();
    });

    it('conflict: plan_import_should_classify_compressed_before_plain_payload', 0, () => {
      // Arrange
      const compressed = '{"v":1,"p":"abc"}';
      const plain = '{"version":1,"p":"abc"}';

      // Act
      const compressedKind = classifyPlanImportPayload(compressed);
      const plainKind = classifyPlanImportPayload(plain);

      // Assert
      expect(compressedKind).assertEqual('compressed');
      expect(plainKind).assertEqual('plain');
    });

    it('regression: plan_import_deep_link_prefix_should_remain_case_sensitive', 0, () => {
      // Arrange
      const uppercasePayload = 'TRAVELAPP://import?data=abc';

      // Act
      const kind = classifyPlanImportPayload(uppercasePayload);

      // Assert
      expect(kind).assertEqual('plain');
    });

    it('combined: plan_import_classification_matrix_should_mark_all_non_empty_payloads_startable', 0, () => {
      // Arrange
      const payloads = [
        'travelapp://import?data=abc',
        '{"v":1,"p":"abc"}',
        '{"schemaVersion":1}',
        'raw text'
      ];

      // Act
      const allStartable = payloads.every((payload) => canStartPlanImport(payload));

      // Assert
      expect(allStartable).assertTrue();
    });

    it('combined: plan_import_dialog_render_should_cover_idle_plain_and_importing_deep_link_states', 0, () => {
      // Arrange
      const page = new PlanImportDialog(undefined, {} as LocalStorage) as Object as PlanImportDialogPrivateEM;
      let threw = false;

      // Act
      page.inputJson = '{"schemaVersion":1}';
      page.importing = false;
      try {
        page.initialRender();
        page.inputJson = 'travelapp://import?data=abc';
        page.importing = true;
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.importing).assertTrue();
      expect(classifyPlanImportPayload(page.inputJson)).assertEqual('deep_link');
    });
  });
}
