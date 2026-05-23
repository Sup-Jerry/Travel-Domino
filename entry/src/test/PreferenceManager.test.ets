import { describe, it, expect } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { AvatarProfile } from '../main/ets/domain/auth/AvatarModels';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';

class PreferenceStoreMockForPreferenceTest {
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

  setRaw(key: string, value: Object): void {
    this.values.set(key, value);
  }
}

function attachPreferenceStoreForPreferenceTest(): PreferenceStoreMockForPreferenceTest {
  const store = new PreferenceStoreMockForPreferenceTest();
  const manager = PreferenceManager.getInstance();
  Reflect.set(manager as Object, 'pref', store as Object);
  return store;
}

function createStrategyProfileForPreferenceTest(): UserStrategyProfile {
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

export default function preferenceManagerTest() {
  describe('preferenceManagerTest', () => {
    it('boundary: min_duration_should_fallback_and_clip', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(PreferenceManager.normalizeMinEventDuration('bad')).assertEqual(30);
      expect(PreferenceManager.normalizeMinEventDuration(-5)).assertEqual(1);
      expect(PreferenceManager.normalizeMinEventDuration(9999)).assertEqual(720);
    });

    it('boundary: idle_gap_trigger_should_fallback_and_clip', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(PreferenceManager.normalizeIdleGapTriggerMinutes('oops')).assertEqual(45);
      expect(PreferenceManager.normalizeIdleGapTriggerMinutes(0)).assertEqual(1);
      expect(PreferenceManager.normalizeIdleGapTriggerMinutes(999)).assertEqual(720);
    });

    it('boundary: theme_mode_should_fallback_to_system', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(PreferenceManager.normalizeThemeMode('light')).assertEqual('light');
      expect(PreferenceManager.normalizeThemeMode('abc')).assertEqual('system');
      expect(PreferenceManager.normalizeThemeMode(1)).assertEqual('system');
    });

    it('boundary: weather_pref_level_should_fallback_and_clip', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(PreferenceManager.normalizeWeatherPreferenceLevel('bad')).assertEqual(1);
      expect(PreferenceManager.normalizeWeatherPreferenceLevel(-1)).assertEqual(0);
      expect(PreferenceManager.normalizeWeatherPreferenceLevel(99)).assertEqual(2);
    });

    it('boundary: avatar_profile_key_should_be_scoped_by_userid', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(PreferenceManager.buildAvatarProfileKey('u_123')).assertEqual('avatarProfile:u_123');
      expect(PreferenceManager.buildAvatarProfileKey('')).assertEqual('avatarProfile:guest_local');
    });
  });
  describe('unit_test_case_generator_autofill_PreferenceManager', () => {
    it('normal: amap_route_api_flag_should_only_accept_true_boolean', 0, () => {
      // Arrange
      const enabled = PreferenceManager.normalizeAmapRouteApiEnabled(true);
      const disabledByString = PreferenceManager.normalizeAmapRouteApiEnabled('true');

      // Act
      const disabledByFalse = PreferenceManager.normalizeAmapRouteApiEnabled(false);

      // Assert
      expect(enabled).assertTrue();
      expect(disabledByString).assertFalse();
      expect(disabledByFalse).assertFalse();
    });

    it('invalid: ai_poi_count_should_fallback_and_clip_for_invalid_values', 0, () => {
      // Arrange
      const invalidText = 'oops';
      const negative = -3;
      const oversized = 99;

      // Act
      const fallbackValue = PreferenceManager.normalizeAiPoiCount(invalidText, 4);
      const minClamped = PreferenceManager.normalizeAiPoiCount(negative, 4);
      const maxClamped = PreferenceManager.normalizeAiPoiCount(oversized, 4);

      // Assert
      expect(fallbackValue).assertEqual(4);
      expect(minClamped).assertEqual(1);
      expect(maxClamped).assertEqual(12);
    });

    it('conflict: profile_cache_key_should_use_trimmed_account_id_and_guest_fallback', 0, () => {
      // Arrange
      const trimmedAccountId = '  acc_conflict  ';
      const blankAccountId = '   ';

      // Act
      const trimmedKey = PreferenceManager.buildProfileCacheKey(trimmedAccountId);
      const blankKey = PreferenceManager.buildProfileCacheKey(blankAccountId);

      // Assert
      expect(trimmedKey).assertEqual('profile_cache_acc_conflict');
      expect(blankKey).assertEqual('profile_cache_guest_local');
    });

    it('regression: avatar_profile_key_should_trim_user_id_before_prefixing', 0, () => {
      // Arrange
      const rawUserId = '  user_regression  ';

      // Act
      const key = PreferenceManager.buildAvatarProfileKey(rawUserId);

      // Assert
      expect(key).assertEqual('avatarProfile:user_regression');
    });

    it('combined: preference_normalizers_should_coordinate_theme_weather_and_duration_outputs', 0, () => {
      // Arrange
      const rawTheme = 'dark';
      const rawWeatherLevel = 2.9;
      const rawDuration = 15.7;
      const rawGap = -100;

      // Act
      const theme = PreferenceManager.normalizeThemeMode(rawTheme);
      const weatherLevel = PreferenceManager.normalizeWeatherPreferenceLevel(rawWeatherLevel);
      const duration = PreferenceManager.normalizeMinEventDuration(rawDuration);
      const idleGap = PreferenceManager.normalizeIdleGapTriggerMinutes(rawGap);

      // Assert
      expect(theme).assertEqual('dark');
      expect(weatherLevel).assertEqual(2);
      expect(duration).assertEqual(15);
      expect(idleGap).assertEqual(1);
    });

    it('boundary: preference_manager_set_theme_mode_should_preserve_valid_mode', 0, async () => {
      // Arrange
      const store = attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();

      // Act
      await manager.setThemeMode('light');
      const saved = await manager.getValue(PreferenceManager.KEY_THEME_MODE, '');

      // Assert
      expect(String(saved)).assertEqual('light');
      expect(String(await store.get(PreferenceManager.KEY_THEME_MODE, ''))).assertEqual('light');
    });

    it('boundary: preference_manager_get_avatar_profile_should_return_fallback_for_empty_raw', 0, async () => {
      // Arrange
      attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();

      // Act
      const profile = await manager.getAvatarProfile('   ');

      // Assert
      expect(profile.userId).assertEqual('guest_local');
      expect(profile.localUri).assertEqual('');
      expect(profile.compressedUri).assertEqual('');
      expect(profile.cloudUrl).assertEqual('');
      expect(profile.uploadState).assertEqual('EMPTY');
      expect(profile.updatedAt).assertEqual(0);
    });

    it('invalid: preference_manager_get_avatar_profile_should_sanitize_partial_snapshot_fields', 0, async () => {
      // Arrange
      const store = attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();
      store.setRaw(
        PreferenceManager.buildAvatarProfileKey('origin_avatar'),
        JSON.stringify({
          userId: '',
          localUri: 123,
          compressedUri: null,
          cloudUrl: false,
          uploadState: 'BROKEN',
          updatedAt: 'oops'
        }) as Object
      );

      // Act
      const profile = await manager.getAvatarProfile(' origin_avatar ');

      // Assert
      expect(profile.userId).assertEqual('origin_avatar');
      expect(profile.localUri).assertEqual('');
      expect(profile.compressedUri).assertEqual('');
      expect(profile.cloudUrl).assertEqual('');
      expect(profile.uploadState).assertEqual('EMPTY');
      expect(profile.updatedAt).assertEqual(0);
    });

    it('boundary: preference_manager_set_avatar_profile_should_keep_trimmed_user_and_positive_updated_at', 0, async () => {
      // Arrange
      const store = attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();
      const avatar = new AvatarProfile();
      avatar.userId = ' avatar_user ';
      avatar.localUri = 'file://avatar';
      avatar.compressedUri = 'file://avatar_small';
      avatar.cloudUrl = 'https://cdn/avatar';
      avatar.uploadState = 'SYNCED';
      avatar.updatedAt = 12345;

      // Act
      await manager.setAvatarProfile(avatar);
      const raw = await store.get(PreferenceManager.buildAvatarProfileKey('avatar_user'), '') as string;
      const saved = JSON.parse(String(raw)) as Record<string, Object>;

      // Assert
      expect(String(saved['userId'] || '')).assertEqual('avatar_user');
      expect(Number(saved['updatedAt'] || 0)).assertEqual(12345);
      expect(String(saved['uploadState'] || '')).assertEqual('SYNCED');
    });

    it('boundary: preference_manager_get_strategy_profile_should_fallback_to_default_when_raw_empty', 0, async () => {
      // Arrange
      attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();

      // Act
      const profile = await manager.getUserStrategyProfile();

      // Assert
      expect(profile.avgDensity).assertEqual(DEFAULT_USER_PROFILE.avgDensity);
      expect(profile.avgPace).assertEqual(DEFAULT_USER_PROFILE.avgPace);
      expect(profile.avgPreference).assertEqual(DEFAULT_USER_PROFILE.avgPreference);
      expect(profile.avgEnergy).assertEqual(DEFAULT_USER_PROFILE.avgEnergy);
      expect(profile.modeFrequency).assertEqual(DEFAULT_USER_PROFILE.modeFrequency);
      expect(profile.sampleCount).assertEqual(DEFAULT_USER_PROFILE.sampleCount);
      expect(profile.manualOverrideEnabled).assertEqual(DEFAULT_USER_PROFILE.manualOverrideEnabled === true);
    });

    it('invalid: preference_manager_get_strategy_profile_should_sanitize_invalid_snapshot_fields', 0, async () => {
      // Arrange
      const store = attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();
      store.setRaw(
        PreferenceManager.KEY_USER_STRATEGY_PROFILE,
        JSON.stringify({
          avgDensity: 'bad',
          avgPace: 'bad',
          avgPreference: null,
          avgEnergy: 'bad',
          modeFrequency: 1,
          sampleCount: 'bad',
          updatedAt: 'bad',
          manualOverrideEnabled: 'true',
          consistencyMatchCount: 'bad',
          consistencyMismatchCount: 'bad',
          lastConsistencyCheckAt: 'bad'
        }) as Object
      );

      // Act
      const profile = await manager.getUserStrategyProfile();

      // Assert
      expect(profile.avgDensity).assertEqual(DEFAULT_USER_PROFILE.avgDensity);
      expect(profile.avgPace).assertEqual(DEFAULT_USER_PROFILE.avgPace);
      expect(profile.avgPreference).assertEqual(DEFAULT_USER_PROFILE.avgPreference);
      expect(profile.avgEnergy).assertEqual(DEFAULT_USER_PROFILE.avgEnergy);
      expect(profile.modeFrequency).assertEqual(DEFAULT_USER_PROFILE.modeFrequency);
      expect(profile.sampleCount).assertEqual(DEFAULT_USER_PROFILE.sampleCount);
      expect(profile.updatedAt).assertEqual(DEFAULT_USER_PROFILE.updatedAt);
      expect(profile.manualOverrideEnabled).assertFalse();
      expect(profile.consistencyMatchCount).assertEqual(Number(DEFAULT_USER_PROFILE.consistencyMatchCount) > 0
        ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMatchCount))
        : 0);
      expect(profile.consistencyMismatchCount).assertEqual(Number(DEFAULT_USER_PROFILE.consistencyMismatchCount) > 0
        ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMismatchCount))
        : 0);
      expect(profile.lastConsistencyCheckAt).assertEqual(Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt) > 0
        ? Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt)
        : 0);
    });

    it('invalid: preference_manager_set_strategy_profile_should_zero_invalid_counters', 0, async () => {
      // Arrange
      const store = attachPreferenceStoreForPreferenceTest();
      const manager = PreferenceManager.getInstance();
      const profile = createStrategyProfileForPreferenceTest();
      profile.consistencyMatchCount = Number.NaN;
      profile.consistencyMismatchCount = Number.NaN;
      profile.lastConsistencyCheckAt = Number.NaN;

      // Act
      await manager.setUserStrategyProfile(profile);
      const raw = await store.get(PreferenceManager.KEY_USER_STRATEGY_PROFILE, '') as string;
      const saved = JSON.parse(String(raw)) as Record<string, Object>;

      // Assert
      expect(Number(saved['consistencyMatchCount'])).assertEqual(0);
      expect(Number(saved['consistencyMismatchCount'])).assertEqual(0);
      expect(Number(saved['lastConsistencyCheckAt'])).assertEqual(0);
    });
  });
}
