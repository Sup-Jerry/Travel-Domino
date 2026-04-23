import { describe, expect, it } from '@ohos/hypium';
import {
  PlanJsonImportDialog,
  canStartPlanJsonImport,
  normalizePlanJsonImportInput
} from '../main/ets/pages/components/dialogs/PlanJsonImportDialog';

interface PlanJsonImportDialogPrivateER {
  inputJson: string;
  importing: boolean;
  initialRender(): void;
}

export default function phase2BatchERTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchER_plan_json_import_extra', () => {
    it('normal: plan_json_import_should_trim_tabs_and_newlines_around_json', 0, () => {
      // Arrange
      const input = '\n\t {"schemaVersion":1} \t';

      // Act
      const normalized = normalizePlanJsonImportInput(input);

      // Assert
      expect(normalized).assertEqual('{"schemaVersion":1}');
    });

    it('boundary: plan_json_import_should_allow_single_character_non_space_payload', 0, () => {
      // Arrange
      const input = 'x';

      // Act
      const canStart = canStartPlanJsonImport(input);

      // Assert
      expect(canStart).assertTrue();
    });

    it('invalid: plan_json_import_should_reject_tab_newline_whitespace_only_input', 0, () => {
      // Arrange
      const input = '\n\t  ';

      // Act
      const normalized = normalizePlanJsonImportInput(input);
      const canStart = canStartPlanJsonImport(input);

      // Assert
      expect(normalized).assertEqual('');
      expect(canStart).assertFalse();
    });

    it('conflict: plan_json_import_should_distinguish_empty_after_trim_and_non_empty_after_trim', 0, () => {
      // Arrange
      const emptyLike = '   ';
      const nonEmptyLike = '  abc  ';

      // Act
      const emptyCanStart = canStartPlanJsonImport(emptyLike);
      const nonEmptyCanStart = canStartPlanJsonImport(nonEmptyLike);

      // Assert
      expect(emptyCanStart).assertFalse();
      expect(nonEmptyCanStart).assertTrue();
    });

    it('regression: plan_json_import_should_keep_bracket_payload_startable_after_trim', 0, () => {
      // Arrange
      const input = '  []  ';

      // Act
      const normalized = normalizePlanJsonImportInput(input);
      const canStart = canStartPlanJsonImport(input);

      // Assert
      expect(normalized).assertEqual('[]');
      expect(canStart).assertTrue();
    });

    it('combined: plan_json_import_dialog_should_render_idle_and_importing_states_without_throwing', 0, () => {
      // Arrange
      const page = new PlanJsonImportDialog(undefined, {} as LocalStorage) as Object as PlanJsonImportDialogPrivateER;
      let threw = false;

      // Act
      page.inputJson = '{"schemaVersion":1}';
      page.importing = false;
      try {
        page.initialRender();
        page.inputJson = 'abc';
        page.importing = true;
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.importing).assertTrue();
      expect(canStartPlanJsonImport(page.inputJson)).assertTrue();
    });
  });
}
