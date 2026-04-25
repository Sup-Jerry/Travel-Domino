import { describe, expect, it } from '@ohos/hypium';
import {
  resolveIndexScheduleBottomBarAddEnabled,
  resolveIndexScheduleBottomBarAiEnabled,
  resolveIndexScheduleUnsavedMarginBottom,
  shouldShowIndexScheduleBottomBar
} from '../main/ets/pages/index/IndexScheduleArea';

export default function phase2BatchHKTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHK_index_schedule_area_edges', () => {
    it('combined: index_schedule_area_should_hide_bottom_bar_and_keep_actions_disabled_matrix', 0, () => {
      const hidden = shouldShowIndexScheduleBottomBar(true);
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(true);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(true);
      const margin = resolveIndexScheduleUnsavedMarginBottom(true);

      expect(hidden).assertFalse();
      expect(aiEnabled).assertFalse();
      expect(addEnabled).assertFalse();
      expect(margin).assertEqual(30);
    });

    it('combined: index_schedule_area_should_show_bottom_bar_and_keep_actions_enabled_matrix', 0, () => {
      const shown = shouldShowIndexScheduleBottomBar(false);
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(false);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(false);
      const margin = resolveIndexScheduleUnsavedMarginBottom(false);

      expect(shown).assertTrue();
      expect(aiEnabled).assertTrue();
      expect(addEnabled).assertTrue();
      expect(margin).assertEqual(96);
    });

    it('combined: index_schedule_area_should_keep_same_ai_and_add_enablement_for_same_archive_flag', 0, () => {
      const archivedAi = resolveIndexScheduleBottomBarAiEnabled(true);
      const archivedAdd = resolveIndexScheduleBottomBarAddEnabled(true);
      const activeAi = resolveIndexScheduleBottomBarAiEnabled(false);
      const activeAdd = resolveIndexScheduleBottomBarAddEnabled(false);

      expect(archivedAi === archivedAdd).assertTrue();
      expect(activeAi === activeAdd).assertTrue();
    });
  });
}
