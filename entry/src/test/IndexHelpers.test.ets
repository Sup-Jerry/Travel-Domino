import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexHelpers, WeatherSuggestionContext } from '../main/ets/pages/index/IndexHelpers';

function buildScheduleEvent(id: number, sortOrder: number, computedTime: string, duration: number, dynamicEndTime: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = 1;
  event.sort_order = sortOrder;
  event.computed_time = computedTime;
  event.duration = duration;
  event.dynamic_end_time = dynamicEndTime;
  return event;
}

export default function indexHelpersTest() {
  describe('unit_test_case_generator_autofill_IndexHelpers', () => {
    it('normal: split_lines_should_keep_row_order', 0, () => {
      // Arrange
      const text = 'a\nb\nc';
      // Act
      const lines = IndexHelpers.splitLines(text);
      // Assert
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('a');
      expect(lines[2]).assertEqual('c');
    });

    it('boundary: build_weather_suggestion_text_should_handle_empty_optional_parts', 0, () => {
      // Arrange
      const context: WeatherSuggestionContext = {
        collabLabel: '',
        planningHint: '建议延后出发',
        collabSummary: '',
        strategyHint: ''
      };
      // Act
      const text = IndexHelpers.buildWeatherSuggestionText(context);
      // Assert
      expect(text).assertContain('天气建议（可选）');
      expect(text).assertContain('建议延后出发');
    });

    it('invalid: resolve_backlog_suggested_time_should_fallback_when_no_schedule_items', 0, () => {
      // Arrange
      const backlog = new EventEntity();
      backlog.status = 0;
      backlog.sort_order = 99;
      const events: EventEntity[] = [backlog];
      // Act
      const suggested = IndexHelpers.resolveBacklogSuggestedTime(events);
      // Assert
      expect(suggested).assertEqual('09:00');
    });

    it('conflict: resolve_backlog_suggested_time_should_prioritize_computed_time_over_dynamic_end', 0, () => {
      // Arrange
      const item = buildScheduleEvent(1, 10, '03-17 08:20', 40, new Date(2026, 3, 1, 9, 40).getTime());
      // Act
      const suggested = IndexHelpers.resolveBacklogSuggestedTime([item]);
      // Assert
      expect(suggested).assertEqual('09:00');
    });

    it('regression: resolve_backlog_suggested_time_should_parse_date_prefixed_time', 0, () => {
      // Arrange
      const item = buildScheduleEvent(2, 100, '03-17 09:30', 30, 0);
      // Act
      const suggested = IndexHelpers.resolveBacklogSuggestedTime([item]);
      // Assert
      expect(suggested).assertEqual('10:00');
    });

    it('combined: resolve_backlog_suggested_time_should_use_last_schedule_by_sort_order', 0, () => {
      // Arrange
      const first = buildScheduleEvent(1, 10, '09:00', 30, 0);
      const second = buildScheduleEvent(2, 20, '10:00', 45, 0);
      const backlog = new EventEntity();
      backlog.status = 0;
      backlog.sort_order = 999;
      const events: EventEntity[] = [second, backlog, first];
      // Act
      const suggested = IndexHelpers.resolveBacklogSuggestedTime(events);
      // Assert
      expect(suggested).assertEqual('10:45');
    });
  });
}
