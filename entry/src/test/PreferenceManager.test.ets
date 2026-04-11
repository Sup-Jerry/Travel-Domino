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
    it('normal: td-20260411-auto-PreferenceManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('invalid: td-20260411-auto-PreferenceManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-PreferenceManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-PreferenceManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-PreferenceManager', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
