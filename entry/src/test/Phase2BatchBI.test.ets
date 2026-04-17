import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexTimelineActionHelper } from '../main/ets/pages/index/IndexTimelineActionHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface AlertDialogButtonLikeBI {
  value: string;
  action: () => void;
}

interface AlertDialogOptionsLikeBI {
  title: string;
  message: string;
  autoCancel: boolean;
  primaryButton: AlertDialogButtonLikeBI;
  secondaryButton: AlertDialogButtonLikeBI;
}

class DialogUiContextMockBI {
  showCount: number = 0;
  lastOptions?: AlertDialogOptionsLikeBI;

  showAlertDialog(options: AlertDialogOptionsLikeBI): void {
    this.showCount += 1;
    this.lastOptions = options;
  }
}

interface TimelineDeleteVmBI {
  refreshTimelineView(): void;
  hardDelete(item: EventEntity): Promise<void>;
}

class TimelineDeleteVmMockBI implements TimelineDeleteVmBI {
  refreshCount: number = 0;
  hardDeleteCount: number = 0;
  hardDeleteItemId: number = -1;
  private readonly pendingDelete: boolean;

  constructor(pendingDelete: boolean) {
    this.pendingDelete = pendingDelete;
  }

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }

  hardDelete(item: EventEntity): Promise<void> {
    this.hardDeleteCount += 1;
    this.hardDeleteItemId = item.id;
    if (this.pendingDelete) {
      return new Promise<void>(() => {});
    }
    return Promise.resolve();
  }
}

function sleepBI(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function buildTimelineEventBI(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

export default function phase2BatchBITest() {
  describe('phase2BatchBITest', () => {
    it('normal: index_timeline_action_helper_confirm_delete_should_refresh_before_and_after_successful_delete', 0, async (done: Function) => {
      // Arrange
      const uiContext = new DialogUiContextMockBI();
      const vm = new TimelineDeleteVmMockBI(false);
      const event = buildTimelineEventBI(101, '西湖');
      // Act
      IndexTimelineActionHelper.confirmDeleteTimelineEvent(
        uiContext as Object as UIContext,
        vm as Object as TimelineViewModel,
        event
      );
      const options = uiContext.lastOptions as AlertDialogOptionsLikeBI;
      options.secondaryButton.action();
      await sleepBI(30);
      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(options.title).assertEqual('确认删除');
      expect(options.message.includes('"西湖"')).assertTrue();
      expect(vm.hardDeleteCount).assertEqual(1);
      expect(vm.hardDeleteItemId).assertEqual(101);
      expect(vm.refreshCount).assertEqual(2);
      done();
    });

    it('boundary: index_timeline_action_helper_confirm_delete_should_keep_vm_unchanged_when_primary_button_clicked', 0, () => {
      // Arrange
      const uiContext = new DialogUiContextMockBI();
      const vm = new TimelineDeleteVmMockBI(false);
      const event = buildTimelineEventBI(102, '故宫');
      // Act
      IndexTimelineActionHelper.confirmDeleteTimelineEvent(
        uiContext as Object as UIContext,
        vm as Object as TimelineViewModel,
        event
      );
      const options = uiContext.lastOptions as AlertDialogOptionsLikeBI;
      options.primaryButton.action();
      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(options.autoCancel).assertTrue();
      expect(vm.hardDeleteCount).assertEqual(0);
      expect(vm.refreshCount).assertEqual(0);
    });

    it('invalid: index_timeline_action_helper_confirm_delete_should_only_refresh_once_when_delete_not_completed', 0, async (done: Function) => {
      // Arrange
      const uiContext = new DialogUiContextMockBI();
      const vm = new TimelineDeleteVmMockBI(true);
      const event = buildTimelineEventBI(103, '无效数据');
      // Act
      IndexTimelineActionHelper.confirmDeleteTimelineEvent(
        uiContext as Object as UIContext,
        vm as Object as TimelineViewModel,
        event
      );
      const options = uiContext.lastOptions as AlertDialogOptionsLikeBI;
      options.secondaryButton.action();
      await sleepBI(30);
      // Assert
      expect(vm.hardDeleteCount).assertEqual(1);
      expect(vm.hardDeleteItemId).assertEqual(103);
      expect(vm.refreshCount).assertEqual(1);
      done();
    });
  });
}
