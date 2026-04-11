import { describe, expect, it } from '@ohos/hypium';
import { TimelineExecutionCoordinator } from '../main/ets/viewmodel/coordinators/TimelineExecutionCoordinator';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

function createScheduleEvent(id: number, dayOffset: number, sortOrder: number): EventEntity {
  const item = new EventEntity(`event_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.day_offset = dayOffset;
  item.dynamic_day_offset = dayOffset;
  item.sort_order = sortOrder;
  item.completion_status = EventEntity.STATE_PENDING;
  item.actual_start_time = 0;
  item.actual_end_time = 0;
  return item;
}

export default function timelineExecutionCoordinatorTest() {
  describe('timelineExecutionCoordinatorTest', () => {
    it('normal: get_ordered_schedule_events_should_sort_by_day_and_order', 0, () => {
      // Arrange
      const e1 = createScheduleEvent(1, 1, 100);
      const e2 = createScheduleEvent(2, 0, 200);
      const e3 = createScheduleEvent(3, 0, 100);
      const backlog = createScheduleEvent(4, 0, 10);
      backlog.status = 0;
      const coordinator = new TimelineExecutionCoordinator({ events: [e1, e2, backlog, e3] });
      // Act
      const ordered = coordinator.getOrderedScheduleEvents();
      // Assert
      expect(ordered.length).assertEqual(3);
      expect(ordered[0].id).assertEqual(3);
      expect(ordered[1].id).assertEqual(2);
      expect(ordered[2].id).assertEqual(1);
    });

    it('boundary: get_ordered_schedule_index_should_return_zero_for_first_item', 0, () => {
      // Arrange
      const e1 = createScheduleEvent(10, 0, 100);
      const e2 = createScheduleEvent(11, 0, 200);
      const coordinator = new TimelineExecutionCoordinator({ events: [e2, e1] });
      const ordered = coordinator.getOrderedScheduleEvents();
      // Act
      const idx = coordinator.getOrderedScheduleIndexById(10, ordered);
      // Assert
      expect(idx).assertEqual(0);
    });

    it('invalid: get_next_executable_event_should_return_null_when_anchor_not_found', 0, () => {
      // Arrange
      const e1 = createScheduleEvent(20, 0, 100);
      const e2 = createScheduleEvent(21, 0, 200);
      const coordinator = new TimelineExecutionCoordinator({ events: [e1, e2] });
      const ordered = coordinator.getOrderedScheduleEvents();
      // Act
      const next = coordinator.getNextExecutableEvent(999, ordered);
      // Assert
      expect(next === null).assertTrue();
    });

    it('conflict: get_next_executable_event_should_skip_non_startable_items', 0, () => {
      // Arrange
      const current = createScheduleEvent(30, 0, 100);
      const active = createScheduleEvent(31, 0, 200);
      active.actual_start_time = Date.now();
      active.actual_end_time = 0;
      const completed = createScheduleEvent(32, 0, 300);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const pending = createScheduleEvent(33, 0, 400);
      const coordinator = new TimelineExecutionCoordinator({ events: [current, active, completed, pending] });
      const ordered = coordinator.getOrderedScheduleEvents();
      // Act
      const next = coordinator.getNextExecutableEvent(30, ordered);
      // Assert
      expect(next !== null).assertTrue();
      expect(next?.id || 0).assertEqual(33);
    });

    it('regression: td-20260411-c4-first-scheduled-item-should-detect-day-boundary', 0, () => {
      // Arrange
      const day0 = createScheduleEvent(40, 0, 100);
      const day1First = createScheduleEvent(41, 1, 100);
      const day1Second = createScheduleEvent(42, 1, 200);
      const coordinator = new TimelineExecutionCoordinator({ events: [day0, day1Second, day1First] });
      // Act
      const firstOfDay1 = coordinator.isFirstScheduledItemOfDay(day1First);
      const secondOfDay1 = coordinator.isFirstScheduledItemOfDay(day1Second);
      // Assert
      expect(firstOfDay1).assertTrue();
      expect(secondOfDay1).assertFalse();
    });

    it('combined: build_reflow_hint_should_cover_skip_shift_and_reflow', 0, () => {
      // Arrange
      const coordinator = new TimelineExecutionCoordinator({ events: [] });
      // Act
      const skipHint = coordinator.buildReflowHint('skip', 0, 0, '故宫', '天坛');
      const shiftHint = coordinator.buildReflowHint('start', 1_000, 1_000 + 15 * 60 * 1000, 'A', 'B');
      const reflowHint = coordinator.buildReflowHint('end', 0, 0, 'A', '');
      // Assert
      expect(skipHint.type).assertEqual('next_changed');
      expect(skipHint.message.includes('下一站改为 天坛')).assertTrue();
      expect(shiftHint.type).assertEqual('shift');
      expect(shiftHint.minutesDelta).assertEqual(15);
      expect(reflowHint.type).assertEqual('reflow');
    });
  });
}
