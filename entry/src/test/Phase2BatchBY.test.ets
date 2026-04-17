import { describe, it, expect } from '@ohos/hypium';
import {
  createAppSideBarRouteOptions,
  getAppSideBarRouteByKey
} from '../main/ets/pages/components/views/AppSideBar';
import {
  getDefaultIndexUnsavedActionTheme,
  shouldShowIndexUnsavedActionBar
} from '../main/ets/pages/index/IndexUnsavedActionBar';
import {
  getDefaultIndexBacklogSectionDividerColor,
  resolveIndexBacklogSectionMaxHeight
} from '../main/ets/pages/index/IndexBacklogSection';
import {
  resolveIndexBacklogItems,
  shouldIncludeIndexBacklogEvent
} from '../main/ets/pages/index/IndexBacklogView';
import {
  advanceAdjustTimeToMinutes,
  resolveAdvanceAdjustPreviewGapColor,
  resolveAdvanceAdjustPreviewGapMessage,
  resolveAdvanceAdjustPreviewRangeMessage,
  resolveAdvanceAdjustSelectedIds,
  resolveAdvanceAdjustSelectedSummary,
  toggleAdvanceAdjustSelection
} from '../main/ets/pages/components/dialogs/AdvanceAdjustDialog';
import {
  getDateFilterDialogOptions,
  isDateFilterDialogActionSupported
} from '../main/ets/pages/components/dialogs/DateFilterDialog';
import {
  buildAiReplanPreviewSummary,
  getAiReplanStrategyLabel
} from '../main/ets/pages/components/dialogs/AiReplanPreviewDialog';
import {
  getSuggestionApplyButtonLabel,
  getSuggestionBackButtonLabel,
  shouldShowSuggestionSummary
} from '../main/ets/pages/components/dialogs/SuggestionDialog';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { AiReplanPreviewResult } from '../main/ets/domain/timeline/services/TimelineAiService';
import { AdvanceAdjustCandidate, AdvanceAdjustPreview } from '../main/ets/viewmodel/TimelineViewModel';

function buildBacklogEvent(id: number, status: number, name: string, duration: number): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = status;
  event.duration = duration;
  event.sort_order = id * 100;
  event.type = id % 3;
  return event;
}

function buildAdvanceAdjustCandidate(id: number, index: number, name: string): AdvanceAdjustCandidate {
  return {
    id: id,
    index: index,
    name: name,
    currentStartTime: '09:00',
    currentEndTime: '10:00',
    duration: 60
  };
}

function buildAdvanceAdjustPreview(remainingGapMinutes: number): AdvanceAdjustPreview {
  return {
    valid: remainingGapMinutes <= 0,
    message: remainingGapMinutes <= 0 ? '可应用前移调整，可消除当前冲突' : '可应用前移调整，仍差 5 分钟可消除冲突',
    selectedCount: 2,
    shiftMinutes: 40,
    requiredGapMinutes: 45,
    remainingGapMinutes: remainingGapMinutes,
    firstNewStartTime: '08:20',
    lastNewEndTime: '10:10',
    items: []
  };
}

function buildAiPreview(itemCount: number, strategyMode: number): AiReplanPreviewResult {
  return {
    prompt: '三日游',
    strategyMode: strategyMode,
    generatedAt: 123456789,
    itemCount: itemCount,
    items: []
  };
}

export default function phase2BatchBYTest() {
  describe('Phase2BatchBY', () => {
    describe('phase2_batch_by_app_sidebar_pure_logic', () => {
      it('normal: app_sidebar_route_options_should_embed_route_url', 0, () => {
        // Arrange
        const route = getAppSideBarRouteByKey('archive');
        // Act
        const options = createAppSideBarRouteOptions(route);
        // Assert
        expect(options.url).assertEqual('pages/ArchivePage');
      });

      it('boundary: app_sidebar_route_options_should_return_fresh_instances', 0, () => {
        // Arrange
        const route = getAppSideBarRouteByKey('settings');
        // Act
        const first = createAppSideBarRouteOptions(route);
        const second = createAppSideBarRouteOptions(route);
        // Assert
        expect(first.url).assertEqual('pages/SettingsPage');
        expect(second.url).assertEqual('pages/SettingsPage');
        expect(first !== second).assertTrue();
      });
    });

    describe('phase2_batch_by_unsaved_action_bar_pure_logic', () => {
      it('invalid: index_unsaved_action_theme_should_not_share_mutated_state_between_calls', 0, () => {
        // Arrange
        const first = getDefaultIndexUnsavedActionTheme();
        first.primary = '#000000';
        // Act
        const second = getDefaultIndexUnsavedActionTheme();
        const visible = shouldShowIndexUnsavedActionBar(true);
        // Assert
        expect(second.primary).assertEqual('#2F7DFF');
        expect(visible).assertTrue();
      });
    });

    describe('phase2_batch_by_backlog_section_pure_logic', () => {
      it('regression: td-20260417-index_backlog_section_defaults_should_stay_stable', 0, () => {
        // Arrange
        // Act
        const height = resolveIndexBacklogSectionMaxHeight();
        const dividerColor = getDefaultIndexBacklogSectionDividerColor();
        // Assert
        expect(height).assertEqual('30%');
        expect(dividerColor).assertEqual('#E7EDF5');
      });
    });

    describe('phase2_batch_by_backlog_view_pure_logic', () => {
      it('conflict: index_backlog_items_should_filter_scheduled_events_and_keep_backlog_fields', 0, () => {
        // Arrange
        const first = buildBacklogEvent(1, 0, '故宫', 120);
        const second = buildBacklogEvent(2, 1, '已排入日程', 60);
        const third = buildBacklogEvent(3, 2, '什刹海', 90);
        // Act
        const items = resolveIndexBacklogItems([first, second, third]);
        // Assert
        expect(shouldIncludeIndexBacklogEvent(first.status)).assertTrue();
        expect(shouldIncludeIndexBacklogEvent(second.status)).assertFalse();
        expect(items.length).assertEqual(2);
        expect(items[0].name).assertEqual('故宫');
        expect(items[1].name).assertEqual('什刹海');
      });
    });

    describe('phase2_batch_by_advance_adjust_dialog_pure_logic', () => {
      it('combined: advance_adjust_selection_and_preview_text_should_stay_consistent', 0, () => {
        // Arrange
        const candidates: AdvanceAdjustCandidate[] = [
          buildAdvanceAdjustCandidate(11, 0, '地点A'),
          buildAdvanceAdjustCandidate(12, 1, '地点B')
        ];
        const previewPending = buildAdvanceAdjustPreview(5);
        const previewDone = buildAdvanceAdjustPreview(0);
        // Act
        const selected = resolveAdvanceAdjustSelectedIds(candidates);
        const removed = toggleAdvanceAdjustSelection(selected, 11, false);
        const summary = resolveAdvanceAdjustSelectedSummary(previewPending);
        const pendingMessage = resolveAdvanceAdjustPreviewGapMessage(previewPending);
        const doneMessage = resolveAdvanceAdjustPreviewGapMessage(previewDone);
        const pendingColor = resolveAdvanceAdjustPreviewGapColor(previewPending);
        const doneColor = resolveAdvanceAdjustPreviewGapColor(previewDone);
        const rangeMessage = resolveAdvanceAdjustPreviewRangeMessage(previewDone);
        // Assert
        expect(selected.has(11)).assertTrue();
        expect(selected.has(12)).assertTrue();
        expect(removed.has(11)).assertFalse();
        expect(removed.has(12)).assertTrue();
        expect(summary).assertEqual('已选 2 个，预计前移 40 分钟');
        expect(pendingMessage).assertEqual('最少前移 45 分钟；还差 5 分钟');
        expect(doneMessage).assertEqual('最少前移 45 分钟；已达到消冲突阈值');
        expect(pendingColor).assertEqual('#FF4D4F');
        expect(doneColor).assertEqual('#2E7D32');
        expect(rangeMessage).assertEqual('首地点：08:20，末地点：10:10');
      });

      it('boundary: advance_adjust_time_to_minutes_should_clamp_overflow_values', 0, () => {
        // Arrange
        const source = '29:99';
        // Act
        const minutes = advanceAdjustTimeToMinutes(source);
        // Assert
        expect(minutes).assertEqual(1439);
      });
    });

    describe('phase2_batch_by_date_filter_dialog_pure_logic', () => {
      it('normal: date_filter_options_should_keep_action_order_and_titles', 0, () => {
        // Arrange
        // Act
        const options = getDateFilterDialogOptions();
        // Assert
        expect(options.length).assertEqual(3);
        expect(options[0].action).assertEqual('show_all');
        expect(options[0].title).assertEqual('显示全部行程');
        expect(options[2].action).assertEqual('select_range');
        expect(options[2].description.indexOf('26号 到 29号') >= 0).assertTrue();
      });
    });

    describe('phase2_batch_by_ai_replan_preview_dialog_pure_logic', () => {
      it('regression: td-20260417-ai_replan_summary_should_keep_count_and_strategy_label', 0, () => {
        // Arrange
        const preview = buildAiPreview(5, -1);
        // Act
        const summary = buildAiReplanPreviewSummary(preview);
        const strategyLabel = getAiReplanStrategyLabel(preview.strategyMode);
        // Assert
        expect(summary).assertEqual('共生成 5 个地点，策略：自定义');
        expect(strategyLabel).assertEqual('自定义');
      });
    });

    describe('phase2_batch_by_suggestion_dialog_pure_logic', () => {
      it('combined: suggestion_dialog_labels_and_summary_guard_should_match_expected_copy', 0, () => {
        // Arrange
        const summaryText = '\n\t  ';
        // Act
        const backLabel = getSuggestionBackButtonLabel();
        const applyLabel = getSuggestionApplyButtonLabel();
        const shouldShow = shouldShowSuggestionSummary(summaryText);
        // Assert
        expect(backLabel).assertEqual('上一步');
        expect(applyLabel).assertEqual('应用修改');
        expect(shouldShow).assertFalse();
      });
    });

    describe('phase2_batch_by_cross_dialog_guards', () => {
      it('invalid: date_filter_support_check_should_reject_blank_action', 0, () => {
        // Arrange
        const action = ' ';
        // Act
        const supported = isDateFilterDialogActionSupported(action);
        // Assert
        expect(supported).assertFalse();
      });
    });
  });
}
