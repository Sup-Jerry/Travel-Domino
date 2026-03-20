import { WeatherReminderPayload, WeatherReminderStore } from '../../common/utils/weather/WeatherReminderStore';

export interface PlanWeatherConsumeInput {
  isDialogOpen: boolean;
  currentPlanId: number;
  onShow: (payload: WeatherReminderPayload) => void;
}

export class WeatherReminderCoordinator {
  private static instance: WeatherReminderCoordinator | null = null;

  public static getInstance(): WeatherReminderCoordinator {
    if (!WeatherReminderCoordinator.instance) {
      WeatherReminderCoordinator.instance = new WeatherReminderCoordinator();
    }
    return WeatherReminderCoordinator.instance;
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
}
