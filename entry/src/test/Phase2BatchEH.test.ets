import { describe, expect, it } from '@ohos/hypium';
import { IndexBottomBar } from '../main/ets/pages/index/IndexBottomBar';

interface IndexBottomBarPrivateEH {
  aiEnabled: boolean;
  addEnabled: boolean;
  onFilter: () => void;
  onAi: () => void;
  onAdd: () => void;
  initialRender(): void;
}

function createIndexBottomBarEH(): IndexBottomBarPrivateEH {
  return new IndexBottomBar(undefined, {} as LocalStorage) as Object as IndexBottomBarPrivateEH;
}

export default function phase2BatchEHTest() {
  describe('phase2BatchEHTest', () => {
    it('normal: index_bottom_bar_initial_render_should_support_all_enabled_actions', 0, () => {
      // Arrange
      const page = createIndexBottomBarEH();
      let filterCount = 0;
      let aiCount = 0;
      let addCount = 0;
      let threw = false;
      page.aiEnabled = true;
      page.addEnabled = true;
      page.onFilter = (): void => {
        filterCount += 1;
      };
      page.onAi = (): void => {
        aiCount += 1;
      };
      page.onAdd = (): void => {
        addCount += 1;
      };

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(filterCount).assertEqual(0);
      expect(aiCount).assertEqual(0);
      expect(addCount).assertEqual(0);
    });

    it('boundary: index_bottom_bar_initial_render_should_support_disabled_ai_and_add', 0, () => {
      // Arrange
      const page = createIndexBottomBarEH();
      let threw = false;
      page.aiEnabled = false;
      page.addEnabled = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.aiEnabled).assertFalse();
      expect(page.addEnabled).assertFalse();
    });
  });
}
