import { describe, expect, it } from '@ohos/hypium';
import {
  buildIndexPageHintLines,
  buildIndexPageScoreLines,
  buildIndexPageWeatherSuggestionText,
  resolveIndexPageGapsCount,
  shouldShowIndexPageWeatherHint
} from '../main/ets/pages/index/IndexPageLayout';

export default function phase2BatchHHTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHH_index_page_layout_wrapper_edges', () => {
    it('combined: index_page_layout_should_build_weather_text_when_only_label_exists', 0, () => {
      const text = buildIndexPageWeatherSuggestionText('双人', '建议原计划', '', '');

      expect(text).assertContain('双人');
      expect(text).assertContain('建议原计划');
    });

    it('combined: index_page_layout_should_keep_empty_hint_line_and_single_score_line', 0, () => {
      const hintLines = buildIndexPageHintLines('');
      const scoreLines = buildIndexPageScoreLines('score_only');

      expect(hintLines.length).assertEqual(1);
      expect(hintLines[0]).assertEqual('');
      expect(scoreLines.length).assertEqual(1);
      expect(scoreLines[0]).assertEqual('score_only');
    });

    it('combined: index_page_layout_should_hide_weather_hint_when_manual_refresh_missing_even_with_whitespace', 0, () => {
      const show = shouldShowIndexPageWeatherHint(true, false, '   ');

      expect(show).assertFalse();
    });

    it('combined: index_page_layout_should_keep_nan_gap_count_unchanged', 0, () => {
      const gaps = resolveIndexPageGapsCount(Number.NaN);

      expect(Number.isNaN(gaps)).assertTrue();
    });
  });
}
