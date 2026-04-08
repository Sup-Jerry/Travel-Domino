import { ComposableStrategy } from '../../domain/strategy/TravelStrategyDimensions';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { InitDialogData, PendingItemData } from './IndexTypes';
import { IndexAddDialogControllerHelper } from './IndexAddDialogControllerHelper';
import { IndexDialogManager } from './IndexDialogManager';

export interface IndexAiDialogControllerContext {
  vm: TimelineViewModel;
  safeShowToast: (message: string) => void;
  onCloseDialog: () => void;
}

export interface IndexAddDialogControllerContext {
  vm: TimelineViewModel;
  editingItemId: number;
  currentPlanId: number;
  initData?: InitDialogData;
  collapsedDayOffsets: number[];
  setCollapsedDayOffsets: (offsets: number[]) => void;
  onGapFoundCallback: (item: EventEntity) => void;
  setPendingItem: (item: PendingItemData | null) => void;
  openConflictDialog: () => void;
  setEditingItemId: (id: number) => void;
  safeShowToast: (message: string) => void;
}

export class IndexDialogBindingsHelper {
  static createAiDialogController(context: IndexAiDialogControllerContext): CustomDialogController {
    return IndexDialogManager.createAiDialogController({
      hasAiHistory: context.vm.hasAiHistory(),
      onConfirm: async (text: string, strategy: number, customStrategy?: ComposableStrategy): Promise<void> => {
        try {
          await context.vm.generateByAi(text, strategy, customStrategy);
          context.safeShowToast('AI 生成成功，已加入暂存池！');
        } catch (error) {
          const msg = error instanceof Error ? error.message : '生成失败';
          context.safeShowToast(msg);
        } finally {
          context.onCloseDialog();
        }
      },
      onRegenerate: async (): Promise<void> => {
        try {
          await context.vm.regenerateByCurrentStrategy();
          context.safeShowToast('重新生成成功');
        } catch (error) {
          const msg = error instanceof Error ? error.message : '重新生成失败';
          console.error('[Index] AI重新规划失败:', JSON.stringify(error));
          context.safeShowToast(msg);
        } finally {
          context.onCloseDialog();
        }
      }
    });
  }

  static createAddDialogController(context: IndexAddDialogControllerContext): CustomDialogController {
    return IndexAddDialogControllerHelper.create({
      vm: context.vm,
      editingItemId: context.editingItemId,
      currentPlanId: context.currentPlanId,
      collapsedDayOffsets: context.collapsedDayOffsets,
      setCollapsedDayOffsets: (offsets: number[]): void => {
        context.setCollapsedDayOffsets(offsets);
      },
      clearFilter: (): void => {
        context.vm.clearFilter();
      },
      hasActiveFilter: context.vm.filterStart > 0 || context.vm.filterEnd > 0,
      onGapFoundCallback: context.onGapFoundCallback,
      setPendingItem: (item: PendingItemData | null): void => {
        context.setPendingItem(item);
      },
      openConflictDialog: (): void => {
        context.openConflictDialog();
      },
      setEditingItemId: (id: number): void => {
        context.setEditingItemId(id);
      },
      safeShowToast: (message: string): void => {
        context.safeShowToast(message);
      }
    }, context.initData);
  }
}
