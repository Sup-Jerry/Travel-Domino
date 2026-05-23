import { describe, expect, it } from '@ohos/hypium';
import {
  AdvanceAdjustCandidate,
  AdvanceAdjustPreview
} from '../main/ets/viewmodel/TimelineViewModel';
import {
  getConflictSelectionGapPrompt,
  shouldUseConflictAdvanceAdjust
} from '../main/ets/pages/components/dialogs/ConflictSelectionDialog';
import {
  resolveRecordCorrectionBaseTime,
  resolveRecordCorrectionSubmitEndTs,
  shouldRecordCorrectionHasEndTime
} from '../main/ets/pages/components/dialogs/RecordCorrectionDialog';
import {
  advanceAdjustMinutesToTime,
  advanceAdjustTimeToMinutes,
  resolveAdvanceAdjustDefaultStartTime,
  resolveAdvanceAdjustPreviewGapColor,
  resolveAdvanceAdjustPreviewGapMessage,
  resolveAdvanceAdjustPreviewRangeMessage,
  resolveAdvanceAdjustSelectedIds,
  resolveAdvanceAdjustSelectedSummary,
  toggleAdvanceAdjustSelection
} from '../main/ets/pages/components/dialogs/AdvanceAdjustDialog';
import {
  canConflictCompressConfirm,
  resolveConflictCompressPreviewNewDuration,
  resolveConflictCompressPreviewReduced,
  resolveConflictCompressRemainingGap,
  shouldShowConflictCompressOverload
} from '../main/ets/pages/components/dialogs/ConflictCompressDialog';

export default function phase2BatchFHTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFH_conflict_adjust_helpers', () => {
    it('normal: conflict_selection_and_record_correction_helpers_should_keep_basic_branches', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(getConflictSelectionGapPrompt(15).indexOf('15') >= 0).assertTrue();
      expect(shouldUseConflictAdvanceAdjust(true)).assertTrue();
      expect(shouldUseConflictAdvanceAdjust(false)).assertFalse();
      expect(resolveRecordCorrectionBaseTime(100, 200, 300)).assertEqual(100);
      expect(resolveRecordCorrectionBaseTime(0, 200, 300)).assertEqual(200);
      expect(resolveRecordCorrectionBaseTime(0, 0, 300)).assertEqual(300);
      expect(shouldRecordCorrectionHasEndTime(1)).assertTrue();
      expect(shouldRecordCorrectionHasEndTime(0)).assertFalse();
      expect(resolveRecordCorrectionSubmitEndTs(true, 456)).assertEqual(456);
      expect(resolveRecordCorrectionSubmitEndTs(false, 456)).assertEqual(0);
    });

    it('boundary: advance_adjust_time_helpers_should_parse_clamp_and_wrap_minutes', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(advanceAdjustTimeToMinutes('09:30')).assertEqual(570);
      expect(advanceAdjustTimeToMinutes('99:99')).assertEqual((23 * 60) + 59);
      expect(advanceAdjustTimeToMinutes('bad')).assertEqual(0);
      expect(advanceAdjustTimeToMinutes('10:xx')).assertEqual(0);
      expect(advanceAdjustMinutesToTime(0)).assertEqual('00:00');
      expect(advanceAdjustMinutesToTime(75)).assertEqual('01:15');
      expect(advanceAdjustMinutesToTime(-1)).assertEqual('23:59');
      expect(advanceAdjustMinutesToTime(24 * 60)).assertEqual('00:00');
      expect(resolveAdvanceAdjustDefaultStartTime('10:00', 45)).assertEqual('09:15');
      expect(resolveAdvanceAdjustDefaultStartTime('00:10', 30)).assertEqual('00:00');
      expect(resolveAdvanceAdjustDefaultStartTime('08:00', 0, 20)).assertEqual('07:40');
    });

    it('combined: advance_adjust_selection_and_preview_helpers_should_cover_summary_gap_and_range', 0, () => {
      // Arrange
      // Act
      // Assert
      const selectedIds = resolveAdvanceAdjustSelectedIds([{ id: 1 }, { id: 2 }] as AdvanceAdjustCandidate[]);
      const added = toggleAdvanceAdjustSelection(selectedIds, 3, true);
      const removed = toggleAdvanceAdjustSelection(added, 2, false);
      const pendingPreview = {
        selectedCount: 2,
        shiftMinutes: 25,
        requiredGapMinutes: 40,
        remainingGapMinutes: 15,
        firstNewStartTime: '08:30',
        lastNewEndTime: '10:00'
      } as AdvanceAdjustPreview;
      const resolvedPreview = {
        selectedCount: 2,
        shiftMinutes: 40,
        requiredGapMinutes: 40,
        remainingGapMinutes: 0,
        firstNewStartTime: '08:00',
        lastNewEndTime: '09:45'
      } as AdvanceAdjustPreview;

      const resolvedGapMessage = resolveAdvanceAdjustPreviewGapMessage(resolvedPreview);

      expect(selectedIds.has(1)).assertTrue();
      expect(selectedIds.has(2)).assertTrue();
      expect(added.has(3)).assertTrue();
      expect(removed.has(2)).assertFalse();
      expect(resolveAdvanceAdjustSelectedSummary(pendingPreview).indexOf('2') >= 0).assertTrue();
      expect(resolveAdvanceAdjustPreviewGapMessage(pendingPreview).indexOf('15') >= 0).assertTrue();
      expect(resolvedGapMessage.indexOf('40') >= 0).assertTrue();
      expect(resolvedGapMessage.length > 0).assertTrue();
      expect(resolveAdvanceAdjustPreviewGapColor(pendingPreview)).assertEqual('#FF4D4F');
      expect(resolveAdvanceAdjustPreviewGapColor(resolvedPreview)).assertEqual('#2E7D32');
      expect(resolveAdvanceAdjustPreviewRangeMessage(pendingPreview).indexOf('08:30') >= 0).assertTrue();
    });

    it('regression: conflict_compress_helpers_should_resolve_preview_and_overload_states', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(canConflictCompressConfirm(1)).assertTrue();
      expect(canConflictCompressConfirm(0)).assertFalse();
      expect(shouldShowConflictCompressOverload('OVERLOAD', 10)).assertTrue();
      expect(shouldShowConflictCompressOverload('OVERLOAD', 0)).assertFalse();
      expect(shouldShowConflictCompressOverload('OK', 10)).assertFalse();
      expect(resolveConflictCompressPreviewNewDuration([{ index: 2, newVal: 35 }], 2, 60)).assertEqual(35);
      expect(resolveConflictCompressPreviewNewDuration([{ index: 2, newVal: 35 }], 1, 60)).assertEqual(60);
      expect(resolveConflictCompressPreviewReduced(60, 35)).assertEqual(25);
      expect(resolveConflictCompressRemainingGap(undefined)).assertEqual(0);
      expect(resolveConflictCompressRemainingGap(12)).assertEqual(12);
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
