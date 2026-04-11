import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';
import {
  getCompanionRuntimeDescription,
  getCompanionRuntimeLabel
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

function buildEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.duration = 30;
  event.fixed_start_time = '';
  event.computed_time = '';
  event.dynamic_start_time = 0;
  event.dynamic_end_time = 0;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

function buildContext(
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP',
  currentEvent: EventEntity | null,
  nextEvent: EventEntity | null
): CompanionContext {
  return {
    runtimeState: runtimeState,
    currentEvent: currentEvent,
    nextEvent: nextEvent,
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

export default function companionDisplayHelperRuntimeDescriptionTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperRuntimeDescription', () => {
    it('normal: runtime_labels_should_distinguish_ready_active_paused_and_gap', 0, () => {
      // Arrange
      const ready = getCompanionRuntimeLabel('READY');
      const active = getCompanionRuntimeLabel('ACTIVE');
      const paused = getCompanionRuntimeLabel('PAUSED');
      const gap = getCompanionRuntimeLabel('GAP');

      // Act
      const allNonEmpty = ready.length > 0 && active.length > 0 && paused.length > 0 && gap.length > 0;

      // Assert
      expect(allNonEmpty).assertTrue();
      expect(ready === active).assertFalse();
      expect(active === paused).assertFalse();
      expect(paused === gap).assertFalse();
    });

    it('boundary: ready_description_should_switch_between_overdue_and_immediate_at_one_minute_threshold', 0, () => {
      // Arrange
      const nowTs = Date.now();
      const overdueEvent = buildEvent(1, 'overdue');
      overdueEvent.dynamic_start_time = nowTs - 2 * 60000;
      const immediateEvent = buildEvent(2, 'immediate');
      immediateEvent.dynamic_start_time = nowTs - 60000;
      const overdueContext = buildContext('READY', overdueEvent, null);
      const immediateContext = buildContext('READY', immediateEvent, null);

      // Act
      const overdueText = getCompanionRuntimeDescription(overdueContext, nowTs);
      const immediateText = getCompanionRuntimeDescription(immediateContext, nowTs);

      // Assert
      expect(overdueText.length > 0).assertTrue();
      expect(immediateText.length > 0).assertTrue();
      expect(/\d+/.test(overdueText)).assertTrue();
      expect(/\d+/.test(immediateText)).assertFalse();
      expect(overdueText === immediateText).assertFalse();
    });

    it('invalid: unknown_runtime_without_next_event_should_fallback_to_idle_description', 0, () => {
      // Arrange
      const context = buildContext('IDLE', null, null);
      const nowTs = Date.now();

      // Act
      const description = getCompanionRuntimeDescription(context, nowTs);

      // Assert
      expect(description.length > 0).assertTrue();
    });

    it('conflict: active_runtime_description_should_take_priority_over_next_event_hint', 0, () => {
      // Arrange
      const current = buildEvent(3, 'active-now');
      current.actual_start_time = Date.now() - 120000;
      const next = buildEvent(4, 'next-stop');
      const context = buildContext('ACTIVE', current, next);

      // Act
      const description = getCompanionRuntimeDescription(context, Date.now());

      // Assert
      expect(description.length > 0).assertTrue();
      expect(description.includes('next-stop')).assertFalse();
    });

    it('regression: paused_runtime_description_should_remain_stable_and_ignore_next_event_name', 0, () => {
      // Arrange
      const current = buildEvent(5, 'pause-now');
      const next = buildEvent(6, 'next-paused');
      const context = buildContext('PAUSED', current, next);

      // Act
      const description = getCompanionRuntimeDescription(context, Date.now());

      // Assert
      expect(description.length > 0).assertTrue();
      expect(description.includes('next-paused')).assertFalse();
    });

    it('combined: gap_and_idle_with_next_event_should_both_reference_next_event_name', 0, () => {
      // Arrange
      const next = buildEvent(7, 'museum-stop');
      const gapContext = buildContext('GAP', null, next);
      const idleContext = buildContext('IDLE', null, next);

      // Act
      const gapDescription = getCompanionRuntimeDescription(gapContext, Date.now());
      const idleDescription = getCompanionRuntimeDescription(idleContext, Date.now());

      // Assert
      expect(gapDescription.includes('museum-stop')).assertTrue();
      expect(idleDescription.includes('museum-stop')).assertTrue();
      expect(gapDescription.length > 0).assertTrue();
      expect(idleDescription.length > 0).assertTrue();
    });
  });
}
