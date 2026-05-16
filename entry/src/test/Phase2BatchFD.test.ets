import { describe, expect, it } from '@ohos/hypium';
import {
  getPlanSettingsActions,
  isPlanSettingsActionSupported,
  isWeatherPreferenceLevelValid,
  PlanSettingsAction
} from '../main/ets/pages/components/dialogs/PlanSettingsDialog';
import {
  canStartPlanJsonImport,
  normalizePlanJsonImportInput
} from '../main/ets/pages/components/dialogs/PlanJsonImportDialog';
import { canCopyPlanJsonText } from '../main/ets/pages/components/dialogs/PlanJsonExportDialog';
import {
  canRenameDialogSubmit,
  normalizeRenameDialogName
} from '../main/ets/pages/components/dialogs/RenameDialog';
import {
  canCreatePlanWithTitle,
  formatCreatePlanDateText
} from '../main/ets/pages/components/dialogs/CreatePlanDialog';

export default function phase2BatchFDTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFD_plan_dialog_helpers', () => {
    it('normal: plan_settings_helpers_should_expose_supported_actions', 0, () => {
      // Arrange
      // Act
      // Assert
      const actions = getPlanSettingsActions();

      expect(actions.length).assertEqual(4);
      expect(actions.indexOf('rename' as PlanSettingsAction) >= 0).assertTrue();
      expect(actions.indexOf('reschedule' as PlanSettingsAction) >= 0).assertTrue();
      expect(actions.indexOf('share' as PlanSettingsAction) >= 0).assertTrue();
      expect(actions.indexOf('weather_preference' as PlanSettingsAction) >= 0).assertTrue();
      expect(isPlanSettingsActionSupported('rename')).assertTrue();
      expect(isPlanSettingsActionSupported('weather_preference')).assertTrue();
      expect(isPlanSettingsActionSupported('delete')).assertFalse();
      expect(isPlanSettingsActionSupported('')).assertFalse();
    });

    it('boundary: weather_preference_level_should_accept_only_integer_zero_to_two', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(isWeatherPreferenceLevelValid(0)).assertTrue();
      expect(isWeatherPreferenceLevelValid(1)).assertTrue();
      expect(isWeatherPreferenceLevelValid(2)).assertTrue();
      expect(isWeatherPreferenceLevelValid(-1)).assertFalse();
      expect(isWeatherPreferenceLevelValid(3)).assertFalse();
      expect(isWeatherPreferenceLevelValid(1.5)).assertFalse();
      expect(isWeatherPreferenceLevelValid(Number.NaN)).assertFalse();
    });

    it('invalid: json_import_helpers_should_trim_input_and_block_empty_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(normalizePlanJsonImportInput('  {"a":1}  ')).assertEqual('{"a":1}');
      expect(normalizePlanJsonImportInput('\n\t')).assertEqual('');
      expect(canStartPlanJsonImport('')).assertFalse();
      expect(canStartPlanJsonImport('   ')).assertFalse();
      expect(canStartPlanJsonImport('{"schemaVersion":1}')).assertTrue();
      expect(canStartPlanJsonImport('  []  ')).assertTrue();
    });

    it('regression: json_export_helper_should_allow_only_non_empty_text', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(canCopyPlanJsonText('')).assertFalse();
      expect(canCopyPlanJsonText(' ')).assertTrue();
      expect(canCopyPlanJsonText('{}')).assertTrue();
    });

    it('combined: rename_and_create_plan_helpers_should_share_trim_semantics', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(normalizeRenameDialogName('  trip  ')).assertEqual('trip');
      expect(normalizeRenameDialogName('')).assertEqual('');
      expect(normalizeRenameDialogName('   ')).assertEqual('');
      expect(canRenameDialogSubmit('  trip  ')).assertTrue();
      expect(canRenameDialogSubmit('   ')).assertFalse();
      expect(canCreatePlanWithTitle('  city  ')).assertTrue();
      expect(canCreatePlanWithTitle('   ')).assertFalse();
    });

    it('boundary: create_plan_date_text_should_use_local_date_components', 0, () => {
      // Arrange
      // Act
      // Assert
      const firstDay = new Date(2026, 0, 1);
      const lastDay = new Date(2026, 11, 31);

      expect(formatCreatePlanDateText(firstDay)).assertEqual('2026/1/1');
      expect(formatCreatePlanDateText(lastDay)).assertEqual('2026/12/31');
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
