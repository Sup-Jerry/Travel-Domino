import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ConflictActionStrategy, IndexEventHandlers } from '../main/ets/pages/index/IndexEventHandlers';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface EventHandlerVm {
  events: EventEntity[];
  moveEvent(index: number, direction: 'up' | 'down'): void;
  updateTravelMode(item: EventEntity, mode: number): void;
  updateManualCommute(item: EventEntity, minutes: number): void;
}

class EventHandlerVmMock implements EventHandlerVm {
  public events: EventEntity[];
  public moveIndex: number = -2;
  public moveDirection: string = '';
  public travelMode: number = -1;
  public manualMinutes: number = -1;

  constructor(events: EventEntity[]) {
    this.events = events;
  }

  moveEvent(index: number, direction: 'up' | 'down'): void {
    this.moveIndex = index;
    this.moveDirection = direction;
  }

  updateTravelMode(_item: EventEntity, mode: number): void {
    this.travelMode = mode;
  }

  updateManualCommute(_item: EventEntity, minutes: number): void {
    this.manualMinutes = minutes;
  }
}

function buildHandlerEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `E${id}`;
  return event;
}

export default function indexEventHandlersTest() {
  describe('unit_test_case_generator_autofill_IndexEventHandlers', () => {
    it('normal: handle_move_up_should_use_current_item_index', 0, () => {
      // Arrange
      const target = buildHandlerEvent(2);
      const vm = new EventHandlerVmMock([buildHandlerEvent(1), target, buildHandlerEvent(3)]);
      // Act
      IndexEventHandlers.handleMoveUp(vm as Object as TimelineViewModel, target);
      // Assert
      expect(vm.moveIndex).assertEqual(1);
      expect(vm.moveDirection).assertEqual('up');
    });

    it('boundary: handle_main_content_click_should_ignore_archived_plan', 0, () => {
      // Arrange
      const item = buildHandlerEvent(4);
      let editCalled = false;
      // Act
      IndexEventHandlers.handleMainContentClick(true, item, (_event: EventEntity) => {
        editCalled = true;
      });
      // Assert
      expect(editCalled).assertFalse();
    });

    it('invalid: handle_move_down_should_pass_negative_index_when_item_missing', 0, () => {
      // Arrange
      const missing = buildHandlerEvent(5);
      const vm = new EventHandlerVmMock([buildHandlerEvent(1), buildHandlerEvent(2)]);
      // Act
      IndexEventHandlers.handleMoveDown(vm as Object as TimelineViewModel, missing);
      // Assert
      expect(vm.moveIndex).assertEqual(-1);
      expect(vm.moveDirection).assertEqual('down');
    });

    it('conflict: handle_conflict_action_should_not_dispatch_when_archived', 0, () => {
      // Arrange
      const item = buildHandlerEvent(6);
      let conflictCalled = false;
      // Act
      IndexEventHandlers.handleConflictAction(
        true,
        item,
        'delay',
        12,
        (_event: EventEntity, _action: ConflictActionStrategy, _gap: number) => {
          conflictCalled = true;
        }
      );
      // Assert
      expect(conflictCalled).assertFalse();
    });

    it('regression: handle_bottom_ai_should_block_archived_and_open_active', 0, () => {
      // Arrange
      let blocked = 0;
      let opened = 0;
      // Act
      IndexEventHandlers.handleBottomAi(true, () => {
        blocked += 1;
      }, () => {
        opened += 1;
      });
      IndexEventHandlers.handleBottomAi(false, () => {
        blocked += 1;
      }, () => {
        opened += 1;
      });
      // Assert
      expect(blocked).assertEqual(1);
      expect(opened).assertEqual(1);
    });

    it('combined: add_and_commute_actions_should_update_vm_and_open_add', 0, () => {
      // Arrange
      const item = buildHandlerEvent(7);
      const vm = new EventHandlerVmMock([item]);
      let addOpened = false;
      let addBlocked = false;
      // Act
      IndexEventHandlers.handleBottomAdd(false, () => {
        addBlocked = true;
      }, () => {
        addOpened = true;
      });
      IndexEventHandlers.handleTravelModeChange(vm as Object as TimelineViewModel, item, 3);
      IndexEventHandlers.handleManualTravelInput(vm as Object as TimelineViewModel, item, 18);
      // Assert
      expect(addOpened).assertTrue();
      expect(addBlocked).assertFalse();
      expect(vm.travelMode).assertEqual(3);
      expect(vm.manualMinutes).assertEqual(18);
    });
  });
}
