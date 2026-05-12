import { describe, expect, it } from '@ohos/hypium';
import { WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';
import {
  ModeFrequencyView,
  buildSettingsPreferenceModeUsageItems,
  clampSettingsPreferenceInt,
  createSettingsPreferenceInsightsPageForTest,
  normalizeSettingsPreferenceCount,
  parseSettingsPreferenceModeCount,
  parseSettingsPreferenceModeFrequency,
  resolveSettingsPreferenceConsistencyRateText,
  resolveSettingsPreferenceDominantModeText,
  resolveSettingsPreferenceModeTotalCount,
  resolveSettingsPreferencePercentText,
  resolveSettingsPreferencePercentWidth,
  resolveSettingsPreferenceStrategySummary
} from '../main/ets/pages/SettingsPreferenceInsightsPage';

interface SettingsPreferencePagePrivateEF {
  loading: boolean;
  savingWeather: boolean;
  savingProfile: boolean;
  weatherFeatureEnabled: boolean;
  weatherPreference: WeatherUserPreference;
  profile: UserStrategyProfile;
  modeFrequency: ModeFrequencyView;
  editHeatSensitivity: number;
  editRainSensitivity: number;
  editWeatherRiskTolerance: number;
  editDensity: number;
  editPace: number;
  editPreference: number;
  editEnergy: number;
  effectiveTheme: string;
  syncEditableState(): void;
  parseModeFrequency(raw: string): ModeFrequencyView;
  getModeTotalCount(): number;
  getModeUsageItems(): Object[];
  getPercentText(count: number, total: number): string;
  getPercentWidth(count: number, total: number): string;
  getConsistencyRateText(): string;
  formatUpdatedAt(timestamp: number): string;
  initialRender(): void;
}

function buildWeatherPreferenceEF(): WeatherUserPreference {
  return {
    heatSensitivity: 2,
    rainSensitivity: 0,
    weatherRiskTolerance: 1
  };
}

function buildProfileEF(): UserStrategyProfile {
  return {
    avgDensity: 2,
    avgPace: 0,
    avgPreference: 4,
    avgEnergy: 2,
    modeFrequency: '{"0":4,"1":3,"2":2,"-1":1}',
    sampleCount: 10,
    updatedAt: 1710000000000,
    manualOverrideEnabled: true,
    consistencyMatchCount: 8,
    consistencyMismatchCount: 2,
    lastConsistencyCheckAt: 1710000000000
  };
}

export default function phase2BatchEFTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEF_settings_preference_extra', () => {
    it('normal: settings_preference_count_helpers_should_floor_positive_decimal_values', 0, () => {
      // Arrange
      const rawCount = 7.9;
      const rawJson = '{"1":6,"0":4}';

      // Act
      const normalized = normalizeSettingsPreferenceCount(rawCount);
      const soldierCount = parseSettingsPreferenceModeCount(rawJson, '1');

      // Assert
      expect(normalized).assertEqual(7);
      expect(soldierCount).assertEqual(6);
    });

    it('boundary: settings_preference_clamp_should_round_before_clamping', 0, () => {
      // Arrange
      const roundUp = 1.6;
      const roundDown = 1.4;

      // Act
      const up = clampSettingsPreferenceInt(roundUp, 0, 2);
      const down = clampSettingsPreferenceInt(roundDown, 0, 2);

      // Assert
      expect(up).assertEqual(2);
      expect(down).assertEqual(1);
    });

    it('invalid: settings_preference_mode_frequency_should_return_zero_view_for_malformed_json', 0, () => {
      // Arrange
      const raw = '{bad json}';

      // Act
      const freq = parseSettingsPreferenceModeFrequency(raw);
      const total = resolveSettingsPreferenceModeTotalCount(freq);

      // Assert
      expect(freq.modeCustom).assertEqual(0);
      expect(freq.modeDefault).assertEqual(0);
      expect(freq.modeSoldier).assertEqual(0);
      expect(freq.modeLeisure).assertEqual(0);
      expect(total).assertEqual(0);
    });

    it('conflict: settings_preference_percent_width_should_enforce_min_width_for_tiny_positive_share', 0, () => {
      // Arrange
      const count = 1;
      const total = 1000;

      // Act
      const text = resolveSettingsPreferencePercentText(count, total);
      const width = resolveSettingsPreferencePercentWidth(count, total);

      // Assert
      expect(text).assertEqual('0.1%');
      expect(width).assertEqual('6%');
    });

    it('regression: settings_preference_consistency_rate_should_return_empty_data_text_when_total_zero', 0, () => {
      // Arrange
      const match = 0;
      const mismatch = 0;

      // Act
      const text = resolveSettingsPreferenceConsistencyRateText(match, mismatch);

      // Assert
      expect(text.trim().length > 0).assertTrue();
      expect(text.indexOf('%') < 0).assertTrue();
    });

    it('combined: settings_preference_dominant_mode_should_return_none_when_sample_count_zero', 0, () => {
      // Arrange
      const freq: ModeFrequencyView = {
        modeCustom: 9,
        modeDefault: 0,
        modeSoldier: 0,
        modeLeisure: 0
      };

      // Act
      const dominant = resolveSettingsPreferenceDominantModeText(freq, 0);

      // Assert
      expect(dominant.trim().length > 0).assertTrue();
      expect(dominant).assertEqual(resolveSettingsPreferenceDominantModeText({
        modeCustom: 0,
        modeDefault: 0,
        modeSoldier: 0,
        modeLeisure: 0
      }, 0));
    });

    it('combined: settings_preference_strategy_summary_should_change_after_sample_threshold', 0, () => {
      // Arrange
      const low = buildProfileEF();
      const enough = buildProfileEF();
      low.sampleCount = 1;
      low.manualOverrideEnabled = false;
      enough.sampleCount = 3;
      enough.manualOverrideEnabled = false;

      // Act
      const lowSummary = resolveSettingsPreferenceStrategySummary(low);
      const enoughSummary = resolveSettingsPreferenceStrategySummary(enough);

      // Assert
      expect(lowSummary.length > 0).assertTrue();
      expect(enoughSummary.length > 0).assertTrue();
      expect(lowSummary === enoughSummary).assertFalse();
    });

    it('combined: settings_preference_mode_usage_items_should_keep_default_soldier_leisure_custom_order', 0, () => {
      // Arrange
      const freq: ModeFrequencyView = {
        modeCustom: 1,
        modeDefault: 4,
        modeSoldier: 3,
        modeLeisure: 2
      };

      // Act
      const items = buildSettingsPreferenceModeUsageItems(freq);

      // Assert
      expect(items.length).assertEqual(4);
      expect(items[0].count).assertEqual(4);
      expect(items[1].count).assertEqual(3);
      expect(items[2].count).assertEqual(2);
      expect(items[3].count).assertEqual(1);
    });

    it('combined: settings_preference_instance_should_sync_edit_state_and_render_non_empty_profile', 0, () => {
      // Arrange
      const page = createSettingsPreferenceInsightsPageForTest() as SettingsPreferencePagePrivateEF;
      page.loading = false;
      page.savingWeather = true;
      page.savingProfile = false;
      page.weatherFeatureEnabled = true;
      page.weatherPreference = buildWeatherPreferenceEF();
      page.profile = buildProfileEF();
      page.modeFrequency = page.parseModeFrequency(page.profile.modeFrequency);
      page.effectiveTheme = 'dark';

      // Act
      page.syncEditableState();
      const total = page.getModeTotalCount();
      const items = page.getModeUsageItems();
      const percent = page.getPercentText(1, total);
      const width = page.getPercentWidth(1, total);
      const rate = page.getConsistencyRateText();
      const updatedAt = page.formatUpdatedAt(page.profile.updatedAt);
      page.initialRender();

      // Assert
      expect(page.editHeatSensitivity).assertEqual(2);
      expect(page.editRainSensitivity).assertEqual(0);
      expect(page.editWeatherRiskTolerance).assertEqual(1);
      expect(total).assertEqual(10);
      expect(items.length).assertEqual(4);
      expect(percent).assertEqual('10%');
      expect(width).assertEqual('10%');
      expect(rate).assertEqual('80%');
      expect(updatedAt.length > 0).assertTrue();
    });
  });
}
