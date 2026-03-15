import { EventEntity } from '../../../model/entity/EventEntity';
import { ScheduleOrchestrator } from '../../../viewmodel/internal/ScheduleOrchestrator';
import { SolverCalculatedItem, ApplyResultFlags } from '../../../viewmodel/TimelineViewModel';
import { TimelineCalculateOptions } from '../../../domain/solver/TimeConstraintSolver';
import { DateUtil } from '../../../common/utils/DateUtil';

export interface RecalculateResult {
  hasFieldChanged: boolean;
  hasDayOffsetChanged: boolean;
}

export type ApplyResultFunction = (entity: EventEntity, result: SolverCalculatedItem | undefined) => ApplyResultFlags;
export type PersistAutoPreTravelFunction = (entity: EventEntity, minutes: number) => void;

export class TimelineCalculationService {
  static recalculate(
    events: EventEntity[],
    globalStartTime: string,
    planStartDate: number,
    orchestrator: ScheduleOrchestrator,
    options: TimelineCalculateOptions,
    applyResultFn: ApplyResultFunction
  ): RecalculateResult {
    const inputList = events.map(e => e.toInterface());
    const globalStartCandidate = DateUtil.extractPureTime(globalStartTime) || globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = orchestrator.calculate(inputList, effectiveGlobalStart, planStartDate, options);

    let hasFieldChanged = false;
    let hasDayOffsetChanged = false;
    events.forEach((entity, index) => {
      const flags = applyResultFn(entity, calculated[index] as SolverCalculatedItem | undefined);
      if (flags.changed) {
        hasFieldChanged = true;
      }
      if (flags.dayOffsetChanged) {
        hasDayOffsetChanged = true;
      }
    });

    return { hasFieldChanged, hasDayOffsetChanged };
  }

  static recalculateFromIndex(
    events: EventEntity[],
    startIndex: number,
    globalStartTime: string,
    planStartDate: number,
    orchestrator: ScheduleOrchestrator,
    options: TimelineCalculateOptions,
    applyResultFn: ApplyResultFunction
  ): RecalculateResult {
    const safeStartIndex = startIndex < 0 ? 0 : startIndex;
    const inputList = events.map(e => e.toInterface());
    const globalStartCandidate = DateUtil.extractPureTime(globalStartTime) || globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = orchestrator.calculate(inputList, effectiveGlobalStart, planStartDate, options);

    let hasFieldChanged = false;
    let hasDayOffsetChanged = false;
    events.forEach((entity: EventEntity, index: number) => {
      if (index < safeStartIndex) {
        return;
      }
      const flags = applyResultFn(entity, calculated[index] as SolverCalculatedItem | undefined);
      if (flags.changed) {
        hasFieldChanged = true;
      }
      if (flags.dayOffsetChanged) {
        hasDayOffsetChanged = true;
      }
    });

    return { hasFieldChanged, hasDayOffsetChanged };
  }

  static recalculateTrafficOnly(
    events: EventEntity[],
    globalStartTime: string,
    planStartDate: number,
    orchestrator: ScheduleOrchestrator,
    options: TimelineCalculateOptions,
    persistAutoPreTravelFn: PersistAutoPreTravelFunction
  ): RecalculateResult {
    const inputList = events.map(e => e.toInterface());
    const globalStartCandidate = DateUtil.extractPureTime(globalStartTime) || globalStartTime;
    const effectiveGlobalStart = DateUtil.isValidTimeString(globalStartCandidate) ? globalStartCandidate : '08:00';

    const calculated = orchestrator.calculate(inputList, effectiveGlobalStart, planStartDate, options);

    let hasChanged = false;
    let hasDayOffsetChanged = false;
    events.forEach((entity, index) => {
      const resultItem = calculated[index];
      if (!resultItem) {
        return;
      }

      if (resultItem.preTravelMinutes !== undefined && entity.pre_travel_min !== resultItem.preTravelMinutes) {
        entity.pre_travel_min = resultItem.preTravelMinutes;
        persistAutoPreTravelFn(entity, resultItem.preTravelMinutes);
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

    return { hasFieldChanged: hasChanged, hasDayOffsetChanged };
  }
}
