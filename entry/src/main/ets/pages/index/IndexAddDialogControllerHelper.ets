import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { InitDialogData, PendingItemData } from './IndexTypes';
import { IndexAddDialogFlowHelper } from './IndexAddDialogFlowHelper';
import { IndexAddDialogHelper } from './IndexAddDialogHelper';
import { IndexDialogManager } from './IndexDialogManager';

export interface IndexAddDialogControllerContext {
  vm: TimelineViewModel;
  editingItemId: number;
  currentPlanId: number;
  collapsedDayOffsets: number[];
  setCollapsedDayOffsets: (offsets: number[]) => void;
  clearFilter: () => void;
  hasActiveFilter: boolean;
  onGapFoundCallback: (item: EventEntity) => void;
  setPendingItem: (item: PendingItemData | null) => void;
  openConflictDialog: () => void;
  setEditingItemId: (id: number) => void;
  safeShowToast: (message: string) => void;
}

export class IndexAddDialogControllerHelper {
  static create(
    context: IndexAddDialogControllerContext,
    initData?: InitDialogData
  ): CustomDialogController {
    const prepared = IndexAddDialogFlowHelper.prepareDialogState(context.vm.events, context.editingItemId, initData);
    hilog.info(
      0x0000,
      'Index',
      `[MAP_TRACE][open_dialog] editId=${context.editingItemId}, createMode=${prepared.isCreateMode}, nameLen=${(initData?.name || '').length}, initCoordValid=${prepared.initCoordValid}, lat=${prepared.initLat}, lng=${prepared.initLng}`
    );

    return IndexDialogManager.createAddItemController({
      initName: initData?.name || '',
      initNote: initData?.note || '',
      initDuration: initData?.duration || 60,
      initIsAnchor: initData?.isAnchor || false,
      initFixedTime: initData?.fixedTime || '',
      initSuggestedTime: prepared.smartTime,
      initIsSchedule: initData ? true : false,
      initDayOffset: prepared.initDayOffset,
      initPreTravel: prepared.currentPreTravel,
      initPriority: prepared.currentPriority,
      storageScopePlanId: context.currentPlanId,
      planStartDate: context.vm.planStartDate,
      initLat: prepared.initLat,
      initLng: prepared.initLng,
      onDateChangedRecommendTime: (dayOffset: number, currentTime: string): string => {
        if (!prepared.isCreateMode) {
          return currentTime;
        }
        return IndexAddDialogHelper.recommendAddByDayOffset(context.vm.events, dayOffset);
      },
      onConfirm: async (name, duration, isSchedule, fixedTime, dayOffset, preTravel, isHardLock, note, isMustVisit, lat, lng) => {
        const result = await IndexAddDialogFlowHelper.handleDialogConfirm(
          {
            vm: context.vm,
            editingItemId: context.editingItemId,
            planStartDate: context.vm.planStartDate,
            collapsedDayOffsets: context.collapsedDayOffsets,
            hasActiveFilter: context.hasActiveFilter,
            onGapFoundCallback: context.onGapFoundCallback
          },
          { name, duration, isSchedule, fixedTime, dayOffset, preTravel, isHardLock, note, isMustVisit, lat, lng }
        );

        context.setCollapsedDayOffsets(result.nextCollapsedDayOffsets);
        if (result.clearFilter) {
          context.clearFilter();
          hilog.info(0x0000, 'IndexPage', '[ADD_UI][clear_filter_for_visibility] reason=new_schedule_item');
        }
        if (result.toastMessage) {
          context.safeShowToast(result.toastMessage);
        }
        if (result.pendingItem) {
          context.setPendingItem(result.pendingItem);
        }
        if (result.openConflictDialog) {
          setTimeout(() => {
            context.openConflictDialog();
          }, 100);
        }
        context.setEditingItemId(result.nextEditingItemId);
      }
    });
  }
}
