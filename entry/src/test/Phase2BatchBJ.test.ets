import { describe, expect, it } from '@ohos/hypium';
import {
  getPlanSettingsActions,
  isPlanSettingsActionSupported,
  isWeatherPreferenceLevelValid
} from '../main/ets/pages/components/dialogs/PlanSettingsDialog';

export default function phase2BatchBJTest() {
  describe('phase2BatchBJTest', () => {
    it('normal: plan_settings_actions_should_include_weather_preference_entry', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();
      // Assert
      expect(actions.indexOf('weather_preference') >= 0).assertTrue();
    });

    it('boundary: plan_settings_actions_should_keep_expected_count', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();
      // Assert
      expect(actions.length).assertEqual(4);
    });

    it('invalid: plan_settings_actions_should_not_contain_unknown_entries', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions().map((action) => String(action));
      // Assert
      expect(actions.indexOf('delete') >= 0).assertFalse();
    });

    it('normal: plan_settings_supported_should_accept_all_builtin_actions', 0, () => {
      // Arrange
      const actions = getPlanSettingsActions();
      // Act
      const allSupported = actions.every((action) => isPlanSettingsActionSupported(action));
      // Assert
      expect(allSupported).assertTrue();
    });

    it('boundary: plan_settings_supported_should_reject_case_mismatch_action', 0, () => {
      // Arrange
      const action = 'Rename';
      // Act
      const supported = isPlanSettingsActionSupported(action);
      // Assert
      expect(supported).assertFalse();
    });

    it('conflict: plan_settings_supported_should_reject_whitespace_padded_action', 0, () => {
      // Arrange
      const action = ' share ';
      // Act
      const supported = isPlanSettingsActionSupported(action);
      // Assert
      expect(supported).assertFalse();
    });

    it('normal: weather_preference_level_should_accept_range_edges', 0, () => {
      // Arrange
      // Act
      const lowValid = isWeatherPreferenceLevelValid(0);
      const highValid = isWeatherPreferenceLevelValid(2);
      // Assert
      expect(lowValid).assertTrue();
      expect(highValid).assertTrue();
    });

    it('boundary: weather_preference_level_should_reject_fractional_number', 0, () => {
      // Arrange
      const level = 1.5;
      // Act
      const valid = isWeatherPreferenceLevelValid(level);
      // Assert
      expect(valid).assertFalse();
    });

    it('invalid: weather_preference_level_should_reject_negative_and_large_values', 0, () => {
      // Arrange
      // Act
      const negativeValid = isWeatherPreferenceLevelValid(-1);
      const largeValid = isWeatherPreferenceLevelValid(3);
      // Assert
      expect(negativeValid).assertFalse();
      expect(largeValid).assertFalse();
    });

    it('combined: plan_settings_action_and_weather_level_validation_should_be_independent', 0, () => {
      // Arrange
      const action = 'weather_preference';
      const level = 1;
      // Act
      const actionSupported = isPlanSettingsActionSupported(action);
      const levelValid = isWeatherPreferenceLevelValid(level);
      // Assert
      expect(actionSupported).assertTrue();
      expect(levelValid).assertTrue();
    });

    it('regression: td-20260417-phase2-bj-plan-settings-action-order-should-stay-stable', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();
      // Assert
      expect(actions[0]).assertEqual('rename');
      expect(actions[1]).assertEqual('reschedule');
      expect(actions[2]).assertEqual('share');
      expect(actions[3]).assertEqual('weather_preference');
    });
  });
}
