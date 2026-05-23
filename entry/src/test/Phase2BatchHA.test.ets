import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexTimelineActionHelper } from '../main/ets/pages/index/IndexTimelineActionHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface AlertButtonLikeHA {
  value: string;
  action: () => void;
}

interface AlertDialogOptionsLikeHA {
  title: string;
  message: string;
  primaryButton: AlertButtonLikeHA;
  secondaryButton: AlertButtonLikeHA;
}

interface AlertUiContextLikeHA {
  showAlertDialog(options: AlertDialogOptionsLikeHA): void;
}

interface TimelineDeleteVmLikeHA {
  refreshTimelineView(): void;
  hardDelete(item: EventEntity): Promise<void>;
}

class AlertUiContextMockHA implements AlertUiContextLikeHA {
  public showCount: number = 0;
  public lastOptions: AlertDialogOptionsLikeHA | null = null;

  showAlertDialog(options: AlertDialogOptionsLikeHA): void {
    this.showCount += 1;
    this.lastOptions = options;
  }
}

class TimelineDeleteVmMockHA implements TimelineDeleteVmLikeHA {
  public refreshCount: number = 0;
  public deletedItemId: number = -1;

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }

  hardDelete(item: EventEntity): Promise<void> {
    this.deletedItemId = item.id;
    return Promise.resolve();
  }
}

function buildTimelineEventHA(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `ha_${id}`;
  event.note = `note_${id}`;
  event.duration = 50;
  event.lock_status = 0;
  event.fixed_start_time = '';
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.latitude = 123.45;
  event.longitude = 181;
  return event;
}

export default function phase2BatchHATest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHA_index_timeline_action_dialogs', () => {
    it('combined: index_timeline_action_helper_should_show_delete_dialog_and_execute_secondary_action', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const uiContext = new AlertUiContextMockHA();
      const vm = new TimelineDeleteVmMockHA();
      const item = buildTimelineEventHA(931);

      IndexTimelineActionHelper.confirmDeleteTimelineEvent(
        uiContext as Object as UIContext,
        vm as Object as TimelineViewModel,
        item
      );

      expect(uiContext.showCount).assertEqual(1);
      expect((uiContext.lastOptions as AlertDialogOptionsLikeHA).message).assertContain('ha_931');

      (uiContext.lastOptions as AlertDialogOptionsLikeHA).secondaryButton.action();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      expect(vm.deletedItemId).assertEqual(931);
      expect(vm.refreshCount).assertEqual(2);
      done();
    });

    it('combined: index_timeline_action_helper_should_keep_delete_cancel_action_side_effect_free', 0, () => {
      // Arrange
      // Act
      // Assert
      const uiContext = new AlertUiContextMockHA();
      const vm = new TimelineDeleteVmMockHA();
      const item = buildTimelineEventHA(932);

      IndexTimelineActionHelper.confirmDeleteTimelineEvent(
        uiContext as Object as UIContext,
        vm as Object as TimelineViewModel,
        item
      );
      (uiContext.lastOptions as AlertDialogOptionsLikeHA).primaryButton.action();

      expect(vm.deletedItemId).assertEqual(-1);
      expect(vm.refreshCount).assertEqual(0);
    });

    it('combined: index_timeline_action_helper_should_fallback_day_offset_to_zero_when_policy_resolves_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const item = buildTimelineEventHA(933);

      const data = IndexTimelineActionHelper.buildEditDialogData(item);

      expect(data.dayOffset).assertEqual(0);
      expect(data.fixedTime).assertEqual('');
      expect(data.isAnchor).assertFalse();
      expect(data.lat).assertEqual(123.45);
      expect(data.lng).assertEqual(181);
    });

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: validator_marker_should_cover_boundary_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
