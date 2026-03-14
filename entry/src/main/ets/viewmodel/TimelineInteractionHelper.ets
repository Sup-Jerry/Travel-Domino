// 鏂囦欢璺緞: ets/viewmodel/TimelineInteractionHelper.ets
import { TimelineViewModel } from './TimelineViewModel';
import { EventEntity } from '../model/entity/EventEntity';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../common/utils/DateUtil';
import { TimelineDatePolicy } from '../domain/policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../domain/policy/TimelineExecutionState';

/**
 * 涓撻棬澶勭悊 UI 浜や簰閫昏緫鐨勮緟鍔╃被
 * 浣滅敤锛氬皢 Index.ets 涓殑澶嶆潅鍒ゆ柇閫昏緫鍓ョ鍑烘潵
 */
export class TimelineInteractionHelper {

  /**
   * [鏍稿績閫昏緫] 妫€娴嬬┖绐楀苟寮圭獥
   * @param vm 浼犲叆 ViewModel 瀹炰緥浠ヨ幏鍙栨暟鎹拰璋冪敤鏂规硶
   */
  public static checkForGapAndPrompt(vm: TimelineViewModel, onGapFound?: (item: EventEntity) => void) {
    setTimeout(() => {
      const gapItem = vm.events.find(e => e.has_gap && !e.is_ignore_wait);

      // 濡傛灉鍙戠幇浜嗙┖绐楋紝骞朵笖澶栭儴浼犱簡鍥炶皟鍑芥暟锛屽氨閫氱煡澶栭儴
      if (gapItem && onGapFound) {
        onGapFound(gapItem);
      }
    }, 50);
  }

  public static async handleSaveItem(
    vm: TimelineViewModel,
    editingItemId: number,
    name: string,
    duration: number,
    isSchedule: boolean,
    fixedTime?: string,
    dayOffset?: number,
    preTravel?: number,
    onGapFound?: (item: EventEntity) => void,
    isHardLock: boolean = false,
    note: string = '',
    isMustVisit: boolean = false,
    lat?: number, // 鉁?[鏂板] 鎺ユ敹绾害
    lng?: number  // 鉁?[鏂板] 鎺ユ敹缁忓害
  ): Promise<void> {
    hilog.info(0x0000, 'TimelineHelper', `[鑺傜偣2: 涓浆绔橾 handleSaveItem 鎺ュ埌鏁版嵁 -> 鍦扮偣: ${name}, lat: ${lat}, lng: ${lng}`);
    const priorityVal = isMustVisit ? 1 : 0;

    if (editingItemId !== -1) {
      // 鉁?[淇敼] 鎶?lat 鍜?lng 浼犵粰 updateEventInfo
      await vm.updateEventInfo(editingItemId, name, duration, fixedTime, dayOffset || 0, isHardLock, note, priorityVal, lat, lng);
    } else {
      // 鉁?[淇敼] 鎶?lat 鍜?lng 浼犵粰 addNewItem
      await vm.addNewItem(name, duration, isSchedule, fixedTime, dayOffset || 0, preTravel ?? -1, isHardLock, note, priorityVal, lat, lng);
    }
    TimelineInteractionHelper.checkForGapAndPrompt(vm, onGapFound);
  }

  public static handleCommuteChange(
    vm: TimelineViewModel,
    item: EventEntity,
    newMinutes: number,
    // 鉁?[鏂板鍙傛暟]
    onGapFound?: (item: EventEntity) => void
  ) {
    const index = vm.events.indexOf(item);
    if (index !== -1) {
      vm.updateCommute(index, newMinutes);
      TimelineInteractionHelper.checkForGapAndPrompt(vm, onGapFound);
    }
  }

  public static handleTimeUpdate(
    vm: TimelineViewModel,
    item: EventEntity,
    duration: number,
    fixedTime: string,
    lockStatus: number,
    // 鉁?[鏂板鍙傛暟]
    onGapFound?: (item: EventEntity) => void
  ) {
    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    vm.updateEventInfo(item.id, item.name, duration, fixedTime, effectiveDayOffset, lockStatus === 1, item.note, item.priority); // 淇敼鐐?
    const target = vm.events.find(e => e.id === item.id);
    if (target) {
      target.lock_status = lockStatus;
    }
    TimelineInteractionHelper.checkForGapAndPrompt(vm, onGapFound);
  }

  public static pickCompanionFocusEventId(vm: TimelineViewModel, _nowTs: number = Date.now()): number {
    const schedule = vm.getOrderedScheduleEvents();
    if (schedule.length === 0) {
      return -1;
    }

    const active = schedule.find((e: EventEntity) => TimelineExecutionState.isActive(e));
    if (active) {
      return active.id;
    }

    const pending = schedule.filter((e: EventEntity) => TimelineExecutionState.isStartable(e));
    if (pending.length === 0) {
      return schedule[0].id;
    }
    return pending[0].id;
  }

  public static findNextPendingEventId(vm: TimelineViewModel, afterEventId: number): number {
    const schedule = vm.getOrderedScheduleEvents();
    if (schedule.length === 0) {
      return -1;
    }

    const startIndex = schedule.findIndex((e: EventEntity) => e.id === afterEventId);
    if (startIndex < 0) {
      const fallback = schedule.find((e: EventEntity) => TimelineExecutionState.isStartable(e));
      return fallback ? fallback.id : -1;
    }

    for (let i = startIndex + 1; i < schedule.length; i++) {
      if (TimelineExecutionState.isStartable(schedule[i])) {
        return schedule[i].id;
      }
    }
    return -1;
  }

  private static resolvePlannedStartTs(vm: TimelineViewModel, item: EventEntity): number {
    if (vm.planStartDate <= 0) {
      return 0;
    }

    const plannedText = item.computed_time || item.fixed_start_time || '';
    if (!plannedText || !DateUtil.isValidTimeString(plannedText)) {
      return 0;
    }

    const dayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    return TimelineDatePolicy.buildPlannedTimestamp(vm.planStartDate, dayOffset, plannedText);
  }
}

