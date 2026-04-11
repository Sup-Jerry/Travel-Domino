import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexAddDialogHelper } from '../main/ets/pages/index/IndexAddDialogHelper';

function buildEvent(
  id: number,
  status: number,
  computedTime: string,
  duration: number,
  dayOffset: number,
  dynamicDayOffset: number
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = status;
  event.name = `E${id}`;
  event.computed_time = computedTime;
  event.fixed_start_time = '';
  event.duration = duration;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dynamicDayOffset;
  return event;
}

export default function indexAddDialogHelperTest() {
  describe('unit_test_case_generator_autofill_IndexAddDialogHelper', () => {
    it('normal: calculate_smart_time_should_use_previous_item_end_time', 0, () => {
      // Arrange
      const events: EventEntity[] = [
        buildEvent(1, 1, '09:00', 30, 0, 0),
        buildEvent(2, 1, '10:00', 40, 0, 0)
      ];
      // Act
      const suggested = IndexAddDialogHelper.calculateSmartTime(events, -1);
      // Assert
      expect(suggested).assertEqual('10:40');
    });

    it('boundary: calculate_smart_time_should_return_default_when_events_empty', 0, () => {
      // Arrange
      const events: EventEntity[] = [];
      // Act
      const suggested = IndexAddDialogHelper.calculateSmartTime(events, -1);
      // Assert
      expect(suggested).assertEqual('09:00');
    });

    it('invalid: calculate_smart_time_should_fallback_when_target_not_found', 0, () => {
      // Arrange
      const events: EventEntity[] = [buildEvent(1, 1, '09:00', 20, 0, 0)];
      // Act
      const suggested = IndexAddDialogHelper.calculateSmartTime(events, 999);
      // Assert
      expect(suggested).assertEqual('09:00');
    });

    it('conflict: recommend_add_by_day_offset_should_fallback_when_day_has_no_schedule', 0, () => {
      // Arrange
      const events: EventEntity[] = [
        buildEvent(1, 1, '09:00', 30, 0, 0),
        buildEvent(2, 0, '11:00', 30, 1, 1)
      ];
      // Act
      const suggested = IndexAddDialogHelper.recommendAddByDayOffset(events, 2);
      // Assert
      expect(suggested).assertEqual('08:00');
    });

    it('regression: resolve_defaults_should_prefer_latest_scheduled_event_by_id', 0, () => {
      // Arrange
      const oldScheduled = buildEvent(2, 1, '09:10', 20, 1, 1);
      const latestScheduled = buildEvent(8, 1, '12:00', 45, 2, 3);
      const backlog = buildEvent(9, 0, '13:00', 30, 4, 4);
      const events: EventEntity[] = [oldScheduled, backlog, latestScheduled];
      // Act
      const defaults = IndexAddDialogHelper.resolveAddDialogDefaults(events);
      // Assert
      expect(defaults.dayOffset).assertEqual(3);
      expect(defaults.suggestedTime).assertEqual('12:45');
    });

    it('combined: recommend_add_by_day_offset_should_use_same_day_last_anchor_end_time', 0, () => {
      // Arrange
      const first = buildEvent(1, 1, '09:00', 30, 0, 1);
      const second = buildEvent(2, 1, '10:00', 20, 0, 1);
      const third = buildEvent(3, 1, '11:10', 25, 0, 2);
      const events: EventEntity[] = [first, second, third];
      // Act
      const suggested = IndexAddDialogHelper.recommendAddByDayOffset(events, 1);
      // Assert
      expect(suggested).assertEqual('10:20');
    });
  });
}
