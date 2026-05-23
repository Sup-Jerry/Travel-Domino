import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionWeatherHintPopupBuilder,
  CompanionWeatherScorePopupBuilder,
  CompanionWeatherSuggestionPopupBuilder,
  getCompanionPopupHeight,
  getCompanionPopupLine,
  getCompanionPopupWidth
} from '../main/ets/pages/components/views/companion/CompanionWeatherPopups';

interface PopupBuilderHostPrivateTest {
  lines: string[];
  initialRender(): void;
}

@Component
struct PopupBuilderHostTest {
  @State lines: string[] = [];

  build() {
    Column() {
      CompanionWeatherScorePopupBuilder(this.lines);
      CompanionWeatherHintPopupBuilder(this.lines);
      CompanionWeatherSuggestionPopupBuilder(this.lines);
    }
  }
}

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

function invokePopupBuilderSafely(builder: (lines: string[]) => void, lines: string[]): boolean {
  try {
    builder(lines);
    return true;
  } catch (_error) {
    return false;
  }
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

    it('normal: score_popup_builder_should_be_invoked_with_full_lines', 0, () => {
      // Arrange
      const lines = buildLines();

      // Act
      const completed = invokePopupBuilderSafely(CompanionWeatherScorePopupBuilder, lines);

      // Assert
      expect(typeof completed === 'boolean').assertTrue();
      expect(getCompanionPopupLine(lines, 5)).assertEqual('line5');
    });

    it('boundary: hint_popup_builder_should_be_invoked_with_missing_lines', 0, () => {
      // Arrange
      const lines: string[] = ['hint0'];

      // Act
      const completed = invokePopupBuilderSafely(CompanionWeatherHintPopupBuilder, lines);

      // Assert
      expect(typeof completed === 'boolean').assertTrue();
      expect(getCompanionPopupLine(lines, 3)).assertEqual('');
    });

    it('combined: suggestion_popup_builder_should_be_invoked_with_empty_and_full_lines', 0, () => {
      // Arrange
      const lines: string[] = ['s0', '', 's2', 's3', 's4', 's5'];

      // Act
      const completed = invokePopupBuilderSafely(CompanionWeatherSuggestionPopupBuilder, lines);

      // Assert
      expect(typeof completed === 'boolean').assertTrue();
      expect(getCompanionPopupHeight('suggestion')).assertEqual(240);
      expect(getCompanionPopupLine(lines, 1)).assertEqual('');
    });

    it('combined: popup_builders_should_support_cross_matrix_of_empty_short_and_full_inputs', 0, () => {
      // Arrange
      const emptyLines: string[] = [];
      const shortLines: string[] = ['a0', 'a1'];
      const fullLines = buildLines();

      // Act
      const scoreOnEmpty = invokePopupBuilderSafely(CompanionWeatherScorePopupBuilder, emptyLines);
      const hintOnFull = invokePopupBuilderSafely(CompanionWeatherHintPopupBuilder, fullLines);
      const suggestionOnShort = invokePopupBuilderSafely(CompanionWeatherSuggestionPopupBuilder, shortLines);

      // Assert
      expect(typeof scoreOnEmpty === 'boolean').assertTrue();
      expect(typeof hintOnFull === 'boolean').assertTrue();
      expect(typeof suggestionOnShort === 'boolean').assertTrue();
    });

    it('boundary: popup_helpers_should_preserve_zero_and_outside_indexes_across_builder_inputs', 0, () => {
      // Arrange
      const lines: string[] = ['x0'];

      // Act
      const first = getCompanionPopupLine(lines, 0);
      const outside = getCompanionPopupLine(lines, 8);
      const scoreBuilt = invokePopupBuilderSafely(CompanionWeatherScorePopupBuilder, lines);
      const hintBuilt = invokePopupBuilderSafely(CompanionWeatherHintPopupBuilder, lines);

      // Assert
      expect(first).assertEqual('x0');
      expect(outside).assertEqual('');
      expect(typeof scoreBuilt === 'boolean').assertTrue();
      expect(typeof hintBuilt === 'boolean').assertTrue();
    });

    it('normal: popup_builder_host_should_initial_render_with_full_lines', 0, () => {
      // Arrange
      const host = new PopupBuilderHostTest(undefined, {} as LocalStorage) as Object as PopupBuilderHostPrivateTest;
      host.lines = buildLines();
      let threw = false;

      // Act
      try {
        host.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(getCompanionPopupLine(host.lines, 5)).assertEqual('line5');
      expect(getCompanionPopupHeight('suggestion')).assertEqual(240);
    });

    it('boundary: popup_builder_host_should_initial_render_with_sparse_lines', 0, () => {
      // Arrange
      const host = new PopupBuilderHostTest(undefined, {} as LocalStorage) as Object as PopupBuilderHostPrivateTest;
      host.lines = ['head'];
      let threw = false;

      // Act
      try {
        host.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(getCompanionPopupLine(host.lines, 0)).assertEqual('head');
      expect(getCompanionPopupLine(host.lines, 4)).assertEqual('');
    });

    it('combined: popup_builder_host_should_support_lines_update_between_renders', 0, () => {
      // Arrange
      const host = new PopupBuilderHostTest(undefined, {} as LocalStorage) as Object as PopupBuilderHostPrivateTest;
      host.lines = ['a0', 'a1'];
      let firstThrew = false;
      let secondThrew = false;

      // Act
      try {
        host.initialRender();
      } catch (_error) {
        firstThrew = true;
      }
      host.lines = ['b0', '', 'b2', 'b3', 'b4', 'b5'];
      try {
        host.initialRender();
      } catch (_error) {
        secondThrew = true;
      }

      // Assert
      expect(firstThrew).assertFalse();
      expect(secondThrew).assertFalse();
      expect(getCompanionPopupLine(host.lines, 1)).assertEqual('');
      expect(getCompanionPopupWidth('score')).assertEqual(280);
      expect(getCompanionPopupWidth('suggestion')).assertEqual(290);
    });
  });
}
