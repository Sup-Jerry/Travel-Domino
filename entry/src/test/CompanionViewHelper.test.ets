import { describe, it, expect } from '@ohos/hypium';
import {
  isCompanionOverlayVisible,
  resolveCompanionBackAction,
  resolveCompanionBackLevel,
  resolveCompanionDefaultFocusId,
  resolveCompanionSearchResults,
  resolveCompanionVisibleFocusId,
  resolveCompanionVisibleFocusPosition
} from '../main/ets/pages/components/views/CompanionView';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

function buildCompanionEvent(id: number, name: string, address: string = ''): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.address = address;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

export default function companionViewHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionViewHelper', () => {
    it('normal: companion_back_level_should_be_overlay_when_any_overlay_visible', 0, () => {
      // Arrange
      const showHistoryPage = true;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(level).assertEqual('overlay');
    });

    it('boundary: companion_back_level_should_be_control_without_overlays_in_control_mode', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'control');
      // Assert
      expect(level).assertEqual('control');
    });

    it('invalid: companion_overlay_visible_should_be_false_when_all_flags_false', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: companion_overlay_visible_should_be_true_when_history_and_search_both_open', 0, () => {
      // Arrange
      const showHistoryPage = true;
      const showSearchPage = true;
      const showFilterPage = false;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      // Assert
      expect(visible).assertTrue();
    });

    it('regression: td-20260412-companion-back-level-immersive-default-should-stay', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(level).assertEqual('immersive');
    });

    it('combined: companion_overlay_and_back_level_should_be_consistent', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = true;
      // Act
      const visible = isCompanionOverlayVisible(showHistoryPage, showSearchPage, showFilterPage);
      const level = resolveCompanionBackLevel(showHistoryPage, showSearchPage, showFilterPage, 'control');
      // Assert
      expect(visible).assertTrue();
      expect(level).assertEqual('overlay');
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewHelperBranches', () => {
    it('normal: companion_back_action_should_return_overlay_close_when_any_overlay_open', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = true;
      const showFilterPage = false;
      // Act
      const action = resolveCompanionBackAction(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(action).assertEqual('close_overlay');
    });

    it('boundary: companion_search_should_limit_empty_keyword_result_to_20_items', 0, () => {
      // Arrange
      const source: EventEntity[] = [];
      for (let i = 1; i <= 25; i++) {
        source.push(buildCompanionEvent(i, `event-${i}`));
      }
      // Act
      const results = resolveCompanionSearchResults(source, '   ');
      // Assert
      expect(results.length).assertEqual(20);
    });

    it('invalid: companion_visible_focus_position_should_return_zero_when_focus_not_mapped', 0, () => {
      // Arrange
      const focusedEventId = 999;
      const visibleIndexById: Map<number, number> = new Map<number, number>();
      visibleIndexById.set(1, 0);
      // Act
      const position = resolveCompanionVisibleFocusPosition(focusedEventId, visibleIndexById);
      // Assert
      expect(position).assertEqual(0);
    });

    it('conflict: companion_default_focus_should_prioritize_current_event_over_next_when_both_exist', 0, () => {
      // Arrange
      const schedule = [buildCompanionEvent(11, 'a'), buildCompanionEvent(12, 'b')];
      const currentEventId = 12;
      const nextEventId = 11;
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, currentEventId, nextEventId);
      // Assert
      expect(focused).assertEqual(12);
    });

    it('regression: td-20260418-companion-visible-focus-id-should-fallback-to-first-visible', 0, () => {
      // Arrange
      const visibleEvents = [buildCompanionEvent(5, 'first'), buildCompanionEvent(6, 'second')];
      const focusedEventId = 100;
      // Act
      const visibleFocusId = resolveCompanionVisibleFocusId(visibleEvents, focusedEventId);
      // Assert
      expect(visibleFocusId).assertEqual(5);
    });

    it('combined: companion_search_and_back_action_should_support_keyword_filter_and_control_mode_exit', 0, () => {
      // Arrange
      const source = [
        buildCompanionEvent(1, 'Museum', 'Center'),
        buildCompanionEvent(2, 'Cafe', 'Lake')
      ];
      // Act
      const results = resolveCompanionSearchResults(source, 'cafe');
      const action = resolveCompanionBackAction(false, false, false, 'control');
      // Assert
      expect(results.length).assertEqual(1);
      expect(results[0].id).assertEqual(2);
      expect(action).assertEqual('control_to_immersive');
    });
  });

  describe('unit_test_case_generator_autofill_CompanionViewHelperPriorityBranches', () => {
    it('normal: companion_default_focus_should_prioritize_active_event_over_current_and_next', 0, () => {
      // Arrange
      const active = buildCompanionEvent(21, 'active');
      active.actual_start_time = 1000;
      active.actual_end_time = 0;
      const pending = buildCompanionEvent(22, 'pending');
      const schedule = [pending, active];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, 22, 21);
      // Assert
      expect(focused).assertEqual(21);
    });

    it('boundary: companion_default_focus_should_fallback_to_negative_one_when_schedule_empty', 0, () => {
      // Arrange
      const schedule: EventEntity[] = [];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, 1, 2);
      // Assert
      expect(focused).assertEqual(-1);
    });

    it('invalid: companion_search_should_use_search_text_map_when_event_text_not_match', 0, () => {
      // Arrange
      const source = [buildCompanionEvent(31, 'A', 'B')];
      const searchTextById = new Map<number, string>();
      searchTextById.set(31, 'custom-keyword');
      // Act
      const results = resolveCompanionSearchResults(source, 'custom', searchTextById);
      // Assert
      expect(results.length).assertEqual(1);
      expect(results[0].id).assertEqual(31);
    });

    it('conflict: companion_back_action_should_exit_when_no_overlay_and_not_control_mode', 0, () => {
      // Arrange
      const showHistoryPage = false;
      const showSearchPage = false;
      const showFilterPage = false;
      // Act
      const action = resolveCompanionBackAction(showHistoryPage, showSearchPage, showFilterPage, 'immersive');
      // Assert
      expect(action).assertEqual('exit');
    });

    it('regression: td-20260418-companion_visible_focus_position_should_be_1_based', 0, () => {
      // Arrange
      const visibleIndexById: Map<number, number> = new Map<number, number>();
      visibleIndexById.set(41, 0);
      // Act
      const position = resolveCompanionVisibleFocusPosition(41, visibleIndexById);
      // Assert
      expect(position).assertEqual(1);
    });

    it('combined: companion_focus_resolution_should_support_startable_fallback_and_visible_focus', 0, () => {
      // Arrange
      const pending = buildCompanionEvent(51, 'pending');
      const done = buildCompanionEvent(52, 'done');
      done.completion_status = EventEntity.STATE_COMPLETED;
      const schedule = [done, pending];
      const visible = [pending];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, -1, -1);
      const visibleFocused = resolveCompanionVisibleFocusId(visible, focused);
      // Assert
      expect(focused).assertEqual(51);
      expect(visibleFocused).assertEqual(51);
    });

    it('boundary: companion_visible_focus_should_return_negative_one_when_visible_list_empty', 0, () => {
      // Arrange
      const visibleEvents: EventEntity[] = [];
      // Act
      const visibleFocusId = resolveCompanionVisibleFocusId(visibleEvents, 88);
      // Assert
      expect(visibleFocusId).assertEqual(-1);
    });

    it('conflict: companion_default_focus_should_use_next_event_when_current_event_missing', 0, () => {
      // Arrange
      const first = buildCompanionEvent(61, 'first');
      first.completion_status = EventEntity.STATE_COMPLETED;
      const next = buildCompanionEvent(62, 'next');
      next.completion_status = EventEntity.STATE_COMPLETED;
      const schedule = [first, next];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, 999, 62);
      // Assert
      expect(focused).assertEqual(62);
    });

    it('regression: td-20260419-companion_default_focus_should_fallback_to_first_when_no_candidate_matches', 0, () => {
      // Arrange
      const first = buildCompanionEvent(71, 'first');
      first.completion_status = EventEntity.STATE_COMPLETED;
      const second = buildCompanionEvent(72, 'second');
      second.completion_status = EventEntity.STATE_COMPLETED;
      const schedule = [first, second];
      // Act
      const focused = resolveCompanionDefaultFocusId(schedule, -1, -1);
      // Assert
      expect(focused).assertEqual(71);
    });
  });
}
