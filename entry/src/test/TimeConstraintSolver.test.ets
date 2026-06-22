import { describe, it, expect } from '@ohos/hypium';
import { TimeConstraintSolver } from '../main/ets/domain/solver/TimeConstraintSolver';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildScheduleItem(
  id: number,
  name: string,
  duration: number,
  dayOffset: number,
  fixedStart: string = '',
  lock: number = 0,
  source: number = 0,
  itemType: number = 0
): TravelPlanItem {
  return {
    id: id,
    name: name,
    note: '',
    duration: duration,
    type: fixedStart ? 'ANCHOR' : 'FLOW',
    preTravelMinutes: 0,
    sortOrder: id * 100,
    status: 1,
    lockStatus: lock,
    fixedStartTime: fixedStart,
    dayOffset: dayOffset,
    itemType: itemType,
    priority: 0,
    transportMode: 2,
    travelMode: 2,
    isTravelManual: 1,
    source: source,
    delFlag: 0,
    groupId: 0,
    address: '',
    aiReasoning: '',
    latitude: 0,
    longitude: 0,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0
  };
}

function buildBacklogItem(id: number, name: string): TravelPlanItem {
  return {
    id: id,
    name: name,
    note: '',
    duration: 30,
    type: 'FLOW',
    preTravelMinutes: 0,
    sortOrder: id * 100,
    status: 0,
    lockStatus: 0,
    fixedStartTime: '',
    dayOffset: 0,
    itemType: 0,
    priority: 0,
    transportMode: 2,
    travelMode: 2,
    isTravelManual: 1,
    source: 0,
    delFlag: 0,
    groupId: 0,
    address: '',
    aiReasoning: '',
    latitude: 0,
    longitude: 0,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0
  };
}

interface TimeConstraintSolverPrivateForTest {
  applyAiTimeWindow(baseTimestamp: number, startTimestamp: number, itemType?: number): number;
}

export default function timeConstraintSolverTest() {
  describe('timeConstraintSolverTest', () => {
    it('boundary: solver_should_cross_day_on_23xx_to_00xx_boundary', 0, () => {
      // Arrange
      // Act
      // Assert
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(1, 'A', 20, 0),
        buildScheduleItem(2, 'B', 30, 0)
      ];
      const result = TimeConstraintSolver.calculateTimeline(input, '23:50', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      const a: TravelPlanItem = result[0];
      const b: TravelPlanItem = result[1];
      expect(a.dynamicDayOffset ?? -1).assertEqual(0);
      expect(b.dynamicDayOffset ?? -1).assertEqual(1);
      const delta = Math.floor(((b.dynamicStartTime ?? 0) - (a.dynamicStartTime ?? 0)) / 60000);
      expect(delta).assertEqual(20);
    });

    it('conflict: solver_should_keep_rigid_anchor_time_and_mark_conflict', 0, () => {
      // Arrange
      // Act
      // Assert
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(1, 'A', 90, 0),
        buildScheduleItem(2, 'B', 30, 0, '10:00', 1)
      ];
      const result = TimeConstraintSolver.calculateTimeline(input, '09:00', planStart, {
        autoRouteEnabled: false
      });

      const anchor: TravelPlanItem = result[1];
      const expectedAnchorTs = new Date('2026-01-01T10:00:00').getTime();
      expect(anchor.dynamicStartTime ?? 0).assertEqual(expectedAnchorTs);
      expect(anchor.isConflict ?? false).assertEqual(true);
    });

    it('normal: solver_should_keep_original_array_order_stable', 0, () => {
      // Arrange
      // Act
      // Assert
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(11, 'S1', 30, 0),
        buildBacklogItem(99, 'Backlog'),
        buildScheduleItem(12, 'S2', 30, 0)
      ];
      const result = TimeConstraintSolver.calculateTimeline(input, '09:00', planStart, {
        autoRouteEnabled: false
      });

      expect(result.length).assertEqual(3);
      expect(result[0].id ?? 0).assertEqual(11);
      expect(result[1].id ?? 0).assertEqual(99);
      expect(result[2].id ?? 0).assertEqual(12);
    });

    it('normal: solver_should_move_ai_scenic_out_of_night_window', 0, () => {
      // Arrange
      // Act
      // Assert
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(1, '王府井', 60, 0, '', 0, 1, 0),
        buildScheduleItem(2, '故宫', 60, 0, '', 0, 1, 0)
      ];
      const result = TimeConstraintSolver.calculateTimeline(input, '23:00', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      const first = result[0];
      const second = result[1];
      expect(first.dynamicDayOffset ?? -1).assertEqual(1);
      expect(first.computedStartTime ?? '').assertEqual('01-02 08:00');
      expect(second.computedStartTime ?? '').assertEqual('09:00');
    });

    it('normal: solver_should_shift_following_item_to_next_day_when_travel_is_super_long', 0, () => {
      // Arrange
      // Act
      // Assert
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const first = buildScheduleItem(1, 'A', 60, 0, '', 0, 0, 0);
      const second = buildScheduleItem(2, 'B', 60, 0, '', 0, 0, 0);
      const third = buildScheduleItem(3, 'C', 60, 0, '', 0, 0, 0);
      first.preTravelMinutes = 0;
      second.preTravelMinutes = 0;
      third.preTravelMinutes = 38 * 60;
      const input = [first, second, third];

      const result = TimeConstraintSolver.calculateTimeline(input, '09:00', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      const eventThird = result[2];
      expect((eventThird.dynamicDayOffset ?? -1) > 0).assertTrue();
    });

    it('boundary: solver_should_extract_pure_time_from_datetime_like_global_start', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [buildScheduleItem(101, 'ExtractTime', 30, 0)];

      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, '2026-01-01 07:30', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      // Assert
      expect(result[0].computedStartTime ?? '').assertEqual('01-01 07:30');
    });

    it('boundary: solver_should_keep_ai_hotel_time_window_unchanged', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [buildScheduleItem(102, 'Hotel Night Checkin', 30, 0, '', 0, 1, 2)];

      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, '23:00', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      // Assert
      expect(result[0].computedStartTime ?? '').assertEqual('01-01 23:00');
      expect(result[0].dynamicDayOffset ?? -1).assertEqual(0);
    });

    it('boundary: solver_should_clamp_ai_food_start_to_food_window_minimum', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [buildScheduleItem(103, 'Breakfast', 30, 0, '', 0, 1, 1)];

      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, '05:30', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      // Assert
      expect(result[0].computedStartTime ?? '').assertEqual('01-01 06:00');
      expect(result[0].dynamicDayOffset ?? -1).assertEqual(0);
    });
  });
  describe('unit_test_case_generator_backfill_TimeConstraintSolver', () => {
    it('invalid: solver_should_fallback_to_default_start_when_global_time_invalid', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [buildScheduleItem(1, 'A', 30, 0)];
      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, 'not-a-time', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });
      // Assert
      expect(result[0].computedStartTime ?? '').assertEqual('01-01 08:00');
      const expectedTs = new Date('2026-01-01T08:00:00').getTime();
      expect(result[0].dynamicStartTime ?? 0).assertEqual(expectedTs);
    });

    it('regression: td-20260411-start-from-event-should-use-previous-dynamic-cursor', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const first = buildScheduleItem(1, 'A', 60, 0);
      first.dynamicStartTime = new Date('2026-01-01T09:00:00').getTime();
      first.dynamicDayOffset = 0;
      const second = buildScheduleItem(2, 'B', 30, 0);
      // Act
      const result = TimeConstraintSolver.calculateTimeline([first, second], '06:00', planStart, {
        autoRouteEnabled: false,
        startFromEventId: 2,
        slackRatio: 0
      });
      // Assert
      expect(result[1].computedStartTime ?? '').assertEqual('10:00');
      expect(result[1].dynamicDayOffset ?? -1).assertEqual(0);
    });

    it('combined: solver_should_mark_idle_gap_for_rigid_anchor_when_gap_detection_enabled', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(1, 'A', 30, 0),
        buildScheduleItem(2, 'Anchor', 30, 0, '12:00', 1)
      ];
      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, '09:00', planStart, {
        autoRouteEnabled: false,
        idleGapDetectionEnabled: true,
        idleGapTriggerMinutes: 45,
        slackRatio: 0
      });
      // Assert
      const anchor = result[1];
      expect(anchor.hasGap ?? false).assertEqual(true);
      expect((anchor.gapMinutes ?? 0) >= 120).assertEqual(true);
      expect(anchor.naturalStartTime ?? '').assertEqual('09:30');
    });

    it('combined: solver_should_mark_idle_gap_for_non_rigid_anchor_when_gap_detection_enabled', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(201, 'Warmup', 30, 0),
        buildScheduleItem(202, 'SoftAnchor', 30, 0, '12:00', 0)
      ];

      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, '09:00', planStart, {
        autoRouteEnabled: false,
        idleGapDetectionEnabled: true,
        idleGapTriggerMinutes: 45,
        slackRatio: 0
      });

      // Assert
      const anchor = result[1];
      expect(anchor.isConflict ?? false).assertFalse();
      expect(anchor.hasGap ?? false).assertTrue();
      expect(anchor.computedStartTime ?? '').assertEqual('12:00');
      expect(anchor.naturalStartTime ?? '').assertEqual('09:30');
    });

    it('regression: solver_should_not_start_a_following_free_item_before_selected_future_day', 0, () => {
      // Arrange
      const planStart = new Date('2026-01-01T00:00:00').getTime();
      const input = [
        buildScheduleItem(301, 'DayOne', 60, 0),
        buildScheduleItem(302, 'DayTwoSelected', 30, 1)
      ];

      // Act
      const result = TimeConstraintSolver.calculateTimeline(input, '09:00', planStart, {
        autoRouteEnabled: false,
        slackRatio: 0
      });

      // Assert
      expect(result[1].dynamicDayOffset ?? -1).assertEqual(1);
      expect(result[1].computedStartTime ?? '').assertEqual('01-02 09:00');
    });

    it('invalid: solver_private_ai_window_should_keep_unknown_item_type_unchanged', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;
      const base = new Date('2026-01-01T00:00:00').getTime();
      const start = new Date('2026-01-01T22:30:00').getTime();

      // Act
      const resolved = privateApi.applyAiTimeWindow(base, start, 99);

      // Assert
      expect(resolved).assertEqual(start);
    });
  });
}
