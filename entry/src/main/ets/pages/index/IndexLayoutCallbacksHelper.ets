import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { InitDialogData } from './IndexTypes';
import { IndexEventHandlers } from './IndexEventHandlers';
import { IndexPageActionsHelper } from './IndexPageActionsHelper';
import { IndexSettingsDialogFlowHelper } from './IndexSettingsDialogFlowHelper';
import { NavigationHelper } from '../../common/utils/NavigationHelper';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface IndexPageLayoutCallbacks {
  onBack: () => void;
  onOpenSettings: () => void;
  onEnterCompanion: () => void;
  onRefreshWeather: () => void;
  onToggleHint: () => void;
  onToggleScore: () => void;
  onHintPopupVisibleChange: (visible: boolean) => void;
  onScorePopupVisibleChange: (visible: boolean) => void;
  onToggleBacklogExpand: () => void;
  onMoveToSchedule: (item: TravelPlanItem) => void;
  onMoveAllToSchedule: () => void;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onScheduleRefresh: () => void;
  onOpenEditDialog: (item: EventEntity) => void;
  onOpenTimeEditDialog: (item: EventEntity) => void;
  onGapFound: (item: EventEntity) => void;
  onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => void;
  onConfirmMoveToBacklog: (item: EventEntity) => void;
  onConfirmDeleteEvent: (item: EventEntity) => void;
  onOpenGapOptimize: () => void;
  onFilter: () => void;
  onAi: () => void;
  onAdd: () => void;
  onUndo: () => void;
  onSave: () => void;
}

export interface IndexLayoutCallbacksContext {
  vm: TimelineViewModel;
  planTitle: string;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  setCompanionMode: (value: boolean) => void;
  setManualPlanningWeatherRefresh: (value: boolean) => void;
  onToggleHint: () => void;
  onToggleScore: () => void;
  setHintPopupVisible: (value: boolean) => void;
  setScorePopupVisible: (value: boolean) => void;
  onToggleBacklogExpand: () => void;
  onMoveToSchedule: (item: TravelPlanItem) => void;
  onMoveAllToSchedule: () => void;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onScheduleRefresh: () => void;
  onOpenEditDialog: (item: EventEntity) => void;
  onGapFound: (item: EventEntity) => void;
  onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => void;
  onConfirmMoveToBacklog: (item: EventEntity) => void;
  onConfirmDeleteEvent: (item: EventEntity) => void;
  onOpenGapOptimize: () => void;
  onFilterOpenDialog: () => void;
  onOpenAiDialog: () => void;
  onAdd: () => void;
  onUndo: () => void;
  onSave: () => void;
  setPlanTitle: (title: string) => void;
  requestPlanDateUpdate: (dateMs: number) => void;
  setDialogController: (controller: CustomDialogController | null) => void;
  setSettingsDialogController: (controller: CustomDialogController | null) => void;
}

export class IndexLayoutCallbacksHelper {
  static createEmpty(): IndexPageLayoutCallbacks {
    return {
      onBack: () => {},
      onOpenSettings: () => {},
      onEnterCompanion: () => {},
      onRefreshWeather: () => {},
      onToggleHint: () => {},
      onToggleScore: () => {},
      onHintPopupVisibleChange: (_visible: boolean) => {},
      onScorePopupVisibleChange: (_visible: boolean) => {},
      onToggleBacklogExpand: () => {},
      onMoveToSchedule: (_item: TravelPlanItem) => {},
      onMoveAllToSchedule: () => {},
      onIsDayCollapsed: (_dayOffset: number) => false,
      onToggleDay: (_dayOffset: number) => {},
      onScheduleRefresh: () => {},
      onOpenEditDialog: (_item: EventEntity) => {},
      onOpenTimeEditDialog: (_item: EventEntity) => {},
      onGapFound: (_item: EventEntity) => {},
      onResolveConflictAction: (_item: EventEntity, _strategy: 'delay' | 'compress' | 'advance' | 'smart', _gapMinutes: number) => {},
      onConfirmMoveToBacklog: (_item: EventEntity) => {},
      onConfirmDeleteEvent: (_item: EventEntity) => {},
      onOpenGapOptimize: () => {},
      onFilter: () => {},
      onAi: () => {},
      onAdd: () => {},
      onUndo: () => {},
      onSave: () => {}
    };
  }

  static create(context: IndexLayoutCallbacksContext): IndexPageLayoutCallbacks {
    return {
      onBack: (): void => {
        void NavigationHelper.backOrFallbackToPlanList(context.getUIContext());
      },
      onOpenSettings: (): void => {
        if (context.vm.isArchived) {
          return;
        }
        IndexSettingsDialogFlowHelper.open({
          vm: context.vm,
          planTitle: context.planTitle,
          getUIContext: (): UIContext => context.getUIContext(),
          safeShowToast: (message: string): void => context.safeShowToast(message),
          setPlanTitle: (title: string): void => context.setPlanTitle(title),
          requestPlanDateUpdate: (dateMs: number): void => context.requestPlanDateUpdate(dateMs),
          setDialogController: (controller: CustomDialogController | null): void => context.setDialogController(controller),
          setSettingsDialogController: (controller: CustomDialogController | null): void => context.setSettingsDialogController(controller)
        });
      },
      onEnterCompanion: (): void => {
        hilog.info(0x0000, 'Index', '[DUAL_MODE_ACCEPT][mode_switch][click_enter]');
        if (context.vm.isArchived) {
          context.safeShowToast('归档计划不可进入伴游');
          return;
        }
        context.setCompanionMode(true);
      },
      onRefreshWeather: (): void => {
        context.setManualPlanningWeatherRefresh(true);
        void context.vm.refreshPlanningWeather(true).then((): void => {
          context.safeShowToast('天气已刷新');
        }).catch((_error: Object): void => {
          context.safeShowToast('天气刷新失败');
        });
      },
      onToggleHint: (): void => context.onToggleHint(),
      onToggleScore: (): void => context.onToggleScore(),
      onHintPopupVisibleChange: (visible: boolean): void => context.setHintPopupVisible(visible),
      onScorePopupVisibleChange: (visible: boolean): void => context.setScorePopupVisible(visible),
      onToggleBacklogExpand: (): void => context.onToggleBacklogExpand(),
      onMoveToSchedule: (item: TravelPlanItem): void => context.onMoveToSchedule(item),
      onMoveAllToSchedule: (): void => context.onMoveAllToSchedule(),
      onIsDayCollapsed: (dayOffset: number): boolean => context.onIsDayCollapsed(dayOffset),
      onToggleDay: (dayOffset: number): void => context.onToggleDay(dayOffset),
      onScheduleRefresh: (): void => context.onScheduleRefresh(),
      onOpenEditDialog: (item: EventEntity): void => context.onOpenEditDialog(item),
      onOpenTimeEditDialog: (_item: EventEntity): void => {},
      onGapFound: (item: EventEntity): void => context.onGapFound(item),
      onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number): void =>
        context.onResolveConflictAction(item, strategy, gapMinutes),
      onConfirmMoveToBacklog: (item: EventEntity): void => context.onConfirmMoveToBacklog(item),
      onConfirmDeleteEvent: (item: EventEntity): void => context.onConfirmDeleteEvent(item),
      onOpenGapOptimize: (): void => context.onOpenGapOptimize(),
      onFilter: (): void => {
        IndexEventHandlers.handleFilter((): void => context.onFilterOpenDialog());
      },
      onAi: (): void => {
        IndexEventHandlers.handleAiSuggestion(
          context.vm.isArchived,
          (): void => context.safeShowToast('归档计划不可操作'),
          (): void => context.onOpenAiDialog()
        );
      },
      onAdd: (): void => context.onAdd(),
      onUndo: (): void => context.onUndo(),
      onSave: (): void => context.onSave()
    };
  }
}
