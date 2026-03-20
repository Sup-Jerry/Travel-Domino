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
    it('resolve_day_offset_should_prefer_dynamic_value', 0, () => {
      const resolved = TimelineDatePolicy.resolveDayOffset(2, 0);
      expect(resolved).assertEqual(2);
    });

    it('resolve_day_offset_should_fallback_to_day_offset_when_dynamic_missing', 0, () => {
      const dynamicValue: number | undefined = undefined;
      const resolved = TimelineDatePolicy.resolveDayOffset(dynamicValue, 3);
      expect(resolved).assertEqual(3);
    });

    it('resolve_day_offset_should_return_zero_when_all_missing', 0, () => {
      const dynamicValue: number | undefined = undefined;
      const dayValue: number | undefined = undefined;
      const resolved = TimelineDatePolicy.resolveDayOffset(dynamicValue, dayValue);
      expect(resolved).assertEqual(0);
    });

    it('insert_smart_should_order_by_resolved_day_offset', 0, () => {
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
}
