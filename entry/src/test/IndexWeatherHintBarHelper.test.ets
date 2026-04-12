import { describe, it, expect } from '@ohos/hypium';
import {
  resolveIndexWeatherHintLine,
  resolveIndexWeatherScoreLine,
  shouldShowIndexWeatherHintBar,
  shouldShowIndexWeatherRouteScore
} from '../main/ets/pages/index/IndexWeatherHintBar';

export default function indexWeatherHintBarHelperTest() {
  describe('unit_test_case_generator_autofill_IndexWeatherHintBarHelper', () => {
    it('normal: hint_line_should_return_value_by_index', 0, () => {
      // Arrange
      const lines: string[] = ['a', 'b', 'c'];

      // Act
      const line = resolveIndexWeatherHintLine(lines, 1);

      // Assert
      expect(line).assertEqual('b');
    });

    it('boundary: score_line_should_fallback_empty_when_index_equals_length', 0, () => {
      // Arrange
      const lines: string[] = ['x', 'y'];

      // Act
      const line = resolveIndexWeatherScoreLine(lines, 2);

      // Assert
      expect(line).assertEqual('');
    });

    it('invalid: hint_line_should_fallback_empty_for_negative_index', 0, () => {
      // Arrange
      const lines: string[] = ['x'];

      // Act
      const line = resolveIndexWeatherHintLine(lines, -1);

      // Assert
      expect(line).assertEqual('');
    });

    it('conflict: route_score_visibility_should_split_negative_and_zero', 0, () => {
      // Arrange
      const negativeScore = -1;
      const zeroScore = 0;

      // Act
      const hide = shouldShowIndexWeatherRouteScore(negativeScore);
      const show = shouldShowIndexWeatherRouteScore(zeroScore);

      // Assert
      expect(hide).assertFalse();
      expect(show).assertTrue();
    });

    it('regression: weather_hint_bar_visibility_should_follow_visible_flag', 0, () => {
      // Arrange
      const visible = true;
      const hidden = false;

      // Act
      const show = shouldShowIndexWeatherHintBar(visible);
      const hide = shouldShowIndexWeatherHintBar(hidden);

      // Assert
      expect(show).assertTrue();
      expect(hide).assertFalse();
    });

    it('combined: line_resolution_and_visibility_should_keep_matrix_consistent', 0, () => {
      // Arrange
      const hintLines: string[] = ['line0', 'line1'];
      const scoreLines: string[] = ['s0'];

      // Act
      const hint = resolveIndexWeatherHintLine(hintLines, 0);
      const score = resolveIndexWeatherScoreLine(scoreLines, 1);
      const showBar = shouldShowIndexWeatherHintBar(true);
      const showScore = shouldShowIndexWeatherRouteScore(7);

      // Assert
      expect(hint).assertEqual('line0');
      expect(score).assertEqual('');
      expect(showBar).assertTrue();
      expect(showScore).assertTrue();
    });
  });
}

