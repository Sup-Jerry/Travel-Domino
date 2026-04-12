import { describe, it, expect } from '@ohos/hypium';
import {
  formatEventItemCommuteTime,
  getEventItemTravelModeIcon,
  resolveEventItemConflictGapMinutes
} from '../main/ets/pages/components/views/EventItemView';

export default function eventItemViewHelperTest() {
  describe('unit_test_case_generator_autofill_EventItemViewHelper', () => {
    it('normal: event_item_travel_mode_icon_should_map_drive_to_car', 0, () => {
      // Arrange
      const mode = 2;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚗');
    });

    it('boundary: event_item_commute_time_should_format_exact_hour', 0, () => {
      // Arrange
      const minutes = 120;
      // Act
      const text = formatEventItemCommuteTime(minutes);
      // Assert
      expect(text).assertEqual('2h');
    });

    it('invalid: event_item_travel_mode_icon_should_fallback_for_unknown_mode', 0, () => {
      // Arrange
      const mode = 999;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚗');
    });

    it('conflict: event_item_conflict_gap_should_parse_from_message_when_gap_missing', 0, () => {
      // Arrange
      const gapMinutes = 0;
      const conflictMsg = '与下一项冲突 25 分钟';
      // Act
      const resolved = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      // Assert
      expect(resolved).assertEqual(25);
    });

    it('regression: td-20260412-event-item-walk-override-icon-should-stay-walk', 0, () => {
      // Arrange
      const mode = 4;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚶');
    });

    it('combined: event_item_gap_and_commute_text_should_match_expected', 0, () => {
      // Arrange
      const gapMinutes = 10;
      const conflictMsg = '冲突 30 分钟';
      const commuteMinutes = 95;
      // Act
      const resolvedGap = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      const commuteText = formatEventItemCommuteTime(commuteMinutes);
      // Assert
      expect(resolvedGap).assertEqual(10);
      expect(commuteText).assertEqual('1h 35m');
    });
  });
}
