import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { InitDialogData, PendingItemData } from './IndexTypes';
import { IndexPageBindingsBuilder } from './IndexPageBindingsBuilder';

export class IndexPageDialogFlowHelper {
  static openAddDialog(
    vm: TimelineViewModel,
    editingItemId: number,
    currentPlanId: number,
    collapsedDayOffsets: number[],
    onGapFoundCallback: (item: EventEntity) => void,
    onSetCollapsedDayOffsets: (offsets: number[]) => void,
    onSetPendingItem: (item: PendingItemData | null) => void,
    onOpenConflictDialog: () => void,
    onSetEditingItemId: (id: number) => void,
    safeShowToast: (message: string) => void,
    initData?: InitDialogData
  ): CustomDialogController {
    const controller = IndexPageBindingsBuilder.createAddDialogController({
      vm: vm,
      editingItemId: editingItemId,
      currentPlanId: currentPlanId,
      collapsedDayOffsets: collapsedDayOffsets,
      setCollapsedDayOffsets: (offsets: number[]): void => onSetCollapsedDayOffsets(offsets),
      onGapFoundCallback: onGapFoundCallback,
      setPendingItem: (item: PendingItemData | null): void => onSetPendingItem(item),
      openConflictDialog: (): void => onOpenConflictDialog(),
      setEditingItemId: (id: number): void => onSetEditingItemId(id),
      safeShowToast: (message: string): void => safeShowToast(message)
    });
    controller.open();
    return controller;
  }

  static openConflictDialog(
    vm: TimelineViewModel,
    getUIContext: () => UIContext,
    getPendingItem: () => PendingItemData | null,
    onSetPendingItem: (item: PendingItemData | null) => void,
    onOpenAddDialog: (initData?: InitDialogData) => void,
    onReopenConflictDialog: () => void,
    safeShowToast: (message: string) => void
  ): CustomDialogController {
    const controller = IndexPageBindingsBuilder.createConflictDialogController({
      vm: vm,
      getUIContext: (): UIContext => getUIContext(),
      getPendingItem: (): PendingItemData | null => getPendingItem(),
      setPendingItem: (item: PendingItemData | null): void => onSetPendingItem(item),
      openDialog: (initData?: InitDialogData): void => onOpenAddDialog(initData),
      reopenConflictDialog: (): void => onReopenConflictDialog(),
      safeShowToast: (message: string): void => safeShowToast(message)
    });
    controller.open();
    return controller;
  }
}
