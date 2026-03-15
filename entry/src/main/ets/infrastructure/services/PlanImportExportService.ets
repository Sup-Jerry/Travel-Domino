import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlanSerializer, ExportPlanMeta } from '../../domain/serializers/PlanSerializer';
import { PlanRepositoryImpl } from '../persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../persistence/EventRepositoryImpl';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { RdbHelper } from '../../common/utils/RdbHelper';

const TAG = 'PlanImportExportService';

interface TransactionStoreLike {
  beginTransaction(): void;
  commit(): void;
  rollBack(): void;
}

interface PlanJsonTransferDeps {
  getStore: () => TransactionStoreLike | null;
  createPlan: (title: string, startDate: number) => Promise<number>;
  updateAutoAmapRoute: (id: number, enabled: boolean) => Promise<void>;
  updatePlanStatus: (id: number, status: number) => Promise<void>;
  insertEvent: (planId: number, item: TravelPlanItem) => Promise<number>;
  hardDeletePlan: (id: number) => Promise<void>;
}

export class PlanJsonImportCancelToken {
  private canceled: boolean = false;

  public cancel(): void {
    this.canceled = true;
  }

  public throwIfCancelled(stage: string): void {
    if (this.canceled) {
      throw new Error(`import_cancelled:${stage}`);
    }
  }
}

export class PlanImportExportService {
  private static testDeps: PlanJsonTransferDeps | null = null;

  public static setDepsForTest(deps: PlanJsonTransferDeps | null): void {
    PlanImportExportService.testDeps = deps;
  }

  private static resolveDeps(): PlanJsonTransferDeps {
    if (PlanImportExportService.testDeps) {
      return PlanImportExportService.testDeps;
    }
    return {
      getStore: (): TransactionStoreLike | null => RdbHelper.getInstance().getRdbStore(),
      createPlan: async (title: string, startDate: number): Promise<number> =>
        PlanRepositoryImpl.createPlan(title, startDate),
      updateAutoAmapRoute: async (id: number, enabled: boolean): Promise<void> =>
        PlanRepositoryImpl.updateAutoAmapRoute(id, enabled),
      updatePlanStatus: async (id: number, status: number): Promise<void> =>
        PlanRepositoryImpl.updatePlanStatus(id, status),
      insertEvent: async (planId: number, item: TravelPlanItem): Promise<number> =>
        EventRepositoryImpl.insertEvent(planId, item),
      hardDeletePlan: async (id: number): Promise<void> =>
        PlanRepositoryImpl.hardDeletePlan(id)
    };
  }

  public static async exportPlanToJson(planId: number): Promise<string> {
    const plan = await PlanRepositoryImpl.getPlanById(planId);
    if (!plan) {
      throw new Error(`plan_not_found:${planId}`);
    }
    const events = await EventRepositoryImpl.getAllEvents(planId);
    const planMeta: ExportPlanMeta = {
      title: plan.title,
      startDate: plan.startDate || Date.now(),
      status: plan.status ?? 0,
      enableAutoAmapRoute: plan.enableAutoAmapRoute ?? 1
    };
    return PlanSerializer.serializePlan(planMeta, events);
  }

  public static async importPlanFromJson(raw: string, cancelToken?: PlanJsonImportCancelToken): Promise<number> {
    cancelToken?.throwIfCancelled('before_parse');
    const parsed = PlanSerializer.deserializePlan(raw);
    cancelToken?.throwIfCancelled('after_validate');
    const deps = PlanImportExportService.resolveDeps();

    const startDate = Number(parsed.plan.startDate) > 0 ? Number(parsed.plan.startDate) : Date.now();
    const importedPlanTitle = `${parsed.plan.title.trim()}(导入)`;
    const rdbStore = deps.getStore();
    if (!rdbStore) {
      throw new Error('db_not_ready');
    }

    const events = parsed.events as TravelPlanItem[];
    let newPlanId = -1;
    let transactionOpened = false;
    try {
      cancelToken?.throwIfCancelled('before_transaction');
      rdbStore.beginTransaction();
      transactionOpened = true;
      newPlanId = await deps.createPlan(importedPlanTitle, startDate);
      if (newPlanId <= 0) {
        throw new Error('create_plan_failed');
      }

      const autoRoute = parsed.plan.enableAutoAmapRoute === 0 ? 0 : 1;
      await deps.updateAutoAmapRoute(newPlanId, autoRoute === 1);
      const planStatus = Math.floor(Number(parsed.plan.status) || 0);
      await deps.updatePlanStatus(newPlanId, planStatus);

      for (let i = 0; i < events.length; i++) {
        cancelToken?.throwIfCancelled(`insert_event_${i}`);
        const normalized = PlanSerializer.normalizeImportEvent(events[i], i);
        await deps.insertEvent(newPlanId, normalized);
      }

      cancelToken?.throwIfCancelled('before_commit');
      rdbStore.commit();
      transactionOpened = false;
      hilog.info(0x0000, TAG, `[PLAN_JSON][import_done] newPlanId=${newPlanId}, count=${events.length}, status=${planStatus}`);
      return newPlanId;
    } catch (error) {
      if (transactionOpened) {
        try {
          rdbStore.rollBack();
        } catch (rollbackError) {
          hilog.error(0x0000, TAG, `[PLAN_JSON][import_rollback_failed] reason=${JSON.stringify(rollbackError)}`);
        } finally {
          transactionOpened = false;
        }
      }
      if (newPlanId > 0) {
        try {
          await deps.hardDeletePlan(newPlanId);
        } catch (compensateError) {
          hilog.error(0x0000, TAG, `[PLAN_JSON][import_compensate_delete_failed] planId=${newPlanId}, reason=${JSON.stringify(compensateError)}`);
        }
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(`import_failed:${JSON.stringify(error)}`);
    }
  }
}
