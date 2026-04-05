// Repository实现：事件数据持久化

import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { RdbHelper } from '../../common/utils/RdbHelper';
import { EventEntity } from '../../model/entity/EventEntity';
import { PlanEntity } from '../../model/entity/PlanEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type {
  EventFieldUpdate,
  RuntimeTransitionType,
  RuntimeTransitionInput,
  RuntimeTransitionResult,
  ActiveEventSnapshot
} from '../../domain/ports/IEventRepository';

const TAG = 'EventRepositoryImpl';

export class EventRepositoryImpl {
  private static dirtyPlanIds: Set<number> = new Set<number>();

  public static markPlanDirty(planId: number): void {
    if (Number.isFinite(planId) && planId > 0) {
      EventRepositoryImpl.dirtyPlanIds.add(planId);
    }
  }

  public static consumeDirtyPlanIds(): number[] {
    const ids = Array.from<number>(EventRepositoryImpl.dirtyPlanIds.values());
    EventRepositoryImpl.dirtyPlanIds.clear();
    return ids;
  }

  private static async resolvePlanIdByEventId(eventId: number): Promise<number> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore || eventId <= 0) {
      return -1;
    }
    try {
      let predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      predicates.equalTo(EventEntity.ID, eventId);
      const resultSet = await rdbStore.query(predicates);
      try {
        if (!resultSet.goToFirstRow()) {
          return -1;
        }
        return resultSet.getLong(resultSet.getColumnIndex(EventEntity.PLAN_ID));
      } finally {
        resultSet.close();
      }
    } catch (err) {
      hilog.warn(0x0000, TAG, `[resolvePlanIdByEventId] failed eventId=${eventId}, err=${JSON.stringify(err)}`);
      return -1;
    }
  }

  private static previewIds(ids: number[], limit: number = 20): string {
    if (ids.length === 0) {
      return '[]';
    }
    const head = ids.slice(0, limit).join(',');
    const suffix = ids.length > limit ? `...(+${ids.length - limit})` : '';
    return `[${head}]${suffix}`;
  }

  private static previewName(name: string, limit: number = 16): string {
    if (!name) {
      return '';
    }
    return name.length > limit ? `${name.slice(0, limit)}...` : name;
  }

  private static async isPlanUsableForRuntime(rdbStore: relationalStore.RdbStore, planId: number): Promise<boolean> {
    if (!Number.isFinite(planId) || planId <= 0) {
      return false;
    }
    try {
      const predicates = new relationalStore.RdbPredicates(PlanEntity.TABLE_NAME);
      predicates.equalTo(PlanEntity.ID, planId);
      const resultSet = await rdbStore.query(predicates);
      try {
        if (!resultSet.goToFirstRow()) {
          return false;
        }
        const delFlag = resultSet.getLong(resultSet.getColumnIndex(PlanEntity.DEL_FLAG));
        const status = resultSet.getLong(resultSet.getColumnIndex(PlanEntity.STATUS));
        return delFlag !== 1 && status !== 2;
      } finally {
        resultSet.close();
      }
    } catch (_err) {
      return false;
    }
  }

  /**
   * [Day 3 鍗囩骇] 鍗曟潯鎻掑叆锛岃繑鍥?ID
   * 鍖呭惈 V2.0 鎵€鏈夋柊瀛楁
   */
  public static async insertEvent(planId: number, item: TravelPlanItem): Promise<number> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return -1;

    try {
      const valueBucket: ValuesBucket = {};
      valueBucket[EventEntity.PLAN_ID] = planId;

    // 鍘熸湁瀛楁...
    valueBucket[EventEntity.NAME] = item.name;
    valueBucket[EventEntity.TRAVEL_MODE] = item.travelMode ?? 0;
    valueBucket[EventEntity.NOTE] = item.note || '';
    valueBucket[EventEntity.DURATION] = item.duration;
    valueBucket[EventEntity.STATUS] = (item.status === undefined) ? 0 : item.status;
    valueBucket[EventEntity.LOCK_STATUS] = item.lockStatus || 0;
    valueBucket[EventEntity.FIXED_START_TIME] = item.fixedStartTime || null;
    valueBucket[EventEntity.DAY_OFFSET] = item.dayOffset || 0;
    valueBucket[EventEntity.SORT_ORDER] = item.sortOrder;
    valueBucket[EventEntity.TYPE] = item.itemType || 0;
    valueBucket[EventEntity.PRIORITY] = item.priority || 0;
    valueBucket[EventEntity.PRE_TRAVEL_MINUTES] = item.preTravelMinutes || 0;
    valueBucket[EventEntity.IS_TRAVEL_MANUAL] = item.isTravelManual || 0;
    valueBucket[EventEntity.LATITUDE] = item.latitude || 0;
    valueBucket[EventEntity.LONGITUDE] = item.longitude || 0;
    valueBucket[EventEntity.SOURCE] = item.source || 0;

    // --- [Round 3 琛ュ叏] ---
    valueBucket[EventEntity.ADDRESS] = item.address || '';
    valueBucket[EventEntity.AI_REASONING] = item.aiReasoning || '';
    valueBucket[EventEntity.GROUP_ID] = item.groupId || 0;
    valueBucket[EventEntity.DEL_FLAG] = item.delFlag || 0;
    valueBucket[EventEntity.DELETE_TIME] = 0; // 榛樿涓?
    valueBucket[EventEntity.ACTUAL_START_TIME] = item.actualStartTime || 0;
    valueBucket[EventEntity.ACTUAL_END_TIME] = item.actualEndTime || 0;
    valueBucket[EventEntity.COMPLETION_STATUS] = item.completionStatus || 0;
    valueBucket[EventEntity.WEATHER_CONDITION] = item.weatherCondition || '';
    valueBucket[EventEntity.WEATHER_TEMPERATURE] = item.weatherTemperature || 0;
    valueBucket[EventEntity.WEATHER_TEXT] = item.weatherText || '';
    valueBucket[EventEntity.WEATHER_FETCH_TIME] = item.weatherFetchTime || 0;

      const rowId = await rdbStore.insert(EventEntity.TABLE_NAME, valueBucket);
      EventRepositoryImpl.markPlanDirty(planId);
      return rowId;
    } catch (err) {
      hilog.error(0x0000, TAG, `[insertEvent] failed planId=${planId}, err=${JSON.stringify(err)}`);
      return -1;
    }
  }

  /**
   * [Day 3 鍗囩骇] 鍏ㄩ噺淇濆瓨 (鐢ㄤ簬閲嶆帓/杩佺Щ)
   */
  public static async saveAllEvents(planId: number, events: TravelPlanItem[]): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      const inputIds = events.map((item) => item.id || -1);
      hilog.info(0x0000, TAG,
        `[ID_FIX][SAVE_BEGIN] planId=${planId} count=${events.length} ids=${EventRepositoryImpl.previewIds(inputIds)}`);

      rdbStore.beginTransaction();

      // 1. 有 id 优先更新，避免 delete+insert 触发主键漂移
      const persistedIds: Set<number> = new Set<number>();
      let updatedCount = 0;
      let insertedNewCount = 0;
      let recoveredInsertCount = 0;
      const newInsertMappings: string[] = [];

      for (let i = 0; i < events.length; i++) {
        const item = events[i];

        let valueBucket: ValuesBucket = {};
        valueBucket[EventEntity.PLAN_ID] = planId;
        valueBucket[EventEntity.NAME] = item.name;
        valueBucket[EventEntity.NOTE] = item.note || '';
        valueBucket[EventEntity.DURATION] = item.duration;
        valueBucket[EventEntity.TRAVEL_MODE] = item.travelMode ?? 0;
        valueBucket[EventEntity.PRE_TRAVEL_MINUTES] = item.preTravelMinutes || 0;
        valueBucket[EventEntity.IS_TRAVEL_MANUAL] = item.isTravelManual || 0;
        valueBucket[EventEntity.SORT_ORDER] = item.sortOrder;
        valueBucket[EventEntity.STATUS] = (item.status === undefined) ? 1 : item.status;
        valueBucket[EventEntity.LOCK_STATUS] = item.lockStatus || 0;
        valueBucket[EventEntity.FIXED_START_TIME] = item.fixedStartTime || null;
        valueBucket[EventEntity.DAY_OFFSET] = item.dayOffset || 0;
        valueBucket[EventEntity.TYPE] = item.itemType || 0;
        valueBucket[EventEntity.PRIORITY] = item.priority || 0;
        valueBucket[EventEntity.LATITUDE] = item.latitude || 0;
        valueBucket[EventEntity.LONGITUDE] = item.longitude || 0;
        valueBucket[EventEntity.SOURCE] = item.source || 0;
        valueBucket[EventEntity.ADDRESS] = item.address || '';
        valueBucket[EventEntity.AI_REASONING] = item.aiReasoning || '';
        valueBucket[EventEntity.GROUP_ID] = item.groupId || 0;
        valueBucket[EventEntity.DEL_FLAG] = item.delFlag || 0;
        valueBucket[EventEntity.DELETE_TIME] = 0;
        valueBucket[EventEntity.ACTUAL_START_TIME] = item.actualStartTime || 0;
        valueBucket[EventEntity.ACTUAL_END_TIME] = item.actualEndTime || 0;
        valueBucket[EventEntity.COMPLETION_STATUS] = item.completionStatus || 0;
        valueBucket[EventEntity.WEATHER_CONDITION] = item.weatherCondition || '';
        valueBucket[EventEntity.WEATHER_TEMPERATURE] = item.weatherTemperature || 0;
        valueBucket[EventEntity.WEATHER_TEXT] = item.weatherText || '';
        valueBucket[EventEntity.WEATHER_FETCH_TIME] = item.weatherFetchTime || 0;

        let persistedId = 0;
        if (item.id && item.id > 0) {
          let updatePredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
          updatePredicates.equalTo(EventEntity.ID, item.id);
          const changedRows = await rdbStore.update(valueBucket, updatePredicates);

          if (changedRows > 0) {
            persistedId = item.id;
            updatedCount += 1;
            hilog.info(0x0000, TAG,
              `[ID_FIX][KEEP_ID] idx=${i} id=${item.id} name=${EventRepositoryImpl.previewName(item.name)}`);
          } else {
            // 兼容异常场景：记录被外部删除但内存仍保留了旧 id
            valueBucket[EventEntity.ID] = item.id;
            persistedId = await rdbStore.insert(EventEntity.TABLE_NAME, valueBucket);
            recoveredInsertCount += 1;
            hilog.warn(0x0000, TAG,
              `[ID_FIX][RECOVER_MISSING_ROW] idx=${i} expectedId=${item.id} insertedId=${persistedId} name=${EventRepositoryImpl.previewName(item.name)}`);
          }
        } else {
          persistedId = await rdbStore.insert(EventEntity.TABLE_NAME, valueBucket);
          insertedNewCount += 1;
          newInsertMappings.push(`${i}->${persistedId}`);
          hilog.info(0x0000, TAG,
            `[ID_FIX][NEW_INSERT] idx=${i} assignedId=${persistedId} name=${EventRepositoryImpl.previewName(item.name)}`);
        }

        if (persistedId > 0) {
          persistedIds.add(persistedId);
        }
      }

      // 2. 清理不在本次输入中的旧记录，保留“全量同步”的语义
      let planPredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      planPredicates.equalTo(EventEntity.PLAN_ID, planId);
      let resultSet = await rdbStore.query(planPredicates);
      const staleIds: number[] = [];

      try {
        while (resultSet.goToNextRow()) {
          const dbId = resultSet.getLong(resultSet.getColumnIndex(EventEntity.ID));
          if (!persistedIds.has(dbId)) {
            staleIds.push(dbId);
          }
        }
      } finally {
        resultSet.close();
      }

      for (let i = 0; i < staleIds.length; i++) {
        let deletePredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
        deletePredicates.equalTo(EventEntity.ID, staleIds[i]);
        await rdbStore.delete(deletePredicates);
      }
      hilog.info(0x0000, TAG,
        `[ID_FIX][CLEAN_STALE] planId=${planId} staleCount=${staleIds.length} staleIds=${EventRepositoryImpl.previewIds(staleIds)}`);

      rdbStore.commit();
      EventRepositoryImpl.markPlanDirty(planId);
      hilog.info(0x0000, TAG,
        `[ID_FIX][SAVE_DONE] planId=${planId} total=${events.length} updated=${updatedCount} newInserted=${insertedNewCount} recoveredInserted=${recoveredInsertCount} cleaned=${staleIds.length} persistedIds=${EventRepositoryImpl.previewIds(Array.from(persistedIds))} newMap=${newInsertMappings.join(',')}`);

    } catch (err) {
      hilog.error(0x0000, TAG, `[ID_FIX][SAVE_FAIL] planId=${planId} err=${JSON.stringify(err)}`);
      try {
        rdbStore.rollBack();
      } catch (rollbackErr) {
        hilog.error(0x0000, TAG, `[ID_FIX][ROLLBACK_FAIL] planId=${planId} err=${JSON.stringify(rollbackErr)}`);
      }

      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`[ID_FIX][SAVE_FAIL] planId=${planId}`);
    }
  }

  /**
   * [Day 3 鍗囩骇] 璇诲彇鎵€鏈変簨浠?
   */
  public static async getAllEvents(planId: number): Promise<TravelPlanItem[]> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return [];

    try {
      let predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      predicates.equalTo(EventEntity.PLAN_ID, planId);
      predicates.equalTo(EventEntity.DEL_FLAG, 0); // [鏂板] 鍙煡鏈垹闄ょ殑
      predicates.orderByAsc(EventEntity.DAY_OFFSET);
      predicates.orderByAsc(EventEntity.SORT_ORDER);
      let resultSet = await rdbStore.query(predicates);
      let resultList: TravelPlanItem[] = [];

      try {
        while (resultSet.goToNextRow()) {
          const rawLock = resultSet.getLong(resultSet.getColumnIndex(EventEntity.LOCK_STATUS));
          const lockStatus = rawLock >= 1 ? 1 : 0;

          resultList.push({
            id: resultSet.getLong(resultSet.getColumnIndex(EventEntity.ID)),
            name: resultSet.getString(resultSet.getColumnIndex(EventEntity.NAME)),
            note: resultSet.getString(resultSet.getColumnIndex(EventEntity.NOTE)),
            travelMode: resultSet.getLong(resultSet.getColumnIndex(EventEntity.TRAVEL_MODE)),
            type: (lockStatus > 0) ? 'ANCHOR' : 'FLOW',
            lockStatus: lockStatus,
            itemType: resultSet.getLong(resultSet.getColumnIndex(EventEntity.TYPE)),
            priority: resultSet.getLong(resultSet.getColumnIndex(EventEntity.PRIORITY)),
            duration: resultSet.getLong(resultSet.getColumnIndex(EventEntity.DURATION)),
            preTravelMinutes: resultSet.getLong(resultSet.getColumnIndex(EventEntity.PRE_TRAVEL_MINUTES)),
            isTravelManual: resultSet.getLong(resultSet.getColumnIndex(EventEntity.IS_TRAVEL_MANUAL)),

            fixedStartTime: resultSet.getString(resultSet.getColumnIndex(EventEntity.FIXED_START_TIME)),
            dayOffset: resultSet.getLong(resultSet.getColumnIndex(EventEntity.DAY_OFFSET)),
            status: resultSet.getLong(resultSet.getColumnIndex(EventEntity.STATUS)),
            sortOrder: resultSet.getLong(resultSet.getColumnIndex(EventEntity.SORT_ORDER)),
            latitude: resultSet.getDouble(resultSet.getColumnIndex(EventEntity.LATITUDE)),
            longitude: resultSet.getDouble(resultSet.getColumnIndex(EventEntity.LONGITUDE)),
            source: resultSet.getLong(resultSet.getColumnIndex(EventEntity.SOURCE)),

            // --- [Round 3 琛ュ叏] ---
            address: resultSet.getString(resultSet.getColumnIndex(EventEntity.ADDRESS)),
            aiReasoning: resultSet.getString(resultSet.getColumnIndex(EventEntity.AI_REASONING)),
            groupId: resultSet.getLong(resultSet.getColumnIndex(EventEntity.GROUP_ID)),
            delFlag: resultSet.getLong(resultSet.getColumnIndex(EventEntity.DEL_FLAG)),
            actualStartTime: resultSet.getLong(resultSet.getColumnIndex(EventEntity.ACTUAL_START_TIME)),
            actualEndTime: resultSet.getLong(resultSet.getColumnIndex(EventEntity.ACTUAL_END_TIME)),
            completionStatus: resultSet.getLong(resultSet.getColumnIndex(EventEntity.COMPLETION_STATUS)),
            weatherCondition: resultSet.getString(resultSet.getColumnIndex(EventEntity.WEATHER_CONDITION)),
            weatherTemperature: resultSet.getDouble(resultSet.getColumnIndex(EventEntity.WEATHER_TEMPERATURE)),
            weatherText: resultSet.getString(resultSet.getColumnIndex(EventEntity.WEATHER_TEXT)),
            weatherFetchTime: resultSet.getLong(resultSet.getColumnIndex(EventEntity.WEATHER_FETCH_TIME))
          });
        }
      } finally {
        resultSet.close();
      }
      const scheduleCount = resultList.filter((item: TravelPlanItem) => item.status === 1).length;
      const invalidCoordCount = resultList.filter((item: TravelPlanItem) => {
        const lat = item.latitude ?? 0;
        const lng = item.longitude ?? 0;
        return !Number.isFinite(lat) || !Number.isFinite(lng) || lat === 0 || lng === 0;
      }).length;
      hilog.info(
        0x0000,
        TAG,
        `[LOAD_DIAG][repo_get_all] planId=${planId}, total=${resultList.length}, schedule=${scheduleCount}, backlog=${resultList.length - scheduleCount}, invalidCoord=${invalidCoordCount}`
      );
      return resultList;
    } catch (err) {
      hilog.error(0x0000, TAG, `[getAllEvents] failed planId=${planId}, err=${JSON.stringify(err)}`);
      return [];
    }
  }

  public static async updateDayOffset(id: number, dayOffset: number) {
    await EventRepositoryImpl.updateSingleField(id, EventEntity.DAY_OFFSET, dayOffset);
  }

  /**
   * [Day 3.5 琛ユ紡] 鎵归噺鏇存柊鏃堕棿杞翠竴鑷存€?(鎷嗛櫎鐐稿脊涓€)
   * 淇鍙橀噺鍚嶆姤閿欙細bucket -> valueBucket
   */
  public static async updateTimelineConsistency(events: TravelPlanItem[], planIdHint: number = -1): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      rdbStore.beginTransaction();

      for (let item of events) {
        // 鍙湁褰?item 鏈?ID 鏃舵墠鏇存柊
        if (item.id) {
          // 淇鐐癸細鍙橀噺鍚嶅畾涔変负 valueBucket
          const valueBucket: ValuesBucket = {};

          // 鍙洿鏂板彈澶氱背璇烘晥搴斿奖鍝嶇殑瀛楁锛氳矾绋嬪拰鎺掑簭
          valueBucket[EventEntity.STATUS] = item.status ?? 0;
          valueBucket[EventEntity.DAY_OFFSET] = item.dayOffset ?? 0;
          valueBucket[EventEntity.LOCK_STATUS] = item.lockStatus ?? 0;
          valueBucket[EventEntity.FIXED_START_TIME] = item.fixedStartTime || '';
          valueBucket[EventEntity.PRE_TRAVEL_MINUTES] = item.preTravelMinutes || 0;
          valueBucket[EventEntity.IS_TRAVEL_MANUAL] = item.isTravelManual || 0;
          valueBucket[EventEntity.SORT_ORDER] = item.sortOrder;

          let predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
          predicates.equalTo(EventEntity.ID, item.id);

          // 淇鐐癸細杩欓噷浣跨敤 valueBucket 灏变笉浼氭姤閿欎簡
          await rdbStore.update(valueBucket, predicates);
        }
      }

      rdbStore.commit();
      if (planIdHint > 0) {
        EventRepositoryImpl.markPlanDirty(planIdHint);
      }
    } catch (err) {
      hilog.error(0x0000, TAG, `Batch update failed: ${JSON.stringify(err)}`);
      try {
        rdbStore.rollBack();
      } catch (_rollbackErr) {
      }
    }
  }

  /**
   * 鍗曞瓧娈垫洿鏂?(淇濇寔涓嶅彉锛岄潪甯搁噸瑕?
   */
  public static async updateSingleField(id: number, column: string, value: Object, planIdHint: number = -1): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;

    try {
      const bucket: ValuesBucket = {};
      bucket[column] = value as number | string | boolean;

      let predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      predicates.equalTo(EventEntity.ID, id);

      await rdbStore.update(bucket, predicates);
      const resolvedPlanId = planIdHint > 0 ? planIdHint : await EventRepositoryImpl.resolvePlanIdByEventId(id);
      if (resolvedPlanId > 0) {
        EventRepositoryImpl.markPlanDirty(resolvedPlanId);
      }
    } catch (err) {
      hilog.error(0x0000, TAG, `[updateSingleField] failed id=${id}, column=${column}, err=${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`[updateSingleField] failed id=${id}, column=${column}`);
    }
  }

  public static async updateFields(id: number, updates: EventFieldUpdate[], planIdHint: number = -1): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore || updates.length === 0) return;

    try {
      const bucket: ValuesBucket = {};
      for (let i = 0; i < updates.length; i++) {
        const pair = updates[i];
        bucket[pair.column] = pair.value;
      }

      let predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      predicates.equalTo(EventEntity.ID, id);

      await rdbStore.update(bucket, predicates);
      const resolvedPlanId = planIdHint > 0 ? planIdHint : await EventRepositoryImpl.resolvePlanIdByEventId(id);
      if (resolvedPlanId > 0) {
        EventRepositoryImpl.markPlanDirty(resolvedPlanId);
      }
    } catch (err) {
      hilog.error(0x0000, TAG, `[updateFields] failed id=${id}, err=${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`[updateFields] failed id=${id}`);
    }
  }

  public static async applyRuntimeTransition(input: RuntimeTransitionInput): Promise<RuntimeTransitionResult> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) {
      return { ok: false, reason: 'db_unavailable', startTime: 0, endTime: 0, completionStatus: EventEntity.STATE_PENDING };
    }

    let currentStart = 0;
    let currentEnd = 0;
    let currentStatus = EventEntity.STATE_PENDING;
    try {
      rdbStore.beginTransaction();

      let targetPredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      targetPredicates.equalTo(EventEntity.ID, input.eventId)
        .and()
        .equalTo(EventEntity.PLAN_ID, input.planId);
      const targetSet = await rdbStore.query(targetPredicates);
      try {
        if (!targetSet.goToFirstRow()) {
          rdbStore.rollBack();
          return { ok: false, reason: 'not_found', startTime: 0, endTime: 0, completionStatus: EventEntity.STATE_PENDING };
        }
        const scheduleStatus = targetSet.getLong(targetSet.getColumnIndex(EventEntity.STATUS));
        if (scheduleStatus !== 1) {
          rdbStore.rollBack();
          return { ok: false, reason: 'not_scheduled', startTime: 0, endTime: 0, completionStatus: EventEntity.STATE_PENDING };
        }
        currentStart = targetSet.getLong(targetSet.getColumnIndex(EventEntity.ACTUAL_START_TIME));
        currentEnd = targetSet.getLong(targetSet.getColumnIndex(EventEntity.ACTUAL_END_TIME));
        currentStatus = targetSet.getLong(targetSet.getColumnIndex(EventEntity.COMPLETION_STATUS));
      } finally {
        targetSet.close();
      }

      const updateBucket: ValuesBucket = {};
      if (input.transition === 'START') {
        if (!(currentStatus === EventEntity.STATE_PENDING && currentStart <= 0)) {
          rdbStore.rollBack();
          return { ok: false, reason: 'invalid_start_state', startTime: currentStart, endTime: currentEnd, completionStatus: currentStatus };
        }

        let activePredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
        activePredicates.equalTo(EventEntity.STATUS, 1)
          .and()
          .equalTo(EventEntity.COMPLETION_STATUS, EventEntity.STATE_PENDING)
          .and()
          .greaterThan(EventEntity.ACTUAL_START_TIME, 0)
          .and()
          .lessThanOrEqualTo(EventEntity.ACTUAL_END_TIME, 0)
          .and()
          .equalTo(EventEntity.DEL_FLAG, 0);
        const activeSet = await rdbStore.query(activePredicates);
        let hasOtherActive = false;
        const planUsableCache: Map<number, boolean> = new Map<number, boolean>();
        try {
          while (activeSet.goToNextRow()) {
            const activeId = activeSet.getLong(activeSet.getColumnIndex(EventEntity.ID));
            const activePlanId = activeSet.getLong(activeSet.getColumnIndex(EventEntity.PLAN_ID));
            if (activeId !== input.eventId) {
              let planUsable = planUsableCache.get(activePlanId);
              if (planUsable === undefined) {
                planUsable = await EventRepositoryImpl.isPlanUsableForRuntime(rdbStore, activePlanId);
                planUsableCache.set(activePlanId, planUsable);
              }
              if (!planUsable) {
                continue;
              }
              hasOtherActive = true;
              break;
            }
          }
        } finally {
          activeSet.close();
        }
        if (hasOtherActive) {
          rdbStore.rollBack();
          return { ok: false, reason: 'active_exists', startTime: currentStart, endTime: currentEnd, completionStatus: currentStatus };
        }
        updateBucket[EventEntity.ACTUAL_START_TIME] = input.timestamp;
        currentStart = input.timestamp;
      } else if (input.transition === 'END') {
        if (!(currentStatus === EventEntity.STATE_PENDING && currentStart > 0)) {
          rdbStore.rollBack();
          return { ok: false, reason: 'invalid_end_state', startTime: currentStart, endTime: currentEnd, completionStatus: currentStatus };
        }
        updateBucket[EventEntity.ACTUAL_END_TIME] = input.timestamp;
        updateBucket[EventEntity.COMPLETION_STATUS] = EventEntity.STATE_COMPLETED;
        currentEnd = input.timestamp;
        currentStatus = EventEntity.STATE_COMPLETED;
      } else if (input.transition === 'SKIP') {
        if (currentStatus !== EventEntity.STATE_PENDING) {
          rdbStore.rollBack();
          return { ok: false, reason: 'invalid_skip_state', startTime: currentStart, endTime: currentEnd, completionStatus: currentStatus };
        }
        updateBucket[EventEntity.ACTUAL_END_TIME] = input.timestamp;
        updateBucket[EventEntity.COMPLETION_STATUS] = EventEntity.STATE_SKIPPED;
        currentEnd = input.timestamp;
        currentStatus = EventEntity.STATE_SKIPPED;
      } else {
        if (currentStatus !== EventEntity.STATE_SKIPPED) {
          rdbStore.rollBack();
          return { ok: false, reason: 'invalid_reopen_state', startTime: currentStart, endTime: currentEnd, completionStatus: currentStatus };
        }
        updateBucket[EventEntity.ACTUAL_START_TIME] = 0;
        updateBucket[EventEntity.ACTUAL_END_TIME] = 0;
        updateBucket[EventEntity.COMPLETION_STATUS] = EventEntity.STATE_PENDING;
        currentStart = 0;
        currentEnd = 0;
        currentStatus = EventEntity.STATE_PENDING;
      }

      let updatePredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      updatePredicates.equalTo(EventEntity.ID, input.eventId)
        .and()
        .equalTo(EventEntity.PLAN_ID, input.planId);
      await rdbStore.update(updateBucket, updatePredicates);
      rdbStore.commit();
      EventRepositoryImpl.markPlanDirty(input.planId);
      return {
        ok: true,
        reason: 'ok',
        startTime: currentStart,
        endTime: currentEnd,
        completionStatus: currentStatus
      };
    } catch (err) {
      try {
        rdbStore.rollBack();
      } catch (_rollbackErr) {
      }
      hilog.error(0x0000, TAG, `[RUNTIME_TRANSITION][failed] plan=${input.planId}, event=${input.eventId}, transition=${input.transition}, reason=${JSON.stringify(err)}`);
      return { ok: false, reason: 'exception', startTime: currentStart, endTime: currentEnd, completionStatus: currentStatus };
    }
  }

  public static async findGlobalActiveEvent(excludeEventId: number = -1): Promise<ActiveEventSnapshot | null> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) {
      return null;
    }
    try {
      const predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      predicates.equalTo(EventEntity.STATUS, 1)
        .and()
        .equalTo(EventEntity.COMPLETION_STATUS, EventEntity.STATE_PENDING)
        .and()
        .greaterThan(EventEntity.ACTUAL_START_TIME, 0)
        .and()
        .lessThanOrEqualTo(EventEntity.ACTUAL_END_TIME, 0)
        .and()
        .equalTo(EventEntity.DEL_FLAG, 0)
        .orderByDesc(EventEntity.ACTUAL_START_TIME);
      const resultSet = await rdbStore.query(predicates);
      const planUsableCache: Map<number, boolean> = new Map<number, boolean>();
      try {
        while (resultSet.goToNextRow()) {
          const eventId = resultSet.getLong(resultSet.getColumnIndex(EventEntity.ID));
          if (excludeEventId > 0 && eventId === excludeEventId) {
            continue;
          }
          const planId = resultSet.getLong(resultSet.getColumnIndex(EventEntity.PLAN_ID));
          let planUsable = planUsableCache.get(planId);
          if (planUsable === undefined) {
            planUsable = await EventRepositoryImpl.isPlanUsableForRuntime(rdbStore, planId);
            planUsableCache.set(planId, planUsable);
          }
          if (!planUsable) {
            continue;
          }
          return {
            eventId: eventId,
            planId: planId,
            name: resultSet.getString(resultSet.getColumnIndex(EventEntity.NAME)),
            actualStartTime: resultSet.getLong(resultSet.getColumnIndex(EventEntity.ACTUAL_START_TIME))
          };
        }
      } finally {
        resultSet.close();
      }
      return null;
    } catch (err) {
      hilog.warn(0x0000, TAG, `[findGlobalActiveEvent] failed excludeEventId=${excludeEventId}, err=${JSON.stringify(err)}`);
      return null;
    }
  }
  /**
   * [浜や簰鍗囩骇] 杞垹闄?(UI涓婄殑鈥滃乏婊戠Щ闄?鏆傚瓨鈥?
   * 灏?del_flag 缃负 1锛屼笉鐗╃悊鍒犻櫎锛屾柟渚挎仮澶?
   */
  public static async softDeleteEvent(id: number): Promise<void> {
    await EventRepositoryImpl.updateSingleField(id, EventEntity.DEL_FLAG, 1);
  }

  /**
   * [浜や簰鍗囩骇] 鐗╃悊鍒犻櫎 (UI涓婄殑鈥滃彸婊戝垹闄も€?
   * 褰诲簳浠庢暟鎹簱绉婚櫎
   */
  public static async hardDeleteEvent(id: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;
    try {
      let queryPredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      queryPredicates.equalTo(EventEntity.ID, id);
      const resultSet = await rdbStore.query(queryPredicates);
      let planId = 0;
      try {
        if (resultSet.goToFirstRow()) {
          planId = resultSet.getLong(resultSet.getColumnIndex(EventEntity.PLAN_ID));
        }
      } finally {
        resultSet.close();
      }

      let deletePredicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
      deletePredicates.equalTo(EventEntity.ID, id);
      await rdbStore.delete(deletePredicates);
      if (planId > 0) {
        EventRepositoryImpl.markPlanDirty(planId);
      }
    } catch (err) {
      hilog.error(0x0000, TAG, `[hardDeleteEvent] failed id=${id}, err=${JSON.stringify(err)}`);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`[hardDeleteEvent] failed id=${id}`);
    }
  }

  public static async deleteEventsBySource(planId: number, source: number): Promise<void> {
    const rdbStore = RdbHelper.getInstance().getRdbStore();
    if (!rdbStore) return;
    const predicates = new relationalStore.RdbPredicates(EventEntity.TABLE_NAME);
    predicates.equalTo(EventEntity.PLAN_ID, planId).and().equalTo(EventEntity.SOURCE, source);
    await rdbStore.delete(predicates);
    EventRepositoryImpl.markPlanDirty(planId);
  }
}

export type {
  EventFieldUpdate,
  RuntimeTransitionInput,
  RuntimeTransitionResult,
  ActiveEventSnapshot
} from '../../domain/ports/IEventRepository';
