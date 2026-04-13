import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { ArrivalReminderCoordinator } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';

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
  });
}
