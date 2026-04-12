import { describe, it, expect } from '@ohos/hypium';
import {
  ModeFrequencyView,
  clampSettingsPreferenceInt,
  parseSettingsPreferenceModeCount,
  parseSettingsPreferenceModeFrequency,
  resolveSettingsPreferenceConsistencyRateText,
  resolveSettingsPreferenceModeTotalCount,
  resolveSettingsPreferencePercentText,
  resolveSettingsPreferencePercentWidth
} from '../main/ets/pages/SettingsPreferenceInsightsPage';

export default function settingsPreferenceInsightsPageHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsPreferenceInsightsPageHelper', () => {
    it('normal: settings_preference_clamp_should_keep_value_within_range', 0, () => {
      // Arrange
      const value = 1;
      // Act
      const result = clampSettingsPreferenceInt(value, 0, 2);
      // Assert
      expect(result).assertEqual(1);
    });

    it('boundary: settings_preference_mode_total_should_return_zero_for_empty_freq', 0, () => {
      // Arrange
      const freq: ModeFrequencyView = { modeCustom: 0, modeDefault: 0, modeSoldier: 0, modeLeisure: 0 };
      // Act
      const total = resolveSettingsPreferenceModeTotalCount(freq);
      // Assert
      expect(total).assertEqual(0);
    });

    it('invalid: settings_preference_mode_count_should_return_zero_for_bad_payload', 0, () => {
      // Arrange
      const raw = '{bad}';
      // Act
      const count = parseSettingsPreferenceModeCount(raw, '1');
      // Assert
      expect(count).assertEqual(0);
    });

    it('conflict: settings_preference_percent_width_should_enforce_minimum_visible_width', 0, () => {
      // Arrange
      const count = 1;
      const total = 100;
      // Act
      const width = resolveSettingsPreferencePercentWidth(count, total);
      // Assert
      expect(width).assertEqual('6%');
    });

    it('regression: td-20260412-settings_preference_consistency_rate_should_keep_one_decimal', 0, () => {
      // Arrange
      const match = 1;
      const mismatch = 2;
      // Act
      const rate = resolveSettingsPreferenceConsistencyRateText(match, mismatch);
      // Assert
      expect(rate).assertEqual('33.3%');
    });

    it('combined: settings_preference_parse_freq_and_percent_text_should_chain', 0, () => {
      // Arrange
      const raw = '{"0":2,"1":3}';
      // Act
      const freq = parseSettingsPreferenceModeFrequency(raw);
      const total = resolveSettingsPreferenceModeTotalCount(freq);
      const soldierPercent = resolveSettingsPreferencePercentText(freq.modeSoldier, total);
      // Assert
      expect(total).assertEqual(5);
      expect(soldierPercent).assertEqual('60%');
    });
  });
}
