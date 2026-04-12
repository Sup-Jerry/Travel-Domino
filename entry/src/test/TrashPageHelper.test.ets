import { describe, it, expect } from '@ohos/hypium';
import {
  resolveTrashAutoPurgeDiffMs,
  resolveTrashRemainingTimeText
} from '../main/ets/pages/TrashPage';

export default function trashPageHelperTest() {
  describe('unit_test_case_generator_autofill_TrashPageHelper', () => {
    it('normal: trash_remaining_time_should_render_day_and_hour_when_diff_over_one_day', 0, () => {
      // Arrange
      const now = 1_000;
      const deleteTime = now - 2 * 24 * 3600 * 1000;
      const retentionMs = 3 * 24 * 3600 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('1天 0小时 后自动清除');
    });

    it('boundary: trash_remaining_time_should_fallback_to_immediate_when_diff_equals_zero', 0, () => {
      // Arrange
      const now = 5_000;
      const deleteTime = 4_000;
      const retentionMs = 1_000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('即将清除');
    });

    it('invalid: trash_remaining_time_should_fallback_to_immediate_when_delete_time_missing', 0, () => {
      // Arrange
      const now = 10_000;
      // Act
      const text = resolveTrashRemainingTimeText(undefined, now);
      // Assert
      expect(text).assertEqual('即将清除');
    });

    it('conflict: trash_remaining_time_should_render_hour_only_when_less_than_one_day', 0, () => {
      // Arrange
      const now = 100_000;
      const deleteTime = now - 6 * 3600 * 1000;
      const retentionMs = 12 * 3600 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('6小时 后自动清除');
    });

    it('regression: td-20260412-trash_auto_purge_diff_should_keep_negative_when_missing_delete_time', 0, () => {
      // Arrange
      const now = 123_456;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(undefined, now);
      // Assert
      expect(diff).assertEqual(-1);
    });

    it('combined: trash_diff_and_text_should_stay_consistent_for_positive_diff', 0, () => {
      // Arrange
      const now = 200_000;
      const deleteTime = now - 1_000;
      const retentionMs = 3_600_000;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, retentionMs);
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(diff > 0).assertTrue();
      expect(text).assertEqual('0小时 后自动清除');
    });
  });
}

