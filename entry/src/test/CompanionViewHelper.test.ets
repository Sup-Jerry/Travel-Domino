import { describe, it, expect } from '@ohos/hypium';
import {
  isCompanionOverlayVisible,
  resolveCompanionBackLevel
} from '../main/ets/pages/components/views/CompanionView';

export default function companionViewHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionViewHelper', () => {
    it('normal: companion_back_level_should_be_overlay_when_any_overlay_visible', 0, () => {
      // Arrange
      const showHistoryPage = true;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(level).assertEqual('overlay');
    });

    it('boundary: companion_back_level_should_be_control_without_overlays_in_control_mode', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'control');
      // Assert
      expect(level).assertEqual('control');
    });

    it('invalid: companion_overlay_visible_should_be_false_when_all_flags_false', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: companion_overlay_visible_should_be_true_when_history_and_search_both_open', 0, () => {
      // Arrange
      const showHistoryPage = true;
      const showSearchPage = true;
      const showFilterPage = false;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      // Assert
      expect(visible).assertTrue();
    });

    it('regression: td-20260412-companion-back-level-immersive-default-should-stay', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(level).assertEqual('immersive');
    });

    it('combined: companion_overlay_and_back_level_should_be_consistent', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = true;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'control');
      // Assert
      expect(visible).assertTrue();
      expect(level).assertEqual('overlay');
    });
  });
}
