import { describe, expect, it } from '@ohos/hypium';
import { TimelineHistoryManager } from '../main/ets/viewmodel/managers/TimelineHistoryManager';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

function createScheduleEvent(id: number, name: string, dayOffset: number, sortOrder: number): EventEntity {
  const item = new EventEntity(name, 1);
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

export default function timelineHistoryManagerTest() {
  describe('timelineHistoryManagerTest', () => {
    it('normal: get_place_address_should_return_first_non_empty_address', 0, () => {
      // Arrange
      const a = createScheduleEvent(1, '西湖', 0, 100);
      const b = createScheduleEvent(2, '西湖', 1, 100);
      a.address = '  ';
      b.address = '杭州市西湖区龙井路';
      const manager = new TimelineHistoryManager({ events: [a, b], planId: 1, planName: '杭州行' });
      // Act
      const address = manager.getPlaceAddress('西湖');
      // Assert
      expect(address).assertEqual('杭州市西湖区龙井路');
    });

    it('boundary: get_place_address_should_fallback_to_dash_when_all_addresses_are_empty', 0, () => {
      // Arrange
      const a = createScheduleEvent(3, '外滩', 0, 100);
      const b = createScheduleEvent(4, '外滩', 1, 100);
      a.address = ' ';
      b.address = '';
      const manager = new TimelineHistoryManager({ events: [a, b], planId: 11, planName: '上海行' });
      // Act
      const address = manager.getPlaceAddress('外滩');
      // Assert
      expect(address).assertEqual('-');
    });

    it('boundary: get_current_plan_history_timeline_items_should_use_default_threshold_when_invalid', 0, () => {
      // Arrange
      const event = createScheduleEvent(10, '博物馆', 0, 100);
      event.dynamic_start_time = 10_000;
      event.actual_start_time = 10_000 + 10 * 60 * 1000;
      const manager = new TimelineHistoryManager({ events: [event], planId: 2, planName: '上海行' });
      // Act
      const items = manager.getCurrentPlanHistoryTimelineItems(0);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].isAbnormal).assertTrue();
    });

    it('invalid: get_latest_event_for_place_should_return_null_when_place_not_found', 0, () => {
      // Arrange
      const event = createScheduleEvent(20, '东方明珠', 0, 100);
      const manager = new TimelineHistoryManager({ events: [event], planId: 3, planName: '浦东行' });
      // Act
      const latest = manager.getLatestEventForPlace('外滩');
      // Assert
      expect(latest === null).assertTrue();
    });

    it('conflict: get_latest_event_for_place_should_break_ties_by_id_when_ts_equal', 0, () => {
      // Arrange
      const olderId = createScheduleEvent(30, '钟楼', 0, 100);
      const newerId = createScheduleEvent(31, '钟楼', 1, 100);
      olderId.actual_end_time = 9_000;
      newerId.actual_end_time = 9_000;
      const manager = new TimelineHistoryManager({ events: [olderId, newerId], planId: 4, planName: '西安行' });
      // Act
      const latest = manager.getLatestEventForPlace('钟楼');
      // Assert
      expect(latest !== null).assertTrue();
      expect(latest?.id || 0).assertEqual(31);
    });

    it('boundary: get_latest_event_for_place_should_use_actual_start_time_and_filter_unscheduled_items', 0, () => {
      // Arrange
      const unscheduled = createScheduleEvent(32, '城墙', 0, 100);
      unscheduled.status = 0;
      unscheduled.actual_end_time = 99_000;
      const byStartTime = createScheduleEvent(33, '城墙', 0, 200);
      byStartTime.actual_start_time = 8_000;
      const byEndTime = createScheduleEvent(34, '城墙', 0, 300);
      byEndTime.actual_end_time = 7_000;
      const manager = new TimelineHistoryManager({ events: [unscheduled, byEndTime, byStartTime], planId: 12, planName: '西安行' });
      // Act
      const latest = manager.getLatestEventForPlace('城墙');
      // Assert
      expect(latest !== null).assertTrue();
      expect(latest?.id || 0).assertEqual(33);
    });

    it('regression: td-20260411-c4-history-items-should-sort-by-display-time', 0, () => {
      // Arrange
      const first = createScheduleEvent(40, 'A', 0, 100);
      first.dynamic_start_time = 1_000;
      first.actual_start_time = 2_000;
      const second = createScheduleEvent(41, 'B', 0, 200);
      second.dynamic_start_time = 2_000;
      second.actual_start_time = 6_000;
      second.actual_end_time = 7_000;
      const manager = new TimelineHistoryManager({ events: [second, first], planId: 5, planName: '排序回归' });
      // Act
      const items = manager.getCurrentPlanHistoryTimelineItems();
      // Assert
      expect(items.length).assertEqual(3);
      expect(items[0].eventId).assertEqual(40);
      expect(items[1].eventId).assertEqual(41);
      expect(items[2].eventId).assertEqual(41);
    });

    it('combined: history_summary_and_items_should_cover_completed_skipped_and_active', 0, () => {
      // Arrange
      const completed = createScheduleEvent(50, '景点A', 0, 100);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      completed.dynamic_start_time = 10_000;
      completed.actual_start_time = 11_000;
      completed.actual_end_time = 12_000;

      const skipped = createScheduleEvent(51, '景点B', 0, 200);
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      skipped.dynamic_start_time = 20_000;
      skipped.actual_end_time = 20_100;

      const active = createScheduleEvent(52, '景点C', 0, 300);
      active.dynamic_start_time = 30_000;
      active.actual_start_time = 31_000;

      const manager = new TimelineHistoryManager({ events: [completed, skipped, active], planId: 6, planName: '综合场景' });
      // Act
      const summary = manager.getCurrentPlanHistorySummary();
      const items = manager.getCurrentPlanHistoryTimelineItems();
      // Assert
      expect(summary.planName).assertEqual('综合场景');
      expect(summary.completedCount).assertEqual(1);
      expect(summary.skippedCount).assertEqual(1);
      expect(summary.activeCount).assertEqual(1);
      expect(items.some((item) => item.actionType === 'LEAVE')).assertTrue();
      expect(items.some((item) => item.actionType === 'SKIP')).assertTrue();
      expect(items.some((item) => item.actionType === 'ACTIVE')).assertTrue();
    });

    it('combined: history_items_should_filter_unscheduled_and_keep_normal_arrive_leave_not_abnormal', 0, () => {
      // Arrange
      const hidden = createScheduleEvent(60, '隐藏点', 0, 50);
      hidden.status = 0;
      hidden.actual_start_time = 2_000;
      hidden.actual_end_time = 3_000;

      const normal = createScheduleEvent(61, '正常点', 0, 100);
      normal.dynamic_start_time = 20 * 60 * 1000;
      normal.actual_start_time = 23 * 60 * 1000;
      normal.actual_end_time = 53 * 60 * 1000;
      normal.address = '  ';
      normal.note = '  ';

      const manager = new TimelineHistoryManager({ events: [hidden, normal], planId: 13, planName: '普通行程' });
      // Act
      const items = manager.getCurrentPlanHistoryTimelineItems(10);
      // Assert
      expect(items.length).assertEqual(2);
      expect(items[0].eventId).assertEqual(61);
      expect(items[0].actionType).assertEqual('ARRIVE');
      expect(items[1].actionType).assertEqual('LEAVE');
      expect(items[0].isAbnormal).assertFalse();
      expect(items[0].address).assertEqual('');
      expect(items[0].note).assertEqual('');
    });

    it('boundary: history_items_should_use_unknown_group_key_when_skip_has_no_available_timestamp', 0, () => {
      // Arrange
      const skipped = createScheduleEvent(62, '未知跳过点', 0, 100);
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      const manager = new TimelineHistoryManager({ events: [skipped], planId: 14, planName: '未知时间行程' });
      // Act
      const items = manager.getCurrentPlanHistoryTimelineItems();
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].actionType).assertEqual('SKIP');
      expect(items[0].groupDateKey).assertEqual('未定');
      expect(items[0].displayTs).assertEqual(0);
    });
  });
}
