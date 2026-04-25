import { describe, it, expect } from '@ohos/hypium';
import {
  AiReplanPreviewDialog,
  buildAiReplanPreviewSummary,
  getAiReplanItemTypeLabel,
  getAiReplanStrategyLabel
} from '../main/ets/pages/components/dialogs/AiReplanPreviewDialog';
import {
  AiReplanPreviewItem,
  AiReplanPreviewResult
} from '../main/ets/domain/timeline/services/TimelineAiService';

class DialogControllerMockAiReplanPreview {
  close(): void {
  }
}

interface AiReplanPreviewDialogPrivateTest {
  controller?: DialogControllerMockAiReplanPreview;
  preview: AiReplanPreviewResult;
  effectiveTheme: string;
  buildStrategyLabel(mode: number): string;
  initialRender(): void;
  setController(controller: DialogControllerMockAiReplanPreview): void;
}

class AiReplanPreviewItemTest implements AiReplanPreviewItem {
  name: string = '';
  duration: number = 0;
  itemType: number = 0;
  aiReasoning: string = '';
}

function buildAiReplanPreviewItemTest(name: string, itemType: number, duration: number): AiReplanPreviewItem {
  const item = new AiReplanPreviewItemTest();
  item.name = name;
  item.itemType = itemType;
  item.duration = duration;
  item.aiReasoning = 'reason';
  return item;
}

export default function aiReplanPreviewDialogHelperTest() {
  describe('unit_test_case_generator_autofill_AiReplanPreviewDialogHelper', () => {
    it('combined: ai_replan_preview_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new AiReplanPreviewDialog(undefined, {} as LocalStorage) as Object as AiReplanPreviewDialogPrivateTest;
      const first = new DialogControllerMockAiReplanPreview();
      const second = new DialogControllerMockAiReplanPreview();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('normal: ai_replan_should_map_food_item_type_label', 0, () => {
      // Arrange
      const itemType = 1;
      // Act
      const label = getAiReplanItemTypeLabel(itemType);
      // Assert
      expect(label).assertEqual('美食');
    });

    it('boundary: ai_replan_should_map_default_strategy_mode_to_default_label', 0, () => {
      // Arrange
      const mode = 0;
      // Act
      const label = getAiReplanStrategyLabel(mode);
      // Assert
      expect(label).assertEqual('默认');
    });

    it('invalid: ai_replan_should_fallback_to_scenery_label_for_unknown_item_type', 0, () => {
      // Arrange
      const itemType = 999;
      // Act
      const label = getAiReplanItemTypeLabel(itemType);
      // Assert
      expect(label).assertEqual('景点');
    });

    it('boundary: ai_replan_should_map_hotel_item_type_label', 0, () => {
      // Arrange
      const itemType = 2;
      // Act
      const label = getAiReplanItemTypeLabel(itemType);
      // Assert
      expect(label).assertEqual('住宿');
    });

    it('conflict: ai_replan_should_distinguish_special_and_leisure_modes', 0, () => {
      // Arrange
      const specialMode = 1;
      const leisureMode = 2;
      // Act
      const specialLabel = getAiReplanStrategyLabel(specialMode);
      const leisureLabel = getAiReplanStrategyLabel(leisureMode);
      // Assert
      expect(specialLabel).assertEqual('特种兵');
      expect(leisureLabel).assertEqual('休闲');
    });

    it('regression: td-20260412-ai-replan-custom-mode-should-stay-custom-label', 0, () => {
      // Arrange
      const mode = -1;
      // Act
      const label = getAiReplanStrategyLabel(mode);
      // Assert
      expect(label).assertEqual('自定义');
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
    it('normal: ai_replan_preview_summary_should_include_count_and_strategy', 0, () => {
      // Arrange
      const preview: AiReplanPreviewResult = {
        prompt: 'xian trip',
        strategyMode: 2,
        generatedAt: 1,
        itemCount: 3,
        items: []
      };

      // Act
      const summary = buildAiReplanPreviewSummary(preview);

      // Assert
      expect(summary.indexOf('3') >= 0).assertTrue();
      expect(summary.indexOf('休闲') >= 0).assertTrue();
    });

    it('boundary: ai_replan_preview_dialog_private_strategy_label_should_delegate_modes', 0, () => {
      // Arrange
      const page = new AiReplanPreviewDialog(undefined, {} as LocalStorage) as Object as AiReplanPreviewDialogPrivateTest;

      // Act
      const customLabel = page.buildStrategyLabel(-1);
      const defaultLabel = page.buildStrategyLabel(0);

      // Assert
      expect(customLabel).assertEqual('自定义');
      expect(defaultLabel).assertEqual('默认');
    });

    it('combined: ai_replan_preview_dialog_initial_render_should_support_item_list_branch', 0, () => {
      // Arrange
      const page = new AiReplanPreviewDialog(undefined, {} as LocalStorage) as Object as AiReplanPreviewDialogPrivateTest;
      const items: AiReplanPreviewItem[] = [];
      let threw = false;

      // Act
      items.push(buildAiReplanPreviewItemTest('museum', 0, 90));
      items.push(buildAiReplanPreviewItemTest('lunch', 1, 60));
      page.preview = {
        prompt: 'culture route',
        strategyMode: -1,
        generatedAt: 1,
        itemCount: 2,
        items: items
      };
      page.effectiveTheme = 'dark';
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
