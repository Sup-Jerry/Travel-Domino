import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';

class FakeResultSetForAC {
  hasFirstRow: boolean = false;
  closeCount: number = 0;

  goToFirstRow(): boolean {
    return this.hasFirstRow;
  }

  getColumnIndex(_name: string): number {
    return 0;
  }

  getLong(_index: number): number {
    return 0;
  }

  getString(_index: number): string {
    return '';
  }

  close(): void {
    this.closeCount++;
  }
}

class FakeRdbStoreForAC {
  beginTxCount: number = 0;
  commitCount: number = 0;
  rollbackCount: number = 0;
  deleteCount: number = 0;
  updateCount: number = 0;
  queryCount: number = 0;
  deleteShouldThrow: boolean = false;
  updateShouldThrow: boolean = false;
  queryShouldThrow: boolean = false;
  resultSet: FakeResultSetForAC = new FakeResultSetForAC();

  beginTransaction(): void {
    this.beginTxCount++;
  }

  commit(): void {
    this.commitCount++;
  }

  rollBack(): void {
    this.rollbackCount++;
  }

  async delete(_predicates: Object): Promise<number> {
    this.deleteCount++;
    if (this.deleteShouldThrow) {
      throw new Error('delete_failed_ac');
    }
    return 1;
  }

  async update(_valueBucket: Object, _predicates: Object): Promise<number> {
    this.updateCount++;
    if (this.updateShouldThrow) {
      throw new Error('update_failed_ac');
    }
    return 1;
  }

  async query(_predicates: Object): Promise<FakeResultSetForAC> {
    this.queryCount++;
    if (this.queryShouldThrow) {
      throw new Error('query_failed_ac');
    }
    return this.resultSet;
  }
}

class FakeHelperForAC {
  private readonly store: Object | null;

  constructor(store: Object | null) {
    this.store = store;
  }

  getRdbStore(): Object | null {
    return this.store;
  }
}

class StaticHooksForAC {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(RdbHelper, 'getInstance') as Object;
  }

  setGetInstance(fn: () => Object): void {
    Reflect.set(RdbHelper, 'getInstance', fn);
  }

  restore(): void {
    Reflect.set(RdbHelper, 'getInstance', this.originGetInstance);
  }
}

function clearDirtyPoolForAC(): void {
  PlanRepositoryImpl.consumeDirtyPlanIds();
}

function createHelperInstanceForAC(store: Object | null): Object {
  return new FakeHelperForAC(store) as Object;
}

export default function phase2CoreCoverageBatchACTest() {
  describe('phase2CoreCoverageBatchACTest', () => {
    it('normal: plan_repository_hard_delete_should_commit_and_mark_dirty_when_all_deletes_succeed', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      await PlanRepositoryImpl.hardDeletePlan(51);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.beginTxCount).assertEqual(1);
      expect(store.deleteCount).assertEqual(2);
      expect(store.commitCount).assertEqual(1);
      expect(store.rollbackCount).assertEqual(0);
      expect(dirty.length).assertEqual(1);
      expect(dirty[0]).assertEqual(51);
    });

    it('boundary: plan_repository_get_plan_by_id_should_return_undefined_and_close_resultset_when_no_first_row', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.resultSet.hasFirstRow = false;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      const plan = await PlanRepositoryImpl.getPlanById(99);
      hooks.restore();
      // Assert
      expect(plan === undefined).assertTrue();
      expect(store.queryCount).assertEqual(1);
      expect(store.resultSet.closeCount).assertEqual(1);
    });

    it('invalid: plan_repository_restore_plan_should_throw_when_update_fails', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      let thrown = '';
      // Act
      try {
        await PlanRepositoryImpl.restorePlan(17);
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(thrown).assertEqual('update_failed_ac');
      expect(dirty.length).assertEqual(0);
    });

    it('conflict: plan_repository_update_plan_name_should_throw_when_update_fails', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      let thrown = '';
      // Act
      try {
        await PlanRepositoryImpl.updatePlanName(18, 'plan_ac');
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(thrown).assertEqual('update_failed_ac');
      expect(dirty.length).assertEqual(0);
    });

    it('regression: td-20260415-update-start-date-should-throw-when-update-fails', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      let thrown = '';
      // Act
      try {
        await PlanRepositoryImpl.updateStartDate(19, 1728000000);
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(thrown).assertEqual('update_failed_ac');
      expect(dirty.length).assertEqual(0);
    });

    it('combined: plan_repository_hard_delete_and_update_strategy_dimensions_should_cover_failure_branches', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.deleteShouldThrow = true;
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      let hardDeleteThrown = '';
      let updateStrategyThrown = '';
      // Act
      try {
        await PlanRepositoryImpl.hardDeletePlan(77);
      } catch (err) {
        const e = err as Error;
        hardDeleteThrown = e.message;
      }
      try {
        await PlanRepositoryImpl.updateStrategyDimensions(77, 1, 2, 3, 4);
      } catch (err) {
        const e = err as Error;
        updateStrategyThrown = e.message;
      }
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(hardDeleteThrown).assertEqual('delete_failed_ac');
      expect(updateStrategyThrown).assertEqual('update_failed_ac');
      expect(store.rollbackCount).assertEqual(1);
      expect(store.commitCount).assertEqual(0);
      expect(dirty.length).assertEqual(0);
    });
  });
}

