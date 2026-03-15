// Repository接口：计划数据访问抽象

export interface PlanItem {
  id: number;
  title: string;
  createdAt: number;
  startDate?: number;
  status?: number;
  delFlag?: number;
  deleteTime?: number;
  enableAutoAmapRoute?: number;
}

export interface IPlanRepository {
  createPlan(title: string, startDate: number): Promise<number>;
  getPlanById(id: number): Promise<PlanItem | undefined>;
  getPlanList(): Promise<PlanItem[]>;
  getTrashPlans(): Promise<PlanItem[]>;
  getArchivedPlans(): Promise<PlanItem[]>;
  searchPlans(keyword: string): Promise<PlanItem[]>;
  searchTrashPlans(keyword: string): Promise<PlanItem[]>;
  searchAllPlansPaged(keyword: string, offset: number, limit: number): Promise<PlanItem[]>;
  updatePlanName(id: number, name: string): Promise<void>;
  updatePlanStatus(id: number, status: number): Promise<void>;
  updateStartDate(id: number, date: number): Promise<void>;
  updateAutoAmapRoute(id: number, enabled: boolean): Promise<void>;
  softDeletePlan(id: number): Promise<void>;
  hardDeletePlan(id: number): Promise<void>;
  restorePlan(id: number): Promise<void>;
  purgeOldTrash(): Promise<number>;
  markPlanDirty(planId: number): void;
  consumeDirtyPlanIds(): number[];
}
