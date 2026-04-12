import { describe, it, expect } from '@ohos/hypium';
import {
  getPlanSettingsActions,
  isPlanSettingsActionSupported,
  isWeatherPreferenceLevelValid
} from '../main/ets/pages/components/dialogs/PlanSettingsDialog';

export default function planSettingsDialogHelperTest() {
  describe('unit_test_case_generator_autofill_PlanSettingsDialogHelper', () => {
    it('normal: plan_settings_actions_should_include_share', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();
      // Assert
      expect(actions.indexOf('share') >= 0).assertTrue();
    });

    it('boundary: plan_settings_actions_should_keep_four_entries', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();
      // Assert
      expect(actions.length).assertEqual(4);
    });

    it('invalid: plan_settings_should_reject_unknown_action', 0, () => {
      // Arrange
      const action = 'delete_plan';
      // Act
      const supported = isPlanSettingsActionSupported(action);
      // Assert
      expect(supported).assertFalse();
    });

    it('conflict: plan_settings_weather_level_should_reject_out_of_range', 0, () => {
      // Arrange
      const level = 3;
      // Act
      const valid = isWeatherPreferenceLevelValid(level);
      // Assert
      expect(valid).assertFalse();
    });

    it('regression: td-20260412-plan-settings-action-order-should-stay-stable', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();
      // Assert
      expect(actions[0]).assertEqual('rename');
      expect(actions[1]).assertEqual('reschedule');
      expect(actions[2]).assertEqual('share');
      expect(actions[3]).assertEqual('weather_preference');
    });

    it('combined: plan_settings_action_and_weather_validation_should_work_together', 0, () => {
      // Arrange
      const action = 'weather_preference';
      const level = 1;
      // Act
      const supported = isPlanSettingsActionSupported(action);
      const validLevel = isWeatherPreferenceLevelValid(level);
      // Assert
      expect(supported).assertTrue();
      expect(validLevel).assertTrue();
    });
  });
}
