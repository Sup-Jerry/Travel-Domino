import { describe, it, expect } from '@ohos/hypium';
import {
  resolveIndexToolbarDisplayTitle,
  shouldShowIndexToolbarModeExplanation,
  shouldShowIndexToolbarModeTag,
  shouldShowIndexToolbarWeatherAction
} from '../main/ets/pages/index/IndexToolbar';

export default function indexToolbarHelperTest() {
  describe('unit_test_case_generator_autofill_IndexToolbarHelper', () => {
    it('normal: toolbar_title_should_truncate_when_exceeds_default_limit', 0, () => {
      // Arrange
      const title = '123456789';

      // Act
      const displayTitle = resolveIndexToolbarDisplayTitle(title);

      // Assert
      expect(displayTitle).assertEqual('1234567...');
    });

    it('boundary: toolbar_title_should_keep_original_when_equal_to_limit', 0, () => {
      // Arrange
      const title = '1234567';

      // Act
      const displayTitle = resolveIndexToolbarDisplayTitle(title);

      // Assert
      expect(displayTitle).assertEqual('1234567');
    });

    it('invalid: mode_tag_should_hide_when_strategy_mode_is_zero', 0, () => {
      // Arrange
      const strategyMode = 0;

      // Act
      const show = shouldShowIndexToolbarModeTag(strategyMode);

      // Assert
      expect(show).assertFalse();
    });

    it('conflict: mode_explanation_should_require_non_zero_mode_and_non_empty_text', 0, () => {
      // Arrange
      const strategyMode = 1;
      const emptyText = '';

      // Act
      const hide = shouldShowIndexToolbarModeExplanation(strategyMode, emptyText);
      const show = shouldShowIndexToolbarModeExplanation(strategyMode, 'explain');

      // Assert
      expect(hide).assertFalse();
      expect(show).assertTrue();
    });

    it('regression: weather_action_should_hide_in_companion_mode_even_if_feature_enabled', 0, () => {
      // Arrange
      const isCompanionMode = true;
      const weatherFeatureEnabled = true;

      // Act
      const show = shouldShowIndexToolbarWeatherAction(isCompanionMode, weatherFeatureEnabled);

      // Assert
      expect(show).assertFalse();
    });

    it('combined: toolbar_visibility_matrix_should_cover_mode_tag_explanation_and_weather_action', 0, () => {
      // Arrange
      const strategyMode = 2;
      const explanation = 'mode text';

      // Act
      const modeTag = shouldShowIndexToolbarModeTag(strategyMode);
      const modeExplanation = shouldShowIndexToolbarModeExplanation(strategyMode, explanation);
      const weatherAction = shouldShowIndexToolbarWeatherAction(false, true);
      const title = resolveIndexToolbarDisplayTitle('ABCDE', 3);

      // Assert
      expect(modeTag).assertTrue();
      expect(modeExplanation).assertTrue();
      expect(weatherAction).assertTrue();
      expect(title).assertEqual('ABC...');
    });
  });
}

