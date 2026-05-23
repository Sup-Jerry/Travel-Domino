import { describe, it, expect } from '@ohos/hypium';
import {
  IndexWeatherHintBar,
  resolveIndexWeatherHintLine,
  resolveIndexWeatherScoreLine,
  shouldShowIndexWeatherHintBar,
  shouldShowIndexWeatherRouteScore
} from '../main/ets/pages/index/IndexWeatherHintBar';

interface IndexWeatherHintBarParamsTest {
  visible?: boolean;
  suggestionText?: string;
  routeScore?: number;
  hintPopupVisible?: boolean;
  scorePopupVisible?: boolean;
  hintLines?: string[];
  scoreLines?: string[];
}

interface IndexWeatherHintBarPrivateTest {
  visible: boolean;
  suggestionText: string;
  routeScore: number;
  hintPopupVisible: boolean;
  scorePopupVisible: boolean;
  hintLines: string[];
  scoreLines: string[];
  setInitiallyProvidedValue(params: IndexWeatherHintBarParamsTest): void;
  updateStateVars(params: IndexWeatherHintBarParamsTest): void;
  initialRender(): void;
}

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

    it('combined: weather_hint_bar_initial_render_should_cover_visible_score_and_popup_builders', 0, () => {
      // Arrange
      const page = new IndexWeatherHintBar(undefined, {} as LocalStorage) as Object as IndexWeatherHintBarPrivateTest;
      let threw = false;

      // Act
      page.visible = true;
      page.suggestionText = 'rain warning';
      page.routeScore = 88;
      page.hintPopupVisible = true;
      page.scorePopupVisible = true;
      page.hintLines = ['h0', 'h1', 'h2', 'h3'];
      page.scoreLines = ['s0', 's1', 's2', 's3', 's4', 's5'];
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: weather_hint_bar_initial_render_should_cover_hidden_branch_without_score', 0, () => {
      // Arrange
      const page = new IndexWeatherHintBar(undefined, {} as LocalStorage) as Object as IndexWeatherHintBarPrivateTest;
      let threw = false;

      // Act
      page.visible = false;
      page.suggestionText = '';
      page.routeScore = -1;
      page.hintPopupVisible = false;
      page.scorePopupVisible = false;
      page.hintLines = [];
      page.scoreLines = [];
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: weather_hint_bar_update_state_vars_should_replace_visibility_and_lines', 0, () => {
      // Arrange
      const page = new IndexWeatherHintBar(undefined, {} as LocalStorage) as Object as IndexWeatherHintBarPrivateTest;
      page.visible = false;
      page.routeScore = -1;
      page.hintLines = [];
      page.scoreLines = [];

      // Act
      page.updateStateVars({
        visible: true,
        routeScore: 66,
        hintLines: ['rain', 'wind'],
        scoreLines: ['score']
      });

      // Assert
      expect(page.visible).assertTrue();
      expect(page.routeScore).assertEqual(66);
      expect(page.hintLines.length).assertEqual(2);
      expect(page.scoreLines[0]).assertEqual('score');
    });
  });
}

