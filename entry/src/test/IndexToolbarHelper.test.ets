import { describe, it, expect } from '@ohos/hypium';
import {
  IndexToolbar,
  IndexToolbarTheme,
  resolveIndexToolbarDisplayTitle,
  resolveIndexToolbarModeColor,
  resolveIndexToolbarModeLabel,
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
  theme?: IndexToolbarTheme;
  onBack?: () => void;
  onOpenSettings?: () => void;
  onEnterCompanion?: () => void;
  onRefreshWeather?: () => void;
}

interface IndexToolbarPrivateTest {
  planTitle: string;
  strategyMode: number;
  currentStrategyExplanation: string;
  isCompanionMode: boolean;
  isArchived: boolean;
  weatherFeatureEnabled: boolean;
  weatherLoading: boolean;
  theme: IndexToolbarTheme;
  onBack: () => void;
  onOpenSettings: () => void;
  onEnterCompanion: () => void;
  onRefreshWeather: () => void;
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

    it('combined: toolbar_state_sync_should_cover_generated_prop_update_and_callbacks', 0, () => {
      // Arrange
      const page = new IndexToolbar(undefined, {} as LocalStorage) as Object as IndexToolbarPrivateTest;
      let callCount = 0;
      const initTheme: IndexToolbarTheme = {
        primary: '#111111',
        textTertiary: '#222222',
        cardBgSoft: '#333333',
        textPrimary: '#444444'
      };
      const nextTheme: IndexToolbarTheme = {
        primary: '#AAAAAA',
        textTertiary: '#BBBBBB',
        cardBgSoft: '#CCCCCC',
        textPrimary: '#DDDDDD'
      };

      // Act
      page.setInitiallyProvidedValue({
        planTitle: 'init_title',
        strategyMode: 1,
        currentStrategyExplanation: 'init_explain',
        isCompanionMode: false,
        isArchived: false,
        weatherFeatureEnabled: true,
        weatherLoading: false,
        theme: initTheme,
        onBack: () => { callCount += 1; },
        onOpenSettings: () => { callCount += 1; },
        onEnterCompanion: () => { callCount += 1; },
        onRefreshWeather: () => { callCount += 1; }
      });
      page.onBack();
      page.onOpenSettings();
      page.onEnterCompanion();
      page.onRefreshWeather();
      page.updateStateVars({
        planTitle: 'next_title',
        strategyMode: -1,
        currentStrategyExplanation: 'next_explain',
        isCompanionMode: true,
        isArchived: true,
        weatherFeatureEnabled: false,
        weatherLoading: true,
        theme: nextTheme
      });

      // Assert
      expect(callCount).assertEqual(4);
      expect(page.planTitle).assertEqual('next_title');
      expect(page.strategyMode).assertEqual(-1);
      expect(page.currentStrategyExplanation).assertEqual('next_explain');
      expect(page.isCompanionMode).assertTrue();
      expect(page.isArchived).assertTrue();
      expect(page.weatherFeatureEnabled).assertFalse();
      expect(page.weatherLoading).assertTrue();
      expect(page.theme.primary).assertEqual('#AAAAAA');
      expect(page.theme.textPrimary).assertEqual('#DDDDDD');
    });

    it('boundary: toolbar_mode_label_should_cover_soldier_leisure_and_custom_modes', 0, () => {
      // Arrange
      // Act
      const soldier = resolveIndexToolbarModeLabel(1);
      const leisure = resolveIndexToolbarModeLabel(2);
      const custom = resolveIndexToolbarModeLabel(-1);

      // Assert
      expect(soldier.length > 0).assertTrue();
      expect(leisure.length > 0).assertTrue();
      expect(custom.length > 0).assertTrue();
      expect(soldier === leisure).assertFalse();
      expect(leisure === custom).assertFalse();
    });

    it('invalid: toolbar_mode_label_should_fallback_to_empty_for_default_mode', 0, () => {
      // Arrange
      const strategyMode = 0;

      // Act
      const label = resolveIndexToolbarModeLabel(strategyMode);

      // Assert
      expect(label).assertEqual('');
    });

    it('combined: toolbar_mode_color_should_use_strategy_palette_or_fallback', 0, () => {
      // Arrange
      const fallbackColor = '#123456';

      // Act
      const soldier = resolveIndexToolbarModeColor(1, fallbackColor);
      const leisure = resolveIndexToolbarModeColor(2, fallbackColor);
      const custom = resolveIndexToolbarModeColor(-1, fallbackColor);
      const fallback = resolveIndexToolbarModeColor(0, fallbackColor);

      // Assert
      expect(soldier).assertEqual('#FF6B35');
      expect(leisure).assertEqual('#4CAF50');
      expect(custom).assertEqual('#2196F3');
      expect(fallback).assertEqual(fallbackColor);
    });
  });
}

