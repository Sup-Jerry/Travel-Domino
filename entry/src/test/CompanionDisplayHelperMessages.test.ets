import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { SoftReplanApplyResult, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import {
  buildCompanionExecutionSuggestionExplanation,
  buildCompanionReplanToastMessage,
  getCompanionForecastStartText,
  getCompanionMainCardTimeText,
  getCompanionPlannedRange,
  getCompanionRuntimeDescription,
  getCompanionTimelineSupplement,
  getCompanionWeatherScoreSummary
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';

type ReplanErrorCode = '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY';

function buildEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
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

function buildSuggestion(id: string, actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE'): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title-${id}`,
    message: 'msg',
    relatedNodeIds: ['node-1'],
    createdAt: Date.now(),
    reason: '',
    expectedBenefit: '',
    canRollback: false,
    cooldownKey: `cool-${id}`,
    expiresAt: Date.now() + 60000
  };
}

function buildResult(success: boolean, errorCode: ReplanErrorCode, summary: string): SoftReplanApplyResult {
  return {
    success: success,
    rolledBack: errorCode === 'REPLAN_CONFLICT',
    errorCode: errorCode,
    reasonCode: '',
    preview: {
      suggestionId: 's-1',
      actionType: 'REORDER',
      changedOrder: success,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: summary,
      riskDelta: success ? -1 : 0
    }
  };
}

function buildReadyContext(currentEvent: EventEntity | null): CompanionContext {
  return {
    runtimeState: 'READY',
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

export default function companionDisplayHelperMessagesTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperMessages', () => {
    it('normal: timeline_supplement_should_include_elapsed_minutes_for_active_event', 0, () => {
      // Arrange
      const event = buildEvent(1);
      event.actual_start_time = Date.now() - 10 * 60000;

      // Act
      const supplement = getCompanionTimelineSupplement(event);

      // Assert
      expect(supplement.includes('|')).assertTrue();
      expect(/\d+/.test(supplement)).assertTrue();
    });

    it('boundary: weather_score_summary_should_use_invalid_bucket_for_nan_and_negative', 0, () => {
      // Arrange
      const scoreNaN = Number.NaN;
      const scoreNegative = -1;

      // Act
      const textNaN = getCompanionWeatherScoreSummary(scoreNaN);
      const textNegative = getCompanionWeatherScoreSummary(scoreNegative);

      // Assert
      expect(textNaN.length > 0).assertTrue();
      expect(textNaN).assertEqual(textNegative);
    });

    it('invalid: execution_explanation_should_fallback_when_reason_and_benefit_are_empty', 0, () => {
      // Arrange
      const suggestion = buildSuggestion('invalid', 'NONE');

      // Act
      const text = buildCompanionExecutionSuggestionExplanation(suggestion);

      // Assert
      expect(text.includes('title-invalid')).assertTrue();
      expect(text.includes('\n')).assertTrue();
      expect(text.length > 20).assertTrue();
    });

    it('conflict: replan_conflict_messages_should_differ_by_reason_code', 0, () => {
      // Arrange
      const applyFailed = buildResult(false, 'REPLAN_CONFLICT', '');
      applyFailed.reasonCode = 'apply_failed';
      const genericConflict = buildResult(false, 'REPLAN_CONFLICT', '');
      genericConflict.reasonCode = '';

      // Act
      const applyFailedMessage = buildCompanionReplanToastMessage(applyFailed);
      const genericMessage = buildCompanionReplanToastMessage(genericConflict);

      // Assert
      expect(applyFailedMessage.length > 0).assertTrue();
      expect(genericMessage.length > 0).assertTrue();
      expect(applyFailedMessage === genericMessage).assertFalse();
    });

    it('regression: success_replan_message_should_prefer_preview_summary_then_fallback', 0, () => {
      // Arrange
      const withSummary = buildResult(true, '', 'apply-ok');
      const withoutSummary = buildResult(true, '', '');

      // Act
      const withSummaryMessage = buildCompanionReplanToastMessage(withSummary);
      const withoutSummaryMessage = buildCompanionReplanToastMessage(withoutSummary);

      // Assert
      expect(withSummaryMessage).assertEqual('apply-ok');
      expect(withoutSummaryMessage.length > 0).assertTrue();
      expect(withoutSummaryMessage === withSummaryMessage).assertFalse();
    });

    it('combined: planned_main_and_forecast_text_should_stay_consistent_in_ready_runtime_flow', 0, () => {
      // Arrange
      const event = buildEvent(6);
      event.computed_time = '14:20';
      event.duration = 40;
      event.dynamic_start_time = new Date(2026, 2, 8, 10, 5, 0, 0).getTime();
      const nowTs = event.dynamic_start_time + 6 * 60000;
      const context = buildReadyContext(event);

      // Act
      const plannedRange = getCompanionPlannedRange(event);
      const mainCardTime = getCompanionMainCardTimeText(event);
      const forecastStart = getCompanionForecastStartText(event);
      const runtimeDescription = getCompanionRuntimeDescription(context, nowTs);

      // Assert
      expect(plannedRange).assertEqual('14:20-15:00');
      expect(mainCardTime).assertEqual(plannedRange);
      expect(forecastStart).assertEqual('10:05');
      expect(runtimeDescription.length > 0).assertTrue();
      expect(runtimeDescription.includes('6')).assertTrue();
    });
  });
}
