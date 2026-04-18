import { describe, it, expect } from '@ohos/hypium';
import {
  buildIndexPageHintLines,
  buildIndexPageScoreLines,
  buildIndexPageWeatherSuggestionText
} from '../main/ets/pages/index/IndexPageLayout';
import {
  resolveIndexToolbarModeColor,
  resolveIndexToolbarModeLabel
} from '../main/ets/pages/index/IndexToolbar';

export default function phase2BatchBXTest() {
  describe('phase2BatchBXTest_indexToolbar', () => {
    it('normal: toolbar_mode_label_should_map_known_strategy_modes', 0, () => {
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

    it('boundary: toolbar_mode_label_should_fallback_to_empty_string_for_default_mode', 0, () => {
      // Arrange
      // Act
      const result = resolveIndexToolbarModeLabel(0);
      // Assert
      expect(result).assertEqual('');
    });

    it('invalid: toolbar_mode_color_should_use_known_palette_and_keep_fallback_for_unknown_mode', 0, () => {
      // Arrange
      const fallbackColor = '#8C8C8C';
      // Act
      const soldier = resolveIndexToolbarModeColor(1, fallbackColor);
      const leisure = resolveIndexToolbarModeColor(2, fallbackColor);
      const custom = resolveIndexToolbarModeColor(-1, fallbackColor);
      const fallback = resolveIndexToolbarModeColor(0, fallbackColor);
      // Assert
      expect(soldier).assertEqual('#FF6B35');
      expect(leisure).assertEqual('#4CAF50');
      expect(custom).assertEqual('#2196F3');
      expect(fallback).assertEqual('#8C8C8C');
    });
  });

  describe('phase2BatchBXTest_indexPageLayout', () => {
    it('conflict: page_weather_suggestion_text_should_include_optional_sections_when_present', 0, () => {
      // Arrange
      // Act
      const result = buildIndexPageWeatherSuggestionText(
        'AI Collab',
        'move to indoor',
        'rain after noon',
        'reduce outdoor stay'
      );
      // Assert
      expect(result.indexOf('AI Collab') >= 0).assertTrue();
      expect(result.indexOf('move to indoor') >= 0).assertTrue();
      expect(result.indexOf('rain after noon') >= 0).assertTrue();
      expect(result.indexOf('reduce outdoor stay') >= 0).assertTrue();
    });

    it('boundary: page_weather_suggestion_text_should_omit_optional_sections_when_blank', 0, () => {
      // Arrange
      // Act
      const result = buildIndexPageWeatherSuggestionText('', 'keep current plan', '', '');
      // Assert
      expect(result.indexOf('keep current plan') >= 0).assertTrue();
    });

    it('regression: page_hint_lines_should_split_multiline_text_in_order', 0, () => {
      // Arrange
      const text = 'line1\nline2\nline3';
      // Act
      const lines = buildIndexPageHintLines(text);
      // Assert
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('line1');
      expect(lines[1]).assertEqual('line2');
      expect(lines[2]).assertEqual('line3');
    });

    it('combined: page_score_lines_should_support_single_line_and_empty_text', 0, () => {
      // Arrange
      // Act
      const singleLine = buildIndexPageScoreLines('stable-score');
      const emptyLine = buildIndexPageScoreLines('');
      // Assert
      expect(singleLine.length).assertEqual(1);
      expect(singleLine[0]).assertEqual('stable-score');
      expect(emptyLine.length).assertEqual(1);
      expect(emptyLine[0]).assertEqual('');
    });
  });
}

