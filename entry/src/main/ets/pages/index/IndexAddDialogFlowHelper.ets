import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { TimelineInteractionHelper } from '../../viewmodel/TimelineInteractionHelper';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AddDialogDefaults, InitDialogData, PendingItemData } from './IndexTypes';
import { IndexAddDialogHelper } from './IndexAddDialogHelper';

export interface AddDialogPreparedState {
  isCreateMode: boolean;
  smartTime: string;
  initDayOffset: number;
  initLat: number;
  initLng: number;
  initCoordValid: boolean;
  currentPreTravel: number;
  currentPriority: number;
}

export interface AddDialogConfirmInput {
  name: string;
  duration: number;
  isSchedule: boolean;
  fixedTime?: string;
  dayOffset?: number;
  preTravel?: number;
  isHardLock?: boolean;
  note?: string;
  isMustVisit?: boolean;
  lat?: number;
  lng?: number;
}

export interface AddDialogConfirmContext {
  vm: TimelineViewModel;
  editingItemId: number;
  planStartDate: number;
  collapsedDayOffsets: number[];
  hasActiveFilter: boolean;
  onGapFoundCallback: (item: EventEntity) => void;
}

export interface AddDialogConfirmResult {
  nextEditingItemId: number;
  nextCollapsedDayOffsets: number[];
  clearFilter: boolean;
  pendingItem: PendingItemData | null;
  openConflictDialog: boolean;
  toastMessage?: string;
}

export class IndexAddDialogFlowHelper {
  static prepareDialogState(events: EventEntity[], editingItemId: number, initData?: InitDialogData): AddDialogPreparedState {
    const isCreateMode = editingItemId === -1;
    const createDefaults = new AddDialogDefaults();

    if (isCreateMode) {
      const computed = IndexAddDialogHelper.resolveAddDialogDefaults(events);
      createDefaults.dayOffset = computed.dayOffset;
      createDefaults.suggestedTime = computed.suggestedTime;
    }

    const smartTime = initData?.suggestedTime ||
      (isCreateMode ? createDefaults.suggestedTime : IndexAddDialogHelper.calculateSmartTime(events, editingItemId));
    const initDayOffset = initData?.dayOffset !== undefined
      ? initData.dayOffset
      : (isCreateMode ? createDefaults.dayOffset : 0);
    const initLat = initData?.lat || 0;
    const initLng = initData?.lng || 0;

    let currentPreTravel = 0;
    let currentPriority = 0;
    if (editingItemId !== -1) {
      const item = events.find((event: EventEntity) => event.id === editingItemId);
      if (item) {
        if (item.pre_travel_min > 0) {
          currentPreTravel = item.pre_travel_min;
        }
        currentPriority = item.priority;
      }
    }

    return {
      isCreateMode: isCreateMode,
      smartTime: smartTime,
      initDayOffset: initDayOffset,
      initLat: initLat,
      initLng: initLng,
      initCoordValid: IndexAddDialogFlowHelper.hasValidCoordinate(initLat, initLng),
      currentPreTravel: currentPreTravel,
      currentPriority: currentPriority
    };
  }

  static async handleDialogConfirm(
    context: AddDialogConfirmContext,
    input: AddDialogConfirmInput
  ): Promise<AddDialogConfirmResult> {
    const hasCoordinate = IndexAddDialogFlowHelper.hasValidCoordinate(input.lat, input.lng);
    hilog.info(0x0000, 'IndexPage', `[DIALOG_SAVE] has_coordinate=${hasCoordinate}`);

    if (context.editingItemId !== -1 && !context.vm.events.find((item: EventEntity) => item.id === context.editingItemId)) {
      hilog.warn(0x0000, 'IndexPage', `[DIALOG_SAVE_SKIP] reason=item_not_found, itemId=${context.editingItemId}`);
      return {
        nextEditingItemId: -1,
        nextCollapsedDayOffsets: [...context.collapsedDayOffsets],
        clearFilter: false,
        pendingItem: null,
        openConflictDialog: false,
        toastMessage: '该地点已不存在，请刷新后重试'
      };
    }

    if (context.planStartDate <= 0 || (input.dayOffset !== undefined && input.dayOffset >= 0)) {
      await TimelineInteractionHelper.handleSaveItem(
        context.vm,
        context.editingItemId,
        input.name,
        input.duration,
        input.isSchedule,
        input.fixedTime,
        input.dayOffset,
        input.preTravel,
        context.onGapFoundCallback,
        input.isHardLock,
        input.note,
        input.isMustVisit,
        input.lat,
        input.lng
      );

      let nextCollapsedDayOffsets = [...context.collapsedDayOffsets];
      let clearFilter = false;

      if (input.isSchedule) {
        const targetDayOffset = input.dayOffset ?? 0;
        nextCollapsedDayOffsets = nextCollapsedDayOffsets.filter((offset: number) => offset !== targetDayOffset);
        if (context.hasActiveFilter) {
          clearFilter = true;
        }
      }

      context.vm.refreshTimelineView();
      const scheduleCount = context.vm.events.filter((event: EventEntity) => event.status === 1).length;
      hilog.info(
        0x0000,
        'IndexPage',
        `[ADD_UI][after_save] total=${context.vm.events.length}, schedule=${scheduleCount}, groups=${context.vm.groupedEvents.length}, dayOffset=${input.dayOffset ?? 0}, isSchedule=${input.isSchedule}`
      );

      return {
        nextEditingItemId: -1,
        nextCollapsedDayOffsets: nextCollapsedDayOffsets,
        clearFilter: clearFilter,
        pendingItem: null,
        openConflictDialog: false
      };
    }

    const targetMs = TimelineDatePolicy.dayOffsetToDayStartMs(context.planStartDate, input.dayOffset!);
    const pendingItem: PendingItemData = {
      id: context.editingItemId,
      name: input.name,
      duration: input.duration,
      isSchedule: input.isSchedule,
      fixedTime: input.fixedTime,
      dayOffset: input.dayOffset!,
      targetDateMs: targetMs,
      note: input.note || '',
      lat: input.lat,
      lng: input.lng
    };

    return {
      nextEditingItemId: context.editingItemId,
      nextCollapsedDayOffsets: [...context.collapsedDayOffsets],
      clearFilter: false,
      pendingItem: pendingItem,
      openConflictDialog: true
    };
  }

  private static hasValidCoordinate(lat?: number, lng?: number): boolean {
    return Number.isFinite(lat) && Number.isFinite(lng) &&
      Math.abs(lat!) <= 90 && Math.abs(lng!) <= 180 &&
      !(lat === 0 && lng === 0);
  }
}
