import { describe, it, expect } from '@ohos/hypium';
import {
  resolveRecordCorrectionBaseTime,
  resolveRecordCorrectionSubmitEndTs,
  shouldRecordCorrectionHasEndTime
} from '../main/ets/pages/components/dialogs/RecordCorrectionDialog';

export default function recordCorrectionDialogHelperTest() {
  describe('unit_test_case_generator_autofill_RecordCorrectionDialogHelper', () => {
    it('normal: record_correction_base_time_should_use_actual_start_first', 0, () => {
      // Arrange
      const actualStart = 100;
      const dynamicStart = 200;
      const nowTs = 300;
      // Act
      const base = resolveRecordCorrectionBaseTime(actualStart, dynamicStart, nowTs);
      // Assert
      expect(base).assertEqual(100);
    });

    it('boundary: record_correction_base_time_should_fallback_to_now_when_no_start', 0, () => {
      // Arrange
      const actualStart = 0;
      const dynamicStart = 0;
      const nowTs = 300;
      // Act
      const base = resolveRecordCorrectionBaseTime(actualStart, dynamicStart, nowTs);
      // Assert
      expect(base).assertEqual(300);
    });

    it('invalid: record_correction_should_mark_no_end_when_actual_end_not_positive', 0, () => {
      // Arrange
      const actualEnd = 0;
      // Act
      const hasEnd = shouldRecordCorrectionHasEndTime(actualEnd);
      // Assert
      expect(hasEnd).assertFalse();
    });

    it('conflict: record_correction_submit_end_should_be_zero_when_end_not_enabled', 0, () => {
      // Arrange
      const hasEnd = false;
      const endTs = 999;
      // Act
      const submitEnd = resolveRecordCorrectionSubmitEndTs(hasEnd, endTs);
      // Assert
      expect(submitEnd).assertEqual(0);
    });

    it('regression: td-20260412-record-correction-should-use-dynamic-when-actual-missing', 0, () => {
      // Arrange
      const actualStart = 0;
      const dynamicStart = 456;
      const nowTs = 789;
      // Act
      const base = resolveRecordCorrectionBaseTime(actualStart, dynamicStart, nowTs);
      // Assert
      expect(base).assertEqual(456);
    });

    it('combined: record_correction_base_and_submit_end_should_match_flags', 0, () => {
      // Arrange
      const actualStart = 0;
      const dynamicStart = 123;
      const nowTs = 999;
      const endTs = 456;
      // Act
      const base = resolveRecordCorrectionBaseTime(actualStart, dynamicStart, nowTs);
      const submitEnd = resolveRecordCorrectionSubmitEndTs(true, endTs);
      // Assert
      expect(base).assertEqual(123);
      expect(submitEnd).assertEqual(456);
    });
  });
}
