import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

class FakePredicatesForAA {
  public readonly tableName: string;
  public readonly clauses: string[] = [];

  constructor(tableName: string) {
    this.tableName = tableName;
  }

  equalTo(column: string, value: Object): FakePredicatesForAA {
    this.clauses.push(`eq:${column}:${String(value)}`);
    return this;
  }

  and(): FakePredicatesForAA {
    this.clauses.push('and');
    return this;
  }

  greaterThan(column: string, value: Object): FakePredicatesForAA {
    this.clauses.push(`gt:${column}:${String(value)}`);
    return this;
  }

  lessThanOrEqualTo(column: string, value: Object): FakePredicatesForAA {
    this.clauses.push(`lte:${column}:${String(value)}`);
    return this;
  }
}

class FakeResultSetForAA {
  private readonly ids: number[];
  private cursor: number = -1;
  closeCount: number = 0;

  constructor(ids: number[]) {
    this.ids = ids;
  }

  goToNextRow(): boolean {
    this.cursor++;
    return this.cursor < this.ids.length;
  }

  getColumnIndex(_name: string): number {
    return 1;
  }

  getLong(_index: number): number {
    return this.ids[this.cursor];
  }

  close(): void {
    this.closeCount++;
  }
}

class FakeRdbStoreForAA {
  beginTxCount: number = 0;
  commitCount: number = 0;
  rollbackCount: number = 0;
  updateCount: number = 0;
  deleteCount: number = 0;
  nextDeleteRows: number = 0;
  updateShouldThrow: boolean = false;
  deleteShouldThrow: boolean = false;
  queryResult: FakeResultSetForAA = new FakeResultSetForAA([]);
  lastUpdateValueBucket: Object | null = null;
  lastUpdatePredicates: Object | null = null;

  beginTransaction(): void {
    this.beginTxCount++;
  }

  commit(): void {
    this.commitCount++;
  }

  rollBack(): void {
    this.rollbackCount++;
  }

  async update(valueBucket: Object, _predicates: Object): Promise<number> {
    this.updateCount++;
    this.lastUpdateValueBucket = valueBucket;
    this.lastUpdatePredicates = _predicates;
    if (this.updateShouldThrow) {
      throw new Error('update_failed_aa');
    }
    return 1;
  }

  async delete(_predicates: Object): Promise<number> {
    this.deleteCount++;
    if (this.deleteShouldThrow) {
      throw new Error('delete_failed_aa');
    }
    return this.nextDeleteRows;
  }

  async query(_predicates: Object): Promise<FakeResultSetForAA> {
    return this.queryResult;
  }
}

class StaticHooksForAA {
  private readonly originGetInstance: Object;
  private readonly originClearActiveRuntimeEventsForPlan: Object;
  private readonly originPredicates: Object;

  constructor() {
    this.originGetInstance = Reflect.get(RdbHelper, 'getInstance') as Object;
    this.originClearActiveRuntimeEventsForPlan =
      Reflect.get(PlanRepositoryImpl as Object, 'clearActiveRuntimeEventsForPlan') as Object;
    this.originPredicates = Reflect.get(Reflect.get(globalThis, 'relationalStore') as Object, 'RdbPredicates') as Object;
  }

  setGetInstance(fn: () => Object): void {
    Reflect.set(RdbHelper, 'getInstance', fn);
  }

  setClearActiveRuntimeEventsForPlan(fn: (store: Object, planId: number) => Promise<void>): void {
    Reflect.set(PlanRepositoryImpl as Object, 'clearActiveRuntimeEventsForPlan', fn);
  }

  useFakePredicates(): void {
    Reflect.set(Reflect.get(globalThis, 'relationalStore') as Object, 'RdbPredicates', FakePredicatesForAA);
  }

  restore(): void {
    Reflect.set(RdbHelper, 'getInstance', this.originGetInstance);
    Reflect.set(PlanRepositoryImpl as Object, 'clearActiveRuntimeEventsForPlan', this.originClearActiveRuntimeEventsForPlan);
    Reflect.set(Reflect.get(globalThis, 'relationalStore') as Object, 'RdbPredicates', this.originPredicates);
  }
}

function clearDirtyPoolForAA(): void {
  PlanRepositoryImpl.consumeDirtyPlanIds();
}

class FakeHelperForAA {
  private readonly store: Object | null;

  constructor(store: Object | null) {
    this.store = store;
  }

  getRdbStore(): Object | null {
    return this.store;
  }
}

function createHelperInstanceForAA(store: Object | null): Object {
  return new FakeHelperForAA(store) as Object;
}

function getPrivateClearActiveForAA(): (store: Object, planId: number) => Promise<void> {
  return Reflect.get(PlanRepositoryImpl as Object, 'clearActiveRuntimeEventsForPlan') as (store: Object, planId: number) => Promise<void>;
}

export default function phase2CoreCoverageBatchAATest() {
  describe('phase2CoreCoverageBatchAATest', () => {
    it('normal: plan_repository_soft_delete_should_call_clear_active_and_commit', 0, async () => {
      // Arrange
      clearDirtyPoolForAA();
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      let clearCalls = 0;
      hooks.setGetInstance((): Object => createHelperInstanceForAA(store as Object));
      hooks.setClearActiveRuntimeEventsForPlan(async (_store: Object, _planId: number): Promise<void> => {
        clearCalls++;
      });
      // Act
      await PlanRepositoryImpl.softDeletePlan(7);
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(clearCalls).assertEqual(1);
      expect(store.beginTxCount).assertEqual(1);
      expect(store.commitCount).assertEqual(1);
    });

    it('boundary: plan_repository_update_plan_status_should_not_call_clear_active_when_status_not_archived', 0, async () => {
      // Arrange
      clearDirtyPoolForAA();
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      let clearCalls = 0;
      hooks.setGetInstance((): Object => createHelperInstanceForAA(store as Object));
      hooks.setClearActiveRuntimeEventsForPlan(async (_store: Object, _planId: number): Promise<void> => {
        clearCalls++;
      });
      // Act
      await PlanRepositoryImpl.updatePlanStatus(9, 1);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.beginTxCount).assertEqual(1);
      expect(store.commitCount).assertEqual(1);
      expect(store.updateCount).assertEqual(1);
      expect(clearCalls).assertEqual(0);
      expect(dirty.length).assertEqual(1);
      expect(dirty[0]).assertEqual(9);
    });

    it('invalid: plan_repository_update_plan_status_should_rollback_and_throw_when_update_fails', 0, async () => {
      // Arrange
      clearDirtyPoolForAA();
      const store = new FakeRdbStoreForAA();
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAA();
      hooks.setGetInstance((): Object => createHelperInstanceForAA(store as Object));
      let thrown = '';
      // Act
      try {
        await PlanRepositoryImpl.updatePlanStatus(10, 2);
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      hooks.restore();
      // Assert
      expect(store.beginTxCount).assertEqual(1);
      expect(store.rollbackCount).assertEqual(1);
      expect(store.commitCount).assertEqual(0);
      expect(thrown).assertEqual('update_failed_aa');
    });

    it('conflict: plan_repository_soft_delete_should_rollback_and_throw_when_clear_active_fails', 0, async () => {
      // Arrange
      clearDirtyPoolForAA();
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      hooks.setGetInstance((): Object => createHelperInstanceForAA(store as Object));
      hooks.setClearActiveRuntimeEventsForPlan(async (_store: Object, _planId: number): Promise<void> => {
        throw new Error('clear_active_failed_aa');
      });
      let thrown = '';
      // Act
      try {
        await PlanRepositoryImpl.softDeletePlan(11);
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      hooks.restore();
      // Assert
      expect(store.beginTxCount).assertEqual(1);
      expect(store.rollbackCount).assertEqual(1);
      expect(store.commitCount).assertEqual(0);
      expect(thrown).assertEqual('clear_active_failed_aa');
    });

    it('regression: td-20260415-update-plan-status-archived-should-call-clear-active-once', 0, async () => {
      // Arrange
      clearDirtyPoolForAA();
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      let clearCalls = 0;
      hooks.setGetInstance((): Object => createHelperInstanceForAA(store as Object));
      hooks.setClearActiveRuntimeEventsForPlan(async (_store: Object, _planId: number): Promise<void> => {
        clearCalls++;
      });
      // Act
      await PlanRepositoryImpl.updatePlanStatus(12, 2);
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(clearCalls).assertEqual(1);
      expect(store.commitCount).assertEqual(1);
    });

    it('combined: plan_repository_purge_old_trash_should_delete_events_then_plans_and_mark_dirty_ids', 0, async () => {
      // Arrange
      clearDirtyPoolForAA();
      const store = new FakeRdbStoreForAA();
      store.queryResult = new FakeResultSetForAA([21, 22]);
      const hooks = new StaticHooksForAA();
      hooks.setGetInstance((): Object => createHelperInstanceForAA(store as Object));
      // Act
      const deletedRows = await PlanRepositoryImpl.purgeOldTrash();
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(deletedRows).assertEqual(0);
      expect(dirty.length).assertEqual(0);
    });

    it('normal: clear_active_runtime_events_should_reset_runtime_columns', 0, async () => {
      // Arrange
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      hooks.useFakePredicates();
      // Act
      await getPrivateClearActiveForAA()(store as Object, 31);
      hooks.restore();
      const bucket = store.lastUpdateValueBucket as Object;
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(Reflect.get(bucket, EventEntity.ACTUAL_START_TIME) as number).assertEqual(0);
      expect(Reflect.get(bucket, EventEntity.ACTUAL_END_TIME) as number).assertEqual(0);
      expect(Reflect.get(bucket, EventEntity.COMPLETION_STATUS) as number).assertEqual(EventEntity.STATE_PENDING);
    });

    it('boundary: clear_active_runtime_events_should_filter_by_exact_plan_id', 0, async () => {
      // Arrange
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      hooks.useFakePredicates();
      // Act
      await getPrivateClearActiveForAA()(store as Object, 1);
      hooks.restore();
      const predicates = store.lastUpdatePredicates as FakePredicatesForAA;
      // Assert
      expect(predicates.tableName).assertEqual(EventEntity.TABLE_NAME);
      expect(predicates.clauses.indexOf(`eq:${EventEntity.PLAN_ID}:1`) >= 0).assertTrue();
    });

    it('invalid: clear_active_runtime_events_should_propagate_update_failure', 0, async () => {
      // Arrange
      const store = new FakeRdbStoreForAA();
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAA();
      hooks.useFakePredicates();
      let thrown = '';
      // Act
      try {
        await getPrivateClearActiveForAA()(store as Object, 32);
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      hooks.restore();
      // Assert
      expect(thrown).assertEqual('update_failed_aa');
      expect(store.updateCount).assertEqual(1);
    });

    it('conflict: clear_active_runtime_events_should_only_target_active_pending_started_events', 0, async () => {
      // Arrange
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      hooks.useFakePredicates();
      // Act
      await getPrivateClearActiveForAA()(store as Object, 33);
      hooks.restore();
      const predicates = store.lastUpdatePredicates as FakePredicatesForAA;
      // Assert
      expect(predicates.clauses.indexOf(`eq:${EventEntity.STATUS}:1`) >= 0).assertTrue();
      expect(predicates.clauses.indexOf(`eq:${EventEntity.COMPLETION_STATUS}:${EventEntity.STATE_PENDING}`) >= 0).assertTrue();
      expect(predicates.clauses.indexOf(`gt:${EventEntity.ACTUAL_START_TIME}:0`) >= 0).assertTrue();
      expect(predicates.clauses.indexOf(`lte:${EventEntity.ACTUAL_END_TIME}:0`) >= 0).assertTrue();
    });

    it('regression: td-20260422-clear-active-should_keep_predicate_chain_order_stable', 0, async () => {
      // Arrange
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      hooks.useFakePredicates();
      // Act
      await getPrivateClearActiveForAA()(store as Object, 34);
      hooks.restore();
      const predicates = store.lastUpdatePredicates as FakePredicatesForAA;
      // Assert
      expect(predicates.clauses[0]).assertEqual(`eq:${EventEntity.PLAN_ID}:34`);
      expect(predicates.clauses[1]).assertEqual('and');
      expect(predicates.clauses[2]).assertEqual(`eq:${EventEntity.STATUS}:1`);
    });

    it('combined: clear_active_runtime_events_should_build_full_runtime_reset_update', 0, async () => {
      // Arrange
      const store = new FakeRdbStoreForAA();
      const hooks = new StaticHooksForAA();
      hooks.useFakePredicates();
      // Act
      await getPrivateClearActiveForAA()(store as Object, 35);
      hooks.restore();
      const bucket = store.lastUpdateValueBucket as Object;
      const predicates = store.lastUpdatePredicates as FakePredicatesForAA;
      // Assert
      expect(Object.keys(bucket).length).assertEqual(3);
      expect(predicates.clauses.length).assertEqual(9);
      expect(predicates.clauses[predicates.clauses.length - 1]).assertEqual(`lte:${EventEntity.ACTUAL_END_TIME}:0`);
    });
  });
}
