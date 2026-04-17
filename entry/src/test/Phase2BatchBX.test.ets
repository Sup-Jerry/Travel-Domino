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
      expect(soldier).assertEqual('🚀 特种兵模式');
      expect(leisure).assertEqual('🌴 休闲模式');
      expect(custom).assertEqual('🎛 自定义策略');
    });

    it('boundary: toolbar_mode_label_should_fallback_to_empty_string_for_default_mode', 0, () => {
      // Arrange
      // Act
      const result = resolveIndexToolbarModeLabel(0);
      // Assert
      expect(result).assertEqual('');
    });

    it('combined: toolbar_mode_color_should_use_known_palette_and_keep_fallback_for_unknown_mode', 0, () => {
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
    it('normal: page_weather_suggestion_text_should_include_optional_sections_when_present', 0, () => {
      // Arrange
      // Act
      const result = buildIndexPageWeatherSuggestionText(
        'AI 协同',
        '建议下午转室内',
        '午后有雨',
        '压缩户外停留'
      );
      // Assert
      expect(result).assertEqual('天气建议（可选） ⓘ · AI 协同：建议下午转室内（午后有雨）；策略联动：压缩户外停留');
    });

    it('boundary: page_weather_suggestion_text_should_omit_optional_sections_when_blank', 0, () => {
      // Arrange
      // Act
      const result = buildIndexPageWeatherSuggestionText('', '保持当前计划', '', '');
      // Assert
      expect(result).assertEqual('天气建议（可选） ⓘ ：保持当前计划');
    });

    it('normal: page_hint_lines_should_split_multiline_text_in_order', 0, () => {
      // Arrange
      const text = '第一行\n第二行\n第三行';
      // Act
      const lines = buildIndexPageHintLines(text);
      // Assert
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('第一行');
      expect(lines[1]).assertEqual('第二行');
      expect(lines[2]).assertEqual('第三行');
    });

    it('combined: page_score_lines_should_support_single_line_and_empty_text', 0, () => {
      // Arrange
      // Act
      const singleLine = buildIndexPageScoreLines('评分稳定');
      const emptyLine = buildIndexPageScoreLines('');
      // Assert
      expect(singleLine.length).assertEqual(1);
      expect(singleLine[0]).assertEqual('评分稳定');
      expect(emptyLine.length).assertEqual(1);
      expect(emptyLine[0]).assertEqual('');
    });
  });
}
