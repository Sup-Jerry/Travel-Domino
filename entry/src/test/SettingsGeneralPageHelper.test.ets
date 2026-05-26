import { describe, it, expect } from '@ohos/hypium';
import {
  buildSettingsGeneralAiPoiRangeConfig,
  createSettingsGeneralPageForTest,
  resolveSettingsGeneralAiPoiInput,
  resolveSettingsGeneralIdleGapTriggerMinutes,
  resolveSettingsGeneralMinEventDuration,
  resolveSettingsGeneralThemeModeText,
  SettingsGeneralAiPoiInputState
} from '../main/ets/pages/SettingsGeneralPage';
import { AiDailyPoiRangeConfig, PreferenceManager } from '../main/ets/common/utils/PreferenceManager';

interface SettingsGeneralPagePrivateTest {
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
  getThemeModeText(): string;
  onWeatherFeatureChanged(value: boolean): Promise<void>;
  onIdleGapDetectionChanged(value: boolean): Promise<void>;
  safeShowToast(message: string): void;
}

interface SettingsGeneralPreferencePortTest {
  setWeatherFeatureEnabled(value: boolean): Promise<void>;
  isWeatherFeatureEnabled(): Promise<boolean>;
  setIdleGapDetectionEnabled(value: boolean): Promise<void>;
  getIdleGapDetectionEnabled(): Promise<boolean>;
}

class SettingsGeneralPreferenceStubTest implements SettingsGeneralPreferencePortTest {
  weatherEnabled: boolean = false;
  idleGapEnabled: boolean = false;

  async setWeatherFeatureEnabled(value: boolean): Promise<void> {
    this.weatherEnabled = value;
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    return this.weatherEnabled;
  }

  async setIdleGapDetectionEnabled(value: boolean): Promise<void> {
    this.idleGapEnabled = value;
  }

  async getIdleGapDetectionEnabled(): Promise<boolean> {
    return this.idleGapEnabled;
  }
}

function createSettingsGeneralPagePrivateForTest(): SettingsGeneralPagePrivateTest {
  return createSettingsGeneralPageForTest() as SettingsGeneralPagePrivateTest;
}

function buildSettingsGeneralInputStateForTest(
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

function buildSettingsGeneralRangeConfigForTest(): AiDailyPoiRangeConfig {
  return {
    defaultMin: 4,
    defaultMax: 6,
    soldierMin: 5,
    soldierMax: 8,
    leisureMin: 3,
    leisureMax: 5
  };
}

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

    it('normal: settings_general_ai_poi_range_should_keep_ordered_values', 0, () => {
      // Arrange
      const inputState = buildSettingsGeneralInputStateForTest('4', '7', '6', '9', '2', '5');
      const current = buildSettingsGeneralRangeConfigForTest();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(4);
      expect(config.defaultMax).assertEqual(7);
      expect(config.soldierMin).assertEqual(6);
      expect(config.soldierMax).assertEqual(9);
      expect(config.leisureMin).assertEqual(2);
      expect(config.leisureMax).assertEqual(5);
    });

    it('boundary: settings_general_ai_poi_range_should_swap_min_and_max_when_reversed', 0, () => {
      // Arrange
      const inputState = buildSettingsGeneralInputStateForTest('9', '3', '10', '6', '5', '1');
      const current = buildSettingsGeneralRangeConfigForTest();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(3);
      expect(config.defaultMax).assertEqual(9);
      expect(config.soldierMin).assertEqual(6);
      expect(config.soldierMax).assertEqual(10);
      expect(config.leisureMin).assertEqual(1);
      expect(config.leisureMax).assertEqual(5);
    });

    it('invalid: settings_general_ai_poi_range_should_fallback_for_nan_inputs', 0, () => {
      // Arrange
      const inputState = buildSettingsGeneralInputStateForTest('abc', '', 'x', '8', '3', 'bad');
      const current = buildSettingsGeneralRangeConfigForTest();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(current.defaultMin);
      expect(config.defaultMax).assertEqual(current.defaultMax);
      expect(config.soldierMin).assertEqual(5);
      expect(config.soldierMax).assertEqual(8);
      expect(config.leisureMin).assertEqual(3);
      expect(config.leisureMax).assertEqual(5);
    });

    it('combined: settings_general_page_should_render_light_enabled_state', 0, () => {
      // Arrange
      const page = createSettingsGeneralPagePrivateForTest();
      page.loading = false;
      page.themeMode = 'light';
      page.effectiveTheme = 'light';
      page.weatherFeatureEnabled = true;
      page.enableIdleGapDetection = true;

      // Act
      const themeText = page.getThemeModeText();
      page.initialRender();

      // Assert
      expect(themeText).assertEqual('浅色');
      expect(page.enableIdleGapDetection).assertTrue();
    });

    it('combined: settings_general_page_should_render_dark_disabled_state', 0, () => {
      // Arrange
      const page = createSettingsGeneralPagePrivateForTest();
      page.loading = true;
      page.themeMode = 'dark';
      page.effectiveTheme = 'dark';
      page.weatherFeatureEnabled = false;
      page.enableIdleGapDetection = false;
      page.idleGapTriggerInput = '90';
      page.minEventDurationInput = '15';
      page.aiDefaultMinInput = '2';
      page.aiDefaultMaxInput = '4';

      // Act
      const themeText = page.getThemeModeText();
      page.initialRender();

      // Assert
      expect(themeText).assertEqual('深色');
      expect(page.weatherFeatureEnabled).assertFalse();
    });

    it('boundary: settings_general_numeric_inputs_should_parse_prefix_and_floor_decimals', 0, () => {
      // Arrange
      const idleInput = '12abc';
      const durationInput = '8.9';
      // Act
      const idleValue = resolveSettingsGeneralIdleGapTriggerMinutes(idleInput, 45);
      const durationValue = resolveSettingsGeneralMinEventDuration(durationInput, 30);
      // Assert
      expect(idleValue).assertEqual(12);
      expect(durationValue).assertEqual(8);
    });

    it('boundary: settings_general_ai_poi_input_should_clamp_low_and_high_values', 0, () => {
      // Arrange
      const lowInput = '-2';
      const highInput = '99';
      // Act
      const lowValue = resolveSettingsGeneralAiPoiInput(lowInput, 6);
      const highValue = resolveSettingsGeneralAiPoiInput(highInput, 6);
      // Assert
      expect(lowValue).assertEqual(1);
      expect(highValue).assertEqual(12);
    });

    it('invalid: settings_general_ai_poi_input_should_normalize_invalid_fallback_to_one', 0, () => {
      // Arrange
      const input = 'bad';
      const fallback = Number.NaN;
      // Act
      const value = resolveSettingsGeneralAiPoiInput(input, fallback);
      // Assert
      expect(value).assertEqual(1);
    });

    it('combined: settings_general_ai_poi_range_should_mix_prefix_decimal_and_invalid_values', 0, () => {
      // Arrange
      const inputState = buildSettingsGeneralInputStateForTest('2abc', '6.9', 'bad', '99', '-3', '');
      const current = buildSettingsGeneralRangeConfigForTest();

      // Act
      const config = buildSettingsGeneralAiPoiRangeConfig(inputState, current);

      // Assert
      expect(config.defaultMin).assertEqual(2);
      expect(config.defaultMax).assertEqual(6);
      expect(config.soldierMin).assertEqual(5);
      expect(config.soldierMax).assertEqual(12);
      expect(config.leisureMin).assertEqual(1);
      expect(config.leisureMax).assertEqual(5);
    });

    it('combined: settings_general_toggle_handlers_should_cover_weather_true_false_and_idle_false_toasts', 0, async () => {
      // Arrange
      const page = createSettingsGeneralPagePrivateForTest();
      const preference = new SettingsGeneralPreferenceStubTest();
      const originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as (() => Object);
      const toastMessages: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });
      Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => preference as Object);

      try {
        // Act
        preference.weatherEnabled = true;
        await page.onWeatherFeatureChanged(true);
        preference.weatherEnabled = false;
        await page.onWeatherFeatureChanged(false);
        preference.idleGapEnabled = false;
        await page.onIdleGapDetectionChanged(false);
      } finally {
        Reflect.set(PreferenceManager as Object, 'getInstance', originalGetInstance);
      }

      // Assert
      expect(toastMessages.length).assertEqual(3);
      expect(toastMessages[0]).assertEqual('已开启天气功能');
      expect(toastMessages[1]).assertEqual('已关闭天气功能');
      expect(toastMessages[2]).assertEqual('已关闭空闲时间检测');
      expect(page.weatherFeatureEnabled).assertFalse();
      expect(page.enableIdleGapDetection).assertFalse();
    });
  });
}
