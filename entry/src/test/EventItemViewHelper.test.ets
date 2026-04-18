import { describe, it, expect } from '@ohos/hypium';
import {
  formatEventItemCommuteTime,
  formatEventItemTimestamp,
  getEventItemTravelModeIcon,
  resolveEventItemCompanionOpacity,
  resolveEventItemCompanionStateLabel,
  resolveEventItemConflictGapMinutes,
  resolveEventItemPlanRange,
  resolveEventItemStartTimeDisplay,
  resolveEventItemThemeColor
} from '../main/ets/pages/components/views/EventItemView';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

export default function eventItemViewHelperTest() {
  describe('unit_test_case_generator_autofill_EventItemViewHelper', () => {
    it('normal: event_item_travel_mode_icon_should_map_drive_to_car', 0, () => {
      // Arrange
      const mode = 2;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚗');
    });

    it('boundary: event_item_commute_time_should_format_exact_hour', 0, () => {
      // Arrange
      const minutes = 120;
      // Act
      const text = formatEventItemCommuteTime(minutes);
      // Assert
      expect(text).assertEqual('2h');
    });

    it('invalid: event_item_travel_mode_icon_should_fallback_for_unknown_mode', 0, () => {
      // Arrange
      const mode = 999;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚗');
    });

    it('conflict: event_item_conflict_gap_should_parse_from_message_when_gap_missing', 0, () => {
      // Arrange
      const gapMinutes = 0;
      const conflictMsg = '与下一项冲突 25 分钟';
      // Act
      const resolved = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      // Assert
      expect(resolved).assertEqual(25);
    });

    it('regression: td-20260412-event-item-walk-override-icon-should-stay-walk', 0, () => {
      // Arrange
      const mode = 4;
      // Act
      const icon = getEventItemTravelModeIcon(mode);
      // Assert
      expect(icon).assertEqual('🚶');
    });

    it('combined: event_item_gap_and_commute_text_should_match_expected', 0, () => {
      // Arrange
      const gapMinutes = 10;
      const conflictMsg = '冲突 30 分钟';
      const commuteMinutes = 95;
      // Act
      const resolvedGap = resolveEventItemConflictGapMinutes(gapMinutes, conflictMsg);
      const commuteText = formatEventItemCommuteTime(commuteMinutes);
      // Assert
      expect(resolvedGap).assertEqual(10);
      expect(commuteText).assertEqual('1h 35m');
    });
  });

  describe('unit_test_case_generator_autofill_EventItemViewHelperBranches', () => {
    it('normal: event_item_plan_range_should_join_start_and_end_by_duration', 0, () => {
      // Arrange
      const computedTime = '09:00';
      const fixedStartTime = '';
      const duration = 90;
      // Act
      const range = resolveEventItemPlanRange(computedTime, fixedStartTime, duration);
      // Assert
      expect(range).assertEqual('09:00-10:30');
    });

    it('boundary: event_item_start_display_should_fallback_to_placeholder_when_both_times_empty', 0, () => {
      // Arrange
      const computedTime = '';
      const fixedStartTime = '';
      // Act
      const display = resolveEventItemStartTimeDisplay(computedTime, fixedStartTime);
      // Assert
      expect(display).assertEqual('--:--');
    });

    it('invalid: event_item_timestamp_should_return_placeholder_for_non_positive_timestamp', 0, () => {
      // Arrange
      const ts = 0;
      // Act
      const text = formatEventItemTimestamp(ts);
      // Assert
      expect(text).assertEqual('--:--');
    });

    it('conflict: event_item_theme_color_should_prioritize_event_type_over_name_keyword', 0, () => {
      // Arrange
      const eventType = 3;
      const eventSource = 0;
      const name = '吃饭地铁站';
      const effectiveTheme = 'light';
      const defaultPrimary = '#123456';
      // Act
      const color = resolveEventItemThemeColor(eventType, eventSource, name, effectiveTheme, defaultPrimary);
      // Assert
      expect(color).assertEqual('#9E9E9E');
    });

    it('regression: td-20260418-event_item_companion_state_label_should_keep_ready_for_current_pending_event', 0, () => {
      // Arrange
      const completionStatus = EventEntity.STATE_PENDING;
      const actualStartTime = 0;
      const eventId = 200;
      const companionCurrentEventId = 200;
      // Act
      const label = resolveEventItemCompanionStateLabel(completionStatus, actualStartTime, eventId, companionCurrentEventId);
      // Assert
      expect(label).assertEqual('READY');
    });

    it('combined: event_item_companion_opacity_and_state_should_match_completed_event_expectation', 0, () => {
      // Arrange
      const isCompanionMode = true;
      const eventId = 9;
      const companionCurrentEventId = 8;
      const completionStatus = EventEntity.STATE_COMPLETED;
      const actualStartTime = 1;
      // Act
      const opacity = resolveEventItemCompanionOpacity(
        isCompanionMode,
        eventId,
        companionCurrentEventId,
        completionStatus,
        actualStartTime
      );
      const label = resolveEventItemCompanionStateLabel(
        completionStatus,
        actualStartTime,
        eventId,
        companionCurrentEventId
      );
      // Assert
      expect(opacity).assertEqual(0.45);
      expect(label).assertEqual('COMPLETED');
    });
  });
}
