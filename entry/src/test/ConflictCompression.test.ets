import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

function buildEvent(
  id: number,
  name: string,
  duration: number,
  lockStatus: number = 0,
  fixedStartTime: string = '',
  preTravelMinutes: number = 0
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.duration = duration;
  event.status = 1;
  event.lock_status = lockStatus;
  event.fixed_start_time = fixedStartTime;
  event.pre_travel_min = preTravelMinutes;
  event.sort_order = id;
  return event;
}

function sumReduced(plan: import('../main/ets/viewmodel/TimelineViewModel').CompressionPlan): number {
  return plan.affectedItems.reduce((sum, item) => sum + (item.oldVal - item.newVal), 0);
}

export default function conflictCompressionTest() {
  describe('conflictCompressionTest', () => {
    it('ratio_mode_should_solve_when_min_limit_allows', 0, () => {
      const vm = new TimelineViewModel();
      vm.globalStartTime = '09:00';
      vm.events = [
        buildEvent(1, 'A', 120),
        buildEvent(2, 'B', 90),
        buildEvent(3, 'Target', 60, 1, '10:30')
      ];

      const plan = vm.compressionCoordinator.calculateCompressionPlanBySelection(2, '10:30', new Set<number>([1, 2]), 'RATIO');
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(plan.remainingGapMinutes ?? -1).assertEqual(0);
      expect(sumReduced(plan)).assertEqual(120);
    });

    it('equal_mode_should_distribute_close_reduction', 0, () => {
      const vm = new TimelineViewModel();
      vm.globalStartTime = '09:00';
      vm.events = [
        buildEvent(1, 'A', 120),
        buildEvent(2, 'B', 90),
        buildEvent(3, 'Target', 60, 1, '11:30')
      ];

      const plan = vm.compressionCoordinator.calculateCompressionPlanBySelection(2, '11:30', new Set<number>([1, 2]), 'EQUAL');
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(sumReduced(plan)).assertEqual(60);

      let firstReduced = 0;
      let secondReduced = 0;
      for (const item of plan.affectedItems) {
        if (item.index === 0) {
          firstReduced = item.oldVal - item.newVal;
        } else if (item.index === 1) {
          secondReduced = item.oldVal - item.newVal;
        }
      }
      expect(Math.abs(firstReduced - secondReduced) <= 1).assertEqual(true);
    });

    it('context_should_mark_rigid_candidate_unselectable', 0, () => {
      const vm = new TimelineViewModel();
      vm.globalStartTime = '09:00';
      vm.events = [
        buildEvent(1, 'Rigid', 60, 1, '09:30'),
        buildEvent(2, 'B', 100),
        buildEvent(3, 'Target', 60, 1, '10:00')
      ];

      const context = vm.compressionCoordinator.buildCompressionSelectionContext(2, '10:00');
      expect(context !== null).assertEqual(true);
      let rigid: import('../main/ets/viewmodel/TimelineViewModel').CompressionSelectionCandidate | undefined = undefined;
      if (context) {
        for (const candidate of context.candidates) {
          if (candidate.id === 1) {
            rigid = candidate;
            break;
          }
        }
      }
      expect(!!rigid).assertEqual(true);
      expect(rigid?.isRigid ?? false).assertEqual(true);
      expect(rigid?.selectable ?? true).assertEqual(false);
    });

    it('should_block_with_remaining_gap_when_selected_capacity_not_enough', 0, () => {
      const vm = new TimelineViewModel();
      vm.globalStartTime = '09:00';
      vm.events = [
        buildEvent(1, 'A', 120),
        buildEvent(2, 'B', 90),
        buildEvent(3, 'Target', 60, 1, '10:30')
      ];

      const plan = vm.compressionCoordinator.calculateCompressionPlanBySelection(2, '10:30', new Set<number>([2]), 'RATIO');
      expect(plan.status).assertEqual('OVERLOAD');
      expect(plan.remainingGapMinutes ?? 0).assertEqual(60);
      expect(plan.suggestedTime !== undefined).assertEqual(true);
    });

    it('should_compute_min_required_gap_for_rigid_target_conflict', 0, () => {
      const vm = new TimelineViewModel();
      vm.globalStartTime = '09:00';
      vm.events = [
        buildEvent(1, 'A', 60),
        buildEvent(2, 'B', 90),
        buildEvent(3, 'RigidTarget', 60, 1, '12:00', 60)
      ];

      const context = vm.compressionCoordinator.buildCompressionSelectionContext(2, '12:00');
      expect(context !== null).assertEqual(true);
      expect(context?.neededGapMinutes ?? -1).assertEqual(30);

      const plan = vm.compressionCoordinator.calculateCompressionPlanBySelection(2, '12:00', new Set<number>([1, 2]), 'RATIO');
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(sumReduced(plan)).assertEqual(30);
    });

    it('advance_preview_should_compare_shift_with_min_required_gap', 0, () => {
      const vm = new TimelineViewModel();
      vm.globalStartTime = '09:00';
      vm.events = [
        buildEvent(1, 'A', 60),
        buildEvent(2, 'B', 90),
        buildEvent(3, 'RigidTarget', 60, 1, '12:00', 60)
      ];

      const notEnough = vm.compressionCoordinator.previewAdvanceAdjust(2, new Set<number>([1, 2]), '08:40', 30);
      expect(notEnough.valid).assertEqual(true);
      expect(notEnough.requiredGapMinutes).assertEqual(30);
      expect(notEnough.remainingGapMinutes).assertEqual(10);

      const enough = vm.compressionCoordinator.previewAdvanceAdjust(2, new Set<number>([1, 2]), '08:30', 30);
      expect(enough.valid).assertEqual(true);
      expect(enough.requiredGapMinutes).assertEqual(30);
      expect(enough.remainingGapMinutes).assertEqual(0);
    });
  });
}
