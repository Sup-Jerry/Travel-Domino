import { describe, it, expect } from '@ohos/hypium';
import {
  ModeFrequencyView,
  clampSettingsPreferenceInt,
  parseSettingsPreferenceModeCount,
  parseSettingsPreferenceModeFrequency,
  resolveSettingsPreferenceConsistencyRateText,
  resolveSettingsPreferenceDensityText,
  resolveSettingsPreferenceDominantModeText,
  resolveSettingsPreferenceEnergyText,
  resolveSettingsPreferenceModeTotalCount,
  resolveSettingsPreferencePaceText,
  resolveSettingsPreferencePercentText,
  resolveSettingsPreferencePercentWidth,
  resolveSettingsPreferencePreferenceText,
  resolveSettingsPreferenceWeatherLevelText
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

    it('boundary: settings_preference_clamp_should_apply_min_and_max_limits_when_out_of_range', 0, () => {
      // Arrange
      const lowValue = -3;
      const highValue = 8;
      // Act
      const lowResult = clampSettingsPreferenceInt(lowValue, 0, 2);
      const highResult = clampSettingsPreferenceInt(highValue, 0, 2);
      // Assert
      expect(lowResult).assertEqual(0);
      expect(highResult).assertEqual(2);
    });

    it('normal: settings_preference_percent_text_should_format_positive_ratio', 0, () => {
      // Arrange
      const count = 1;
      const total = 4;
      // Act
      const text = resolveSettingsPreferencePercentText(count, total);
      // Assert
      expect(text).assertEqual('25%');
    });

    it('normal: settings_preference_percent_width_should_keep_real_width_for_large_ratio', 0, () => {
      // Arrange
      const count = 5;
      const total = 10;
      // Act
      const width = resolveSettingsPreferencePercentWidth(count, total);
      // Assert
      expect(width).assertEqual('50%');
    });

    it('invalid: settings_preference_percent_helpers_should_return_zero_percent_when_count_or_total_not_positive', 0, () => {
      // Arrange
      const count = 0;
      const total = 4;
      // Act
      const text = resolveSettingsPreferencePercentText(count, total);
      const width = resolveSettingsPreferencePercentWidth(count, total);
      // Assert
      expect(text).assertEqual('0%');
      expect(width).assertEqual('0%');
    });

    it('boundary: settings_preference_weather_level_should_cover_low_mid_high_labels', 0, () => {
      // Arrange
      const lowValue = 0;
      const midValue = 1;
      const highValue = 2;
      // Act
      const lowText = resolveSettingsPreferenceWeatherLevelText(lowValue);
      const midText = resolveSettingsPreferenceWeatherLevelText(midValue);
      const highText = resolveSettingsPreferenceWeatherLevelText(highValue);
      // Assert
      expect(lowText.length > 0).assertTrue();
      expect(midText.length > 0).assertTrue();
      expect(highText.length > 0).assertTrue();
      expect(lowText !== midText).assertTrue();
      expect(midText !== highText).assertTrue();
    });

    it('combined: settings_preference_density_pace_and_energy_should_return_mid_labels_for_level_one', 0, () => {
      // Arrange
      const value = 1;
      // Act
      const densityText = resolveSettingsPreferenceDensityText(value);
      const paceText = resolveSettingsPreferencePaceText(value);
      const energyText = resolveSettingsPreferenceEnergyText(value);
      // Assert
      expect(densityText.length > 0).assertTrue();
      expect(paceText.length > 0).assertTrue();
      expect(energyText.length > 0).assertTrue();
      expect(densityText !== resolveSettingsPreferenceDensityText(0)).assertTrue();
      expect(paceText !== resolveSettingsPreferencePaceText(0)).assertTrue();
      expect(energyText !== resolveSettingsPreferenceEnergyText(0)).assertTrue();
    });

    it('combined: settings_preference_preference_text_should_cover_spot_food_and_default_labels', 0, () => {
      // Arrange
      const spotValue = 1;
      const foodValue = 2;
      const defaultValue = 0;
      // Act
      const spotText = resolveSettingsPreferencePreferenceText(spotValue);
      const foodText = resolveSettingsPreferencePreferenceText(foodValue);
      const defaultText = resolveSettingsPreferencePreferenceText(defaultValue);
      // Assert
      expect(spotText.length > 0).assertTrue();
      expect(foodText.length > 0).assertTrue();
      expect(defaultText.length > 0).assertTrue();
      expect(spotText !== foodText).assertTrue();
      expect(foodText !== defaultText).assertTrue();
    });

    it('conflict: settings_preference_dominant_mode_should_choose_leisure_when_it_exceeds_other_modes', 0, () => {
      // Arrange
      const leisureFreq: ModeFrequencyView = { modeCustom: 1, modeDefault: 2, modeSoldier: 2, modeLeisure: 4 };
      const defaultFreq: ModeFrequencyView = { modeCustom: 1, modeDefault: 5, modeSoldier: 4, modeLeisure: 3 };
      // Act
      const leisureText = resolveSettingsPreferenceDominantModeText(leisureFreq, 9);
      const defaultText = resolveSettingsPreferenceDominantModeText(defaultFreq, 13);
      // Assert
      expect(leisureText.length > 0).assertTrue();
      expect(defaultText.length > 0).assertTrue();
      expect(leisureText !== defaultText).assertTrue();
    });
  });
}
