import { describe, expect, it } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { UserProfileService } from '../main/ets/domain/strategy/UserProfileService';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';

class PreferencesMock {
  private readonly values: Map<string, Object> = new Map<string, Object>();

  async put(key: string, value: Object): Promise<void> {
    this.values.set(key, value);
  }

  async get(key: string, defaultValue: Object): Promise<Object> {
    const value = this.values.get(key);
    return value === undefined ? defaultValue : value;
  }

  async flush(): Promise<void> {
    return;
  }
}

function createProfile(): UserStrategyProfile {
  return {
    avgDensity: DEFAULT_USER_PROFILE.avgDensity,
    avgPace: DEFAULT_USER_PROFILE.avgPace,
    avgPreference: DEFAULT_USER_PROFILE.avgPreference,
    avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
    modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
    sampleCount: DEFAULT_USER_PROFILE.sampleCount,
    updatedAt: DEFAULT_USER_PROFILE.updatedAt,
    manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled === true,
    consistencyMatchCount: Number(DEFAULT_USER_PROFILE.consistencyMatchCount) > 0
      ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMatchCount))
      : 0,
    consistencyMismatchCount: Number(DEFAULT_USER_PROFILE.consistencyMismatchCount) > 0
      ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMismatchCount))
      : 0,
    lastConsistencyCheckAt: Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt) > 0
      ? Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt)
      : 0
  };
}

function ensurePreferenceMock(): PreferenceManager {
  const manager = PreferenceManager.getInstance();
  Reflect.set(manager, 'pref', new PreferencesMock());
  return manager;
}

export default function phase1ZeroHitBatchGTest() {
  describe('phase1ZeroHitBatchGTest', () => {
    it('normal: user_profile_record_usage_should_update_soldier_mode_frequency_and_ewma', 0, async () => {
      // Arrange
      const manager = ensurePreferenceMock();
      const profile = createProfile();
      profile.modeFrequency = '{}';
      profile.sampleCount = 2;
      profile.consistencyMatchCount = 0;
      profile.consistencyMismatchCount = 0;
      await manager.setUserStrategyProfile(profile);
      // Act
      await UserProfileService.recordStrategyUsage(1);
      const saved = await manager.getUserStrategyProfile();
      // Assert
      expect(saved.sampleCount).assertEqual(3);
      expect(saved.modeFrequency).assertEqual('{"-1":0,"0":0,"1":1,"2":0}');
      expect(saved.avgDensity > profile.avgDensity).assertTrue();
      expect(saved.consistencyMismatchCount).assertEqual(1);
    });

    it('boundary: user_profile_record_usage_custom_should_increase_match_when_equals_target', 0, async () => {
      // Arrange
      const manager = ensurePreferenceMock();
      const profile = createProfile();
      profile.modeFrequency = '{"0":2}';
      profile.sampleCount = 5;
      profile.consistencyMatchCount = 0;
      profile.consistencyMismatchCount = 0;
      await manager.setUserStrategyProfile(profile);
      const custom: ComposableStrategy = {
        density: DensityLevel.MEDIUM,
        pace: PaceLevel.BALANCED,
        preference: PreferenceType.BALANCED,
        energy: EnergyLevel.MEDIUM
      };
      // Act
      await UserProfileService.recordStrategyUsage(-1, custom);
      const saved = await manager.getUserStrategyProfile();
      // Assert
      expect(saved.modeFrequency).assertEqual('{"-1":1,"0":2,"1":0,"2":0}');
      expect(saved.consistencyMatchCount).assertEqual(1);
      expect(saved.consistencyMismatchCount).assertEqual(0);
    });

    it('invalid: user_profile_recommend_should_return_null_below_threshold_without_manual_override', 0, async () => {
      // Arrange
      const manager = ensurePreferenceMock();
      const profile = createProfile();
      profile.sampleCount = 2;
      profile.manualOverrideEnabled = false;
      await manager.setUserStrategyProfile(profile);
      // Act
      const result = await UserProfileService.getRecommendedStrategy();
      // Assert
      expect(result === null).assertTrue();
    });

    it('conflict: user_profile_hint_should_still_return_text_when_manual_override_enabled', 0, async () => {
      // Arrange
      const manager = ensurePreferenceMock();
      const profile = createProfile();
      profile.sampleCount = 0;
      profile.manualOverrideEnabled = true;
      profile.modeFrequency = '{"1":3}';
      await manager.setUserStrategyProfile(profile);
      // Act
      const hint = await UserProfileService.getRecommendationHint();
      // Assert
      expect(hint.length > 0).assertTrue();
    });

    it('regression: user_profile_recommend_should_clamp_strategy_values_into_valid_range', 0, async () => {
      // Arrange
      const manager = ensurePreferenceMock();
      const profile = createProfile();
      profile.sampleCount = 6;
      profile.avgDensity = 99;
      profile.avgPace = -10;
      profile.avgPreference = 100;
      profile.avgEnergy = -2;
      await manager.setUserStrategyProfile(profile);
      // Act
      const result = await UserProfileService.getRecommendedStrategy();
      // Assert
      expect(result !== null).assertTrue();
      expect(result!.density).assertEqual(2);
      expect(result!.pace).assertEqual(0);
      expect(result!.preference).assertEqual(4);
      expect(result!.energy).assertEqual(0);
    });

    it('combined: user_profile_record_usage_should_handle_default_mode_and_safe_counters', 0, async () => {
      // Arrange
      const manager = ensurePreferenceMock();
      const profile = createProfile();
      profile.modeFrequency = '{"-1":2,"0":3,"1":1,"2":4}';
      profile.sampleCount = 1;
      profile.consistencyMatchCount = Number.NaN;
      profile.consistencyMismatchCount = -8;
      await manager.setUserStrategyProfile(profile);
      // Act
      await UserProfileService.recordStrategyUsage(0);
      const saved = await manager.getUserStrategyProfile();
      // Assert
      expect(saved.sampleCount).assertEqual(2);
      expect(saved.modeFrequency).assertEqual('{"-1":2,"0":4,"1":1,"2":4}');
      expect(saved.consistencyMatchCount).assertEqual(1);
      expect(saved.consistencyMismatchCount).assertEqual(0);
    });
  });
}
