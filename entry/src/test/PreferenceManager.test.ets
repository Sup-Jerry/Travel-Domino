import { describe, it, expect } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';

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
  });
}
