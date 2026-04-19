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

export default function companionPresentationHelperEdgeFallbackTest() {
  describe('unit_test_case_generator_autofill_CompanionPresentationHelperEdgeFallback', () => {
    it('normal: format_datetime_should_return_placeholder_when_timestamp_is_non_positive', 0, () => {
      // Arrange
      const zeroTs = 0;
      const negativeTs = -1;

      // Act
      const zeroText = CompanionPresentationHelper.formatDateTime(zeroTs);
      const negativeText = CompanionPresentationHelper.formatDateTime(negativeTs);

      // Assert
      expect(zeroText).assertEqual('--:--');
      expect(negativeText).assertEqual('--:--');
    });

    it('boundary: timeline_supplement_should_fallback_to_pending_branch_when_actual_start_missing', 0, () => {
      // Arrange
      const event = buildEvent(1);
      event.actual_start_time = 0;
      event.fixed_start_time = '10:10';
      const nowTs = Date.now();

      // Act
      const supplement = CompanionPresentationHelper.getTimelineSupplement(event, nowTs);

      // Assert
      expect(supplement.includes('10:10')).assertTrue();
      expect(supplement.includes('|')).assertTrue();
    });

    it('invalid: timeline_supplement_active_branch_should_allow_zero_stay_minutes_when_start_time_missing', 0, () => {
      // Arrange
      const event = buildEvent(6);
      event.actual_start_time = 0;
      const originalGetEventState =
        Reflect.get(CompanionPresentationHelper as Object, 'getEventState') as (event: EventEntity) => string;
      Reflect.set(CompanionPresentationHelper as Object, 'getEventState', (_event: EventEntity): string => 'ACTIVE');

      // Act
      let supplement = '';
      try {
        supplement = CompanionPresentationHelper.getTimelineSupplement(event, Date.now());
      } finally {
        Reflect.set(CompanionPresentationHelper as Object, 'getEventState', originalGetEventState);
      }

      // Assert
      expect(supplement.indexOf('0') >= 0).assertTrue();
    });

    it('invalid: planned_range_should_fallback_to_placeholder_when_start_time_candidates_are_empty', 0, () => {
      // Arrange
      const event = buildEvent(2);
      event.duration = 45;

      // Act
      const range = CompanionPresentationHelper.getPlannedRange(event);

      // Assert
      expect(range.includes('--:--')).assertTrue();
      expect(range.includes('-')).assertTrue();
    });

    it('conflict: forecast_start_should_fallback_to_fixed_start_when_dynamic_and_computed_are_unavailable', 0, () => {
      // Arrange
      const event = buildEvent(3);
      event.dynamic_start_time = 0;
      event.computed_time = '';
      event.fixed_start_time = '11:25';

      // Act
      const text = CompanionPresentationHelper.getForecastStartText(event);

      // Assert
      expect(text).assertEqual('11:25');
    });

    it('regression: active_main_card_should_show_placeholder_start_when_actual_start_is_zero', 0, () => {
      // Arrange
      const event = buildEvent(4);
      event.actual_start_time = 0;

      // Act
      const text = CompanionPresentationHelper.getMainCardTimeText(event);

      // Assert
      expect(text.includes('--:--')).assertTrue();
      expect(text.length > 0).assertTrue();
    });

    it('combined: pending_paths_should_align_between_main_card_timeline_and_forecast_when_only_fixed_start_exists', 0, () => {
      // Arrange
      const event = buildEvent(5);
      event.fixed_start_time = '13:40';
      event.computed_time = '';
      event.duration = 20;

      // Act
      const forecast = CompanionPresentationHelper.getForecastStartText(event);
      const mainCard = CompanionPresentationHelper.getMainCardTimeText(event);
      const timeline = CompanionPresentationHelper.getTimelineSupplement(event);

      // Assert
      expect(forecast).assertEqual('13:40');
      expect(mainCard).assertEqual('13:40-14:00');
      expect(timeline.includes('13:40')).assertTrue();
    });
  });
}
