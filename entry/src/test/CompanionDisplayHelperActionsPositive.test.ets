import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';
import {
  canCompanionEndFocused,
  canCompanionStartFocused,
  hasCompanionOtherActiveEvent,
  isCompanionCurrentEventActive,
  isCompanionCurrentEventPending,
  matchesCompanionFilter
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

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

function buildContext(currentEvent: EventEntity | null): CompanionContext {
  return {
    runtimeState: 'ACTIVE',
    currentEvent: currentEvent,
    nextEvent: null,
    hint: null,
    actions: {
      canStart: true,
      canPause: true,
      canResume: true,
      canEnd: true,
      canSkip: true,
      canNavigate: true,
      canViewDetail: true
    }
  };
}

export default function companionDisplayHelperActionsPositiveTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperActionsPositive', () => {
    it('normal: start_focused_should_allow_pending_event_when_no_other_active_exists', 0, () => {
      // Arrange
      const focused = buildEvent(1, 'PENDING');
      const pending2 = buildEvent(2, 'PENDING');
      const schedule: EventEntity[] = [focused, pending2];

      // Act
      const canStart = canCompanionStartFocused(focused, schedule);

      // Assert
      expect(canStart).assertTrue();
    });

    it('boundary: end_focused_should_allow_only_when_current_event_matches_and_can_end', 0, () => {
      // Arrange
      const focused = buildEvent(3, 'ACTIVE');
      const context = buildContext(focused);

      // Act
      const canEnd = canCompanionEndFocused(focused, context);

      // Assert
      expect(canEnd).assertTrue();
    });

    it('invalid: helper_should_return_false_for_pending_active_flags_when_current_event_is_null', 0, () => {
      // Arrange
      const context = buildContext(null);

      // Act
      const isPending = isCompanionCurrentEventPending(context);
      const isActive = isCompanionCurrentEventActive(context);

      // Assert
      expect(isPending).assertFalse();
      expect(isActive).assertFalse();
    });

    it('conflict: has_other_active_event_should_ignore_excluded_event_id_only', 0, () => {
      // Arrange
      const focused = buildEvent(4, 'ACTIVE');
      const sameAsFocused = buildEvent(4, 'ACTIVE');
      const anotherActive = buildEvent(5, 'ACTIVE');
      const scheduleSameOnly: EventEntity[] = [focused, sameAsFocused];
      const scheduleWithConflict: EventEntity[] = [focused, sameAsFocused, anotherActive];

      // Act
      const noConflict = hasCompanionOtherActiveEvent(scheduleSameOnly, focused.id);
      const hasConflict = hasCompanionOtherActiveEvent(scheduleWithConflict, focused.id);

      // Assert
      expect(noConflict).assertFalse();
      expect(hasConflict).assertTrue();
    });

    it('regression: matches_filter_should_keep_state_specific_matching_for_non_all_filters', 0, () => {
      // Arrange
      const active = buildEvent(6, 'ACTIVE');
      const pending = buildEvent(7, 'PENDING');

      // Act
      const activeMatched = matchesCompanionFilter(active, 'ACTIVE');
      const pendingMatchedByActive = matchesCompanionFilter(pending, 'ACTIVE');
      const pendingMatched = matchesCompanionFilter(pending, 'PENDING');

      // Assert
      expect(activeMatched).assertTrue();
      expect(pendingMatchedByActive).assertFalse();
      expect(pendingMatched).assertTrue();
    });

    it('combined: context_state_flags_and_actions_should_remain_consistent_when_current_event_switches', 0, () => {
      // Arrange
      const pending = buildEvent(8, 'PENDING');
      const active = buildEvent(9, 'ACTIVE');
      const pendingContext = buildContext(pending);
      const activeContext = buildContext(active);
      const schedule: EventEntity[] = [pending, active];

      // Act
      const pendingFlag = isCompanionCurrentEventPending(pendingContext);
      const activeFlag = isCompanionCurrentEventActive(activeContext);
      const canStartPending = canCompanionStartFocused(pending, schedule);
      const canEndActive = canCompanionEndFocused(active, activeContext);

      // Assert
      expect(pendingFlag).assertTrue();
      expect(activeFlag).assertTrue();
      expect(canStartPending).assertFalse();
      expect(canEndActive).assertTrue();
    });
  });
}
