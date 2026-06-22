import { WeatherReminderPayload, WeatherReminderStore } from '../../common/utils/weather/WeatherReminderStore';
import { PlanStateMachine } from '../../domain/statemachine/PlanStateMachine';
import { PlanStatus } from '../../domain/statemachine/PlanStatus';

export type WeatherReminderShowCallback = (payload: WeatherReminderPayload) => void;
export type WeatherReminderDialogStateGetter = () => boolean;
export type WeatherReminderVoidCallback = () => void;
export type WeatherReminderUnsubscribeCallback = () => void;

export interface PlanWeatherConsumeInput {
  isDialogOpen: boolean;
  currentPlanId: number;
  onShow: WeatherReminderShowCallback;
}

export interface WeatherReminderSubscriptionHandlers {
  isDialogOpen: WeatherReminderDialogStateGetter;
  onShow: WeatherReminderShowCallback;
  onClear?: WeatherReminderVoidCallback;
  pollIntervalMs?: number;
}

export class WeatherReminderCoordinator {
  private static instance: WeatherReminderCoordinator | null = null;
  private readonly planStateMachine: PlanStateMachine = PlanStateMachine.getInstance();

  public static getInstance(): WeatherReminderCoordinator {
    if (!WeatherReminderCoordinator.instance) {
      WeatherReminderCoordinator.instance = new WeatherReminderCoordinator();
    }
    return WeatherReminderCoordinator.instance;
  }

  public subscribePlan(planId: number, handlers: WeatherReminderSubscriptionHandlers): WeatherReminderUnsubscribeCallback {
    const normalizedPlanId = planId > 0 ? planId : -1;
    if (normalizedPlanId <= 0) {
      return () => {
      };
    }

    let disposed = false;
    let lastSeq = -1;
    const planIdStr = `${normalizedPlanId}`;

    const stateUnsubscribe = this.planStateMachine.subscribePlanTransition(planIdStr, (event) => {
      if (this.isTerminalStatus(event.toStatus)) {
        this.clear(normalizedPlanId);
        handlers.onClear?.();
      }
    });

    const tick = (): void => {
      if (disposed || handlers.isDialogOpen()) {
        return;
      }
      const status = this.planStateMachine.getPlanStatus(planIdStr).status;
      if (this.isTerminalStatus(status)) {
        return;
      }
      const payload = WeatherReminderStore.readPayload(normalizedPlanId);
      if (!payload || payload.planId !== normalizedPlanId) {
        return;
      }
      if (!Number.isFinite(payload.seq) || payload.seq <= lastSeq) {
        return;
      }
      lastSeq = payload.seq;
      handlers.onShow(payload);
    };

    const interval = handlers.pollIntervalMs ?? 1000;
    const timerId = setInterval(() => tick(), interval);
    tick();

    return () => {
      if (disposed) {
        return;
      }
      disposed = true;
      clearInterval(timerId);
      stateUnsubscribe();
    };
  }

  public consumeOnPlan(input: PlanWeatherConsumeInput): void {
    if (input.isDialogOpen) {
      return;
    }
    const payload = WeatherReminderStore.readPayload(input.currentPlanId);
    if (!payload) {
      return;
    }
    if (payload.planId !== input.currentPlanId) {
      return;
    }
    input.onShow(payload);
  }

  public clear(planId?: number): void {
    WeatherReminderStore.clearPayload(planId);
  }

  private isTerminalStatus(status: PlanStatus): boolean {
    return status === PlanStatus.COMPLETED || status === PlanStatus.CANCELLED || status === PlanStatus.EXPIRED;
  }
}
