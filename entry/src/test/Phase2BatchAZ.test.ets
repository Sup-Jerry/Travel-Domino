import { describe, it, expect } from '@ohos/hypium';
import { WeatherSuggestion, WeatherSuggestionActionType } from '../main/ets/domain/services/WeatherModels';
import {
  getCompanionDismissSuggestionToast,
  getCompanionWeatherGuidePopupText,
  getCompanionWeatherSuggestionDetailText
} from '../main/ets/pages/components/views/companion/CompanionWeatherActionHelper';
import {
  canPlanItemShowConflictFixButton,
  resolvePlanItemTimeText,
  shouldPlanItemShowCrossDayLabel
} from '../main/ets/pages/components/views/PlanItemView';
import {
  getBacklogBadgeText,
  getBacklogExpandSymbol,
  shouldShowBacklogEmptyState,
  shouldShowBacklogMoveAllButton
} from '../main/ets/pages/components/views/BacklogView';

function buildWeatherSuggestionAZ(id: string, actionType: WeatherSuggestionActionType): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: actionType,
    title: `title-${id}`,
    message: `message-${id}`,
    relatedNodeIds: ['node-1'],
    createdAt: 1710000000000,
    reason: `reason-${id}`,
    expectedBenefit: `benefit-${id}`,
    canRollback: true,
    cooldownKey: `cooldown-${id}`,
    expiresAt: 1710000060000
  };
}

export default function phase2BatchAZTest() {
  describe('phase2BatchAZTest', () => {
    // CompanionFocusActionHelper only exports side-effect orchestration methods, so this pure-logic batch excludes it.

    it('normal: plan_item_pure_helpers_should_handle_standard_values', 0, () => {
      // Arrange
      const computedStartTime = '04-17 09:00';
      const timeText = '09:00';
      const isConflict = true;
      const suggestedShiftMinutes = 15;

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(computedStartTime);
      const displayText = resolvePlanItemTimeText(timeText);
      const canShowFixButton = canPlanItemShowConflictFixButton(isConflict, suggestedShiftMinutes);

      // Assert
      expect(crossDay).assertTrue();
      expect(displayText).assertEqual('09:00');
      expect(canShowFixButton).assertTrue();
    });

    it('boundary: plan_item_pure_helpers_should_keep_placeholder_and_zero_shift_rules', 0, () => {
      // Arrange
      const computedStartTime = '';
      const timeText = '--:--';
      const isConflict = true;
      const suggestedShiftMinutes = 0;

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(computedStartTime);
      const displayText = resolvePlanItemTimeText(timeText);
      const canShowFixButton = canPlanItemShowConflictFixButton(isConflict, suggestedShiftMinutes);

      // Assert
      expect(crossDay).assertFalse();
      expect(displayText).assertEqual('--:--');
      expect(canShowFixButton).assertFalse();
    });

    it('invalid: plan_item_pure_helpers_should_use_current_fallbacks_for_malformed_inputs', 0, () => {
      // Arrange
      const malformedComputedStartTime = '-';
      const emptyTimeText = '';
      const negativeShiftMinutes = -5;

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(malformedComputedStartTime);
      const displayText = resolvePlanItemTimeText(emptyTimeText);
      const canShowFixButton = canPlanItemShowConflictFixButton(true, negativeShiftMinutes);

      // Assert
      expect(crossDay).assertTrue();
      expect(displayText).assertEqual('--:--');
      expect(canShowFixButton).assertFalse();
    });

    it('normal: backlog_pure_helpers_should_handle_expanded_non_empty_state', 0, () => {
      // Arrange
      const isExpanded = true;
      const itemCount = 3;

      // Act
      const expandSymbol = getBacklogExpandSymbol(isExpanded);
      const showMoveAllButton = shouldShowBacklogMoveAllButton(itemCount);
      const showEmptyState = shouldShowBacklogEmptyState(isExpanded, itemCount);
      const badgeText = getBacklogBadgeText(itemCount);

      // Assert
      expect(expandSymbol).assertEqual('\u25BC');
      expect(showMoveAllButton).assertTrue();
      expect(showEmptyState).assertFalse();
      expect(badgeText).assertEqual('3');
    });

    it('boundary: backlog_pure_helpers_should_handle_collapsed_or_zero_item_cases', 0, () => {
      // Arrange
      const isExpanded = false;
      const emptyItemCount = 0;

      // Act
      const expandSymbol = getBacklogExpandSymbol(isExpanded);
      const showMoveAllButton = shouldShowBacklogMoveAllButton(emptyItemCount);
      const showEmptyState = shouldShowBacklogEmptyState(true, emptyItemCount);
      const badgeText = getBacklogBadgeText(emptyItemCount);

      // Assert
      expect(expandSymbol).assertEqual('\u25B6');
      expect(showMoveAllButton).assertFalse();
      expect(showEmptyState).assertTrue();
      expect(badgeText).assertEqual('0');
    });

    it('invalid: backlog_pure_helpers_should_treat_negative_counts_as_non_actionable', 0, () => {
      // Arrange
      const rawExpanded: Object | undefined = undefined;
      const negativeItemCount = -2;

      // Act
      const expandSymbol = getBacklogExpandSymbol(!!rawExpanded);
      const showMoveAllButton = shouldShowBacklogMoveAllButton(negativeItemCount);
      const showEmptyState = shouldShowBacklogEmptyState(true, negativeItemCount);
      const badgeText = getBacklogBadgeText(negativeItemCount);

      // Assert
      expect(expandSymbol).assertEqual('\u25B6');
      expect(showMoveAllButton).assertFalse();
      expect(showEmptyState).assertFalse();
      expect(badgeText).assertEqual('-2');
    });

    it('normal: companion_weather_pure_helpers_should_build_readable_texts_for_standard_input', 0, () => {
      // Arrange
      const suggestion = buildWeatherSuggestionAZ('normal', 'REORDER');

      // Act
      const guideText = getCompanionWeatherGuidePopupText();
      const detailText = getCompanionWeatherSuggestionDetailText(suggestion);
      const dismissToast = getCompanionDismissSuggestionToast('later');

      // Assert
      expect(guideText.length > 20).assertTrue();
      expect(guideText.includes('\n')).assertTrue();
      expect(detailText.includes(suggestion.title)).assertTrue();
      expect(detailText.includes(suggestion.reason)).assertTrue();
      expect(detailText.includes(suggestion.expectedBenefit)).assertTrue();
      expect(dismissToast.length > 0).assertTrue();
    });

    it('boundary: companion_weather_pure_helpers_should_keep_stable_output_for_repeat_and_blank_optional_fields', 0, () => {
      // Arrange
      const suggestion = buildWeatherSuggestionAZ('boundary', 'PREPARE');
      suggestion.reason = '   ';
      suggestion.expectedBenefit = '   ';

      // Act
      const firstGuideText = getCompanionWeatherGuidePopupText();
      const secondGuideText = getCompanionWeatherGuidePopupText();
      const detailText = getCompanionWeatherSuggestionDetailText(suggestion);
      const laterToast = getCompanionDismissSuggestionToast('later');
      const ignoreToast = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(firstGuideText).assertEqual(secondGuideText);
      expect(detailText.includes(suggestion.title)).assertTrue();
      expect(detailText.length > suggestion.title.length).assertTrue();
      expect(detailText.includes('undefined')).assertFalse();
      expect(ignoreToast.length > 0).assertTrue();
      expect(ignoreToast === laterToast).assertFalse();
    });

    it('invalid: companion_weather_pure_helpers_should_fallback_cleanly_for_unknown_mode_and_action_type', 0, () => {
      // Arrange
      const suggestion = buildWeatherSuggestionAZ('invalid', 'NONE');
      suggestion.actionType = 'UNSUPPORTED' as WeatherSuggestionActionType;
      suggestion.reason = '';
      suggestion.expectedBenefit = '';
      suggestion.canRollback = false;
      const unknownMode = 'unexpected' as 'later' | 'ignore';

      // Act
      const guideText = getCompanionWeatherGuidePopupText();
      const detailText = getCompanionWeatherSuggestionDetailText(suggestion);
      const unknownToast = getCompanionDismissSuggestionToast(unknownMode);
      const ignoreToast = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(guideText.includes('undefined')).assertFalse();
      expect(guideText.includes('null')).assertFalse();
      expect(detailText.includes(suggestion.title)).assertTrue();
      expect(detailText.length > 0).assertTrue();
      expect(detailText.includes('undefined')).assertFalse();
      expect(unknownToast).assertEqual(ignoreToast);
    });

    it('conflict: pure_helpers_should_keep_conflict_fix_empty_state_and_detail_text_rules_separate', 0, () => {
      // Arrange
      const suggestion = buildWeatherSuggestionAZ('conflict', 'SHORTEN_STAY');
      const isConflict = true;
      const suggestedShiftMinutes = 25;
      const backlogExpanded = true;
      const backlogItemCount = 1;

      // Act
      const canShowFixButton = canPlanItemShowConflictFixButton(isConflict, suggestedShiftMinutes);
      const showEmptyState = shouldShowBacklogEmptyState(backlogExpanded, backlogItemCount);
      const detailText = getCompanionWeatherSuggestionDetailText(suggestion);

      // Assert
      expect(canShowFixButton).assertTrue();
      expect(showEmptyState).assertFalse();
      expect(detailText.includes(suggestion.title)).assertTrue();
      expect(detailText.includes(suggestion.expectedBenefit)).assertTrue();
    });

    it('regression: td-20260417_phase2_batch_az_plain_time_zero_badge_and_unknown_dismiss_fallback_should_stay_stable', 0, () => {
      // Arrange
      const unknownMode = 'unexpected' as 'later' | 'ignore';

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel('09:30');
      const badgeText = getBacklogBadgeText(0);
      const unknownToast = getCompanionDismissSuggestionToast(unknownMode);
      const ignoreToast = getCompanionDismissSuggestionToast('ignore');

      // Assert
      expect(crossDay).assertFalse();
      expect(badgeText).assertEqual('0');
      expect(unknownToast).assertEqual(ignoreToast);
    });

    it('combined: pure_helpers_should_keep_plan_backlog_and_weather_outputs_independent', 0, () => {
      // Arrange
      const suggestion = buildWeatherSuggestionAZ('combined', 'REPLACE_NODE');

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel('05-01 08:00');
      const displayText = resolvePlanItemTimeText('');
      const expandSymbol = getBacklogExpandSymbol(true);
      const showMoveAllButton = shouldShowBacklogMoveAllButton(2);
      const guideText = getCompanionWeatherGuidePopupText();
      const detailText = getCompanionWeatherSuggestionDetailText(suggestion);

      // Assert
      expect(crossDay).assertTrue();
      expect(displayText).assertEqual('--:--');
      expect(expandSymbol).assertEqual('\u25BC');
      expect(showMoveAllButton).assertTrue();
      expect(guideText.length > 20).assertTrue();
      expect(detailText.includes(suggestion.title)).assertTrue();
    });
  });
}
