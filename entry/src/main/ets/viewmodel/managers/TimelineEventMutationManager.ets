import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../../common/utils/DateUtil';
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { EventFieldUpdate, EventRepositoryImpl } from '../../infrastructure/persistence/EventRepositoryImpl';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { UserBehaviorTracker } from '../../domain/strategy/UserBehaviorTracker';
import { GeoPointInput } from '../../domain/services/WeatherModels';
import { TimelineStrategyManager } from './TimelineStrategyManager';

const TAG = 'TimelineViewModel';

export interface ITimelineEventMutationHost {
  events: EventEntity[];
  planId: number;
  enableAutoAmapRoute: boolean;
  enableGlobalAmapRouteApi: boolean;

  isFirstScheduledItemOfDay(item: EventEntity): boolean;
  resolveCoordinatesForPlaceName(
    placeName: string,
    lat?: number,
    lng?: number,
    source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput>;
  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean;
  recalculateFromEventId(eventId: number): void;
  recalculateFromIndex(startIndex: number): void;
  save(): Promise<void>;
  updatePlanDate(newDateTimestamp: number): Promise<void>;
  tryBeginMutation(itemId: number): boolean;
  endMutation(itemId: number): void;
  refreshTimelineView(): void;
}

export class TimelineEventMutationManager {
  private readonly host: ITimelineEventMutationHost;
  private readonly behaviorTracker: UserBehaviorTracker;
  private readonly strategyManager: TimelineStrategyManager;

  constructor(host: ITimelineEventMutationHost, behaviorTracker: UserBehaviorTracker, strategyManager: TimelineStrategyManager) {
    this.host = host;
    this.behaviorTracker = behaviorTracker;
    this.strategyManager = strategyManager;
  }

  public async addNewItem(
    name: string,
    duration: number,
    isSchedule: boolean = false,
    fixedTime?: string,
    dayOffset: number = 0,
    preTravel: number = -1,
    isHardLock: boolean = false,
    note: string = '',
    priority: number = 0,
    lat?: number,
    lng?: number
  ): Promise<void> {
    hilog.info(0x0000, TAG, `[节点3A: 准备新增入库] -> 地点: ${name}, lat: ${lat}, lng: ${lng}`);
    const resolvedCoordinate = await this.host.resolveCoordinatesForPlaceName(name, lat, lng, 'add');

    const newItemInterface: TravelPlanItem = {
      name: name,
      duration: duration,
      type: fixedTime ? 'ANCHOR' : 'FLOW',
      preTravelMinutes: preTravel,
      sortOrder: 0,
      status: isSchedule ? 1 : 0,
      lockStatus: fixedTime ? (isHardLock ? 1 : 0) : 0,
      fixedStartTime: fixedTime || undefined,
      dayOffset: dayOffset,
      note: note,
      itemType: 0,
      priority: priority,
      isTravelManual: 0,
      source: 0,
      delFlag: 0,
      groupId: 0,
      address: '',
      aiReasoning: '',
      travelMode: 2,
      latitude: resolvedCoordinate.latitude,
      longitude: resolvedCoordinate.longitude
    };

    const newId = await EventRepositoryImpl.insertEvent(this.host.planId, newItemInterface);
    newItemInterface.id = newId;

    const newEntity = EventEntity.fromInterface(newItemInterface, this.host.planId);
    if (isSchedule) {
      this.insertSmart(newEntity);
      if (newEntity.pre_travel_min < 0 && !this.shouldAutoRouteForItem(newEntity)) {
        newEntity.pre_travel_min = 0;
      }
    } else {
      this.host.events.push(newEntity);
    }

    this.host.recalculateFromEventId(newEntity.id);
    const scheduleCount = this.host.events.filter((event: EventEntity) => event.status === 1).length;
    hilog.info(
      0x0000,
      TAG,
      `[ADD_ITEM][done] id=${newEntity.id}, status=${newEntity.status}, total=${this.host.events.length}, schedule=${scheduleCount}`
    );
  }

  public updateManualCommute(item: EventEntity, minutes: number): void {
    if (!item) {
      return;
    }
    const safeMinutes = Math.floor(minutes);
    if (!Number.isFinite(safeMinutes) || safeMinutes <= 0) {
      return;
    }

    item.pre_travel_min = safeMinutes;
    item.is_travel_manual = 1;

    if (item.id) {
      EventRepositoryImpl.updateSingleField(item.id, EventEntity.PRE_TRAVEL_MINUTES, safeMinutes, this.host.planId);
      EventRepositoryImpl.updateSingleField(item.id, EventEntity.IS_TRAVEL_MANUAL, 1, this.host.planId);
    }

    this.host.recalculateFromEventId(item.id);
  }

  public async moveEvent(index: number, direction: 'up' | 'down'): Promise<void> {
    if (index < 0 || index >= this.host.events.length) {
      return;
    }
    const source = this.host.events[index];
    if (source.status !== 1) {
      return;
    }

    const scheduleIndexes: number[] = [];
    this.host.events.forEach((item: EventEntity, idx: number) => {
      if (item.status === 1) {
        scheduleIndexes.push(idx);
      }
    });

    const currentSchedulePos = scheduleIndexes.indexOf(index);
    const targetSchedulePos = direction === 'up' ? currentSchedulePos - 1 : currentSchedulePos + 1;
    if (targetSchedulePos < 0 || targetSchedulePos >= scheduleIndexes.length) {
      return;
    }
    const targetIndex = scheduleIndexes[targetSchedulePos];

    const swappedEvents = [...this.host.events];
    const temp = swappedEvents[index];
    swappedEvents[index] = swappedEvents[targetIndex];
    swappedEvents[targetIndex] = temp;

    let order = 0;
    swappedEvents.forEach((item: EventEntity) => {
      if (item.status !== 1) {
        return;
      }
      item.sort_order = order;
      order += 100;
    });

    await EventRepositoryImpl.updateTimelineConsistency(swappedEvents.map((event: EventEntity) => event.toInterface()), this.host.planId);
    this.host.events.splice(0, this.host.events.length, ...swappedEvents);
    const recalculateStartIndex = Math.max(Math.min(index, targetIndex) - 1, 0);
    this.host.recalculateFromIndex(recalculateStartIndex);
  }

  public async moveAllBacklogToSchedule(): Promise<number> {
    const backlogItems = this.host.events.filter((event: EventEntity) => event.status !== 1);
    if (backlogItems.length === 0) {
      return 0;
    }
    hilog.info(0x0000, TAG, `[BACKLOG][move_all_begin] total=${backlogItems.length}`);

    const scheduleItems = this.host.events.filter((event: EventEntity) => event.status === 1);
    let maxSort = scheduleItems.reduce((max: number, cur: EventEntity) => cur.sort_order > max ? cur.sort_order : max, 0);

    backlogItems.forEach((target: EventEntity) => {
      maxSort += 100;
      target.status = 1;
      target.sort_order = maxSort;
      target.fixed_start_time = '';
      target.computed_time = '';
      target.dynamic_start_time = 0;
      target.dynamic_end_time = 0;
      if (this.shouldAutoRouteForItem(target)) {
        target.pre_travel_min = -1;
      }
    });

    this.host.events.sort((a: EventEntity, b: EventEntity) => {
      if (a.status !== b.status) {
        return b.status - a.status;
      }
      return a.sort_order - b.sort_order;
    });
    this.host.refreshTimelineView();
    this.host.recalculateFromIndex(0);
    hilog.info(0x0000, TAG, '[BACKLOG][move_all_recalc_done] fromIndex=0');
    await this.host.save();
    this.host.refreshTimelineView();
    hilog.info(0x0000, TAG, '[BACKLOG][move_all_ui_refreshed]');
    return backlogItems.length;
  }

  public async moveToBacklog(item: TravelPlanItem | EventEntity): Promise<void> {
    if (!item || !item.id) {
      hilog.warn(0x0000, TAG, '[SCHEDULE][move_to_backlog_skip] reason=invalid_item');
      throw new Error('[SCHEDULE][move_to_backlog_skip] reason=invalid_item');
    }
    if (!this.host.tryBeginMutation(item.id)) {
      hilog.warn(0x0000, TAG, `[SCHEDULE][move_to_backlog_skip] reason=mutation_in_flight, itemId=${item.id}`);
      throw new Error(`[SCHEDULE][move_to_backlog_skip] reason=mutation_in_flight, itemId=${item.id}`);
    }
    try {
      const target = this.host.events.find((event: EventEntity) => event.id === item.id);
      if (!target) {
        hilog.warn(0x0000, TAG, `[SCHEDULE][move_to_backlog_skip] reason=item_not_found, itemId=${item.id}`);
        this.host.refreshTimelineView();
        return;
      }
      if (target.status !== 1) {
        hilog.warn(0x0000, TAG, `[SCHEDULE][move_to_backlog_skip] reason=not_schedule, itemId=${item.id}, status=${target.status}`);
        this.host.refreshTimelineView();
        return;
      }
      const previousIndex = this.host.events.indexOf(target);
      const previousStatus = target.status;
      const previousDayOffset = target.day_offset;
      const previousDynamicDayOffset = target.dynamic_day_offset;
      hilog.info(
        0x0000,
        TAG,
        `[SCHEDULE][move_to_backlog_begin] itemId=${target.id}, fromStatus=${previousStatus}, index=${previousIndex}, dayOffset=${previousDayOffset}, dynamicDayOffset=${previousDynamicDayOffset}`
      );
      target.status = 0;
      target.sort_order = 0;
      // 先刷新一帧，避免 UI 依赖 groupedEvents 时出现“操作后不立即生效”
      this.host.refreshTimelineView();
      this.host.recalculateFromIndex(previousIndex > 0 ? previousIndex - 1 : 0);
      await this.host.save();
      hilog.info(
        0x0000,
        TAG,
        `[SCHEDULE][move_to_backlog_done] itemId=${target.id}, toStatus=${target.status}, recalcFrom=${previousIndex > 0 ? previousIndex - 1 : 0}`
      );
    } catch (error) {
      hilog.error(0x0000, TAG, `[SCHEDULE][move_to_backlog_fail] itemId=${item.id}, reason=${JSON.stringify(error)}`);
      this.host.refreshTimelineView();
      throw new Error(`[SCHEDULE][move_to_backlog_fail] itemId=${item.id}`);
    } finally {
      this.host.endMutation(item.id);
    }
  }

  public async hardDelete(item: EventEntity): Promise<void> {
    if (!item || !item.id) {
      hilog.warn(0x0000, TAG, '[SCHEDULE][hard_delete_skip] reason=invalid_item');
      throw new Error('[SCHEDULE][hard_delete_skip] reason=invalid_item');
    }
    if (!this.host.tryBeginMutation(item.id)) {
      hilog.warn(0x0000, TAG, `[SCHEDULE][hard_delete_skip] reason=mutation_in_flight, itemId=${item.id}`);
      throw new Error(`[SCHEDULE][hard_delete_skip] reason=mutation_in_flight, itemId=${item.id}`);
    }
    const previousStatus = item.status;
    const previousDayOffset = item.day_offset;
    const previousDynamicDayOffset = item.dynamic_day_offset;
    const previousIndex = this.host.events.indexOf(item);
    hilog.info(
      0x0000,
      TAG,
      `[SCHEDULE][hard_delete_begin] itemId=${item.id}, status=${previousStatus}, index=${previousIndex}, dayOffset=${previousDayOffset}, dynamicDayOffset=${previousDynamicDayOffset}`
    );
    try {
      const index = this.host.events.indexOf(item);
      if (index !== -1) {
        this.host.events.splice(index, 1);
        // 删除后先刷新分组，保证 UI 立即可见
        this.host.refreshTimelineView();
      }

      await EventRepositoryImpl.hardDeleteEvent(item.id);
      this.host.recalculateFromIndex(index > 0 ? index - 1 : 0);

      if (item.source === 1) {
        this.behaviorTracker.recordDeletion(item.type, item.duration, item.pre_travel_min);
        if (this.behaviorTracker.shouldTriggerAdaptation()) {
          await this.strategyManager.triggerStrategyAdaptation();
        }
      }
      hilog.info(
        0x0000,
        TAG,
        `[SCHEDULE][hard_delete_done] itemId=${item.id}, fromStatus=${previousStatus}, dbDeleted=yes, recalcFrom=${index > 0 ? index - 1 : 0}`
      );
    } catch (error) {
      hilog.error(0x0000, TAG, `[SCHEDULE][hard_delete_fail] itemId=${item.id}, reason=${JSON.stringify(error)}`);
      this.host.refreshTimelineView();
      throw new Error(`[SCHEDULE][hard_delete_fail] itemId=${item.id}`);
    } finally {
      this.host.endMutation(item.id);
    }
  }

  public async resolveConflictByBacklog(
    id: number,
    name: string,
    duration: number,
    note: string = '',
    priority: number = 0
  ): Promise<void> {
    if (id !== -1) {
      const target = this.host.events.find((event: EventEntity) => event.id === id);
      if (target) {
        hilog.info(
          0x0000,
          TAG,
          `[SCHEDULE][conflict_move_to_backlog] itemId=${target.id}, fromStatus=${target.status}, dayOffset=${target.day_offset}, dynamicDayOffset=${target.dynamic_day_offset}`
        );
        target.status = 0;
        target.day_offset = 0;
        target.dynamic_day_offset = 0;
        target.fixed_start_time = '';
        await this.updateEventInfo(id, name, duration, undefined, 0, false, note, priority);
      }
      return;
    }
    await this.addNewItem(name, duration, false, undefined, 0, 0, false, note, priority);
  }

  public async resolveConflictByMovingPlan(
    id: number,
    targetDateMs: number,
    name: string,
    duration: number,
    isSchedule: boolean,
    fixedTime?: string,
    note: string = '',
    priority: number = 0
  ): Promise<void> {
    await this.host.updatePlanDate(targetDateMs);

    if (id !== -1) {
      await this.updateEventInfo(id, name, duration, fixedTime, 0, false, note, priority);
      return;
    }
    await this.addNewItem(name, duration, isSchedule, fixedTime, 0, -1, false, note, priority);
  }

  public async updateEventInfo(
    id: number,
    name: string,
    duration: number,
    fixedTime?: string,
    dayOffset: number = 0,
    isHardLock: boolean = false,
    note: string = '',
    priority: number = 0,
    lat?: number,
    lng?: number
  ): Promise<void> {
    hilog.info(0x0000, TAG, `[节点3B: 准备更新入库] -> 地点: ${name}(ID:${id}), lat: ${lat}, lng: ${lng}`);

    const target = this.host.events.find((event: EventEntity) => event.id === id);
    if (!target) {
      return;
    }

    const oldStatus = target.status;
    const oldTime = target.fixed_start_time;
    const oldDayOffset = target.day_offset;
    const oldName = target.name;
    const oldLat = target.latitude;
    const oldLng = target.longitude;
    const resolvedCoordinate = await this.host.resolveCoordinatesForPlaceName(name, lat, lng, 'update', oldLat, oldLng);
    const resolvedLat = resolvedCoordinate.latitude;
    const resolvedLng = resolvedCoordinate.longitude;
    const dayOffsetChanged = oldDayOffset !== dayOffset;
    const nextLat = this.host.isCoordinateMissingForWeather(resolvedLat, resolvedLng) ? oldLat : resolvedLat;
    const nextLng = this.host.isCoordinateMissingForWeather(resolvedLat, resolvedLng) ? oldLng : resolvedLng;
    const placeChanged = oldName !== name || oldLat !== nextLat || oldLng !== nextLng;

    target.name = name;
    target.duration = duration;
    target.note = note;
    target.day_offset = dayOffset;
    target.dynamic_day_offset = dayOffset;
    target.priority = priority;
    if (!this.host.isCoordinateMissingForWeather(resolvedLat, resolvedLng)) {
      target.latitude = resolvedLat;
      target.longitude = resolvedLng;
    }

    if (placeChanged && this.shouldAutoRouteForItem(target)) {
      target.is_travel_manual = 0;
      target.pre_travel_min = -1;
    }

    if (fixedTime) {
      target.status = 1;
      target.fixed_start_time = fixedTime;
      target.lock_status = isHardLock ? 1 : 0;
    }

    if (target.id) {
      const updates: EventFieldUpdate[] = [
        { column: 'status', value: target.status },
        { column: 'name', value: name },
        { column: 'duration', value: duration },
        { column: 'lock_status', value: target.lock_status },
        { column: 'fixed_start_time', value: target.fixed_start_time || '' },
        { column: EventEntity.DAY_OFFSET, value: dayOffset },
        { column: 'note', value: note },
        { column: 'priority', value: priority }
      ];
      if (placeChanged && this.shouldAutoRouteForItem(target)) {
        updates.push({ column: EventEntity.IS_TRAVEL_MANUAL, value: 0 });
        updates.push({ column: EventEntity.PRE_TRAVEL_MINUTES, value: -1 });
      }
      if (!this.host.isCoordinateMissingForWeather(resolvedLat, resolvedLng)) {
        updates.push({ column: 'latitude', value: resolvedLat });
        updates.push({ column: 'longitude', value: resolvedLng });
      }
      await EventRepositoryImpl.updateFields(target.id, updates, this.host.planId);
      hilog.info(0x0000, TAG, `[节点3B: 准备更新入库] -> 地点: ${name}(ID:${id}), lat: ${resolvedLat}, lng: ${resolvedLng}`);
    }

    const shouldReinsert = ((oldStatus === 0 && target.status === 1) || (fixedTime && fixedTime !== oldTime) ||
      (dayOffsetChanged && target.status === 1));
    if (shouldReinsert) {
      const currentIndex = this.host.events.indexOf(target);
      if (currentIndex >= 0) {
        this.host.events.splice(currentIndex, 1);
      }
      this.insertSmart(target);
      await EventRepositoryImpl.updateTimelineConsistency(this.host.events.map((event: EventEntity) => event.toInterface()), this.host.planId);
    }

    this.host.recalculateFromEventId(id);
  }

  public insertSmartForCompat(newEntity: EventEntity): void {
    this.insertSmart(newEntity);
  }

  private shouldAutoRouteForItem(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    if (!(this.host.enableAutoAmapRoute && this.host.enableGlobalAmapRouteApi)) {
      return false;
    }
    if (item.is_travel_manual === 1) {
      return false;
    }
    if (this.host.isFirstScheduledItemOfDay(item)) {
      return false;
    }
    return true;
  }

  private insertSmart(newEntity: EventEntity): void {
    if (newEntity.status === 0) {
      this.host.events.push(newEntity);
      return;
    }

    const targetTimeStr = newEntity.fixed_start_time || newEntity.computed_time || '23:59';
    const targetMin = DateUtil.timeToMinutes(targetTimeStr);

    let insertIndex = -1;
    for (let i = 0; i < this.host.events.length; i++) {
      const curr = this.host.events[i];
      if (curr.status !== 1) {
        continue;
      }

      const currDayOffset = TimelineDatePolicy.resolveEventDayOffset(curr);
      const targetDayOffset = TimelineDatePolicy.resolveEventDayOffset(newEntity);

      if (currDayOffset > targetDayOffset) {
        insertIndex = i;
        break;
      }

      if (currDayOffset === targetDayOffset) {
        const currTimeStr = curr.fixed_start_time || curr.computed_time || '23:59';
        const currMin = DateUtil.timeToMinutes(currTimeStr);
        if (currMin > targetMin) {
          insertIndex = i;
          break;
        }
      }
    }

    if (insertIndex !== -1) {
      this.host.events.splice(insertIndex, 0, newEntity);
    } else {
      this.host.events.push(newEntity);
    }

    this.host.events.forEach((event: EventEntity, index: number) => {
      event.sort_order = index * 100;
    });
  }
}
