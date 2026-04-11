import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';
import {
  getCompanionFilterLabel,
  getCompanionRuntimeDescription,
  getCompanionRuntimeLabel,
  getCompanionWeatherScoreSummary
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';

function buildEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  event.dynamic_start_time = 0;
  event.dynamic_end_time = 0;
  return event;
}

function buildContext(runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP', nextEvent: EventEntity | null): CompanionContext {
  return {
    runtimeState: runtimeState,
    currentEvent: null,
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

export default function companionDisplayHelperFallbackModesTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperFallbackModes', () => {
    it('normal: runtime_label_should_return_idle_for_unknown_state', 0, () => {
      // Arrange
      const unknownState = 'UNKNOWN_STATE';

      // Act
      const unknownLabel = getCompanionRuntimeLabel(unknownState);
      const idleLabel = getCompanionRuntimeLabel('IDLE');

      // Assert
      expect(unknownLabel).assertEqual(idleLabel);
      expect(unknownLabel.length > 0).assertTrue();
    });

    it('boundary: score_summary_should_switch_bucket_exactly_at_70_and_85', 0, () => {
      // Arrange
      const belowMid = 69;
      const atMid = 70;
      const belowHigh = 84;
      const atHigh = 85;

      // Act
      const text69 = getCompanionWeatherScoreSummary(belowMid);
      const text70 = getCompanionWeatherScoreSummary(atMid);
      const text84 = getCompanionWeatherScoreSummary(belowHigh);
      const text85 = getCompanionWeatherScoreSummary(atHigh);

      // Assert
      expect(text69 === text70).assertFalse();
      expect(text84 === text85).assertFalse();
      expect(text70.includes('70')).assertTrue();
      expect(text84.includes('84')).assertTrue();
    });

    it('invalid: filter_label_should_fallback_to_skipped_branch_for_unknown_state_cast', 0, () => {
      // Arrange
      const unknownFilter = 'UNKNOWN_FILTER' as 'ALL' | 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED';

      // Act
      const unknownLabel = getCompanionFilterLabel(unknownFilter);
      const skippedLabel = getCompanionFilterLabel('SKIPPED');

      // Assert
      expect(unknownLabel).assertEqual(skippedLabel);
      expect(unknownLabel.length > 0).assertTrue();
    });

    it('conflict: runtime_description_should_prioritize_paused_message_over_next_event_hint', 0, () => {
      // Arrange
      const next = buildEvent(1, 'museum');
      const pausedContext = buildContext('PAUSED', next);

      // Act
      const description = getCompanionRuntimeDescription(pausedContext, Date.now());

      // Assert
      expect(description.length > 0).assertTrue();
      expect(description.includes('museum')).assertFalse();
    });

    it('regression: idle_without_next_event_should_keep_stable_default_description', 0, () => {
      // Arrange
      const context = buildContext('IDLE', null);

      // Act
      const description = getCompanionRuntimeDescription(context, Date.now());

      // Assert
      expect(description.length > 0).assertTrue();
    });

    it('combined: unknown_runtime_label_and_idle_with_next_event_should_share_fallback_path', 0, () => {
      // Arrange
      const next = buildEvent(2, 'station');
      const context = buildContext('IDLE', next);

      // Act
      const unknownRuntimeLabel = getCompanionRuntimeLabel('INVALID_RUNTIME');
      const idleRuntimeLabel = getCompanionRuntimeLabel('IDLE');
      const description = getCompanionRuntimeDescription(context, Date.now());

      // Assert
      expect(unknownRuntimeLabel).assertEqual(idleRuntimeLabel);
      expect(description.includes('station')).assertTrue();
      expect(description.length > 0).assertTrue();
    });
  });
}
