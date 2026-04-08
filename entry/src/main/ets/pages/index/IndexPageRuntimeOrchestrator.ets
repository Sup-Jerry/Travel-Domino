import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { PlanAppService } from '../../viewmodel/PlanAppService';
import { WeatherReminderCoordinator } from '../../infrastructure/services/WeatherReminderCoordinator';
import { ArrivalReminderCoordinator } from '../../infrastructure/services/ArrivalReminderCoordinator';
import { WeatherReminderPayload } from '../../common/utils/weather/WeatherReminderStore';
import { ArrivalReminderPayload } from '../../infrastructure/services/ArrivalReminderEngine';
import { ConflictFlowContext } from './IndexConflictFlowHelper';
import { IndexPageBehaviorHelper, ReminderDialogContext, StrategyDialogContext } from './IndexPageBehaviorHelper';
import { IndexPageRuntimeBindingsBuilder } from './IndexPageRuntimeBindingsBuilder';

export interface IndexPageRuntimeOrchestratorContext {
  currentPlanId: number;
  vm: TimelineViewModel;
  planService: PlanAppService;
  weatherCoordinator: WeatherReminderCoordinator;
  arrivalCoordinator: ArrivalReminderCoordinator;
  strategyMode: number;
  isWeatherDialogOpen: boolean;
  isArrivalDialogOpen: boolean;
  weatherReminderUnsubscribe: (() => void) | null;
  arrivalReminderUnsubscribe: (() => void) | null;
  strategyAdaptationCheckTimer: number;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  tryStartEventWithConflictPrompt: (eventId: number) => Promise<boolean>;
  setWeatherDialogOpen: (value: boolean) => void;
  setArrivalDialogOpen: (value: boolean) => void;
  setCompanionMode: (value: boolean) => void;
  setManualPlanningWeatherRefresh: (value: boolean) => void;
  setWeatherReminderUnsubscribe: (unsubscribe: (() => void) | null) => void;
  setArrivalReminderUnsubscribe: (unsubscribe: (() => void) | null) => void;
  setConflictSelectionController: (controller: CustomDialogController | null) => void;
  setConflictCompressController: (controller: CustomDialogController | null) => void;
  setConflictAdvanceController: (controller: CustomDialogController | null) => void;
  setSuggestionDialogController: (controller: CustomDialogController | null) => void;
  setCurrentStrategyExplanation: (explanation: string) => void;
  setStrategyAdaptationCheckTimer: (timer: number) => void;
}

export class IndexPageRuntimeOrchestrator {
  private static createReminderDialogContext(context: IndexPageRuntimeOrchestratorContext): ReminderDialogContext {
    return IndexPageRuntimeBindingsBuilder.createReminderDialogContext({
      vm: context.vm,
      currentPlanId: context.currentPlanId,
      getUIContext: (): UIContext => context.getUIContext(),
      weatherCoordinator: context.weatherCoordinator,
      arrivalCoordinator: context.arrivalCoordinator,
      tryStartEventWithConflictPrompt: async (eventId: number): Promise<boolean> =>
        context.tryStartEventWithConflictPrompt(eventId),
      setWeatherDialogOpen: (value: boolean): void => context.setWeatherDialogOpen(value),
      setArrivalDialogOpen: (value: boolean): void => context.setArrivalDialogOpen(value),
      setCompanionMode: (value: boolean): void => context.setCompanionMode(value),
      safeShowToast: (message: string): void => context.safeShowToast(message)
    });
  }

  static bindReminderSubscriptions(context: IndexPageRuntimeOrchestratorContext): void {
    const result = IndexPageRuntimeBindingsBuilder.bindReminderSubscriptions({
      currentPlanId: context.currentPlanId,
      vm: context.vm,
      weatherCoordinator: context.weatherCoordinator,
      arrivalCoordinator: context.arrivalCoordinator,
      isWeatherDialogOpen: (): boolean => context.isWeatherDialogOpen,
      isArrivalDialogOpen: (): boolean => context.isArrivalDialogOpen,
      onShowWeatherDialog: (payload: WeatherReminderPayload): void => {
        IndexPageBehaviorHelper.showWeatherReminderDialog(
          IndexPageRuntimeOrchestrator.createReminderDialogContext(context),
          payload
        );
      },
      onShowArrivalDialog: (payload: ArrivalReminderPayload): void => {
        IndexPageBehaviorHelper.showArrivalReminderDialog(
          IndexPageRuntimeOrchestrator.createReminderDialogContext(context),
          payload
        );
      },
      onClearWeatherDialog: (): void => {
        context.setWeatherDialogOpen(false);
      }
    });
    context.setWeatherReminderUnsubscribe(result.weatherUnsubscribe);
    context.setArrivalReminderUnsubscribe(result.arrivalUnsubscribe);
  }

  static unbindReminderSubscriptions(context: IndexPageRuntimeOrchestratorContext): void {
    const result = IndexPageRuntimeBindingsBuilder.unbindReminderSubscriptions(
      context.weatherReminderUnsubscribe,
      context.arrivalReminderUnsubscribe
    );
    context.setWeatherReminderUnsubscribe(result.weatherUnsubscribe);
    context.setArrivalReminderUnsubscribe(result.arrivalUnsubscribe);
  }

  static async handlePagePullRefresh(context: IndexPageRuntimeOrchestratorContext): Promise<void> {
    await IndexPageRuntimeBindingsBuilder.handlePagePullRefresh({
      currentPlanId: context.currentPlanId,
      vm: context.vm,
      planService: context.planService,
      arrivalCoordinator: context.arrivalCoordinator,
      isArrivalDialogOpen: context.isArrivalDialogOpen,
      onShowArrivalDialog: (payload: ArrivalReminderPayload): void => {
        IndexPageBehaviorHelper.showArrivalReminderDialog(
          IndexPageRuntimeOrchestrator.createReminderDialogContext(context),
          payload
        );
      },
      setManualWeatherRefreshed: (): void => {
        context.setManualPlanningWeatherRefresh(true);
      }
    });
  }

  static createConflictFlowContext(context: IndexPageRuntimeOrchestratorContext): ConflictFlowContext {
    return IndexPageRuntimeBindingsBuilder.createConflictFlowContext({
      vm: context.vm,
      getUIContext: (): UIContext => context.getUIContext(),
      safeShowToast: (message: string): void => context.safeShowToast(message),
      setConflictSelectionController: (controller: CustomDialogController | null): void =>
        context.setConflictSelectionController(controller),
      setConflictCompressController: (controller: CustomDialogController | null): void =>
        context.setConflictCompressController(controller),
      setConflictAdvanceController: (controller: CustomDialogController | null): void =>
        context.setConflictAdvanceController(controller),
      setSuggestionDialogController: (controller: CustomDialogController | null): void =>
        context.setSuggestionDialogController(controller)
    });
  }

  static loadStrategyExplanation(context: IndexPageRuntimeOrchestratorContext): void {
    context.setCurrentStrategyExplanation(IndexPageBehaviorHelper.loadStrategyExplanation(context.strategyMode));
  }

  static startStrategyAdaptationCheck(context: IndexPageRuntimeOrchestratorContext): void {
    const timer = IndexPageBehaviorHelper.startStrategyAdaptationCheck(
      IndexPageRuntimeOrchestrator.createStrategyDialogContext(context)
    );
    context.setStrategyAdaptationCheckTimer(timer);
  }

  static createStrategyDialogContext(context: IndexPageRuntimeOrchestratorContext): StrategyDialogContext {
    return IndexPageRuntimeBindingsBuilder.createStrategyDialogContext({
      vm: context.vm,
      strategyMode: context.strategyMode,
      getUIContext: (): UIContext => context.getUIContext(),
      regenerateByCurrentStrategy: async (): Promise<void> => context.vm.regenerateByCurrentStrategy()
    });
  }
}
