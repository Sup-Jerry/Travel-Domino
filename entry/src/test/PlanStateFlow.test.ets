import { describe, it, expect } from '@ohos/hypium';
import { PlanAppService, PlanRepository } from '../main/ets/viewmodel/PlanAppService';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';

interface PlanRecord {
  plan: PlanItem;
  eventCount: number;
  delFlag: number;
}

class InMemoryPlanRepo implements PlanRepository {
  private plans: Map<number, PlanRecord> = new Map<number, PlanRecord>();
  private idSeed: number = 100;

  private clonePlan(plan: PlanItem): PlanItem {
    return {
      id: plan.id,
      title: plan.title,
      createdAt: plan.createdAt,
      startDate: plan.startDate,
      status: plan.status,
      deleteTime: plan.deleteTime,
      enableAutoAmapRoute: plan.enableAutoAmapRoute
    };
  }

  public seedPlan(plan: PlanItem, eventCount: number = 0): void {
    this.plans.set(plan.id, {
      plan: this.clonePlan(plan),
      eventCount: eventCount,
      delFlag: 0
    });
    if (plan.id > this.idSeed) {
      this.idSeed = plan.id;
    }
  }

  public getEventCount(planId: number): number {
    const record = this.plans.get(planId);
    return record ? record.eventCount : 0;
  }

  public async createPlan(title: string, startDate: number): Promise<number> {
    this.idSeed += 1;
    this.plans.set(this.idSeed, {
      plan: {
        id: this.idSeed,
        title: title,
        createdAt: Date.now(),
        startDate: startDate,
        status: 0,
        deleteTime: 0,
        enableAutoAmapRoute: 1
      },
      eventCount: 0,
      delFlag: 0
    });
    return this.idSeed;
  }

  public async purgeOldTrash(): Promise<number> {
    return 0;
  }

  public async getPlanList(): Promise<PlanItem[]> {
    const list: PlanItem[] = [];
    this.plans.forEach((record: PlanRecord) => {
      if ((record.plan.deleteTime ?? 0) >= 0 && record.delFlag !== 1) {
        list.push(this.clonePlan(record.plan));
      }
    });
    return list;
  }

  public async getArchivedPlans(): Promise<PlanItem[]> {
    const list: PlanItem[] = [];
    this.plans.forEach((record: PlanRecord) => {
      if (record.delFlag !== 1 && (record.plan.status ?? 0) === 2) {
        list.push(this.clonePlan(record.plan));
      }
    });
    return list;
  }

  public async getTrashPlans(): Promise<PlanItem[]> {
    const list: PlanItem[] = [];
    this.plans.forEach((record: PlanRecord) => {
      if (record.delFlag === 1) {
        list.push(this.clonePlan(record.plan));
      }
    });
    return list;
  }

  public async updatePlanStatus(id: number, status: number): Promise<void> {
    const record = this.plans.get(id);
    if (!record) {
      return;
    }
    record.plan.status = status;
  }

  public async softDeletePlan(id: number): Promise<void> {
    const record = this.plans.get(id);
    if (!record) {
      return;
    }
    record.delFlag = 1;
    record.plan.deleteTime = Date.now();
  }

  public async restorePlan(id: number): Promise<void> {
    const record = this.plans.get(id);
    if (!record) {
      return;
    }
    record.delFlag = 0;
    record.plan.deleteTime = 0;
  }

  public async hardDeletePlan(id: number): Promise<void> {
    this.plans.delete(id);
  }
}

function buildPlan(id: number, title: string, status: number): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: 1733000000000 + id,
    startDate: 1733000000000,
    status: status,
    deleteTime: 0,
    enableAutoAmapRoute: 1
  };
}

export default function planStateFlowTest() {
  describe('planStateFlowTest', () => {
    it('soft_delete_should_hide_from_visible_and_show_in_trash', 0, async (done: () => void) => {
      const repo = new InMemoryPlanRepo();
      repo.seedPlan(buildPlan(1, 'A', 0), 3);
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();

      await service.softDeletePlan(1);
      const visible = await service.loadVisiblePlans();
      const trash = await service.loadTrashPlans();

      expect(visible.findIndex((item: PlanItem) => item.id === 1)).assertEqual(-1);
      expect(trash.findIndex((item: PlanItem) => item.id === 1) >= 0).assertEqual(true);

      PlanAppService.setPlanRepositoryForTest(null);
      done();
    });

    it('restore_should_keep_archived_status_and_metadata', 0, async (done: () => void) => {
      const repo = new InMemoryPlanRepo();
      repo.seedPlan(buildPlan(2, 'ArchivedPlan', 0), 2);
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();

      await service.archivePlan(2);
      await service.softDeletePlan(2);
      await service.restorePlan(2);

      const visible = await service.loadVisiblePlans();
      const archived = await service.loadArchivedPlans();
      const archivedItem = archived.find((item: PlanItem) => item.id === 2);

      expect(visible.findIndex((item: PlanItem) => item.id === 2)).assertEqual(-1);
      expect(archivedItem !== undefined).assertEqual(true);
      expect(archivedItem?.status ?? -1).assertEqual(2);
      expect(archivedItem?.title ?? '').assertEqual('ArchivedPlan');
      expect(repo.getEventCount(2)).assertEqual(2);

      PlanAppService.setPlanRepositoryForTest(null);
      done();
    });

    it('hard_delete_should_remove_plan_from_all_lists', 0, async (done: () => void) => {
      const repo = new InMemoryPlanRepo();
      repo.seedPlan(buildPlan(3, 'DeleteMe', 0), 4);
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();

      await service.hardDeletePlan(3);

      const visible = await service.loadVisiblePlans();
      const archived = await service.loadArchivedPlans();
      const trash = await service.loadTrashPlans();

      expect(visible.findIndex((item: PlanItem) => item.id === 3)).assertEqual(-1);
      expect(archived.findIndex((item: PlanItem) => item.id === 3)).assertEqual(-1);
      expect(trash.findIndex((item: PlanItem) => item.id === 3)).assertEqual(-1);
      expect(repo.getEventCount(3)).assertEqual(0);

      PlanAppService.setPlanRepositoryForTest(null);
      done();
    });
  });
}
