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
      expect(all).assertEqual('全部');
      expect(completed).assertEqual('只看完成');
      expect(skipped).assertEqual('只看跳过');
      expect(abnormal).assertEqual('只看异常');
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
      const timeout = getHistoryTimelineSkipReasonByNote('  因为时间不足，赶下个点  ');
      const manual = getHistoryTimelineSkipReasonByNote('用户主动取消');
      // Assert
      expect(timeout).assertEqual('时间不足');
      expect(manual).assertEqual('手动跳过');
    });

    it('normal: execution_weather_should_map_refresh_and_expand_labels', 0, () => {
      // Arrange
      // Act
      const loading = getExecutionWeatherRefreshText(true);
      const idle = getExecutionWeatherRefreshText(false);
      const expanded = getExecutionWeatherExpandToggleText(true);
      const collapsed = getExecutionWeatherExpandToggleText(false);
      // Assert
      expect(loading).assertEqual('刷新中...');
      expect(idle).assertEqual('刷新');
      expect(expanded).assertEqual('收起');
      expect(collapsed).assertEqual('展开');
    });

    it('boundary: execution_weather_should_resolve_collapsed_hint_with_fallback', 0, () => {
      // Arrange
      // Act
      const withHint = getExecutionWeatherCollapsedHintText('将于 15:00 下雨');
      const fallback = getExecutionWeatherCollapsedHintText('   ');
      // Assert
      expect(withHint).assertEqual('将于 15:00 下雨');
      expect(fallback).assertEqual('天气建议已收起，请用上方“展开”查看');
    });

    it('normal: execution_weather_should_build_current_and_next_node_text', 0, () => {
      // Arrange
      // Act
      const current = getExecutionWeatherCurrentNodeText('上海 晴 25℃');
      const currentFallback = getExecutionWeatherCurrentNodeText('   ');
      const next = getExecutionWeatherNextNodeText('苏州 阵雨 19℃');
      const nextFallback = getExecutionWeatherNextNodeText('');
      // Assert
      expect(current).assertEqual('当前位置：上海 晴 25℃');
      expect(currentFallback).assertEqual('当前位置：天气未知');
      expect(next).assertEqual('下一节点：苏州 阵雨 19℃');
      expect(nextFallback).assertEqual('下一节点：天气未知');
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
      const hintShow = shouldShowExecutionWeatherHint('注意防风');
      const hintHide = shouldShowExecutionWeatherHint('   ');
      const collabShow = shouldShowExecutionWeatherCollabSummary('跨城联动');
      const collabHide = shouldShowExecutionWeatherCollabSummary('');
      const appliedShow = shouldShowExecutionWeatherAppliedSummary('已后移 20 分钟');
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
      const summaryWithZero = getCompanionTimelineFilterSummary('全部', 0, 0);
      const summaryWithCount = getCompanionTimelineFilterSummary('仅未完成', 2, 5);
      // Assert
      expect(summaryWithZero).assertEqual('筛选 全部  0/1');
      expect(summaryWithCount).assertEqual('筛选 仅未完成  2/5');
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
  });
}
