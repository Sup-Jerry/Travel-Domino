import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { PlanEntity } from '../main/ets/model/entity/PlanEntity';

class PageWindowForX {
  offset: number = 0;
  limit: number = 0;
}

class FakeResultSetForX {
  private readonly rows: Array<Map<string, number | string>>;
  private cursor: number = -1;
  closeCount: number = 0;

  constructor(rows: Array<Map<string, number | string>>) {
    this.rows = rows;
  }

  goToNextRow(): boolean {
    this.cursor++;
    return this.cursor < this.rows.length;
  }

  getColumnIndex(name: string): number {
    if (name === PlanEntity.ID) { return 1; }
    if (name === PlanEntity.NAME) { return 2; }
    if (name === PlanEntity.CREATED_AT) { return 3; }
    if (name === PlanEntity.START_DATE) { return 4; }
    if (name === PlanEntity.STATUS) { return 5; }
    if (name === PlanEntity.DEL_FLAG) { return 6; }
    if (name === PlanEntity.DELETE_TIME) { return 7; }
    if (name === PlanEntity.ENABLE_AUTO_AMAP_ROUTE) { return 8; }
    if (name === PlanEntity.STRATEGY_MODE) { return 9; }
    if (name === PlanEntity.STRATEGY_VERSION) { return 10; }
    if (name === PlanEntity.LAST_AI_PROMPT) { return 11; }
    if (name === PlanEntity.LAST_STRATEGY_EXPLANATION) { return 12; }
    if (name === PlanEntity.STRATEGY_DENSITY) { return 13; }
    if (name === PlanEntity.STRATEGY_PACE) { return 14; }
    if (name === PlanEntity.STRATEGY_PREFERENCE) { return 15; }
    if (name === PlanEntity.STRATEGY_ENERGY) { return 16; }
    return -1;
  }

  getLong(index: number): number {
    const row = this.rows[this.cursor];
    if (index === 1) { return row.get(PlanEntity.ID) as number; }
    if (index === 3) { return row.get(PlanEntity.CREATED_AT) as number; }
    if (index === 4) { return row.get(PlanEntity.START_DATE) as number; }
    if (index === 5) { return row.get(PlanEntity.STATUS) as number; }
    if (index === 6) { return row.get(PlanEntity.DEL_FLAG) as number; }
    if (index === 7) { return row.get(PlanEntity.DELETE_TIME) as number; }
    if (index === 8) { return row.get(PlanEntity.ENABLE_AUTO_AMAP_ROUTE) as number; }
    if (index === 9) { return row.get(PlanEntity.STRATEGY_MODE) as number; }
    if (index === 10) { return row.get(PlanEntity.STRATEGY_VERSION) as number; }
    if (index === 13) { return row.get(PlanEntity.STRATEGY_DENSITY) as number; }
    if (index === 14) { return row.get(PlanEntity.STRATEGY_PACE) as number; }
    if (index === 15) { return row.get(PlanEntity.STRATEGY_PREFERENCE) as number; }
    if (index === 16) { return row.get(PlanEntity.STRATEGY_ENERGY) as number; }
    return 0;
  }

  getString(index: number): string {
    const row = this.rows[this.cursor];
    if (index === 2) { return row.get(PlanEntity.NAME) as string; }
    if (index === 11) { return row.get(PlanEntity.LAST_AI_PROMPT) as string; }
    if (index === 12) { return row.get(PlanEntity.LAST_STRATEGY_EXPLANATION) as string; }
    return '';
  }

  close(): void {
    this.closeCount++;
  }
}

class BrokenResultSetForX {
  closeCount: number = 0;

  goToNextRow(): boolean {
    throw new Error('broken_result_set');
  }

  close(): void {
    this.closeCount++;
  }
}

function getPrivateNormalizePageForX(): (offset: number, limit: number) => PageWindowForX {
  return Reflect.get(PlanRepositoryImpl as Object, 'normalizePage') as (offset: number, limit: number) => PageWindowForX;
}

function getPrivateParseResultSetForX(): (resultSet: Object) => Object[] {
  return Reflect.get(PlanRepositoryImpl as Object, 'parseResultSet') as (resultSet: Object) => Object[];
}

function clearDirtyPoolForX(): void {
  PlanRepositoryImpl.consumeDirtyPlanIds();
}

export default function phase2CoreCoverageBatchXTest() {
  describe('phase2CoreCoverageBatchXTest', () => {
    it('normal: plan_repository_parse_result_set_should_map_row_fields_and_close_result_set', 0, () => {
      // Arrange
      clearDirtyPoolForX();
      const row = new Map<string, number | string>();
      row.set(PlanEntity.ID, 1);
      row.set(PlanEntity.NAME, 'plan_x');
      row.set(PlanEntity.CREATED_AT, 1000);
      row.set(PlanEntity.START_DATE, 2000);
      row.set(PlanEntity.STATUS, 0);
      row.set(PlanEntity.DEL_FLAG, 0);
      row.set(PlanEntity.DELETE_TIME, 0);
      row.set(PlanEntity.ENABLE_AUTO_AMAP_ROUTE, 1);
      row.set(PlanEntity.STRATEGY_MODE, 2);
      row.set(PlanEntity.STRATEGY_VERSION, 1);
      row.set(PlanEntity.LAST_AI_PROMPT, 'prompt_x');
      row.set(PlanEntity.LAST_STRATEGY_EXPLANATION, 'exp_x');
      row.set(PlanEntity.STRATEGY_DENSITY, 1);
      row.set(PlanEntity.STRATEGY_PACE, 2);
      row.set(PlanEntity.STRATEGY_PREFERENCE, 3);
      row.set(PlanEntity.STRATEGY_ENERGY, 4);
      const rs = new FakeResultSetForX([row]);
      const parse = getPrivateParseResultSetForX();
      // Act
      const result = parse(rs as Object);
      // Assert
      expect(result.length).assertEqual(1);
      const first = result[0] as Map<string, number | string> | Object;
      expect(Reflect.get(first as Object, 'id') as number).assertEqual(1);
      expect(Reflect.get(first as Object, 'title') as string).assertEqual('plan_x');
      expect(rs.closeCount).assertEqual(1);
    });

    it('boundary: plan_repository_normalize_page_should_clamp_offset_and_limit_into_safe_window', 0, () => {
      // Arrange
      const normalize = getPrivateNormalizePageForX();
      // Act
      const low = normalize(-10, 0);
      const high = normalize(11.8, 999);
      // Assert
      expect(low.offset).assertEqual(0);
      expect(low.limit).assertEqual(1);
      expect(high.offset).assertEqual(11);
      expect(high.limit).assertEqual(200);
    });

    it('invalid: plan_repository_create_plan_should_return_negative_one_when_rdb_not_initialized', 0, async () => {
      // Arrange
      clearDirtyPoolForX();
      // Act
      const id = await PlanRepositoryImpl.createPlan('x', Date.now());
      // Assert
      expect(id).assertEqual(-1);
    });

    it('conflict: plan_repository_mark_plan_dirty_should_ignore_non_positive_and_keep_unique_positive_ids', 0, () => {
      // Arrange
      clearDirtyPoolForX();
      // Act
      PlanRepositoryImpl.markPlanDirty(-1);
      PlanRepositoryImpl.markPlanDirty(0);
      PlanRepositoryImpl.markPlanDirty(7);
      PlanRepositoryImpl.markPlanDirty(7);
      const ids = PlanRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual(7);
    });

    it('regression: td-20260415-consume-dirty-plan-ids-should-clear_pool_between_calls', 0, () => {
      // Arrange
      clearDirtyPoolForX();
      PlanRepositoryImpl.markPlanDirty(101);
      // Act
      const first = PlanRepositoryImpl.consumeDirtyPlanIds();
      const second = PlanRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(first.length).assertEqual(1);
      expect(first[0]).assertEqual(101);
      expect(second.length).assertEqual(0);
    });

    it('combined: plan_repository_parse_failure_and_null_store_paths_should_return_safe_defaults_without_throw', 0, async () => {
      // Arrange
      const broken = new BrokenResultSetForX();
      const parse = getPrivateParseResultSetForX();
      // Act
      const parsed = parse(broken as Object);
      const list = await PlanRepositoryImpl.getPlanList();
      const trash = await PlanRepositoryImpl.getTrashPlans();
      const archived = await PlanRepositoryImpl.getArchivedPlans();
      const searched = await PlanRepositoryImpl.searchAllPlansPaged('  x  ', -1, 500);
      // Assert
      expect(parsed.length).assertEqual(0);
      expect(broken.closeCount).assertEqual(1);
      expect(list.length).assertEqual(0);
      expect(trash.length).assertEqual(0);
      expect(archived.length).assertEqual(0);
      expect(searched.length).assertEqual(0);
    });
  });
}
