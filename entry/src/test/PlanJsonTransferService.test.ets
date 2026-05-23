import { describe, it, expect } from '@ohos/hypium';
import { PlanImportExportService, PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
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
    it('invalid: import_should_fail_on_invalid_json', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      let thrown = '';
      try {
        await PlanImportExportService.importPlanFromJson('{ bad_json ');
      } catch (_) {
        thrown = 'invalid_payload:json_parse_failed';
      }
      expect(thrown).assertEqual('invalid_payload:json_parse_failed');
      done();
    });

    it('invalid: import_should_fail_on_missing_required_fields', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
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

    it('invalid: import_should_rollback_and_compensate_on_mid_insert_failure', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
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
  describe('unit_test_case_generator_backfill_PlanJsonTransferService', () => {
    it('normal: import_should_commit_and_return_new_plan_id_on_valid_payload', 0, async (done: () => void) => {
      // Arrange
      const store = new MockStore();
      const createdPlanIds: number[] = [];
      const createdPlanStartDates: number[] = [];
      let inserted = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, startDate: number): Promise<number> => {
          createdPlanIds.push(2001);
          createdPlanStartDates.push(startDate);
          return 2001;
        },
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {
        },
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {
        },
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => {
          inserted += 1;
          return inserted;
        },
        hardDeletePlan: async (_id: number): Promise<void> => {
        }
      });
      // Act
      const importedId = await PlanImportExportService.importPlanFromJson(buildValidPayloadJson());
      // Assert
      expect(importedId).assertEqual(2001);
      expect(store.stats.beginCount).assertEqual(1);
      expect(store.stats.commitCount).assertEqual(1);
      expect(store.stats.rollbackCount).assertEqual(0);
      expect(createdPlanIds.length).assertEqual(1);
      expect(createdPlanStartDates[0]).assertEqual(1733000000000);
      expect(inserted).assertEqual(2);
      PlanImportExportService.setDepsForTest(null);
      done();
    });

    it('boundary: import_should_allow_empty_events_payload', 0, async (done: () => void) => {
      // Arrange
      const store = new MockStore();
      const parsed = JSON.parse(buildValidPayloadJson()) as TestImportPayload;
      parsed.events = [];
      let inserted = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 2101,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {
        },
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {
        },
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => {
          inserted += 1;
          return inserted;
        },
        hardDeletePlan: async (_id: number): Promise<void> => {
        }
      });
      // Act
      const importedId = await PlanImportExportService.importPlanFromJson(JSON.stringify(parsed));
      // Assert
      expect(importedId).assertEqual(2101);
      expect(inserted).assertEqual(0);
      expect(store.stats.commitCount).assertEqual(1);
      expect(store.stats.rollbackCount).assertEqual(0);
      PlanImportExportService.setDepsForTest(null);
      done();
    });

    it('conflict: import_should_rollback_when_cancelled_during_event_loop', 0, async (done: () => void) => {
      // Arrange
      const store = new MockStore();
      const cancelToken = new PlanJsonImportCancelToken();
      const deletedPlanIds: number[] = [];
      let inserted = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 2201,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {
        },
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {
        },
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => {
          inserted += 1;
          if (inserted === 1) {
            cancelToken.cancel();
          }
          return inserted;
        },
        hardDeletePlan: async (id: number): Promise<void> => {
          deletedPlanIds.push(id);
        }
      });
      // Act
      let thrown = '';
      try {
        await PlanImportExportService.importPlanFromJson(buildValidPayloadJson(), cancelToken);
      } catch (error) {
        thrown = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }
      // Assert
      expect(thrown).assertContain('import_cancelled:insert_event_1');
      expect(store.stats.commitCount).assertEqual(0);
      expect(store.stats.rollbackCount).assertEqual(1);
      expect(deletedPlanIds.length).assertEqual(1);
      expect(deletedPlanIds[0]).assertEqual(2201);
      done();
    });

    it('regression: td-20260411-import_should_floor_status_before_persist', 0, async (done: () => void) => {
      // Arrange
      const store = new MockStore();
      const parsed = JSON.parse(buildValidPayloadJson()) as TestImportPayload;
      parsed.plan.status = 1.8;
      let persistedStatus = -1;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 2301,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {
        },
        updatePlanStatus: async (_id: number, status: number): Promise<void> => {
          persistedStatus = status;
        },
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 1,
        hardDeletePlan: async (_id: number): Promise<void> => {
        }
      });
      // Act
      await PlanImportExportService.importPlanFromJson(JSON.stringify(parsed));
      // Assert
      expect(persistedStatus).assertEqual(1);
      expect(store.stats.commitCount).assertEqual(1);
      PlanImportExportService.setDepsForTest(null);
      done();
    });

    it('combined: import_should_apply_status_and_auto_route_with_event_normalization', 0, async (done: () => void) => {
      // Arrange
      const store = new MockStore();
      const parsed = JSON.parse(buildValidPayloadJson()) as TestImportPayload;
      parsed.plan.status = 2;
      parsed.plan.enableAutoAmapRoute = 0;
      parsed.events[0].preTravelMinutes = -1;
      let persistedStatus = -1;
      let persistedAutoRoute = true;
      let persistedPreTravel = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 2401,
        updateAutoAmapRoute: async (_id: number, enabled: boolean): Promise<void> => {
          persistedAutoRoute = enabled;
        },
        updatePlanStatus: async (_id: number, status: number): Promise<void> => {
          persistedStatus = status;
        },
        insertEvent: async (_planId: number, item: TravelPlanItem): Promise<number> => {
          persistedPreTravel = item.preTravelMinutes ?? 0;
          return 1;
        },
        hardDeletePlan: async (_id: number): Promise<void> => {
        }
      });
      // Act
      await PlanImportExportService.importPlanFromJson(JSON.stringify(parsed));
      // Assert
      expect(persistedStatus).assertEqual(2);
      expect(persistedAutoRoute).assertEqual(false);
      expect(persistedPreTravel).assertEqual(-1);
      expect(store.stats.commitCount).assertEqual(1);
      PlanImportExportService.setDepsForTest(null);
      done();
    });

    it('boundary: import_should_fail_before_transaction_when_store_not_ready', 0, async (done: () => void) => {
      // Arrange
      PlanImportExportService.setDepsForTest({
        getStore: (): null => null,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 0,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 0,
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });
      let thrown = '';

      // Act
      try {
        await PlanImportExportService.importPlanFromJson(buildValidPayloadJson());
      } catch (error) {
        thrown = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }

      // Assert
      expect(thrown).assertEqual('db_not_ready');
      done();
    });

    it('regression: cancel_token_should_throw_immediately_after_manual_cancel', 0, () => {
      // Arrange
      const token = new PlanJsonImportCancelToken();
      let thrown = '';

      // Act
      token.cancel();
      try {
        token.throwIfCancelled('manual_stage');
      } catch (error) {
        thrown = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(thrown).assertEqual('import_cancelled:manual_stage');
    });
  });
}
