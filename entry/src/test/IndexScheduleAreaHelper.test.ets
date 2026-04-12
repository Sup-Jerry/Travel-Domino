import { describe, it, expect } from '@ohos/hypium';
import {
  resolveIndexScheduleBottomBarAddEnabled,
  resolveIndexScheduleBottomBarAiEnabled,
  resolveIndexScheduleUnsavedMarginBottom,
  shouldShowIndexScheduleBottomBar
} from '../main/ets/pages/index/IndexScheduleArea';

export default function indexScheduleAreaHelperTest() {
  describe('unit_test_case_generator_autofill_IndexScheduleAreaHelper', () => {
    it('normal: schedule_bottom_bar_should_show_when_not_in_companion_mode', 0, () => {
      // Arrange
      const isCompanionMode = false;

      // Act
      const show = shouldShowIndexScheduleBottomBar(isCompanionMode);

      // Assert
      expect(show).assertTrue();
    });

    it('boundary: schedule_bottom_bar_should_hide_in_companion_mode', 0, () => {
      // Arrange
      const isCompanionMode = true;

      // Act
      const show = shouldShowIndexScheduleBottomBar(isCompanionMode);

      // Assert
      expect(show).assertFalse();
    });

    it('invalid: schedule_bottom_bar_actions_should_disable_when_archived', 0, () => {
      // Arrange
      const isArchived = true;

      // Act
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(isArchived);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(isArchived);

      // Assert
      expect(aiEnabled).assertFalse();
      expect(addEnabled).assertFalse();
    });

    it('conflict: schedule_bottom_bar_actions_should_enable_when_not_archived', 0, () => {
      // Arrange
      const isArchived = false;

      // Act
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(isArchived);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(isArchived);

      // Assert
      expect(aiEnabled).assertTrue();
      expect(addEnabled).assertTrue();
    });

    it('regression: schedule_unsaved_margin_should_match_mode_switch', 0, () => {
      // Arrange
      const companionMode = true;
      const normalMode = false;

      // Act
      const companionMargin = resolveIndexScheduleUnsavedMarginBottom(companionMode);
      const normalMargin = resolveIndexScheduleUnsavedMarginBottom(normalMode);

      // Assert
      expect(companionMargin).assertEqual(30);
      expect(normalMargin).assertEqual(96);
    });

    it('combined: schedule_helper_matrix_should_keep_visibility_enablement_and_margin_consistent', 0, () => {
      // Arrange
      const showBottomBar = shouldShowIndexScheduleBottomBar(false);
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(false);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(false);
      const margin = resolveIndexScheduleUnsavedMarginBottom(true);

      // Act
      const pass = showBottomBar && aiEnabled && addEnabled && margin === 30;

      // Assert
      expect(pass).assertTrue();
    });
  });
}

