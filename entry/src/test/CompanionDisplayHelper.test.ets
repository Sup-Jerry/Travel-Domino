import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  buildCompanionReplanToastMessage,
  canCompanionStartFocused,
  getCompanionFilterOptions,
  getCompanionRuntimeDescription,
  getCompanionStateCoreColor,
  getCompanionWeatherScoreSummary,
  isCompanionCurrentEventActive
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';
import { SoftReplanApplyResult } from '../main/ets/domain/services/WeatherModels';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';

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

function buildContext(runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP', current: EventEntity | null, next: EventEntity | null): CompanionContext {
  return {
    runtimeState: runtimeState,
    currentEvent: current,
    nextEvent: next,
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

function buildResult(success: boolean, errorCode: '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY', summary: string): SoftReplanApplyResult {
  return {
    success: success,
    rolledBack: errorCode === 'REPLAN_CONFLICT',
    errorCode: errorCode,
    reasonCode: '',
    preview: {
      suggestionId: 's1',
      actionType: 'REORDER',
      changedOrder: success,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: summary,
      riskDelta: 0
    }
  };
}

export default function companionDisplayHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelper', () => {
    it('normal: state_core_color_should_follow_event_runtime_state', 0, () => {
      // Arrange
      const active = buildEvent(1, 'ACTIVE');
      const palette = ThemeCenter.getPalette('light');

      // Act
      const actual = getCompanionStateCoreColor(active, palette);

      // Assert
      expect(actual as string).assertEqual(palette.success);
    });

    it('boundary: weather_score_summary_should_change_bucket_at_thresholds', 0, () => {
      // Arrange
      const scoreLow = 69;
      const scoreMid = 70;
      const scoreHigh = 85;

      // Act
      const low = getCompanionWeatherScoreSummary(scoreLow);
      const mid = getCompanionWeatherScoreSummary(scoreMid);
      const high = getCompanionWeatherScoreSummary(scoreHigh);

      // Assert
      expect(low === mid).assertFalse();
      expect(mid === high).assertFalse();
      expect(low.length > 0 && mid.length > 0 && high.length > 0).assertTrue();
    });

    it('invalid: replan_toast_should_return_invalid_message_for_missing_suggestion', 0, () => {
      // Arrange
      const result = buildResult(false, 'REPLAN_INVALID', '');
      result.reasonCode = 'suggestion_missing';

      // Act
      const message = buildCompanionReplanToastMessage(result);

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('conflict: start_focused_should_be_blocked_when_other_active_event_exists', 0, () => {
      // Arrange
      const focused = buildEvent(10, 'PENDING');
      const anotherActive = buildEvent(11, 'ACTIVE');
      const schedule: EventEntity[] = [focused, anotherActive];

      // Act
      const canStart = canCompanionStartFocused(focused, schedule);

      // Assert
      expect(canStart).assertFalse();
    });

    it('regression: filter_options_should_keep_stable_order_and_size', 0, () => {
      // Arrange
      const expectedFirst = 'ALL';
      const expectedLast = 'SKIPPED';

      // Act
      const options = getCompanionFilterOptions();

      // Assert
      expect(options.length).assertEqual(5);
      expect(options[0]).assertEqual(expectedFirst);
      expect(options[4]).assertEqual(expectedLast);
    });

    it('combined: runtime_description_and_active_state_guard_should_reflect_context', 0, () => {
      // Arrange
      const current = buildEvent(20, 'ACTIVE');
      const next = buildEvent(21, 'PENDING');
      next.name = 'next-stop';
      const gapContext = buildContext('GAP', current, next);

      // Act
      const description = getCompanionRuntimeDescription(gapContext, Date.now());
      const currentActive = isCompanionCurrentEventActive(gapContext);

      // Assert
      expect(description.includes('next-stop')).assertTrue();
      expect(currentActive).assertTrue();
    });
  });
}
