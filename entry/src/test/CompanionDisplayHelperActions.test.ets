import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  canCompanionEndFocused,
  getCompanionEventStateLabel,
  getCompanionFilterLabel,
  getCompanionRuntimeDescription,
  getCompanionRuntimeLabel,
  getCompanionStateTagBackgroundColor,
  hasCompanionOtherActiveEvent,
  isCompanionCurrentEventPending,
  matchesCompanionFilter
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

function buildContext(runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP', current: EventEntity | null): CompanionContext {
  return {
    runtimeState: runtimeState,
    currentEvent: current,
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

export default function companionDisplayHelperActionsTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperActions', () => {
    it('normal: matches_filter_should_accept_all_and_exact_state', 0, () => {
      // Arrange
      const active = buildEvent(1, 'ACTIVE');

      // Act
      const allMatched = matchesCompanionFilter(active, 'ALL');
      const activeMatched = matchesCompanionFilter(active, 'ACTIVE');

      // Assert
      expect(allMatched).assertTrue();
      expect(activeMatched).assertTrue();
    });

    it('boundary: runtime_and_state_labels_should_be_non_empty_across_known_and_unknown_values', 0, () => {
      // Arrange
      const active = buildEvent(2, 'ACTIVE');
      const pending = buildEvent(3, 'PENDING');

      // Act
      const knownRuntimeLabel = getCompanionRuntimeLabel('ACTIVE');
      const unknownRuntimeLabel = getCompanionRuntimeLabel('UNKNOWN');
      const activeStateLabel = getCompanionEventStateLabel(active);
      const pendingStateLabel = getCompanionEventStateLabel(pending);
      const allFilterLabel = getCompanionFilterLabel('ALL');
      const skippedFilterLabel = getCompanionFilterLabel('SKIPPED');

      // Assert
      expect(knownRuntimeLabel.length > 0).assertTrue();
      expect(unknownRuntimeLabel.length > 0).assertTrue();
      expect(activeStateLabel.length > 0).assertTrue();
      expect(pendingStateLabel.length > 0).assertTrue();
      expect(allFilterLabel.length > 0).assertTrue();
      expect(skippedFilterLabel.length > 0).assertTrue();
      expect(activeStateLabel === pendingStateLabel).assertFalse();
    });

    it('invalid: end_focused_should_fail_when_permission_or_current_event_is_missing', 0, () => {
      // Arrange
      const active = buildEvent(4, 'ACTIVE');
      const noCurrent = buildContext('ACTIVE', null);
      const noPermission = buildContext('ACTIVE', active);
      noPermission.actions.canEnd = false;

      // Act
      const noCurrentResult = canCompanionEndFocused(active, noCurrent);
      const noPermissionResult = canCompanionEndFocused(active, noPermission);

      // Assert
      expect(noCurrentResult).assertFalse();
      expect(noPermissionResult).assertFalse();
    });

    it('conflict: other_active_event_should_be_detected_except_for_excluded_id', 0, () => {
      // Arrange
      const focused = buildEvent(5, 'ACTIVE');
      const pending = buildEvent(6, 'PENDING');
      const otherActive = buildEvent(7, 'ACTIVE');
      const scheduleWithoutConflict: EventEntity[] = [focused, pending];
      const scheduleWithConflict: EventEntity[] = [focused, pending, otherActive];

      // Act
      const noConflict = hasCompanionOtherActiveEvent(scheduleWithoutConflict, focused.id);
      const hasConflict = hasCompanionOtherActiveEvent(scheduleWithConflict, focused.id);

      // Assert
      expect(noConflict).assertFalse();
      expect(hasConflict).assertTrue();
    });

    it('regression: state_tag_background_color_should_keep_stable_mapping', 0, () => {
      // Arrange
      const active = buildEvent(8, 'ACTIVE');
      const completed = buildEvent(9, 'COMPLETED');
      const skipped = buildEvent(10, 'SKIPPED');
      const pending = buildEvent(11, 'PENDING');

      // Act
      const activeColor = getCompanionStateTagBackgroundColor(active);
      const completedColor = getCompanionStateTagBackgroundColor(completed);
      const skippedColor = getCompanionStateTagBackgroundColor(skipped);
      const pendingColor = getCompanionStateTagBackgroundColor(pending);

      // Assert
      expect(activeColor as string).assertEqual('#E9F8F1');
      expect(completedColor as string).assertEqual('#EAF7EE');
      expect(skippedColor as string).assertEqual('#FFF4E7');
      expect(pendingColor as string).assertEqual('#EAF2FF');
    });

    it('combined: pending_context_should_block_end_action_and_keep_runtime_description_available', 0, () => {
      // Arrange
      const nowTs = Date.now();
      const pending = buildEvent(12, 'PENDING');
      pending.dynamic_start_time = nowTs - 5 * 60000;
      const context = buildContext('READY', pending);

      // Act
      const currentPending = isCompanionCurrentEventPending(context);
      const canEndPending = canCompanionEndFocused(pending, context);
      const description = getCompanionRuntimeDescription(context, nowTs);

      // Assert
      expect(currentPending).assertTrue();
      expect(canEndPending).assertFalse();
      expect(description.length > 0).assertTrue();
    });
  });
}
