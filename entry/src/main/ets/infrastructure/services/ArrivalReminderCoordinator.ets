import { EventEntity } from '../../model/entity/EventEntity';
import { ArrivalReminderAction, ArrivalReminderEngine, ArrivalReminderPayload } from './ArrivalReminderEngine';
import { ArrivalReminderStore } from '../../common/utils/arrival/ArrivalReminderStore';
import { TimelineExecutionState } from '../../domain/policy/TimelineExecutionState';

export interface HomeArrivalConsumeInput {
  isDialogOpen: boolean;
  resolvePlanTitle: (planId: number) => string;
  onShow: (payload: ArrivalReminderPayload, planTitle: string) => void;
}

export interface PlanArrivalConsumeInput {
  isDialogOpen: boolean;
  currentPlanId: number;
  events: EventEntity[];
  onShow: (payload: ArrivalReminderPayload) => void;
}

export class ArrivalReminderCoordinator {
  private static instance: ArrivalReminderCoordinator | null = null;

  public static getInstance(): ArrivalReminderCoordinator {
    if (!ArrivalReminderCoordinator.instance) {
      ArrivalReminderCoordinator.instance = new ArrivalReminderCoordinator();
    }
    return ArrivalReminderCoordinator.instance;
  }

  public consumeOnHome(input: HomeArrivalConsumeInput): void {
    if (input.isDialogOpen) {
      return;
    }
    const payload = this.readPayload();
    if (!payload) {
      return;
    }
    input.onShow(payload, input.resolvePlanTitle(payload.planId));
  }

  public consumeOnPlan(input: PlanArrivalConsumeInput): void {
    if (input.isDialogOpen) {
      return;
    }
    const payload = this.readPayload(input.currentPlanId);
    if (!payload) {
      return;
    }
    if (payload.planId !== input.currentPlanId) {
      return;
    }

    const active = input.events.find((event: EventEntity) => TimelineExecutionState.isActive(event));
    if (active && active.id !== payload.eventId) {
      this.acknowledge(payload.eventId, 'dismiss');
      return;
    }

    const target = input.events.find((event: EventEntity) => event.id === payload.eventId);
    if (!target || !TimelineExecutionState.isStartable(target)) {
      this.acknowledge(payload.eventId, 'dismiss');
      return;
    }

    input.onShow(payload);
  }

  public acknowledge(eventId: number, action: ArrivalReminderAction): void {
    ArrivalReminderEngine.getInstance().acknowledgeReminder(eventId, action);
  }

  private readPayload(planId?: number): ArrivalReminderPayload | null {
    return ArrivalReminderStore.readPayload(planId);
  }
}
