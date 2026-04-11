import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionPresentationHelper } from '../main/ets/pages/components/views/CompanionPresentationHelper';

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

export default function companionPresentationHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionPresentationHelper', () => {
    it('normal: planned_range_should_use_computed_time_and_duration', 0, () => {
      // Arrange
      const event = buildEvent(1);
      event.computed_time = '09:00';
      event.duration = 45;

      // Act
      const range = CompanionPresentationHelper.getPlannedRange(event);

      // Assert
      expect(range).assertEqual('09:00-09:45');
    });

    it('boundary: format_ts_should_return_placeholder_when_timestamp_is_zero', 0, () => {
      // Arrange
      const ts = 0;

      // Act
      const text = CompanionPresentationHelper.formatTs(ts);

      // Assert
      expect(text).assertEqual('--:--');
    });

    it('invalid: forecast_start_should_fallback_to_placeholder_when_no_time_candidates_exist', 0, () => {
      // Arrange
      const event = buildEvent(2);

      // Act
      const text = CompanionPresentationHelper.getForecastStartText(event);

      // Assert
      expect(text).assertEqual('--:--');
    });

    it('conflict: event_state_should_resolve_to_pending_for_backlog_even_with_actual_start', 0, () => {
      // Arrange
      const event = buildEvent(3);
      event.status = 0;
      event.actual_start_time = Date.now() - 120000;

      // Act
      const state = CompanionPresentationHelper.getEventState(event);

      // Assert
      expect(state).assertEqual('PENDING');
    });

    it('regression: forecast_start_should_prioritize_dynamic_start_over_computed_or_fixed', 0, () => {
      // Arrange
      const event = buildEvent(4);
      event.dynamic_start_time = new Date(2026, 2, 8, 10, 5, 0, 0).getTime();
      event.computed_time = '08:10';
      event.fixed_start_time = '07:00';

      // Act
      const text = CompanionPresentationHelper.getForecastStartText(event);

      // Assert
      expect(text).assertEqual('10:05');
    });

    it('combined: datetime_and_main_card_time_should_stay_consistent_for_pending_event', 0, () => {
      // Arrange
      const event = buildEvent(5);
      event.computed_time = '14:20';
      event.duration = 40;
      const ts = new Date(2026, 0, 2, 3, 4, 0, 0).getTime();

      // Act
      const dateTimeText = CompanionPresentationHelper.formatDateTime(ts);
      const plannedRange = CompanionPresentationHelper.getPlannedRange(event);
      const mainCardTime = CompanionPresentationHelper.getMainCardTimeText(event);

      // Assert
      expect(dateTimeText).assertEqual('2026-01-02 03:04');
      expect(plannedRange).assertEqual('14:20-15:00');
      expect(mainCardTime).assertEqual(plannedRange);
    });
  });
}
