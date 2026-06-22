import { EventEntity } from '../../model/entity/EventEntity';
import { ArrivalReminderAction, ArrivalReminderEngine, ArrivalReminderPayload } from './ArrivalReminderEngine';
import { ArrivalReminderStore } from '../../common/utils/arrival/ArrivalReminderStore';
import { TimelineExecutionState } from '../../domain/policy/TimelineExecutionState';
import { PlanStateMachine } from '../../domain/statemachine/PlanStateMachine';
import { PlanStatus } from '../../domain/statemachine/PlanStatus';

export type ArrivalPlanTitleResolver = (planId: number) => string;
export type ArrivalHomeShowCallback = (payload: ArrivalReminderPayload, planTitle: string) => void;
export type ArrivalPlanShowCallback = (payload: ArrivalReminderPayload) => void;
export type ArrivalDialogStateGetter = () => boolean;
export type ArrivalEventsResolver = () => EventEntity[];
export type ArrivalUnsubscribeCallback = () => void;

export interface HomeArrivalConsumeInput {
  isDialogOpen: boolean;
  resolvePlanTitle: ArrivalPlanTitleResolver;
  onShow: ArrivalHomeShowCallback;
}

export interface PlanArrivalConsumeInput {
  isDialogOpen: boolean;
  currentPlanId: number;
  events: EventEntity[];
  onShow: ArrivalPlanShowCallback;
}

export interface ArrivalReminderSubscriptionHandlers {
  isDialogOpen: ArrivalDialogStateGetter;
  resolveEvents?: ArrivalEventsResolver;
  resolvePlanTitle?: ArrivalPlanTitleResolver;
  onShowPlan?: ArrivalPlanShowCallback;
  onShowHome?: ArrivalHomeShowCallback;
  pollIntervalMs?: number;
}

export class ArrivalReminderCoordinator {
  private static instance: ArrivalReminderCoordinator | null = null;
  private readonly planStateMachine: PlanStateMachine = PlanStateMachine.getInstance();

  public static getInstance(): ArrivalReminderCoordinator {
    if (!ArrivalReminderCoordinator.instance) {
      ArrivalReminderCoordinator.instance = new ArrivalReminderCoordinator();
    }
    return ArrivalReminderCoordinator.instance;
  }

  public subscribePlan(planId: number | '*', handlers: ArrivalReminderSubscriptionHandlers): ArrivalUnsubscribeCallback {
    const isWildcard = planId === '*';
    let disposed = false;
    let lastConsumeKey = '';

    const stateUnsubscribe = this.planStateMachine.subscribePlanTransition(
      isWildcard ? '*' : `${planId}`,
      (event) => {
        if (!this.isTerminalStatus(event.toStatus)) {
          return;
        }
        const payload = this.readPayload(Number(event.planId));
        if (payload) {
          this.acknowledge(payload.eventId, 'dismiss');
        }
        ArrivalReminderStore.clearPayload(Number(event.planId));
      }
    );

    const tick = (): void => {
      if (disposed || handlers.isDialogOpen()) {
        return;
      }
      const payload = this.readPayload(isWildcard ? undefined : (planId as number));
      if (!payload) {
        return;
      }
      if (!this.canShowByPlanStatus(payload.planId)) {
        return;
      }

      const key = `${payload.planId}_${payload.eventId}_${payload.seq}`;
      if (key === lastConsumeKey) {
        return;
      }

      if (isWildcard) {
        if (!handlers.onShowHome || !handlers.resolvePlanTitle) {
          return;
        }
        lastConsumeKey = key;
        handlers.onShowHome(payload, handlers.resolvePlanTitle(payload.planId));
        return;
      }

      const currentPlanId = planId as number;
      if (payload.planId !== currentPlanId) {
        return;
      }
      if (!handlers.onShowPlan || !handlers.resolveEvents) {
        return;
      }
      const events = handlers.resolveEvents();
      const active = events.find((event: EventEntity) => TimelineExecutionState.isActive(event));
      if (active && active.id !== payload.eventId) {
        this.acknowledge(payload.eventId, 'dismiss');
        return;
      }
      const target = events.find((event: EventEntity) => event.id === payload.eventId);
      if (!target || !TimelineExecutionState.isStartable(target)) {
        this.acknowledge(payload.eventId, 'dismiss');
        return;
      }

      lastConsumeKey = key;
      handlers.onShowPlan(payload);
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

  private canShowByPlanStatus(planId: number): boolean {
    const status = this.planStateMachine.getPlanStatus(`${planId}`).status;
    return status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS;
  }

  private isTerminalStatus(status: PlanStatus): boolean {
    return status === PlanStatus.COMPLETED || status === PlanStatus.CANCELLED || status === PlanStatus.EXPIRED;
  }
}
