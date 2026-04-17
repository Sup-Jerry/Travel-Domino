import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  getCompanionControlCurrentEventId,
  resolveCompanionControlCardOpacity,
  resolveCompanionControlCardScale,
  resolveCompanionControlCardTranslateX,
  shouldShowCompanionWeatherCard
} from '../main/ets/pages/components/views/companion/CompanionControlPage';
import {
  resolveCompanionFocusedActionMode,
  shouldRenderFocusedSwitchCards,
  shouldShowFocusedPlannedRange
} from '../main/ets/pages/components/views/companion/CompanionFocusedCardHost';
import {
  getHistoryTimelineFilterLabelValue,
  getHistoryTimelineSkipReasonByNote,
  getNextHistoryTimelineFilterValue,
  isHistoryTimelineItemVisibleByFilter
} from '../main/ets/pages/components/views/companion/CompanionHistoryPage';
import {
  getExecutionWeatherCollapsedHintText,
  getExecutionWeatherCurrentNodeText,
  getExecutionWeatherExpandToggleText,
  getExecutionWeatherNextNodeText,
  getExecutionWeatherRefreshText,
  shouldShowExecutionWeatherAppliedSummary,
  shouldShowExecutionWeatherCollabSummary,
  shouldShowExecutionWeatherHint,
  shouldShowExecutionWeatherScore,
  splitExecutionWeatherSuggestionPopupText
} from '../main/ets/pages/components/views/companion/CompanionExecutionWeatherCard';
import {
  getCompanionTimelineFilterSummary,
  getCompanionTimelineVisibleCount,
  isCompanionTimelineFocused,
  shouldShowCompanionTimelineEmptyState
} from '../main/ets/pages/components/views/companion/CompanionTimelineSection';

function buildEventBM(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  return event;
}

export default function phase2BatchBMTest() {
  describe('phase2BatchBMTest', () => {
    it('normal: companion_control_should_show_weather_card_when_feature_enabled', 0, () => {
      // Arrange
      // Act
      const show = shouldShowCompanionWeatherCard(true);
      // Assert
      expect(show).assertTrue();
    });

    it('boundary: companion_control_should_hide_weather_card_when_feature_disabled', 0, () => {
      // Arrange
      // Act
      const show = shouldShowCompanionWeatherCard(false);
      // Assert
      expect(show).assertFalse();
    });

    it('normal: companion_control_should_resolve_current_event_id_or_fallback', 0, () => {
      // Arrange
      const event = buildEventBM(42);
      // Act
      const actual = getCompanionControlCurrentEventId(event);
      const fallback = getCompanionControlCurrentEventId(null);
      // Assert
      expect(actual).assertEqual(42);
      expect(fallback).assertEqual(-1);
    });

    it('normal: companion_control_translate_should_follow_switch_phase', 0, () => {
      // Arrange
      // Act
      const outgoing = resolveCompanionControlCardTranslateX(true, 0.5, 'outgoing');
      const incoming = resolveCompanionControlCardTranslateX(true, 0.5, 'incoming');
      const stable = resolveCompanionControlCardTranslateX(true, 0.5, 'stable');
      const idle = resolveCompanionControlCardTranslateX(false, 0.5, 'incoming');
      // Assert
      expect(outgoing).assertEqual(-9);
      expect(incoming).assertEqual(9);
      expect(stable).assertEqual(0);
      expect(idle).assertEqual(0);
    });

    it('normal: companion_control_opacity_should_follow_switch_phase', 0, () => {
      // Arrange
      // Act
      const outgoing = resolveCompanionControlCardOpacity(true, 0.25, 'outgoing');
      const incoming = resolveCompanionControlCardOpacity(true, 0.25, 'incoming');
      const stable = resolveCompanionControlCardOpacity(true, 0.25, 'stable');
      const idle = resolveCompanionControlCardOpacity(false, 0.25, 'incoming');
      // Assert
      expect(outgoing).assertEqual(0.75);
      expect(incoming).assertEqual(0.25);
      expect(stable).assertEqual(1);
      expect(idle).assertEqual(1);
    });

    it('normal: companion_control_scale_should_follow_switch_phase', 0, () => {
      // Arrange
      // Act
      const outgoing = resolveCompanionControlCardScale(true, 0.4, 'outgoing');
      const incoming = resolveCompanionControlCardScale(true, 0.4, 'incoming');
      const stable = resolveCompanionControlCardScale(true, 0.4, 'stable');
      const idle = resolveCompanionControlCardScale(false, 0.4, 'incoming');
      // Assert
      expect(Math.abs(outgoing - 0.994) < 0.000001).assertTrue();
      expect(Math.abs(incoming - 0.9952) < 0.000001).assertTrue();
      expect(stable).assertEqual(1);
      expect(idle).assertEqual(1);
    });

    it('normal: focused_card_should_show_planned_range_for_non_pending_state', 0, () => {
      // Arrange
      // Act
      const forActive = shouldShowFocusedPlannedRange('ACTIVE');
      const forPending = shouldShowFocusedPlannedRange('PENDING');
      // Assert
      expect(forActive).assertTrue();
      expect(forPending).assertFalse();
    });

    it('normal: focused_card_should_resolve_action_mode_branches', 0, () => {
      // Arrange
      // Act
      const pending = resolveCompanionFocusedActionMode('PENDING', 'IDLE', -1, 1);
      const active = resolveCompanionFocusedActionMode('ACTIVE', 'IDLE', -1, 1);
      const pausedActive = resolveCompanionFocusedActionMode('DONE', 'PAUSED', 3, 3);
      const skipped = resolveCompanionFocusedActionMode('SKIPPED', 'IDLE', -1, 1);
      const disabled = resolveCompanionFocusedActionMode('DONE', 'IDLE', -1, 1);
      // Assert
      expect(pending).assertEqual('PENDING');
      expect(active).assertEqual('ACTIVE');
      expect(pausedActive).assertEqual('PAUSED_ACTIVE');
      expect(skipped).assertEqual('SKIPPED');
      expect(disabled).assertEqual('DISABLED');
    });

    it('boundary: focused_card_should_require_both_switch_events', 0, () => {
      // Arrange
      const outgoing = buildEventBM(1);
      const incoming = buildEventBM(2);
      // Act
      const allReady = shouldRenderFocusedSwitchCards(true, outgoing, incoming);
      const missingOutgoing = shouldRenderFocusedSwitchCards(true, null, incoming);
      const missingIncoming = shouldRenderFocusedSwitchCards(true, outgoing, null);
      const disabled = shouldRenderFocusedSwitchCards(false, outgoing, incoming);
      // Assert
      expect(allReady).assertTrue();
      expect(missingOutgoing).assertFalse();
      expect(missingIncoming).assertFalse();
      expect(disabled).assertFalse();
    });

    it('normal: history_page_should_rotate_filter_state_in_fixed_order', 0, () => {
      // Arrange
      // Act
      const fromAll = getNextHistoryTimelineFilterValue('all');
      const fromCompleted = getNextHistoryTimelineFilterValue('completed');
      const fromSkipped = getNextHistoryTimelineFilterValue('skipped');
      const fromAbnormal = getNextHistoryTimelineFilterValue('abnormal');
      // Assert
      expect(fromAll).assertEqual('completed');
      expect(fromCompleted).assertEqual('skipped');
      expect(fromSkipped).assertEqual('abnormal');
      expect(fromAbnormal).assertEqual('all');
    });

    it('normal: history_page_should_map_filter_label', 0, () => {
      // Arrange
      // Act
      const all = getHistoryTimelineFilterLabelValue('all');
      const completed = getHistoryTimelineFilterLabelValue('completed');
      const skipped = getHistoryTimelineFilterLabelValue('skipped');
      const abnormal = getHistoryTimelineFilterLabelValue('abnormal');
      // Assert
      expect(all).assertEqual('\u5168\u90e8');
      expect(completed).assertEqual('\u53ea\u770b\u5b8c\u6210');
      expect(skipped).assertEqual('\u53ea\u770b\u8df3\u8fc7');
      expect(abnormal).assertEqual('\u53ea\u770b\u5f02\u5e38');
    });

    it('combined: history_page_should_filter_timeline_items_by_filter_and_state', 0, () => {
      // Arrange
      // Act
      const allVisible = isHistoryTimelineItemVisibleByFilter('all', 'ARRIVE', false);
      const completedArrive = isHistoryTimelineItemVisibleByFilter('completed', 'ARRIVE', false);
      const completedSkip = isHistoryTimelineItemVisibleByFilter('completed', 'SKIP', false);
      const skippedOnly = isHistoryTimelineItemVisibleByFilter('skipped', 'SKIP', false);
      const skippedArrive = isHistoryTimelineItemVisibleByFilter('skipped', 'ARRIVE', false);
      const abnormalFlag = isHistoryTimelineItemVisibleByFilter('abnormal', 'ARRIVE', true);
      const abnormalSkip = isHistoryTimelineItemVisibleByFilter('abnormal', 'SKIP', false);
      const abnormalNormal = isHistoryTimelineItemVisibleByFilter('abnormal', 'ARRIVE', false);
      // Assert
      expect(allVisible).assertTrue();
      expect(completedArrive).assertTrue();
      expect(completedSkip).assertFalse();
      expect(skippedOnly).assertTrue();
      expect(skippedArrive).assertFalse();
      expect(abnormalFlag).assertTrue();
      expect(abnormalSkip).assertTrue();
      expect(abnormalNormal).assertFalse();
    });

    it('boundary: history_page_should_resolve_skip_reason_from_note', 0, () => {
      // Arrange
      // Act
      const timeout = getHistoryTimelineSkipReasonByNote('  \u56e0\u4e3a\u65f6\u95f4\u4e0d\u8db3\uff0c\u8d76\u4e0b\u4e2a\u70b9  ');
      const manual = getHistoryTimelineSkipReasonByNote('\u7528\u6237\u4e3b\u52a8\u53d6\u6d88');
      // Assert
      expect(timeout).assertEqual('\u65f6\u95f4\u4e0d\u8db3');
      expect(manual).assertEqual('\u624b\u52a8\u8df3\u8fc7');
    });

    it('normal: execution_weather_should_map_refresh_and_expand_labels', 0, () => {
      // Arrange
      // Act
      const loading = getExecutionWeatherRefreshText(true);
      const idle = getExecutionWeatherRefreshText(false);
      const expanded = getExecutionWeatherExpandToggleText(true);
      const collapsed = getExecutionWeatherExpandToggleText(false);
      // Assert
      expect(loading).assertEqual('\u5237\u65b0\u4e2d...');
      expect(idle).assertEqual('\u5237\u65b0');
      expect(expanded).assertEqual('\u6536\u8d77');
      expect(collapsed).assertEqual('\u5c55\u5f00');
    });

    it('boundary: execution_weather_should_resolve_collapsed_hint_with_fallback', 0, () => {
      // Arrange
      // Act
      const withHint = getExecutionWeatherCollapsedHintText('\u5c06\u4e8e 15:00 \u4e0b\u96e8');
      const fallback = getExecutionWeatherCollapsedHintText('   ');
      // Assert
      expect(withHint).assertEqual('\u5c06\u4e8e 15:00 \u4e0b\u96e8');
      expect(fallback).assertEqual('\u5929\u6c14\u5efa\u8bae\u5df2\u6536\u8d77\uff0c\u8bf7\u7528\u4e0a\u65b9\u201c\u5c55\u5f00\u201d\u67e5\u770b');
    });

    it('normal: execution_weather_should_build_current_and_next_node_text', 0, () => {
      // Arrange
      // Act
      const current = getExecutionWeatherCurrentNodeText('\u4e0a\u6d77 \u6674 25\u2103');
      const currentFallback = getExecutionWeatherCurrentNodeText('   ');
      const next = getExecutionWeatherNextNodeText('\u82cf\u5dde \u9635\u96e8 19\u2103');
      const nextFallback = getExecutionWeatherNextNodeText('');
      // Assert
      expect(current).assertEqual('\u5f53\u524d\u4f4d\u7f6e\uff1a\u4e0a\u6d77 \u6674 25\u2103');
      expect(currentFallback).assertEqual('\u5f53\u524d\u4f4d\u7f6e\uff1a\u5929\u6c14\u672a\u77e5');
      expect(next).assertEqual('\u4e0b\u4e00\u8282\u70b9\uff1a\u82cf\u5dde \u9635\u96e8 19\u2103');
      expect(nextFallback).assertEqual('\u4e0b\u4e00\u8282\u70b9\uff1a\u5929\u6c14\u672a\u77e5');
    });

    it('normal: execution_weather_should_show_score_only_when_non_negative', 0, () => {
      // Arrange
      // Act
      const hide = shouldShowExecutionWeatherScore(-1);
      const zero = shouldShowExecutionWeatherScore(0);
      const positive = shouldShowExecutionWeatherScore(86);
      // Assert
      expect(hide).assertFalse();
      expect(zero).assertTrue();
      expect(positive).assertTrue();
    });

    it('normal: execution_weather_should_show_hint_collab_and_applied_when_non_blank', 0, () => {
      // Arrange
      // Act
      const hintShow = shouldShowExecutionWeatherHint('\u6ce8\u610f\u9632\u98ce');
      const hintHide = shouldShowExecutionWeatherHint('   ');
      const collabShow = shouldShowExecutionWeatherCollabSummary('\u8de8\u57ce\u8054\u52a8');
      const collabHide = shouldShowExecutionWeatherCollabSummary('');
      const appliedShow = shouldShowExecutionWeatherAppliedSummary('\u5df2\u540e\u79fb 20 \u5206\u949f');
      const appliedHide = shouldShowExecutionWeatherAppliedSummary('   ');
      // Assert
      expect(hintShow).assertTrue();
      expect(hintHide).assertFalse();
      expect(collabShow).assertTrue();
      expect(collabHide).assertFalse();
      expect(appliedShow).assertTrue();
      expect(appliedHide).assertFalse();
    });

    it('boundary: execution_weather_should_split_suggestion_popup_by_newline', 0, () => {
      // Arrange
      const text = '第1行\n第2行\n第3行';
      // Act
      const lines = splitExecutionWeatherSuggestionPopupText(text);
      // Assert
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('第1行');
      expect(lines[2]).assertEqual('第3行');
    });

    it('normal: timeline_section_should_match_focused_item_by_id', 0, () => {
      // Arrange
      // Act
      const focused = isCompanionTimelineFocused(7, 7);
      const notFocused = isCompanionTimelineFocused(7, 8);
      // Assert
      expect(focused).assertTrue();
      expect(notFocused).assertFalse();
    });

    it('boundary: timeline_section_visible_count_should_have_minimum_one', 0, () => {
      // Arrange
      // Act
      const zero = getCompanionTimelineVisibleCount(0);
      const negative = getCompanionTimelineVisibleCount(-3);
      const positive = getCompanionTimelineVisibleCount(5);
      // Assert
      expect(zero).assertEqual(1);
      expect(negative).assertEqual(1);
      expect(positive).assertEqual(5);
    });

    it('normal: timeline_section_should_build_filter_summary_with_visible_count', 0, () => {
      // Arrange
      // Act
      const summaryWithZero = getCompanionTimelineFilterSummary('\u5168\u90e8', 0, 0);
      const summaryWithCount = getCompanionTimelineFilterSummary('\u4ec5\u672a\u5b8c\u6210', 2, 5);
      // Assert
      expect(summaryWithZero).assertEqual('\u7b5b\u9009 \u5168\u90e8  0/1');
      expect(summaryWithCount).assertEqual('\u7b5b\u9009 \u4ec5\u672a\u5b8c\u6210  2/5');
    });

    it('boundary: timeline_section_should_show_empty_state_only_when_count_is_zero', 0, () => {
      // Arrange
      // Act
      const zero = shouldShowCompanionTimelineEmptyState(0);
      const positive = shouldShowCompanionTimelineEmptyState(1);
      const negative = shouldShowCompanionTimelineEmptyState(-1);
      // Assert
      expect(zero).assertTrue();
      expect(positive).assertFalse();
      expect(negative).assertFalse();
    });

    it('invalid: companion_control_should_fallback_to_minus_one_for_null_event', 0, () => {
      // Arrange
      const event = null;
      // Act
      const eventId = getCompanionControlCurrentEventId(event);
      // Assert
      expect(eventId).assertEqual(-1);
    });

    it('conflict: focused_card_should_prioritize_paused_active_state_when_focus_ids_match', 0, () => {
      // Arrange
      const currentState = 'DONE';
      // Act
      const mode = resolveCompanionFocusedActionMode(currentState, 'PAUSED', 9, 9);
      // Assert
      expect(mode).assertEqual('PAUSED_ACTIVE');
    });

    it('regression: timeline_summary_should_keep_minimum_total_count_of_one', 0, () => {
      // Arrange
      const label = '??';
      // Act
      const summary = getCompanionTimelineFilterSummary(label, 0, 0);
      // Assert
      expect(summary).assertEqual('\u7b5b\u9009 ??  0/1');
    });
  });
}
