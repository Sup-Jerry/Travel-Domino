import { describe, it, expect } from '@ohos/hypium';
import {
  advanceAdjustMinutesToTime,
  advanceAdjustTimeToMinutes,
  resolveAdvanceAdjustDefaultStartTime
} from '../main/ets/pages/components/dialogs/AdvanceAdjustDialog';

export default function advanceAdjustDialogHelperTest() {
  describe('unit_test_case_generator_autofill_AdvanceAdjustDialogHelper', () => {
    it('normal: advance_adjust_should_parse_valid_time_to_minutes', 0, () => {
      // Arrange
      const time = '08:30';
      // Act
      const minutes = advanceAdjustTimeToMinutes(time);
      // Assert
      expect(minutes).assertEqual(510);
    });

    it('boundary: advance_adjust_should_wrap_negative_minutes_to_last_day_time', 0, () => {
      // Arrange
      const minutes = -1;
      // Act
      const time = advanceAdjustMinutesToTime(minutes);
      // Assert
      expect(time).assertEqual('23:59');
    });

    it('invalid: advance_adjust_should_fallback_to_zero_for_bad_time_text', 0, () => {
      // Arrange
      const time = 'bad-time';
      // Act
      const minutes = advanceAdjustTimeToMinutes(time);
      // Assert
      expect(minutes).assertEqual(0);
    });

    it('conflict: advance_adjust_should_prefer_forced_gap_when_present', 0, () => {
      // Arrange
      const currentStart = '10:00';
      const forcedGap = 45;
      // Act
      const target = resolveAdvanceAdjustDefaultStartTime(currentStart, forcedGap);
      // Assert
      expect(target).assertEqual('09:15');
    });

    it('regression: td-20260412-advance-adjust-default-shift-should-stay-30-minutes', 0, () => {
      // Arrange
      const currentStart = '09:00';
      // Act
      const target = resolveAdvanceAdjustDefaultStartTime(currentStart, 0);
      // Assert
      expect(target).assertEqual('08:30');
    });

    it('combined: advance_adjust_minutes_roundtrip_should_keep_hour_and_minute', 0, () => {
      // Arrange
      const source = '17:42';
      // Act
      const minutes = advanceAdjustTimeToMinutes(source);
      const target = advanceAdjustMinutesToTime(minutes);
      // Assert
      expect(target).assertEqual(source);
    });
  });
}
