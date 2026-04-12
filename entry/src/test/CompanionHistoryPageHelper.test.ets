import { describe, it, expect } from '@ohos/hypium';
import {
  getHistoryTimelineFilterLabelValue,
  getHistoryTimelineSkipReasonByNote,
  getNextHistoryTimelineFilterValue,
  isHistoryTimelineItemVisibleByFilter
} from '../main/ets/pages/components/views/companion/CompanionHistoryPage';
import { HistoryTimelineFilter } from '../main/ets/viewmodel/TimelineViewModel';

export default function companionHistoryPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionHistoryPageHelper', () => {
    it('normal: next_filter_should_cycle_from_all_to_completed', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'all';

      // Act
      const next = getNextHistoryTimelineFilterValue(filter);

      // Assert
      expect(next).assertEqual('completed');
    });

    it('boundary: filter_label_should_return_all_for_default_filter', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'all';

      // Act
      const label = getHistoryTimelineFilterLabelValue(filter);

      // Assert
      expect(label).assertEqual('全部');
    });

    it('invalid: timeline_item_visibility_should_reject_completed_filter_for_skip_action', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'completed';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'SKIP', false);

      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: abnormal_filter_should_show_item_when_abnormal_even_if_not_skip', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'abnormal';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'ARRIVE', true);

      // Assert
      expect(visible).assertTrue();
    });

    it('regression: skip_reason_should_return_time_shortage_when_note_contains_keyword', 0, () => {
      // Arrange
      const note = '因天气导致时间不足，选择跳过';

      // Act
      const reason = getHistoryTimelineSkipReasonByNote(note);

      // Assert
      expect(reason).assertEqual('时间不足');
    });

    it('combined: history_helper_matrix_should_cover_filter_cycle_label_visibility_and_reason', 0, () => {
      // Arrange
      const next = getNextHistoryTimelineFilterValue('skipped');
      const label = getHistoryTimelineFilterLabelValue('abnormal');
      const visible = isHistoryTimelineItemVisibleByFilter('skipped', 'SKIP', false);
      const reason = getHistoryTimelineSkipReasonByNote('用户手动调整');

      // Act
      const ok = next === 'abnormal' && label === '只看异常' && visible && reason === '手动跳过';

      // Assert
      expect(ok).assertTrue();
    });

    it('boundary: next_filter_should_cycle_back_to_all_after_abnormal', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'abnormal';

      // Act
      const next = getNextHistoryTimelineFilterValue(filter);

      // Assert
      expect(next).assertEqual('all');
    });

    it('normal: completed_filter_should_show_leave_action', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'completed';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'LEAVE', false);

      // Assert
      expect(visible).assertTrue();
    });

    it('conflict: abnormal_filter_should_show_skip_action_even_without_abnormal_flag', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'abnormal';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'SKIP', false);

      // Assert
      expect(visible).assertTrue();
    });

    it('invalid: skip_reason_should_fallback_to_manual_when_note_is_blank', 0, () => {
      // Arrange
      const note = '   ';

      // Act
      const reason = getHistoryTimelineSkipReasonByNote(note);

      // Assert
      expect(reason).assertEqual('手动跳过');
    });
  });
}
