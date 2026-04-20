import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionWeatherHintPopupBuilder,
  CompanionWeatherScorePopupBuilder,
  CompanionWeatherSuggestionPopupBuilder,
  getCompanionPopupHeight,
  getCompanionPopupLine,
  getCompanionPopupWidth
} from '../main/ets/pages/components/views/companion/CompanionWeatherPopups';

function buildLines(): string[] {
  const lines: string[] = [];
  lines.push('line0');
  lines.push('line1');
  lines.push('line2');
  lines.push('line3');
  lines.push('line4');
  lines.push('line5');
  return lines;
}

export default function companionWeatherPopupsHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionWeatherPopupsHelper', () => {
    it('normal: popup_line_should_return_existing_item_by_index', 0, () => {
      // Arrange
      const lines = buildLines();

      // Act
      const actual = getCompanionPopupLine(lines, 2);

      // Assert
      expect(actual).assertEqual('line2');
    });

    it('boundary: popup_line_should_return_empty_when_index_equals_length', 0, () => {
      // Arrange
      const lines = buildLines();

      // Act
      const actual = getCompanionPopupLine(lines, lines.length);

      // Assert
      expect(actual).assertEqual('');
    });

    it('invalid: popup_line_should_return_empty_for_negative_index', 0, () => {
      // Arrange
      const lines = buildLines();

      // Act
      const actual = getCompanionPopupLine(lines, -1);

      // Assert
      expect(actual).assertEqual('');
    });

    it('conflict: popup_size_should_use_suggestion_override_when_kind_is_suggestion', 0, () => {
      // Arrange
      const kind = 'suggestion';

      // Act
      const height = getCompanionPopupHeight(kind);
      const width = getCompanionPopupWidth(kind);

      // Assert
      expect(height).assertEqual(240);
      expect(width).assertEqual(290);
    });

    it('regression: popup_size_should_keep_default_for_unknown_kind', 0, () => {
      // Arrange
      const kind = 'unknown';

      // Act
      const height = getCompanionPopupHeight(kind);
      const width = getCompanionPopupWidth(kind);

      // Assert
      expect(height).assertEqual(230);
      expect(width).assertEqual(280);
    });

    it('combined: popup_helpers_should_handle_empty_line_and_multi_kind_sizes', 0, () => {
      // Arrange
      const lines: string[] = ['A', '', 'C'];

      // Act
      const emptyLine = getCompanionPopupLine(lines, 1);
      const hintHeight = getCompanionPopupHeight('hint');
      const scoreWidth = getCompanionPopupWidth('score');

      // Assert
      expect(emptyLine).assertEqual('');
      expect(hintHeight).assertEqual(230);
      expect(scoreWidth).assertEqual(280);
    });

    it('normal: popup_builders_should_export_function_references', 0, () => {
      // Arrange
      const scoreBuilderRef = CompanionWeatherScorePopupBuilder;
      const hintBuilderRef = CompanionWeatherHintPopupBuilder;
      const suggestionBuilderRef = CompanionWeatherSuggestionPopupBuilder;

      // Act
      const allAreFunctions =
        typeof scoreBuilderRef === 'function' &&
        typeof hintBuilderRef === 'function' &&
        typeof suggestionBuilderRef === 'function';

      // Assert
      expect(allAreFunctions).assertTrue();
    });

    it('boundary: popup_builders_should_keep_distinct_builder_references', 0, () => {
      // Arrange
      const scoreBuilderRef = CompanionWeatherScorePopupBuilder;
      const hintBuilderRef = CompanionWeatherHintPopupBuilder;
      const suggestionBuilderRef = CompanionWeatherSuggestionPopupBuilder;

      // Act
      const scoreEqualsHint = scoreBuilderRef === hintBuilderRef;
      const hintEqualsSuggestion = hintBuilderRef === suggestionBuilderRef;
      const scoreEqualsSuggestion = scoreBuilderRef === suggestionBuilderRef;

      // Assert
      expect(scoreEqualsHint).assertFalse();
      expect(hintEqualsSuggestion).assertFalse();
      expect(scoreEqualsSuggestion).assertFalse();
    });

    it('regression: td-20260412-popup_builder_exports_should_remain_addressable', 0, () => {
      // Arrange
      const refs: Object[] = [
        CompanionWeatherScorePopupBuilder,
        CompanionWeatherHintPopupBuilder,
        CompanionWeatherSuggestionPopupBuilder
      ];

      // Act
      const refCount = refs.length;
      const hasUndefinedRef = refs.some((item: Object) => item === undefined);

      // Assert
      expect(refCount).assertEqual(3);
      expect(hasUndefinedRef).assertFalse();
    });

  });
}
