import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { ArrivalReminderCoordinator } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';

interface PlanTransitionEventForF {
  planId: string;
  toStatus: PlanStatus;
}

interface PlanStatusSnapshotForF {
  status: PlanStatus;
}

class FakePlanStateMachineForF {
  public status: PlanStatus = PlanStatus.READY;
  private listener: ((event: PlanTransitionEventForF) => void) | null = null;

  public subscribePlanTransition(_planId: string, handler: (event: PlanTransitionEventForF) => void): () => void {
    this.listener = handler;
    return (): void => {
      this.listener = null;
    };
  }

  public getPlanStatus(_planId: string): PlanStatusSnapshotForF {
    return { status: this.status };
  }

  public emit(planId: number, toStatus: PlanStatus): void {
    this.listener?.({ planId: `${planId}`, toStatus: toStatus });
  }
}

function buildPayload(planId: number, eventId: number, seq: number, placeName: string): ArrivalReminderPayload {
  return {
    seq: seq,
    planId: planId,
    eventId: eventId,
    placeName: placeName,
    distanceMeters: 120,
    triggerAt: 1713000000000 + seq
  };
}

function buildStartableEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

function buildActiveEvent(id: number): EventEntity {
  const event = buildStartableEvent(id);
  event.actual_start_time = 1000;
  event.actual_end_time = 0;
  return event;
}

export default function phase1ZeroHitBatchFTest() {
  describe('phase1ZeroHitBatchFTest', () => {
    it('normal: coordinator_consume_on_home_should_show_payload_when_dialog_closed', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(71, 701, 1, 'museum');
      ArrivalReminderStore.writePayload(payload);
      let shownPlanId = -1;
      let shownTitle = '';
      // Act
      coordinator.consumeOnHome({
        isDialogOpen: false,
        resolvePlanTitle: (planId: number): string => `plan-${planId}`,
        onShow: (nextPayload, title: string): void => {
          shownPlanId = nextPayload.planId;
          shownTitle = title;
        }
      });
      // Assert
      expect(shownPlanId).assertEqual(71);
      expect(shownTitle).assertEqual('plan-71');
    });

    it('boundary: coordinator_consume_on_home_should_skip_when_dialog_open', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(72, 702, 2, 'station');
      ArrivalReminderStore.writePayload(payload);
      let showCount = 0;
      // Act
      coordinator.consumeOnHome({
        isDialogOpen: true,
        resolvePlanTitle: (_planId: number): string => 'ignored',
        onShow: (_nextPayload, _title: string): void => {
          showCount += 1;
        }
      });
      // Assert
      expect(showCount).assertEqual(0);
    });

    it('invalid: coordinator_consume_on_plan_should_ignore_payload_for_other_plan', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(81, 801, 3, 'park');
      ArrivalReminderStore.writePayload(payload);
      let showCount = 0;
      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 82,
        events: [buildStartableEvent(801)],
        onShow: (_nextPayload): void => {
          showCount += 1;
        }
      });
      // Assert
      expect(showCount).assertEqual(0);
    });

    it('conflict: coordinator_consume_on_plan_should_dismiss_when_active_event_differs', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(91, 901, 4, 'bridge');
      ArrivalReminderStore.writePayload(payload);
      const activeOther = buildActiveEvent(902);
      const startableTarget = buildStartableEvent(901);
      let showCount = 0;
      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 91,
        events: [activeOther, startableTarget],
        onShow: (_nextPayload): void => {
          showCount += 1;
        }
      });
      const after = ArrivalReminderStore.readPayload(91);
      // Assert
      expect(showCount).assertEqual(0);
      expect(after === null).assertTrue();
    });

    it('regression: coordinator_consume_on_plan_should_show_when_target_startable_and_no_active_conflict', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(92, 920, 5, 'hotel');
      ArrivalReminderStore.writePayload(payload);
      let shownEventId = -1;
      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 92,
        events: [buildStartableEvent(920)],
        onShow: (nextPayload): void => {
          shownEventId = nextPayload.eventId;
        }
      });
      // Assert
      expect(shownEventId).assertEqual(920);
    });

    it('combined: coordinator_acknowledge_should_handle_all_actions_without_throw', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(93, 930, 6, 'mall');
      ArrivalReminderStore.writePayload(payload);
      let reached = false;
      // Act
      coordinator.acknowledge(930, 'dismiss');
      coordinator.acknowledge(930, 'open_page');
      coordinator.acknowledge(930, 'start');
      reached = true;
      // Assert
      expect(reached).assertTrue();
    });

    it('invalid: coordinator_consume_on_plan_should_ignore_when_payload_absent', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      ArrivalReminderStore.clearPayload(94);
      let showCount = 0;

      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 94,
        events: [buildStartableEvent(940)],
        onShow: (_nextPayload): void => {
          showCount += 1;
        }
      });

      // Assert
      expect(showCount).assertEqual(0);
    });

    it('invalid: coordinator_consume_on_plan_should_dismiss_when_target_event_missing', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const payload = buildPayload(95, 950, 7, 'missing-target');
      ArrivalReminderStore.writePayload(payload);
      let showCount = 0;

      // Act
      coordinator.consumeOnPlan({
        isDialogOpen: false,
        currentPlanId: 95,
        events: [buildStartableEvent(951)],
        onShow: (_nextPayload): void => {
          showCount += 1;
        }
      });
      const after = ArrivalReminderStore.readPayload(95);

      // Assert
      expect(showCount).assertEqual(0);
      expect(after === null).assertTrue();
    });

    it('boundary: coordinator_subscribe_plan_should_skip_home_show_when_resolve_title_missing', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineForF();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      const payload = buildPayload(96, 960, 8, 'title-missing');
      ArrivalReminderStore.writePayload(payload);
      let showCount = 0;

      // Act
      const unsubscribe = coordinator.subscribePlan('*', {
        isDialogOpen: (): boolean => false,
        onShowHome: (_nextPayload: ArrivalReminderPayload, _planTitle: string): void => {
          showCount += 1;
        },
        pollIntervalMs: 1000
      });
      unsubscribe();

      // Assert
      expect(showCount).assertEqual(0);
      expect(ArrivalReminderStore.readPayload(96) !== null).assertTrue();
    });

    it('boundary: coordinator_subscribe_plan_should_skip_plan_show_when_event_resolver_missing', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineForF();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      const payload = buildPayload(97, 970, 9, 'resolver-missing');
      ArrivalReminderStore.writePayload(payload);
      let showCount = 0;

      // Act
      const unsubscribe = coordinator.subscribePlan(97, {
        isDialogOpen: (): boolean => false,
        onShowPlan: (_nextPayload: ArrivalReminderPayload): void => {
          showCount += 1;
        },
        pollIntervalMs: 1000
      });
      unsubscribe();

      // Assert
      expect(showCount).assertEqual(0);
      expect(ArrivalReminderStore.readPayload(97) !== null).assertTrue();
    });

    it('regression: coordinator_subscribe_plan_should_ignore_non_terminal_transition', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineForF();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      const payload = buildPayload(98, 980, 10, 'non-terminal');
      ArrivalReminderStore.writePayload(payload);

      // Act
      const unsubscribe = coordinator.subscribePlan(98, {
        isDialogOpen: (): boolean => true,
        resolveEvents: (): EventEntity[] => [buildStartableEvent(980)],
        onShowPlan: (_nextPayload: ArrivalReminderPayload): void => {},
        pollIntervalMs: 1000
      });
      machine.emit(98, PlanStatus.READY);
      const after = ArrivalReminderStore.readPayload(98);
      unsubscribe();

      // Assert
      expect(after === null).assertFalse();
    });
  });
}
