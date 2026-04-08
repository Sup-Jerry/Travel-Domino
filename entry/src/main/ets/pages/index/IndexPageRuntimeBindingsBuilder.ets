import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { PlanAppService } from '../../viewmodel/PlanAppService';
import { WeatherReminderCoordinator } from '../../infrastructure/services/WeatherReminderCoordinator';
import { ArrivalReminderCoordinator } from '../../infrastructure/services/ArrivalReminderCoordinator';
import { WeatherReminderPayload } from '../../common/utils/weather/WeatherReminderStore';
import { ArrivalReminderPayload } from '../../infrastructure/services/ArrivalReminderEngine';
import { IndexReminderSubscriptionHelper } from './IndexReminderSubscriptionHelper';
import { IndexPageContextFactory } from './IndexPageContextFactory';
import { ConflictFlowContext } from './IndexConflictFlowHelper';
import { ReminderDialogContext, StrategyDialogContext } from './IndexPageBehaviorHelper';

export interface ReminderSubscriptionBindingsInput {
  currentPlanId: number;
  vm: TimelineViewModel;
  weatherCoordinator: WeatherReminderCoordinator;
  arrivalCoordinator: ArrivalReminderCoordinator;
  isWeatherDialogOpen: () => boolean;
  isArrivalDialogOpen: () => boolean;
  onShowWeatherDialog: (payload: WeatherReminderPayload) => void;
  onShowArrivalDialog: (payload: ArrivalReminderPayload) => void;
  onClearWeatherDialog: () => void;
}

export interface ReminderPullRefreshBindingsInput {
  currentPlanId: number;
  vm: TimelineViewModel;
  planService: PlanAppService;
  arrivalCoordinator: ArrivalReminderCoordinator;
  isArrivalDialogOpen: boolean;
  onShowArrivalDialog: (payload: ArrivalReminderPayload) => void;
  setManualWeatherRefreshed: () => void;
}

export interface ReminderDialogContextBindingsInput {
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

export interface ConflictFlowContextBindingsInput {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  setConflictSelectionController: (controller: CustomDialogController | null) => void;
  setConflictCompressController: (controller: CustomDialogController | null) => void;
  setConflictAdvanceController: (controller: CustomDialogController | null) => void;
  setSuggestionDialogController: (controller: CustomDialogController | null) => void;
}

export interface StrategyDialogContextBindingsInput {
  vm: TimelineViewModel;
  strategyMode: number;
  getUIContext: () => UIContext;
  regenerateByCurrentStrategy: () => Promise<void>;
}

export interface ReminderUnsubscribeResult {
  weatherUnsubscribe: (() => void) | null;
  arrivalUnsubscribe: (() => void) | null;
}

export class IndexPageRuntimeBindingsBuilder {
  static bindReminderSubscriptions(input: ReminderSubscriptionBindingsInput): ReminderUnsubscribeResult {
    return IndexReminderSubscriptionHelper.bind({
      currentPlanId: input.currentPlanId,
      vm: input.vm,
      weatherCoordinator: input.weatherCoordinator,
      arrivalCoordinator: input.arrivalCoordinator,
      isWeatherDialogOpen: (): boolean => input.isWeatherDialogOpen(),
      isArrivalDialogOpen: (): boolean => input.isArrivalDialogOpen(),
      onShowWeatherDialog: (payload: WeatherReminderPayload): void => input.onShowWeatherDialog(payload),
      onShowArrivalDialog: (payload: ArrivalReminderPayload): void => input.onShowArrivalDialog(payload),
      onClearWeatherDialog: (): void => input.onClearWeatherDialog()
    });
  }

  static unbindReminderSubscriptions(
    weatherUnsubscribe: (() => void) | null,
    arrivalUnsubscribe: (() => void) | null
  ): ReminderUnsubscribeResult {
    return IndexReminderSubscriptionHelper.unbind(weatherUnsubscribe, arrivalUnsubscribe);
  }

  static async handlePagePullRefresh(input: ReminderPullRefreshBindingsInput): Promise<void> {
    await IndexReminderSubscriptionHelper.handlePagePullRefresh({
      currentPlanId: input.currentPlanId,
      vm: input.vm,
      planService: input.planService,
      arrivalCoordinator: input.arrivalCoordinator,
      isArrivalDialogOpen: input.isArrivalDialogOpen,
      onShowArrivalDialog: (payload: ArrivalReminderPayload): void => input.onShowArrivalDialog(payload),
      setManualWeatherRefreshed: (): void => input.setManualWeatherRefreshed()
    });
  }

  static createReminderDialogContext(input: ReminderDialogContextBindingsInput): ReminderDialogContext {
    return IndexPageContextFactory.createReminderDialogContext({
      vm: input.vm,
      currentPlanId: input.currentPlanId,
      getUIContext: (): UIContext => input.getUIContext(),
      weatherCoordinator: input.weatherCoordinator,
      arrivalCoordinator: input.arrivalCoordinator,
      tryStartEventWithConflictPrompt: async (eventId: number): Promise<boolean> =>
        input.tryStartEventWithConflictPrompt(eventId),
      setWeatherDialogOpen: (value: boolean): void => input.setWeatherDialogOpen(value),
      setArrivalDialogOpen: (value: boolean): void => input.setArrivalDialogOpen(value),
      setCompanionMode: (value: boolean): void => input.setCompanionMode(value),
      safeShowToast: (message: string): void => input.safeShowToast(message)
    });
  }

  static createConflictFlowContext(input: ConflictFlowContextBindingsInput): ConflictFlowContext {
    return IndexPageContextFactory.createConflictFlowContext({
      vm: input.vm,
      getUIContext: (): UIContext => input.getUIContext(),
      safeShowToast: (message: string): void => input.safeShowToast(message),
      setConflictSelectionController: (controller: CustomDialogController | null): void =>
        input.setConflictSelectionController(controller),
      setConflictCompressController: (controller: CustomDialogController | null): void =>
        input.setConflictCompressController(controller),
      setConflictAdvanceController: (controller: CustomDialogController | null): void =>
        input.setConflictAdvanceController(controller),
      setSuggestionDialogController: (controller: CustomDialogController | null): void =>
        input.setSuggestionDialogController(controller)
    });
  }

  static createStrategyDialogContext(input: StrategyDialogContextBindingsInput): StrategyDialogContext {
    return IndexPageContextFactory.createStrategyDialogContext({
      vm: input.vm,
      strategyMode: input.strategyMode,
      getUIContext: (): UIContext => input.getUIContext(),
      regenerateByCurrentStrategy: async (): Promise<void> => input.regenerateByCurrentStrategy()
    });
  }
}

