import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { EventEntity } from '../../model/entity/EventEntity';
import { InitDialogData } from './IndexTypes';
import { ConflictFlowContext, IndexConflictFlowHelper } from './IndexConflictFlowHelper';
import { IndexLayoutCallbacksBuilderContext } from './IndexLayoutCallbacksBuilder';

export interface IndexLayoutCallbacksContextFactoryParams {
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
  setDialogController: (controller: CustomDialogController | null) => void;
  setSettingsDialogController: (controller: CustomDialogController | null) => void;
}

export class IndexLayoutCallbacksContextFactory {
  static create(params: IndexLayoutCallbacksContextFactoryParams): IndexLayoutCallbacksBuilderContext {
    return {
      vm: params.vm,
      planTitle: params.planTitle,
      currentPlanId: params.currentPlanId,
      collapsedDayOffsets: params.collapsedDayOffsets,
      backlogExpanded: params.backlogExpanded,
      getUIContext: (): UIContext => params.getUIContext(),
      safeShowToast: (message: string): void => params.safeShowToast(message),
      setCompanionMode: (value: boolean): void => params.setCompanionMode(value),
      setManualPlanningWeatherRefresh: (value: boolean): void => params.setManualPlanningWeatherRefresh(value),
      setHintPopupVisible: (value: boolean): void => params.setHintPopupVisible(value),
      setScorePopupVisible: (value: boolean): void => params.setScorePopupVisible(value),
      toggleHintPopup: (): void => params.toggleHintPopup(),
      toggleScorePopup: (): void => params.toggleScorePopup(),
      setBacklogExpanded: (value: boolean): void => params.setBacklogExpanded(value),
      setCollapsedDayOffsets: (offsets: number[]): void => params.setCollapsedDayOffsets(offsets),
      setEditingItemId: (id: number): void => params.setEditingItemId(id),
      setHasUnsavedChanges: (value: boolean): void => params.setHasUnsavedChanges(value),
      onScheduleRefresh: (): void => params.onScheduleRefresh(),
      onGapFound: (item: EventEntity): void => params.onGapFound(item),
      getConflictFlowContext: (): ConflictFlowContext => params.getConflictFlowContext(),
      setGapItem: (item: EventEntity | null): void => params.setGapItem(item),
      openGapDialog: (): void => params.openGapDialog(),
      setDateFilterController: (controller: CustomDialogController | null): void => params.setDateFilterController(controller),
      openAiDialog: (): void => params.openAiDialog(),
      openDialog: (initData?: InitDialogData): void => params.openDialog(initData),
      setPlanTitle: (title: string): void => params.setPlanTitle(title),
      requestPlanDateUpdate: (dateMs: number): void => {
        IndexConflictFlowHelper.requestPlanDateUpdate(params.getConflictFlowContext(), dateMs);
      },
      setDialogController: (controller: CustomDialogController | null): void => params.setDialogController(controller),
      setSettingsDialogController: (controller: CustomDialogController | null): void => {
        params.setSettingsDialogController(controller);
      }
    };
  }
}
