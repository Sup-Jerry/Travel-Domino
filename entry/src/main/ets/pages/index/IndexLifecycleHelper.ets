import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { IndexStateManager } from './IndexStateManager';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export interface AboutToAppearParams {
  uiContext: UIContext;
  vm: TimelineViewModel;
  onSetCurrentPlanId: (planId: number) => void;
  onSetManualWeatherRefresh: (value: boolean) => void;
  onRefreshUnsavedFlag: () => void;
  onSetPlanTitle: (title: string) => void;
  onBindReminderSubscriptions: () => void;
  onSetStrategyMode: (mode: number) => void;
  onLoadStrategyExplanation: () => void;
  onSetCompanionMode: (value: boolean) => void;
  onTryStartEvent: (eventId: number) => Promise<boolean>;
  onStartArrivalReminderEngine: () => void;
  onStartStrategyAdaptationCheck: () => void;
  onInitBacklogExpandedState: (planId: number, isNewPlan: boolean) => Promise<void>;
  onLoadDataError: (reason: string) => void;
}

export interface AboutToDisappearParams {
  strategyAdaptationCheckTimer: number;
  onUnbindReminderSubscriptions: () => void;
  onStopArrivalEngine: () => void;
  onStopExecutionWeatherScheduler: () => void;
  onUnbindPlanState: () => void;
  onClearDialogDraftStorage: () => void;
  onSetStrategyAdaptationCheckTimer: (timer: number) => void;
}

export class IndexLifecycleHelper {
  static handleAboutToAppear(params: AboutToAppearParams): void {
    const routeParams = params.uiContext.getRouter().getParams() as Record<string, Object>;
    if (!routeParams || !routeParams['planId']) {
      console.error('Index page loaded without Plan ID');
      return;
    }

    const planId = routeParams['planId'] as number;
    const isNewPlan = (routeParams['isNewPlan'] as boolean) === true;
    const autoStartFromReminder = (routeParams['autoStartFromReminder'] as boolean) === true;
    const forceCompanionMode = (routeParams['forceCompanionMode'] as boolean) === true;
    const reminderEventId = Number(routeParams['reminderEventId'] as number) || -1;

    params.onSetCurrentPlanId(planId);
    params.onSetManualWeatherRefresh(false);
    params.onSetCompanionMode(false);
    params.vm.setHasUnsavedPostponeStorageKey(
      IndexStateManager.scopedStorageKey(AppStorageKeys.HAS_UNSAVED_POSTPONE, planId)
    );
    params.onRefreshUnsavedFlag();
    params.onSetPlanTitle(routeParams['title'] as string || '行程详情');
    params.onBindReminderSubscriptions();

    void params.vm.loadData(planId).then(() => {
      params.onSetStrategyMode(params.vm.getStrategyMode());
      params.onLoadStrategyExplanation();
      if (params.vm.isWeatherFeatureEnabled()) {
        if (params.vm.shouldAutoRefreshPlanningWeather()) {
          void params.vm.refreshPlanningWeather(false);
        }
      } else {
        params.vm.stopExecutionWeatherScheduler();
      }

      if (autoStartFromReminder && reminderEventId > 0) {
        params.onSetCompanionMode(true);
        void params.onTryStartEvent(reminderEventId);
      } else if (forceCompanionMode) {
        params.onSetCompanionMode(true);
      }
      params.onStartArrivalReminderEngine();
      params.onStartStrategyAdaptationCheck();
    }).catch((error: Error) => {
      const reason = error instanceof Error && error.message.length > 0 ? error.message : 'unknown_error';
      params.onLoadDataError(reason);
    });

    void params.onInitBacklogExpandedState(planId, isNewPlan);
  }

  static handleAboutToDisappear(params: AboutToDisappearParams): void {
    params.onUnbindReminderSubscriptions();
    params.onStopArrivalEngine();
    params.onStopExecutionWeatherScheduler();
    params.onUnbindPlanState();
    params.onClearDialogDraftStorage();
    if (params.strategyAdaptationCheckTimer !== -1) {
      clearInterval(params.strategyAdaptationCheckTimer);
      params.onSetStrategyAdaptationCheckTimer(-1);
      hilog.info(0x0000, 'Index', '[STRATEGY_ADAPT][timer_cleared]');
    }
  }
}
