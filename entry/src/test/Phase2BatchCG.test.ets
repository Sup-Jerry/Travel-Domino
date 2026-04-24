import { describe, expect, it } from '@ohos/hypium';
import {
  buildSettingsGeneralAiPoiRangeConfig,
  createSettingsGeneralPageForTest,
  resolveSettingsGeneralAiPoiInput,
  resolveSettingsGeneralIdleGapTriggerMinutes,
  resolveSettingsGeneralMinEventDuration,
  resolveSettingsGeneralThemeModeText,
  SettingsGeneralAiPoiInputState
} from '../main/ets/pages/SettingsGeneralPage';
import { AiDailyPoiRangeConfig } from '../main/ets/common/utils/PreferenceManager';

interface SettingsGeneralPagePrivateCG {
  weatherFeatureEnabled: boolean;
  enableIdleGapDetection: boolean;
  idleGapTriggerMinutes: number;
  idleGapTriggerInput: string;
  minEventDuration: number;
  minEventDurationInput: string;
  aiDefaultMinInput: string;
  aiDefaultMaxInput: string;
  aiSoldierMinInput: string;
  aiSoldierMaxInput: string;
  aiLeisureMinInput: string;
  aiLeisureMaxInput: string;
  loading: boolean;
  themeMode: 'system' | 'light' | 'dark';
  effectiveTheme: string;
  initialRender(): void;
  getThemePalette(): Object;
  getThemeModeText(): string;
}

function createSettingsGeneralPageCG(): SettingsGeneralPagePrivateCG {
  return createSettingsGeneralPageForTest() as SettingsGeneralPagePrivateCG;
}

function buildInputStateCG(
  defaultMinInput: string,
  defaultMaxInput: string,
  soldierMinInput: string,
  soldierMaxInput: string,
  leisureMinInput: string,
  leisureMaxInput: string
): SettingsGeneralAiPoiInputState {
  return {
    defaultMinInput: defaultMinInput,
    defaultMaxInput: defaultMaxInput,
    soldierMinInput: soldierMinInput,
    soldierMaxInput: soldierMaxInput,
    leisureMinInput: leisureMinInput,
    leisureMaxInput: leisureMaxInput
  };
}

function buildRangeConfigCG(): AiDailyPoiRangeConfig {
  return {
    defaultMin: 4,
    defaultMax: 6,
    soldierMin: 5,
    soldierMax: 8,
    leisureMin: 3,
    leisureMax: 5
  };
}

export default function phase2BatchCGTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCG_settings_general_extra', () => {
    it('normal: settings_general_theme_mode_text_should_cover_all_valid_modes', 0, () => {
      // Arrange
      const systemMode = 'system';
      const lightMode = 'light';
      const darkMode = 'dark';

      // Act
      const systemText = resolveSettingsGeneralThemeModeText(systemMode);
      const lightText = resolveSettingsGeneralThemeModeText(lightMode);
      const darkText = resolveSettingsGeneralThemeModeText(darkMode);

      // Assert
      expect(systemText.length > 0).assertTrue();
      expect(lightText.length > 0).assertTrue();
      expect(darkText.length > 0).assertTrue();
      expect(systemText === lightText).assertFalse();
      expect(lightText === darkText).assertFalse();
    });

    it('boundary: settings_general_idle_gap_minutes_should_floor_decimal_and_clamp_low_high', 0, () => {
      // Arrange
      const decimalInput = '12.8';
      const lowInput = '-3';
      const highInput = '9999';

      // Act
      const decimalValue = resolveSettingsGeneralIdleGapTriggerMinutes(decimalInput, 45);
      const lowValue = resolveSettingsGeneralIdleGapTriggerMinutes(lowInput, 45);
      const highValue = resolveSettingsGeneralIdleGapTriggerMinutes(highInput, 45);

      // Assert
      expect(decimalValue).assertEqual(12);
      expect(lowValue).assertEqual(1);
      expect(highValue).assertEqual(720);
    });

    it('boundary: settings_general_min_event_duration_should_floor_decimal_and_clamp_low_high', 0, () => {
      // Arrange
      const decimalInput = '18.9';
      const lowInput = '-1';
      const highInput = '900';

      // Act
      const decimalValue = resolveSettingsGeneralMinEventDuration(decimalInput, 30);
      const lowValue = resolveSettingsGeneralMinEventDuration(lowInput, 30);
      const highValue = resolveSettingsGeneralMinEventDuration(highInput, 30);

      // Assert
      expect(decimalValue).assertEqual(18);
      expect(lowValue).assertEqual(1);
      expect(highValue).assertEqual(720);
    });

    it('invalid: settings_general_ai_poi_input_should_use_normalized_fallback_when_input_is_invalid', 0, () => {
      // Arrange
      const invalidInput = 'bad';
      const tooLargeFallback = 99;

      // Act
      const resolved = resolveSettingsGeneralAiPoiInput(invalidInput, tooLargeFallback);

      // Assert
      expect(resolved).assertEqual(12);
    });

    it('boundary: settings_general_numeric_inputs_should_keep_current_for_blank_and_parse_prefix_digits', 0, () => {
      // Arrange
      const blank = '   ';
      const prefixed = '18minutes';

      // Act
      const idleBlank = resolveSettingsGeneralIdleGapTriggerMinutes(blank, 45);
      const idlePrefixed = resolveSettingsGeneralIdleGapTriggerMinutes(prefixed, 45);
      const durationBlank = resolveSettingsGeneralMinEventDuration(blank, 30);
      const durationPrefixed = resolveSettingsGeneralMinEventDuration(prefixed, 30);

      // Assert
      expect(idleBlank).assertEqual(45);
      expect(idlePrefixed).assertEqual(18);
      expect(durationBlank).assertEqual(30);
      expect(durationPrefixed).assertEqual(18);
    });

    it('normal: settings_general_ai_poi_input_should_parse_prefix_and_clamp_negative_fallback', 0, () => {
      // Arrange
      const prefixedInput = '7 spots';
      const invalidInput = 'NaN';

      // Act
      const parsed = resolveSettingsGeneralAiPoiInput(prefixedInput, 4);
      const fallback = resolveSettingsGeneralAiPoiInput(invalidInput, -5);

      // Assert
      expect(parsed).assertEqual(7);
      expect(fallback).assertEqual(1);
    });

    it('conflict: settings_general_ai_poi_range_should_clamp_before_swapping_reversed_pairs', 0, () => {
      // Arrange
      const inputState = buildInputStateCG('20', '0', '12', '1', '-3', '30');
      const current = buildRangeConfigCG();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(1);
      expect(config.defaultMax).assertEqual(12);
      expect(config.soldierMin).assertEqual(1);
      expect(config.soldierMax).assertEqual(12);
      expect(config.leisureMin).assertEqual(1);
      expect(config.leisureMax).assertEqual(12);
    });

    it('regression: settings_general_ai_poi_range_should_keep_current_pair_when_both_inputs_invalid', 0, () => {
      // Arrange
      const inputState = buildInputStateCG('bad', ' ', 'x', 'y', '3', '4');
      const current = buildRangeConfigCG();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(current.defaultMin);
      expect(config.defaultMax).assertEqual(current.defaultMax);
      expect(config.soldierMin).assertEqual(current.soldierMin);
      expect(config.soldierMax).assertEqual(current.soldierMax);
      expect(config.leisureMin).assertEqual(3);
      expect(config.leisureMax).assertEqual(4);
    });

    it('boundary: settings_general_ai_poi_range_should_keep_equal_min_max_pairs', 0, () => {
      // Arrange
      const inputState = buildInputStateCG('5', '5', '8', '8', '3', '3');
      const current = buildRangeConfigCG();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(5);
      expect(config.defaultMax).assertEqual(5);
      expect(config.soldierMin).assertEqual(8);
      expect(config.soldierMax).assertEqual(8);
      expect(config.leisureMin).assertEqual(3);
      expect(config.leisureMax).assertEqual(3);
    });

    it('combined: settings_general_ai_poi_range_should_mix_current_fallback_parsed_and_swapped_pairs', 0, () => {
      // Arrange
      const inputState = buildInputStateCG('', '9', '6', 'bad', '11', '2');
      const current = buildRangeConfigCG();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(current.defaultMin);
      expect(config.defaultMax).assertEqual(9);
      expect(config.soldierMin).assertEqual(6);
      expect(config.soldierMax).assertEqual(current.soldierMax);
      expect(config.leisureMin).assertEqual(2);
      expect(config.leisureMax).assertEqual(11);
    });

    it('combined: settings_general_page_should_render_system_theme_with_disabled_idle_gap_inputs', 0, () => {
      // Arrange
      const page = createSettingsGeneralPageCG();
      page.loading = false;
      page.themeMode = 'system';
      page.effectiveTheme = 'light';
      page.weatherFeatureEnabled = true;
      page.enableIdleGapDetection = false;
      page.idleGapTriggerInput = '60';
      page.minEventDurationInput = '20';

      // Act
      const text = page.getThemeModeText();
      const palette = page.getThemePalette();
      page.initialRender();

      // Assert
      expect(text.length > 0).assertTrue();
      expect(palette !== null).assertTrue();
      expect(page.enableIdleGapDetection).assertFalse();
    });

    it('combined: settings_general_page_should_render_loading_dark_with_ai_range_inputs', 0, () => {
      // Arrange
      const page = createSettingsGeneralPageCG();
      page.loading = true;
      page.themeMode = 'dark';
      page.effectiveTheme = 'dark';
      page.weatherFeatureEnabled = false;
      page.enableIdleGapDetection = true;
      page.aiDefaultMinInput = '1';
      page.aiDefaultMaxInput = '12';
      page.aiSoldierMinInput = '10';
      page.aiSoldierMaxInput = '12';
      page.aiLeisureMinInput = '2';
      page.aiLeisureMaxInput = '3';

      // Act
      const text = page.getThemeModeText();
      page.initialRender();

      // Assert
      expect(text.length > 0).assertTrue();
      expect(page.loading).assertTrue();
      expect(page.weatherFeatureEnabled).assertFalse();
    });
  });
}
