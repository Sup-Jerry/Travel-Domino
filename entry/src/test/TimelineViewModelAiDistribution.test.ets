import { describe, it, expect } from '@ohos/hypium';
import { TimelineDistributionService } from '../main/ets/domain/timeline/services/TimelineDistributionService';
import { TimelineAiService } from '../main/ets/domain/timeline/services/TimelineAiService';

export default function timelineViewModelAiDistributionTest() {
  describe('timelineViewModelAiDistributionTest', () => {
    it('normal: build_ai_day_offsets_should_split_evenly', 0, () => {
      // Arrange
      // Act
      // Assert
      const offsets = TimelineAiService.buildAiDayOffsets(7, 3, 0);
      expect(offsets.length).assertEqual(7);
      expect(offsets[0]).assertEqual(0);
      expect(offsets[1]).assertEqual(0);
      expect(offsets[2]).assertEqual(0);
      expect(offsets[3]).assertEqual(1);
      expect(offsets[4]).assertEqual(1);
      expect(offsets[5]).assertEqual(2);
      expect(offsets[6]).assertEqual(2);
    });

    it('boundary: clamp_distribution_add_should_cap_single_item_duration_to_240', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(TimelineDistributionService.clampDistributionAdd(230, 30)).assertEqual(10);
      expect(TimelineDistributionService.clampDistributionAdd(240, 50)).assertEqual(0);
      expect(TimelineDistributionService.clampDistributionAdd(100, 20)).assertEqual(20);
    });
  });
  describe('unit_test_case_generator_backfill_TimelineViewModelAiDistribution', () => {
    it('invalid: build_ai_day_offsets_should_return_empty_when_total_items_non_positive', 0, () => {
      // Arrange
      // Act
      const offsets = TimelineAiService.buildAiDayOffsets(0, 3, 1);
      // Assert
      expect(offsets.length).assertEqual(0);
    });

    it('conflict: clamp_distribution_add_should_resolve_capacity_conflict_to_zero', 0, () => {
      // Arrange
      const currentDuration = 300;
      // Act
      const add = TimelineDistributionService.clampDistributionAdd(currentDuration, 40);
      // Assert
      expect(add).assertEqual(0);
    });

    it('regression: td-20260411-build_ai_day_offsets_should_keep_base_offset_even_when_days_invalid', 0, () => {
      // Arrange
      // Act
      const offsets = TimelineAiService.buildAiDayOffsets(3, 0, 5);
      // Assert
      expect(offsets.length).assertEqual(3);
      expect(offsets[0]).assertEqual(5);
      expect(offsets[1]).assertEqual(5);
      expect(offsets[2]).assertEqual(5);
    });

    it('combined: build_offsets_and_clamp_should_keep_day_split_and_single_item_cap_together', 0, () => {
      // Arrange
      const offsets = TimelineAiService.buildAiDayOffsets(4, 2, 2);
      // Act
      const cappedAdd = TimelineDistributionService.clampDistributionAdd(235, 20);
      // Assert
      expect(offsets[0]).assertEqual(2);
      expect(offsets[1]).assertEqual(2);
      expect(offsets[2]).assertEqual(3);
      expect(offsets[3]).assertEqual(3);
      expect(cappedAdd).assertEqual(5);
    });
  });
}
