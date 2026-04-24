import { describe, it, expect } from '@ohos/hypium';
import {
  hasPositiveAllocationValues,
  resolveGapTierColor,
  resolveGapTierLabel
} from '../main/ets/pages/components/dialogs/GapResolutionDialog';

export default function gapResolutionDialogHelperTest() {
  describe('unit_test_case_generator_autofill_GapResolutionDialogHelper', () => {
    it('normal: gap_resolution_should_resolve_efficiency_tier_label', 0, () => {
      // Arrange
      const min = 40;
      const trigger = 30;
      // Act
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(label).assertEqual('效率补全');
    });

    it('boundary: gap_resolution_should_return_empty_label_below_trigger', 0, () => {
      // Arrange
      const min = 29;
      const trigger = 30;
      // Act
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(label).assertEqual('');
    });

    it('invalid: gap_resolution_positive_allocation_should_reject_all_non_positive_values', 0, () => {
      // Arrange
      const values = [0, -1, 0];
      // Act
      const positive = hasPositiveAllocationValues(values);
      // Assert
      expect(positive).assertFalse();
    });

    it('conflict: gap_resolution_should_distinguish_blue_and_gold_tiers', 0, () => {
      // Arrange
      const blueMin = 90;
      const goldMin = 150;
      const trigger = 30;
      // Act
      const blueColor = resolveGapTierColor(blueMin, trigger);
      const goldColor = resolveGapTierColor(goldMin, trigger);
      // Assert
      expect(blueColor).assertEqual('#007DFF');
      expect(goldColor).assertEqual('#FFB800');
    });

    it('regression: td-20260412-gap-resolution-green-color-should-stay-4caf50', 0, () => {
      // Arrange
      const min = 45;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      // Assert
      expect(color).assertEqual('#4CAF50');
    });

    it('combined: gap_resolution_tier_and_positive_allocation_should_align', 0, () => {
      // Arrange
      const min = 95;
      const trigger = 30;
      const values = [0, 10, 0];
      // Act
      const label = resolveGapTierLabel(min, trigger);
      const hasPositive = hasPositiveAllocationValues(values);
      // Assert
      expect(label).assertEqual('体验升级');
      expect(hasPositive).assertTrue();
    });

    it('boundary: gap_resolution_tier_should_return_gold_label_at_150_minutes', 0, () => {
      // Arrange
      const min = 150;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(color).assertEqual('#FFB800');
      expect(label).assertEqual('黄金重排');
    });

    it('boundary: gap_resolution_tier_should_return_blue_label_at_90_minutes', 0, () => {
      // Arrange
      const min = 90;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      const label = resolveGapTierLabel(min, trigger);
      // Assert
      expect(color).assertEqual('#007DFF');
      expect(label).assertEqual('体验升级');
    });

    it('invalid: gap_resolution_tier_color_should_return_empty_below_trigger', 0, () => {
      // Arrange
      const min = 29;
      const trigger = 30;
      // Act
      const color = resolveGapTierColor(min, trigger);
      // Assert
      expect(color).assertEqual('');
    });

    it('combined: gap_resolution_positive_allocation_should_accept_positive_fraction', 0, () => {
      // Arrange
      const values = [0, 0.5, -1];
      // Act
      const positive = hasPositiveAllocationValues(values);
      // Assert
      expect(positive).assertTrue();
    });
  });
}
