import { describe, it, expect } from '@ohos/hypium';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import { TimeConstraintSolver } from '../main/ets/domain/solver/TimeConstraintSolver';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildItem(id: number, name: string, dayOffset: number, sortOrder: number): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.id = id;
  item.name = name;
  item.note = '';
  item.duration = 60;
  item.travelMode = 2;
  item.preTravelMinutes = 0;
  item.isTravelManual = 1;
  item.status = 1;
  item.lockStatus = 0;
  item.fixedStartTime = '';
  item.dayOffset = dayOffset;
  item.sortOrder = sortOrder;
  item.itemType = 0;
  item.priority = 0;
  item.latitude = 0;
  item.longitude = 0;
  item.source = 0;
  item.address = '';
  item.aiReasoning = '';
  item.groupId = 0;
  item.delFlag = 0;
  item.actualStartTime = 0;
  item.actualEndTime = 0;
  item.completionStatus = 0;
  item.type = 'FLOW';
  return item;
}

export default function scheduleOrchestratorTest() {
  describe('scheduleOrchestratorTest', () => {
    it('calculate_should_delegate_to_solver_without_behavior_change', 0, (done: () => void) => {
      const input = [
        buildItem(1, 'A', 0, 100),
        buildItem(2, 'B', 0, 200)
      ];
      const orchestrator = new ScheduleOrchestrator();
      const byOrchestrator = orchestrator.calculate(input, '09:00', 1735660800000, {
        autoRouteEnabled: false
      });
      const bySolver = TimeConstraintSolver.calculateTimeline(input, '09:00', 1735660800000, {
        autoRouteEnabled: false
      });
      expect(JSON.stringify(byOrchestrator)).assertEqual(JSON.stringify(bySolver));
      done();
    });
  });
}
