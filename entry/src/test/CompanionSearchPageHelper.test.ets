import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionSearchResultMetaText,
  shouldShowCompanionSearchEmptyState,
  shouldShowCompanionSearchPage
} from '../main/ets/pages/components/views/companion/CompanionSearchPage';

export default function companionSearchPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionSearchPageHelper', () => {
    it('normal: search_page_should_follow_show_flag', 0, () => {
      // Arrange
      const show = true;

      // Act
      const visible = shouldShowCompanionSearchPage(show);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: empty_state_should_be_true_when_result_count_is_zero', 0, () => {
      // Arrange
      const resultCount = 0;

      // Act
      const empty = shouldShowCompanionSearchEmptyState(resultCount);

      // Assert
      expect(empty).assertTrue();
    });

    it('invalid: empty_state_should_be_false_for_negative_count', 0, () => {
      // Arrange
      const resultCount = -1;

      // Act
      const empty = shouldShowCompanionSearchEmptyState(resultCount);

      // Assert
      expect(empty).assertFalse();
    });

    it('conflict: search_page_and_empty_state_should_be_independent', 0, () => {
      // Arrange
      const show = false;
      const resultCount = 0;

      // Act
      const visible = shouldShowCompanionSearchPage(show);
      const empty = shouldShowCompanionSearchEmptyState(resultCount);

      // Assert
      expect(visible).assertFalse();
      expect(empty).assertTrue();
    });

    it('regression: result_meta_text_should_keep_state_and_range_tokens', 0, () => {
      // Arrange
      const state = '进行中';
      const range = '10:00-11:00';

      // Act
      const text = getCompanionSearchResultMetaText(state, range);

      // Assert
      expect(text.includes(state)).assertTrue();
      expect(text.includes(range)).assertTrue();
    });

    it('combined: search_helper_matrix_should_cover_visibility_empty_and_meta', 0, () => {
      // Arrange
      const show = shouldShowCompanionSearchPage(true);
      const nonEmpty = shouldShowCompanionSearchEmptyState(3);
      const meta = getCompanionSearchResultMetaText('已完成', '08:00-09:00');

      // Act
      const ok = show && !nonEmpty && meta.includes('已完成') && meta.includes('08:00-09:00');

      // Assert
      expect(ok).assertTrue();
    });
  });
}
