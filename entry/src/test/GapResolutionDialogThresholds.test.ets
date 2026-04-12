import { describe, it, expect } from '@ohos/hypium';
import {
  hasPositiveAllocationValues,
  resolveGapTierColor,
  resolveGapTierLabel
} from '../main/ets/pages/components/dialogs/GapResolutionDialog';

export default function gapResolutionDialogThresholdsTest() {
  describe('unit_test_case_generator_autofill_GapResolutionDialogThresholds', () => {
    it('normal: gap_threshold_should_return_gold_tier_at_150_and_above', 0, () => {
      // Arrange
      const trigger = 30;

      // Act
      const color = resolveGapTierColor(150, trigger);
      const label = resolveGapTierLabel(180, trigger);

      // Assert
      expect(color).assertEqual('#FFB800');
      expect(label).assertEqual('\u9EC4\u91D1\u91CD\u6392');
    });

    it('boundary: gap_threshold_should_switch_from_green_to_blue_at_90', 0, () => {
      // Arrange
      const trigger = 30;

      // Act
      const before = resolveGapTierColor(89, trigger);
      const at = resolveGapTierColor(90, trigger);

      // Assert
      expect(before).assertEqual('#4CAF50');
      expect(at).assertEqual('#007DFF');
    });

    it('invalid: gap_threshold_should_return_empty_when_trigger_is_not_met', 0, () => {
      // Arrange
      const trigger = 45;

      // Act
      const color = resolveGapTierColor(44, trigger);
      const label = resolveGapTierLabel(44, trigger);

      // Assert
      expect(color).assertEqual('');
      expect(label).assertEqual('');
    });

    it('conflict: gap_label_should_prioritize_blue_tier_over_trigger_label', 0, () => {
      // Arrange
      const trigger = 20;

      // Act
      const label = resolveGapTierLabel(120, trigger);

      // Assert
      expect(label).assertEqual('\u4F53\u9A8C\u5347\u7EA7');
    });

    it('regression: td-20260412-gap-positive-allocation-should-ignore-zero-and-negative', 0, () => {
      // Arrange
      const values = [0, -3, 0, -1];

      // Act
      const hasPositive = hasPositiveAllocationValues(values);

      // Assert
      expect(hasPositive).assertFalse();
    });

    it('combined: gap_threshold_and_positive_allocation_should_align_for_trigger_edge', 0, () => {
      // Arrange
      const trigger = 60;
      const values = [0, 5, 0];

      // Act
      const color = resolveGapTierColor(60, trigger);
      const label = resolveGapTierLabel(60, trigger);
      const hasPositive = hasPositiveAllocationValues(values);

      // Assert
      expect(color).assertEqual('#4CAF50');
      expect(label).assertEqual('\u6548\u7387\u8865\u5168');
      expect(hasPositive).assertTrue();
    });
  });
}

