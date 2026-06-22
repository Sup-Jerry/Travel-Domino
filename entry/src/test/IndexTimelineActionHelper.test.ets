import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexTimelineActionHelper } from '../main/ets/pages/index/IndexTimelineActionHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface TimelineActionVm {
  refreshTimelineView(): void;
  moveToBacklog(item: EventEntity): Promise<void>;
  hardDelete(item: EventEntity): Promise<void>;
}

class TimelineActionVmMock implements TimelineActionVm {
  public refreshCount: number = 0;
  public moveItemId: number = -1;
  public hardDeleteItemId: number = -1;
  private readonly shouldRejectMove: boolean;

  constructor(shouldRejectMove: boolean) {
    this.shouldRejectMove = shouldRejectMove;
  }

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }

  moveToBacklog(item: EventEntity): Promise<void> {
    this.moveItemId = item.id;
    if (this.shouldRejectMove) {
      return Promise.reject(new Error('move_failed'));
    }
    return Promise.resolve();
  }

  hardDelete(item: EventEntity): Promise<void> {
    this.hardDeleteItemId = item.id;
    return Promise.resolve();
  }
}

class TimelineActionAlertButtonTest {
  value: string = '';
  action: () => void = () => {};
}

class TimelineActionAlertOptionsTest {
  title: string = '';
  message: string = '';
  primaryButton: TimelineActionAlertButtonTest = new TimelineActionAlertButtonTest();
  secondaryButton: TimelineActionAlertButtonTest = new TimelineActionAlertButtonTest();
}

class TimelineActionUiContextMockTest {
  alertCount: number = 0;
  lastAlert: TimelineActionAlertOptionsTest | null = null;

  showAlertDialog(options: TimelineActionAlertOptionsTest): void {
    this.alertCount += 1;
    this.lastAlert = options;
  }
}

function buildTimelineEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `E${id}`;
  event.note = `note-${id}`;
  event.duration = 45;
  event.fixed_start_time = '10:30';
  event.lock_status = 1;
  event.day_offset = 1;
  event.dynamic_day_offset = 2;
  event.status = 1;
  event.latitude = 31.1;
  event.longitude = 121.5;
  return event;
}

export default function indexTimelineActionHelperTest() {
  describe('unit_test_case_generator_autofill_IndexTimelineActionHelper', () => {
    it('normal: handle_move_to_backlog_should_refresh_before_and_after_success', 0, async (done: Function) => {
      // Arrange
      const event = buildTimelineEvent(1);
      const vm = new TimelineActionVmMock(false);
      let toastCount = 0;
      // Act
      IndexTimelineActionHelper.handleMoveToBacklog(
        vm as Object as TimelineViewModel,
        event,
        (_message: string) => {
          toastCount += 1;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(vm.moveItemId).assertEqual(1);
      expect(vm.refreshCount).assertEqual(2);
      expect(toastCount).assertEqual(0);
      done();
    });

    it('boundary: handle_move_to_backlog_should_block_non_schedule_items', 0, () => {
      // Arrange
      const event = buildTimelineEvent(2);
      event.status = 0;
      const vm = new TimelineActionVmMock(false);
      let toastCount = 0;
      // Act
      IndexTimelineActionHelper.handleMoveToBacklog(
        vm as Object as TimelineViewModel,
        event,
        (_message: string) => {
          toastCount += 1;
        }
      );
      // Assert
      expect(vm.moveItemId).assertEqual(-1);
      expect(vm.refreshCount).assertEqual(0);
      expect(toastCount).assertEqual(1);
    });

    it('invalid: handle_move_to_backlog_should_toast_when_move_failed', 0, async (done: Function) => {
      // Arrange
      const event = buildTimelineEvent(3);
      const vm = new TimelineActionVmMock(true);
      let toastCount = 0;
      // Act
      IndexTimelineActionHelper.handleMoveToBacklog(
        vm as Object as TimelineViewModel,
        event,
        (_message: string) => {
          toastCount += 1;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(vm.moveItemId).assertEqual(3);
      expect(vm.refreshCount).assertEqual(1);
      expect(toastCount).assertEqual(1);
      done();
    });

    it('conflict: build_edit_dialog_data_should_prefer_dynamic_day_offset', 0, () => {
      // Arrange
      const event = buildTimelineEvent(4);
      event.day_offset = 0;
      event.dynamic_day_offset = 5;
      // Act
      const data = IndexTimelineActionHelper.buildEditDialogData(event);
      // Assert
      expect(data.dayOffset).assertEqual(5);
      expect(data.isAnchor).assertTrue();
      expect(data.fixedTime).assertEqual('10:30');
    });

    it('regression: build_edit_dialog_data_should_fallback_to_day_offset_when_dynamic_invalid', 0, () => {
      // Arrange
      const event = buildTimelineEvent(5);
      event.dynamic_day_offset = Number.NaN;
      event.day_offset = 7;
      // Act
      const data = IndexTimelineActionHelper.buildEditDialogData(event);
      // Assert
      expect(data.dayOffset).assertEqual(7);
    });

    it('combined: build_edit_dialog_data_should_keep_payload_even_with_invalid_coordinates', 0, () => {
      // Arrange
      const event = buildTimelineEvent(6);
      event.lock_status = 0;
      event.fixed_start_time = '';
      event.latitude = 0;
      event.longitude = 0;
      // Act
      const data = IndexTimelineActionHelper.buildEditDialogData(event);
      // Assert
      expect(data.name).assertEqual('E6');
      expect(data.isAnchor).assertFalse();
      expect(data.fixedTime).assertEqual('');
      expect(data.lat).assertEqual(0);
      expect(data.lng).assertEqual(0);
    });

    it('combined: confirm_delete_timeline_event_should_keep_cancel_noop_and_execute_delete_confirm', 0, async (done: Function) => {
      // Arrange
      const event = buildTimelineEvent(7);
      const vm = new TimelineActionVmMock(false);
      const uiContext = new TimelineActionUiContextMockTest();

      // Act
      IndexTimelineActionHelper.confirmDeleteTimelineEvent(
        uiContext as Object as UIContext,
        vm as Object as TimelineViewModel,
        event
      );
      (uiContext.lastAlert as TimelineActionAlertOptionsTest).primaryButton.action();
      (uiContext.lastAlert as TimelineActionAlertOptionsTest).secondaryButton.action();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(uiContext.alertCount).assertEqual(1);
      expect(vm.refreshCount).assertEqual(2);
      expect(vm.hardDeleteItemId).assertEqual(7);
      done();
    });
  });
}
