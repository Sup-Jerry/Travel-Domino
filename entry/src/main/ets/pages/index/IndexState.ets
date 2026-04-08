import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { PlanRepositoryImpl } from '../../infrastructure/persistence/PlanRepositoryImpl';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export class IndexStateManager {
  /**
   * 生成带计划作用域的存储键
   */
  static scopedStorageKey(currentPlanId: number, base: string): string {
    if (currentPlanId > 0) {
      return `${base}_${currentPlanId}`;
    }
    return base;
  }

  /**
   * 清理对话框草稿存储
   */
  static clearDialogDraftStorage(currentPlanId: number): void {
    AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(currentPlanId, AppStorageKeys.TEMP_DIALOG_STATE), '');
    AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(currentPlanId, AppStorageKeys.PICKED_LOCATION_STR), '');
    AppStorage.setOrCreate(AppStorageKeys.TEMP_DIALOG_STATE, '');
    AppStorage.setOrCreate(AppStorageKeys.PICKED_LOCATION_STR, '');
  }

  /**
   * 读取草稿存储（带降级）
   */
  static readDraftStorageWithFallback(currentPlanId: number, key: string): string {
    const scoped = AppStorage.get<Object>(IndexStateManager.scopedStorageKey(currentPlanId, key));
    if (typeof scoped === 'string' && scoped.trim().length > 0) {
      return scoped;
    }
    const globalVal = AppStorage.get<Object>(key);
    if (typeof globalVal === 'string' && globalVal.trim().length > 0) {
      return globalVal;
    }
    return '';
  }

  /**
   * 刷新未保存标志
   */
  static refreshUnsavedFlag(currentPlanId: number): boolean {
    return AppStorage.get<boolean>(IndexStateManager.scopedStorageKey(currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE)) ?? false;
  }

  /**
   * 设置未保存标志
   */
  static setUnsavedFlag(currentPlanId: number, value: boolean): void {
    AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE), value);
  }

  /**
   * 检查是否有未保存的更改
   */
  static hasScopedUnsavedChanges(currentPlanId: number): boolean {
    return AppStorage.get<boolean>(IndexStateManager.scopedStorageKey(currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE)) ?? false;
  }

  /**
   * 获取暂存池展开状态键
   */
  static getBacklogExpandedKey(planId: number): string {
    return `backlog_expanded_plan_${planId}`;
  }

  /**
   * 获取暂存池初始化状态键
   */
  static getBacklogInitializedKey(planId: number): string {
    return `backlog_expanded_initialized_plan_${planId}`;
  }

  /**
   * 安全显示 Toast
   */
  static safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      const errorMsg = IndexStateManager.sanitizeError(error as Object);
      hilog.warn(0x0000, 'IndexState', `[TOAST_FAIL] ${errorMsg}`);
    }
  }

  /**
   * 清理错误信息
   */
  static sanitizeError(error: Object): string {
    if (error instanceof Error && typeof error.message === 'string' && error.message.length > 0) {
      return error.message;
    }
    return 'unknown_error';
  }

  /**
   * 解析冲突计划名称
   */
  static async resolveConflictPlanName(planId: number, currentPlanId: number, planTitle: string): Promise<string> {
    if (planId === currentPlanId) {
      const localTitle = (planTitle || '').trim();
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

  /**
   * 显示活动冲突对话框
   */
  static async showActiveConflictDialog(
    uiContext: UIContext,
    conflictPlanId: number,
    conflictName: string,
    currentPlanId: number,
    planTitle: string
  ): Promise<void> {
    const planName = await IndexStateManager.resolveConflictPlanName(conflictPlanId, currentPlanId, planTitle);
    const safeName = (conflictName || '').trim().length > 0 ? conflictName : '其他地点';
    uiContext.showAlertDialog({
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

  /**
   * 尝试开始事件（带冲突提示）
   */
  static async tryStartEventWithConflictPrompt(
    vm: TimelineViewModel,
    eventId: number,
    uiContext: UIContext,
    currentPlanId: number,
    planTitle: string
  ): Promise<boolean> {
    const conflict = await vm.getStartConflictInfo(eventId);
    if (conflict) {
      await IndexStateManager.showActiveConflictDialog(uiContext, conflict.planId, conflict.name, currentPlanId, planTitle);
      return false;
    }
    const started = await vm.updateActualTime(eventId, 'actual_start_time', Date.now());
    if (!started) {
      const retryConflict = await vm.getStartConflictInfo(eventId);
      if (retryConflict) {
        await IndexStateManager.showActiveConflictDialog(uiContext, retryConflict.planId, retryConflict.name, currentPlanId, planTitle);
      } else {
        IndexStateManager.safeShowToast('开始打卡失败，请稍后重试');
      }
      return false;
    }
    return true;
  }
}
