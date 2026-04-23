import { describe, expect, it } from '@ohos/hypium';
import { RenameDialog } from '../main/ets/pages/components/dialogs/RenameDialog';
import { TipDialog } from '../main/ets/pages/components/dialogs/TipDialog';

class DialogControllerMockED {
  public closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

interface RenameDialogPrivateED {
  controller: DialogControllerMockED;
  initName: string;
  name: string;
  onConfirm: (newName: string) => void;
  aboutToAppear(): void;
  initialRender(): void;
}

interface TipDialogPrivateED {
  controller: DialogControllerMockED;
  title: string;
  message: string;
  storageKey: string;
  isChecked: boolean;
  onConfirm: () => void;
  initialRender(): void;
}

function createRenameDialogED(controller: DialogControllerMockED): RenameDialogPrivateED {
  const page = new RenameDialog(undefined, {} as LocalStorage) as Object as RenameDialogPrivateED;
  page.controller = controller;
  return page;
}

function createTipDialogED(controller: DialogControllerMockED): TipDialogPrivateED {
  const page = new TipDialog(undefined, {} as LocalStorage) as Object as TipDialogPrivateED;
  page.controller = controller;
  return page;
}

export default function phase2BatchEDTest() {
  describe('phase2BatchEDTest', () => {
    it('normal: rename_dialog_about_to_appear_should_copy_initial_name', 0, () => {
      // Arrange
      const page = createRenameDialogED(new DialogControllerMockED());
      page.initName = 'Tokyo Plan';

      // Act
      page.aboutToAppear();

      // Assert
      expect(page.name).assertEqual('Tokyo Plan');
    });

    it('boundary: rename_dialog_initial_render_should_support_empty_name', 0, () => {
      // Arrange
      const page = createRenameDialogED(new DialogControllerMockED());
      let threw = false;
      page.name = '';

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: rename_dialog_initial_render_should_support_prefilled_name', 0, () => {
      // Arrange
      const page = createRenameDialogED(new DialogControllerMockED());
      let confirmedName = '';
      let threw = false;
      page.name = 'Kyoto Plan';
      page.onConfirm = (newName: string): void => {
        confirmedName = newName;
      };

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(confirmedName).assertEqual('');
    });

    it('regression: tip_dialog_initial_render_should_support_unchecked_choice', 0, () => {
      // Arrange
      const page = createTipDialogED(new DialogControllerMockED());
      let confirmed = false;
      let threw = false;
      page.title = 'Import Tip';
      page.message = 'Keep this tip visible.';
      page.storageKey = 'ed_tip_unchecked';
      page.isChecked = false;
      page.onConfirm = (): void => {
        confirmed = true;
      };

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(confirmed).assertFalse();
    });

    it('conflict: tip_dialog_initial_render_should_support_checked_choice', 0, () => {
      // Arrange
      const page = createTipDialogED(new DialogControllerMockED());
      let threw = false;
      page.title = 'Route Tip';
      page.message = 'Persist choice only after user confirms.';
      page.storageKey = 'ed_tip_checked';
      page.isChecked = true;

      // Act
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
