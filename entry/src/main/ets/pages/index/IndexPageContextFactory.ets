import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { ArrivalReminderCoordinator } from '../../infrastructure/services/ArrivalReminderCoordinator';
import { WeatherReminderCoordinator } from '../../infrastructure/services/WeatherReminderCoordinator';
import { ConflictFlowContext } from './IndexConflictFlowHelper';
import { ReminderDialogContext, StrategyDialogContext } from './IndexPageBehaviorHelper';

export interface ReminderDialogContextParams {
  vm: TimelineViewModel;
  currentPlanId: number;
  getUIContext: () => UIContext;
  weatherCoordinator: WeatherReminderCoordinator;
  arrivalCoordinator: ArrivalReminderCoordinator;
  tryStartEventWithConflictPrompt: (eventId: number) => Promise<boolean>;
  setWeatherDialogOpen: (value: boolean) => void;
  setArrivalDialogOpen: (value: boolean) => void;
  setCompanionMode: (value: boolean) => void;
  safeShowToast: (message: string) => void;
}

export interface ConflictFlowContextParams {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  setConflictSelectionController: (controller: CustomDialogController | null) => void;
  setConflictCompressController: (controller: CustomDialogController | null) => void;
  setConflictAdvanceController: (controller: CustomDialogController | null) => void;
  setSuggestionDialogController: (controller: CustomDialogController | null) => void;
}

export interface StrategyDialogContextParams {
  vm: TimelineViewModel;
  strategyMode: number;
  getUIContext: () => UIContext;
  regenerateByCurrentStrategy: () => Promise<void>;
}

export class IndexPageContextFactory {
  static createReminderDialogContext(params: ReminderDialogContextParams): ReminderDialogContext {
    return {
      vm: params.vm,
      currentPlanId: params.currentPlanId,
      getUIContext: (): UIContext => params.getUIContext(),
      weatherCoordinator: params.weatherCoordinator,
      arrivalCoordinator: params.arrivalCoordinator,
      tryStartEventWithConflictPrompt: async (eventId: number): Promise<boolean> => params.tryStartEventWithConflictPrompt(eventId),
      setWeatherDialogOpen: (value: boolean): void => {
        params.setWeatherDialogOpen(value);
      },
      setArrivalDialogOpen: (value: boolean): void => {
        params.setArrivalDialogOpen(value);
      },
      setCompanionMode: (value: boolean): void => {
        params.setCompanionMode(value);
      },
      safeShowToast: (message: string): void => {
        params.safeShowToast(message);
      }
    };
  }

  static createConflictFlowContext(params: ConflictFlowContextParams): ConflictFlowContext {
    return {
      vm: params.vm,
      getUIContext: (): UIContext => params.getUIContext(),
      safeShowToast: (message: string): void => params.safeShowToast(message),
      setConflictSelectionController: (controller: CustomDialogController | null): void => {
        params.setConflictSelectionController(controller);
      },
      setConflictCompressController: (controller: CustomDialogController | null): void => {
        params.setConflictCompressController(controller);
      },
      setConflictAdvanceController: (controller: CustomDialogController | null): void => {
        params.setConflictAdvanceController(controller);
      },
      setSuggestionDialogController: (controller: CustomDialogController | null): void => {
        params.setSuggestionDialogController(controller);
      }
    };
  }

  static createStrategyDialogContext(params: StrategyDialogContextParams): StrategyDialogContext {
    return {
      vm: params.vm,
      strategyMode: params.strategyMode,
      getUIContext: (): UIContext => params.getUIContext(),
      regenerateByCurrentStrategy: async (): Promise<void> => params.regenerateByCurrentStrategy()
    };
  }
}
