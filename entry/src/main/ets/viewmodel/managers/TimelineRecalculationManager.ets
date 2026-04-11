import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../../common/utils/DateUtil';
import { EventEntity } from '../../model/entity/EventEntity';
import { EventFieldUpdate, EventRepositoryImpl } from '../../infrastructure/persistence/EventRepositoryImpl';
import { TimelineCalculationService } from '../../domain/timeline/services/TimelineCalculationService';
import { ScheduleOrchestrator } from '../internal/ScheduleOrchestrator';
import { StrategyPresets } from '../../domain/strategy/StrategyPresets';
import { TravelStrategyMode } from '../../domain/strategy/TravelStrategyMode';
import { ApplyResultFlags, SolverCalculatedItem } from '../types/TimelineTypes';

const TAG = 'TimelineViewModel';

export interface ITimelineRecalculationHost {
  events: EventEntity[];
  planId: number;
  globalStartTime: string;
  planStartDate: number;
  idleGapDetectionEnabled: boolean;
  idleGapTriggerMinutes: number;
  currentStrategyMode: number;
  enableAutoAmapRoute: boolean;
  enableGlobalAmapRouteApi: boolean;

  isFirstScheduledItemOfDay(item: EventEntity): boolean;
  getScheduleOrchestrator(): ScheduleOrchestrator;
  calculateRealtimeSchedule(): void;
  regenerateGroups(): void;
  markScheduleChanged(): void;
  refreshTimelineView(): void;
}

export class TimelineRecalculationManager {
  private readonly host: ITimelineRecalculationHost;
  private hasLoggedLifecycleDetach: boolean = false;

  constructor(host: ITimelineRecalculationHost) {
    this.host = host;
  }

  public resolveEffectiveGlobalStartMinutes(): number {
    const pure = DateUtil.extractPureTime(this.host.globalStartTime) || this.host.globalStartTime;
    if (DateUtil.isValidTimeString(pure)) {
      return DateUtil.timeToMinutes(pure);
    }
    return DateUtil.timeToMinutes('08:00');
  }

  public testAllCommute(): void {
    this.host.events.forEach((item: EventEntity, index: number) => {
      if (item.status === 1 && index > 0 && this.shouldAutoRouteForItem(item)) {
        item.pre_travel_min = -1;
      }
    });
    this.recalculate();
  }

  public updateTravelMode(item: EventEntity, newMode: number): void {
    if (!item) {
      return;
    }
    hilog.info(0x0000, TAG, `[VM层] 接收到模式切换 -> ${item.name} 切换为: ${newMode}`);

    item.travel_mode = newMode;
    item.transport_mode = newMode;
    item.is_travel_manual = 0;
    if (this.shouldAutoRouteForItem(item)) {
      item.pre_travel_min = -1;
    } else if (item.pre_travel_min < 0) {
      item.pre_travel_min = 0;
    }

    if (item.id) {
      void EventRepositoryImpl.updateSingleField(item.id, EventEntity.TRAVEL_MODE, newMode, this.host.planId);
      void EventRepositoryImpl.updateSingleField(item.id, EventEntity.IS_TRAVEL_MANUAL, 0, this.host.planId);
      void EventRepositoryImpl.updateSingleField(item.id, EventEntity.PRE_TRAVEL_MINUTES, item.pre_travel_min, this.host.planId);
    }

    this.recalculateFromEventId(item.id);
  }

  public logTimelineSnapshot(scene: string): void {
    hilog.info(0x0000, TAG, `[DUAL_MODE_ACCEPT][snapshot][${scene}] ${this.buildTimelineSnapshot()}`);
  }

  public recalculateFromEventId(eventId: number): void {
    const startIndex = this.resolveRecalculateStartIndexByEventId(eventId);
    this.recalculateFromIndex(startIndex);
  }

  public recalculateFromIndex(startIndex: number): void {
    this.normalizeAutoRouteCandidates();
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    const startFromEventId = this.resolveScheduleAnchorEventId(safeStartIndex);
    const profile = StrategyPresets.getProfile(this.host.currentStrategyMode as TravelStrategyMode);
    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][recalc_trigger] scene=recalculate_from_index,mode=${this.host.currentStrategyMode},autoRoute=${this.isAutoRouteEnabled()},idleGap=${this.host.idleGapDetectionEnabled},idleGapMin=${this.host.idleGapTriggerMinutes},strategySlack=${profile.slackRatio},solverSlack=default,startIndex=${safeStartIndex},startFromEventId=${startFromEventId}`
    );

    TimelineCalculationService.recalculateFromIndex(
      this.host.events,
      safeStartIndex,
      this.host.globalStartTime,
      this.host.planStartDate,
      this.host.getScheduleOrchestrator(),
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.host.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.host.idleGapTriggerMinutes,
        startFromEventId: startFromEventId
      },
      (entity: EventEntity, calculated: SolverCalculatedItem | undefined): ApplyResultFlags =>
        this.applyCalculatedResult(entity, calculated)
    );

    this.host.calculateRealtimeSchedule();
    this.host.regenerateGroups();
    this.host.markScheduleChanged();
    this.host.refreshTimelineView();
    this.emitPaperExperimentSummary('recalculate_from_index');
  }

  public recalculate(): void {
    this.normalizeAutoRouteCandidates();
    if (!this.hasLoggedLifecycleDetach) {
      hilog.info(0x0000, TAG, '[LIFECYCLE_GUARD] recalculate uses context-free solver path.');
      this.hasLoggedLifecycleDetach = true;
    }
    const globalStartCandidate = DateUtil.extractPureTime(this.host.globalStartTime) || this.host.globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';
    const strategyProfile = StrategyPresets.getProfile(this.host.currentStrategyMode as TravelStrategyMode);
    hilog.info(
      0x0000,
      TAG,
      `[SHIFT_VM][recalculate_input] globalStart=${this.host.globalStartTime}, effectiveStart=${effectiveGlobalStart}, planStartDate=${this.host.planStartDate}, total=${this.host.events.length}`
    );
    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][recalc_trigger] scene=recalculate,mode=${this.host.currentStrategyMode},autoRoute=${this.isAutoRouteEnabled()},idleGap=${this.host.idleGapDetectionEnabled},idleGapMin=${this.host.idleGapTriggerMinutes},strategySlack=${strategyProfile.slackRatio},solverSlack=${strategyProfile.slackRatio}`
    );

    const result = TimelineCalculationService.recalculate(
      this.host.events,
      this.host.globalStartTime,
      this.host.planStartDate,
      this.host.getScheduleOrchestrator(),
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.host.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.host.idleGapTriggerMinutes,
        slackRatio: StrategyPresets.getProfile(this.host.currentStrategyMode as TravelStrategyMode).slackRatio
      },
      (entity: EventEntity, calculated: SolverCalculatedItem | undefined): ApplyResultFlags =>
        this.applyCalculatedResult(entity, calculated)
    );

    this.host.calculateRealtimeSchedule();
    this.host.regenerateGroups();
    this.host.markScheduleChanged();
    this.logScheduleShiftSnapshot('recalculate');
    if (result.hasFieldChanged || result.hasDayOffsetChanged) {
      this.host.refreshTimelineView();
    }
    this.emitPaperExperimentSummary('recalculate');
    this.logTimelineSnapshot('recalculate');
  }

  public recalculateTrafficOnly(): void {
    this.normalizeAutoRouteCandidates();
    const profile = StrategyPresets.getProfile(this.host.currentStrategyMode as TravelStrategyMode);
    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][recalc_trigger] scene=traffic_only,mode=${this.host.currentStrategyMode},autoRoute=${this.isAutoRouteEnabled()},idleGap=${this.host.idleGapDetectionEnabled},idleGapMin=${this.host.idleGapTriggerMinutes},strategySlack=${profile.slackRatio},solverSlack=default`
    );
    const result = TimelineCalculationService.recalculateTrafficOnly(
      this.host.events,
      this.host.globalStartTime,
      this.host.planStartDate,
      this.host.getScheduleOrchestrator(),
      {
        autoRouteEnabled: this.isAutoRouteEnabled(),
        idleGapDetectionEnabled: this.host.idleGapDetectionEnabled,
        idleGapTriggerMinutes: this.host.idleGapTriggerMinutes
      },
      (entity, minutes) => this.persistAutoPreTravel(entity, minutes)
    );

    if (!result.hasFieldChanged) {
      return;
    }

    this.host.calculateRealtimeSchedule();
    if (result.hasDayOffsetChanged) {
      this.host.regenerateGroups();
      this.host.markScheduleChanged();
    }
    this.logScheduleShiftSnapshot('traffic_only');
    this.host.refreshTimelineView();
    this.emitPaperExperimentSummary('traffic_only');
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
    const schedule = this.host.events
      .filter((e: EventEntity) => e.status === 1)
      .slice(0, limit)
      .map((e: EventEntity, idx: number) => {
        const forecastStart = e.forecast_start_time || '--:--';
        const forecastEnd = e.forecast_end_time || '--:--';
        return `${idx + 1}:${e.id}/${e.name}|${this.completionStatusLabel(e.completion_status)}|f=${forecastStart}-${forecastEnd}|aS=${e.actual_start_time}|aE=${e.actual_end_time}`;
      });

    if (schedule.length === 0) {
      return 'empty';
    }
    return schedule.join('; ');
  }

  private resolveRecalculateStartIndexByEventId(eventId: number): number {
    if (eventId <= 0) {
      return 0;
    }
    const index = this.host.events.findIndex((event: EventEntity) => event.id === eventId);
    if (index < 0) {
      return 0;
    }

    let prevScheduleIndex = -1;
    for (let i = index - 1; i >= 0; i--) {
      if (this.host.events[i].status === 1) {
        prevScheduleIndex = i;
        break;
      }
    }

    return prevScheduleIndex >= 0 ? prevScheduleIndex : 0;
  }

  private resolveScheduleAnchorEventId(startIndex: number): number {
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    for (let i = safeStartIndex; i < this.host.events.length; i++) {
      const item = this.host.events[i];
      if (item.status === 1 && item.id > 0) {
        return item.id;
      }
    }
    return -1;
  }

  private shouldPersistAutoPreTravel(entity: EventEntity, minutes: number): boolean {
    if (!entity || entity.id <= 0 || this.host.planId <= 0) {
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
    void EventRepositoryImpl.updateFields(entity.id, updates, this.host.planId);
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
      if (resultItem.dynamicStartTime !== undefined && entity.dynamic_start_time !== resultItem.dynamicStartTime) {
        entity.dynamic_start_time = resultItem.dynamicStartTime;
        changed = true;
      }
      if (resultItem.dynamicEndTime !== undefined && entity.dynamic_end_time !== resultItem.dynamicEndTime) {
        entity.dynamic_end_time = resultItem.dynamicEndTime;
        changed = true;
      }

      if (entity.lock_status === 0 && resultItem.computedStartTime) {
        const timeOnly = resultItem.computedStartTime.includes(' ')
          ? resultItem.computedStartTime.split(' ').pop() || resultItem.computedStartTime
          : resultItem.computedStartTime;
        if (entity.fixed_start_time !== timeOnly) {
          entity.fixed_start_time = timeOnly;
          changed = true;
        }
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

  private isAutoRouteEnabled(): boolean {
    return this.host.enableAutoAmapRoute && this.host.enableGlobalAmapRouteApi;
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
    if (this.host.isFirstScheduledItemOfDay(item)) {
      return false;
    }
    return true;
  }

  private normalizeAutoRouteCandidates(): void {
    for (let i = 0; i < this.host.events.length; i++) {
      const item = this.host.events[i];
      if (!item || item.status !== 1) {
        continue;
      }
      if (!this.shouldAutoRouteForItem(item)) {
        continue;
      }
      // 历史数据里存在 pre_travel_min=0 但应走自动路程的情况，这里统一修正为待计算态。
      if (item.pre_travel_min === 0 && item.is_travel_manual !== 1) {
        item.pre_travel_min = -1;
      }
    }
  }

  private logScheduleShiftSnapshot(scene: string): void {
    const schedule = this.host.events.filter((event: EventEntity) => event.status === 1);
    const parts: string[] = [];
    for (let i = 0; i < schedule.length; i++) {
      const item = schedule[i];
      parts.push(
        `${item.id}:${item.name}|pre=${item.pre_travel_min}|day=${item.day_offset}->${item.dynamic_day_offset}|time=${item.computed_time}`
      );
    }
    hilog.info(0x0000, TAG, `[SHIFT_VM][snapshot][${scene}] ${parts.join(' ; ')}`);
  }

  private emitPaperExperimentSummary(scene: string): void {
    const schedule = this.host.events.filter((event: EventEntity) => event.status === 1);
    const total = schedule.length;
    let conflict = 0;
    let conflictMin = 0;
    let gap = 0;
    let gapMin = 0;
    let overflow = 0;
    let durationMin = 0;
    let travelMin = 0;
    let spanStart = Number.MAX_SAFE_INTEGER;
    let spanEnd = 0;

    for (let i = 0; i < schedule.length; i++) {
      const item = schedule[i];
      durationMin += Math.max(0, item.duration ?? 0);
      travelMin += Math.max(0, item.pre_travel_min ?? 0);
      if (item.is_conflict) {
        conflict += 1;
        conflictMin += Math.max(0, item.gap_minutes ?? 0);
      }
      if (item.has_gap) {
        gap += 1;
        gapMin += Math.max(0, item.gap_minutes ?? 0);
      }
      if ((item.dynamic_day_offset ?? item.day_offset ?? 0) > (item.day_offset ?? 0)) {
        overflow += 1;
      }
      const dynamicStart = item.dynamic_start_time ?? 0;
      const dynamicEnd = item.dynamic_end_time ?? 0;
      if (dynamicStart > 0 && dynamicStart < spanStart) {
        spanStart = dynamicStart;
      }
      if (dynamicEnd > spanEnd) {
        spanEnd = dynamicEnd;
      }
    }

    const spanMin = (spanStart !== Number.MAX_SAFE_INTEGER && spanEnd > spanStart)
      ? Math.floor((spanEnd - spanStart) / (60 * 1000))
      : 0;
    const utilPermille = spanMin > 0 ? Math.floor((durationMin * 1000) / spanMin) : -1;

    hilog.info(
      0x0000,
      TAG,
      `[PAPER_EXP][vm_summary] scene=${scene},mode=${this.host.currentStrategyMode},total=${total},conflict=${conflict},conflictMin=${conflictMin},gap=${gap},gapMin=${gapMin},overflow=${overflow},durationMin=${durationMin},travelMin=${travelMin},spanMin=${spanMin},utilPermille=${utilPermille}`
    );
  }
}
