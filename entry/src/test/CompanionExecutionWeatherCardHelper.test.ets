import { describe, it, expect } from '@ohos/hypium';
import {
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
  });
}
