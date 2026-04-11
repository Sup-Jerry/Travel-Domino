import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionTimelineFilterSummary,
  getCompanionTimelineVisibleCount,
  isCompanionTimelineFocused,
  shouldShowCompanionTimelineEmptyState
} from '../main/ets/pages/components/views/companion/CompanionTimelineSection';

export default function companionTimelineSectionHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionTimelineSectionHelper', () => {
    it('normal: timeline_focus_should_match_same_event_id', 0, () => {
      // Arrange
      const itemId = 100;
      const focusedEventId = 100;

      // Act
      const focused = isCompanionTimelineFocused(itemId, focusedEventId);

      // Assert
      expect(focused).assertTrue();
    });

    it('boundary: visible_count_should_keep_minimum_one_when_timeline_empty', 0, () => {
      // Arrange
      const timelineCount = 0;

      // Act
      const visibleCount = getCompanionTimelineVisibleCount(timelineCount);

      // Assert
      expect(visibleCount).assertEqual(1);
    });

    it('invalid: timeline_empty_state_should_be_false_for_negative_count', 0, () => {
      // Arrange
      const timelineCount = -1;

      // Act
      const isEmpty = shouldShowCompanionTimelineEmptyState(timelineCount);

      // Assert
      expect(isEmpty).assertFalse();
    });

    it('conflict: timeline_focus_should_be_false_when_ids_conflict', 0, () => {
      // Arrange
      const itemId = 101;
      const focusedEventId = 202;

      // Act
      const focused = isCompanionTimelineFocused(itemId, focusedEventId);

      // Assert
      expect(focused).assertFalse();
    });

    it('regression: filter_summary_should_keep_filter_and_position_tokens', 0, () => {
      // Arrange
      const filterLabel = '进行中';
      const focusPosition = 2;
      const timelineCount = 0;

      // Act
      const summary = getCompanionTimelineFilterSummary(filterLabel, focusPosition, timelineCount);

      // Assert
      expect(summary.includes(filterLabel)).assertTrue();
      expect(summary.includes('2/1')).assertTrue();
    });

    it('combined: summary_and_empty_state_should_follow_count_matrix', 0, () => {
      // Arrange
      const emptySummary = getCompanionTimelineFilterSummary('全部', 0, 0);
      const nonEmptySummary = getCompanionTimelineFilterSummary('全部', 3, 8);
      const emptyVisible = shouldShowCompanionTimelineEmptyState(0);
      const nonEmptyVisible = shouldShowCompanionTimelineEmptyState(8);

      // Act
      const result = emptySummary.includes('0/1')
        && nonEmptySummary.includes('3/8')
        && emptyVisible
        && !nonEmptyVisible;

      // Assert
      expect(result).assertTrue();
    });
  });
}
