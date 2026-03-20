import { describe, it, expect } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';

export default function preferenceManagerTest() {
  describe('preferenceManagerTest', () => {
    it('min_duration_should_fallback_and_clip', 0, () => {
      expect(PreferenceManager.normalizeMinEventDuration('bad')).assertEqual(30);
      expect(PreferenceManager.normalizeMinEventDuration(-5)).assertEqual(1);
      expect(PreferenceManager.normalizeMinEventDuration(9999)).assertEqual(720);
    });

    it('idle_gap_trigger_should_fallback_and_clip', 0, () => {
      expect(PreferenceManager.normalizeIdleGapTriggerMinutes('oops')).assertEqual(45);
      expect(PreferenceManager.normalizeIdleGapTriggerMinutes(0)).assertEqual(1);
      expect(PreferenceManager.normalizeIdleGapTriggerMinutes(999)).assertEqual(720);
    });

    it('theme_mode_should_fallback_to_system', 0, () => {
      expect(PreferenceManager.normalizeThemeMode('light')).assertEqual('light');
      expect(PreferenceManager.normalizeThemeMode('abc')).assertEqual('system');
      expect(PreferenceManager.normalizeThemeMode(1)).assertEqual('system');
    });

    it('weather_pref_level_should_fallback_and_clip', 0, () => {
      expect(PreferenceManager.normalizeWeatherPreferenceLevel('bad')).assertEqual(1);
      expect(PreferenceManager.normalizeWeatherPreferenceLevel(-1)).assertEqual(0);
      expect(PreferenceManager.normalizeWeatherPreferenceLevel(99)).assertEqual(2);
    });
  });
}
