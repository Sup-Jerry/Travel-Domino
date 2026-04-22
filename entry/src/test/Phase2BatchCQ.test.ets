import { describe, expect, it } from '@ohos/hypium';
import {
  ArrivalReminderCoordinator,
  HomeArrivalConsumeInput,
  PlanArrivalConsumeInput
} from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';

interface ArrivalReminderCoordinatorPrivateCQ {
  acknowledgeCalls?: string[];
  readPayload(planId?: number): ArrivalReminderPayload | null;
  acknowledge(eventId: number, action: string): void;
  canShowByPlanStatus(planId: number): boolean;
  isTerminalStatus(status: PlanStatus): boolean;
}

interface FakePlanStatusResultCQ {
  planId: string;
  status: PlanStatus;
}

class FakePlanStateMachineCQ {
  public status: PlanStatus = PlanStatus.READY;
  public requestedPlanIds: string[] = [];

  getPlanStatus(planId: string): FakePlanStatusResultCQ {
    this.requestedPlanIds.push(planId);
    const result: FakePlanStatusResultCQ = { planId: planId, status: this.status };
    return result;
  }
}

class CoordinatorHooksCQ {
  private readonly coordinator: ArrivalReminderCoordinator;
  private readonly originReadPayload: Object;
  private readonly originAcknowledge: Object;
  private readonly originPlanStateMachine: Object;
  public readonly stateMachine: FakePlanStateMachineCQ = new FakePlanStateMachineCQ();

  constructor(coordinator: ArrivalReminderCoordinator) {
    this.coordinator = coordinator;
    this.originReadPayload = Reflect.get(coordinator as Object, 'readPayload') as Object;
    this.originAcknowledge = Reflect.get(coordinator as Object, 'acknowledge') as Object;
    this.originPlanStateMachine = Reflect.get(coordinator as Object, 'planStateMachine') as Object;
    Reflect.set(coordinator as Object, 'planStateMachine', this.stateMachine as Object);
  }

  setPayload(payload: ArrivalReminderPayload | null): void {
    Reflect.set(this.coordinator as Object, 'readPayload', (_planId?: number): ArrivalReminderPayload | null => payload);
  }

  captureAcknowledge(): string[] {
    const calls: string[] = [];
    Reflect.set(this.coordinator as Object, 'acknowledge', (eventId: number, action: string): void => {
      calls.push(`${eventId}:${action}`);
    });
    return calls;
  }

  restore(): void {
    Reflect.set(this.coordinator as Object, 'readPayload', this.originReadPayload);
    Reflect.set(this.coordinator as Object, 'acknowledge', this.originAcknowledge);
    Reflect.set(this.coordinator as Object, 'planStateMachine', this.originPlanStateMachine);
  }
}

function payloadCQ(planId: number, eventId: number, seq: number = 1): ArrivalReminderPayload {
  return {
    seq: seq,
    planId: planId,
    eventId: eventId,
    placeName: `place_${eventId}`,
    distanceMeters: 80,
    triggerAt: 1000 + seq
  };
}

function eventCQ(id: number, status: number, completionStatus: number, actualStart: number, actualEnd: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = status;
  event.completion_status = completionStatus;
  event.actual_start_time = actualStart;
  event.actual_end_time = actualEnd;
  return event;
}

export default function phase2BatchCQTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCQ_arrival_reminder_coordinator', () => {
    it('normal: arrival_home_consume_should_show_payload_with_resolved_title', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const hooks = new CoordinatorHooksCQ(coordinator);
      hooks.setPayload(payloadCQ(41, 4101));
      let shownTitle = '';
      let shownEventId = 0;
      const input: HomeArrivalConsumeInput = {
        isDialogOpen: false,
        resolvePlanTitle: (planId: number): string => `Plan-${planId}`,
        onShow: (payload: ArrivalReminderPayload, title: string): void => {
          shownEventId = payload.eventId;
          shownTitle = title;
        }
      };
      // Act
      coordinator.consumeOnHome(input);
      hooks.restore();
      // Assert
      expect(shownEventId).assertEqual(4101);
      expect(shownTitle).assertEqual('Plan-41');
    });

    it('boundary: arrival_plan_consume_should_ignore_mismatched_plan_payload', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const hooks = new CoordinatorHooksCQ(coordinator);
      hooks.setPayload(payloadCQ(42, 4201));
      let showCount = 0;
      const input: PlanArrivalConsumeInput = {
        isDialogOpen: false,
        currentPlanId: 43,
        events: [eventCQ(4201, 1, EventEntity.STATE_PENDING, 0, 0)],
        onShow: (_payload: ArrivalReminderPayload): void => {
          showCount++;
        }
      };
      // Act
      coordinator.consumeOnPlan(input);
      hooks.restore();
      // Assert
      expect(showCount).assertEqual(0);
    });

    it('invalid: arrival_plan_consume_should_acknowledge_missing_target_event', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const hooks = new CoordinatorHooksCQ(coordinator);
      hooks.setPayload(payloadCQ(44, 4401));
      const acknowledgeCalls = hooks.captureAcknowledge();
      const input: PlanArrivalConsumeInput = {
        isDialogOpen: false,
        currentPlanId: 44,
        events: [],
        onShow: (_payload: ArrivalReminderPayload): void => {
        }
      };
      // Act
      coordinator.consumeOnPlan(input);
      hooks.restore();
      // Assert
      expect(acknowledgeCalls.length).assertEqual(1);
      expect(acknowledgeCalls[0]).assertEqual('4401:dismiss');
    });

    it('conflict: arrival_plan_consume_should_acknowledge_when_other_event_is_active', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const hooks = new CoordinatorHooksCQ(coordinator);
      hooks.setPayload(payloadCQ(45, 4501));
      const acknowledgeCalls = hooks.captureAcknowledge();
      const input: PlanArrivalConsumeInput = {
        isDialogOpen: false,
        currentPlanId: 45,
        events: [
          eventCQ(4599, 1, EventEntity.STATE_PENDING, 100, 0),
          eventCQ(4501, 1, EventEntity.STATE_PENDING, 0, 0)
        ],
        onShow: (_payload: ArrivalReminderPayload): void => {
        }
      };
      // Act
      coordinator.consumeOnPlan(input);
      hooks.restore();
      // Assert
      expect(acknowledgeCalls.length).assertEqual(1);
      expect(acknowledgeCalls[0]).assertEqual('4501:dismiss');
    });

    it('regression: arrival_status_gate_should_allow_ready_and_block_completed', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const hooks = new CoordinatorHooksCQ(coordinator);
      const privateApi = coordinator as Object as ArrivalReminderCoordinatorPrivateCQ;
      // Act
      hooks.stateMachine.status = PlanStatus.READY;
      const ready = privateApi.canShowByPlanStatus(46);
      hooks.stateMachine.status = PlanStatus.COMPLETED;
      const completed = privateApi.canShowByPlanStatus(46);
      hooks.restore();
      // Assert
      expect(ready).assertTrue();
      expect(completed).assertFalse();
      expect(hooks.stateMachine.requestedPlanIds[0]).assertEqual('46');
    });

    it('combined: arrival_plan_consume_should_show_only_startable_matching_event_and_terminal_status_should_include_expired', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const hooks = new CoordinatorHooksCQ(coordinator);
      hooks.setPayload(payloadCQ(47, 4701));
      const privateApi = coordinator as Object as ArrivalReminderCoordinatorPrivateCQ;
      let shownEventId = 0;
      const input: PlanArrivalConsumeInput = {
        isDialogOpen: false,
        currentPlanId: 47,
        events: [eventCQ(4701, 1, EventEntity.STATE_PENDING, 0, 0)],
        onShow: (payload: ArrivalReminderPayload): void => {
          shownEventId = payload.eventId;
        }
      };
      // Act
      coordinator.consumeOnPlan(input);
      const expired = privateApi.isTerminalStatus(PlanStatus.EXPIRED);
      const paused = privateApi.isTerminalStatus(PlanStatus.PAUSED);
      hooks.restore();
      // Assert
      expect(shownEventId).assertEqual(4701);
      expect(expired).assertTrue();
      expect(paused).assertFalse();
    });
  });
}
