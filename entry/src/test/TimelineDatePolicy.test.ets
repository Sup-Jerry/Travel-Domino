import { describe, it, expect } from '@ohos/hypium';
import { TimelineDatePolicy } from '../main/ets/domain/policy/TimelineDatePolicy';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface TimelineViewModelInternal {
  insertSmart: (newEntity: EventEntity) => void;
}

function buildEvent(id: number, dayOffset: number, dynamicDayOffset: number, time: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `E${id}`;
  event.status = 1;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dynamicDayOffset;
  event.fixed_start_time = time;
  event.computed_time = time;
  event.sort_order = id * 100;
  return event;
}

export default function timelineDatePolicyTest() {
  describe('timelineDatePolicyTest', () => {
    it('normal: resolve_day_offset_should_prefer_dynamic_value', 0, () => {
      // Arrange
      // Act
      // Assert
      const resolved = TimelineDatePolicy.resolveDayOffset(2, 0);
      expect(resolved).assertEqual(2);
    });

    it('boundary: resolve_day_offset_should_fallback_to_day_offset_when_dynamic_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const dynamicValue: number | undefined = undefined;
      const resolved = TimelineDatePolicy.resolveDayOffset(dynamicValue, 3);
      expect(resolved).assertEqual(3);
    });

    it('boundary: resolve_day_offset_should_return_zero_when_all_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const dynamicValue: number | undefined = undefined;
      const dayValue: number | undefined = undefined;
      const resolved = TimelineDatePolicy.resolveDayOffset(dynamicValue, dayValue);
      expect(resolved).assertEqual(0);
    });

    it('normal: insert_smart_should_order_by_resolved_day_offset', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.events = [
        buildEvent(1, 0, 0, '09:00'),
        buildEvent(2, 0, 2, '09:00')
      ];

      const newEntity = buildEvent(3, 1, 1, '08:30');
      const internalVm = vm as Object as TimelineViewModelInternal;
      internalVm.insertSmart(newEntity);

      expect(vm.events.length).assertEqual(3);
      expect(vm.events[0].id).assertEqual(1);
      expect(vm.events[1].id).assertEqual(3);
      expect(vm.events[2].id).assertEqual(2);
    });
  });
  describe('unit_test_case_generator_backfill_TimelineDatePolicy', () => {
    it('invalid: build_planned_timestamp_should_fallback_to_0000_for_invalid_time_text', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T09:00:00').getTime();
      const expected = new Date('2026-01-02T00:00:00').getTime();
      // Act
      const actual = TimelineDatePolicy.buildPlannedTimestamp(planStart, 1, 'bad-time');
      // Assert
      expect(actual).assertEqual(expected);
    });

    it('conflict: resolve_event_day_offset_should_prioritize_dynamic_over_base_day_offset', 0, () => {
      // Arrange
      const event = buildEvent(9, 0, 3, '09:00');
      // Act
      const resolved = TimelineDatePolicy.resolveEventDayOffset(event);
      // Assert
      expect(resolved).assertEqual(3);
    });

    it('regression: td-20260411-timestamp_to_day_offset_should_handle_cross_month_boundary', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-31T08:00:00').getTime();
      const nextMonthTs = new Date('2026-02-01T09:00:00').getTime();
      // Act
      const offset = TimelineDatePolicy.timestampToDayOffset(planStart, nextMonthTs);
      // Assert
      expect(offset).assertEqual(1);
    });

    it('combined: build_planned_timestamp_should_apply_day_offset_and_next_day_shift_together', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T09:00:00').getTime();
      const expected = new Date('2026-01-03T01:30:00').getTime();
      // Act
      const timestamp = TimelineDatePolicy.buildPlannedTimestamp(planStart, 1, '次日 01:30');
      const dayDate = TimelineDatePolicy.dayOffsetToDate(planStart, 2);
      // Assert
      expect(timestamp).assertEqual(expected);
      expect(dayDate.getDate()).assertEqual(3);
    });

    it('boundary: day_offset_to_day_start_ms_should_fallback_to_current_day_when_plan_start_non_positive', 0, () => {
      // Arrange
      const before = TimelineDatePolicy.toDayStartMs(Date.now());

      // Act
      const actual = TimelineDatePolicy.dayOffsetToDayStartMs(0, 2);

      // Assert
      const after = TimelineDatePolicy.toDayStartMs(Date.now());
      const expectedFromBefore = before + 2 * 24 * 60 * 60 * 1000;
      const expectedFromAfter = after + 2 * 24 * 60 * 60 * 1000;
      expect(actual === expectedFromBefore || actual === expectedFromAfter).assertTrue();
    });
  });
}
