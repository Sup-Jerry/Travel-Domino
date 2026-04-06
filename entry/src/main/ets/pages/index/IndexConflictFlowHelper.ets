import { hilog } from '@kit.PerformanceAnalysisKit';
import { CompressionMode, CompressionPlan, TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { EventEntity } from '../../model/entity/EventEntity';
import { IndexDialogManager } from './IndexDialogManager';
import { IndexConflictHelper } from './IndexConflictHelper';

export type ConflictStrategy = 'delay' | 'compress' | 'advance' | 'smart';

export interface ConflictFlowContext {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  setConflictSelectionController: (controller: CustomDialogController | null) => void;
  setConflictCompressController: (controller: CustomDialogController | null) => void;
  setConflictAdvanceController: (controller: CustomDialogController | null) => void;
  setSuggestionDialogController: (controller: CustomDialogController | null) => void;
}

export class IndexConflictFlowHelper {
  static handleEventConflictAction(
    context: ConflictFlowContext,
    item: EventEntity,
    strategy: ConflictStrategy,
    gapMinutes: number,
    onDone?: () => void
  ): void {
    IndexConflictHelper.handleEventConflictAction(
      context.vm,
      item,
      strategy,
      gapMinutes,
      onDone,
      (index: number, target: EventEntity, targetTime: string, plan: CompressionPlan,
        saveCallback: (t?: string) => void, onBack: () => void): void => {
        IndexConflictFlowHelper.openPreview(context, index, target, targetTime, plan, saveCallback, onBack);
      },
      (index: number, target: EventEntity, targetTime: string, saveCallback: (t?: string) => void): void => {
        IndexConflictFlowHelper.openAdvanceAdjustDialog(context, index, target, targetTime, saveCallback);
      },
      (index: number, target: EventEntity, targetTime: string, saveCallback: (t?: string) => void, onBack: () => void): void => {
        IndexConflictFlowHelper.openCompressSelectionDialog(context, index, target, targetTime, saveCallback, onBack);
      },
      (index: number, target: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void): void => {
        IndexConflictFlowHelper.openConflictMenu(context, index, target, targetTime, gap, saveCallback);
      }
    );
  }

  static requestPlanDateUpdate(context: ConflictFlowContext, newDateTimestamp: number): void {
    IndexConflictHelper.requestPlanDateUpdate(
      context.vm,
      newDateTimestamp,
      (index: number, item: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void): void => {
        IndexConflictFlowHelper.openConflictMenu(context, index, item, targetTime, gap, saveCallback);
      }
    );
  }

  static openConflictMenu(
    context: ConflictFlowContext,
    index: number,
    item: EventEntity,
    targetTime: string,
    gap: number,
    saveCallback: (t?: string) => void
  ): void {
    const controller = IndexConflictHelper.openConflictMenu(
      context.vm,
      index,
      item,
      targetTime,
      gap,
      saveCallback,
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void): void => {
        IndexConflictFlowHelper.openPreview(context, indexVal, itemVal, targetTimeVal, plan, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void, backFn: () => void): void => {
        IndexConflictFlowHelper.openCompressSelectionDialog(context, indexVal, itemVal, targetTimeVal, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void): void => {
        IndexConflictFlowHelper.openAdvanceAdjustDialog(context, indexVal, itemVal, targetTimeVal, saveFn);
      }
    );
    context.setConflictSelectionController(controller);
  }

  private static openAdvanceAdjustDialog(
    context: ConflictFlowContext,
    index: number,
    item: EventEntity,
    targetTime: string,
    saveCallback: (t?: string) => void
  ): void {
    const controller = IndexConflictHelper.openAdvanceAdjustDialog(
      context.vm,
      index,
      item,
      targetTime,
      saveCallback,
      (message: string): void => {
        context.safeShowToast(message);
      },
      (): void => {
        IndexConflictFlowHelper.openAdvanceAdjustDialog(context, index, item, targetTime, saveCallback);
      },
      (gap: number): void => {
        IndexConflictFlowHelper.openConflictMenu(context, index, item, targetTime, gap, saveCallback);
      }
    );
    context.setConflictAdvanceController(controller);
  }

  private static showCompressionBlockedDialog(
    context: ConflictFlowContext,
    index: number,
    item: EventEntity,
    targetTime: string,
    plan: CompressionPlan,
    selectedIds: number[],
    mode: CompressionMode,
    saveCallback: (t?: string) => void,
    onBack: () => void
  ): void {
    IndexConflictHelper.showCompressionBlockedDialog(
      context.getUIContext(),
      index,
      item,
      targetTime,
      plan,
      selectedIds,
      mode,
      saveCallback,
      onBack,
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void, backFn: () => void,
        presetSelectedIds: number[], presetMode: CompressionMode): void => {
        IndexConflictFlowHelper.openCompressSelectionDialog(
          context,
          indexVal,
          itemVal,
          targetTimeVal,
          saveFn,
          backFn,
          presetSelectedIds,
          presetMode
        );
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, nextPlan: CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void): void => {
        IndexConflictFlowHelper.openPreview(context, indexVal, itemVal, targetTimeVal, nextPlan, saveFn, backFn);
      },
      context.vm
    );
  }

  private static openCompressSelectionDialog(
    context: ConflictFlowContext,
    index: number,
    item: EventEntity,
    targetTime: string,
    saveCallback: (t?: string) => void,
    onBack: () => void,
    presetSelectedIds: number[] = [],
    presetMode: CompressionMode = 'RATIO'
  ): void {
    const controller = IndexConflictHelper.openCompressSelectionDialog(
      context.vm,
      index,
      item,
      targetTime,
      saveCallback,
      onBack,
      (message: string): void => {
        context.safeShowToast(message);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: CompressionPlan,
        saveFn: (t?: string) => void, backFn: () => void): void => {
        IndexConflictFlowHelper.openPreview(context, indexVal, itemVal, targetTimeVal, plan, saveFn, backFn);
      },
      (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: CompressionPlan,
        selectedIds: number[], mode: CompressionMode, saveFn: (t?: string) => void, backFn: () => void): void => {
        IndexConflictFlowHelper.showCompressionBlockedDialog(
          context,
          indexVal,
          itemVal,
          targetTimeVal,
          plan,
          selectedIds,
          mode,
          saveFn,
          backFn
        );
      },
      presetSelectedIds,
      presetMode
    );
    context.setConflictCompressController(controller);
  }

  private static openPreview(
    context: ConflictFlowContext,
    index: number,
    item: EventEntity,
    targetTime: string,
    plan: CompressionPlan,
    saveCallback: (t?: string) => void,
    onBack: () => void
  ): void {
    const detailMsg = plan.affectedItems.length === 0
      ? '• 没有前序行程受到压缩，仅调整当前开始时间。'
      : plan.affectedItems.map((aff) => `• ${aff.name}: ${aff.oldVal}m ➔ ${aff.newVal}m`).join('\n');
    const prevItem = index > 0 ? context.vm.events[index - 1] : null;
    const controller = IndexDialogManager.createSuggestionController({
      itemName: item.name,
      conflictName: prevItem ? prevItem.name : '前序行程',
      targetTime: targetTime,
      suggestedTime: plan.suggestedTime || targetTime,
      detailMsg: detailMsg,
      onConfirm: (): void => {
        if (!plan.suggestedTime) {
          return;
        }
        if (plan.affectedItems.length > 0) {
          context.vm.applyCompressionPlan(plan);
        }
        saveCallback(plan.suggestedTime);
      },
      onBack: onBack
    });
    context.setSuggestionDialogController(controller);
    controller.open();
    hilog.info(0x0000, 'Index', `[CONFLICT_UI][preview_open] itemId=${item.id}, targetTime=${targetTime}`);
  }
}
