import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  CompanionExecutionWeatherCard,
  getExecutionWeatherCollapsedHintText,
  getExecutionWeatherCurrentNodeText,
  getExecutionWeatherExpandToggleText,
  getExecutionWeatherNextNodeText,
  getExecutionWeatherRefreshText,
  shouldShowExecutionWeatherAppliedSummary,
  shouldShowExecutionWeatherCollabSummary,
  shouldShowExecutionWeatherHint,
  shouldShowExecutionWeatherScore,
  splitExecutionWeatherSuggestionPopupText
} from '../main/ets/pages/components/views/companion/CompanionExecutionWeatherCard';

interface CompanionExecutionWeatherPaletteTest {
  textPrimary: Object;
  primary: Object;
}

interface CompanionExecutionWeatherCardParamsTest {
  weatherExpanded?: boolean;
  showWeatherScorePopup?: boolean;
  showWeatherHintPopup?: boolean;
  showWeatherSuggestionPopup?: boolean;
  weatherSuggestionPopupText?: string;
  weatherScoreSummary?: string;
  weatherScoreLines?: string[];
  weatherHintLines?: string[];
  executionWeatherCollabBadge?: string;
  executionWeatherLoading?: boolean;
  executionWeatherHint?: string;
  executionWeatherLevel?: string;
  executionWeatherCurrentText?: string;
  executionWeatherNextText?: string;
  executionWeatherScore?: number;
  executionWeatherCollabSummary?: string;
  executionWeatherAppliedSummary?: string;
  executionWeatherSuggestions?: Object[];
}

interface CompanionExecutionWeatherCardPrivateTest {
  weatherExpanded: boolean;
  showWeatherScorePopup: boolean;
  showWeatherHintPopup: boolean;
  showWeatherSuggestionPopup: boolean;
  weatherSuggestionPopupText: string;
  weatherScoreSummary: string;
  weatherScoreLines: string[];
  weatherHintLines: string[];
  executionWeatherCollabBadge: string;
  executionWeatherLoading: boolean;
  executionWeatherHint: string;
  executionWeatherLevel: string;
  executionWeatherCurrentText: string;
  executionWeatherNextText: string;
  executionWeatherScore: number;
  executionWeatherCollabSummary: string;
  executionWeatherAppliedSummary: string;
  executionWeatherSuggestions: Object[];
  effectiveTheme: string;
  onRefreshWeather: () => void;
  onToggleExpanded: () => void;
  onToggleScorePopup: () => void;
  onToggleHintPopup: () => void;
  onToggleSuggestionPopup: () => void;
  onScorePopupStateChange: (visible: boolean) => void;
  onHintPopupStateChange: (visible: boolean) => void;
  onSuggestionPopupStateChange: (visible: boolean) => void;
  onOpenSuggestionGuide: () => void;
  onOpenSuggestionDetail: (item: Object) => void;
  onApplySuggestion: (item: Object) => void;
  onLaterSuggestion: (suggestionId: string) => void;
  onIgnoreSuggestion: (suggestionId: string) => void;
  setInitiallyProvidedValue(params: CompanionExecutionWeatherCardParamsTest): void;
  updateStateVars(params: CompanionExecutionWeatherCardParamsTest): void;
  getThemePalette(): CompanionExecutionWeatherPaletteTest;
}

class WeatherSuggestionPlaceholderTest {}

export default function companionExecutionWeatherCardHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionExecutionWeatherCardHelper', () => {
    it('normal: refresh_text_should_switch_by_loading_state', 0, () => {
      // Arrange
      const loading = true;
      const idle = false;

      // Act
      const loadingText = getExecutionWeatherRefreshText(loading);
      const idleText = getExecutionWeatherRefreshText(idle);

      // Assert
      expect(loadingText).assertEqual('刷新中...');
      expect(idleText).assertEqual('刷新');
    });

    it('boundary: weather_score_zero_should_be_visible', 0, () => {
      // Arrange
      const score = 0;

      // Act
      const visible = shouldShowExecutionWeatherScore(score);

      // Assert
      expect(visible).assertTrue();
    });

    it('invalid: collapsed_hint_should_fallback_for_blank_input', 0, () => {
      // Arrange
      const blankHint = '   ';

      // Act
      const collapsed = getExecutionWeatherCollapsedHintText(blankHint);
      const visible = shouldShowExecutionWeatherHint(blankHint);

      // Assert
      expect(collapsed.includes('天气建议已收起')).assertTrue();
      expect(visible).assertFalse();
    });

    it('conflict: suggestion_popup_split_should_preserve_multiline_order', 0, () => {
      // Arrange
      const text = 'A\nB\nC';

      // Act
      const lines = splitExecutionWeatherSuggestionPopupText(text);

      // Assert
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('A');
      expect(lines[2]).assertEqual('C');
    });

    it('regression: node_text_should_fallback_to_unknown_when_value_missing', 0, () => {
      // Arrange
      const empty = '';

      // Act
      const currentText = getExecutionWeatherCurrentNodeText(empty);
      const nextText = getExecutionWeatherNextNodeText('   ');

      // Assert
      expect(currentText.includes('天气未知')).assertTrue();
      expect(nextText.includes('天气未知')).assertTrue();
    });

    it('combined: summary_visibility_and_expand_text_should_keep_semantic_matrix', 0, () => {
      // Arrange
      const collabSummary = '跨城协调';
      const emptySummary = ' ';

      // Act
      const expandedText = getExecutionWeatherExpandToggleText(true);
      const collapsedText = getExecutionWeatherExpandToggleText(false);
      const collabVisible = shouldShowExecutionWeatherCollabSummary(collabSummary);
      const appliedVisible = shouldShowExecutionWeatherAppliedSummary(emptySummary);

      // Assert
      expect(expandedText).assertEqual('收起');
      expect(collapsedText).assertEqual('展开');
      expect(collabVisible).assertTrue();
      expect(appliedVisible).assertFalse();
    });

    it('boundary: weather_score_negative_should_not_be_visible', 0, () => {
      // Arrange
      const score = -1;

      // Act
      const visible = shouldShowExecutionWeatherScore(score);

      // Assert
      expect(visible).assertFalse();
    });

    it('normal: node_text_should_include_expected_prefix_and_trimmed_value', 0, () => {
      // Arrange
      const currentText = ' 晴 ';
      const nextText = ' 阵雨 ';

      // Act
      const currentNodeText = getExecutionWeatherCurrentNodeText(currentText);
      const nextNodeText = getExecutionWeatherNextNodeText(nextText);

      // Assert
      expect(currentNodeText).assertEqual('当前位置： 晴 ');
      expect(nextNodeText).assertEqual('下一节点： 阵雨 ');
    });

    it('invalid: suggestion_popup_split_should_keep_empty_lines_for_popup_alignment', 0, () => {
      // Arrange
      const text = 'A\n\nC';

      // Act
      const lines = splitExecutionWeatherSuggestionPopupText(text);

      // Assert
      expect(lines.length).assertEqual(3);
      expect(lines[1]).assertEqual('');
    });

    it('combined: summary_visibility_should_be_true_for_non_blank_values', 0, () => {
      // Arrange
      const collabSummary = '  多日协同  ';
      const appliedSummary = '  已顺延30分钟  ';

      // Act
      const collabVisible = shouldShowExecutionWeatherCollabSummary(collabSummary);
      const appliedVisible = shouldShowExecutionWeatherAppliedSummary(appliedSummary);

      // Assert
      expect(collabVisible).assertTrue();
      expect(appliedVisible).assertTrue();
    });

    it('combined: weather_card_instance_should_sync_state_and_theme_palette_without_runtime_build', 0, () => {
      // Arrange
      const page = new CompanionExecutionWeatherCard(undefined, {} as LocalStorage) as Object as CompanionExecutionWeatherCardPrivateTest;
      const suggestion = new WeatherSuggestionPlaceholderTest() as Object;
      const initParams: CompanionExecutionWeatherCardParamsTest = {
        weatherExpanded: true,
        showWeatherScorePopup: true,
        showWeatherHintPopup: false,
        showWeatherSuggestionPopup: true,
        weatherSuggestionPopupText: 'A\nB',
        weatherScoreSummary: 'score',
        weatherScoreLines: ['l1'],
        weatherHintLines: ['h1'],
        executionWeatherCollabBadge: 'badge',
        executionWeatherHint: 'rain',
        executionWeatherLevel: 'NOTICE',
        executionWeatherCurrentText: 'sunny',
        executionWeatherNextText: 'cloud',
        executionWeatherScore: 5,
        executionWeatherCollabSummary: 'multi',
        executionWeatherAppliedSummary: 'shifted',
        executionWeatherSuggestions: [suggestion]
      };
      const nextParams: CompanionExecutionWeatherCardParamsTest = {
        weatherExpanded: false,
        showWeatherScorePopup: false,
        showWeatherHintPopup: true,
        showWeatherSuggestionPopup: false,
        executionWeatherLoading: true,
        executionWeatherHint: 'wind',
        executionWeatherLevel: 'WARNING',
        executionWeatherCurrentText: 'now',
        executionWeatherNextText: 'next',
        executionWeatherScore: 8,
        executionWeatherCollabSummary: 'updated',
        executionWeatherAppliedSummary: 'updated2',
        executionWeatherSuggestions: [suggestion, suggestion]
      };

      // Act
      page.onRefreshWeather();
      page.onToggleExpanded();
      page.onToggleScorePopup();
      page.onToggleHintPopup();
      page.onToggleSuggestionPopup();
      page.onScorePopupStateChange(true);
      page.onHintPopupStateChange(false);
      page.onSuggestionPopupStateChange(true);
      page.onOpenSuggestionGuide();
      page.onOpenSuggestionDetail(suggestion);
      page.onApplySuggestion(suggestion);
      page.onLaterSuggestion('s1');
      page.onIgnoreSuggestion('s1');
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);
      const initExpanded = page.weatherExpanded;
      const initScorePopup = page.showWeatherScorePopup;
      const initHintPopup = page.showWeatherHintPopup;
      const initSuggestionPopup = page.showWeatherSuggestionPopup;
      const initSuggestionText = page.weatherSuggestionPopupText;
      const initScoreSummary = page.weatherScoreSummary;
      const initScoreLineCount = page.weatherScoreLines.length;
      const initHintLineCount = page.weatherHintLines.length;
      const initCollabBadge = page.executionWeatherCollabBadge;
      const initSuggestionCount = page.executionWeatherSuggestions.length;
      page.updateStateVars(nextParams);
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(initExpanded).assertTrue();
      expect(initScorePopup).assertTrue();
      expect(initHintPopup).assertFalse();
      expect(initSuggestionPopup).assertTrue();
      expect(initSuggestionText).assertEqual('A\nB');
      expect(initScoreSummary).assertEqual('score');
      expect(initScoreLineCount).assertEqual(1);
      expect(initHintLineCount).assertEqual(1);
      expect(initCollabBadge).assertEqual('badge');
      expect(initSuggestionCount).assertEqual(1);
      expect(page.weatherExpanded).assertFalse();
      expect(page.showWeatherScorePopup).assertFalse();
      expect(page.showWeatherHintPopup).assertTrue();
      expect(page.showWeatherSuggestionPopup).assertFalse();
      expect(page.executionWeatherLoading).assertTrue();
      expect(page.executionWeatherHint).assertEqual('wind');
      expect(page.executionWeatherLevel).assertEqual('WARNING');
      expect(page.executionWeatherCurrentText).assertEqual('now');
      expect(page.executionWeatherNextText).assertEqual('next');
      expect(page.executionWeatherScore).assertEqual(8);
      expect(page.executionWeatherCollabSummary).assertEqual('updated');
      expect(page.executionWeatherAppliedSummary).assertEqual('updated2');
      expect(page.executionWeatherSuggestions.length).assertEqual(2);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });
  });
}

