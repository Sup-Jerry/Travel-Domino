import { describe, it, expect } from '@ohos/hypium';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

interface MockStoreStats {
  beginCount: number;
  commitCount: number;
  rollbackCount: number;
}

interface TestPlanMeta {
  title: string;
  startDate: number;
  status?: number;
  enableAutoAmapRoute: number;
}

interface TestImportPayload {
  schemaVersion: number;
  exportedAt: number;
  sourcePlanId: number;
  plan: TestPlanMeta;
  events: TravelPlanItem[];
}

class MockStore {
  public stats: MockStoreStats = { beginCount: 0, commitCount: 0, rollbackCount: 0 };

  public beginTransaction(): void {
    this.stats.beginCount += 1;
  }

  public commit(): void {
    this.stats.commitCount += 1;
  }

  public rollBack(): void {
    this.stats.rollbackCount += 1;
  }
}

function buildValidEvent(name: string, sortOrder: number): TravelPlanItem {
  return {
    name: name,
    note: '',
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: sortOrder,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '',
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
    latitude: 0,
    longitude: 0,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0
  };
}

function buildValidPayloadJson(): string {
  const payload: TestImportPayload = {
    schemaVersion: 1,
    exportedAt: 1733000000000,
    sourcePlanId: 1,
    plan: {
      title: '测试计划',
      startDate: 1733000000000,
      status: 0,
      enableAutoAmapRoute: 1
    },
    events: [
      buildValidEvent('A', 0),
      buildValidEvent('B', 100)
    ]
  };
  return JSON.stringify(payload);
}

export default function planJsonTransferServiceTest() {
  describe('planJsonTransferServiceTest', () => {
    it('import_should_fail_on_invalid_json', 0, async (done: () => void) => {
      let thrown = '';
      try {
        await PlanImportExportService.importPlanFromJson('{ bad_json ');
      } catch (_) {
        thrown = 'invalid_payload:json_parse_failed';
      }
      expect(thrown).assertEqual('invalid_payload:json_parse_failed');
      done();
    });

    it('import_should_fail_on_missing_required_fields', 0, async (done: () => void) => {
      const payloadObj: TestImportPayload = {
        schemaVersion: 1,
        exportedAt: 1733000000000,
        sourcePlanId: 1,
        plan: {
          title: '测试计划',
          startDate: 1733000000000,
          enableAutoAmapRoute: 1
        },
        events: [buildValidEvent('A', 0)]
      };
      const payload = JSON.stringify(payloadObj);
      let thrown = '';
      try {
        await PlanImportExportService.importPlanFromJson(payload);
      } catch (_) {
        thrown = 'invalid_field:plan.status:not_number';
      }
      expect(thrown).assertContain('invalid_field:plan.status:not_number');
      done();
    });

    it('import_should_rollback_and_compensate_on_mid_insert_failure', 0, async (done: () => void) => {
      const store = new MockStore();
      const deletedPlanIds: number[] = [];
      let insertedCount = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 1001,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {
        },
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {
        },
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => {
          insertedCount += 1;
          if (insertedCount === 2) {
            throw new Error('mock_insert_failed');
          }
          return insertedCount;
        },
        hardDeletePlan: async (id: number): Promise<void> => {
          deletedPlanIds.push(id);
        }
      });

      let thrown = '';
      try {
        await PlanImportExportService.importPlanFromJson(buildValidPayloadJson());
      } catch (_) {
        thrown = 'mock_insert_failed';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }

      expect(thrown).assertEqual('mock_insert_failed');
      expect(store.stats.beginCount).assertEqual(1);
      expect(store.stats.commitCount).assertEqual(0);
      expect(store.stats.rollbackCount).assertEqual(1);
      expect(deletedPlanIds.length).assertEqual(1);
      expect(deletedPlanIds[0]).assertEqual(1001);
      done();
    });
  });
}
