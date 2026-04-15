import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';

class FakeResultSetForAD {
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

class FakeRdbStoreForAD {
  queryShouldThrow: boolean = false;
  deleteShouldThrow: boolean = false;
  queryCount: number = 0;
  deleteCount: number = 0;
  beginTxCount: number = 0;
  commitCount: number = 0;
  rollbackCount: number = 0;
  nextDeleteRows: number = 0;
  queryResult: FakeResultSetForAD = new FakeResultSetForAD([]);

  beginTransaction(): void {
    this.beginTxCount++;
  }

  commit(): void {
    this.commitCount++;
  }

  rollBack(): void {
    this.rollbackCount++;
  }

  async query(_predicates: Object): Promise<FakeResultSetForAD> {
    this.queryCount++;
    if (this.queryShouldThrow) {
      throw new Error('query_failed_ad');
    }
    return this.queryResult;
  }

  async delete(_predicates: Object): Promise<number> {
    this.deleteCount++;
    if (this.deleteShouldThrow) {
      throw new Error('delete_failed_ad');
    }
    return this.nextDeleteRows;
  }
}

class FakeHelperForAD {
  private readonly store: Object | null;

  constructor(store: Object | null) {
    this.store = store;
  }

  getRdbStore(): Object | null {
    return this.store;
  }
}

class StaticHooksForAD {
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

function clearDirtyPoolForAD(): void {
  PlanRepositoryImpl.consumeDirtyPlanIds();
}

function createHelperInstanceForAD(store: Object | null): Object {
  return new FakeHelperForAD(store) as Object;
}

export default function phase2CoreCoverageBatchADTest() {
  describe('phase2CoreCoverageBatchADTest', () => {
    it('normal: plan_repository_search_all_plans_paged_should_return_array_when_store_exists', 0, async () => {
      // Arrange
      clearDirtyPoolForAD();
      const store = new FakeRdbStoreForAD();
      const hooks = new StaticHooksForAD();
      hooks.setGetInstance((): Object => createHelperInstanceForAD(store as Object));
      // Act
      const result = await PlanRepositoryImpl.searchAllPlansPaged('keyword_ad', 0, 20);
      hooks.restore();
      // Assert
      expect(Array.isArray(result)).assertTrue();
    });

    it('boundary: plan_repository_purge_old_trash_should_return_zero_when_store_exists_but_no_rows', 0, async () => {
      // Arrange
      clearDirtyPoolForAD();
      const store = new FakeRdbStoreForAD();
      store.queryResult = new FakeResultSetForAD([]);
      const hooks = new StaticHooksForAD();
      hooks.setGetInstance((): Object => createHelperInstanceForAD(store as Object));
      // Act
      const deleted = await PlanRepositoryImpl.purgeOldTrash();
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(deleted).assertEqual(0);
      expect(dirty.length).assertEqual(0);
    });

    it('invalid: plan_repository_search_all_plans_paged_should_return_empty_when_query_throws', 0, async () => {
      // Arrange
      clearDirtyPoolForAD();
      const store = new FakeRdbStoreForAD();
      store.queryShouldThrow = true;
      const hooks = new StaticHooksForAD();
      hooks.setGetInstance((): Object => createHelperInstanceForAD(store as Object));
      // Act
      const result = await PlanRepositoryImpl.searchAllPlansPaged('invalid_ad', 10, 10);
      hooks.restore();
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('conflict: plan_repository_purge_old_trash_should_return_zero_when_query_throws', 0, async () => {
      // Arrange
      clearDirtyPoolForAD();
      const store = new FakeRdbStoreForAD();
      store.queryShouldThrow = true;
      const hooks = new StaticHooksForAD();
      hooks.setGetInstance((): Object => createHelperInstanceForAD(store as Object));
      // Act
      const deleted = await PlanRepositoryImpl.purgeOldTrash();
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(deleted).assertEqual(0);
      expect(dirty.length).assertEqual(0);
    });

    it('regression: td-20260415-search-all-plans-paged-should-handle-blank-keyword-with-store', 0, async () => {
      // Arrange
      clearDirtyPoolForAD();
      const store = new FakeRdbStoreForAD();
      const hooks = new StaticHooksForAD();
      hooks.setGetInstance((): Object => createHelperInstanceForAD(store as Object));
      // Act
      const result = await PlanRepositoryImpl.searchAllPlansPaged('   ', -5, 999);
      hooks.restore();
      // Assert
      expect(Array.isArray(result)).assertTrue();
    });

    it('combined: plan_repository_search_and_purge_should_not_throw_on_store_paths', 0, async () => {
      // Arrange
      clearDirtyPoolForAD();
      const store = new FakeRdbStoreForAD();
      store.queryResult = new FakeResultSetForAD([1]);
      store.nextDeleteRows = 1;
      const hooks = new StaticHooksForAD();
      hooks.setGetInstance((): Object => createHelperInstanceForAD(store as Object));
      // Act
      const searched = await PlanRepositoryImpl.searchAllPlansPaged('combo_ad', 1, 5);
      const deleted = await PlanRepositoryImpl.purgeOldTrash();
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(Array.isArray(searched)).assertTrue();
      expect(deleted >= 0).assertTrue();
      expect(Array.isArray(dirty)).assertTrue();
    });
  });
}

