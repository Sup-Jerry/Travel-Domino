import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { PlanAppService } from '../../viewmodel/PlanAppService';
import { WeatherReminderCoordinator } from '../../infrastructure/services/WeatherReminderCoordinator';
import { ArrivalReminderCoordinator } from '../../infrastructure/services/ArrivalReminderCoordinator';
import { IndexPageRuntimeOrchestratorContext } from './IndexPageRuntimeOrchestrator';

export interface IndexPageRuntimeContextFactoryParams {
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

export class IndexPageRuntimeContextFactory {
  static create(
    currentPlanId: number,
    vm: TimelineViewModel,
    planService: PlanAppService,
    weatherCoordinator: WeatherReminderCoordinator,
    arrivalCoordinator: ArrivalReminderCoordinator,
    strategyMode: number,
    isWeatherDialogOpen: boolean,
    isArrivalDialogOpen: boolean,
    weatherReminderUnsubscribe: (() => void) | null,
    arrivalReminderUnsubscribe: (() => void) | null,
    strategyAdaptationCheckTimer: number,
    getUIContext: () => UIContext,
    safeShowToast: (message: string) => void,
    tryStartEventWithConflictPrompt: (eventId: number) => Promise<boolean>,
    setWeatherDialogOpen: (value: boolean) => void,
    setArrivalDialogOpen: (value: boolean) => void,
    setCompanionMode: (value: boolean) => void,
    setManualPlanningWeatherRefresh: (value: boolean) => void,
    setWeatherReminderUnsubscribe: (unsubscribe: (() => void) | null) => void,
    setArrivalReminderUnsubscribe: (unsubscribe: (() => void) | null) => void,
    setConflictSelectionController: (controller: CustomDialogController | null) => void,
    setConflictCompressController: (controller: CustomDialogController | null) => void,
    setConflictAdvanceController: (controller: CustomDialogController | null) => void,
    setSuggestionDialogController: (controller: CustomDialogController | null) => void,
    setCurrentStrategyExplanation: (explanation: string) => void,
    setStrategyAdaptationCheckTimer: (timer: number) => void
  ): IndexPageRuntimeOrchestratorContext {
    return {
      currentPlanId: currentPlanId,
      vm: vm,
      planService: planService,
      weatherCoordinator: weatherCoordinator,
      arrivalCoordinator: arrivalCoordinator,
      strategyMode: strategyMode,
      isWeatherDialogOpen: isWeatherDialogOpen,
      isArrivalDialogOpen: isArrivalDialogOpen,
      weatherReminderUnsubscribe: weatherReminderUnsubscribe,
      arrivalReminderUnsubscribe: arrivalReminderUnsubscribe,
      strategyAdaptationCheckTimer: strategyAdaptationCheckTimer,
      getUIContext: (): UIContext => getUIContext(),
      safeShowToast: (message: string): void => safeShowToast(message),
      tryStartEventWithConflictPrompt: async (eventId: number): Promise<boolean> =>
        tryStartEventWithConflictPrompt(eventId),
      setWeatherDialogOpen: (value: boolean): void => setWeatherDialogOpen(value),
      setArrivalDialogOpen: (value: boolean): void => setArrivalDialogOpen(value),
      setCompanionMode: (value: boolean): void => setCompanionMode(value),
      setManualPlanningWeatherRefresh: (value: boolean): void => setManualPlanningWeatherRefresh(value),
      setWeatherReminderUnsubscribe: (unsubscribe: (() => void) | null): void =>
        setWeatherReminderUnsubscribe(unsubscribe),
      setArrivalReminderUnsubscribe: (unsubscribe: (() => void) | null): void =>
        setArrivalReminderUnsubscribe(unsubscribe),
      setConflictSelectionController: (controller: CustomDialogController | null): void =>
        setConflictSelectionController(controller),
      setConflictCompressController: (controller: CustomDialogController | null): void =>
        setConflictCompressController(controller),
      setConflictAdvanceController: (controller: CustomDialogController | null): void =>
        setConflictAdvanceController(controller),
      setSuggestionDialogController: (controller: CustomDialogController | null): void =>
        setSuggestionDialogController(controller),
      setCurrentStrategyExplanation: (explanation: string): void => setCurrentStrategyExplanation(explanation),
      setStrategyAdaptationCheckTimer: (timer: number): void => setStrategyAdaptationCheckTimer(timer)
    };
  }
}
