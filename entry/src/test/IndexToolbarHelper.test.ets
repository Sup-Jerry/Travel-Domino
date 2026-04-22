import { describe, it, expect } from '@ohos/hypium';
import {
  IndexToolbar,
  resolveIndexToolbarDisplayTitle,
  shouldShowIndexToolbarModeExplanation,
  shouldShowIndexToolbarModeTag,
  shouldShowIndexToolbarWeatherAction
} from '../main/ets/pages/index/IndexToolbar';

interface IndexToolbarParamsTest {
  planTitle?: string;
  strategyMode?: number;
  currentStrategyExplanation?: string;
  isCompanionMode?: boolean;
  isArchived?: boolean;
  weatherFeatureEnabled?: boolean;
  weatherLoading?: boolean;
}

interface IndexToolbarPrivateTest {
  planTitle: string;
  strategyMode: number;
  currentStrategyExplanation: string;
  isCompanionMode: boolean;
  isArchived: boolean;
  weatherFeatureEnabled: boolean;
  weatherLoading: boolean;
  setInitiallyProvidedValue(params: IndexToolbarParamsTest): void;
  updateStateVars(params: IndexToolbarParamsTest): void;
  initialRender(): void;
}

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

    it('combined: toolbar_initial_render_should_cover_mode_explanation_and_weather_action_branch', 0, () => {
      // Arrange
      const page = new IndexToolbar(undefined, {} as LocalStorage) as Object as IndexToolbarPrivateTest;
      let threw = false;

      // Act
      page.planTitle = 'travel_plan_alpha';
      page.strategyMode = 2;
      page.currentStrategyExplanation = 'weather first';
      page.isCompanionMode = false;
      page.isArchived = false;
      page.weatherFeatureEnabled = true;
      page.weatherLoading = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: toolbar_initial_render_should_cover_archived_and_weather_hidden_branch', 0, () => {
      // Arrange
      const page = new IndexToolbar(undefined, {} as LocalStorage) as Object as IndexToolbarPrivateTest;
      let threw = false;

      // Act
      page.planTitle = 'short';
      page.strategyMode = 0;
      page.currentStrategyExplanation = '';
      page.isCompanionMode = true;
      page.isArchived = true;
      page.weatherFeatureEnabled = false;
      page.weatherLoading = true;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}

