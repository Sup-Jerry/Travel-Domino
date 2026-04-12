import { describe, it, expect } from '@ohos/hypium';
import {
  getAiReplanItemTypeLabel,
  getAiReplanStrategyLabel
} from '../main/ets/pages/components/dialogs/AiReplanPreviewDialog';

export default function aiReplanPreviewDialogHelperTest() {
  describe('unit_test_case_generator_autofill_AiReplanPreviewDialogHelper', () => {
    it('normal: ai_replan_should_map_food_item_type_label', 0, () => {
      // Arrange
      const itemType = 1;
      // Act
      const label = getAiReplanItemTypeLabel(itemType);
      // Assert
      expect(label).assertEqual('缇庨');
    });

    it('boundary: ai_replan_should_map_default_strategy_mode_to_default_label', 0, () => {
      // Arrange
      const mode = 0;
      // Act
      const label = getAiReplanStrategyLabel(mode);
      // Assert
      expect(label).assertEqual('榛樿');
    });

    it('invalid: ai_replan_should_fallback_to_scenery_label_for_unknown_item_type', 0, () => {
      // Arrange
      const itemType = 999;
      // Act
      const label = getAiReplanItemTypeLabel(itemType);
      // Assert
      expect(label).assertEqual('鏅偣');
    });

    it('conflict: ai_replan_should_distinguish_special_and_leisure_modes', 0, () => {
      // Arrange
      const specialMode = 1;
      const leisureMode = 2;
      // Act
      const specialLabel = getAiReplanStrategyLabel(specialMode);
      const leisureLabel = getAiReplanStrategyLabel(leisureMode);
      // Assert
      expect(specialLabel).assertEqual('鐗圭鍏?');
      expect(leisureLabel).assertEqual('浼戦棽');
    });

    it('regression: td-20260412-ai-replan-custom-mode-should-stay-custom-label', 0, () => {
      // Arrange
      const mode = -1;
      // Act
      const label = getAiReplanStrategyLabel(mode);
      // Assert
      expect(label).assertEqual('鑷畾涔?');
    });

    it('combined: ai_replan_strategy_and_item_labels_should_be_non_empty', 0, () => {
      // Arrange
      const mode = 2;
      const itemType = 0;
      // Act
      const strategyLabel = getAiReplanStrategyLabel(mode);
      const itemLabel = getAiReplanItemTypeLabel(itemType);
      // Assert
      expect(strategyLabel.length > 0).assertTrue();
      expect(itemLabel.length > 0).assertTrue();
    });
  });
}
