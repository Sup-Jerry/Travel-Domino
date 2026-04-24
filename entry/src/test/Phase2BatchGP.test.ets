import { describe, expect, it } from '@ohos/hypium';
import { ArrivalReminderCoordinator, ArrivalReminderSubscriptionHandlers } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { ArrivalReminderAction, ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';

interface PlanTransitionEventGP {
  planId: string;
  toStatus: PlanStatus;
}

class PlanStatusSnapshotGP {
  status: PlanStatus = PlanStatus.READY;
}

class FakePlanStateMachineGP {
  public status: PlanStatus = PlanStatus.READY;
  private listener: ((event: PlanTransitionEventGP) => void) | null = null;

  subscribePlanTransition(_planId: string, listener: (event: PlanTransitionEventGP) => void): () => void {
    this.listener = listener;
    return (): void => {
      this.listener = null;
    };
  }

  getPlanStatus(_planId: string): PlanStatusSnapshotGP {
    const snapshot = new PlanStatusSnapshotGP();
    snapshot.status = this.status;
    return snapshot;
  }

  emit(planId: string, toStatus: PlanStatus): void {
    this.listener?.({ planId: planId, toStatus: toStatus });
  }
}

class TimerHooksGP {
  private readonly originSetInterval: Object;
  private readonly originClearInterval: Object;
  private callback: (() => void) | null = null;
  public clearCalls: number[] = [];

  constructor() {
    this.originSetInterval = Reflect.get(globalThis, 'setInterval') as Object;
    this.originClearInterval = Reflect.get(globalThis, 'clearInterval') as Object;
  }

  install(): void {
    Reflect.set(globalThis, 'setInterval', (callback: () => void, _intervalMs: number): number => {
      this.callback = callback;
      return 1;
    });
    Reflect.set(globalThis, 'clearInterval', (timerId: number): void => {
      this.clearCalls.push(timerId);
    });
  }

  trigger(): void {
    this.callback?.();
  }

  restore(): void {
    Reflect.set(globalThis, 'setInterval', this.originSetInterval);
    Reflect.set(globalThis, 'clearInterval', this.originClearInterval);
  }
}

function buildPayloadGP(planId: number, eventId: number, seq: number): ArrivalReminderPayload {
  return {
    seq: seq,
    planId: planId,
    eventId: eventId,
    placeName: `place-${eventId}`,
    distanceMeters: 80,
    triggerAt: 1713000000000 + seq
  };
}

function buildStartableEventGP(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

export default function phase2BatchGPTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGP_arrival_subscription_lines', () => {
    it('normal: subscribe_plan_should_acknowledge_and_clear_when_terminal_transition_arrives', 0, () => {
      // Arrange
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const coordinator = ArrivalReminderCoordinator.getInstance() as Object;
      const machine = new FakePlanStateMachineGP();
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      const originClear = Reflect.get(ArrivalReminderStore, 'clearPayload') as Object;
      const originAcknowledge = Reflect.get(coordinator, 'acknowledge') as Object;
      let acknowledgedEventId = -1;
      let acknowledgedAction = '';
      let clearedPlanId = -1;
      Reflect.set(coordinator, 'planStateMachine', machine);
      Reflect.set(ArrivalReminderStore, 'readPayload', (_planId?: number): ArrivalReminderPayload | null => buildPayloadGP(701, 7001, 1));
      Reflect.set(ArrivalReminderStore, 'clearPayload', (planId?: number): void => {
        clearedPlanId = Number(planId ?? -1);
      });
      Reflect.set(coordinator, 'acknowledge', (eventId: number, action: ArrivalReminderAction): void => {
        acknowledgedEventId = eventId;
        acknowledgedAction = action;
      });

      // Act
      const unsubscribe = (coordinator as ArrivalReminderCoordinator).subscribePlan('*', {
        isDialogOpen: (): boolean => true,
        pollIntervalMs: 30
      } as ArrivalReminderSubscriptionHandlers);
      machine.emit('701', PlanStatus.COMPLETED);
      unsubscribe();

      // Assert
      expect(acknowledgedEventId).assertEqual(7001);
      expect(acknowledgedAction).assertEqual('dismiss');
      expect(clearedPlanId).assertEqual(701);
      Reflect.set(coordinator, 'acknowledge', originAcknowledge);
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      Reflect.set(ArrivalReminderStore, 'clearPayload', originClear);
    });

    it('combined: subscribe_plan_timer_should_show_plan_after_interval_tick_with_startable_target', 0, () => {
      // Arrange
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const coordinator = ArrivalReminderCoordinator.getInstance() as Object;
      const machine = new FakePlanStateMachineGP();
      const timerHooks = new TimerHooksGP();
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      let dialogOpen = true;
      let showCount = 0;
      let shownEventId = -1;
      Reflect.set(coordinator, 'planStateMachine', machine);
      Reflect.set(ArrivalReminderStore, 'readPayload', (_planId?: number): ArrivalReminderPayload | null => buildPayloadGP(801, 8001, 2));
      timerHooks.install();

      // Act
      const unsubscribe = (coordinator as ArrivalReminderCoordinator).subscribePlan(801, {
        isDialogOpen: (): boolean => dialogOpen,
        resolveEvents: (): EventEntity[] => [buildStartableEventGP(8001)],
        onShowPlan: (payload: ArrivalReminderPayload): void => {
          showCount += 1;
          shownEventId = payload.eventId;
        },
        pollIntervalMs: 60
      } as ArrivalReminderSubscriptionHandlers);
      dialogOpen = false;
      timerHooks.trigger();
      unsubscribe();

      // Assert
      expect(showCount).assertEqual(1);
      expect(shownEventId).assertEqual(8001);
      expect(timerHooks.clearCalls.length).assertEqual(1);
      timerHooks.restore();
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
    });
  });
}
