import { describe, it, expect } from '@ohos/hypium';
import {
  resolveIndexPageGapsCount,
  shouldShowIndexPageWeatherHint
} from '../main/ets/pages/index/IndexPageLayout';

export default function indexPageLayoutHelperTest() {
  describe('unit_test_case_generator_autofill_IndexPageLayoutHelper', () => {
    it('normal: page_weather_hint_should_show_when_all_conditions_match', 0, () => {
      // Arrange
      const weatherFeatureEnabled = true;
      const hasManualPlanningWeatherRefresh = true;
      const weatherPlanningHint = 'hint';

      // Act
      const show = shouldShowIndexPageWeatherHint(
        weatherFeatureEnabled,
        hasManualPlanningWeatherRefresh,
        weatherPlanningHint
      );

      // Assert
      expect(show).assertTrue();
    });

    it('boundary: page_weather_hint_should_hide_when_hint_text_empty', 0, () => {
      // Arrange
      const weatherFeatureEnabled = true;
      const hasManualPlanningWeatherRefresh = true;
      const weatherPlanningHint = '';

      // Act
      const show = shouldShowIndexPageWeatherHint(
        weatherFeatureEnabled,
        hasManualPlanningWeatherRefresh,
        weatherPlanningHint
      );

      // Assert
      expect(show).assertFalse();
    });

    it('invalid: page_weather_hint_should_hide_when_feature_disabled', 0, () => {
      // Arrange
      const weatherFeatureEnabled = false;

      // Act
      const show = shouldShowIndexPageWeatherHint(weatherFeatureEnabled, true, 'hint');

      // Assert
      expect(show).assertFalse();
    });

    it('conflict: page_weather_hint_should_hide_when_manual_refresh_not_triggered', 0, () => {
      // Arrange
      const hasManualPlanningWeatherRefresh = false;

      // Act
      const show = shouldShowIndexPageWeatherHint(true, hasManualPlanningWeatherRefresh, 'hint');

      // Assert
      expect(show).assertFalse();
    });

    it('regression: page_gaps_count_should_keep_identity_mapping', 0, () => {
      // Arrange
      const gapsCount = 3;

      // Act
      const actual = resolveIndexPageGapsCount(gapsCount);

      // Assert
      expect(actual).assertEqual(3);
    });

    it('combined: page_layout_helper_matrix_should_cover_hint_and_gaps_path', 0, () => {
      // Arrange
      const showHint = shouldShowIndexPageWeatherHint(true, true, 'ok');
      const hideHint = shouldShowIndexPageWeatherHint(true, false, 'ok');
      const gaps = resolveIndexPageGapsCount(5);

      // Act
      const pass = showHint && !hideHint && gaps === 5;

      // Assert
      expect(pass).assertTrue();
    });
  });
}

