import { EventEntity } from '../../model/entity/EventEntity';
import { ThemeCenter, ThemePalette } from '../../common/utils/ThemeCenter';
import { IndexLayoutProps, IndexLayoutPropsBuilder } from './IndexLayoutPropsBuilder';
import { IndexLayoutCallbacksBuilder } from './IndexLayoutCallbacksBuilder';
import { IndexLayoutCallbacksContextFactory } from './IndexLayoutCallbacksContextFactory';
import { ConflictFlowContext } from './IndexConflictFlowHelper';
import { InitDialogData, PendingItemData } from './IndexTypes';
import { IndexDialogBindingsHelper } from './IndexDialogBindingsHelper';
import { IndexDateConflictDialogFlowHelper } from './IndexDateConflictDialogFlowHelper';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export interface IndexPageLayoutBindingsInput {
  vm: TimelineViewModel;
  planTitle: string;
  strategyMode: number;
  currentStrategyExplanation: string;
  isCompanionMode: boolean;
  hasManualPlanningWeatherRefresh: boolean;
  showPlanningWeatherHintPopup: boolean;
  showPlanningWeatherScorePopup: boolean;
  backlogExpanded: boolean;
  isPageRefreshing: boolean;
  hasUnsavedChanges: boolean;
  themePalette: ThemePalette;
  companionOverlayZIndex: number;
  companionBackRequestToken: number;
  currentPlanId: number;
  collapsedDayOffsets: number[];
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

export interface IndexAddDialogBindingsInput {
  vm: TimelineViewModel;
  editingItemId: number;
  currentPlanId: number;
  initData?: InitDialogData;
  collapsedDayOffsets: number[];
  setCollapsedDayOffsets: (offsets: number[]) => void;
  onGapFoundCallback: (item: EventEntity) => void;
  setPendingItem: (item: PendingItemData | null) => void;
  openConflictDialog: () => void;
  setEditingItemId: (id: number) => void;
  safeShowToast: (message: string) => void;
}

export interface IndexConflictDialogBindingsInput {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  getPendingItem: () => PendingItemData | null;
  setPendingItem: (item: PendingItemData | null) => void;
  openDialog: (initData?: InitDialogData) => void;
  reopenConflictDialog: () => void;
  safeShowToast: (message: string) => void;
}

export class IndexPageBindingsBuilder {
  static createLayoutProps(input: IndexPageLayoutBindingsInput): IndexLayoutProps {
    return IndexLayoutPropsBuilder.create({
      vm: input.vm ?? new TimelineViewModel(),
      planTitle: input.planTitle,
      strategyMode: input.strategyMode,
      currentStrategyExplanation: input.currentStrategyExplanation,
      isCompanionMode: input.isCompanionMode,
      hasManualPlanningWeatherRefresh: input.hasManualPlanningWeatherRefresh,
      showPlanningWeatherHintPopup: input.showPlanningWeatherHintPopup,
      showPlanningWeatherScorePopup: input.showPlanningWeatherScorePopup,
      backlogExpanded: input.backlogExpanded,
      isPageRefreshing: input.isPageRefreshing,
      hasUnsavedChanges: input.hasUnsavedChanges,
      themePalette: input.themePalette ?? ThemeCenter.getPalette('light'),
      companionOverlayZIndex: input.companionOverlayZIndex,
      companionBackRequestToken: input.companionBackRequestToken,
      callbacks: IndexLayoutCallbacksBuilder.create(IndexLayoutCallbacksContextFactory.create({
        vm: input.vm,
        planTitle: input.planTitle,
        currentPlanId: input.currentPlanId,
        collapsedDayOffsets: input.collapsedDayOffsets,
        backlogExpanded: input.backlogExpanded,
        getUIContext: (): UIContext => input.getUIContext(),
        safeShowToast: (message: string): void => input.safeShowToast(message),
        setCompanionMode: (value: boolean): void => input.setCompanionMode(value),
        setManualPlanningWeatherRefresh: (value: boolean): void => input.setManualPlanningWeatherRefresh(value),
        setHintPopupVisible: (value: boolean): void => input.setHintPopupVisible(value),
        setScorePopupVisible: (value: boolean): void => input.setScorePopupVisible(value),
        toggleHintPopup: (): void => input.toggleHintPopup(),
        toggleScorePopup: (): void => input.toggleScorePopup(),
        setBacklogExpanded: (value: boolean): void => input.setBacklogExpanded(value),
        setCollapsedDayOffsets: (offsets: number[]): void => input.setCollapsedDayOffsets(offsets),
        setEditingItemId: (id: number): void => input.setEditingItemId(id),
        setHasUnsavedChanges: (value: boolean): void => input.setHasUnsavedChanges(value),
        onScheduleRefresh: (): void => input.onScheduleRefresh(),
        onGapFound: (item: EventEntity): void => input.onGapFound(item),
        getConflictFlowContext: (): ConflictFlowContext => input.getConflictFlowContext(),
        setGapItem: (item: EventEntity | null): void => input.setGapItem(item),
        openGapDialog: (): void => input.openGapDialog(),
        setDateFilterController: (controller: CustomDialogController | null): void => input.setDateFilterController(controller),
        openAiDialog: (): void => input.openAiDialog(),
        openDialog: (initData?: InitDialogData): void => input.openDialog(initData),
        setPlanTitle: (title: string): void => input.setPlanTitle(title),
        setDialogController: (controller: CustomDialogController | null): void => input.setDialogController(controller),
        setSettingsDialogController: (controller: CustomDialogController | null): void => input.setSettingsDialogController(controller)
      }))
    });
  }

  static createAddDialogController(input: IndexAddDialogBindingsInput): CustomDialogController {
    return IndexDialogBindingsHelper.createAddDialogController({
      vm: input.vm,
      editingItemId: input.editingItemId,
      currentPlanId: input.currentPlanId,
      initData: input.initData,
      collapsedDayOffsets: input.collapsedDayOffsets,
      setCollapsedDayOffsets: (offsets: number[]): void => input.setCollapsedDayOffsets(offsets),
      onGapFoundCallback: input.onGapFoundCallback,
      setPendingItem: (item: PendingItemData | null): void => input.setPendingItem(item),
      openConflictDialog: (): void => input.openConflictDialog(),
      setEditingItemId: (id: number): void => input.setEditingItemId(id),
      safeShowToast: (message: string): void => input.safeShowToast(message)
    });
  }

  static createConflictDialogController(input: IndexConflictDialogBindingsInput): CustomDialogController {
    return IndexDateConflictDialogFlowHelper.createController({
      vm: input.vm,
      getUIContext: (): UIContext => input.getUIContext(),
      getPendingItem: (): PendingItemData | null => input.getPendingItem(),
      setPendingItem: (item: PendingItemData | null): void => input.setPendingItem(item),
      openDialog: (initData?: InitDialogData): void => input.openDialog(initData),
      reopenConflictDialog: (): void => input.reopenConflictDialog(),
      safeShowToast: (message: string): void => input.safeShowToast(message)
    });
  }
}
