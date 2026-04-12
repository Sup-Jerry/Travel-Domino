// 文件路径: ets/viewmodel/TimelineInteractionHelper.ets
import { TimelineViewModel } from './TimelineViewModel';
import { EventEntity } from '../model/entity/EventEntity';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../common/utils/DateUtil';
import { TimelineDatePolicy } from '../domain/policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../domain/policy/TimelineExecutionState';

/**
 * 专门处理 UI 交互逻辑的辅助类
 * 作用：将 Index.ets 中的复杂判断逻辑剥离出来
 */
export class TimelineInteractionHelper {

  /**
   * [核心逻辑] 检测空窗并回调
   * @param vm 传入 ViewModel 实例以获取数据和调用方法
   */
  public static checkForGapAndPrompt(vm: TimelineViewModel, onGapFound?: (item: EventEntity) => void) {
    setTimeout(() => {
      const gapItem = vm.getSortedGaps().find((item: EventEntity) => !item.is_ignore_wait);

      // 如果发现了空窗，并且外部传入了回调函数，就通知外部
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
    lat?: number, // 接收纬度
    lng?: number  // 接收经度
  ): Promise<void> {
    hilog.info(0x0000, 'TimelineHelper', `[节点2: 中转站 handleSaveItem 接到数据 -> 地点: ${name}, lat: ${lat}, lng: ${lng}`);
    const priorityVal = isMustVisit ? 1 : 0;

    if (editingItemId !== -1) {
      // 把 lat 和 lng 传给 updateEventInfo
      await vm.updateEventInfo(editingItemId, name, duration, fixedTime, dayOffset || 0, isHardLock, note, priorityVal, lat, lng);
    } else {
      // 把 lat 和 lng 传给 addNewItem
      await vm.addNewItem(name, duration, isSchedule, fixedTime, dayOffset || 0, preTravel ?? -1, isHardLock, note, priorityVal, lat, lng);
    }
    TimelineInteractionHelper.checkForGapAndPrompt(vm, onGapFound);
  }

  public static handleCommuteChange(
    vm: TimelineViewModel,
    item: EventEntity,
    newMinutes: number,
    // 新增参数
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
    // 新增参数
    onGapFound?: (item: EventEntity) => void
  ) {
    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    vm.updateEventInfo(item.id, item.name, duration, fixedTime, effectiveDayOffset, lockStatus === 1, item.note, item.priority); // 修改点
    const target = vm.events.find(e => e.id === item.id);
    if (target) {
      target.lock_status = lockStatus;
    }
    TimelineInteractionHelper.checkForGapAndPrompt(vm, onGapFound);
  }

  public static pickCompanionFocusEventId(vm: TimelineViewModel, _nowTs: number = Date.now()): number {
    const schedule = vm.executionCoordinator.getOrderedScheduleEvents();
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
    const schedule = vm.executionCoordinator.getOrderedScheduleEvents();
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
