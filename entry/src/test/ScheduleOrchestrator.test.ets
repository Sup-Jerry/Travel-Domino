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
    it('normal: calculate_should_delegate_to_solver_without_behavior_change', 0, (done: () => void) => {
      // Arrange
      // Act
      // Assert
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
  describe('unit_test_case_generator_autofill_ScheduleOrchestrator', () => {
    it('boundary: calculate_should_keep_empty_result_for_empty_input', 0, () => {
      // Arrange
      const orchestrator = new ScheduleOrchestrator();
      const events: TravelPlanItem[] = [];

      // Act
      const byOrchestrator = orchestrator.calculate(events, '09:00', 1735660800000, {
        autoRouteEnabled: false
      });
      const bySolver = TimeConstraintSolver.calculateTimeline(events, '09:00', 1735660800000, {
        autoRouteEnabled: false
      });

      // Assert
      expect(JSON.stringify(byOrchestrator)).assertEqual(JSON.stringify(bySolver));
      expect(byOrchestrator.length).assertEqual(0);
    });

    it('invalid: calculate_should_match_solver_even_with_invalid_global_start_time', 0, () => {
      // Arrange
      const orchestrator = new ScheduleOrchestrator();
      const input = [
        buildItem(11, 'InvalidStartA', 0, 100),
        buildItem(12, 'InvalidStartB', 0, 200)
      ];

      // Act
      const byOrchestrator = orchestrator.calculate(input, 'bad_time', 1735660800000, {
        autoRouteEnabled: false
      });
      const bySolver = TimeConstraintSolver.calculateTimeline(input, 'bad_time', 1735660800000, {
        autoRouteEnabled: false
      });

      // Assert
      expect(JSON.stringify(byOrchestrator)).assertEqual(JSON.stringify(bySolver));
    });

    it('conflict: calculate_should_preserve_solver_behavior_for_cross_day_and_same_order_items', 0, () => {
      // Arrange
      const orchestrator = new ScheduleOrchestrator();
      const input = [
        buildItem(21, 'DayOne', 0, 100),
        buildItem(22, 'DayTwo', 1, 100)
      ];

      // Act
      const byOrchestrator = orchestrator.calculate(input, '23:30', 1735660800000, {
        autoRouteEnabled: false
      });
      const bySolver = TimeConstraintSolver.calculateTimeline(input, '23:30', 1735660800000, {
        autoRouteEnabled: false
      });

      // Assert
      expect(JSON.stringify(byOrchestrator)).assertEqual(JSON.stringify(bySolver));
      expect(byOrchestrator.length).assertEqual(2);
    });

    it('regression: calculate_should_not_mutate_delegation_consistency_when_route_option_enabled', 0, () => {
      // Arrange
      const orchestrator = new ScheduleOrchestrator();
      const input = [
        buildItem(31, 'RouteOnA', 0, 100),
        buildItem(32, 'RouteOnB', 0, 200)
      ];

      // Act
      const byOrchestrator = orchestrator.calculate(input, '08:30', 1735660800000, {
        autoRouteEnabled: true
      });
      const bySolver = TimeConstraintSolver.calculateTimeline(input, '08:30', 1735660800000, {
        autoRouteEnabled: true
      });

      // Assert
      expect(JSON.stringify(byOrchestrator)).assertEqual(JSON.stringify(bySolver));
    });

    it('combined: calculate_should_coordinate_multi_day_items_and_route_toggle_without_behavior_drift', 0, () => {
      // Arrange
      const orchestrator = new ScheduleOrchestrator();
      const input = [
        buildItem(41, 'ComboA', 0, 100),
        buildItem(42, 'ComboB', 0, 200),
        buildItem(43, 'ComboC', 1, 100)
      ];

      // Act
      const byOrchestrator = orchestrator.calculate(input, '07:45', 1735660800000, {
        autoRouteEnabled: true
      });
      const bySolver = TimeConstraintSolver.calculateTimeline(input, '07:45', 1735660800000, {
        autoRouteEnabled: true
      });

      // Assert
      expect(JSON.stringify(byOrchestrator)).assertEqual(JSON.stringify(bySolver));
      expect(byOrchestrator.length).assertEqual(3);
    });
  });
}
