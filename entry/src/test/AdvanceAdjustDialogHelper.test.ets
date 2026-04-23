import { describe, it, expect } from '@ohos/hypium';
import {
  AdvanceAdjustDialog,
  toggleAdvanceAdjustSelection,
  advanceAdjustMinutesToTime,
  advanceAdjustTimeToMinutes,
  resolveAdvanceAdjustDefaultStartTime,
  resolveAdvanceAdjustPreviewGapColor,
  resolveAdvanceAdjustPreviewGapMessage,
  resolveAdvanceAdjustPreviewRangeMessage,
  resolveAdvanceAdjustSelectedIds,
  resolveAdvanceAdjustSelectedSummary
} from '../main/ets/pages/components/dialogs/AdvanceAdjustDialog';
import {
  AdvanceAdjustCandidate,
  AdvanceAdjustContext,
  AdvanceAdjustPreview
} from '../main/ets/viewmodel/TimelineViewModel';

interface AdvanceAdjustDialogPrivateTest {
  targetName: string;
  context: AdvanceAdjustContext | null;
  selectedIds: Set<number>;
  targetStartTime: string;
  preview: AdvanceAdjustPreview | null;
  initialRender(): void;
}

class AdvanceAdjustCandidateTest implements AdvanceAdjustCandidate {
  id: number = 0;
  index: number = 0;
  name: string = '';
  currentStartTime: string = '';
  currentEndTime: string = '';
  duration: number = 0;
}

function buildAdvanceAdjustCandidateTest(
  id: number,
  index: number,
  name: string,
  currentStartTime: string,
  currentEndTime: string,
  duration: number
): AdvanceAdjustCandidate {
  const candidate = new AdvanceAdjustCandidateTest();
  candidate.id = id;
  candidate.index = index;
  candidate.name = name;
  candidate.currentStartTime = currentStartTime;
  candidate.currentEndTime = currentEndTime;
  candidate.duration = duration;
  return candidate;
}

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

    it('boundary: advance_adjust_should_pad_single_digit_minute_when_formatting_time', 0, () => {
      // Arrange
      const minutes = 125;
      // Act
      const time = advanceAdjustMinutesToTime(minutes);
      // Assert
      expect(time).assertEqual('02:05');
    });

    it('invalid: advance_adjust_should_return_zero_when_time_part_is_not_finite_number', 0, () => {
      // Arrange
      const time = '08:ab';
      // Act
      const minutes = advanceAdjustTimeToMinutes(time);
      // Assert
      expect(minutes).assertEqual(0);
    });

    it('combined: advance_adjust_selection_should_add_target_id_when_checked', 0, () => {
      // Arrange
      const selectedIds = new Set<number>();
      // Act
      const nextSelectedIds = toggleAdvanceAdjustSelection(selectedIds, 7, true);
      // Assert
      expect(nextSelectedIds.has(7)).assertTrue();
      expect(nextSelectedIds.size).assertEqual(1);
    });

    it('normal: advance_adjust_selected_ids_should_include_all_candidates', 0, () => {
      // Arrange
      const candidates: AdvanceAdjustCandidate[] = [];
      candidates.push(buildAdvanceAdjustCandidateTest(1, 0, 'a', '08:00', '09:00', 60));
      candidates.push(buildAdvanceAdjustCandidateTest(2, 1, 'b', '09:10', '10:00', 50));

      // Act
      const selectedIds = resolveAdvanceAdjustSelectedIds(candidates);

      // Assert
      expect(selectedIds.has(1)).assertTrue();
      expect(selectedIds.has(2)).assertTrue();
      expect(selectedIds.size).assertEqual(2);
    });

    it('boundary: advance_adjust_preview_helpers_should_fallback_for_null_preview', 0, () => {
      // Arrange
      const preview = null;

      // Act
      const summary = resolveAdvanceAdjustSelectedSummary(preview);
      const gapMessage = resolveAdvanceAdjustPreviewGapMessage(preview);
      const gapColor = resolveAdvanceAdjustPreviewGapColor(preview);
      const rangeMessage = resolveAdvanceAdjustPreviewRangeMessage(preview);

      // Assert
      expect(summary).assertEqual('已选 0 个，预计前移 0 分钟');
      expect(gapMessage).assertEqual('最少前移 0 分钟；已达到消冲突阈值');
      expect(gapColor).assertEqual('#2E7D32');
      expect(rangeMessage).assertEqual('首地点：-，末地点：-');
    });

    it('conflict: advance_adjust_preview_helpers_should_show_remaining_gap_warning', 0, () => {
      // Arrange
      const preview: AdvanceAdjustPreview = {
        valid: false,
        message: '还不够',
        selectedCount: 2,
        shiftMinutes: 15,
        requiredGapMinutes: 30,
        remainingGapMinutes: 15,
        firstNewStartTime: '08:45',
        lastNewEndTime: '10:20',
        items: []
      };

      // Act
      const summary = resolveAdvanceAdjustSelectedSummary(preview);
      const gapMessage = resolveAdvanceAdjustPreviewGapMessage(preview);
      const gapColor = resolveAdvanceAdjustPreviewGapColor(preview);
      const rangeMessage = resolveAdvanceAdjustPreviewRangeMessage(preview);

      // Assert
      expect(summary).assertEqual('已选 2 个，预计前移 15 分钟');
      expect(gapMessage).assertEqual('最少前移 30 分钟；还差 15 分钟');
      expect(gapColor).assertEqual('#FF4D4F');
      expect(rangeMessage).assertEqual('首地点：08:45，末地点：10:20');
    });

    it('combined: advance_adjust_dialog_initial_render_should_support_valid_preview_branch', 0, () => {
      // Arrange
      const page = new AdvanceAdjustDialog(undefined, {} as LocalStorage) as Object as AdvanceAdjustDialogPrivateTest;
      let threw = false;

      // Act
      page.targetName = '午餐';
      page.context = {
        targetIndex: 2,
        targetId: 200,
        targetDayOffset: 0,
        candidates: [
          buildAdvanceAdjustCandidateTest(1, 0, '早餐', '08:00', '09:00', 60),
          buildAdvanceAdjustCandidateTest(2, 1, '通勤', '09:10', '09:40', 30)
        ]
      };
      page.selectedIds = new Set<number>([1, 2]);
      page.targetStartTime = '07:30';
      page.preview = {
        valid: true,
        message: 'ok',
        selectedCount: 2,
        shiftMinutes: 30,
        requiredGapMinutes: 20,
        remainingGapMinutes: 0,
        firstNewStartTime: '07:30',
        lastNewEndTime: '09:10',
        items: []
      };
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('regression: advance_adjust_dialog_initial_render_should_support_empty_context_branch', 0, () => {
      // Arrange
      const page = new AdvanceAdjustDialog(undefined, {} as LocalStorage) as Object as AdvanceAdjustDialogPrivateTest;
      let threw = false;

      // Act
      page.targetName = '冲突点';
      page.context = null;
      page.selectedIds = new Set<number>();
      page.targetStartTime = '';
      page.preview = null;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: advance_adjust_time_to_minutes_should_clamp_hour_and_minute_overflows', 0, () => {
      // Arrange
      const overflowTime = '99:88';
      const negativeTime = '-1:-5';
      // Act
      const overflowMinutes = advanceAdjustTimeToMinutes(overflowTime);
      const negativeMinutes = advanceAdjustTimeToMinutes(negativeTime);
      // Assert
      expect(overflowMinutes).assertEqual(23 * 60 + 59);
      expect(negativeMinutes).assertEqual(0);
    });

    it('boundary: advance_adjust_minutes_to_time_should_floor_decimal_and_wrap_next_day', 0, () => {
      // Arrange
      const minutes = (24 * 60) + 61.8;
      // Act
      const time = advanceAdjustMinutesToTime(minutes);
      // Assert
      expect(time).assertEqual('01:01');
    });

    it('combined: advance_adjust_selection_should_remove_id_without_mutating_source_set', 0, () => {
      // Arrange
      const selectedIds = new Set<number>([3, 7]);
      // Act
      const nextSelectedIds = toggleAdvanceAdjustSelection(selectedIds, 7, false);
      // Assert
      expect(nextSelectedIds.has(7)).assertFalse();
      expect(nextSelectedIds.has(3)).assertTrue();
      expect(selectedIds.has(7)).assertTrue();
    });

    it('boundary: advance_adjust_selected_ids_should_return_empty_set_for_empty_candidates', 0, () => {
      // Arrange
      const candidates: AdvanceAdjustCandidate[] = [];
      // Act
      const selectedIds = resolveAdvanceAdjustSelectedIds(candidates);
      // Assert
      expect(selectedIds.size).assertEqual(0);
    });

    it('conflict: advance_adjust_default_start_should_not_move_before_day_start', 0, () => {
      // Arrange
      const currentStart = '00:10';
      const forcedGap = 45;
      // Act
      const target = resolveAdvanceAdjustDefaultStartTime(currentStart, forcedGap);
      // Assert
      expect(target).assertEqual('00:00');
    });
  });
}
