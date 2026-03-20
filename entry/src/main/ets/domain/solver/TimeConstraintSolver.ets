// 路径: ets/domain/solver/TimeConstraintSolver.ets
import { LocationInfo } from '../../model/interface/IMapService';
import { DateUtil } from '../../common/utils/DateUtil';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { TrafficEngine } from '../../infrastructure/services/TrafficEngine';
import hilog from '@ohos.hilog';

export interface TimelineCalculateOptions {
  autoRouteEnabled?: boolean;
  idleGapDetectionEnabled?: boolean;
  idleGapTriggerMinutes?: number;
  startFromEventId?: number;
  slackRatio?: number;
}

export class TimeConstraintSolver {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;
  private static readonly MINUTE_MS: number = 60 * 1000;
  private static readonly FALLBACK_START_MIN: number = 8 * 60;
  private static readonly DEFAULT_IDLE_GAP_TRIGGER_MINUTES: number = 45;

  private static getDayStart(timestamp: number): number {
    const d = new Date(timestamp);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  private static calcDayOffset(baseTimestamp: number, timestamp: number): number {
    const dayStart = TimeConstraintSolver.getDayStart(timestamp);
    return Math.floor((dayStart - baseTimestamp) / TimeConstraintSolver.DAY_MS);
  }

  private static buildTimestamp(baseTimestamp: number, dayOffset: number, minuteOfDay: number): number {
    return baseTimestamp + (dayOffset * TimeConstraintSolver.DAY_MS) + (minuteOfDay * TimeConstraintSolver.MINUTE_MS);
  }

  private static isSameNaturalDay(tsA: number, tsB: number): boolean {
    return TimeConstraintSolver.getDayStart(tsA) === TimeConstraintSolver.getDayStart(tsB);
  }

  private static resolveGlobalStartMin(globalStartTimeStr: string): number {
    if (DateUtil.isValidTimeString(globalStartTimeStr)) {
      return DateUtil.timeToMinutes(globalStartTimeStr);
    }

    const pureTime = DateUtil.extractPureTime(globalStartTimeStr);
    if (pureTime && DateUtil.isValidTimeString(pureTime)) {
      return DateUtil.timeToMinutes(pureTime);
    }

    return TimeConstraintSolver.FALLBACK_START_MIN;
  }

  public static calculateTimeline(
    events: TravelPlanItem[],
    globalStartTimeStr: string,
    planStartDate: number,
    options?: TimelineCalculateOptions
  ): TravelPlanItem[] {
    const baseDate = new Date(planStartDate > 0 ? planStartDate : new Date().getTime());
    baseDate.setHours(0, 0, 0, 0);
    const baseTimestamp = baseDate.getTime();
    const globalStartMin = TimeConstraintSolver.resolveGlobalStartMin(globalStartTimeStr);

    hilog.info(
      0x0000,
      'TimeConstraintSolver',
      `[SHIFT_SOLVER][input] globalStartTimeStr=${globalStartTimeStr}, resolvedStartMin=${globalStartMin}, planStartDate=${planStartDate}, baseTimestamp=${baseTimestamp}`
    );

    // 深拷贝，保留原顺序
    const processList: TravelPlanItem[] = JSON.parse(JSON.stringify(events));

    // 仅抽出 schedule 做时间推演，但对象引用仍然指向 processList 内部元素
    const scheduleList: TravelPlanItem[] = processList.filter((e: TravelPlanItem) => e.status === 1);
    const startFromEventId = options?.startFromEventId ?? -1;
    let startScheduleIndex = 0;
    if (startFromEventId > 0) {
      const foundIndex = scheduleList.findIndex((item: TravelPlanItem) => (item.id ?? -1) === startFromEventId);
      if (foundIndex >= 0) {
        startScheduleIndex = foundIndex;
      }
    }
    const autoRouteEnabled = options?.autoRouteEnabled ?? true;
    const idleGapDetectionEnabled = options?.idleGapDetectionEnabled ?? true;
    const idleGapTriggerMinutesRaw = Number(options?.idleGapTriggerMinutes ?? TimeConstraintSolver.DEFAULT_IDLE_GAP_TRIGGER_MINUTES);
    const idleGapTriggerMinutes = Number.isFinite(idleGapTriggerMinutesRaw)
      ? Math.max(1, Math.floor(idleGapTriggerMinutesRaw))
      : TimeConstraintSolver.DEFAULT_IDLE_GAP_TRIGGER_MINUTES;
    const idleGapTriggerMs = idleGapTriggerMinutes * TimeConstraintSolver.MINUTE_MS;
    const slackRatio = options?.slackRatio ?? 0.25;

    let cursorTimestamp = baseTimestamp + (globalStartMin * TimeConstraintSolver.MINUTE_MS);
    let previousItem: TravelPlanItem | null = null;
    let previousFinalDayOffset: number = -999999;

    if (startScheduleIndex > 0) {
      previousItem = scheduleList[startScheduleIndex - 1];
      const prevDynamicStart = previousItem.dynamicStartTime ?? 0;
      if (prevDynamicStart > 0) {
        cursorTimestamp = prevDynamicStart + (previousItem.duration * TimeConstraintSolver.MINUTE_MS);
      } else {
        const prevDayOffset = previousItem.dynamicDayOffset ?? previousItem.dayOffset ?? 0;
        const prevRawTime = DateUtil.extractPureTime(previousItem.computedStartTime ?? '') || globalStartTimeStr;
        const prevStartMin = DateUtil.isValidTimeString(prevRawTime) ? DateUtil.timeToMinutes(prevRawTime) : globalStartMin;
        cursorTimestamp = TimeConstraintSolver.buildTimestamp(baseTimestamp, prevDayOffset, prevStartMin) +
          (previousItem.duration * TimeConstraintSolver.MINUTE_MS);
      }
      previousFinalDayOffset = previousItem.dynamicDayOffset ?? previousItem.dayOffset ?? 0;
    }

    for (let i = startScheduleIndex; i < scheduleList.length; i++) {
      const item = scheduleList[i];

      // 每轮先清空动态计算结果，避免脏值残留
      item.isConflict = false;
      item.conflictMsg = '';
      item.hasGap = false;
      item.gapMinutes = 0;
      item.naturalStartTime = '';

      // 邻居变动检测
      const currentPrevId = previousItem ? (previousItem.id ?? -1) : -1;
      const isManualTravel = (item.isTravelManual ?? 0) === 1;
      if (item.lastFromId !== currentPrevId) {
        if (!isManualTravel && autoRouteEnabled) {
          item.preTravelMinutes = -1;
        }
        item.lastFromId = currentPrevId;
      }

      // 路程计算
      if (previousItem) {
        const baseDayOffset = item.dayOffset ?? 0;
        const isDayFirstByBase = (i === 0) || (baseDayOffset > previousFinalDayOffset);
        if (isDayFirstByBase) {
          item.preTravelMinutes = 0;
        } else if (isManualTravel) {
          if (item.preTravelMinutes === undefined || item.preTravelMinutes === null || item.preTravelMinutes < 0) {
            item.preTravelMinutes = 0;
          }
        } else if (!autoRouteEnabled) {
          if (item.preTravelMinutes === undefined || item.preTravelMinutes === null || item.preTravelMinutes < 0) {
            item.preTravelMinutes = 0;
          }
        } else if (item.preTravelMinutes === -1 || item.preTravelMinutes === -2) {
          const fromInfo: LocationInfo = {
            name: previousItem.name,
            address: previousItem.address ?? '',
            latitude: previousItem.latitude ?? 0,
            longitude: previousItem.longitude ?? 0
          };

          const toInfo: LocationInfo = {
            name: item.name,
            address: item.address ?? '',
            latitude: item.latitude ?? 0,
            longitude: item.longitude ?? 0
          };

          const mode = item.travelMode ?? 2;
          const startTimeStr = DateUtil.formatDate(new Date(cursorTimestamp), "HH:mm");

          hilog.info(
            0x0000,
            'TimeConstraintSolver',
            `[Solver] 查通勤 ${previousItem.name} -> ${item.name}, mode=${mode}`
          );

          item.transitWarning = (mode === 3);
          const commute = TrafficEngine.getInstance().getCommuteMinutes(fromInfo, toInfo, mode, startTimeStr);
          item.preTravelMinutes = commute;
        } else if (item.preTravelMinutes === undefined || item.preTravelMinutes === null) {
          item.preTravelMinutes = 0;
        }
      } else {
        item.preTravelMinutes = 0;
      }

      const originalOffset = item.dayOffset ?? 0;
      const travelMs = (item.preTravelMinutes ?? 0) * TimeConstraintSolver.MINUTE_MS;

      let idealStartTimeFromCursor = 0;
      if (previousItem) {
        idealStartTimeFromCursor = cursorTimestamp + travelMs;
      } else {
        idealStartTimeFromCursor = TimeConstraintSolver.buildTimestamp(
          baseTimestamp,
          originalOffset,
          globalStartMin
        );
      }

      let finalStartTimestamp = 0;
      let finalDayOffset = originalOffset;

      const hasFixedTime = !!(item.fixedStartTime && item.fixedStartTime.trim().length > 0);

      if (!previousItem) {
        // 第一个日程项
        if (hasFixedTime) {
          const fixMin = DateUtil.timeToMinutes(item.fixedStartTime!);
          finalDayOffset = originalOffset;
          finalStartTimestamp = TimeConstraintSolver.buildTimestamp(baseTimestamp, finalDayOffset, fixMin);
        } else {
          finalDayOffset = originalOffset;
          finalStartTimestamp = TimeConstraintSolver.buildTimestamp(
            baseTimestamp,
            finalDayOffset,
            globalStartMin
          );
        }
      } else if (hasFixedTime) {
        // 有固定时间：允许因为前序跨午夜而把事件整体推进到后续自然日
        const fixMin = DateUtil.timeToMinutes(item.fixedStartTime!);
        const cursorDayOffset = TimeConstraintSolver.calcDayOffset(baseTimestamp, idealStartTimeFromCursor);

        let anchorDayOffset = Math.max(originalOffset, cursorDayOffset);
        let anchorTimestamp = TimeConstraintSolver.buildTimestamp(baseTimestamp, anchorDayOffset, fixMin);

        const crossedToFutureDay = cursorDayOffset > originalOffset;

        // 只有在“前序已经把时间轴推进到了更晚的自然日”时，才允许整体顺延到下一个自然日
        if (crossedToFutureDay) {
          while (anchorTimestamp < idealStartTimeFromCursor - TimeConstraintSolver.MINUTE_MS) {
            anchorDayOffset += 1;
            anchorTimestamp = TimeConstraintSolver.buildTimestamp(baseTimestamp, anchorDayOffset, fixMin);
          }
        }

        finalDayOffset = anchorDayOffset;

        if (item.lockStatus === 1) {
          // 刚性时间：同一天内迟到仍报冲突；跨天推进时允许整体迁移到新的自然日
          if (!crossedToFutureDay && anchorTimestamp < idealStartTimeFromCursor - TimeConstraintSolver.MINUTE_MS) {
            const diffMin = Math.floor((idealStartTimeFromCursor - anchorTimestamp) / TimeConstraintSolver.MINUTE_MS);
            item.isConflict = true;
            item.conflictMsg = `冲突 ${diffMin} min`;
            item.gapMinutes = diffMin;
            finalStartTimestamp = anchorTimestamp;
            hilog.warn(
              0x0000,
              'TimeConstraintSolver',
              `[ANCHOR_CONFLICT][solver] id=${item.id ?? -1}, name=${item.name}, dayOffset=${originalOffset}, ideal=${idealStartTimeFromCursor}, anchor=${anchorTimestamp}, diffMin=${diffMin}`
            );
          } else {
            const gapMs = anchorTimestamp - idealStartTimeFromCursor;
            const sameDayGap = TimeConstraintSolver.isSameNaturalDay(anchorTimestamp, idealStartTimeFromCursor);
            if (idleGapDetectionEnabled && sameDayGap && gapMs >= idleGapTriggerMs) {
              item.hasGap = true;
              item.gapMinutes = Math.floor(gapMs / TimeConstraintSolver.MINUTE_MS);
              item.naturalStartTime = DateUtil.formatDate(new Date(idealStartTimeFromCursor), "HH:mm");
            }
            finalStartTimestamp = anchorTimestamp;
          }
        } else {
          // 非刚性时间：同日内晚到就顺延；跨到更晚自然日则整体落到新自然日的固定时刻
          if (idealStartTimeFromCursor > anchorTimestamp) {
            finalStartTimestamp = idealStartTimeFromCursor;
          } else {
            const gapMs = anchorTimestamp - idealStartTimeFromCursor;
            const sameDayGap = TimeConstraintSolver.isSameNaturalDay(anchorTimestamp, idealStartTimeFromCursor);
            if (idleGapDetectionEnabled && sameDayGap && gapMs >= idleGapTriggerMs) {
              item.hasGap = true;
              item.gapMinutes = Math.floor(gapMs / TimeConstraintSolver.MINUTE_MS);
              item.naturalStartTime = DateUtil.formatDate(new Date(idealStartTimeFromCursor), "HH:mm");
            }
            finalStartTimestamp = anchorTimestamp;
          }
        }
      } else {
        // 无固定时间：默认跟随前序游标，但不得早于用户原始选择的自然日
        const selectedDayStartTimestamp = TimeConstraintSolver.buildTimestamp(
          baseTimestamp,
          originalOffset,
          globalStartMin
        );

        if (originalOffset > previousFinalDayOffset) {
          finalStartTimestamp = Math.max(selectedDayStartTimestamp, idealStartTimeFromCursor);
        } else {
          finalStartTimestamp = idealStartTimeFromCursor;
          if (finalStartTimestamp < selectedDayStartTimestamp) {
            finalStartTimestamp = selectedDayStartTimestamp;
          }
        }

        finalDayOffset = TimeConstraintSolver.calcDayOffset(baseTimestamp, finalStartTimestamp);
        if (finalDayOffset < originalOffset) {
          finalDayOffset = originalOffset;
        }
      }

      // 以最终开始时间反推最终归属日（仅写入动态字段，不污染用户基准 dayOffset）
      finalDayOffset = TimeConstraintSolver.calcDayOffset(baseTimestamp, finalStartTimestamp);
      item.dynamicDayOffset = finalDayOffset;
      if (finalDayOffset !== originalOffset) {
        hilog.info(0x0000, 'TimeConstraintSolver', `[DAY_OFFSET_GUARD][solver] name=${item.name} base=${originalOffset} dynamic=${finalDayOffset}`);
      }
      item.dynamicStartTime = finalStartTimestamp;

      const startObj = new Date(finalStartTimestamp);
      const endObj = new Date(finalStartTimestamp + item.duration * TimeConstraintSolver.MINUTE_MS);
      item.dynamicEndTime = endObj.getTime();

      const isDayFirst = (i === 0) || (finalDayOffset > previousFinalDayOffset);

      if (isDayFirst) {
        item.computedStartTime = DateUtil.formatDate(startObj, "MM-dd HH:mm");
      } else {
        item.computedStartTime = DateUtil.formatDate(startObj, "HH:mm");
      }

      const endTimeStr = DateUtil.formatDate(endObj, "HH:mm");
      const startDayBase = new Date(startObj).setHours(0, 0, 0, 0);
      const endDayBase = new Date(endObj).setHours(0, 0, 0, 0);
      const diffDays = Math.floor((endDayBase - startDayBase) / TimeConstraintSolver.DAY_MS);

      if (diffDays === 0) {
        item.computedEndTime = endTimeStr;
      } else if (diffDays === 1) {
        item.computedEndTime = `次日 ${endTimeStr}`;
      } else {
        item.computedEndTime = `+${diffDays}天 ${endTimeStr}`;
      }

      cursorTimestamp = endObj.getTime() + (60 * slackRatio * TimeConstraintSolver.MINUTE_MS);
      previousItem = item;
      previousFinalDayOffset = finalDayOffset;
    }

    // 返回原顺序，保证 ViewModel 用 index 回填时不乱位
    return processList;
  }
}
