// 璺緞: ets/model/entity/PlanRepositoryImpl.ets

import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { RdbHelper } from '../../common/utils/RdbHelper';
import { PlanEntity } from '../../model/entity/PlanEntity';
import { EventEntity } from '../../model/entity/EventEntity';

export interface PlanItem {
  id: number;
  title: string; // 瀵瑰杩樻槸鍙?title锛屾柟渚?UI 缁戝畾锛屽唴閮ㄦ槧灏勫埌 DB 鐨?name
  createdAt: number;
  startDate?: number; // [鏂板]
  status?: number;    // [新增] 0:规划, 2:归档
  delFlag?: number;
  deleteTime?: number; // [淇敼鐐?1] 鏂板 deleteTime 瀛楁
  enableAutoAmapRoute?: number;
  strategyMode?: number;
  lastAiPrompt?: string;
  lastStrategyExplanation?: string;
}

interface PlanPageWindow {
  offset: number;
  limit: number;
}

export class PlanRepositoryImpl {
  private static dirtyPlanIds: Set<number> = new Set<number>();

  private static async clearActiveRuntimeEventsForPlan(
    rdbStore: relationalStore.RdbStore,
    planId: number
  ): Promise<void> {
    const runtimeReset: ValuesBucket = {};
    runtimeReset[EventEntity.ACTUAL_START_TIME] = 0;
    runtimeReset[EventEntity.ACTUAL_END_TIME] = 0;
    runtimeReset[EventEntity.COMPLETION_STATUS] = EventEntity.STATE_PENDING;

    const predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
    predicates.equalTo(EventEntity.PLAN_ID, planId)
      .and()
      .equalTo(EventEntity.STATUS, 1)
      .and()
      .equalTo(EventEntity.COMPLETION_STATUS, EventEntity.STATE_PENDING)
      .and()
      .greaterThan(EventEntity.ACTUAL_START_TIME, 0)
      .and()
      .lessThanOrEqualTo(EventEntity.ACTUAL_END_TIME, 0);

    await rdbStore.update(runtimeReset, predicates);
  }

  private static normalizePage(offset: number, limit: number): PlanPageWindow {
    const safeOffset = Number.isFinite(offset) && offset > 0 ? Math.floor(offset) : 0;
    let safeLimit = Number.isFinite(limit) ? Math.floor(limit) : 40;
    if (safeLimit < 1) {
      safeLimit = 1;
    } else if (safeLimit > 200) {
      safeLimit = 200;
    }
    const window: PlanPageWindow = { offset: safeOffset, limit: safeLimit };
    return window;
  }

  public static markPlanDirty(planId: number): void {
    if (Number.isFinite(planId) && planId > 0) {
      PlanRepositoryImpl.dirtyPlanIds.add(planId);
    }
  }

  public static consumeDirtyPlanIds(): number[] {
    const ids = Array.from<number>(PlanRepositoryImpl.dirtyPlanIds.values());
    PlanRepositoryImpl.dirtyPlanIds.clear();
    return ids;
  }

  /**
   * 鍒涘缓鏂拌鍒?
   * [Phase 2 淇敼] 澧炲姞 startDate 鍙傛暟
   */
  public static async createPlan(title: string, startDate: number): Promise<number> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return -1;

    try {
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.NAME] = title;
      valueBucket[PlanEntity.CREATED_AT] = new Date().getTime();

      // 鉁?[Phase 2] 浣跨敤鐢ㄦ埛閫夋嫨鐨勬棩鏈?
      valueBucket[PlanEntity.START_DATE] = startDate;

      valueBucket[PlanEntity.STATUS] = 0; // 瑙勫垝涓?
      valueBucket[PlanEntity.DEL_FLAG] = 0; // 鏈垹闄?
      valueBucket[PlanEntity.ENABLE_AUTO_AMAP_ROUTE] = 1;

      const rowId = await rdbStore.insert(PlanEntity.TABLE_NAME, valueBucket);
      PlanRepositoryImpl.markPlanDirty(rowId);
      return rowId;
    } catch (err) {
      console.error(`[PlanDao] createPlan failed: ${JSON.stringify(err)}`);
      return -1;
    }
  }

  /**
   * [鏂板] 鏍规嵁 ID 鑾峰彇鍗曚釜璁″垝璇︽儏
   * 浣滅敤锛歍imelineViewModel 闇€瑕佽鍙?startDate
   */
  public static async getPlanById(id: number): Promise<PlanItem | undefined> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return undefined;

    try {
      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      let resultSet = await rdbStore.query(predicates);
      let result: PlanItem | undefined = undefined;
      try {
        if (resultSet.goToFirstRow()) {
          result = {
            id: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.ID)),
            title: resultSet.getString(resultSet.getColumnIndex(PlanEntity.NAME)),
            createdAt: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.CREATED_AT)),
            // [鍏抽敭] 鑾峰彇 startDate
            startDate: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.START_DATE)),
            status: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.STATUS)),
            delFlag: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.DEL_FLAG)),
            enableAutoAmapRoute: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.ENABLE_AUTO_AMAP_ROUTE)),
            strategyMode: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.STRATEGY_MODE)),
            lastAiPrompt: resultSet.getString(resultSet.getColumnIndex(PlanEntity.LAST_AI_PROMPT)),
            lastStrategyExplanation: resultSet.getString(resultSet.getColumnIndex(PlanEntity.LAST_STRATEGY_EXPLANATION))
          };
        }
      } finally {
        resultSet.close();
      }
      return result;
    } catch (err) {
      console.error(`[PlanDao] getPlanById failed: ${JSON.stringify(err)}`);
      return undefined;
    }
  }

  /**
   * [渚ц竟鏍忓姛鑳絔 鑾峰彇鍥炴敹绔欒鍒?(del_flag = 1)
   */
  public static async getTrashPlans(): Promise<PlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.DEL_FLAG, 1); // 鏌ュ凡鍒犻櫎
      predicates.orderByDesc(PlanEntity.DELETE_TIME); // 鎸夊垹闄ゆ椂闂村€掑簭

      let resultSet = await rdbStore.query(predicates);
      return PlanRepositoryImpl.parseResultSet(resultSet);
    } catch (err) {
      console.error(`[PlanDao] getTrashPlans failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * [渚ц竟鏍忓姛鑳絔 鑾峰彇褰掓。璁″垝 (status = 2 && del_flag = 0)
   */
  public static async getArchivedPlans(): Promise<PlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.DEL_FLAG, 0);
      predicates.equalTo(PlanEntity.STATUS, 2); // 鏌ュ綊妗ｇ姸鎬?
      predicates.orderByDesc(PlanEntity.CREATED_AT);

      let resultSet = await rdbStore.query(predicates);
      return PlanRepositoryImpl.parseResultSet(resultSet);
    } catch (err) {
      console.error(`[PlanDao] getArchivedPlans failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * [渚ц竟鏍忓姛鑳絔 杩樺師璁″垝 (浠庡洖鏀剁珯鎭㈠)
   */
  public static async restorePlan(id: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.DEL_FLAG] = 0; // 鎭㈠姝ｅ父
      valueBucket[PlanEntity.DELETE_TIME] = 0;

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      await rdbStore.update(valueBucket, predicates);
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      console.error(`[PlanDao] restorePlan failed: ${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`restore_plan_failed:${JSON.stringify(err)}`);
    }
  }

  /**
   * [渚ц竟鏍忓姛鑳絔 褰诲簳鍒犻櫎 (鐗╃悊鍒犻櫎)
   */
  public static async hardDeletePlan(id: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;
    try {
      rdbStore.beginTransaction();

      let eventPredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      eventPredicates.equalTo(EventEntity.PLAN_ID, id);
      await rdbStore.delete(eventPredicates);

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);
      await rdbStore.delete(predicates);

      rdbStore.commit();
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      try {
        rdbStore.rollBack();
      } catch (_rollbackErr) {
      }
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`hard_delete_plan_failed:${JSON.stringify(err)}`);
    }
  }

  // --- 鍐呴儴杈呭姪锛氶伩鍏嶉噸澶嶅啓瑙ｆ瀽浠ｇ爜 ---
  private static parseResultSet(resultSet: relationalStore.ResultSet): PlanItem[] {
    let resultList: PlanItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        resultList.push({
          id: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.ID)),
          title: resultSet.getString(resultSet.getColumnIndex(PlanEntity.NAME)),
          createdAt: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.CREATED_AT)),
          startDate: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.START_DATE)),
          status: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.STATUS)),
          delFlag: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.DEL_FLAG)),
          deleteTime: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.DELETE_TIME)),
          enableAutoAmapRoute: resultSet.getLong(resultSet.getColumnIndex(PlanEntity.ENABLE_AUTO_AMAP_ROUTE))
        });
      }
    } catch (err) {
      console.error(`[PlanDao] parseResultSet failed: ${JSON.stringify(err)}`);
      resultList = [];
    } finally {
      try {
        resultSet.close();
      } catch (_closeErr) {
      }
    }
    return resultList;
  }

  /**
   * [Phase 2 鏂板] 鏇存柊璁″垝鐘舵€?
   * 浣滅敤锛氱敤浜?褰掓。(2) 鎴?閲嶆柊婵€娲?0)
   */
  public static async updatePlanStatus(id: number, status: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      rdbStore.beginTransaction();
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.STATUS] = status;

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      await rdbStore.update(valueBucket, predicates);
      if (status === 2) {
        await PlanRepositoryImpl.clearActiveRuntimeEventsForPlan(rdbStore, id);
      }
      rdbStore.commit();
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      try {
        rdbStore.rollBack();
      } catch (_rollbackErr) {
      }
      console.error(`[PlanDao] updatePlanStatus failed: ${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`update_plan_status_failed:${JSON.stringify(err)}`);
    }
  }

  /**
   * 鑾峰彇鎵€鏈夎鍒掑垪琛?(榛樿鍙煡鏈垹闄ょ殑)
   */
  public static async getPlanList(): Promise<PlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      // 鍙煡璇㈡湭鍒犻櫎鐨?
      predicates.equalTo(PlanEntity.DEL_FLAG, 0);
      predicates.orderByDesc(PlanEntity.CREATED_AT);

      let resultSet = await rdbStore.query(predicates);

      // 鉁?[淇敼] 鐩存帴璋冪敤 parseResultSet 澶嶇敤閫昏緫锛屼唬鐮佹洿绮剧畝
      return PlanRepositoryImpl.parseResultSet(resultSet);
    } catch (err) {
      console.error(`[PlanDao] getPlanList failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * [Day 3.5 鏂板] 妯＄硦鎼滅储璁″垝
   * 浣滅敤锛氬湪涓婚〉鎼滅储妗嗚緭鍏ュ叧閿瘝锛岃繃婊ゆ樉绀?
   */
  public static async searchPlans(keyword: string): Promise<PlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.DEL_FLAG, 0); // 鍙兘鎼滄湭鍒犻櫎鐨?
      predicates.like(PlanEntity.NAME, `%${keyword}%`); // 妯＄硦鍖归厤
      predicates.orderByDesc(PlanEntity.CREATED_AT);

      let resultSet = await rdbStore.query(predicates);
      return PlanRepositoryImpl.parseResultSet(resultSet);
    } catch (err) {
      console.error(`[PlanDao] searchPlans failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  public static async searchTrashPlans(keyword: string): Promise<PlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.DEL_FLAG, 1);
      predicates.like(PlanEntity.NAME, `%${keyword}%`);
      predicates.orderByDesc(PlanEntity.DELETE_TIME);

      let resultSet = await rdbStore.query(predicates);
      return PlanRepositoryImpl.parseResultSet(resultSet);
    } catch (err) {
      console.error(`[PlanDao] searchTrashPlans failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  public static async searchAllPlansPaged(keyword: string, offset: number, limit: number): Promise<PlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      const page = PlanRepositoryImpl.normalizePage(offset, limit);
      const trimmed = (keyword || '').trim();

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      if (trimmed.length > 0) {
        predicates.like(PlanEntity.NAME, `%${trimmed}%`);
      }
      predicates.orderByDesc(PlanEntity.CREATED_AT);
      predicates.limitAs(page.limit);
      predicates.offsetAs(page.offset);

      let resultSet = await rdbStore.query(predicates);
      return PlanRepositoryImpl.parseResultSet(resultSet);
    } catch (err) {
      console.error(`[PlanDao] searchAllPlansPaged failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * [Day 3.5 鏂板] 杞垹闄よ鍒?(杩涘叆鍥炴敹绔?
   */
  public static async softDeletePlan(id: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      rdbStore.beginTransaction();
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.DEL_FLAG] = 1; // 鏍囪涓哄垹闄?
      valueBucket[PlanEntity.DELETE_TIME] = new Date().getTime(); // 璁板綍鍒犻櫎鏃堕棿

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      await rdbStore.update(valueBucket, predicates);
      await PlanRepositoryImpl.clearActiveRuntimeEventsForPlan(rdbStore, id);
      rdbStore.commit();
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      try {
        rdbStore.rollBack();
      } catch (_rollbackErr) {
      }
      console.error(`[PlanDao] softDeletePlan failed: ${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`soft_delete_plan_failed:${JSON.stringify(err)}`);
    }
  }

  /**
   * [Priority 4 鏂板] 鏇存柊璁″垝鍑哄彂鏃ユ湡
   */
  public static async updateStartDate(id: number, date: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.START_DATE] = date;

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      await rdbStore.update(valueBucket, predicates);
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      console.error(`[PlanDao] updateStartDate failed: ${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`update_start_date_failed:${JSON.stringify(err)}`);
    }
  }
  /**
   * [Priority 2 鏂板] 鏇存柊璁″垝鍚嶇О
   */
  public static async updatePlanName(id: number, name: string): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.NAME] = name;

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      await rdbStore.update(valueBucket, predicates);
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      console.error(`[PlanDao] updatePlanName failed: ${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`update_plan_name_failed:${JSON.stringify(err)}`);
    }
  }

  public static async updateAutoAmapRoute(id: number, enabled: boolean): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      const valueBucket: ValuesBucket = {};
      valueBucket[PlanEntity.ENABLE_AUTO_AMAP_ROUTE] = enabled ? 1 : 0;

      let predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, id);

      await rdbStore.update(valueBucket, predicates);
      PlanRepositoryImpl.markPlanDirty(id);
    } catch (err) {
      console.error(`[PlanDao] updateAutoAmapRoute failed: ${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`update_auto_amap_route_failed:${JSON.stringify(err)}`);
    }
  }
  // --- 鍦?PlanDao 绫诲唴閮ㄦ坊鍔?---

  /**
   * [V5.0 鏂板] 鐗╃悊娓呯悊瓒呰繃 7 澶╃殑搴熷純璁″垝
   * 寤鸿鍦?App 鍚姩鏃堕€氳繃 Worker 鎴栧欢鏃惰皟鐢?
   * @returns 鍒犻櫎鐨勮鏁?
   */
  public static async purgeOldTrash(): Promise<number> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return 0;

    // 1. 璁＄畻鎴鏃堕棿 (褰撳墠鏃堕棿 - 7澶?
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    const limitTime = new Date().getTime() - sevenDaysMs;

    try {
      // 2. 先查待清理计划 id，再级联清理 events + plans
      let queryPredicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      queryPredicates.equalTo(PlanEntity.DEL_FLAG, 1)
        .and()
        .lessThanOrEqualTo(PlanEntity.DELETE_TIME, limitTime);
      const resultSet = await rdbStore.query(queryPredicates);
      const planIds: number[] = [];
      try {
        while (resultSet.goToNextRow()) {
          planIds.push(resultSet.getLong(resultSet.getColumnIndex(PlanEntity.ID)));
        }
      } finally {
        resultSet.close();
      }
      if (planIds.length === 0) {
        return 0;
      }

      rdbStore.beginTransaction();
      for (let i = 0; i < planIds.length; i++) {
        const planId = planIds[i];
        let eventPredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
        eventPredicates.equalTo(EventEntity.PLAN_ID, planId);
        await rdbStore.delete(eventPredicates);
        PlanRepositoryImpl.markPlanDirty(planId);
      }
      let deletePlanPredicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      deletePlanPredicates.equalTo(PlanEntity.DEL_FLAG, 1)
        .and()
        .lessThanOrEqualTo(PlanEntity.DELETE_TIME, limitTime);
      const deletedRows = await rdbStore.delete(deletePlanPredicates);
      rdbStore.commit();
      if (deletedRows > 0) {
        console.info(`[PlanDao] Auto-purged ${deletedRows} expired plans.`);
      }
      return deletedRows;
    } catch (err) {
      try {
        rdbStore.rollBack();
      } catch (_rollbackErr) {
      }
      console.error(`[PlanDao] Purge error: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  public static async updateStrategyMode(id: number, mode: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    const valueBucket: ValuesBucket = {};
    valueBucket[PlanEntity.STRATEGY_MODE] = mode;
    valueBucket[PlanEntity.STRATEGY_VERSION] = 1;

    const predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
    predicates.equalTo(PlanEntity.ID, id);

    await rdbStore.update(valueBucket, predicates);
    PlanRepositoryImpl.markPlanDirty(id);
  }

  public static async saveAiContext(
    id: number,
    prompt: string,
    explanation: string
  ): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    const valueBucket: ValuesBucket = {};
    valueBucket[PlanEntity.LAST_AI_PROMPT] = prompt;
    valueBucket[PlanEntity.LAST_STRATEGY_EXPLANATION] = explanation;

    const predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
    predicates.equalTo(PlanEntity.ID, id);

    await rdbStore.update(valueBucket, predicates);
  }
}


