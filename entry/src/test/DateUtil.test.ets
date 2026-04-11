import { describe, it, expect } from '@ohos/hypium';
import { DateUtil } from '../main/ets/common/utils/DateUtil';

export default function dateUtilTest() {
  describe('dateUtilTest', () => {
    it('normal: extract_pure_time_should_parse_time_from_prefixed_text', 0, () => {
      // Arrange
      const source = '次日 09:30';
      // Act
      const actual = DateUtil.extractPureTime(source);
      // Assert
      expect(actual).assertEqual('09:30');
    });

    it('boundary: format_real_time_should_render_month_day_when_cross_month', 0, () => {
      // Arrange
      const baseDate = new Date(2026, 0, 31, 23, 50, 0, 0);
      // Act
      const actual = DateUtil.formatRealTime(baseDate, 20);
      // Assert
      expect(actual).assertEqual('02-01 00:10');
    });

    it('invalid: is_valid_time_string_should_reject_out_of_range_value', 0, () => {
      // Arrange
      const invalidTime = '25:61';
      // Act
      const actual = DateUtil.isValidTimeString(invalidTime);
      // Assert
      expect(actual).assertFalse();
    });

    it('conflict: calculate_end_time_should_reject_invalid_day_shift_time', 0, () => {
      // Arrange
      const startTime = '次日 99:99';
      // Act
      const actual = DateUtil.calculateEndTime(startTime, 30);
      // Assert
      expect(actual).assertEqual('--:--');
    });

    it('regression: format_real_time_should_render_month_day_when_cross_year', 0, () => {
      // Arrange
      const baseDate = new Date(2026, 11, 31, 23, 50, 0, 0);
      // Act
      const actual = DateUtil.formatRealTime(baseDate, 20);
      // Assert
      expect(actual).assertEqual('01-01 00:10');
    });

    it('combined: calculate_end_time_should_support_date_prefix_input', 0, () => {
      // Arrange
      const startTime = '12-21 09:00';
      const durationMinutes = 90;
      // Act
      const actual = DateUtil.calculateEndTime(startTime, durationMinutes);
      // Assert
      expect(actual).assertEqual('10:30');
    });
  });
}
