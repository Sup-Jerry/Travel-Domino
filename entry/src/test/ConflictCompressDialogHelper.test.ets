import { describe, it, expect } from '@ohos/hypium';
import {
  canConflictCompressConfirm,
  ConflictCompressDialog,
  ConflictCompressAffectedItem,
  resolveConflictCompressPreviewNewDuration,
  resolveConflictCompressPreviewReduced,
  resolveConflictCompressRemainingGap,
  shouldShowConflictCompressOverload
} from '../main/ets/pages/components/dialogs/ConflictCompressDialog';
import {
  CompressionPlan,
  CompressionSelectionContext
} from '../main/ets/viewmodel/TimelineViewModel';

class DialogControllerMockConflictCompress {
  close(): void {
  }
}

interface ConflictCompressDialogPrivateTest {
  controller?: DialogControllerMockConflictCompress;
  targetIndex: number;
  targetTime: string;
  targetName: string;
  context: CompressionSelectionContext | null;
  selectedIds: Set<number>;
  previewPlan: CompressionPlan | null;
  safeShowToast(message: string, duration?: number): void;
  initialRender(): void;
  setController(controller: DialogControllerMockConflictCompress): void;
}

class MockAffectedItem implements ConflictCompressAffectedItem {
  index: number = 0;
  newVal: number = 0;
}

function buildAffectedItem(index: number, newVal: number): ConflictCompressAffectedItem {
  const item = new MockAffectedItem();
  item.index = index;
  item.newVal = newVal;
  return item;
}

export default function conflictCompressDialogHelperTest() {
  describe('unit_test_case_generator_autofill_ConflictCompressDialogHelper', () => {
    it('combined: conflict_compress_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new ConflictCompressDialog(undefined, {} as LocalStorage) as Object as ConflictCompressDialogPrivateTest;
      const first = new DialogControllerMockConflictCompress();
      const second = new DialogControllerMockConflictCompress();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('normal: conflict_compress_confirm_should_pass_with_positive_selection', 0, () => {
      // Arrange
      const selectedCount = 2;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertTrue();
    });

    it('boundary: conflict_compress_confirm_should_fail_with_zero_selection', 0, () => {
      // Arrange
      const selectedCount = 0;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      // Assert
      expect(canConfirm).assertFalse();
    });

    it('invalid: conflict_compress_overload_should_hide_when_status_not_overload', 0, () => {
      // Arrange
      const status = 'OK';
      const remaining = 10;
      // Act
      const show = shouldShowConflictCompressOverload(status, remaining);
      // Assert
      expect(show).assertFalse();
    });

    it('conflict: conflict_compress_overload_should_show_when_overload_and_remaining_positive', 0, () => {
      // Arrange
      const status = 'OVERLOAD';
      const remaining = 5;
      // Act
      const show = shouldShowConflictCompressOverload(status, remaining);
      // Assert
      expect(show).assertTrue();
    });

    it('regression: td-20260412-conflict-compress-overload-zero-remaining-should-hide', 0, () => {
      // Arrange
      const status = 'OVERLOAD';
      const remaining = 0;
      // Act
      const show = shouldShowConflictCompressOverload(status, remaining);
      // Assert
      expect(show).assertFalse();
    });

    it('combined: conflict_compress_confirm_and_overload_checks_should_be_independent', 0, () => {
      // Arrange
      const selectedCount = 1;
      // Act
      const canConfirm = canConflictCompressConfirm(selectedCount);
      const showOverload = shouldShowConflictCompressOverload('OVERLOAD', 8);
      // Assert
      expect(canConfirm).assertTrue();
      expect(showOverload).assertTrue();
    });

    it('normal: conflict_compress_preview_new_duration_should_use_affected_match', 0, () => {
      // Arrange
      const affectedItems: ConflictCompressAffectedItem[] = [];
      affectedItems.push(buildAffectedItem(3, 42));
      // Act
      const value = resolveConflictCompressPreviewNewDuration(affectedItems, 3, 60);
      // Assert
      expect(value).assertEqual(42);
    });

    it('boundary: conflict_compress_preview_new_duration_should_fallback_when_affected_empty', 0, () => {
      // Arrange
      const affectedItems: ConflictCompressAffectedItem[] = [];
      // Act
      const value = resolveConflictCompressPreviewNewDuration(affectedItems, 9, 35);
      // Assert
      expect(value).assertEqual(35);
    });

    it('invalid: conflict_compress_remaining_gap_should_fallback_to_zero_for_undefined', 0, () => {
      // Arrange
      const remainingGap = undefined;
      // Act
      const value = resolveConflictCompressRemainingGap(remainingGap);
      // Assert
      expect(value).assertEqual(0);
    });

    it('conflict: conflict_compress_reduced_should_support_negative_delta_when_new_duration_grows', 0, () => {
      // Arrange
      const oldVal = 20;
      const newVal = 24;
      // Act
      const reduced = resolveConflictCompressPreviewReduced(oldVal, newVal);
      // Assert
      expect(reduced).assertEqual(-4);
    });

    it('regression: td-20260412-conflict-compress-reduced-should-stay-difference', 0, () => {
      // Arrange
      const oldVal = 55;
      const newVal = 40;
      // Act
      const reduced = resolveConflictCompressPreviewReduced(oldVal, newVal);
      // Assert
      expect(reduced).assertEqual(15);
    });

    it('combined: conflict_compress_preview_helpers_should_link_new_duration_reduce_and_gap', 0, () => {
      // Arrange
      const affectedItems: ConflictCompressAffectedItem[] = [];
      affectedItems.push(buildAffectedItem(1, 30));
      // Act
      const newVal = resolveConflictCompressPreviewNewDuration(affectedItems, 1, 50);
      const reduced = resolveConflictCompressPreviewReduced(50, newVal);
      const gap = resolveConflictCompressRemainingGap(12);
      // Assert
      expect(newVal).assertEqual(30);
      expect(reduced).assertEqual(20);
      expect(gap).assertEqual(12);
    });

    it('boundary: conflict_compress_dialog_safe_show_toast_should_support_optional_duration', 0, () => {
      // Arrange
      const page = new ConflictCompressDialog(undefined, {} as LocalStorage) as Object as ConflictCompressDialogPrivateTest;
      let threw = false;

      // Act
      try {
        page.safeShowToast('compress toast');
        page.safeShowToast('compress toast timed', 1200);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('normal: conflict_compress_dialog_initial_render_should_support_selectable_preview_branch', 0, () => {
      // Arrange
      const page = new ConflictCompressDialog(undefined, {} as LocalStorage) as Object as ConflictCompressDialogPrivateTest;
      let threw = false;

      // Act
      page.targetIndex = 2;
      page.targetTime = '10:30';
      page.targetName = '博物馆';
      page.context = {
        targetIndex: 2,
        targetTime: '10:30',
        neededGapMinutes: 30,
        naturalArrivalMinutes: 650,
        chainStartIndex: 0,
        candidates: [
          { id: 1, index: 0, name: '早餐', oldVal: 60, minAllowed: 30, maxReducible: 30, isRigid: false, selectable: true },
          { id: 2, index: 1, name: '地铁', oldVal: 35, minAllowed: 35, maxReducible: 0, isRigid: true, selectable: false, disabledReason: '刚性地点不可压缩' }
        ]
      };
      page.selectedIds = new Set<number>([1]);
      page.previewPlan = {
        status: 'COMPRESS_CONFIRM',
        msg: 'ok',
        affectedItems: [{ index: 0, name: '早餐', oldVal: 60, newVal: 40 }],
        remainingGapMinutes: 0,
        capacityMinutes: 30,
        mode: 'RATIO'
      };
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: conflict_compress_dialog_initial_render_should_support_overload_branch', 0, () => {
      // Arrange
      const page = new ConflictCompressDialog(undefined, {} as LocalStorage) as Object as ConflictCompressDialogPrivateTest;
      let threw = false;

      // Act
      page.targetIndex = 3;
      page.targetTime = '12:00';
      page.targetName = '午餐';
      page.context = {
        targetIndex: 3,
        targetTime: '12:00',
        neededGapMinutes: 45,
        naturalArrivalMinutes: 735,
        chainStartIndex: 1,
        candidates: [
          { id: 11, index: 1, name: '景点A', oldVal: 50, minAllowed: 30, maxReducible: 20, isRigid: false, selectable: true }
        ]
      };
      page.selectedIds = new Set<number>([11]);
      page.previewPlan = {
        status: 'OVERLOAD',
        msg: 'overload',
        affectedItems: [{ index: 1, name: '景点A', oldVal: 50, newVal: 30 }],
        remainingGapMinutes: 25,
        capacityMinutes: 20,
        suggestedTime: '12:25',
        mode: 'EQUAL'
      };
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}
