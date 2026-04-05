import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../../model/entity/EventEntity';
import { DateUtil } from '../../../common/utils/DateUtil';
import { TimelineDatePolicy } from '../../policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../../policy/TimelineExecutionState';
import { EventRepositoryImpl, ActiveEventSnapshot } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { PlanStatus, TransitionTriggerSource } from '../../statemachine/PlanStatus';

const TAG = 'TimelineViewModel';

interface ActualTimeMutationMeta {
  beforeNextTs: number;
  beforeNextName: string;
}

export interface StartConflictInfo {
  eventId: number;
  planId: number;
  name: string;
  actualStartTime: number;
}

export interface ReflowHint {
  type: 'reflow' | 'shift' | 'next_changed';
  minutesDelta: number;
  message: string;
  updatedAt: number;
}

interface PlanStatusSnapshot {
  status: PlanStatus;
}

interface ExecutionPlanStateMachine {
  startExecution(planId: string, source: TransitionTriggerSource): void;
  completeExecution(planId: string): void;
  getPlanStatus(planId: string): PlanStatusSnapshot;
}

interface ExecutionReminderFacade {
  updateScheduleNotification(
    title: string,
    body: string,
    planId: number,
    eventId: number,
    ongoing: boolean
  ): Promise<void>;
}

export interface ITimelineExecutionHost {
  events: EventEntity[];
  conflictList: EventEntity[];
  planStartDate: number;
  isArchived: boolean;
  actualTimeMutationInFlight: boolean;
  latestReflowHint: ReflowHint | null;
  planId: number;
  currentPlanStatus: PlanStatus;
  planStateMachine: ExecutionPlanStateMachine;
  reminderFacade: ExecutionReminderFacade;

  applyRuntimeTransition(
    target: EventEntity,
    transition: 'START' | 'END' | 'SKIP' | 'REOPEN',
    timestamp: number
  ): Promise<boolean>;
  recalculateFromEventId(eventId: number): void;
  getNextExecutableEvent(afterId: number, schedule?: EventEntity[]): EventEntity | null;
  buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint;
  logTimelineSnapshot(scene: string): void;
  getPlaceCheckinSummary(placeName: string): void;
  evaluatePlanStatusByRuntime(): void;
  getRealActiveEvent(schedule?: EventEntity[]): EventEntity | null;
  markScheduleChanged(): void;
  getOrderedScheduleEvents(): EventEntity[];
  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number;
  getCurrentPlanStatus(): PlanStatus;
}

export interface ITimelineExecutionService {
  findCurrentActiveEvent(): EventEntity | null;
  skipEvent(item: EventEntity): Promise<void>;
  reopenSkippedEvent(id: number): Promise<boolean>;
  calculateRealtimeSchedule(): void;
  checkOutEvent(item: EventEntity): Promise<void>;
  recordStartTime(item: EventEntity): Promise<void>;
  updateActualTime(id: number, field: 'actual_start_time' | 'actual_end_time', timestamp: number): Promise<boolean>;
  getStartConflictInfo(excludeEventId: number): Promise<StartConflictInfo | null>;
}

export class TimelineExecutionService implements ITimelineExecutionService {
  private host: ITimelineExecutionHost;

  constructor(host: ITimelineExecutionHost) {
    this.host = host;
  }

  public findCurrentActiveEvent(): EventEntity | null {
    const currentTs = new Date().getTime();

    for (const item of this.host.events) {
      if (item.status !== 1 || item.completion_status !== 0) {
        continue;
      }

      if (item.actual_start_time > 0) {
        return item;
      }

      if (item.dynamic_start_time > 0 && item.dynamic_end_time > 0) {
        if (currentTs >= item.dynamic_start_time && currentTs < item.dynamic_end_time) {
          return item;
        }
      }
    }
    return null;
  }

  public async skipEvent(item: EventEntity): Promise<void> {
    if (this.host.isArchived) {
      return;
    }
    const beforeNext = this.host.getNextExecutableEvent(item.id);
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
      const ok = await this.host.applyRuntimeTransition(item, 'SKIP', now);
      if (!ok) {
        return;
      }
    }

    this.host.recalculateFromEventId(item.id);
    const afterNext = this.host.getNextExecutableEvent(item.id);
    const afterNextTs = afterNext ? afterNext.dynamic_start_time : 0;
    const afterNextName = afterNext ? afterNext.name : beforeNextName;
    this.host.latestReflowHint = this.host.buildReflowHint('skip', beforeNextTs, afterNextTs, item.name, afterNextName);
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][skip_event][done] id=${item.id}, name=${item.name}, status=${item.completion_status}, actualEnd=${item.actual_end_time}`
    );
    this.host.logTimelineSnapshot('skip_event');
    this.host.getPlaceCheckinSummary(item.name);
    this.host.evaluatePlanStatusByRuntime();
  }

  public async reopenSkippedEvent(id: number): Promise<boolean> {
    if (this.host.isArchived) {
      return false;
    }
    const target = this.host.events.find((event: EventEntity) => event.id === id);
    if (!target) {
      return false;
    }

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
      const ok = await this.host.applyRuntimeTransition(target, 'REOPEN', Date.now());
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

    this.host.recalculateFromEventId(target.id);

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][reopen_skipped][done] id=${target.id}, name=${target.name}, newStatus=${target.completion_status}, newStart=${target.actual_start_time}, newEnd=${target.actual_end_time}`
    );
    this.host.logTimelineSnapshot('reopen_skipped');
    this.host.getPlaceCheckinSummary(target.name);
    this.host.evaluatePlanStatusByRuntime();
    return true;
  }

  public calculateRealtimeSchedule(): void {
    this.host.conflictList = [];
    const anyStarted = this.host.events.some((event: EventEntity) => event.actual_start_time > 0);
    let completedCount = 0;
    let skippedCount = 0;
    let pendingCount = 0;
    let actualOverrideCount = 0;
    const baseTimeMs = TimelineDatePolicy.toDayStartMs(this.host.planStartDate || Date.now());
    let currentCursor = baseTimeMs;

    for (let i = 0; i < this.host.events.length; i++) {
      const item = this.host.events[i];
      const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
      item.is_forecast_conflict = false;

      if (i === 0) {
        const rawTime = (item.computed_time || '09:00').split(' ').pop() || '09:00';
        currentCursor = item.actual_start_time > 0
          ? item.actual_start_time
          : TimelineDatePolicy.buildPlannedTimestamp(baseTimeMs, effectiveDayOffset, rawTime);
      } else {
        if (item.actual_start_time > 0) {
          currentCursor = item.actual_start_time;
        } else {
          currentCursor += (item.pre_travel_min > 0 ? item.pre_travel_min : 0) * 60000;
        }
      }

      if (item.fixed_start_time && item.completion_status === 0) {
        const anchorTs = TimelineDatePolicy.buildPlannedTimestamp(baseTimeMs, effectiveDayOffset, item.fixed_start_time);

        if (item.lock_status === 1 && currentCursor > anchorTs + 60000) {
          item.is_forecast_conflict = true;
          this.host.conflictList.push(item);
        }

        if (currentCursor < anchorTs) {
          currentCursor = anchorTs;
        }
      }

      item.dynamic_start_time = currentCursor;
      const stepEndTime = item.actual_end_time > 0 ? item.actual_end_time : (currentCursor + item.duration * 60000);
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
        item.forecast_start_time = 'xxxx';
        item.forecast_end_time = 'xxxx';
      } else {
        const diff = Math.round((new Date(currentCursor).setHours(0, 0, 0, 0) - (baseTimeMs + effectiveDayOffset * 86400000)) / 86400000);
        const dayLabel = diff === 1 ? '次日 ' : (diff > 1 ? `+${diff}天 ` : '');
        item.forecast_start_time = dayLabel + DateUtil.formatDate(new Date(currentCursor), 'HH:mm');
        item.forecast_end_time = DateUtil.formatDate(new Date(stepEndTime), 'HH:mm');
      }

      currentCursor = stepEndTime;
    }

    const active = this.host.getRealActiveEvent();
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][realtime] anyStarted=${anyStarted}, pending=${pendingCount}, completed=${completedCount}, skipped=${skippedCount}, actualOverride=${actualOverrideCount}, active=${active ? active.name : 'none'}`
    );
  }

  public async checkOutEvent(item: EventEntity): Promise<void> {
    const now = new Date().getTime();
    if (item.id) {
      const ok = await this.host.applyRuntimeTransition(item, 'END', now);
      if (!ok) {
        return;
      }
    }

    this.calculateRealtimeSchedule();
    this.host.events = [...this.host.events];
  }

  public async recordStartTime(item: EventEntity): Promise<void> {
    const now = new Date().getTime();
    if (item.id) {
      const ok = await this.host.applyRuntimeTransition(item, 'START', now);
      if (!ok) {
        return;
      }
    }

    this.calculateRealtimeSchedule();
    this.host.events = [...this.host.events];
  }

  private hasPrecheckActiveConflict(id: number): boolean {
    return this.host.events.some((item: EventEntity) => item.id !== id && TimelineExecutionState.isActive(item));
  }

  private buildActualTimeMutationMeta(
    id: number,
    target: EventEntity,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): ActualTimeMutationMeta {
    const beforeNext = this.host.getNextExecutableEvent(id);
    const beforeNextTs = beforeNext ? beforeNext.dynamic_start_time : 0;
    const beforeNextName = beforeNext ? beforeNext.name : '';
    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][actual_time][begin] id=${id}, name=${target.name}, field=${field}, ts=${timestamp}, oldStart=${target.actual_start_time}, oldEnd=${target.actual_end_time}, oldStatus=${target.completion_status}`
    );
    return {
      beforeNextTs: beforeNextTs,
      beforeNextName: beforeNextName
    };
  }

  private async applyActualTimeMutation(
    target: EventEntity,
    id: number,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): Promise<boolean> {
    if (field === 'actual_start_time') {
      if (timestamp > 0) {
        return this.host.applyRuntimeTransition(target, 'START', timestamp);
      }
      await EventRepositoryImpl.updateFields(id, [{ column: field, value: timestamp }], this.host.planId);
      target.actual_start_time = timestamp;
      return true;
    }
    return this.host.applyRuntimeTransition(target, 'END', timestamp);
  }

  private async postActualTimeMutationEffects(
    id: number,
    target: EventEntity,
    field: 'actual_start_time' | 'actual_end_time',
    beforeNextTs: number,
    beforeNextName: string
  ): Promise<void> {
    this.host.recalculateFromEventId(id);
    this.host.markScheduleChanged();
    const schedule = this.host.getOrderedScheduleEvents();
    const afterNext = this.host.getNextExecutableEvent(id, schedule);
    const afterNextTs = afterNext ? afterNext.dynamic_start_time : 0;
    const afterNextName = afterNext ? afterNext.name : beforeNextName;
    this.host.latestReflowHint = this.host.buildReflowHint(
      field === 'actual_start_time' ? 'start' : 'end',
      beforeNextTs,
      afterNextTs,
      target.name,
      afterNextName
    );

    const active = this.host.getRealActiveEvent(schedule);
    if (active) {
      const nextIdx = this.host.getOrderedScheduleIndexById(active.id, schedule) + 1;
      const next = (nextIdx > 0 && nextIdx < schedule.length) ? schedule[nextIdx] : null;
      const nextTip = next ? `下个地点：${next.name}` : '今日行程即将结束';
      await this.host.reminderFacade.updateScheduleNotification(
        `正在：${active.name}`,
        nextTip,
        this.host.planId,
        active.id,
        true
      );
    }

    hilog.info(
      0x0000,
      TAG,
      `[DUAL_MODE_ACCEPT][actual_time][done] id=${id}, name=${target.name}, field=${field}, newStart=${target.actual_start_time}, newEnd=${target.actual_end_time}, newStatus=${target.completion_status}, active=${active ? active.name : 'none'}`
    );
    this.host.logTimelineSnapshot(`actual_time_${field}`);
    if (field === 'actual_end_time') {
      this.host.getPlaceCheckinSummary(target.name);
    }
  }

  public async updateActualTime(
    id: number,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): Promise<boolean> {
    if (this.host.isArchived) {
      return false;
    }
    if (this.host.actualTimeMutationInFlight) {
      hilog.warn(0x0000, TAG, `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=mutation_in_flight, id=${id}, field=${field}`);
      return false;
    }
    const target = this.host.events.find((event: EventEntity) => event.id === id);
    if (!target) {
      return false;
    }

    if (field === 'actual_start_time' && timestamp > 0) {
      if (this.hasPrecheckActiveConflict(id)) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=active_exists_precheck, id=${id}, name=${target.name}, ts=${timestamp}`
        );
        return false;
      }
      const globalConflict = await this.getStartConflictInfo(id);
      if (globalConflict) {
        hilog.warn(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][blocked] reason=active_exists_global, id=${id}, name=${target.name}, conflictEventId=${globalConflict.eventId}, conflictPlanId=${globalConflict.planId}`
        );
        return false;
      }
    }

    this.host.actualTimeMutationInFlight = true;
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
        return false;
      }

      try {
        const applied = await this.applyActualTimeMutation(target, id, field, timestamp);
        if (!applied) {
          return false;
        }
      } catch (error) {
        hilog.error(
          0x0000,
          TAG,
          `[DUAL_MODE_ACCEPT][actual_time][rollback] id=${id}, name=${target.name}, field=${field}, reason=${JSON.stringify(error)}`
        );
        return false;
      }
      await this.postActualTimeMutationEffects(id, target, field, beforeNextTs, beforeNextName);

      if (this.host.planId > 0) {
        const planIdStr = `${this.host.planId}`;
        if (field === 'actual_start_time' && timestamp > 0) {
          this.host.planStateMachine.startExecution(planIdStr, TransitionTriggerSource.USER_ACTION);
        } else if (field === 'actual_end_time') {
          const scheduled = this.host.events.filter((item: EventEntity) => item.status === 1);
          const allCompleted = scheduled.length > 0 &&
            scheduled.every((item: EventEntity) => item.completion_status === EventEntity.STATE_COMPLETED);
          if (allCompleted) {
            this.host.planStateMachine.completeExecution(planIdStr);
          } else {
            this.host.evaluatePlanStatusByRuntime();
          }
        }
        this.host.currentPlanStatus = this.host.planStateMachine.getPlanStatus(planIdStr).status;
      }

      return true;
    } finally {
      this.host.actualTimeMutationInFlight = false;
    }
  }

  public async getStartConflictInfo(excludeEventId: number): Promise<StartConflictInfo | null> {
    const active: ActiveEventSnapshot | null = await EventRepositoryImpl.findGlobalActiveEvent(excludeEventId);
    if (!active) {
      return null;
    }
    return {
      eventId: active.eventId,
      planId: active.planId,
      name: active.name,
      actualStartTime: active.actualStartTime
    };
  }
}

