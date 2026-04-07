import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { InitDialogData } from './IndexTypes';
import { ConflictFlowContext, IndexConflictFlowHelper } from './IndexConflictFlowHelper';
import { IndexLayoutCallbacksHelper, IndexPageLayoutCallbacks } from './IndexLayoutCallbacksHelper';
import { IndexPageActionsHelper } from './IndexPageActionsHelper';
import { IndexStateManager } from './IndexStateManager';

export interface IndexLayoutCallbacksBuilderContext {
  vm: TimelineViewModel;
  planTitle: string;
  currentPlanId: number;
  collapsedDayOffsets: number[];
  backlogExpanded: boolean;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  setCompanionMode: (value: boolean) => void;
  setManualPlanningWeatherRefresh: (value: boolean) => void;
  setHintPopupVisible: (value: boolean) => void;
  setScorePopupVisible: (value: boolean) => void;
  toggleHintPopup: () => void;
  toggleScorePopup: () => void;
  setBacklogExpanded: (value: boolean) => void;
  setCollapsedDayOffsets: (offsets: number[]) => void;
  setEditingItemId: (id: number) => void;
  setHasUnsavedChanges: (value: boolean) => void;
  onScheduleRefresh: () => void;
  onGapFound: (item: EventEntity) => void;
  getConflictFlowContext: () => ConflictFlowContext;
  setGapItem: (item: EventEntity | null) => void;
  openGapDialog: () => void;
  setDateFilterController: (controller: CustomDialogController | null) => void;
  openAiDialog: () => void;
  openDialog: (initData?: InitDialogData) => void;
  setPlanTitle: (title: string) => void;
  requestPlanDateUpdate: (dateMs: number) => void;
  setDialogController: (controller: CustomDialogController | null) => void;
  setSettingsDialogController: (controller: CustomDialogController | null) => void;
}

export class IndexLayoutCallbacksBuilder {
  static create(context: IndexLayoutCallbacksBuilderContext): IndexPageLayoutCallbacks {
    return IndexLayoutCallbacksHelper.create({
      vm: context.vm,
      planTitle: context.planTitle,
      getUIContext: (): UIContext => context.getUIContext(),
      safeShowToast: (message: string): void => context.safeShowToast(message),
      setCompanionMode: (value: boolean): void => {
        context.setCompanionMode(value);
      },
      setManualPlanningWeatherRefresh: (value: boolean): void => {
        context.setManualPlanningWeatherRefresh(value);
      },
      onToggleHint: (): void => context.toggleHintPopup(),
      onToggleScore: (): void => context.toggleScorePopup(),
      setHintPopupVisible: (value: boolean): void => context.setHintPopupVisible(value),
      setScorePopupVisible: (value: boolean): void => context.setScorePopupVisible(value),
      onToggleBacklogExpand: (): void => {
        const nextExpanded = !context.backlogExpanded;
        context.setBacklogExpanded(nextExpanded);
        IndexStateManager.persistBacklogExpanded(context.currentPlanId, nextExpanded);
      },
      onMoveToSchedule: (item: TravelPlanItem): void => {
        IndexPageActionsHelper.moveTravelPlanItemToSchedule({
          vm: context.vm,
          setEditingItemId: (id: number): void => {
            context.setEditingItemId(id);
          },
          openDialog: (initData?: InitDialogData): void => {
            context.openDialog(initData);
          }
        }, item);
      },
      onMoveAllToSchedule: (): void => {
        IndexPageActionsHelper.handleMoveAllToSchedule({
          vm: context.vm,
          safeShowToast: (message: string): void => context.safeShowToast(message),
          getUIContext: (): UIContext => context.getUIContext()
        });
      },
      onIsDayCollapsed: (dayOffset: number): boolean => IndexStateManager.isDayCollapsed(context.collapsedDayOffsets, dayOffset),
      onToggleDay: (dayOffset: number): void => {
        const nextOffsets = IndexStateManager.toggleDayCollapse(context.collapsedDayOffsets, dayOffset);
        context.setCollapsedDayOffsets(nextOffsets);
      },
      onScheduleRefresh: (): void => context.onScheduleRefresh(),
      onOpenEditDialog: (item: EventEntity): void => {
        const prepared = IndexPageActionsHelper.prepareEditDialog(item);
        context.setEditingItemId(prepared.editingItemId);
        context.openDialog(prepared.initData);
      },
      onGapFound: (item: EventEntity): void => context.onGapFound(item),
      onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number): void => {
        IndexConflictFlowHelper.handleEventConflictAction(context.getConflictFlowContext(), item, strategy, gapMinutes);
      },
      onConfirmMoveToBacklog: (item: EventEntity): void => {
        IndexPageActionsHelper.handleConfirmMoveToBacklog({
          vm: context.vm,
          safeShowToast: (message: string): void => context.safeShowToast(message),
          getUIContext: (): UIContext => context.getUIContext()
        }, item);
      },
      onConfirmDeleteEvent: (item: EventEntity): void => {
        IndexPageActionsHelper.handleConfirmDeleteEvent({
          vm: context.vm,
          safeShowToast: (message: string): void => context.safeShowToast(message),
          getUIContext: (): UIContext => context.getUIContext()
        }, item);
      },
      onOpenGapOptimize: (): void => {
        context.setGapItem(null);
        context.openGapDialog();
      },
      onFilterOpenDialog: (): void => {
        const controller = IndexPageActionsHelper.openDateFilterDialog({
          vm: context.vm,
          getUIContext: (): UIContext => context.getUIContext()
        });
        context.setDateFilterController(controller);
      },
      onOpenAiDialog: (): void => context.openAiDialog(),
      onAdd: (): void => {
        context.setEditingItemId(-1);
        context.openDialog();
      },
      onUndo: (): void => {
        void context.vm.loadData(context.vm.planId);
        context.setHasUnsavedChanges(
          IndexStateManager.setUnsavedFlag(context.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE, false)
        );
      },
      onSave: (): void => {
        context.vm.save();
        context.setHasUnsavedChanges(
          IndexStateManager.setUnsavedFlag(context.currentPlanId, AppStorageKeys.HAS_UNSAVED_POSTPONE, false)
        );
      },
      setPlanTitle: (title: string): void => context.setPlanTitle(title),
      requestPlanDateUpdate: (dateMs: number): void => context.requestPlanDateUpdate(dateMs),
      setDialogController: (controller: CustomDialogController | null): void => context.setDialogController(controller),
      setSettingsDialogController: (controller: CustomDialogController | null): void => {
        context.setSettingsDialogController(controller);
      }
    });
  }
}
