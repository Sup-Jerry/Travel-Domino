import { describe, it, expect } from '@ohos/hypium';
import {
  formatEventItemCommuteTime,
  getEventItemTravelModeIcon,
  resolveEventItemConflictGapMinutes
} from '../main/ets/pages/components/views/EventItemView';

export default function eventItemViewConflictGapEdgeTest() {
  describe('unit_test_case_generator_autofill_EventItemViewConflictGapEdge', () => {
    it('normal: conflict_gap_should_prefer_explicit_gap_when_positive', 0, () => {
      // Arrange
      const gapMinutes = 12;
      const conflictMsg = '冲突 45 分钟';

      // Act
      const resolved = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);

      // Assert
      expect(resolved).assertEqual(12);
    });

    it('boundary: conflict_gap_should_parse_first_number_from_message_when_gap_is_zero', 0, () => {
      // Arrange
      const gapMinutes = 0;
      const conflictMsg = 'A段 15 分钟，B段 30 分钟';

      // Act
      const resolved = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);

      // Assert
      expect(resolved).assertEqual(15);
    });

    it('invalid: conflict_gap_should_return_zero_when_message_has_no_number', 0, () => {
      // Arrange
      const gapMinutes = 0;
      const conflictMsg = '无冲突详情';

      // Act
      const resolved = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);

      // Assert
      expect(resolved).assertEqual(0);
    });

    it('conflict: commute_format_should_switch_hour_boundary_correctly', 0, () => {
      // Arrange
      // Act
      const m59 = formatEventItemCommuteTime(59);
      const m60 = formatEventItemCommuteTime(60);
      const m61 = formatEventItemCommuteTime(61);

      // Assert
      expect(m59).assertEqual('59m');
      expect(m60).assertEqual('1h');
      expect(m61).assertEqual('1h 1m');
    });

    it('regression: td-20260412-event-item-travel-mode-icon-matrix-should-stay-stable', 0, () => {
      // Arrange
      // Act
      const walk0 = getEventItemTravelModeIcon(0);
      const walk4 = getEventItemTravelModeIcon(4);
      const ride = getEventItemTravelModeIcon(1);
      const drive = getEventItemTravelModeIcon(2);
      const transit = getEventItemTravelModeIcon(3);

      // Assert
      expect(walk0).assertEqual('\uD83D\uDEB6');
      expect(walk4).assertEqual('\uD83D\uDEB6');
      expect(ride).assertEqual('\uD83D\uDEB4');
      expect(drive).assertEqual('\uD83D\uDE97');
      expect(transit).assertEqual('\uD83D\uDE87');
    });

    it('combined: gap_parse_and_fallback_icon_should_work_together', 0, () => {
      // Arrange
      const gapMinutes = 0;
      const conflictMsg = '冲突预计 20 分钟';

      // Act
      const resolvedGap = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      const unknownIcon = getEventItemTravelModeIcon(99);
      const zeroMinuteText = formatEventItemCommuteTime(0);

      // Assert
      expect(resolvedGap).assertEqual(20);
      expect(unknownIcon).assertEqual('\uD83D\uDE97');
      expect(zeroMinuteText).assertEqual('0m');
    });
  });
}

