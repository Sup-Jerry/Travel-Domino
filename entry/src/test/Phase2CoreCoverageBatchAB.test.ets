import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { PlanEntity } from '../main/ets/model/entity/PlanEntity';

class FakeRdbStoreForAB {
  insertCount: number = 0;
  updateCount: number = 0;
  insertShouldThrow: boolean = false;
  updateShouldThrow: boolean = false;
  nextInsertId: number = 0;
  insertedValueBucket: Object | null = null;
  updateValueBuckets: Object[] = [];

  async insert(_tableName: string, valueBucket: Object): Promise<number> {
    this.insertCount++;
    this.insertedValueBucket = valueBucket;
    if (this.insertShouldThrow) {
      throw new Error('insert_failed_ab');
    }
    return this.nextInsertId;
  }

  async update(valueBucket: Object, _predicates: Object): Promise<number> {
    this.updateCount++;
    this.updateValueBuckets.push(valueBucket);
    if (this.updateShouldThrow) {
      throw new Error('update_failed_ab');
    }
    return 1;
  }
}

class FakeHelperForAB {
  private readonly store: Object | null;

  constructor(store: Object | null) {
    this.store = store;
  }

  getRdbStore(): Object | null {
    return this.store;
  }
}

class StaticHooksForAB {
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

function clearDirtyPoolForAB(): void {
  PlanRepositoryImpl.consumeDirtyPlanIds();
}

function createHelperInstanceForAB(store: Object | null): Object {
  return new FakeHelperForAB(store) as Object;
}

export default function phase2CoreCoverageBatchABTest() {
  describe('phase2CoreCoverageBatchABTest', () => {
    it('normal: plan_repository_create_plan_should_return_row_id_and_mark_dirty', 0, async () => {
      // Arrange
      clearDirtyPoolForAB();
      const store = new FakeRdbStoreForAB();
      store.nextInsertId = 301;
      const hooks = new StaticHooksForAB();
      hooks.setGetInstance((): Object => createHelperInstanceForAB(store as Object));
      // Act
      const rowId = await PlanRepositoryImpl.createPlan('batch_ab_plan', 1728000000);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(rowId).assertEqual(301);
      expect(store.insertCount).assertEqual(1);
      expect(dirty.length).assertEqual(1);
      expect(dirty[0]).assertEqual(301);
      const inserted = store.insertedValueBucket as Object;
      expect(Reflect.get(inserted, PlanEntity.NAME) as string).assertEqual('batch_ab_plan');
      expect(Reflect.get(inserted, PlanEntity.START_DATE) as number).assertEqual(1728000000);
      expect(Reflect.get(inserted, PlanEntity.ENABLE_AUTO_AMAP_ROUTE) as number).assertEqual(1);
    });

    it('boundary: plan_repository_mark_plan_dirty_should_ignore_non_positive_and_non_finite_ids', 0, () => {
      // Arrange
      clearDirtyPoolForAB();
      // Act
      PlanRepositoryImpl.markPlanDirty(0);
      PlanRepositoryImpl.markPlanDirty(-1);
      PlanRepositoryImpl.markPlanDirty(Number.NaN);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(dirty.length).assertEqual(0);
    });

    it('invalid: plan_repository_create_plan_should_return_minus_one_when_insert_throws', 0, async () => {
      // Arrange
      clearDirtyPoolForAB();
      const store = new FakeRdbStoreForAB();
      store.insertShouldThrow = true;
      const hooks = new StaticHooksForAB();
      hooks.setGetInstance((): Object => createHelperInstanceForAB(store as Object));
      // Act
      const rowId = await PlanRepositoryImpl.createPlan('batch_ab_failed', 1);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(rowId).assertEqual(-1);
      expect(store.insertCount).assertEqual(1);
      expect(dirty.length).assertEqual(0);
    });

    it('conflict: plan_repository_update_auto_amap_route_should_throw_when_update_fails', 0, async () => {
      // Arrange
      clearDirtyPoolForAB();
      const store = new FakeRdbStoreForAB();
      store.updateShouldThrow = true;
      const hooks = new StaticHooksForAB();
      hooks.setGetInstance((): Object => createHelperInstanceForAB(store as Object));
      let thrown = '';
      // Act
      try {
        await PlanRepositoryImpl.updateAutoAmapRoute(19, true);
      } catch (err) {
        const e = err as Error;
        thrown = e.message;
      }
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(thrown).assertEqual('update_failed_ab');
      expect(store.updateCount).assertEqual(1);
      expect(dirty.length).assertEqual(0);
    });

    it('regression: td-20260415-save-ai-context-should-persist-fields-without-dirty-flag', 0, async () => {
      // Arrange
      clearDirtyPoolForAB();
      const store = new FakeRdbStoreForAB();
      const hooks = new StaticHooksForAB();
      hooks.setGetInstance((): Object => createHelperInstanceForAB(store as Object));
      // Act
      await PlanRepositoryImpl.saveAiContext(23, 'prompt_ab', 'explain_ab');
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(1);
      const updateValue = store.updateValueBuckets[0] as Object;
      expect(Reflect.get(updateValue, PlanEntity.LAST_AI_PROMPT) as string).assertEqual('prompt_ab');
      expect(Reflect.get(updateValue, PlanEntity.LAST_STRATEGY_EXPLANATION) as string).assertEqual('explain_ab');
      expect(dirty.length).assertEqual(0);
    });

    it('combined: plan_repository_update_auto_amap_route_should_cover_true_and_false_value_bucket_paths', 0, async () => {
      // Arrange
      clearDirtyPoolForAB();
      const store = new FakeRdbStoreForAB();
      const hooks = new StaticHooksForAB();
      hooks.setGetInstance((): Object => createHelperInstanceForAB(store as Object));
      // Act
      await PlanRepositoryImpl.updateAutoAmapRoute(41, true);
      await PlanRepositoryImpl.updateAutoAmapRoute(42, false);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      hooks.restore();
      // Assert
      expect(store.updateCount).assertEqual(2);
      const firstBucket = store.updateValueBuckets[0] as Object;
      const secondBucket = store.updateValueBuckets[1] as Object;
      expect(Reflect.get(firstBucket, PlanEntity.ENABLE_AUTO_AMAP_ROUTE) as number).assertEqual(1);
      expect(Reflect.get(secondBucket, PlanEntity.ENABLE_AUTO_AMAP_ROUTE) as number).assertEqual(0);
      expect(dirty.length).assertEqual(2);
      expect(dirty[0]).assertEqual(41);
      expect(dirty[1]).assertEqual(42);
    });
  });
}

