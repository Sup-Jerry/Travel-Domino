import { describe, it, expect } from '@ohos/hypium';
import {
  resolveSettingsGeneralAiPoiInput,
  resolveSettingsGeneralIdleGapTriggerMinutes,
  resolveSettingsGeneralMinEventDuration,
  resolveSettingsGeneralThemeModeText
} from '../main/ets/pages/SettingsGeneralPage';

export default function settingsGeneralPageHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsGeneralPageHelper', () => {
    it('normal: settings_general_theme_mode_should_map_dark_to_dark_text', 0, () => {
      // Arrange
      const mode = 'dark';
      // Act
      const text = resolveSettingsGeneralThemeModeText(mode);
      // Assert
      expect(text).assertEqual('深色');
    });

    it('boundary: settings_general_theme_mode_should_fallback_to_system_text', 0, () => {
      // Arrange
      const mode = 'system';
      // Act
      const text = resolveSettingsGeneralThemeModeText(mode);
      // Assert
      expect(text).assertEqual('跟随系统');
    });

    it('invalid: settings_general_idle_gap_minutes_should_fallback_to_current_when_input_nan', 0, () => {
      // Arrange
      const input = 'abc';
      const currentValue = 45;
      // Act
      const value = resolveSettingsGeneralIdleGapTriggerMinutes(input, currentValue);
      // Assert
      expect(value).assertEqual(currentValue);
    });

    it('conflict: settings_general_min_event_duration_should_apply_upper_bound_when_input_too_large', 0, () => {
      // Arrange
      const input = '1000';
      const currentValue = 30;
      // Act
      const value = resolveSettingsGeneralMinEventDuration(input, currentValue);
      // Assert
      expect(value).assertEqual(720);
    });

    it('regression: td-20260412-settings_general_ai_poi_input_should_keep_fallback_for_blank_text', 0, () => {
      // Arrange
      const input = '';
      const fallback = 6;
      // Act
      const value = resolveSettingsGeneralAiPoiInput(input, fallback);
      // Assert
      expect(value).assertEqual(fallback);
    });

    it('combined: settings_general_idle_and_duration_normalization_should_return_positive_values', 0, () => {
      // Arrange
      const idleInput = '0';
      const durationInput = '0';
      // Act
      const idleValue = resolveSettingsGeneralIdleGapTriggerMinutes(idleInput, 45);
      const durationValue = resolveSettingsGeneralMinEventDuration(durationInput, 30);
      // Assert
      expect(idleValue > 0).assertTrue();
      expect(durationValue > 0).assertTrue();
    });
  });
}
