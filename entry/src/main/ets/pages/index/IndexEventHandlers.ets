import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { TimelineInteractionHelper } from '../../viewmodel/TimelineInteractionHelper';

export type ConflictActionStrategy = 'delay' | 'compress' | 'advance' | 'smart';
export type IndexEventVoidCallback = () => void;
export type IndexEventEntityCallback = (event: EventEntity) => void;
export type IndexEventConflictCallback = (
  event: EventEntity,
  action: ConflictActionStrategy,
  gap: number
) => void;

export class IndexEventHandlers {
  static handleFilter(onOpenFilter: IndexEventVoidCallback): void {
    onOpenFilter();
  }

  static handleMoveUp(vm: TimelineViewModel, item: EventEntity): void {
    vm.moveEvent(vm.events.indexOf(item), 'up');
  }

  static handleMoveDown(vm: TimelineViewModel, item: EventEntity): void {
    vm.moveEvent(vm.events.indexOf(item), 'down');
  }

  static handleDragDrop(vm: TimelineViewModel, item: EventEntity, direction: 'up' | 'down'): void {
    vm.moveEvent(vm.events.indexOf(item), direction);
  }

  static handleMainContentClick(
    isArchived: boolean,
    item: EventEntity,
    onOpenEdit: IndexEventEntityCallback
  ): void {
    if (isArchived) {
      return;
    }
    onOpenEdit(item);
  }

  static handleEditItem(
    isArchived: boolean,
    item: EventEntity,
    onOpenEdit: IndexEventEntityCallback
  ): void {
    IndexEventHandlers.handleMainContentClick(isArchived, item, onOpenEdit);
  }

  static handleTimeClick(
    isArchived: boolean,
    item: EventEntity,
    onOpenTimeEdit: IndexEventEntityCallback
  ): void {
    if (isArchived) {
      return;
    }
    onOpenTimeEdit(item);
  }

  static handleDeleteItem(item: EventEntity, onDelete: IndexEventEntityCallback): void {
    onDelete(item);
  }

  static handleMoveToBacklog(item: EventEntity, onMove: IndexEventEntityCallback): void {
    onMove(item);
  }

  static handleAddItem(
    isArchived: boolean,
    onBlocked: IndexEventVoidCallback,
    onOpenAdd: IndexEventVoidCallback
  ): void {
    IndexEventHandlers.handleBottomAdd(isArchived, onBlocked, onOpenAdd);
  }

  static handleTravelModeChange(vm: TimelineViewModel, item: EventEntity, mode: number): void {
    vm.updateTravelMode(item, mode);
  }

  static handleManualTravelInput(vm: TimelineViewModel, item: EventEntity, minutes: number): void {
    vm.updateManualCommute(item, minutes);
  }

  static handleCommuteChange(
    vm: TimelineViewModel,
    item: EventEntity,
    minutes: number,
    onGapFound: IndexEventEntityCallback
  ): void {
    TimelineInteractionHelper.handleCommuteChange(vm, item, minutes, onGapFound);
  }

  static handleConflictAction(
    isArchived: boolean,
    item: EventEntity,
    strategy: ConflictActionStrategy,
    gapMinutes: number,
    onHandleConflict: IndexEventConflictCallback
  ): void {
    if (isArchived) {
      return;
    }
    onHandleConflict(item, strategy, gapMinutes);
  }

  static handleDateConflict(
    isArchived: boolean,
    item: EventEntity,
    strategy: ConflictActionStrategy,
    gapMinutes: number,
    onHandleConflict: IndexEventConflictCallback
  ): void {
    IndexEventHandlers.handleConflictAction(isArchived, item, strategy, gapMinutes, onHandleConflict);
  }

  static handleAiSuggestion(
    isArchived: boolean,
    onBlocked: IndexEventVoidCallback,
    onOpenAi: IndexEventVoidCallback
  ): void {
    IndexEventHandlers.handleBottomAi(isArchived, onBlocked, onOpenAi);
  }

  static handleBottomAi(
    isArchived: boolean,
    onBlocked: IndexEventVoidCallback,
    onOpenAi: IndexEventVoidCallback
  ): void {
    if (isArchived) {
      onBlocked();
      return;
    }
    onOpenAi();
  }

  static handleBottomAdd(
    isArchived: boolean,
    onBlocked: IndexEventVoidCallback,
    onOpenAdd: IndexEventVoidCallback
  ): void {
    if (isArchived) {
      onBlocked();
      return;
    }
    onOpenAdd();
  }
}
