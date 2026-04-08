import { InitDialogData } from './IndexTypes';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { AboutToAppearParams, AboutToDisappearParams } from './IndexLifecycleHelper';
import { IndexPageShowParams } from './IndexPageShowHelper';

export interface IndexPageShowBindingsInput {
  vm: TimelineViewModel;
  onStartArrivalReminderEngine: () => void;
  onRefreshUnsavedFlag: () => void;
  onReadDraftStorage: (key: string) => string;
  onClearDraftStorage: () => void;
  onOpenDialog: (initData?: InitDialogData) => void;
  onSafeToast: (message: string) => void;
  onSanitizeError: (error: Object) => string;
}

export interface IndexAboutToAppearBindingsInput {
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

export interface IndexAboutToDisappearBindingsInput {
  strategyAdaptationCheckTimer: number;
  onUnbindReminderSubscriptions: () => void;
  onStopArrivalEngine: () => void;
  onStopExecutionWeatherScheduler: () => void;
  onUnbindPlanState: () => void;
  onClearDialogDraftStorage: () => void;
  onSetStrategyAdaptationCheckTimer: (timer: number) => void;
}

export class IndexPageLifecycleBindingsBuilder {
  static createPageShowParams(input: IndexPageShowBindingsInput): IndexPageShowParams {
    return {
      vm: input.vm,
      onStartArrivalReminderEngine: (): void => input.onStartArrivalReminderEngine(),
      onRefreshUnsavedFlag: (): void => input.onRefreshUnsavedFlag(),
      onReadDraftStorage: (key: string): string => input.onReadDraftStorage(key),
      onClearDraftStorage: (): void => input.onClearDraftStorage(),
      onOpenDialog: (initData?: InitDialogData): void => input.onOpenDialog(initData),
      onSafeToast: (message: string): void => input.onSafeToast(message),
      onSanitizeError: (error: Object): string => input.onSanitizeError(error)
    };
  }

  static createAboutToAppearParams(input: IndexAboutToAppearBindingsInput): AboutToAppearParams {
    return {
      uiContext: input.uiContext,
      vm: input.vm,
      onSetCurrentPlanId: (planId: number): void => input.onSetCurrentPlanId(planId),
      onSetManualWeatherRefresh: (value: boolean): void => input.onSetManualWeatherRefresh(value),
      onRefreshUnsavedFlag: (): void => input.onRefreshUnsavedFlag(),
      onSetPlanTitle: (title: string): void => input.onSetPlanTitle(title),
      onBindReminderSubscriptions: (): void => input.onBindReminderSubscriptions(),
      onSetStrategyMode: (mode: number): void => input.onSetStrategyMode(mode),
      onLoadStrategyExplanation: (): void => input.onLoadStrategyExplanation(),
      onSetCompanionMode: (value: boolean): void => input.onSetCompanionMode(value),
      onTryStartEvent: async (eventId: number): Promise<boolean> => input.onTryStartEvent(eventId),
      onStartArrivalReminderEngine: (): void => input.onStartArrivalReminderEngine(),
      onStartStrategyAdaptationCheck: (): void => input.onStartStrategyAdaptationCheck(),
      onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean): Promise<void> =>
        input.onInitBacklogExpandedState(planId, isNewPlan),
      onLoadDataError: (reason: string): void => input.onLoadDataError(reason)
    };
  }

  static createAboutToDisappearParams(input: IndexAboutToDisappearBindingsInput): AboutToDisappearParams {
    return {
      strategyAdaptationCheckTimer: input.strategyAdaptationCheckTimer,
      onUnbindReminderSubscriptions: (): void => input.onUnbindReminderSubscriptions(),
      onStopArrivalEngine: (): void => input.onStopArrivalEngine(),
      onStopExecutionWeatherScheduler: (): void => input.onStopExecutionWeatherScheduler(),
      onUnbindPlanState: (): void => input.onUnbindPlanState(),
      onClearDialogDraftStorage: (): void => input.onClearDialogDraftStorage(),
      onSetStrategyAdaptationCheckTimer: (timer: number): void => input.onSetStrategyAdaptationCheckTimer(timer)
    };
  }
}
