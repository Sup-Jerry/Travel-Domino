// @deprecated 使用 IPlanRepository 替代
// 此文件将在阶段5删除
import { PlanRepositoryImpl } from '../../infrastructure/persistence/PlanRepositoryImpl';

export class PlanDao {
  static createPlan(title: string, startDate: number) {
    return PlanRepositoryImpl.createPlan(title, startDate);
  }
  static getPlanById(id: number) {
    return PlanRepositoryImpl.getPlanById(id);
  }
  static getPlanList() {
    return PlanRepositoryImpl.getPlanList();
  }
  static getTrashPlans() {
    return PlanRepositoryImpl.getTrashPlans();
  }
  static getArchivedPlans() {
    return PlanRepositoryImpl.getArchivedPlans();
  }
  static searchPlans(keyword: string) {
    return PlanRepositoryImpl.searchPlans(keyword);
  }
  static searchTrashPlans(keyword: string) {
    return PlanRepositoryImpl.searchTrashPlans(keyword);
  }
  static searchAllPlansPaged(keyword: string, offset: number, limit: number) {
    return PlanRepositoryImpl.searchAllPlansPaged(keyword, offset, limit);
  }
  static updatePlanName(id: number, name: string) {
    return PlanRepositoryImpl.updatePlanName(id, name);
  }
  static updatePlanStatus(id: number, status: number) {
    return PlanRepositoryImpl.updatePlanStatus(id, status);
  }
  static updateStartDate(id: number, date: number) {
    return PlanRepositoryImpl.updateStartDate(id, date);
  }
  static updateAutoAmapRoute(id: number, enabled: boolean) {
    return PlanRepositoryImpl.updateAutoAmapRoute(id, enabled);
  }
  static softDeletePlan(id: number) {
    return PlanRepositoryImpl.softDeletePlan(id);
  }
  static hardDeletePlan(id: number) {
    return PlanRepositoryImpl.hardDeletePlan(id);
  }
  static restorePlan(id: number) {
    return PlanRepositoryImpl.restorePlan(id);
  }
  static purgeOldTrash() {
    return PlanRepositoryImpl.purgeOldTrash();
  }
  static markPlanDirty(planId: number) {
    return PlanRepositoryImpl.markPlanDirty(planId);
  }
  static consumeDirtyPlanIds() {
    return PlanRepositoryImpl.consumeDirtyPlanIds();
  }
}

export type { PlanItem } from '../../domain/ports/IPlanRepository';
