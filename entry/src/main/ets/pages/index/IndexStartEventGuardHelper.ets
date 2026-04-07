import { PlanRepositoryImpl } from '../../infrastructure/persistence/PlanRepositoryImpl';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export interface StartEventGuardContext {
  vm: TimelineViewModel;
  currentPlanId: number;
  planTitle: string;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
}

export class IndexStartEventGuardHelper {
  static async tryStartEventWithConflictPrompt(context: StartEventGuardContext, eventId: number): Promise<boolean> {
    const conflict = await context.vm.getStartConflictInfo(eventId);
    if (conflict) {
      await IndexStartEventGuardHelper.showActiveConflictDialog(context, conflict.planId, conflict.name);
      return false;
    }
    const started = await context.vm.updateActualTime(eventId, 'actual_start_time', Date.now());
    if (!started) {
      const retryConflict = await context.vm.getStartConflictInfo(eventId);
      if (retryConflict) {
        await IndexStartEventGuardHelper.showActiveConflictDialog(context, retryConflict.planId, retryConflict.name);
      } else {
        context.safeShowToast('开始打卡失败，请稍后重试');
      }
      return false;
    }
    return true;
  }

  private static async resolveConflictPlanName(context: StartEventGuardContext, planId: number): Promise<string> {
    if (planId === context.currentPlanId) {
      const localTitle = (context.planTitle || '').trim();
      return localTitle.length > 0 ? localTitle : `计划 #${planId}`;
    }
    try {
      const plan = await PlanRepositoryImpl.getPlanById(planId);
      const title = (plan?.title || '').trim();
      return title.length > 0 ? title : `计划 #${planId}`;
    } catch (_error) {
      return `计划 #${planId}`;
    }
  }

  private static async showActiveConflictDialog(
    context: StartEventGuardContext,
    conflictPlanId: number,
    conflictName: string
  ): Promise<void> {
    const planName = await IndexStartEventGuardHelper.resolveConflictPlanName(context, conflictPlanId);
    const safeName = (conflictName || '').trim().length > 0 ? conflictName : '其他地点';
    context.getUIContext().showAlertDialog({
      title: '无法开始打卡',
      message: `当前已有进行中的计划【${planName}】地点【${safeName}】。\n请先结束该地点后再开始新的打卡。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '我知道了',
        action: () => {}
      }
    });
  }
}
