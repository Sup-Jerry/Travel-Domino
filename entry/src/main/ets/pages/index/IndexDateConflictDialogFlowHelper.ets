import { DateUtil } from '../../common/utils/DateUtil';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexDialogManager } from './IndexDialogManager';
import { InitDialogData, PendingItemData } from './IndexTypes';

export interface DateConflictDialogFlowContext {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  getPendingItem: () => PendingItemData | null;
  setPendingItem: (item: PendingItemData | null) => void;
  openDialog: (initData?: InitDialogData) => void;
  reopenConflictDialog: () => void;
  safeShowToast: (message: string) => void;
}

export class IndexDateConflictDialogFlowHelper {
  static createController(context: DateConflictDialogFlowContext): CustomDialogController {
    return IndexDialogManager.createDateConflictController({
      conflictDateStr: IndexDateConflictDialogFlowHelper.resolveConflictDateStr(context),
      planStartDateStr: DateUtil.formatDate(new Date(context.vm.planStartDate), 'MM月dd日'),
      planStartDate: context.vm.planStartDate,
      onChangeItemDate: () => {
        IndexDateConflictDialogFlowHelper.handleChangeItemDate(context);
      },
      onMoveToBacklog: async () => {
        await IndexDateConflictDialogFlowHelper.handleMoveToBacklog(context);
      },
      onChangePlanStartDate: async () => {
        await IndexDateConflictDialogFlowHelper.handleChangePlanStartDate(context);
      },
      onCancel: () => {
        IndexDateConflictDialogFlowHelper.handleCancel(context);
      }
    });
  }

  private static resolveConflictDateStr(context: DateConflictDialogFlowContext): string {
    const pending = context.getPendingItem();
    return pending ? DateUtil.formatDate(new Date(pending.targetDateMs), 'MM月dd日') : '';
  }

  private static handleChangeItemDate(context: DateConflictDialogFlowContext): void {
    if (!context.getPendingItem()) {
      return;
    }
    setTimeout(() => {
      context.getUIContext().showDatePickerDialog({
        start: new Date(context.vm.planStartDate),
        end: new Date('2100-12-31'),
        selected: new Date(context.vm.planStartDate),
        onAccept: async (value: DatePickerResult) => {
          const selectedDate = new Date();
          selectedDate.setFullYear(value.year, value.month, value.day);
          const newOffset = TimelineDatePolicy.timestampToDayOffset(context.vm.planStartDate, selectedDate.getTime());
          const pending = context.getPendingItem();
          if (!pending) {
            return;
          }
          if (pending.id !== -1) {
            await context.vm.updateEventInfo(
              pending.id,
              pending.name,
              pending.duration,
              pending.fixedTime,
              newOffset,
              false,
              pending.note
            );
          } else {
            await context.vm.addNewItem(
              pending.name,
              pending.duration,
              true,
              pending.fixedTime,
              newOffset,
              -1,
              false,
              pending.note
            );
          }
          context.setPendingItem(null);
          context.safeShowToast('已更新日期并移至日程');
        },
        onCancel: () => {
          context.reopenConflictDialog();
        }
      });
    }, 200);
  }

  private static async handleMoveToBacklog(context: DateConflictDialogFlowContext): Promise<void> {
    const pending = context.getPendingItem();
    if (!pending) {
      return;
    }
    await context.vm.resolveConflictByBacklog(pending.id, pending.name, pending.duration, pending.note);
    context.setPendingItem(null);
    context.safeShowToast('已移至暂存池');
  }

  private static async handleChangePlanStartDate(context: DateConflictDialogFlowContext): Promise<void> {
    const pending = context.getPendingItem();
    if (!pending) {
      return;
    }
    await context.vm.resolveConflictByMovingPlan(
      pending.id,
      pending.targetDateMs,
      pending.name,
      pending.duration,
      pending.isSchedule,
      pending.fixedTime,
      pending.note
    );
    context.setPendingItem(null);
    context.safeShowToast('计划出发日期已更新');
  }

  private static handleCancel(context: DateConflictDialogFlowContext): void {
    const pending = context.getPendingItem();
    if (!pending) {
      return;
    }
    context.openDialog({
      name: pending.name,
      note: pending.note,
      duration: pending.duration,
      isAnchor: false,
      fixedTime: pending.fixedTime || '',
      dayOffset: pending.dayOffset,
      isSchedule: pending.isSchedule
    });
    context.setPendingItem(null);
  }
}
