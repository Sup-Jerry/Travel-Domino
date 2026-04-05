import { DateUtil } from '../../common/utils/DateUtil';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../model/entity/EventEntity';
import { CompressionMode, CompressionPlan, TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexDialogManager } from './IndexDialogManager';

export class IndexConflictHelper {
  static resolveConflictGapMinutes(item: EventEntity, fallbackGap: number = 0): number {
    if (item.gap_minutes > 0) {
      return item.gap_minutes;
    }

    const match = (item.conflict_msg || '').match(/(\d+)/);
    if (match && match.length > 1) {
      const parsed = Number.parseInt(match[1], 10);
      if (Number.isFinite(parsed) && parsed > 0) {
        return parsed;
      }
    }

    return fallbackGap > 0 ? fallbackGap : 0;
  }

  static getConflictTargetTime(item: EventEntity): string {
    const raw = item.fixed_start_time || item.computed_time || '09:00';
    const pure = DateUtil.extractPureTime(raw);
    return pure && DateUtil.isValidTimeString(pure) ? pure : '09:00';
  }

  static async saveConflictTime(
    vm: TimelineViewModel,
    item: EventEntity,
    newTime?: string,
    onDone?: () => Promise<void> | void
  ): Promise<void> {
    if (newTime && item.id > 0) {
      const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      await vm.updateEventInfo(
        item.id,
        item.name,
        item.duration,
        newTime,
        effectiveDayOffset,
        item.lock_status === 1,
        item.note,
        item.priority,
        item.latitude,
        item.longitude
      );
    }

    if (onDone) {
      await onDone();
    }
  }

  static handleEventConflictAction(
    vm: TimelineViewModel,
    item: EventEntity,
    strategy: 'delay' | 'compress' | 'advance' | 'smart',
    gapMinutes: number,
    onDone: (() => void) | undefined,
    openPreview: (index: number, target: EventEntity, targetTime: string, plan: CompressionPlan, saveCallback: (t?: string) => void,
      onBack: () => void) => void,
    openAdvanceAdjustDialog: (index: number, target: EventEntity, targetTime: string, saveCallback: (t?: string) => void) => void,
    openCompressSelectionDialog: (index: number, target: EventEntity, targetTime: string, saveCallback: (t?: string) => void,
      onBack: () => void) => void,
    openConflictMenu: (index: number, target: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void) => void
  ): void {
    const index = vm.events.indexOf(item);
    if (index < 0) {
      hilog.warn(0x0000, 'Index', `[CONFLICT_UI][missing_item] strategy=${strategy}, itemId=${item.id}`);
      return;
    }

    const targetTime = IndexConflictHelper.getConflictTargetTime(item);
    const saveCallback = (nextTime?: string) => {
      void IndexConflictHelper.saveConflictTime(vm, item, nextTime, onDone);
    };
    const reopenConflictMenu = () => {
      const latestGap = IndexConflictHelper.resolveConflictGapMinutes(item, gapMinutes);
      openConflictMenu(index, item, targetTime, latestGap, saveCallback);
    };

    hilog.info(
      0x0000,
      'Index',
      `[CONFLICT_UI][action] strategy=${strategy}, itemId=${item.id}, targetTime=${targetTime}, gap=${gapMinutes}`
    );

    if (strategy === 'delay') {
      const plan = vm.calculateDelayPlan(index);
      openPreview(index, item, targetTime, plan, saveCallback, reopenConflictMenu);
      return;
    }

    if (strategy === 'advance') {
      openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      return;
    }

    openCompressSelectionDialog(index, item, targetTime, saveCallback, reopenConflictMenu);
  }

  static openAdvanceAdjustDialog(
    vm: TimelineViewModel,
    index: number,
    item: EventEntity,
    targetTime: string,
    saveCallback: (t?: string) => void,
    showToast: (message: string) => void,
    onReopenAdvanceDialog: () => void,
    onOpenConflictMenu: (gap: number) => void
  ): CustomDialogController | null {
    const context = vm.buildAdvanceAdjustContext(index);
    if (!context || context.candidates.length === 0) {
      showToast('当前冲突前不存在可调整区间');
      return null;
    }

    const controller = IndexDialogManager.createAdvanceAdjustController({
      vm: vm,
      targetIndex: index,
      targetName: item.name,
      onCancel: () => {},
      onConfirm: (selectedIds: number[], nextStartTime: string) => {
        void vm.applyAdvanceAdjust(index, new Set<number>(selectedIds), nextStartTime).then((result) => {
          if (!result.success) {
            showToast(result.message || '前移调整失败');
            onReopenAdvanceDialog();
            return;
          }
          saveCallback(targetTime);
          if (result.remainingGapMinutes > 0) {
            showToast(`已前移 ${result.appliedShiftMinutes} 分钟，仍有 ${result.remainingGapMinutes} 分钟冲突`);
            onOpenConflictMenu(result.remainingGapMinutes);
            return;
          }
          showToast(`已前移 ${result.appliedShiftMinutes} 分钟`);
        }).catch((_error: Object) => {
          showToast('前移调整失败');
        });
      }
    });
    controller.open();
    return controller;
  }

  static showCompressionBlockedDialog(
    uiContext: UIContext,
    index: number,
    item: EventEntity,
    targetTime: string,
    plan: CompressionPlan,
    selectedIds: number[],
    mode: CompressionMode,
    saveCallback: (t?: string) => void,
    onBack: () => void,
    openCompressSelectionDialog: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void,
      backFn: () => void, presetSelectedIds: number[], presetMode: CompressionMode) => void,
    openPreview: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, nextPlan: CompressionPlan, saveFn: (t?: string) => void,
      backFn: () => void) => void,
    vm: TimelineViewModel
  ): void {
    const remain = plan.remainingGapMinutes ?? 0;
    const suggested = plan.suggestedTime || targetTime;
    uiContext.showAlertDialog({
      title: '⛔ 压缩后仍冲突',
      message: `已按所选范围压缩，但仍有 ${remain} 分钟冲突。\n建议最早开始时间：${suggested}\n\n请扩大压缩范围或改为向后顺延。`,
      primaryButton: {
        value: '返回重选',
        action: () => {
          openCompressSelectionDialog(index, item, targetTime, saveCallback, onBack, selectedIds, mode);
        }
      },
      secondaryButton: {
        value: '改为顺延',
        action: () => {
          const delayPlan = vm.calculateDelayPlan(index);
          openPreview(index, item, targetTime, delayPlan, saveCallback, onBack);
        }
      },
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
  }

  static openCompressSelectionDialog(
    vm: TimelineViewModel,
    index: number,
    item: EventEntity,
    targetTime: string,
    saveCallback: (t?: string) => void,
    onBack: () => void,
    showToast: (message: string) => void,
    openPreview: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: CompressionPlan, saveFn: (t?: string) => void,
      backFn: () => void) => void,
    showCompressionBlockedDialog: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: CompressionPlan,
      selectedIds: number[], mode: CompressionMode, saveFn: (t?: string) => void, backFn: () => void) => void,
    presetSelectedIds: number[] = [],
    presetMode: CompressionMode = 'RATIO'
  ): CustomDialogController | null {
    const context = vm.buildCompressionSelectionContext(index, targetTime);
    if (!context) {
      showToast('当前上下文无法计算压缩方案，请稍后重试');
      return null;
    }
    if (context.neededGapMinutes <= 0) {
      saveCallback(targetTime);
      return null;
    }

    const controller = IndexDialogManager.createConflictCompressController({
      vm: vm,
      targetIndex: index,
      targetTime: targetTime,
      targetName: item.name,
      initialMode: presetMode,
      initialSelectedIds: presetSelectedIds,
      onCancel: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][compress_dialog_cancel] itemId=${item.id}`);
      },
      onConfirm: (selectedIds: number[], mode: CompressionMode) => {
        const plan = vm.calculateCompressionPlanBySelection(index, targetTime, new Set<number>(selectedIds), mode);
        if (plan.status === 'NO_ACTION') {
          saveCallback(targetTime);
          return;
        }
        if (plan.status === 'OVERLOAD') {
          showCompressionBlockedDialog(index, item, targetTime, plan, selectedIds, mode, saveCallback, onBack);
          return;
        }
        openPreview(index, item, targetTime, plan, saveCallback, () => {
          IndexConflictHelper.openCompressSelectionDialog(
            vm,
            index,
            item,
            targetTime,
            saveCallback,
            onBack,
            showToast,
            openPreview,
            showCompressionBlockedDialog,
            selectedIds,
            mode
          );
        });
      }
    });
    controller.open();
    return controller;
  }

  static openConflictMenu(
    vm: TimelineViewModel,
    index: number,
    item: EventEntity,
    targetTime: string,
    gap: number,
    saveCallback: (t?: string) => void,
    openPreview: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, plan: CompressionPlan, saveFn: (t?: string) => void,
      backFn: () => void) => void,
    openCompressSelectionDialog: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void,
      backFn: () => void) => void,
    openAdvanceAdjustDialog: (indexVal: number, itemVal: EventEntity, targetTimeVal: string, saveFn: (t?: string) => void) => void
  ): CustomDialogController {
    hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_open] index=${index}, itemId=${item.id}, targetTime=${targetTime}, gap=${gap}`);
    const controller = IndexDialogManager.createConflictSelectionController({
      gapMinutes: gap,
      onDelayY: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_delay] itemId=${item.id}`);
        const plan = vm.calculateDelayPlan(index);
        openPreview(index, item, targetTime, plan, saveCallback, () => {
          IndexConflictHelper.openConflictMenu(
            vm,
            index,
            item,
            targetTime,
            gap,
            saveCallback,
            openPreview,
            openCompressSelectionDialog,
            openAdvanceAdjustDialog
          );
        });
      },
      onCompressX: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_compress] itemId=${item.id}`);
        openCompressSelectionDialog(index, item, targetTime, saveCallback, () => {
          IndexConflictHelper.openConflictMenu(
            vm,
            index,
            item,
            targetTime,
            gap,
            saveCallback,
            openPreview,
            openCompressSelectionDialog,
            openAdvanceAdjustDialog
          );
        });
      },
      onAdvanceAdjust: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_advance_adjust] itemId=${item.id}`);
        openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      },
      onShiftSameDay: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_shift_same_day_compat] itemId=${item.id}`);
        openAdvanceAdjustDialog(index, item, targetTime, saveCallback);
      },
      onSmartAdjust: () => {
        hilog.info(0x0000, 'Index', `[CONFLICT_UI][menu_smart] itemId=${item.id}`);
        openCompressSelectionDialog(index, item, targetTime, saveCallback, () => {
          IndexConflictHelper.openConflictMenu(
            vm,
            index,
            item,
            targetTime,
            gap,
            saveCallback,
            openPreview,
            openCompressSelectionDialog,
            openAdvanceAdjustDialog
          );
        });
      }
    });
    controller.open();
    return controller;
  }

  static requestPlanDateUpdate(
    vm: TimelineViewModel,
    newDateTimestamp: number,
    openConflictMenu: (index: number, item: EventEntity, targetTime: string, gap: number, saveCallback: (t?: string) => void) => void
  ): void {
    const nextDate = new Date(newDateTimestamp);
    nextDate.setHours(0, 0, 0, 0);
    const normalizedTimestamp = nextDate.getTime();

    const preview = vm.previewPlanDateShift(normalizedTimestamp);
    if (!preview.hasRigidConflict) {
      hilog.info(0x0000, 'Index', `[SHIFT_UI][direct_apply] date=${normalizedTimestamp}`);
      vm.updatePlanDate(normalizedTimestamp);
      return;
    }

    const conflictItem = vm.events.find(e => e.id === preview.conflictItemId);
    if (!conflictItem) {
      hilog.warn(0x0000, 'Index', `[SHIFT_UI][fallback_apply] conflict item not found, date=${normalizedTimestamp}`);
      vm.updatePlanDate(normalizedTimestamp);
      return;
    }

    const conflictIndex = vm.events.indexOf(conflictItem);
    if (conflictIndex < 0) {
      vm.updatePlanDate(normalizedTimestamp);
      return;
    }

    const targetTime = IndexConflictHelper.getConflictTargetTime(conflictItem);
    const conflictGap = IndexConflictHelper.resolveConflictGapMinutes(conflictItem, preview.gapMinutes);

    hilog.warn(
      0x0000,
      'Index',
      `[SHIFT_UI][blocked_by_rigid] date=${normalizedTimestamp}, itemId=${conflictItem.id}, itemName=${conflictItem.name}, gap=${conflictGap}`
    );

    openConflictMenu(
      conflictIndex,
      conflictItem,
      targetTime,
      conflictGap,
      (suggestedTime?: string) => {
        void IndexConflictHelper.saveConflictTime(vm, conflictItem, suggestedTime, async () => {
          await vm.updatePlanDate(normalizedTimestamp);
        });
      }
    );
  }
}
