import { describe, expect, it } from '@ohos/hypium';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class SaveAllEventsHookCZ {
  private readonly originalSaveAllEvents: Object;

  constructor() {
    this.originalSaveAllEvents = Reflect.get(EventRepositoryImpl as Object, 'saveAllEvents') as Object;
  }

  failWith(message: string): void {
    Reflect.set(EventRepositoryImpl as Object, 'saveAllEvents', async (_planId: number, _items: TravelPlanItem[]): Promise<void> => {
      throw new Error(message);
    });
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl as Object, 'saveAllEvents', this.originalSaveAllEvents);
  }
}

function createEventCZ(id: number, name: string, dayOffset: number, sortOrder: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.plan_id = 9900;
  event.status = 1;
  event.duration = 30;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dayOffset;
  event.sort_order = sortOrder;
  return event;
}

export default function phase2BatchCZTest() {
  describe('phase2BatchCZ_timeline_viewmodel_tail_anonymous_functions', () => {
    it('regression: failed_save_should_route_through_save_queue_catch_handler', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const hook = new SaveAllEventsHookCZ();
      vm.planId = 9900;
      vm.events = [createEventCZ(9901, 'save_fail_cz', 0, 1)];
      hook.failWith('save_fail_cz');
      try {
        // Act
        let failed = false;
        try {
          await vm.save();
        } catch (_error) {
          failed = true;
        }
        await new Promise<void>((resolve) => {
          setTimeout(() => resolve(), 0);
        });

        // Assert
        expect(failed).assertTrue();
      } finally {
        hook.restore();
      }
    });

    it('combined: sorted_gaps_should_order_multiple_same_day_gaps_by_gap_minutes', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const first = createEventCZ(9911, 'first_cz', 0, 1);
      const smallGap = createEventCZ(9912, 'small_gap_cz', 0, 2);
      const largeGap = createEventCZ(9913, 'large_gap_cz', 0, 3);
      smallGap.has_gap = true;
      smallGap.gap_minutes = 35;
      largeGap.has_gap = true;
      largeGap.gap_minutes = 65;
      vm.events = [largeGap, first, smallGap];
      Reflect.set(vm as Object, 'idleGapDetectionEnabled', true);
      Reflect.set(vm as Object, 'idleGapTriggerMinutes', 30);

      // Act
      const gaps = vm.getSortedGaps();

      // Assert
      expect(gaps.length).assertEqual(2);
      expect(gaps[0].id).assertEqual(9913);
      expect(gaps[1].id).assertEqual(9912);
    });
  });
}
