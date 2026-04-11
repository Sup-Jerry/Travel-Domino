import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  canCompanionEndFocused,
  canCompanionStartFocused,
  isCompanionCurrentEventActive,
  isCompanionCurrentEventPending
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';

function buildEvent(id: number, state: 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED'): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  event.dynamic_start_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 60000;
  } else if (state === 'COMPLETED') {
    event.completion_status = EventEntity.STATE_COMPLETED;
    event.actual_start_time = Date.now() - 3600000;
    event.actual_end_time = Date.now() - 1800000;
  } else if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

function buildContext(current: EventEntity | null, canEnd: boolean = true): CompanionContext {
  return {
    runtimeState: 'ACTIVE',
    currentEvent: current,
    nextEvent: null,
    hint: null,
    actions: {
      canStart: true,
      canPause: true,
      canResume: true,
      canEnd: canEnd,
      canSkip: true,
      canNavigate: true,
      canViewDetail: true
    }
  };
}

export default function companionDisplayHelperStateGuardsTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperStateGuards', () => {
    it('normal: start_focused_should_allow_pending_without_other_active_events', 0, () => {
      // Arrange
      const focused = buildEvent(1, 'PENDING');
      const schedule: EventEntity[] = [focused, buildEvent(2, 'COMPLETED')];

      // Act
      const canStart = canCompanionStartFocused(focused, schedule);

      // Assert
      expect(canStart).assertTrue();
    });

    it('boundary: end_focused_should_allow_when_current_matches_focused_and_permission_enabled', 0, () => {
      // Arrange
      const focused = buildEvent(3, 'ACTIVE');
      const context = buildContext(focused, true);

      // Act
      const canEnd = canCompanionEndFocused(focused, context);

      // Assert
      expect(canEnd).assertTrue();
    });

    it('invalid: start_focused_should_reject_non_pending_event_states', 0, () => {
      // Arrange
      const completed = buildEvent(4, 'COMPLETED');
      const skipped = buildEvent(5, 'SKIPPED');
      const schedule: EventEntity[] = [completed, skipped];

      // Act
      const completedResult = canCompanionStartFocused(completed, schedule);
      const skippedResult = canCompanionStartFocused(skipped, schedule);

      // Assert
      expect(completedResult).assertFalse();
      expect(skippedResult).assertFalse();
    });

    it('conflict: end_focused_should_reject_when_context_current_event_id_mismatches', 0, () => {
      // Arrange
      const focused = buildEvent(6, 'ACTIVE');
      const anotherActive = buildEvent(7, 'ACTIVE');
      const context = buildContext(anotherActive, true);

      // Act
      const canEnd = canCompanionEndFocused(focused, context);

      // Assert
      expect(canEnd).assertFalse();
    });

    it('regression: pending_and_active_checks_should_not_be_true_at_the_same_time', 0, () => {
      // Arrange
      const pendingContext = buildContext(buildEvent(8, 'PENDING'));
      const activeContext = buildContext(buildEvent(9, 'ACTIVE'));

      // Act
      const pendingIsPending = isCompanionCurrentEventPending(pendingContext);
      const pendingIsActive = isCompanionCurrentEventActive(pendingContext);
      const activeIsPending = isCompanionCurrentEventPending(activeContext);
      const activeIsActive = isCompanionCurrentEventActive(activeContext);

      // Assert
      expect(pendingIsPending).assertTrue();
      expect(pendingIsActive).assertFalse();
      expect(activeIsPending).assertFalse();
      expect(activeIsActive).assertTrue();
    });

    it('combined: start_and_end_guards_should_switch_after_event_state_transitions_to_active', 0, () => {
      // Arrange
      const focused = buildEvent(10, 'PENDING');
      const schedule: EventEntity[] = [focused];
      const context = buildContext(focused, true);

      // Act
      const beforeStart = canCompanionStartFocused(focused, schedule);
      const beforeEnd = canCompanionEndFocused(focused, context);
      focused.actual_start_time = Date.now() - 120000;
      const afterStart = canCompanionStartFocused(focused, schedule);
      const afterEnd = canCompanionEndFocused(focused, context);

      // Assert
      expect(beforeStart).assertTrue();
      expect(beforeEnd).assertFalse();
      expect(afterStart).assertFalse();
      expect(afterEnd).assertTrue();
    });
  });
}
