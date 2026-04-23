import { describe, expect, it } from '@ohos/hypium';
import { PlanImportExportService, PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

interface StoreStatsCU {
  beginCount: number;
  commitCount: number;
  rollbackCount: number;
}

interface PlanMetaCU {
  title: string;
  startDate: number;
  status: number;
  enableAutoAmapRoute: number;
}

interface ImportPayloadCU {
  schemaVersion: number;
  exportedAt: number;
  sourcePlanId: number;
  plan: PlanMetaCU;
  events: TravelPlanItem[];
}

interface DepsOptionsCU {
  newPlanId?: number;
  insertShouldThrow?: boolean;
  hardDeleteShouldThrow?: boolean;
}

interface DepsStateCU {
  deletedIds: number[];
  insertedCount: () => number;
}

class StoreMockCU {
  stats: StoreStatsCU = { beginCount: 0, commitCount: 0, rollbackCount: 0 };
  rollbackShouldThrow: boolean = false;

  beginTransaction(): void {
    this.stats.beginCount += 1;
  }

  commit(): void {
    this.stats.commitCount += 1;
  }

  rollBack(): void {
    this.stats.rollbackCount += 1;
    if (this.rollbackShouldThrow) {
      throw new Error('rollback_failed_cu');
    }
  }
}

class StageCancelTokenCU extends PlanJsonImportCancelToken {
  private readonly targetStage: string;

  constructor(targetStage: string) {
    super();
    this.targetStage = targetStage;
  }

  public throwIfCancelled(stage: string): void {
    if (stage === this.targetStage) {
      throw new Error(`import_cancelled:${stage}`);
    }
  }
}

function buildEventCU(name: string, sortOrder: number): TravelPlanItem {
  return {
    name: name,
    note: '',
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: sortOrder,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '09:00',
    dayOffset: 0,
    itemType: 0,
    priority: 0,
    transportMode: 2,
    travelMode: 2,
    isTravelManual: 0,
    source: 0,
    delFlag: 0,
    groupId: 0,
    address: '',
    aiReasoning: '',
    latitude: 30.1,
    longitude: 120.2,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0
  };
}

function buildPayloadCU(eventCount: number = 1): string {
  const events: TravelPlanItem[] = [];
  for (let i = 0; i < eventCount; i++) {
    events.push(buildEventCU(`CU${i}`, i));
  }
  const payload: ImportPayloadCU = {
    schemaVersion: 1,
    exportedAt: 1733000000000,
    sourcePlanId: 71,
    plan: {
      title: 'CU Plan',
      startDate: 1733000000000,
      status: 1,
      enableAutoAmapRoute: 1
    },
    events: events
  };
  return JSON.stringify(payload);
}

function setDepsCU(
  store: StoreMockCU,
  options?: DepsOptionsCU
): DepsStateCU {
  const deletedIds: number[] = [];
  let inserted = 0;
  PlanImportExportService.setDepsForTest({
    getStore: (): StoreMockCU => store,
    createPlan: async (_title: string, _startDate: number): Promise<number> => options?.newPlanId ?? 7101,
    updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
    updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
    insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => {
      inserted += 1;
      if (options?.insertShouldThrow === true) {
        throw new Error('insert_failed_cu');
      }
      return inserted;
    },
    hardDeletePlan: async (id: number): Promise<void> => {
      deletedIds.push(id);
      if (options?.hardDeleteShouldThrow === true) {
        throw new Error('hard_delete_failed_cu');
      }
    }
  });
  return {
    deletedIds: deletedIds,
    insertedCount: (): number => inserted
  };
}

async function captureImportErrorCU(raw: string, token?: PlanJsonImportCancelToken): Promise<string> {
  let message = '';
  try {
    await PlanImportExportService.importPlanFromJson(raw, token);
  } catch (error) {
    message = error instanceof Error ? error.message : String(error);
  }
  return message;
}

export default function phase2BatchCUTest() {
  describe('phase2BatchCU_plan_import_export_edges', () => {
    it('normal: import_should_stop_after_validate_before_opening_transaction', 0, async () => {
      // Arrange
      const store = new StoreMockCU();
      setDepsCU(store);
      const token = new StageCancelTokenCU('after_validate');

      // Act
      const message = await captureImportErrorCU(buildPayloadCU(), token);

      // Assert
      expect(message).assertEqual('import_cancelled:after_validate');
      expect(store.stats.beginCount).assertEqual(0);
      PlanImportExportService.setDepsForTest(null);
    });

    it('boundary: import_should_stop_before_transaction_without_rollback', 0, async () => {
      // Arrange
      const store = new StoreMockCU();
      setDepsCU(store);
      const token = new StageCancelTokenCU('before_transaction');

      // Act
      const message = await captureImportErrorCU(buildPayloadCU(), token);

      // Assert
      expect(message).assertEqual('import_cancelled:before_transaction');
      expect(store.stats.beginCount).assertEqual(0);
      expect(store.stats.rollbackCount).assertEqual(0);
      PlanImportExportService.setDepsForTest(null);
    });

    it('invalid: import_should_rollback_and_delete_when_cancelled_before_commit', 0, async () => {
      // Arrange
      const store = new StoreMockCU();
      const depsState = setDepsCU(store, { newPlanId: 7103 });
      const token = new StageCancelTokenCU('before_commit');

      // Act
      const message = await captureImportErrorCU(buildPayloadCU(2), token);

      // Assert
      expect(message).assertEqual('import_cancelled:before_commit');
      expect(store.stats.commitCount).assertEqual(0);
      expect(store.stats.rollbackCount).assertEqual(1);
      expect(depsState.insertedCount()).assertEqual(2);
      expect(depsState.deletedIds[0]).assertEqual(7103);
      PlanImportExportService.setDepsForTest(null);
    });

    it('conflict: import_should_keep_original_error_when_rollback_fails', 0, async () => {
      // Arrange
      const store = new StoreMockCU();
      store.rollbackShouldThrow = true;
      const depsState = setDepsCU(store, { newPlanId: 7104, insertShouldThrow: true });

      // Act
      const message = await captureImportErrorCU(buildPayloadCU(), undefined);

      // Assert
      expect(message).assertEqual('insert_failed_cu');
      expect(store.stats.rollbackCount).assertEqual(1);
      expect(depsState.deletedIds[0]).assertEqual(7104);
      PlanImportExportService.setDepsForTest(null);
    });

    it('regression: import_should_keep_original_error_when_compensate_delete_fails', 0, async () => {
      // Arrange
      const store = new StoreMockCU();
      const depsState = setDepsCU(store, { newPlanId: 7105, insertShouldThrow: true, hardDeleteShouldThrow: true });

      // Act
      const message = await captureImportErrorCU(buildPayloadCU(), undefined);

      // Assert
      expect(message).assertEqual('insert_failed_cu');
      expect(store.stats.rollbackCount).assertEqual(1);
      expect(depsState.deletedIds[0]).assertEqual(7105);
      PlanImportExportService.setDepsForTest(null);
    });

    it('combined: import_should_wrap_non_error_dependency_failure', 0, async () => {
      // Arrange
      const store = new StoreMockCU();
      PlanImportExportService.setDepsForTest({
        getStore: (): StoreMockCU => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 7106,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {
          return Promise.reject('status_failed_cu');
        },
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 1,
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });

      // Act
      const message = await captureImportErrorCU(buildPayloadCU(), undefined);

      // Assert
      expect(message).assertEqual('import_failed:"status_failed_cu"');
      expect(store.stats.rollbackCount).assertEqual(1);
      PlanImportExportService.setDepsForTest(null);
    });
  });
}
