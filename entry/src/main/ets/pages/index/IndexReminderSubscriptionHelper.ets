import { EventEntity } from '../../model/entity/EventEntity';
import { ArrivalReminderPayload } from '../../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../../infrastructure/services/ArrivalReminderCoordinator';
import { WeatherReminderPayload } from '../../common/utils/weather/WeatherReminderStore';
import { WeatherReminderCoordinator } from '../../infrastructure/services/WeatherReminderCoordinator';
import { PlanAppService } from '../../viewmodel/PlanAppService';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export interface ReminderSubscriptionBindResult {
  weatherUnsubscribe: (() => void) | null;
  arrivalUnsubscribe: (() => void) | null;
}

export interface ReminderSubscriptionBindContext {
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

export interface PullRefreshContext {
  currentPlanId: number;
  vm: TimelineViewModel;
  planService: PlanAppService;
  arrivalCoordinator: ArrivalReminderCoordinator;
  isArrivalDialogOpen: boolean;
  onShowArrivalDialog: (payload: ArrivalReminderPayload) => void;
  setManualWeatherRefreshed: () => void;
}

export class IndexReminderSubscriptionHelper {
  static bind(context: ReminderSubscriptionBindContext): ReminderSubscriptionBindResult {
    if (context.currentPlanId <= 0) {
      return {
        weatherUnsubscribe: null,
        arrivalUnsubscribe: null
      };
    }

    const weatherUnsubscribe = context.weatherCoordinator.subscribePlan(context.currentPlanId, {
      isDialogOpen: (): boolean => context.isWeatherDialogOpen(),
      onShow: (payload: WeatherReminderPayload): void => {
        if (!context.vm.isWeatherFeatureEnabled()) {
          return;
        }
        context.onShowWeatherDialog(payload);
      },
      onClear: (): void => {
        context.onClearWeatherDialog();
      }
    });

    const arrivalUnsubscribe = context.arrivalCoordinator.subscribePlan(context.currentPlanId, {
      isDialogOpen: (): boolean => context.isArrivalDialogOpen(),
      resolveEvents: (): EventEntity[] => context.vm.events,
      onShowPlan: (payload: ArrivalReminderPayload): void => {
        context.onShowArrivalDialog(payload);
      }
    });

    return {
      weatherUnsubscribe,
      arrivalUnsubscribe
    };
  }

  static unbind(
    weatherUnsubscribe: (() => void) | null,
    arrivalUnsubscribe: (() => void) | null
  ): ReminderSubscriptionBindResult {
    if (weatherUnsubscribe) {
      weatherUnsubscribe();
    }
    if (arrivalUnsubscribe) {
      arrivalUnsubscribe();
    }
    return {
      weatherUnsubscribe: null,
      arrivalUnsubscribe: null
    };
  }

  static async handlePagePullRefresh(context: PullRefreshContext): Promise<void> {
    if (context.currentPlanId <= 0) {
      return;
    }
    await context.vm.loadData(context.currentPlanId);
    await context.planService.requestArrivalCheckNow('plan_manual_refresh');
    context.arrivalCoordinator.consumeOnPlan({
      isDialogOpen: context.isArrivalDialogOpen,
      currentPlanId: context.currentPlanId,
      events: context.vm.events,
      onShow: (payload: ArrivalReminderPayload): void => {
        context.onShowArrivalDialog(payload);
      }
    });
    if (context.vm.isWeatherFeatureEnabled()) {
      context.setManualWeatherRefreshed();
    }
  }
}
