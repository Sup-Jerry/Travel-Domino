import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { getCompanionEventState } from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

function buildEvent(
  id: number,
  status: number = 1,
  completionStatus: number = EventEntity.STATE_PENDING,
  actualStart: number = 0,
  actualEnd: number = 0
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = status;
  event.completion_status = completionStatus;
  event.actual_start_time = actualStart;
  event.actual_end_time = actualEnd;
  event.duration = 60;
  event.fixed_start_time = '10:00';
  event.computed_time = '10:00';
  return event;
}

export default function companionDisplayHelperEventStateTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperEventState', () => {
    it('normal: event_state_should_return_pending_for_scheduled_pending_event', 0, () => {
      // Arrange
      const event = buildEvent(1);

      // Act
      const state = getCompanionEventState(event);

      // Assert
      expect(state).assertEqual('PENDING');
    });

    it('boundary: event_state_should_return_active_when_started_but_not_ended', 0, () => {
      // Arrange
      const now = Date.now();
      const event = buildEvent(2, 1, EventEntity.STATE_PENDING, now - 5 * 60 * 1000, 0);

      // Act
      const state = getCompanionEventState(event);

      // Assert
      expect(state).assertEqual('ACTIVE');
    });

    it('invalid: event_state_should_fallback_to_pending_for_backlog_item', 0, () => {
      // Arrange
      const backlogEvent = buildEvent(3, 0, EventEntity.STATE_PENDING, 0, 0);

      // Act
      const state = getCompanionEventState(backlogEvent);

      // Assert
      expect(state).assertEqual('PENDING');
    });

    it('conflict: event_state_should_prioritize_completed_over_runtime_timestamps', 0, () => {
      // Arrange
      const event = buildEvent(4, 1, EventEntity.STATE_COMPLETED, Date.now() - 60 * 60 * 1000, 0);

      // Act
      const state = getCompanionEventState(event);

      // Assert
      expect(state).assertEqual('COMPLETED');
    });

    it('regression: event_state_should_keep_skipped_priority_over_active_shape', 0, () => {
      // Arrange
      const event = buildEvent(5, 1, EventEntity.STATE_SKIPPED, Date.now() - 30 * 60 * 1000, 0);

      // Act
      const state = getCompanionEventState(event);

      // Assert
      expect(state).assertEqual('SKIPPED');
    });

    it('combined: event_state_matrix_should_cover_four_display_states', 0, () => {
      // Arrange
      const now = Date.now();
      const matrix: EventEntity[] = [
        buildEvent(11),
        buildEvent(12, 1, EventEntity.STATE_PENDING, now - 60000, 0),
        buildEvent(13, 1, EventEntity.STATE_COMPLETED, now - 3600000, now - 1800000),
        buildEvent(14, 1, EventEntity.STATE_SKIPPED, 0, 0)
      ];

      // Act
      const states = matrix.map((item) => getCompanionEventState(item));

      // Assert
      expect(states.length).assertEqual(4);
      expect(states[0]).assertEqual('PENDING');
      expect(states[1]).assertEqual('ACTIVE');
      expect(states[2]).assertEqual('COMPLETED');
      expect(states[3]).assertEqual('SKIPPED');
    });
  });
}
