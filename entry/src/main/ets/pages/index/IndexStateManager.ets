import { PreferenceManager } from '../../common/utils/PreferenceManager';

export class IndexStateManager {
  static scopedStorageKey(base: string, currentPlanId: number): string {
    if (currentPlanId > 0) {
      return `${base}_${currentPlanId}`;
    }
    return base;
  }

  static clearDialogDraftStorage(currentPlanId: number, tempDialogStateKey: string, pickedLocationKey: string): void {
    AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(tempDialogStateKey, currentPlanId), '');
    AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(pickedLocationKey, currentPlanId), '');
    AppStorage.setOrCreate(tempDialogStateKey, '');
    AppStorage.setOrCreate(pickedLocationKey, '');
  }

  static readDraftStorageWithFallback(currentPlanId: number, key: string): string {
    const scoped = AppStorage.get<Object>(IndexStateManager.scopedStorageKey(key, currentPlanId));
    if (typeof scoped === 'string' && scoped.trim().length > 0) {
      return scoped;
    }
    const globalVal = AppStorage.get<Object>(key);
    if (typeof globalVal === 'string' && globalVal.trim().length > 0) {
      return globalVal;
    }
    return '';
  }

  static readUnsavedFlag(currentPlanId: number, unsavedKey: string): boolean {
    return AppStorage.get<boolean>(IndexStateManager.scopedStorageKey(unsavedKey, currentPlanId)) ?? false;
  }

  static setUnsavedFlag(currentPlanId: number, unsavedKey: string, value: boolean): boolean {
    AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(unsavedKey, currentPlanId), value);
    return value;
  }

  static getBacklogExpandedKey(planId: number): string {
    return `backlog_expanded_plan_${planId}`;
  }

  static getBacklogInitializedKey(planId: number): string {
    return `backlog_expanded_initialized_plan_${planId}`;
  }

  static async initBacklogExpandedState(planId: number, isNewPlan: boolean): Promise<boolean> {
    const pref = PreferenceManager.getInstance();

    if (isNewPlan) {
      await pref.setValue(IndexStateManager.getBacklogExpandedKey(planId), true);
      await pref.setValue(IndexStateManager.getBacklogInitializedKey(planId), true);
      return true;
    }

    const initialized = await pref.getValue(IndexStateManager.getBacklogInitializedKey(planId), false);
    if (initialized === true) {
      const savedExpanded = await pref.getValue(IndexStateManager.getBacklogExpandedKey(planId), false);
      return savedExpanded === true;
    }

    await pref.setValue(IndexStateManager.getBacklogExpandedKey(planId), false);
    await pref.setValue(IndexStateManager.getBacklogInitializedKey(planId), true);
    return false;
  }

  static persistBacklogExpanded(planId: number, expanded: boolean): void {
    if (planId > 0) {
      PreferenceManager.getInstance().setValue(IndexStateManager.getBacklogExpandedKey(planId), expanded);
    }
  }

  static isDayCollapsed(collapsedDayOffsets: number[], dayOffset: number): boolean {
    return collapsedDayOffsets.indexOf(dayOffset) >= 0;
  }

  static toggleDayCollapse(collapsedDayOffsets: number[], dayOffset: number): number[] {
    const next = [...collapsedDayOffsets];
    const idx = next.indexOf(dayOffset);
    if (idx >= 0) {
      next.splice(idx, 1);
    } else {
      next.push(dayOffset);
    }
    return next;
  }
}
