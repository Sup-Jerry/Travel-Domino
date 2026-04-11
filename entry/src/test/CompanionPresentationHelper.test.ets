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

    it('normal: state_labels_should_cover_pending_active_completed_and_skipped', 0, () => {
      // Arrange
      const pending = buildEvent(6);
      const active = buildEvent(7);
      active.actual_start_time = new Date(2026, 2, 8, 10, 5, 0, 0).getTime();
      const completed = buildEvent(8);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const skipped = buildEvent(9);
      skipped.completion_status = EventEntity.STATE_SKIPPED;

      // Act
      const pendingLabel = CompanionPresentationHelper.getEventStateLabel(pending);
      const activeLabel = CompanionPresentationHelper.getEventStateLabel(active);
      const completedLabel = CompanionPresentationHelper.getEventStateLabel(completed);
      const skippedLabel = CompanionPresentationHelper.getEventStateLabel(skipped);

      // Assert
      expect(pendingLabel.length > 0).assertTrue();
      expect(activeLabel.length > 0).assertTrue();
      expect(completedLabel.length > 0).assertTrue();
      expect(skippedLabel.length > 0).assertTrue();
      expect(pendingLabel === activeLabel).assertFalse();
      expect(completedLabel === skippedLabel).assertFalse();
    });

    it('boundary: active_timeline_supplement_should_report_minimum_one_minute_when_just_started', 0, () => {
      // Arrange
      const event = buildEvent(10);
      const nowTs = new Date(2026, 2, 8, 10, 5, 0, 0).getTime();
      event.actual_start_time = nowTs;

      // Act
      const supplement = CompanionPresentationHelper.getTimelineSupplement(event, nowTs);

      // Assert
      expect(supplement.includes('1')).assertTrue();
      expect(supplement.includes('|')).assertTrue();
    });

    it('invalid: completed_main_card_and_timeline_should_keep_placeholders_when_actual_times_missing', 0, () => {
      // Arrange
      const event = buildEvent(11);
      event.completion_status = EventEntity.STATE_COMPLETED;
      event.actual_start_time = 0;
      event.actual_end_time = 0;

      // Act
      const mainCardTime = CompanionPresentationHelper.getMainCardTimeText(event);
      const supplement = CompanionPresentationHelper.getTimelineSupplement(event);

      // Assert
      expect(mainCardTime.includes('--:--')).assertTrue();
      expect(supplement.includes('--:--')).assertTrue();
    });

    it('conflict: skipped_state_texts_should_not_fall_back_to_pending_planned_range', 0, () => {
      // Arrange
      const event = buildEvent(12);
      event.computed_time = '09:30';
      event.duration = 20;
      event.completion_status = EventEntity.STATE_SKIPPED;
      const plannedRange = CompanionPresentationHelper.getPlannedRange(event);

      // Act
      const label = CompanionPresentationHelper.getEventStateLabel(event);
      const mainCardTime = CompanionPresentationHelper.getMainCardTimeText(event);
      const supplement = CompanionPresentationHelper.getTimelineSupplement(event);

      // Assert
      expect(label.length > 0).assertTrue();
      expect(mainCardTime.length > 0).assertTrue();
      expect(supplement.length > 0).assertTrue();
      expect(mainCardTime === plannedRange).assertFalse();
      expect(supplement.includes('09:30')).assertFalse();
    });

    it('regression: active_main_card_time_should_prefer_actual_start_over_planned_range', 0, () => {
      // Arrange
      const event = buildEvent(13);
      event.computed_time = '08:10';
      event.duration = 40;
      event.actual_start_time = new Date(2026, 2, 8, 10, 5, 0, 0).getTime();

      // Act
      const mainCardTime = CompanionPresentationHelper.getMainCardTimeText(event);
      const plannedRange = CompanionPresentationHelper.getPlannedRange(event);

      // Assert
      expect(mainCardTime.includes('10:05')).assertTrue();
      expect(mainCardTime === plannedRange).assertFalse();
    });

    it('combined: completed_state_label_main_card_and_timeline_should_align_on_actual_end', 0, () => {
      // Arrange
      const event = buildEvent(14);
      event.completion_status = EventEntity.STATE_COMPLETED;
      event.actual_start_time = new Date(2026, 2, 8, 9, 10, 0, 0).getTime();
      event.actual_end_time = new Date(2026, 2, 8, 9, 50, 0, 0).getTime();

      // Act
      const label = CompanionPresentationHelper.getEventStateLabel(event);
      const mainCardTime = CompanionPresentationHelper.getMainCardTimeText(event);
      const supplement = CompanionPresentationHelper.getTimelineSupplement(event);

      // Assert
      expect(label.length > 0).assertTrue();
      expect(mainCardTime.includes('09:10')).assertTrue();
      expect(mainCardTime.includes('09:50')).assertTrue();
      expect(supplement.includes('09:50')).assertTrue();
    });
  });
}
