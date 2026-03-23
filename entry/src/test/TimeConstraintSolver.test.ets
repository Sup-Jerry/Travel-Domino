import { describe, it, expect } from '@ohos/hypium';
import { TimeConstraintSolver } from '../main/ets/domain/solver/TimeConstraintSolver';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildScheduleItem(id: number, name: string, duration: number, dayOffset: number, fixedStart: string = '', lock: number = 0): TravelPlanItem {
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

export default function timeConstraintSolverTest() {
  describe('timeConstraintSolverTest', () => {
    it('solver_should_cross_day_on_23xx_to_00xx_boundary', 0, () => {
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

    it('solver_should_keep_rigid_anchor_time_and_mark_conflict', 0, () => {
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

    it('solver_should_keep_original_array_order_stable', 0, () => {
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
  });
}
