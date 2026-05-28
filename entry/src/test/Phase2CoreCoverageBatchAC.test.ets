import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';

class FakeResultSetForAC {
  hasFirstRow: boolean = false;
  closeCount: number = 0;
  rowIds: number[] = [];
  private rowCursor: number = -1;
  longValues: Map<number, number> = new Map<number, number>();
  stringValues: Map<number, string> = new Map<number, string>();

  goToFirstRow(): boolean {
    return this.hasFirstRow;
  }

  goToNextRow(): boolean {
    this.rowCursor++;
    return this.rowCursor < this.rowIds.length;
  }

  getColumnIndex(_name: string): number {
    return 0;
  }

  getLong(_index: number): number {
    if (this.rowIds.length > 0) {
      return this.rowIds[this.rowCursor] ?? 0;
    }
    return this.longValues.get(_index) ?? 0;
  }

  getString(_index: number): string {
    return this.stringValues.get(_index) ?? '';
  }

  close(): void {
    this.closeCount++;
    this.rowCursor = -1;
  }
}

class NonErrorDeleteFailureForAC {
  code: string = 'delete_failed_object_ac';
}

class NonErrorUpdateFailureForAC {
  code: string = 'update_failed_object_ac';
}

class FakeRdbStoreForAC {
  beginTxCount: number = 0;
  commitCount: number = 0;
  rollbackCount: number = 0;
  deleteCount: number = 0;
  updateCount: number = 0;
  queryCount: number = 0;
  deleteShouldThrow: boolean = false;
  deleteShouldThrowObject: boolean = false;
  updateShouldThrow: boolean = false;
  updateShouldThrowObject: boolean = false;
  queryShouldThrow: boolean = false;
  deleteReturnValue: number = 1;
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
    if (this.deleteShouldThrowObject) {
      return Promise.reject(new NonErrorDeleteFailureForAC());
    }
    return this.deleteReturnValue;
  }

  async update(_valueBucket: Object, _predicates: Object): Promise<number> {
    this.updateCount++;
    if (this.updateShouldThrow) {
      throw new Error('update_failed_ac');
    }
    if (this.updateShouldThrowObject) {
      return Promise.reject(new NonErrorUpdateFailureForAC());
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

    it('normal: plan_repository_get_plan_by_id_should_map_first_row_and_close_resultset', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.resultSet.hasFirstRow = true;
      store.resultSet.longValues.set(0, 901);
      store.resultSet.stringValues.set(0, 'plan_ac_first');
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      const plan = await PlanRepositoryImpl.getPlanById(901);
      hooks.restore();
      // Assert
      expect(store.queryCount).assertEqual(1);
      expect(store.resultSet.closeCount).assertEqual(1);
      expect(Reflect.get(plan as Object, 'id') as number).assertEqual(901);
      expect(Reflect.get(plan as Object, 'title') as string).assertEqual('plan_ac_first');
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

    it('boundary: plan_repository_restore_plan_should_mark_dirty_when_update_succeeds', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      await PlanRepositoryImpl.restorePlan(61);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(dirty.length).assertEqual(1);
      expect(dirty[0]).assertEqual(61);
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

    it('invalid: plan_repository_get_plan_by_id_should_return_undefined_when_query_throws', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.queryShouldThrow = true;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      const plan = await PlanRepositoryImpl.getPlanById(1001);
      hooks.restore();
      // Assert
      expect(store.queryCount).assertEqual(1);
      expect(plan === undefined).assertTrue();
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

    it('regression: td-20260522-plan-repository-update-strategy-mode-should-mark-dirty-on-success', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      await PlanRepositoryImpl.updateStrategyMode(71, 2);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(dirty.length).assertEqual(1);
      expect(dirty[0]).assertEqual(71);
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

    it('combined: plan_repository_save_ai_context_should_persist_without_dirty_flag', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      await PlanRepositoryImpl.saveAiContext(91, 'prompt_ac', 'explain_ac');
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      expect(dirty.length).assertEqual(0);
    });

    it('combined: plan_repository_should_wrap_non_error_failures_with_method_specific_messages', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      store.deleteShouldThrowObject = true;
      store.updateShouldThrowObject = true;
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      const messages: string[] = [];
      // Act
      try { await PlanRepositoryImpl.restorePlan(201); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.hardDeletePlan(202); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.updatePlanStatus(203, 2); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.updateStrategyDimensions(204, 1, 2, 3, 4); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.softDeletePlan(205); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.updateStartDate(206, 1000); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.updatePlanName(207, 'wrapped'); } catch (err) { messages.push((err as Error).message); }
      try { await PlanRepositoryImpl.updateAutoAmapRoute(208, true); } catch (err) { messages.push((err as Error).message); }
      hooks.restore();
      // Assert
      expect(messages.length).assertEqual(8);
      expect(messages[0].includes('restore_plan_failed')).assertTrue();
      expect(messages[1].includes('hard_delete_plan_failed')).assertTrue();
      expect(messages[2].includes('update_plan_status_failed')).assertTrue();
      expect(messages[3].includes('update_strategy_dimensions_failed')).assertTrue();
      expect(messages[4].includes('soft_delete_plan_failed')).assertTrue();
      expect(messages[5].includes('update_start_date_failed')).assertTrue();
      expect(messages[6].includes('update_plan_name_failed')).assertTrue();
      expect(messages[7].includes('update_auto_amap_route_failed')).assertTrue();
    });

    it('boundary: purge_old_trash_should_return_zero_when_no_expired_plan_ids_are_found', 0, async () => {
      // Arrange
      clearDirtyPoolForAC();
      const store = new FakeRdbStoreForAC();
      const hooks = new StaticHooksForAC();
      hooks.setGetInstance((): Object => createHelperInstanceForAC(store as Object));
      // Act
      const emptyDeleted = await PlanRepositoryImpl.purgeOldTrash();
      hooks.restore();
      // Assert
      expect(emptyDeleted).assertEqual(0);
      expect(store.beginTxCount).assertEqual(0);
      expect(store.deleteCount).assertEqual(0);
    });
  });
}
