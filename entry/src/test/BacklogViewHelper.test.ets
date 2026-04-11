import { describe, it, expect } from '@ohos/hypium';
import {
  getBacklogBadgeText,
  getBacklogExpandSymbol,
  shouldShowBacklogEmptyState,
  shouldShowBacklogMoveAllButton
} from '../main/ets/pages/components/views/BacklogView';

export default function backlogViewHelperTest() {
  describe('unit_test_case_generator_autofill_BacklogViewHelper', () => {
    it('normal: backlog_expand_symbol_should_use_down_when_expanded', 0, () => {
      // Arrange
      const expanded = true;
      // Act
      const symbol = getBacklogExpandSymbol(expanded);
      // Assert
      expect(symbol).assertEqual('\u25BC');
    });

    it('boundary: backlog_badge_text_should_show_zero_count', 0, () => {
      // Arrange
      const count = 0;
      // Act
      const text = getBacklogBadgeText(count);
      // Assert
      expect(text).assertEqual('0');
    });

    it('invalid: backlog_move_all_button_should_hide_when_no_items', 0, () => {
      // Arrange
      const count = 0;
      // Act
      const visible = shouldShowBacklogMoveAllButton(count);
      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: backlog_empty_state_should_show_when_expanded_but_empty', 0, () => {
      // Arrange
      const expanded = true;
      const count = 0;
      // Act
      const showEmpty = shouldShowBacklogEmptyState(expanded, count);
      // Assert
      expect(showEmpty).assertTrue();
    });

    it('regression: td-20260412-backlog-collapse-should-not-show-empty', 0, () => {
      // Arrange
      const expanded = false;
      const count = 0;
      // Act
      const showEmpty = shouldShowBacklogEmptyState(expanded, count);
      // Assert
      expect(showEmpty).assertFalse();
    });

    it('combined: backlog_button_and_empty_state_should_match_non_empty_expanded', 0, () => {
      // Arrange
      const expanded = true;
      const count = 3;
      // Act
      const showButton = shouldShowBacklogMoveAllButton(count);
      const showEmpty = shouldShowBacklogEmptyState(expanded, count);
      // Assert
      expect(showButton).assertTrue();
      expect(showEmpty).assertFalse();
    });
  });
}
