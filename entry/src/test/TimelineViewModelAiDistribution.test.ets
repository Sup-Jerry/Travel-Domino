import { describe, it, expect } from '@ohos/hypium';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

export default function timelineViewModelAiDistributionTest() {
  describe('timelineViewModelAiDistributionTest', () => {
    it('build_ai_day_offsets_should_split_evenly', 0, () => {
      const offsets = TimelineViewModel.buildAiDayOffsetsForTest(7, 3, 0);
      expect(offsets.length).assertEqual(7);
      expect(offsets[0]).assertEqual(0);
      expect(offsets[1]).assertEqual(0);
      expect(offsets[2]).assertEqual(0);
      expect(offsets[3]).assertEqual(1);
      expect(offsets[4]).assertEqual(1);
      expect(offsets[5]).assertEqual(2);
      expect(offsets[6]).assertEqual(2);
    });

    it('clamp_distribution_add_should_cap_single_item_duration_to_240', 0, () => {
      expect(TimelineViewModel.clampDistributionAddForTest(230, 30)).assertEqual(10);
      expect(TimelineViewModel.clampDistributionAddForTest(240, 50)).assertEqual(0);
      expect(TimelineViewModel.clampDistributionAddForTest(100, 20)).assertEqual(20);
    });
  });
}
