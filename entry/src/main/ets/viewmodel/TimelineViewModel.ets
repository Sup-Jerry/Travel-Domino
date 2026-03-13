// 文件路径: ets/viewmodel/TimelineViewModel.ets
import { TravelPlanItem } from '../model/interface/IStandardEvent';
import { EventDao, EventFieldUpdate } from '../model/entity/EventDao';
import { EventEntity } from '../model/entity/EventEntity'; // 引入 Entity
import { TimeConstraintSolver } from '../model/logic/TimeConstraintSolver';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../common/utils/DateUtil';
import { TimelineDatePolicy } from '../common/utils/TimelineDatePolicy';
import { TimelineExecutionState } from '../common/utils/TimelineExecutionState';
import { PlanDao } from '../model/entity/PlanDao'; // [修改 1] 新增导入 PlanDao
import { AiService } from '../common/utils/AiService'; // 记得导入
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { NotificationGateway } from '../common/utils/NotificationGateway';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';

export interface DateGroup {
  dateHeader: string;
  dayIndex: number;
  dayOffset: number;
  actualDateMs: number;
  events: EventEntity[];
}

interface GeneratedTypeLiteralInterface_7 {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

export interface CompressionPlan {

  status: 'NO_ACTION' | 'COMPRESS_CONFIRM' | 'OVERLOAD' | 'FAIL_TOO_SHORT';
  msg: string;
  affectedItems: GeneratedTypeLiteralInterface_7[];
  suggestedTime?: string;
  remainingGapMinutes?: number;
  capacityMinutes?: number;
  mode?: CompressionMode;
}

export type CompressionMode = 'EQUAL' | 'RATIO';

export interface CompressionSelectionCandidate {
  index: number;
  id: number;
  name: string;
  oldVal: number;
  minAllowed: number;
  maxReducible: number;
  isRigid: boolean;
  selectable: boolean;
  disabledReason?: string;
}

export interface CompressionSelectionContext {
  targetIndex: number;
  targetTime: string;
  neededGapMinutes: number;
  naturalArrivalMinutes: number;
  chainStartIndex: number;
  candidates: CompressionSelectionCandidate[];
}

export interface PlanDateShiftPreview {
  hasRigidConflict: boolean;
  conflictItemId: number;
  conflictItemName: string;
  gapMinutes: number;
  conflictMsg: string;
}

export interface PlaceCheckinRecord {
  id: number;
  name: string;
  dayOffset: number;
  status: number;
  actualStart: number;
  actualEnd: number;
  stayMinutes: number;
}

export interface PlaceCheckinSummary {
  placeName: string;
  totalRecords: number;
  completedRecords: number;
  skippedRecords: number;
  avgStayMinutes: number;
  lastEndTime: number;
  records: PlaceCheckinRecord[];
}

export type CompanionRuntimeState = 'IDLE' | 'READY' | 'ACTIVE' | 'GAP';

export interface ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed';
  minutesDelta: number;
  message: string;
  updatedAt: number;
}

export interface CompanionActions {
  canStart: boolean;
  canEnd: boolean;
  canSkip: boolean;
  canNavigate: boolean;
  canViewDetail: boolean;
}

export interface CompanionContext {
  runtimeState: CompanionRuntimeState;
  currentEvent: EventEntity | null;
  nextEvent: EventEntity | null;
  hint: ReflowHint | null;
  actions: CompanionActions;
}

const TAG = 'TimelineViewModel';


interface GeneratedTypeLiteralInterface_5 {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

interface GeneratedTypeLiteralInterface_6 {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

interface SolverCalculatedItem {
  isConflict?: boolean;
  conflictMsg?: string;
  computedStartTime?: string;
  preTravelMinutes?: number;
  hasGap?: boolean;
  gapMinutes?: number;
  naturalStartTime?: string;
  transitWarning?: boolean;
  dynamicDayOffset?: number;
  dayOffset?: number;
}

interface ApplyResultFlags {
  changed: boolean;
  dayOffsetChanged: boolean;
}

interface ActualTimeMutationMeta {
  beforeNextTs: number;
  beforeNextName: string;
}


@Observed
export class TimelineViewModel {
  @Track public events: EventEntity[] = [];
  @Track public planId: number = -1;
  @Track public globalStartTime: string = '09:00';
  @Track public planStartDate: number = 0;
  @Track public isArchived: boolean = false;
  @Track public enableAutoAmapRoute: boolean = true;
  @Track public enableGlobalAmapRouteApi: boolean = false;
  @Track public groupedEvents: DateGroup[] = [];
  @Track public filterStart: number = 0;
  @Track public filterEnd: number = 0;
  @Track public conflictList: EventEntity[] = [];
  @Track public latestReflowHint: ReflowHint | null = null;
  @Track private scheduleVersion: number = 0;
  
  private hasLoggedLifecycleDetach: boolean = false;
  private actualTimeMutationInFlight: boolean = false;
  private hasUnsavedPostponeStorageKey: string = AppStorageKeys.HAS_UNSAVED_POSTPONE;
  private minEventDurationLimit: number = 30;
  @Track private idleGapDetectionEnabled: boolean = true;
  @Track private idleGapTriggerMinutes: number = 45;

  /**
   *
   */
  public setFilter(start: number, end: number) {
    this.filterStart = start;
    this.filterEnd = end;
    this.generateGroups(); // 重新分组
  }

  /**
   *
   */
  public clearFilter() {
    this.filterStart = 0;
    this.filterEnd = 0;
    this.generateGroups();
  }

  private markScheduleChanged(): void {
    this.scheduleVersion += 1;
  }

  public getScheduleVersion(): number {
    return this.scheduleVersion;
  }
  public getMinEventDurationLimit(): number {
    return this.minEventDurationLimit;
  }

  public setHasUnsavedPostponeStorageKey(key: string): void {
    this.hasUnsavedPostponeStorageKey = key && key.length > 0 ? key : AppStorageKeys.HAS_UNSAVED_POSTPONE;
  }

  private markHasUnsavedPostpone(): void {
    AppStorage.setOrCreate(this.hasUnsavedPostponeStorageKey, true);
  }

  private async applyRuntimeTransition(target: EventEntity, transition: 'START' | 'END' | 'SKIP' | 'REOPEN', timestamp: number): Promise<boolean> {
    if (!target || target.id <= 0 || this.planId <= 0) {
      return false;
    }
    const result = await EventDao.applyRuntimeTransition({
      planId: this.planId,
      eventId: target.id,
      transition: transition,
      timestamp: timestamp
    });
    if (!result.ok) {
      hilog.warn(0x0000, TAG, `[RUNTIME_TRANSITION][blocked] event=${target.id}, transition=${transition}, reason=${result.reason}`);
      return false;
    }
    target.actual_start_time = result.startTime;
    target.actual_end_time = result.endTime;
    target.completion_status = result.completionStatus;
    return true;
  }

  public async reloadMinEventDurationLimit(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      const value = await pref.getMinEventDuration();
      this.minEventDurationLimit = PreferenceManager.normalizeMinEventDuration(value);
      hilog.info(0x0000, TAG, `[SETTING_VM][min_duration_loaded] value=${this.minEventDurationLimit}`);
    } catch (error) {
      this.minEventDurationLimit = 30;
      hilog.warn(0x0000, TAG, `[SETTING_VM][min_duration_fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public isIdleGapDetectionEnabled(): boolean {
    return this.idleGapDetectionEnabled;
  }

  public getIdleGapTriggerMinutes(): number {
    return this.idleGapTriggerMinutes;
  }

  public async reloadIdleGapSettings(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      const enabled = await pref.getIdleGapDetectionEnabled();
      const threshold = await pref.getIdleGapTriggerMinutes();
      this.idleGapDetectionEnabled = enabled;
      this.idleGapTriggerMinutes = PreferenceManager.normalizeIdleGapTriggerMinutes(threshold);
      hilog.info(
        0x0000,
        TAG,
        `[SETTING_VM][idle_gap_loaded] enabled=${this.idleGapDetectionEnabled}, threshold=${this.idleGapTriggerMinutes}`
      );
    } catch (error) {
      this.idleGapDetectionEnabled = true;
      this.idleGapTriggerMinutes = 45;
      hilog.warn(0x0000, TAG, `[SETTING_VM][idle_gap_fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public async loadData(planId: number): Promise<void> {
    this.planId = planId;
    try {
      const results = await Promise.all([
        PlanDao.getPlanById(planId),
        EventDao.getAllEvents(this.planId)
      ]);

      const plan = results[0] as import('../model/entity/PlanDao').PlanItem | undefined;
      const rawEvents = results[1] as import('../model/interface/IStandardEvent').TravelPlanItem[];


      if (plan) {
        if (plan.startDate) {
          this.planStartDate = plan.startDate;
        }

        this.isArchived = (plan.status === 2);
        this.enableAutoAmapRoute = (plan.enableAutoAmapRoute ?? 1) === 1;
      }

      const entities = rawEvents.map(item => EventEntity.fromInterface(item, planId));
      this.events = entities;

      await this.reloadMinEventDurationLimit();
      await this.reloadIdleGapSettings();
      await this.reloadGlobalRouteApiSwitch();
      this.recalculate();
    } catch (err) {
      hilog.error(0x0000, TAG, `Load data failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 用户修改路程时间 (修复保存问题)
   */
  public updateCommute(index: number, newMinutes: number): void {
    if (index < 0 || index >= this.events.length) {
      return;
    }

    this.updateManualCommute(this.events[index], newMinutes);
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
      EventDao.updateSingleField(item.id, EventEntity.PRE_TRAVEL_MINUTES, safeMinutes, this.planId);
      EventDao.updateSingleField(item.id, EventEntity.IS_TRAVEL_MANUAL, 1, this.planId);
    }

    this.recalculateFromEventId(item.id);
  }

  public updateDuration(index: number, newDuration: number): void {
    if (index < 0 || index >= this.events.length) {
      return;
    }
    const item = this.events[index];
    item.duration = newDuration;
    this.recalculateFromEventId(item.id);
    if (item.id) {
      EventDao.updateSingleField(item.id, 'duration', newDuration, this.planId);
      void EventDao.updateTimelineConsistency(this.events.map(e => e.toInterface()), this.planId);
    }
  }

  public async moveEvent(index: number, direction: 'up' | 'down'): Promise<void> {
    if (index < 0 || index >= this.events.length) {
      return;
    }
    const source = this.events[index];
    if (source.status !== 1) {
      return;
    }

    const scheduleIndexes: number[] = [];
    this.events.forEach((item, idx) => {
      if (item.status === 1) {
        scheduleIndexes.push(idx);
      }
    });

    const currentSchedulePos = scheduleIndexes.indexOf(index);
    if (currentSchedulePos < 0) {
      return;
    }
    const targetSchedulePos = direction === 'up' ? currentSchedulePos - 1 : currentSchedulePos + 1;
    if (targetSchedulePos < 0 || targetSchedulePos >= scheduleIndexes.length) {
      return;
    }
    const targetIndex = scheduleIndexes[targetSchedulePos];

    const swappedEvents = [...this.events];
    const temp = swappedEvents[index];
    swappedEvents[index] = swappedEvents[targetIndex];
    swappedEvents[targetIndex] = temp;

    let order = 0;
    swappedEvents.forEach((item) => {
      if (item.status !== 1) {
        return;
      }
      item.sort_order = order;
      order += 100;
    });

    await EventDao.updateTimelineConsistency(swappedEvents.map(e => e.toInterface()), this.planId);
    this.events = swappedEvents;
    const recalculateStartIndex = Math.max(Math.min(index, targetIndex) - 1, 0);
    this.recalculateFromIndex(recalculateStartIndex);
  }

  public moveToSchedule(item: TravelPlanItem): void {

    // 我们需要在 this.events 里找到对应的 Entity
    const target = this.events.find(e => e.id === item.id);
    if (target) {
      target.status = 1;

      const scheduleItems = this.events.filter(e => e.status === 1);
      const maxSort = scheduleItems.reduce((max, cur) => cur.sort_order > max ? cur.sort_order : max, 0);
      target.sort_order = maxSort + 100;
      if (this.shouldAutoRouteForItem(target)) {
        target.pre_travel_min = -1;
      }
      this.recalculateFromEventId(target.id);
      this.save();
    }
  }

  // 兼容 Backlog 移除逻辑
  public moveToBacklog(item: TravelPlanItem | EventEntity): void {
    const target = this.events.find(e => e.id === item.id);
    if (target) {
      const previousIndex = this.events.indexOf(target);
      target.status = 0;
      target.sort_order = 0;
      this.recalculateFromIndex(previousIndex > 0 ? previousIndex - 1 : 0);
      this.save();
    }
  }

  public fixConflict(item: TravelPlanItem | EventEntity, shiftMinutes: number) {
    const target = this.events.find(e => e.id === item.id);
    if (target && target.fixed_start_time) {
      const currentMin = DateUtil.timeToMinutes(target.fixed_start_time);
      const newMin = currentMin + shiftMinutes;
      const h = Math.floor(newMin / 60) % 24;
      const m = newMin % 60;
      const newTimeStr = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;

      target.fixed_start_time = newTimeStr;
      this.recalculateFromEventId(target.id);
      if (target.id) {
        EventDao.updateSingleField(target.id, 'fixed_start_time', newTimeStr, this.planId);
      }
    }
  }


  // 文件路径: ets/viewmodel/TimelineViewModel.ets

  /**
   * [节点 3A] 新增地点入库
   */
  public async addNewItem(name: string, duration: number, isSchedule: boolean = false, fixedTime?: string,
    dayOffset: number = 0, preTravel: number = -1, isHardLock: boolean = false, note: string = '', priority: number = 0,
    lat?: number, lng?: number
  ) {

    hilog.info(0x0000, TAG, `[节点3A: 准备新增入库] -> 地点: ${name}, lat: ${lat}, lng: ${lng}`);

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
      latitude: lat || 0,
      longitude: lng || 0
    };

    const newId = await EventDao.insertEvent(this.planId, newItemInterface);
    newItemInterface.id = newId;

    const newEntity = EventEntity.fromInterface(newItemInterface, this.planId);
    if (isSchedule) {
      this.insertSmart(newEntity);
      if (newEntity.pre_travel_min < 0 && !this.shouldAutoRouteForItem(newEntity)) {
        newEntity.pre_travel_min = 0;
      }
    } else {
      this.events.push(newEntity);
    }

    this.recalculateFromEventId(newEntity.id);
  }
  public async save(): Promise<void> {
    if (this.planId === -1) {
      return;
    }

    const payload = this.events.map(e => e.toInterface());
    const idPreview = payload.map(item => item.id || -1).slice(0, 20).join(',');
    const idSuffix = payload.length > 20 ? `...(+${payload.length - 20})` : '';
    hilog.info(0x0000, TAG, `[ID_FIX][VM_SAVE_TRIGGER] planId=${this.planId} count=${payload.length} ids=[${idPreview}]${idSuffix}`);
    await EventDao.saveAllEvents(this.planId, payload);
  }

  // TimelineViewModel.ets 内部修改/替换原有冲突处理方法

  /**
   *
   */
  public async resolveConflictByBacklog(id: number, name: string, duration: number, note: string = '', priority: number = 0) {
    if (id !== -1) {


      const target = this.events.find(e => e.id === id);
      if (target) {
        target.status = 0; // 回归暂存
        target.day_offset = 0;
        target.dynamic_day_offset = 0;
        target.fixed_start_time = '';
        await this.updateEventInfo(id, name, duration, undefined, 0, false, note, priority);
      }
    } else {

      await this.addNewItem(name, duration, false, undefined, 0, 0, false, note, priority);
    }

  }

  /**
   *
   * 既然该地点早于原计划，我们将计划起点平移到该地点的日期，该地点的 offset 变为 0
   */
  public async resolveConflictByMovingPlan(id: number, targetDateMs: number, name: string, duration: number, isSchedule: boolean,
    fixedTime?: string, note: string = '', priority: number = 0) {

    // 1. 全局平移计划起点
    await this.updatePlanDate(targetDateMs);

    // 2. 判断更新还是新增
    if (id !== -1) {

      await this.updateEventInfo(id, name, duration, fixedTime, 0, false, note, priority);
    } else {
      await this.addNewItem(name, duration, isSchedule, fixedTime, 0, -1, false, note, priority);
    }
  }

  // path: ets/viewmodel/TimelineViewModel.ets


  /** [测试功能] 强制全量重算所有路线 */
  public testAllCommute() {
    this.events.forEach((item, index) => {
      if (item.status === 1 && index > 0) {
        if (this.shouldAutoRouteForItem(item)) {
          item.pre_travel_min = -1;
        }
      }
    });
    this.recalculate(); // 触发 Solver 调用 TrafficEngine
  }


  /**
   *
   */
  public updateTravelMode(item: EventEntity, newMode: number) {
    if (!item) return;


    hilog.info(0x0000, TAG, `[VM层] 接收到模式切换 -> ${item.name} 切换为: ${newMode}`);


    item.travel_mode = newMode;
    item.transport_mode = newMode;
    item.is_travel_manual = 0;
    if (this.shouldAutoRouteForItem(item)) {
      item.pre_travel_min = -1; // 触发 Loading
    } else if (item.pre_travel_min < 0) {
      item.pre_travel_min = 0;
    }


    if (item.id) {
      import('../model/entity/EventDao').then(m => {
        m.EventDao.updateSingleField(item.id, EventEntity.TRAVEL_MODE, newMode, this.planId);
        m.EventDao.updateSingleField(item.id, EventEntity.IS_TRAVEL_MANUAL, 0, this.planId);
        m.EventDao.updateSingleField(item.id, EventEntity.PRE_TRAVEL_MINUTES, item.pre_travel_min, this.planId);
      });
    }


    this.recalculateFromEventId(item.id);
  }

  /** [测试功能] 针对单项进行路程刷新 */
  public testSingleCommute(item: EventEntity) {
    if (this.shouldAutoRouteForItem(item)) {
      item.pre_travel_min = -1;
    }
    this.recalculateFromEventId(item.id);
  }

  private getEffectiveDayOffset(item: EventEntity): number {
    return TimelineDatePolicy.resolveEventDayOffset(item);
  }

  private completionStatusLabel(status: number): string {
    if (status === EventEntity.STATE_COMPLETED) {
      return 'COMPLETED';
    }
    if (status === EventEntity.STATE_SKIPPED) {
      return 'SKIPPED';
    }
    return 'PENDING';
  }

  private buildTimelineSnapshot(limit: number = 6): string {
    const schedule = this.events
      .filter(e => e.status === 1)
      .slice(0, limit)
      .map((e, idx) => {
        const forecastStart = e.forecast_start_time || '--:--';
        const forecastEnd = e.forecast_end_time || '--:--';
        return `${idx + 1}:${e.id}/${e.name}|${this.completionStatusLabel(e.completion_status)}|f=${forecastStart}-${forecastEnd}|aS=${e.actual_start_time}|aE=${e.actual_end_time}`;
      });

    if (schedule.length === 0) {
      return 'empty';
    }
    return schedule.join('; ');
  }

  private buildScheduleOrderSnapshot(limit: number = 12): string {
    const schedule = this.events
      .filter(e => e.status === 1)
      .slice(0, limit)
      .map((e, idx) => `${idx + 1}:${e.id}/${e.name}[base=${e.day_offset},dyn=${e.dynamic_day_offset},fix=${e.fixed_start_time || '--'},sort=${e.sort_order}]`);

    if (schedule.length === 0) {
      return 'empty';
    }
    return schedule.join('; ');
  }

  private logTimelineSnapshot(scene: string): void {
    hilog.info(0x0000, TAG, `[DUAL_MODE_ACCEPT][snapshot][${scene}] ${this.buildTimelineSnapshot()}`);
  }

  private resolveRecalculateStartIndexByEventId(eventId: number): number {
    if (eventId <= 0) {
      return 0;
    }
    const index = this.events.findIndex((event: EventEntity) => event.id === eventId);
    if (index < 0) {
      return 0;
    }
    return index > 0 ? index - 1 : 0;
  }

  private shouldPersistAutoPreTravel(entity: EventEntity, minutes: number): boolean {
    if (!entity || entity.id <= 0 || this.planId <= 0) {
      return false;
    }
    if (entity.status !== 1 || entity.is_travel_manual === 1) {
      return false;
    }
    if (!this.shouldAutoRouteForItem(entity)) {
      return false;
    }
    return Number.isFinite(minutes) && minutes >= 0;
  }

  private persistAutoPreTravel(entity: EventEntity, minutes: number): void {
    if (!this.shouldPersistAutoPreTravel(entity, minutes)) {
      return;
    }
    const updates: EventFieldUpdate[] = [
      { column: EventEntity.PRE_TRAVEL_MINUTES, value: minutes },
      { column: EventEntity.IS_TRAVEL_MANUAL, value: 0 }
    ];
    void EventDao.updateFields(entity.id, updates, this.planId);
  }

  private applyCalculatedResult(entity: EventEntity, resultItem: SolverCalculatedItem | undefined): ApplyResultFlags {
    let changed = false;
    let dayOffsetChanged = false;

    if (resultItem) {
      const nextConflict = resultItem.isConflict || false;
      if (entity.is_conflict !== nextConflict) {
        entity.is_conflict = nextConflict;
        changed = true;
      }
      const nextConflictMsg = resultItem.conflictMsg || '';
      if (entity.conflict_msg !== nextConflictMsg) {
        entity.conflict_msg = nextConflictMsg;
        changed = true;
      }

      if (resultItem.computedStartTime && entity.computed_time !== resultItem.computedStartTime) {
        entity.computed_time = resultItem.computedStartTime;
        changed = true;
      }

      if (resultItem.preTravelMinutes !== undefined && entity.pre_travel_min !== resultItem.preTravelMinutes) {
        entity.pre_travel_min = resultItem.preTravelMinutes;
        this.persistAutoPreTravel(entity, resultItem.preTravelMinutes);
        changed = true;
      }

      const nextHasGap = resultItem.hasGap || false;
      if (entity.has_gap !== nextHasGap) {
        entity.has_gap = nextHasGap;
        changed = true;
      }
      const nextGapMinutes = resultItem.gapMinutes || 0;
      if (entity.gap_minutes !== nextGapMinutes) {
        entity.gap_minutes = nextGapMinutes;
        changed = true;
      }
      const nextNaturalStart = resultItem.naturalStartTime || '';
      if (entity.natural_start_time !== nextNaturalStart) {
        entity.natural_start_time = nextNaturalStart;
        changed = true;
      }
      const nextTransitWarning = resultItem.transitWarning || false;
      if (entity.transit_warning !== nextTransitWarning) {
        entity.transit_warning = nextTransitWarning;
        changed = true;
      }

      const dynamicDayOffset = resultItem.dynamicDayOffset ?? resultItem.dayOffset ?? entity.day_offset;
      if (entity.dynamic_day_offset !== dynamicDayOffset) {
        entity.dynamic_day_offset = dynamicDayOffset;
        changed = true;
        dayOffsetChanged = true;
      }
      if (entity.day_offset !== dynamicDayOffset) {
        hilog.info(
          0x0000,
          TAG,
          `[DAY_SHIFT_FIX][solver_reconcile] id=${entity.id}, name=${entity.name}, base=${entity.day_offset}, dynamic=${dynamicDayOffset}`
        );
      }
      return {
        changed: changed,
        dayOffsetChanged: dayOffsetChanged
      };
    }

    if (entity.status === 0) {
      if (entity.is_conflict) {
        entity.is_conflict = false;
        changed = true;
      }
      if (entity.computed_time !== '') {
        entity.computed_time = '';
        changed = true;
      }
      if (entity.has_gap) {
        entity.has_gap = false;
        changed = true;
      }
      if (entity.gap_minutes !== 0) {
        entity.gap_minutes = 0;
        changed = true;
      }
      if (entity.natural_start_time !== '') {
        entity.natural_start_time = '';
        changed = true;
      }
      if (entity.transit_warning) {
        entity.transit_warning = false;
        changed = true;
      }
      if (entity.dynamic_day_offset !== entity.day_offset) {
        entity.dynamic_day_offset = entity.day_offset;
        changed = true;
        dayOffsetChanged = true;
      }
    }

    return {
      changed: changed,
      dayOffsetChanged: dayOffsetChanged
    };
  }

  public recalculateFromEventId(eventId: number): void {
    const startIndex = this.resolveRecalculateStartIndexByEventId(eventId);
    this.recalculateFromIndex(startIndex);
  }

  private resolveScheduleAnchorEventId(startIndex: number): number {
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    for (let i = safeStartIndex; i < this.events.length; i++) {
      const item = this.events[i];
      if (item.status === 1 && item.id > 0) {
        return item.id;
      }
    }
    return -1;
  }

  public recalculateFromIndex(startIndex: number): void {
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    const inputList = this.events.map(e => e.toInterface());
    const globalStartCandidate = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';
    const startFromEventId = this.resolveScheduleAnchorEventId(safeStartIndex);

    const calculated = TimeConstraintSolver.calculateTimeline(
      inputList,
      effectiveGlobalStart,
      this.planStartDate,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes,
        startFromEventId: startFromEventId
      }
    );

    let hasFieldChanged = false;
    let hasDayOffsetChanged = false;
    this.events.forEach((entity: EventEntity, index: number) => {
      if (index < safeStartIndex) {
        return;
      }
      const flags = this.applyCalculatedResult(entity, calculated[index] as SolverCalculatedItem | undefined);
      if (flags.changed) {
        hasFieldChanged = true;
      }
      if (flags.dayOffsetChanged) {
        hasDayOffsetChanged = true;
      }
    });

    if (!hasFieldChanged && !hasDayOffsetChanged) {
      return;
    }

    this.calculateRealtimeSchedule();
    if (hasDayOffsetChanged) {
      this.generateGroups();
      this.markScheduleChanged();
    }
    this.events = [...this.events];
  }

  public recalculate(): void {
    // 1. 准备输入
    const inputList = this.events.map(e => e.toInterface());
    const globalStartCandidate = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    if (!this.hasLoggedLifecycleDetach) {
      hilog.info(0x0000, TAG, '[LIFECYCLE_GUARD] recalculate uses context-free solver path.');
      this.hasLoggedLifecycleDetach = true;
    }
    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][recalculate_input] globalStart=${this.globalStartTime}, effectiveStart=${effectiveGlobalStart}, planStartDate=${this.planStartDate}, total=${inputList.length}`
    );
    const calculated = TimeConstraintSolver.calculateTimeline(
      inputList,
      effectiveGlobalStart,
      this.planStartDate,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes
      }
    );


    let hasFieldChanged = false;
    let hasDayOffsetChanged = false;
    this.events.forEach((entity, index) => {
      const flags = this.applyCalculatedResult(entity, calculated[index] as SolverCalculatedItem | undefined);
      if (flags.changed) {
        hasFieldChanged = true;
      }
      if (flags.dayOffsetChanged) {
        hasDayOffsetChanged = true;
      }
    });

    // 4. 先更新预测字段，确保分组可使用最新 dynamic_start_time 作为现实锚点
    this.calculateRealtimeSchedule();

    // 5. 重新生成 Day 分组
    this.generateGroups();

    // 6. 刷新 UI
    this.markScheduleChanged();
    if (hasFieldChanged || hasDayOffsetChanged) {
      this.events = [...this.events];
    }
    this.logTimelineSnapshot('recalculate');
  }

  public recalculateTrafficOnly(): void {
    const inputList = this.events.map(e => e.toInterface());
    const globalStartCandidate = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = TimeConstraintSolver.calculateTimeline(
      inputList,
      effectiveGlobalStart,
      this.planStartDate,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes
      }
    );

    let hasChanged = false;
    let hasDayOffsetChanged = false;
    this.events.forEach((entity, index) => {
      const resultItem = calculated[index];
      if (!resultItem) {
        return;
      }

      if (resultItem.preTravelMinutes !== undefined && entity.pre_travel_min !== resultItem.preTravelMinutes) {
        entity.pre_travel_min = resultItem.preTravelMinutes;
        this.persistAutoPreTravel(entity, resultItem.preTravelMinutes);
        hasChanged = true;
      }
      if (resultItem.computedStartTime && entity.computed_time !== resultItem.computedStartTime) {
        entity.computed_time = resultItem.computedStartTime;
        hasChanged = true;
      }
      const dynamicDayOffset = resultItem.dynamicDayOffset ?? resultItem.dayOffset ?? entity.day_offset;
      if (entity.dynamic_day_offset !== dynamicDayOffset) {
        entity.dynamic_day_offset = dynamicDayOffset;
        hasChanged = true;
        hasDayOffsetChanged = true;
      }
    });

    if (!hasChanged) {
      return;
    }

    this.calculateRealtimeSchedule();
    if (hasDayOffsetChanged) {
      this.generateGroups();
      this.markScheduleChanged();
    }
    this.events = [...this.events];
  }


  public resolveGapBySync(item: EventEntity) {
    if (item.natural_start_time) {
      this.updateEventInfo(item.id, item.name, item.duration, item.natural_start_time, item.day_offset);
    }
  }

  /** [选项 C] 临时提前：本次运行不等待，直接开始 */
  public resolveGapByIgnore(item: EventEntity) {
    item.is_ignore_wait = true;
    this.recalculateFromEventId(item.id);
  }

  private generateGroups() {
    this.groupedEvents = [];
    const planBaseDayMs = TimelineDatePolicy.toDayStartMs(this.planStartDate > 0 ? this.planStartDate : Date.now());

    const scheduleEvents = this.events
      .filter(e => e.status === 1)
      .sort((a, b) => {
        const dayOffsetA = this.getEffectiveDayOffset(a);
        const dayOffsetB = this.getEffectiveDayOffset(b);
        if (dayOffsetA !== dayOffsetB) {
          return dayOffsetA - dayOffsetB;
        }
        return a.sort_order - b.sort_order;
      });

    if (scheduleEvents.length === 0) {
      return;
    }

    let currentGroup: DateGroup | null = null;
    let lastDayOffset = Number.MIN_SAFE_INTEGER;
    let visibleDayIndex = 0;

    scheduleEvents.forEach((item) => {
      const renderDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      // 单一基准：分组键与日期头都严格使用 dynamic_day_offset，
      // 避免长时长或伴游预测导致的“组键与日期头锚点不一致”。
      const itemDateMs = TimelineDatePolicy.dayOffsetToDayStartMs(planBaseDayMs, renderDayOffset);


      if (this.filterStart > 0 && (itemDateMs < this.filterStart || itemDateMs > this.filterEnd)) {
        return;
      }

      // 新日期组：只对“实际存在的日期组”做连续编号
      if (renderDayOffset !== lastDayOffset) {
        const groupDate = new Date(itemDateMs);

        visibleDayIndex += 1;

        const dateStr = DateUtil.formatDate(groupDate, "MM月dd日");
        let headerStr = `Day ${visibleDayIndex} (${dateStr})`;

        if (renderDayOffset < 0) {
          headerStr = `待定/冲突 (${renderDayOffset}天前)`;
        }

        currentGroup = {
          dateHeader: headerStr,
          dayIndex: visibleDayIndex,
          dayOffset: renderDayOffset,
          actualDateMs: itemDateMs,
          events: []
        };
        hilog.info(
          0x0000,
          TAG,
          `[DAY_SHIFT_FIX][group_anchor] mode=offset_only, dayOffset=${renderDayOffset}, header=${headerStr}, eventId=${item.id}, eventName=${item.name}, dynamicStart=${item.dynamic_start_time}, actualStart=${item.actual_start_time}`
        );

        this.groupedEvents.push(currentGroup);
        lastDayOffset = renderDayOffset;
      }

      if (currentGroup) {
        currentGroup.events.push(item);
      }
    });
  }


  /**
   * [交互升级] 物理删除 (右滑)
   * 彻底从数据库移除
   */
  public async hardDelete(item: EventEntity) {
    // 1. 内存移除
    const index = this.events.indexOf(item);
    if (index !== -1) {
      this.events.splice(index, 1);
    }


    if (item.id) {
      await EventDao.hardDeleteEvent(item.id);
    }

    // 3. 触发刷新
    this.recalculateFromIndex(index > 0 ? index - 1 : 0);
  }

  // 文件路径: ets/viewmodel/TimelineViewModel.ets

  /**
   * [节点 3B] 更新地点入库
   */
  public async updateEventInfo(id: number, name: string, duration: number, fixedTime?: string, dayOffset: number = 0,
    isHardLock: boolean = false, note: string = '', priority: number = 0,
    lat?: number, lng?: number
  ) {

    hilog.info(0x0000, TAG, `[节点3B: 准备更新入库] -> 地点: ${name}(ID:${id}), lat: ${lat}, lng: ${lng}`);

    const target = this.events.find(e => e.id === id);
    if (!target) return;

    const oldStatus = target.status;
    const oldTime = target.fixed_start_time;
    const oldDayOffset = target.day_offset;
    const oldName = target.name;
    const oldLat = target.latitude;
    const oldLng = target.longitude;
    const dayOffsetChanged = oldDayOffset !== dayOffset;
    const nextLat = (lat !== undefined && lat !== 0) ? lat : oldLat;
    const nextLng = (lng !== undefined && lng !== 0) ? lng : oldLng;
    const placeChanged = oldName !== name || oldLat !== nextLat || oldLng !== nextLng;

    if (dayOffsetChanged) {
      hilog.info(
        0x0000,
        TAG,
        `[DAY_SHIFT_FIX][update_day_offset][begin] id=${id}, name=${name}, oldDayOffset=${oldDayOffset}, newDayOffset=${dayOffset}, orderBefore=${this.buildScheduleOrderSnapshot()}`
      );
    }

    // 1. 更新内存
    target.name = name;
    target.duration = duration;
    target.note = note;
    target.day_offset = dayOffset;
    target.dynamic_day_offset = dayOffset;
    target.priority = priority;
    if (lat !== undefined && lat !== 0) target.latitude = lat;
    if (lng !== undefined && lng !== 0) target.longitude = lng;

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
      if (lat !== undefined && lat !== 0) {
        updates.push({ column: 'latitude', value: lat });
      }
      if (lng !== undefined && lng !== 0) {
        updates.push({ column: 'longitude', value: lng });
      }
      await EventDao.updateFields(target.id, updates, this.planId);
      hilog.info(0x0000, TAG, `[节点3B: 准备更新入库] -> 地点: ${name}(ID:${id}), lat: ${lat}, lng: ${lng}`);
    }

    // 3. 逻辑联动：处理状态变更、时间变动或 day_offset 变动
    const shouldReinsert = ((oldStatus === 0 && target.status === 1) || (fixedTime && fixedTime !== oldTime) ||
      (dayOffsetChanged && target.status === 1));
    if (shouldReinsert) {
      const currentIndex = this.events.indexOf(target);
      if (currentIndex >= 0) {
        this.events.splice(currentIndex, 1);
      }
      this.insertSmart(target);
      hilog.info(
        0x0000,
        TAG,
        `[DAY_SHIFT_FIX][reinsert_done] id=${id}, name=${name}, reason=status_or_time_or_day_offset, newIndex=${this.events.indexOf(target)}, orderAfter=${this.buildScheduleOrderSnapshot()}`
      );
      await EventDao.updateTimelineConsistency(this.events.map(e => e.toInterface()), this.planId);
    } else if (dayOffsetChanged) {
      hilog.info(
        0x0000,
        TAG,
        `[DAY_SHIFT_FIX][update_day_offset][skip_reinsert] id=${id}, name=${name}, status=${target.status}`
      );
    }

    this.recalculateFromEventId(id);
  }
  private parseConflictMinutes(conflictMsg: string): number {
    const match = conflictMsg ? conflictMsg.match(/(\d+)/) : null;
    if (!match || match.length < 2) {
      return 0;
    }

    const parsed = Number.parseInt(match[1], 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }

  public previewPlanDateShift(newDateTimestamp: number): PlanDateShiftPreview {
    const nextDate = new Date(newDateTimestamp);
    nextDate.setHours(0, 0, 0, 0);
    const normalizedTimestamp = nextDate.getTime();

    const globalStartCandidate = DateUtil.extractPureTime(this.globalStartTime) || this.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = TimeConstraintSolver.calculateTimeline(
      this.events.map(e => e.toInterface()),
      effectiveGlobalStart,
      normalizedTimestamp,
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.idleGapTriggerMinutes
      }
    );

    for (let index = 0; index < this.events.length; index++) {
      const sourceItem = this.events[index];
      const resultItem = calculated[index];
      if (!sourceItem || !resultItem) {
        continue;
      }

      if (sourceItem.status !== 1 || sourceItem.lock_status !== 1) {
        continue;
      }

      if (!resultItem.isConflict) {
        continue;
      }

      const gapMinutes = (resultItem.gapMinutes && resultItem.gapMinutes > 0)
        ? resultItem.gapMinutes
        : this.parseConflictMinutes(resultItem.conflictMsg || '');

      hilog.warn(
        0x0000,
        TAG,
        `[SHIFT_VM][preview_conflict] targetDate=${normalizedTimestamp}, eventId=${sourceItem.id}, eventName=${sourceItem.name}, gapMinutes=${gapMinutes}, msg=${resultItem.conflictMsg || ''}`
      );

      return {
        hasRigidConflict: true,
        conflictItemId: sourceItem.id,
        conflictItemName: sourceItem.name,
        gapMinutes: gapMinutes,
        conflictMsg: resultItem.conflictMsg || ''
      };
    }

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][preview_ok] targetDate=${normalizedTimestamp}, eventCount=${this.events.length}`
    );

    return {
      hasRigidConflict: false,
      conflictItemId: -1,
      conflictItemName: '',
      gapMinutes: 0,
      conflictMsg: ''
    };
  }
  /**
   * [Priority 4] 修改计划出发日期 (整体平移)
   */
  public async updatePlanDate(newDateTimestamp: number) {
    const nextDate = new Date(newDateTimestamp);
    nextDate.setHours(0, 0, 0, 0);
    const normalizedTimestamp = nextDate.getTime();

    const oldPlanStartDate = this.planStartDate;
    this.planStartDate = normalizedTimestamp;

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][apply_plan_date] oldPlanStartDate=${oldPlanStartDate}, newPlanStartDate=${normalizedTimestamp}`
    );

    if (this.planId !== -1) {
      await PlanDao.updateStartDate(this.planId, normalizedTimestamp);
    }

    // 仅计划基准日期变更时，无需重新求解整条时间链；刷新绝对时间与分组即可
    this.calculateRealtimeSchedule();
    this.generateGroups();
    this.markScheduleChanged();
    this.events = [...this.events];

    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][apply_plan_date_done] planId=${this.planId}, groups=${this.groupedEvents.length}`
    );
  }

  /**
   *
   */
  public async renamePlan(newName: string) {
    if (this.planId === -1) {
      return;
    }


    await PlanDao.updatePlanName(this.planId, newName);



  }

  public async updatePlanAutoAmapRoute(enabled: boolean): Promise<void> {
    const previousEnabled = this.enableAutoAmapRoute;
    this.enableAutoAmapRoute = enabled;
    let hasLocalFieldChanged = false;
    if (!enabled) {
      this.events.forEach((item) => {
        if (item.pre_travel_min < 0 && item.is_travel_manual !== 1) {
          item.pre_travel_min = 0;
          hasLocalFieldChanged = true;
        }
      });
    }
    if (this.planId !== -1) {
      await PlanDao.updateAutoAmapRoute(this.planId, enabled);
    }
    if (previousEnabled !== enabled || hasLocalFieldChanged) {
      this.recalculateFromIndex(0);
    }
  }



  /**
   *
   *
   */
  public isDateConflict(targetDateMs: number): boolean {
    if (this.planStartDate <= 0) {
      return false;
    }


    const targetDay = new Date(targetDateMs).setHours(0, 0, 0, 0);
    const planDay = new Date(this.planStartDate).setHours(0, 0, 0, 0);

    return targetDay < planDay;
  }



  /**
   *
   *
   *
   * @returns 是否存在风险
   */
  public checkDistributionRisk(gapItem: EventEntity, distributionMap: Map<number, number>): boolean {
    if (distributionMap.size === 0) return false;

    // 1. 确定受影响的范围：从最早被分配的地点到 gapItem 之前
    const allSchedule = this.events.filter(e => e.status === 1);
    const gapIndex = allSchedule.indexOf(gapItem);


    let firstModifiedIdx = gapIndex;
    distributionMap.forEach((_, id) => {
      const idx = allSchedule.findIndex(e => e.id === id);
      if (idx < firstModifiedIdx) firstModifiedIdx = idx;
    });

    // 2. 模拟推演
    let accumulatedAdd = 0;
    for (let i = firstModifiedIdx; i < gapIndex; i++) {
      const current = allSchedule[i];
      accumulatedAdd += (distributionMap.get(current.id) || 0);


      const nextItem = allSchedule[i + 1];
      if (nextItem && nextItem.lock_status === 1) {


        if (accumulatedAdd > nextItem.gap_minutes) {
          return true; // 触发预警
        }
      }
    }
    return false;
  }


  public async resolveConflictBySyncItem(name: string, duration: number, isSchedule: boolean, fixedTime?: string, note: string = '') {
    // 透传 note
    await this.addNewItem(name, duration, isSchedule, fixedTime, 0, -1, false, note);
  }

  public async resolveConflictByKeepDraft(name: string, duration: number,  isSchedule: boolean,
    fixedTime: string | undefined, negativeOffset: number, note: string = '') {
    // 透传 note
    await this.addNewItem(name, duration, false, fixedTime, negativeOffset, -1, false, note);
  }




  public async smartFixConflict(targetItem: EventEntity) {
    if (!targetItem || !targetItem.is_conflict) {
      return;
    }

    const index = this.events.indexOf(targetItem);
    if (index === -1) {
      return;
    }

    // =========================================================
    // 策略 A: 硬锚点保卫战 (尝试压缩前序)
    // =========================================================
    if (targetItem.lock_status === 1 && targetItem.fixed_start_time) {
      console.info(TAG, `SmartFix: 检测到刚性冲突 [${targetItem.name}]，尝试反向压缩...`);

      const plan = this.calculateCompressionPlan(index, targetItem.fixed_start_time);


      if (plan.status === 'NO_ACTION' || plan.status === 'COMPRESS_CONFIRM') {
        if (plan.status === 'COMPRESS_CONFIRM') {
          this.applyCompressionPlan(plan);
        }
        this.markHasUnsavedPostpone();
        return;
      }


      // ⚠️ 修改点：刚性逻辑下，压缩失败就是失败，禁止降级去改时间！
      console.warn(TAG, `SmartFix: 刚性冲突且无法压缩，修复失败。请用户手动调整。`);
      return;
    }
  }

  public calculateCompressionPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    const context = this.buildCompressionSelectionContext(targetIndex, newTimeStr);
    if (!context || context.neededGapMinutes <= 0) {
      return { status: 'NO_ACTION', msg: '时间充裕', affectedItems: [] };
    }

    const selectedIds = new Set<number>();
    context.candidates.forEach((candidate) => {
      if (candidate.selectable) {
        selectedIds.add(candidate.id);
      }
    });
    return this.calculateCompressionPlanBySelection(targetIndex, newTimeStr, selectedIds, 'RATIO');
  }

  private resolveCompressionChainStart(targetIndex: number): number {
    let chainStartIndex = 0;
    for (let i = targetIndex - 1; i >= 0; i--) {
      const item = this.events[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        chainStartIndex = i;
        break;
      }
    }
    return chainStartIndex;
  }

  private buildCompressionSelectionContextInternal(targetIndex: number, targetTime: string): CompressionSelectionContext | null {
    if (targetIndex <= 0 || !this.events[targetIndex]) {
      return null;
    }
    if (!DateUtil.isValidTimeString(targetTime)) {
      return null;
    }

    const naturalArrivalMinutes = this._calculateNaturalArrival(targetIndex);
    const targetMinutes = DateUtil.timeToMinutes(targetTime);
    const targetDayOffset = this.getEffectiveDayOffset(this.events[targetIndex]);
    const neededGapMinutes = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);
    const chainStartIndex = this.resolveCompressionChainStart(targetIndex);
    const minKeepDuration = this.getMinEventDurationLimit();

    const candidates: CompressionSelectionCandidate[] = [];
    for (let i = 0; i < targetIndex; i++) {
      const item = this.events[i];
      if (item.status !== 1) {
        continue;
      }

      const minAllowed = Math.min(item.duration, minKeepDuration);
      const maxReducible = Math.max(0, item.duration - minAllowed);
      const isRigid = item.lock_status === 1;
      const withinActiveChain = i >= chainStartIndex;
      let selectable = !isRigid && withinActiveChain && maxReducible > 0;
      let disabledReason = '';

      if (isRigid) {
        disabledReason = '刚性地点不可压缩';
      } else if (!withinActiveChain) {
        disabledReason = '受前序刚性锚点阻断';
      } else if (maxReducible <= 0) {
        disabledReason = `已达到最短停留 ${minKeepDuration} 分钟`;
      }

      candidates.push({
        index: i,
        id: item.id,
        name: item.name,
        oldVal: item.duration,
        minAllowed: minAllowed,
        maxReducible: maxReducible,
        isRigid: isRigid,
        selectable: selectable,
        disabledReason: disabledReason
      });
    }

    return {
      targetIndex: targetIndex,
      targetTime: targetTime,
      neededGapMinutes: neededGapMinutes,
      naturalArrivalMinutes: naturalArrivalMinutes,
      chainStartIndex: chainStartIndex,
      candidates: candidates
    };
  }

  public buildCompressionSelectionContext(targetIndex: number, targetTime: string): CompressionSelectionContext | null {
    return this.buildCompressionSelectionContextInternal(targetIndex, targetTime);
  }

  private buildCompressionAffectedItems(selected: CompressionSelectionCandidate[], reducedMap: Map<number, number>): GeneratedTypeLiteralInterface_7[] {
    const affected: GeneratedTypeLiteralInterface_7[] = [];
    selected.forEach((candidate) => {
      const reduced = reducedMap.get(candidate.id) ?? 0;
      if (reduced <= 0) {
        return;
      }
      affected.push({
        index: candidate.index,
        name: candidate.name,
        oldVal: candidate.oldVal,
        newVal: candidate.oldVal - reduced
      });
    });
    return affected;
  }

  public calculateCompressionPlanBySelection(targetIndex: number, targetTime: string, selectedIds: Set<number>,
    mode: CompressionMode = 'RATIO'): CompressionPlan {
    const context = this.buildCompressionSelectionContextInternal(targetIndex, targetTime);
    if (!context) {
      return { status: 'NO_ACTION', msg: '无需操作', affectedItems: [], mode: mode };
    }
    if (context.neededGapMinutes <= 0) {
      return { status: 'NO_ACTION', msg: '时间充裕', affectedItems: [], mode: mode };
    }

    const selected = context.candidates.filter((candidate) => selectedIds.has(candidate.id) && candidate.selectable);
    if (selected.length === 0) {
      return {
        status: 'OVERLOAD',
        msg: '请先选择至少一个可压缩地点',
        affectedItems: [],
        suggestedTime: DateUtil.minutesToTime(context.naturalArrivalMinutes),
        remainingGapMinutes: context.neededGapMinutes,
        capacityMinutes: 0,
        mode: mode
      };
    }

    const remainingCapMap = new Map<number, number>();
    const reducedMap = new Map<number, number>();
    const weightMap = new Map<number, number>();
    let capacityMinutes = 0;
    selected.forEach((candidate) => {
      remainingCapMap.set(candidate.id, candidate.maxReducible);
      reducedMap.set(candidate.id, 0);
      weightMap.set(candidate.id, Math.max(1, candidate.oldVal));
      capacityMinutes += candidate.maxReducible;
    });

    let remainingNeed = context.neededGapMinutes;

    if (mode === 'EQUAL') {
      let progressed = true;
      while (remainingNeed > 0 && progressed) {
        progressed = false;
        for (let i = 0; i < selected.length; i++) {
          if (remainingNeed <= 0) {
            break;
          }
          const id = selected[i].id;
          const cap = remainingCapMap.get(id) ?? 0;
          if (cap <= 0) {
            continue;
          }
          remainingCapMap.set(id, cap - 1);
          reducedMap.set(id, (reducedMap.get(id) ?? 0) + 1);
          remainingNeed--;
          progressed = true;
        }
      }
    } else {
      let activeIds = selected.map((candidate) => candidate.id);
      while (remainingNeed > 0 && activeIds.length > 0) {
        let totalWeight = 0;
        activeIds.forEach((id) => {
          totalWeight += (weightMap.get(id) ?? 0);
        });
        if (totalWeight <= 0) {
          break;
        }

        let allocatedThisRound = 0;
        const nextActiveIds: number[] = [];
        for (let i = 0; i < activeIds.length; i++) {
          const id = activeIds[i];
          const cap = remainingCapMap.get(id) ?? 0;
          if (cap <= 0) {
            continue;
          }
          const share = Math.floor(remainingNeed * ((weightMap.get(id) ?? 0) / totalWeight));
          const grant = Math.min(cap, Math.max(share, 0));
          if (grant > 0) {
            remainingCapMap.set(id, cap - grant);
            reducedMap.set(id, (reducedMap.get(id) ?? 0) + grant);
            remainingNeed -= grant;
            allocatedThisRound += grant;
          }
          if ((remainingCapMap.get(id) ?? 0) > 0) {
            nextActiveIds.push(id);
          }
        }

        if (allocatedThisRound === 0) {
          const sorted = [...activeIds].sort((a, b) => (weightMap.get(b) ?? 0) - (weightMap.get(a) ?? 0));
          for (let i = 0; i < sorted.length; i++) {
            if (remainingNeed <= 0) {
              break;
            }
            const id = sorted[i];
            const cap = remainingCapMap.get(id) ?? 0;
            if (cap <= 0) {
              continue;
            }
            remainingCapMap.set(id, cap - 1);
            reducedMap.set(id, (reducedMap.get(id) ?? 0) + 1);
            remainingNeed -= 1;
            allocatedThisRound += 1;
          }
          if (allocatedThisRound === 0) {
            break;
          }
        }

        activeIds = nextActiveIds.filter((id) => (remainingCapMap.get(id) ?? 0) > 0);
      }
    }

    const reducedTotal = context.neededGapMinutes - remainingNeed;
    const affectedItems = this.buildCompressionAffectedItems(selected, reducedMap);
    const suggestedMinutes = context.naturalArrivalMinutes - reducedTotal;
    const suggestedTime = DateUtil.minutesToTime(suggestedMinutes);

    if (remainingNeed > 0) {
      return {
        status: 'OVERLOAD',
        msg: `所选地点可压缩总量不足，仍冲突 ${remainingNeed} 分钟`,
        affectedItems: affectedItems,
        suggestedTime: suggestedTime,
        remainingGapMinutes: remainingNeed,
        capacityMinutes: capacityMinutes,
        mode: mode
      };
    }

    hilog.info(
      0x0000,
      TAG,
      `[CONFLICT_VM][compress_plan_ready] targetIndex=${targetIndex}, mode=${mode}, needed=${context.neededGapMinutes}, capacity=${capacityMinutes}`
    );

    return {
      status: 'COMPRESS_CONFIRM',
      msg: '需要压缩前序行程',
      affectedItems: affectedItems,
      suggestedTime: targetTime,
      remainingGapMinutes: 0,
      capacityMinutes: capacityMinutes,
      mode: mode
    };
  }

  /**
   * [执行] 应用压缩方案
   */
  public applyCompressionPlan(plan: CompressionPlan) {
    if (!plan.affectedItems || plan.affectedItems.length === 0) {
      return;
    }

    let minChangedIndex = Number.MAX_SAFE_INTEGER;
    plan.affectedItems.forEach(change => {
      const item = this.events[change.index];
      // 1. 更新内存
      item.duration = change.newVal;
      if (change.index < minChangedIndex) {
        minChangedIndex = change.index;
      }

      if (item.id) {
        EventDao.updateSingleField(item.id, 'duration', change.newVal, this.planId);
      }
    });


    const startIndex = minChangedIndex > 0 ? minChangedIndex - 1 : 0;
    this.recalculateFromIndex(startIndex);
  }

  /**
   * [新增] AI 智能生成入口
   */
  public async generateByAi(userPrompt: string) {
    try {
      // 1. 调用云端服务
      const aiItems = await AiService.generateItinerary(userPrompt);

      if (!aiItems || aiItems.length === 0) {
        return;
      }



      for (const item of aiItems) {

        const newItemInterface: import('../model/interface/IStandardEvent').TravelPlanItem = {
          name: item.name,
          duration: item.duration,
          type: 'FLOW',
          preTravelMinutes: -1,
          sortOrder: 0,
          status: 0,
          lockStatus: 0,
          fixedStartTime: undefined,
          dayOffset: 0,

          itemType: item.type,
          priority: 1,
          isTravelManual: 0,


          source: 1,

          aiReasoning: item.ai_reasoning || 'AI 智能推荐',

          delFlag: 0,
          groupId: 0,
          address: '',
          travelMode: 2
        };

        // 入库
        const newId = await EventDao.insertEvent(this.planId, newItemInterface);
        newItemInterface.id = newId;


        const newEntity = EventEntity.fromInterface(newItemInterface, this.planId);
        this.events.push(newEntity);
      }

      // AI 结果默认进入 Backlog，不影响已排程链路；仅刷新列表并失效缓存
      this.markScheduleChanged();
      this.events = [...this.events];

    } catch (error) {
      console.error(TAG, 'AI Generation Failed');

      // 🔧 [修复] 只能抛出 Error 类型
      if (error instanceof Error) {
        throw error;
      } else {

        throw new Error(JSON.stringify(error));
      }
    }

  }


  // 修改点：完全重构 findCurrentActiveEvent，改用绝对时间戳判定
  public findCurrentActiveEvent(): EventEntity | null {
    const currentTs = new Date().getTime();

    for (const item of this.events) {

      if (item.status !== 1 || item.completion_status !== 0) continue;


      if (item.actual_start_time > 0) return item;


      if (item.dynamic_start_time > 0 && item.dynamic_end_time > 0) {

        if (currentTs >= item.dynamic_start_time && currentTs < item.dynamic_end_time) {
          return item;
        }
      }
    }
    return null;
  }
  // =========================================================

  // =========================================================

  /**
   * [方案1] 计算顺延方案 (Delay Y)
   * 逻辑：完全不动前面，计算出自然到达时间，作为建议时间
   */
  public calculateDelayPlan(targetIndex: number): CompressionPlan {
    // 1. 直接调用公共辅助方法计算自然到达时间
    const naturalArrivalMinutes = this._calculateNaturalArrival(targetIndex);

    // 2. 转换为字符串 (HH:mm)
    const timeStr = DateUtil.minutesToTime(naturalArrivalMinutes);

    // 3. 返回方案：affectedItems 为空，表示前面没人需要改
    return {
      status: 'COMPRESS_CONFIRM',
      msg: '顺延',
      affectedItems: [],
      suggestedTime: timeStr
    };
  }

  /**
   * [方案2] 计算强压方案 (Force Compress X)
   *
   */
  public calculateForceCompressPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    const targetMinutes = DateUtil.timeToMinutes(newTimeStr);
    const naturalArrivalMinutes = this._calculateNaturalArrival(targetIndex);
    const targetDayOffset = this.getEffectiveDayOffset(this.events[targetIndex]);
    const neededGap = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);


    if (neededGap <= 0) {
      return {
        status: 'NO_ACTION',
        msg: '时间充裕',
        affectedItems: [],
        suggestedTime: newTimeStr
      };
    }

    // 1. 寻找最近的一个非锁定邻居 (Location X)
    let prevIndex = -1;
    for (let i = targetIndex - 1; i >= 0; i--) {
      if (this.events[i].lock_status !== 1) {
        prevIndex = i;
        break;
      }
    }


    if (prevIndex === -1) {
      return {
        status: 'OVERLOAD',
        msg: '前序行程均为固定时间，无法压缩',
        affectedItems: [],
        suggestedTime: DateUtil.minutesToTime(naturalArrivalMinutes)
      };
    }

    // 3. 计算压缩后的时长
    const item = this.events[prevIndex];
    const original = item.duration;
    let newDur = original - neededGap;
    const minKeepDuration = this.getMinEventDurationLimit();

    if (newDur < minKeepDuration) {

      return {
        status: 'FAIL_TOO_SHORT',
        msg: `行程将低于${minKeepDuration}分钟`,

        affectedItems: [{
          index: prevIndex,
          name: item.name,
          oldVal: original,
          newVal: newDur
        }],
        suggestedTime: ''
      };
    }

    // 4. 成功
    return {
      status: 'COMPRESS_CONFIRM',
      msg: '强力压缩',
      affectedItems: [{
        index: prevIndex,
        name: item.name,
        oldVal: original,
        newVal: newDur
      }],
      suggestedTime: newTimeStr
    };
  }

  /**
   *
   *
   */
  public _calculateNaturalArrival(targetIndex: number): number {
    // 1. 寻找计算起点
    let chainStartIndex = 0;

    let startMinutes = DateUtil.timeToMinutes(this.globalStartTime);

    for (let i = targetIndex - 1; i >= 0; i--) {
      const item = this.events[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        chainStartIndex = i;
        startMinutes = DateUtil.timeToMinutes(item.fixed_start_time);
        break;
      }
    }

    const chainStartItem = this.events[chainStartIndex];
    const chainDayOffset = chainStartItem ? this.getEffectiveDayOffset(chainStartItem) : 0;
    // 使用绝对分钟轴计算，避免跨天(day_offset)场景下建议时间偏移。
    startMinutes += chainDayOffset * 24 * 60;

    // 2. 累加时间
    let currentCursor = startMinutes;
    for (let i = chainStartIndex; i < targetIndex; i++) {
      const item = this.events[i];


      if (i > chainStartIndex) {
        if (item.pre_travel_min > 0) {
          currentCursor += item.pre_travel_min;
        }
      } else {

        if (item.lock_status !== 1 && item.pre_travel_min > 0) {
          currentCursor += item.pre_travel_min;
        }
      }


      currentCursor += item.duration;
    }


    const targetItem = this.events[targetIndex];
    if (targetItem.pre_travel_min > 0) {
      currentCursor += targetItem.pre_travel_min;
    }

    return currentCursor;
  }

  public async resolveGapByDistribution(targetItem: EventEntity) {
    if (!targetItem || !targetItem.has_gap || targetItem.gap_minutes <= 0) {
      return;
    }

    const gap = targetItem.gap_minutes;
    const index = this.events.indexOf(targetItem);
    if (index <= 0) {
      return;
    }

    // 1. 回溯寻找可分摊的浮动行程 (Lock=0)

    const candidates: EventEntity[] = [];
    for (let i = index - 1; i >= 0; i--) {
      const item = this.events[i];
      if (item.lock_status !== 0) {
        break;
      }
      candidates.push(item);
    }

    if (candidates.length === 0) {

      return;
    }


    const count = candidates.length;
    const baseAdd = Math.floor(gap / count);
    const remainder = gap % count;

    // 3. 应用更改 (注意：candidates 是倒序收集的，candidates[0] 是离 gap 最近的那个)
    candidates.forEach((item, idx) => {
      let add = baseAdd;

      if (idx === 0) {
        add += remainder;
      }

      item.duration += add;


      if (item.id) {
        EventDao.updateSingleField(item.id, 'duration', item.duration, this.planId);
      }
    });


    const recalculateStartIndex = this.events.indexOf(candidates[candidates.length - 1]);
    this.recalculateFromIndex(recalculateStartIndex > 0 ? recalculateStartIndex - 1 : 0);
  }


  /**
   *
   */
  public async skipEvent(item: EventEntity) {
    if (this.isArchived) {
      return;
    }
    const beforeNext = this.getNextExecutableEvent(item.id);
    const beforeNextTs = beforeNext ? beforeNext.dynamic_start_time : 0;
    const beforeNextName = beforeNext ? beforeNext.name : '';
    const now = new Date().getTime();
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][skip_event][begin] id=${item.id}, name=${item.name}, now=${now}, oldStatus=${item.completion_status}`
    );

    if (!TimelineExecutionState.isStartable(item) && !TimelineExecutionState.isActive(item)) {
      hilog.warn(
        0x0000,
        TAG,
        `[DUAL_MODE_ACCEPT][skip_event][blocked] reason=non_pending_skip, id=${item.id}, name=${item.name}, status=${item.completion_status}`
      );
      return;
    }

    if (item.id) {
      const ok = await this.applyRuntimeTransition(item, 'SKIP', now);
      if (!ok) {
        return;
      }
    }

    // 3. 刷新
    this.recalculateFromEventId(item.id);
    const afterNext = this.getNextExecutableEvent(item.id);
    const afterNextTs = afterNext ? afterNext.dynamic_start_time : 0;
    const afterNextName = afterNext ? afterNext.name : beforeNextName;
    this.latestReflowHint = this.buildReflowHint('skip', beforeNextTs, afterNextTs, item.name, afterNextName);
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][skip_event][done] id=${item.id}, name=${item.name}, status=${item.completion_status}, actualEnd=${item.actual_end_time}`
    );
    this.logTimelineSnapshot('skip_event');
    this.getPlaceCheckinSummary(item.name);
  }


  public async reopenSkippedEvent(id: number): Promise<boolean> {
    if (this.isArchived) {
      return false;
    }
    const target = this.events.find(e => e.id === id);
    if (!target) {
      return false;
    }
    const oldStatus = target.completion_status;
    const oldStart = target.actual_start_time;
    const oldEnd = target.actual_end_time;

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][reopen_skipped][begin] id=${target.id}, name=${target.name}, oldStatus=${target.completion_status}, oldStart=${target.actual_start_time}, oldEnd=${target.actual_end_time}`
    );

    if (!TimelineExecutionState.isSkipped(target)) {
      hilog.warn(
        0x0000,
        TAG,
        `[DUAL_MODE_ACCEPT][reopen_skipped][blocked] reason=non_skipped_target, id=${target.id}, name=${target.name}, status=${target.completion_status}`
      );
      return false;
    }

    try {
      const ok = await this.applyRuntimeTransition(target, 'REOPEN', Date.now());
      if (!ok) {
        return false;
      }
    } catch (error) {
      hilog.error(
        0x0000,
        TAG,
        `[DUAL_MODE_ACCEPT][reopen_skipped][rollback] id=${target.id}, name=${target.name}, reason=${JSON.stringify(error)}`
      );
      return false;
    }
    this.recalculateFromEventId(target.id);

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][reopen_skipped][done] id=${target.id}, name=${target.name}, newStatus=${target.completion_status}, newStart=${target.actual_start_time}, newEnd=${target.actual_end_time}`
    );
    this.logTimelineSnapshot('reopen_skipped');
    this.getPlaceCheckinSummary(target.name);
    return true;
  }

  // 修改点：重构 calculateRealtimeSchedule 循环内部逻辑
  public calculateRealtimeSchedule() {
    this.conflictList = [];
    const anyStarted = this.events.some(e => e.actual_start_time > 0);
    let completedCount = 0;
    let skippedCount = 0;
    let pendingCount = 0;
    let actualOverrideCount = 0;
    const baseTimeMs = TimelineDatePolicy.toDayStartMs(this.planStartDate || Date.now());
    let currentCursor = baseTimeMs;

    for (let i = 0; i < this.events.length; i++) {
      const item = this.events[i];
      const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      item.is_forecast_conflict = false;

      if (i === 0) {
        const rawTime = (item.computed_time || '09:00').split(' ').pop() || '09:00';
        currentCursor = item.actual_start_time > 0 ? item.actual_start_time :
          TimelineDatePolicy.buildPlannedTimestamp(baseTimeMs, effectiveDayOffset, rawTime);
      } else {
        if (item.actual_start_time > 0) {
          currentCursor = item.actual_start_time;
        } else {
          currentCursor += (item.pre_travel_min > 0 ? item.pre_travel_min : 0) * 60000;
        }
      }

      if (item.fixed_start_time && item.completion_status === 0) {
        const anchorTs = TimelineDatePolicy.buildPlannedTimestamp(baseTimeMs, effectiveDayOffset, item.fixed_start_time);

        // 刚性冲突仅记录 UI 警告
        if (item.lock_status === 1 && currentCursor > anchorTs + 60000) {
          item.is_forecast_conflict = true;
          this.conflictList.push(item);
        }

        if (currentCursor < anchorTs) {
          currentCursor = anchorTs; // 修改点：核心修复
        }
      }

      item.dynamic_start_time = currentCursor; // 物理层始终写入，保障伴游模式工作
      let stepEndTime = item.actual_end_time > 0 ? item.actual_end_time : (currentCursor + item.duration * 60000);
      item.dynamic_end_time = stepEndTime;
      if (item.actual_end_time > 0) {
        actualOverrideCount += 1;
      }

      if (item.completion_status === EventEntity.STATE_COMPLETED) {
        completedCount += 1;
      } else if (item.completion_status === EventEntity.STATE_SKIPPED) {
        skippedCount += 1;
      } else {
        pendingCount += 1;
      }

      if (!anyStarted) {
        item.forecast_start_time = "xxxx";
        item.forecast_end_time = "xxxx";
      } else {
        const diff = Math.round((new Date(currentCursor).setHours(0,0,0,0) - (baseTimeMs + effectiveDayOffset * 86400000)) / 86400000);
        const dayLabel = (diff === 1 ? "次日 " : (diff > 1 ? `+${diff}天 ` : ""));
        item.forecast_start_time = dayLabel + DateUtil.formatDate(new Date(currentCursor), 'HH:mm');
        item.forecast_end_time = DateUtil.formatDate(new Date(stepEndTime), 'HH:mm');
      }

      // --- D. 推进游标 ---
      currentCursor = stepEndTime;
    }

    const active = this.getRealActiveEvent();
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][realtime] anyStarted=${anyStarted}, pending=${pendingCount}, completed=${completedCount}, skipped=${skippedCount}, actualOverride=${actualOverrideCount}, active=${active ? active.name : 'none'}`
    );
  }

  public async checkOutEvent(item: EventEntity) {
    const now = new Date().getTime();
    if (item.id) {
      const ok = await this.applyRuntimeTransition(item, 'END', now);
      if (!ok) {
        return;
      }
    }

    // 2. 触发预测
    this.calculateRealtimeSchedule();

    // 3. 刷新
    this.events = [...this.events];
  }

  public async recordStartTime(item: EventEntity) {
    const now = new Date().getTime();
    if (item.id) {
      const ok = await this.applyRuntimeTransition(item, 'START', now);
      if (!ok) {
        return;
      }
    }

    // 触发预测更新
    this.calculateRealtimeSchedule();
    this.events = [...this.events];
  }

  private hasPrecheckActiveConflict(id: number): boolean {
    return this.events.some((item: EventEntity) => item.id !== id && TimelineExecutionState.isActive(item));
  }

  private buildActualTimeMutationMeta(
    id: number,
    target: EventEntity,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): ActualTimeMutationMeta {
    const beforeNext = this.getNextExecutableEvent(id);
    const beforeNextTs = beforeNext ? beforeNext.dynamic_start_time : 0;
    const beforeNextName = beforeNext ? beforeNext.name : '';
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][actual_time][begin] id=${id}, name=${target.name}, field=${field}, ts=${timestamp}, oldStart=${target.actual_start_time}, oldEnd=${target.actual_end_time}, oldStatus=${target.completion_status}`
    );
    const meta: ActualTimeMutationMeta = {
      beforeNextTs: beforeNextTs,
      beforeNextName: beforeNextName
    };
    return meta;
  }

  private async applyActualTimeMutation(
    target: EventEntity,
    id: number,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): Promise<boolean> {
    if (field === 'actual_start_time') {
      if (timestamp > 0) {
        const started = await this.applyRuntimeTransition(target, 'START', timestamp);
        return started;
      }
      await EventDao.updateFields(id, [{ column: field, value: timestamp }], this.planId);
      target.actual_start_time = timestamp;
      return true;
    } else {
      const ended = await this.applyRuntimeTransition(target, 'END', timestamp);
      return ended;
    }
  }

  private async postActualTimeMutationEffects(
    id: number,
    target: EventEntity,
    field: 'actual_start_time' | 'actual_end_time',
    beforeNextTs: number,
    beforeNextName: string
  ): Promise<void> {
    this.recalculateFromEventId(id);
    this.markScheduleChanged();
    const schedule = this.getOrderedScheduleEvents();
    const afterNext = this.getNextExecutableEvent(id, schedule);
    const afterNextTs = afterNext ? afterNext.dynamic_start_time : 0;
    const afterNextName = afterNext ? afterNext.name : beforeNextName;
    this.latestReflowHint = this.buildReflowHint(
      field === 'actual_start_time' ? 'start' : 'end',
      beforeNextTs,
      afterNextTs,
      target.name,
      afterNextName
    );

    const active = this.getRealActiveEvent(schedule);
    if (active) {
      const nextIdx = this.getOrderedScheduleIndexById(active.id, schedule) + 1;
      const next = (nextIdx > 0 && nextIdx < schedule.length) ? schedule[nextIdx] : null;
      const nextTip = next ? `下个地点：${next.name}` : '今日行程即将结束';
      void NotificationGateway.updateScheduleNotification(`正在：${active.name}`, nextTip);
    }

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][actual_time][done] id=${id}, name=${target.name}, field=${field}, newStart=${target.actual_start_time}, newEnd=${target.actual_end_time}, newStatus=${target.completion_status}, active=${active ? active.name : 'none'}`
    );
    this.logTimelineSnapshot(`actual_time_${field}`);
    if (field === 'actual_end_time') {
      this.getPlaceCheckinSummary(target.name);
    }
  }


  /**
   *
   */
  public async updateActualTime(id: number, field: 'actual_start_time' | 'actual_end_time', timestamp: number): Promise<void> {
    if (this.isArchived) {
      return;
    }
    if (this.actualTimeMutationInFlight) {
      hilog.warn(0x0000, TAG, `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=mutation_in_flight, id=${id}, field=${field}`);
      return;
    }
    const target = this.events.find(e => e.id === id);
    if (!target) return;

    if (field === 'actual_start_time' && timestamp > 0) {
      if (this.hasPrecheckActiveConflict(id)) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=active_exists_precheck, id=${id}, name=${target.name}, ts=${timestamp}`
        );
        return;
      }
    }

    this.actualTimeMutationInFlight = true;
    try {
      const mutationMeta = this.buildActualTimeMutationMeta(id, target, field, timestamp);
      const beforeNextTs = mutationMeta.beforeNextTs;
      const beforeNextName = mutationMeta.beforeNextName;

      if (field === 'actual_start_time' &&
        timestamp > 0 &&
        !TimelineExecutionState.isStartable(target)) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=non_pending_start, id=${id}, name=${target.name}, status=${target.completion_status}, ts=${timestamp}`
        );
        return;
      }

      try {
        const applied = await this.applyActualTimeMutation(target, id, field, timestamp);
        if (!applied) {
          return;
        }
      } catch (error) {
        hilog.error(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][rollback] id=${id}, name=${target.name}, field=${field}, reason=${JSON.stringify(error)}`
        );
        return;
      }
      await this.postActualTimeMutationEffects(id, target, field, beforeNextTs, beforeNextName);
    } finally {
      this.actualTimeMutationInFlight = false;
    }
  }

  private async reloadGlobalRouteApiSwitch(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      this.enableGlobalAmapRouteApi = await pref.isAmapRouteApiEnabled();
    } catch (error) {
      this.enableGlobalAmapRouteApi = false;
      hilog.warn(0x0000, TAG, `[SETTING_VM][amap_api_switch_fallback] reason=${JSON.stringify(error)}`);
    }
  }

  public async reloadRouteSwitches(): Promise<void> {
    await this.reloadIdleGapSettings();
    await this.reloadGlobalRouteApiSwitch();
  }

  private isAutoRouteEnabled(): boolean {
    return this.enableAutoAmapRoute && this.enableGlobalAmapRouteApi;
  }

  private shouldAutoRouteForItem(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    if (!this.isAutoRouteEnabled()) {
      return false;
    }
    if (item.is_travel_manual === 1) {
      return false;
    }
    if (this.isFirstScheduledItemOfDay(item)) {
      return false;
    }
    return true;
  }

  public getOrderedScheduleEvents(): EventEntity[] {
    const schedule = this.events.filter((event: EventEntity) => event.status === 1);
    const stableIndex = new Map<number, number>();
    schedule.forEach((event: EventEntity, index: number) => {
      stableIndex.set(event.id, index);
    });
    const ordered = schedule.slice();
    ordered.sort((a: EventEntity, b: EventEntity) => {
      const dayA = TimelineDatePolicy.resolveEventDayOffset(a);
      const dayB = TimelineDatePolicy.resolveEventDayOffset(b);
      if (dayA !== dayB) {
        return dayA - dayB;
      }
      if (a.sort_order !== b.sort_order) {
        return a.sort_order - b.sort_order;
      }
      return (stableIndex.get(a.id) ?? 0) - (stableIndex.get(b.id) ?? 0);
    });
    return ordered;
  }

  private getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const source = schedule ?? this.getOrderedScheduleEvents();
    return source.findIndex((event: EventEntity) => event.id === eventId);
  }

  private normalizePlaceKey(placeName: string): string {
    return placeName.trim().toLowerCase();
  }

  public getEventsByPlaceName(placeName: string): EventEntity[] {
    const key = this.normalizePlaceKey(placeName);
    if (key.length === 0) {
      return [];
    }
    const items = this.events.filter((event: EventEntity) =>
      this.normalizePlaceKey(event.name || '') === key
    );
    items.sort((a: EventEntity, b: EventEntity) => {
      const dayA = TimelineDatePolicy.resolveEventDayOffset(a);
      const dayB = TimelineDatePolicy.resolveEventDayOffset(b);
      if (dayA !== dayB) {
        return dayA - dayB;
      }
      if (a.sort_order !== b.sort_order) {
        return a.sort_order - b.sort_order;
      }
      return a.id - b.id;
    });
    return items;
  }

  public getPlaceAddress(placeName: string): string {
    const events = this.getEventsByPlaceName(placeName);
    for (let i = 0; i < events.length; i++) {
      const address = (events[i].address || '').trim();
      if (address.length > 0) {
        return address;
      }
    }
    return '-';
  }

  public getLatestEventForPlace(placeName: string): EventEntity | null {
    const events = this.getEventsByPlaceName(placeName)
      .filter((event: EventEntity) => TimelineExecutionState.isScheduled(event));
    if (events.length === 0) {
      return null;
    }
    events.sort((a: EventEntity, b: EventEntity) => {
      const aTs = a.actual_end_time > 0 ? a.actual_end_time : (a.actual_start_time > 0 ? a.actual_start_time : 0);
      const bTs = b.actual_end_time > 0 ? b.actual_end_time : (b.actual_start_time > 0 ? b.actual_start_time : 0);
      if (bTs !== aTs) {
        return bTs - aTs;
      }
      return b.id - a.id;
    });
    return events[0];
  }

  public getAllPlaceCheckinSummaries(): PlaceCheckinSummary[] {
    const summaries: PlaceCheckinSummary[] = [];
    const uniquePlaceNames = new Set<string>();
    for (let i = 0; i < this.events.length; i++) {
      const rawName = (this.events[i].name || '').trim();
      if (rawName.length === 0) {
        continue;
      }
      uniquePlaceNames.add(rawName);
    }
    const names = Array.from(uniquePlaceNames.values());
    for (let i = 0; i < names.length; i++) {
      const summary = this.getPlaceCheckinSummary(names[i]);
      if (summary.totalRecords > 0) {
        summaries.push(summary);
      }
    }
    return summaries;
  }

  private getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null {
    const source = schedule ?? this.getOrderedScheduleEvents();
    const idx = this.getOrderedScheduleIndexById(afterId, source);
    if (idx === -1) {
      return null;
    }
    for (let i = idx + 1; i < source.length; i++) {
      if (TimelineExecutionState.isStartable(source[i])) {
        return source[i];
      }
    }
    return null;
  }

  public buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    if (action === 'skip') {
      return {
        type: 'next_changed',
        minutesDelta: 0,
        message: nextName
          ? `已跳过 ${targetName}，下一站改为 ${nextName}`
          : `已跳过 ${targetName}，后续行程已自动重排`,
        updatedAt: Date.now()
      };
    }

    if (beforeTs > 0 && afterTs > 0) {
      const deltaMinutes = Math.round((afterTs - beforeTs) / 60000);
      if (deltaMinutes > 0) {
        return {
          type: 'shift',
          minutesDelta: deltaMinutes,
          message: `后续整体顺延 ${deltaMinutes} 分钟`,
          updatedAt: Date.now()
        };
      }
      if (deltaMinutes < 0) {
        return {
          type: 'shift',
          minutesDelta: deltaMinutes,
          message: `后续整体提前 ${Math.abs(deltaMinutes)} 分钟`,
          updatedAt: Date.now()
        };
      }
    }

    return {
      type: 'reflow',
      minutesDelta: 0,
      message: '已根据实际时间自动更新后续安排',
      updatedAt: Date.now()
    };
  }

  public getDistributionCandidates(gapItem: EventEntity): EventEntity[] {
    const index = this.events.indexOf(gapItem);
    if (index <= 0) return [];

    return this.events.slice(0, index).filter(e => e.status === 1 && this.getEffectiveDayOffset(e) === this.getEffectiveDayOffset(gapItem));
  }

  // TimelineViewModel.ets 内部新增/修改

  /**
   *
   */
  public getSafetyCap(candidate: EventEntity, gapItem: EventEntity): number {
    const allSchedule = this.events.filter(e => e.status === 1);

    const candIdx = allSchedule.findIndex(e => e.id === candidate.id);
    const gapIdx = allSchedule.findIndex(e => e.id === gapItem.id);

    if (candIdx === -1 || gapIdx === -1 || candIdx >= gapIdx) {
      return 0;
    }

    let minBuffer = Math.max(0, gapItem.gap_minutes);

    for (let i = candIdx + 1; i < gapIdx; i++) {
      const item = allSchedule[i];
      if (item.lock_status === 1 && item.fixed_start_time) {
        const eventIdxInEvents = this.events.findIndex(e => e.id === item.id);
        if (eventIdxInEvents === -1) {
          continue;
        }

        const naturalArrival = this._calculateNaturalArrival(eventIdxInEvents);
        const targetMin = DateUtil.timeToMinutes(item.fixed_start_time);
        const buffer = targetMin - naturalArrival;

        if (buffer < minBuffer) {
          minBuffer = Math.max(0, buffer);
        }
      }
    }

    return minBuffer;
  }

  public calculateDistributionPreview(gapItem: EventEntity, candidates: EventEntity[], selectedIds: Set<number>,
    strategy: 'EQUAL' | 'SMART'): Map<number, number> {
    const selectedItems = candidates.filter(c => selectedIds.has(c.id));
    const result = new Map<number, number>();
    if (selectedItems.length === 0) return result;

    const caps = new Map<number, number>();
    const weights = new Map<number, number>();
    let totalWeight = 0;


    selectedItems.forEach(item => {
      // 强制限制逻辑：A=3 安全策略
      const cap = this.getSafetyCap(item, gapItem);
      caps.set(item.id, cap);

      let w = 1.0;
      if (strategy === 'SMART') {


        const pFactor = (item.priority === 1 ? 2.0 : 1.0);
        const dFactor = item.duration;
        w = pFactor * dFactor;
      }
      weights.set(item.id, w);
      totalWeight += w;
      result.set(item.id, 0);
    });


    let remainingGap = gapItem.gap_minutes;
    let activeIds = selectedItems.map(i => i.id);

    while (remainingGap > 0 && activeIds.length > 0) {
      let currentRoundWeight = 0;
      activeIds.forEach(id => {
        currentRoundWeight += (weights.get(id) ?? 0);
      });

      if (currentRoundWeight <= 0) break;

      let nextActiveIds: number[] = [];
      let allocatedThisRound = 0;

      for (const id of activeIds) {

        const weightVal: number = weights.get(id) ?? 0;
        const share: number = Math.floor(remainingGap * (weightVal / currentRoundWeight));

        const currentAllocated = result.get(id) ?? 0;
        const cap = caps.get(id) ?? 0;

        if (currentAllocated + share >= cap) {

          const actualAdd = cap - currentAllocated;
          result.set(id, cap);
          allocatedThisRound += actualAdd;
        } else {
          result.set(id, currentAllocated + share);
          allocatedThisRound += share;
          nextActiveIds.push(id);
        }
      }

      remainingGap -= allocatedThisRound;


      if (allocatedThisRound === 0 && remainingGap > 0) {
        const luckyId = nextActiveIds[0];
        if (luckyId && (result.get(luckyId) ?? 0) < (caps.get(luckyId) ?? 0)) {
          result.set(luckyId, (result.get(luckyId) ?? 0) + 1);
          remainingGap--;
        } else {
          break;
        }
      }
      activeIds = nextActiveIds;
    }

    return result;
  }


  /** * 获取所有已排序的空闲时间段
   */
  public getSortedGaps(): EventEntity[] {
    if (!this.idleGapDetectionEnabled) {
      return [];
    }

    const minGap = this.idleGapTriggerMinutes;
    return this.events
      .filter(e =>
      e.status === 1 &&
      e.has_gap &&
        e.gap_minutes >= minGap &&
        !this.isFirstScheduledItemOfDay(e)
      )
      .sort((a, b) => b.gap_minutes - a.gap_minutes);
  }

  /** * 获取空闲时间段的前序地点名称
   */
  public getPreviousItemName(gapItem: EventEntity): string {
    const schedule = this.getOrderedScheduleEvents();
    const idx = this.getOrderedScheduleIndexById(gapItem.id, schedule);
    if (idx <= 0) {
      return "日程开始";
    }

    const prev = schedule[idx - 1];
    if (this.getEffectiveDayOffset(prev) !== this.getEffectiveDayOffset(gapItem)) {
      return "当日开始";
    }

    return prev.name;
  }


  public async applyDistribution(distributionMap: Map<number, number>) {
    const entries = Array.from(distributionMap.entries());
    let startIndex = this.events.length;
    for (let i = 0; i < entries.length; i++) {
      const id = entries[i][0];
      const addMin = entries[i][1];
      const item = this.events.find(e => e.id === id);
      if (item && addMin > 0) {
        const idx = this.events.indexOf(item);
        if (idx >= 0 && idx < startIndex) {
          startIndex = idx;
        }
        item.duration += addMin;
        await EventDao.updateSingleField(item.id, 'duration', item.duration, this.planId);
      }
    }
    if (startIndex < this.events.length) {
      this.recalculateFromIndex(startIndex > 0 ? startIndex - 1 : 0);
    }
  }

  public getPlaceCheckinSummary(placeName: string): PlaceCheckinSummary {
    const samePlaceEvents = this.getEventsByPlaceName(placeName);
    const records: PlaceCheckinRecord[] = [];
    let completedCount = 0;
    let skippedCount = 0;
    let totalStay = 0;
    let lastEnd = 0;
    for (let i = 0; i < samePlaceEvents.length; i++) {
      const e = samePlaceEvents[i];
      if (e.actual_start_time <= 0 && e.actual_end_time <= 0 && e.completion_status === EventEntity.STATE_PENDING) {
        continue;
      }
      const stayMs = (e.actual_start_time > 0 && e.actual_end_time > e.actual_start_time)
        ? (e.actual_end_time - e.actual_start_time)
        : 0;
      const stayMinutes = stayMs > 0 ? Math.round(stayMs / 60000) : 0;
      if (e.completion_status === EventEntity.STATE_COMPLETED) {
        completedCount += 1;
        totalStay += stayMinutes;
        if (e.actual_end_time > lastEnd) {
          lastEnd = e.actual_end_time;
        }
      } else if (e.completion_status === EventEntity.STATE_SKIPPED) {
        skippedCount += 1;
      }
      records.push({
        id: e.id,
        name: e.name,
        dayOffset: e.day_offset,
        status: e.completion_status,
        actualStart: e.actual_start_time,
        actualEnd: e.actual_end_time,
        stayMinutes: stayMinutes
      });
    }
    records.sort((a, b) => {
      const ta = a.actualEnd > 0 ? a.actualEnd : a.actualStart;
      const tb = b.actualEnd > 0 ? b.actualEnd : b.actualStart;
      return tb - ta;
    });
    const avgStay = completedCount > 0 ? Math.round(totalStay / completedCount) : 0;

    const summary: PlaceCheckinSummary = {
      placeName: placeName,
      totalRecords: records.length,
      completedRecords: completedCount,
      skippedRecords: skippedCount,
      avgStayMinutes: avgStay,
      lastEndTime: lastEnd,
      records: records
    };

    hilog.info(
      0x0000,
      TAG,
      `[CHECKIN_HISTORY][summary] place=${placeName}, total=${summary.totalRecords}, completed=${summary.completedRecords}, skipped=${summary.skippedRecords}, avgStay=${summary.avgStayMinutes}, lastEnd=${summary.lastEndTime}`
    );
    return summary;
  }

  public getCompanionContext(nowTs: number = Date.now()): CompanionContext {
    const schedule = this.getOrderedScheduleEvents();
    if (schedule.length === 0) {
      return {
        runtimeState: 'IDLE',
        currentEvent: null,
        nextEvent: null,
        hint: this.latestReflowHint,
        actions: {
          canStart: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        }
      };
    }

    let active: EventEntity | null = null;
    let pending: EventEntity | null = null;
    for (let i = 0; i < schedule.length; i++) {
      const event = schedule[i];
      if (!active && TimelineExecutionState.isActive(event)) {
        active = event;
      }
      if (!pending && TimelineExecutionState.isStartable(event)) {
        pending = event;
      }
      if (active && pending) {
        break;
      }
    }

    if (active) {
      const next = this.getNextExecutableEvent(active.id, schedule);
      return {
        runtimeState: 'ACTIVE',
        currentEvent: active,
        nextEvent: next,
        hint: this.latestReflowHint,
        actions: {
          canStart: false,
          canEnd: true,
          canSkip: true,
          canNavigate: true,
          canViewDetail: true
        }
      };
    }

    if (!pending) {
      return {
        runtimeState: 'IDLE',
        currentEvent: null,
        nextEvent: null,
        hint: this.latestReflowHint,
        actions: {
          canStart: false,
          canEnd: false,
          canSkip: false,
          canNavigate: false,
          canViewDetail: false
        }
      };
    }

    const hasDynamicStart = pending.dynamic_start_time > 0;
    const next = this.getNextExecutableEvent(pending.id, schedule);
    let runtimeHint = this.latestReflowHint;
    if (!runtimeHint && hasDynamicStart) {
      const deltaMinutes = Math.round((pending.dynamic_start_time - nowTs) / 60000);
      runtimeHint = {
        type: 'reflow',
        minutesDelta: deltaMinutes,
        message: deltaMinutes > 0
          ? `距计划开始约 ${Math.max(1, deltaMinutes)} 分钟，可手动提前开始`
          : `已超过计划开始 ${Math.max(1, Math.abs(deltaMinutes))} 分钟，可直接开始`,
        updatedAt: nowTs
      };
    }

    return {
      runtimeState: 'READY',
      currentEvent: pending,
      nextEvent: next,
      hint: runtimeHint,
      actions: {
        canStart: true,
        canEnd: false,
        canSkip: true,
        canNavigate: true,
        canViewDetail: true
      }
    };
  }

  public getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null {
    const now = new Date().getTime();
    const source = schedule ?? this.getOrderedScheduleEvents();
    let pending: EventEntity | null = null;
    for (let i = 0; i < source.length; i++) {
      const event = source[i];
      if (TimelineExecutionState.isActive(event)) {
        return event;
      }
      if (!pending && TimelineExecutionState.isStartable(event) && event.dynamic_end_time > now) {
        pending = event;
      }
    }
    return pending;
  }

  private isFirstScheduledItemOfDay(item: EventEntity): boolean {
    if (!item || item.status !== 1) {
      return false;
    }
    const schedule = this.getOrderedScheduleEvents();
    const idx = schedule.findIndex((event: EventEntity) => event.id === item.id);
    if (idx <= 0) {
      return idx === 0;
    }
    const prev = schedule[idx - 1];
    return TimelineDatePolicy.resolveEventDayOffset(prev) !== TimelineDatePolicy.resolveEventDayOffset(item);
  }


  private insertSmart(newEntity: EventEntity) {

    if (newEntity.status === 0) {
      this.events.push(newEntity);
      return;
    }

    // 1. 准备比较标准（无 fixed_start_time 时回退到 computed_time）
    const targetTimeStr = newEntity.fixed_start_time || newEntity.computed_time || '23:59';
    const targetMin = DateUtil.timeToMinutes(targetTimeStr);


    let insertIndex = -1;

    // 遍历现有数组 (假设 this.events 主要是大概有序的，或者我们只关心同一天的相对顺序)
    for (let i = 0; i < this.events.length; i++) {
      const curr = this.events[i];
      if (curr.status !== 1) {
        continue;
      }

      if (curr.day_offset > newEntity.day_offset) {
        insertIndex = i;
        break;
      }

      // 只比较同一天的日程
      if (curr.day_offset === newEntity.day_offset) {

        // 获取当前项的比较时间 (优先用固定时间，没有则用推算时间)
        const currTimeStr = curr.fixed_start_time || curr.computed_time || '23:59';
        const currMin = DateUtil.timeToMinutes(currTimeStr);


        if (currMin > targetMin) {
          insertIndex = i;
          break;
        }
      }
    }

    if (insertIndex !== -1) {
      this.events.splice(insertIndex, 0, newEntity);
    } else {

      this.events.push(newEntity);
    }


    this.events.forEach((e, index) => {
      e.sort_order = index * 100;
    });
  }
}






































