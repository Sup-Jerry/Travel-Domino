import { describe, it, expect } from '@ohos/hypium';
import {
  createSettingsPreferenceInsightsPageForTest,
  ModeFrequencyView,
  ModeBarItem
} from '../main/ets/pages/SettingsPreferenceInsightsPage';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';

interface SettingsPreferenceInsightsPagePrivateDI {
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
  aboutToAppear(): void;
  safeShowToast(message: string): void;
  syncEditableState(): void;
  reloadInsights(): Promise<void>;
  saveWeatherPreference(): Promise<void>;
  saveAiProfile(): Promise<void>;
  parseModeFrequency(raw: string): ModeFrequencyView;
  parseModeCount(raw: string, key: string): number;
  getDensityText(value: number): string;
  getPaceText(value: number): string;
  getPreferenceText(value: number): string;
  getEnergyText(value: number): string;
  getModeUsageItems(): ModeBarItem[];
  getModeTotalCount(): number;
  getPercentText(count: number, total: number): string;
  getPercentWidth(count: number, total: number): string;
  getMatchCount(): number;
  getMismatchCount(): number;
  getConsistencyRateText(): string;
}

class PreferenceInsightsMockDI {
  public weatherEnabled: boolean = true;
  public weatherPreference: WeatherUserPreference = {
    heatSensitivity: 1,
    rainSensitivity: 1,
    weatherRiskTolerance: 1
  };
  public profile: UserStrategyProfile = buildProfileDI();
  public failMethod: string = '';
  public setCalls: string[] = [];

  async isWeatherFeatureEnabled(): Promise<boolean> {
    this.throwIfNeeded('isWeatherFeatureEnabled');
    return this.weatherEnabled;
  }

  async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    this.throwIfNeeded('getWeatherUserPreference');
    return this.weatherPreference;
  }

  async setWeatherUserPreference(value: WeatherUserPreference): Promise<void> {
    this.setCalls.push(`setWeather:${value.heatSensitivity}-${value.rainSensitivity}-${value.weatherRiskTolerance}`);
    this.throwIfNeeded('setWeatherUserPreference');
    this.weatherPreference = value;
  }

  async getUserStrategyProfile(): Promise<UserStrategyProfile> {
    this.throwIfNeeded('getUserStrategyProfile');
    return this.profile;
  }

  async setUserStrategyProfile(value: UserStrategyProfile): Promise<void> {
    this.setCalls.push(`setProfile:${value.avgDensity}-${value.avgPace}-${value.avgPreference}-${value.avgEnergy}`);
    this.throwIfNeeded('setUserStrategyProfile');
    this.profile = value;
  }

  private throwIfNeeded(method: string): void {
    if (this.failMethod === method) {
      throw new Error(`${method}_failed_di`);
    }
  }
}

class StaticPatchDI {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

function buildWeatherDI(heat: 0 | 1 | 2, rain: 0 | 1 | 2, tolerance: 0 | 1 | 2): WeatherUserPreference {
  return {
    heatSensitivity: heat,
    rainSensitivity: rain,
    weatherRiskTolerance: tolerance
  };
}

function buildProfileDI(overrides?: Partial<UserStrategyProfile>): UserStrategyProfile {
  const profile: UserStrategyProfile = {
    avgDensity: 1,
    avgPace: 1,
    avgPreference: 0,
    avgEnergy: 1,
    modeFrequency: '{"0":2,"1":3,"2":1,"-1":4}',
    sampleCount: 10,
    updatedAt: 1710000000000,
    manualOverrideEnabled: false,
    consistencyMatchCount: 6,
    consistencyMismatchCount: 2,
    lastConsistencyCheckAt: 1710000000000
  };
  if (overrides) {
    if (overrides.avgDensity !== undefined) {
      profile.avgDensity = overrides.avgDensity;
    }
    if (overrides.avgPace !== undefined) {
      profile.avgPace = overrides.avgPace;
    }
    if (overrides.avgPreference !== undefined) {
      profile.avgPreference = overrides.avgPreference;
    }
    if (overrides.avgEnergy !== undefined) {
      profile.avgEnergy = overrides.avgEnergy;
    }
    if (overrides.modeFrequency !== undefined) {
      profile.modeFrequency = overrides.modeFrequency;
    }
    if (overrides.sampleCount !== undefined) {
      profile.sampleCount = overrides.sampleCount;
    }
    if (overrides.updatedAt !== undefined) {
      profile.updatedAt = overrides.updatedAt;
    }
    if (overrides.manualOverrideEnabled !== undefined) {
      profile.manualOverrideEnabled = overrides.manualOverrideEnabled;
    }
    if (overrides.consistencyMatchCount !== undefined) {
      profile.consistencyMatchCount = overrides.consistencyMatchCount;
    }
    if (overrides.consistencyMismatchCount !== undefined) {
      profile.consistencyMismatchCount = overrides.consistencyMismatchCount;
    }
    if (overrides.lastConsistencyCheckAt !== undefined) {
      profile.lastConsistencyCheckAt = overrides.lastConsistencyCheckAt;
    }
  }
  return profile;
}

function createPageDI(): SettingsPreferenceInsightsPagePrivateDI {
  return createSettingsPreferenceInsightsPageForTest() as SettingsPreferenceInsightsPagePrivateDI;
}

function patchPreferenceDI(pref: PreferenceInsightsMockDI): StaticPatchDI {
  return new StaticPatchDI(PreferenceManager as Object, 'getInstance', (): PreferenceInsightsMockDI => pref);
}

async function flushMicrotasksDI(): Promise<void> {
  for (let i = 0; i < 20; i += 1) {
    await Promise.resolve();
  }
}

export default function phase2BatchDITest() {
  describe('phase2BatchDITest', () => {
    it('normal: preference_insights_reload_should_apply_weather_profile_and_editable_state', 0, async () => {
      // Arrange
      const pref = new PreferenceInsightsMockDI();
      pref.weatherEnabled = false;
      pref.weatherPreference = buildWeatherDI(2, 0, 1);
      pref.profile = buildProfileDI({ avgDensity: 2, avgPace: 0, avgPreference: 4, avgEnergy: 2 });
      const patch = patchPreferenceDI(pref);
      const page = createPageDI();

      // Act
      await page.reloadInsights();
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.weatherFeatureEnabled).assertFalse();
      expect(page.editHeatSensitivity).assertEqual(2);
      expect(page.editRainSensitivity).assertEqual(0);
      expect(page.editPreference).assertEqual(4);
      expect(page.modeFrequency.modeCustom).assertEqual(4);
    });

    it('boundary: preference_insights_about_to_appear_should_finish_async_reload', 0, async () => {
      // Arrange
      const pref = new PreferenceInsightsMockDI();
      pref.profile = buildProfileDI({ modeFrequency: '{"0":1}' });
      const patch = patchPreferenceDI(pref);
      const page = createPageDI();

      // Act
      page.aboutToAppear();
      await flushMicrotasksDI();
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.modeFrequency.modeDefault).assertEqual(1);
    });

    it('invalid: preference_insights_reload_should_clear_loading_when_preference_read_fails', 0, async () => {
      // Arrange
      const pref = new PreferenceInsightsMockDI();
      pref.failMethod = 'getUserStrategyProfile';
      const patch = patchPreferenceDI(pref);
      const page = createPageDI();
      page.loading = false;

      // Act
      await page.reloadInsights();
      page.safeShowToast('di_toast');
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.weatherPreference.heatSensitivity).assertEqual(1);
    });

    it('conflict: preference_insights_weather_save_should_clamp_inputs_and_persist', 0, async () => {
      // Arrange
      const pref = new PreferenceInsightsMockDI();
      const patch = patchPreferenceDI(pref);
      const page = createPageDI();
      page.editHeatSensitivity = 9;
      page.editRainSensitivity = -3;
      page.editWeatherRiskTolerance = 1;

      // Act
      await page.saveWeatherPreference();
      patch.restore();

      // Assert
      expect(page.savingWeather).assertFalse();
      expect(pref.weatherPreference.heatSensitivity).assertEqual(2);
      expect(pref.weatherPreference.rainSensitivity).assertEqual(0);
      expect(pref.setCalls.indexOf('setWeather:2-0-1') >= 0).assertTrue();
    });

    it('regression: preference_insights_weather_save_should_clear_saving_when_write_fails', 0, async () => {
      // Arrange
      const pref = new PreferenceInsightsMockDI();
      pref.failMethod = 'setWeatherUserPreference';
      const patch = patchPreferenceDI(pref);
      const page = createPageDI();
      page.savingWeather = false;

      // Act
      await page.saveWeatherPreference();
      patch.restore();

      // Assert
      expect(page.savingWeather).assertFalse();
      expect(pref.weatherPreference.heatSensitivity).assertEqual(1);
    });

    it('combined: preference_insights_ai_profile_save_should_enable_manual_profile_and_keep_counts', 0, async () => {
      // Arrange
      const pref = new PreferenceInsightsMockDI();
      pref.profile = buildProfileDI({
        sampleCount: 7,
        consistencyMatchCount: 3.8,
        consistencyMismatchCount: 2.1,
        lastConsistencyCheckAt: 123
      });
      const patch = patchPreferenceDI(pref);
      const page = createPageDI();
      page.profile = pref.profile;
      page.editDensity = 2;
      page.editPace = 0;
      page.editPreference = 4;
      page.editEnergy = 2;

      // Act
      await page.saveAiProfile();
      patch.restore();

      // Assert
      expect(page.savingProfile).assertFalse();
      expect(pref.profile.manualOverrideEnabled).assertTrue();
      expect(pref.profile.avgDensity).assertEqual(2);
      expect(pref.profile.avgPace).assertEqual(0);
      expect(pref.profile.avgPreference).assertEqual(4);
      expect(pref.profile.consistencyMatchCount).assertEqual(3);
      expect(pref.profile.consistencyMismatchCount).assertEqual(2);
    });

    it('combined: preference_insights_private_derivations_should_cover_labels_counts_and_widths', 0, () => {
      // Arrange
      const page = createPageDI();
      page.profile = buildProfileDI({ consistencyMatchCount: -5, consistencyMismatchCount: 4 });
      page.modeFrequency = page.parseModeFrequency('{"0":2,"1":2,"2":1,"-1":1}');

      // Act
      const customCount = page.parseModeCount('{"-1":6}', '-1');
      const density = page.getDensityText(2);
      const pace = page.getPaceText(0);
      const preference = page.getPreferenceText(3);
      const energy = page.getEnergyText(1);
      const items = page.getModeUsageItems();
      const total = page.getModeTotalCount();
      const percent = page.getPercentText(items[0].count, total);
      const width = page.getPercentWidth(1, total);
      const match = page.getMatchCount();
      const mismatch = page.getMismatchCount();
      const rate = page.getConsistencyRateText();

      // Assert
      expect(customCount).assertEqual(6);
      expect(density.length > 0).assertTrue();
      expect(pace.length > 0).assertTrue();
      expect(preference.length > 0).assertTrue();
      expect(energy.length > 0).assertTrue();
      expect(items.length).assertEqual(4);
      expect(percent.length > 0).assertTrue();
      expect(width.length > 0).assertTrue();
      expect(match).assertEqual(0);
      expect(mismatch).assertEqual(4);
      expect(rate).assertEqual('0%');
    });
  });
}
