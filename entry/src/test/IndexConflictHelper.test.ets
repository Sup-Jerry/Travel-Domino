import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexConflictHelper } from '../main/ets/pages/index/IndexConflictHelper';
import { CompressionPlan, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface SaveConflictVm {
  updateEventInfo(
    id: number,
    name: string,
    duration: number,
    fixedTime: string | undefined,
    dayOffset: number,
    isLocked: boolean,
    note: string,
    priority: number,
    latitude: number,
    longitude: number
  ): Promise<void>;
}

interface ActionConflictVm {
  events: EventEntity[];
  calculateDelayPlan(targetIndex: number): CompressionPlan;
}

class SaveConflictVmMock implements SaveConflictVm {
  public called: boolean = false;
  public receivedDayOffset: number = -1;
  private readonly event: EventEntity;

  constructor(event: EventEntity) {
    this.event = event;
  }

  async updateEventInfo(
    id: number,
    name: string,
    duration: number,
    fixedTime: string | undefined,
    dayOffset: number,
    _isLocked: boolean,
    _note: string,
    _priority: number,
    _latitude: number,
    _longitude: number
  ): Promise<void> {
    this.called = id === this.event.id && name === this.event.name && duration === this.event.duration && fixedTime === '10:20';
    this.receivedDayOffset = dayOffset;
  }
}

class ActionConflictVmMock implements ActionConflictVm {
  public events: EventEntity[];
  private readonly delayPlan: CompressionPlan;

  constructor(events: EventEntity[], plan: CompressionPlan) {
    this.events = events;
    this.delayPlan = plan;
  }

  calculateDelayPlan(_targetIndex: number): CompressionPlan {
    return this.delayPlan;
  }
}

function buildConflictEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `E${id}`;
  event.status = 1;
  event.duration = 30;
  event.fixed_start_time = '09:00';
  event.computed_time = '09:00';
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.lock_status = 0;
  return event;
}

export default function indexConflictHelperTest() {
  describe('unit_test_case_generator_autofill_IndexConflictHelper', () => {
    it('normal: resolve_conflict_gap_should_prefer_gap_minutes_field', 0, () => {
      // Arrange
      const event = buildConflictEvent(1);
      event.gap_minutes = 15;
      event.conflict_msg = '仍冲突 40 分钟';
      // Act
      const gap = IndexConflictHelper.resolveConflictGapMinutes(event, 5);
      // Assert
      expect(gap).assertEqual(15);
    });

    it('boundary: resolve_conflict_gap_should_parse_positive_number_from_message', 0, () => {
      // Arrange
      const event = buildConflictEvent(2);
      event.gap_minutes = 0;
      event.conflict_msg = '仍有 22 分钟冲突';
      // Act
      const gap = IndexConflictHelper.resolveConflictGapMinutes(event, 3);
      // Assert
      expect(gap).assertEqual(22);
    });

    it('invalid: resolve_conflict_gap_should_fallback_to_zero_when_all_invalid', 0, () => {
      // Arrange
      const event = buildConflictEvent(3);
      event.gap_minutes = 0;
      event.conflict_msg = '无有效数字';
      // Act
      const gap = IndexConflictHelper.resolveConflictGapMinutes(event, -1);
      // Assert
      expect(gap).assertEqual(0);
    });

    it('conflict: get_conflict_target_time_should_use_default_when_time_invalid', 0, () => {
      // Arrange
      const event = buildConflictEvent(4);
      event.fixed_start_time = 'bad-time';
      event.computed_time = '';
      // Act
      const targetTime = IndexConflictHelper.getConflictTargetTime(event);
      // Assert
      expect(targetTime).assertEqual('09:00');
    });

    it('regression: save_conflict_time_should_call_update_event_info_with_resolved_day_offset', 0, async (done: Function) => {
      // Arrange
      const event = buildConflictEvent(5);
      event.dynamic_day_offset = 2;
      event.day_offset = 0;
      let doneCalled = false;
      const vm = new SaveConflictVmMock(event);
      // Act
      await IndexConflictHelper.saveConflictTime(vm as Object as TimelineViewModel, event, '10:20', () => {
        doneCalled = true;
      });
      // Assert
      expect(vm.called).assertTrue();
      expect(vm.receivedDayOffset).assertEqual(2);
      expect(doneCalled).assertTrue();
      done();
    });

    it('combined: handle_event_conflict_action_should_route_delay_strategy_to_preview', 0, () => {
      // Arrange
      const event = buildConflictEvent(6);
      const plan: CompressionPlan = {
        status: 'COMPRESS_CONFIRM',
        msg: '',
        affectedItems: []
      };
      const vm = new ActionConflictVmMock([event], plan);

      let previewCalled = false;
      let advanceCalled = false;
      let compressCalled = false;
      let menuCalled = false;

      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        event,
        'delay',
        18,
        undefined,
        (_index: number, _target: EventEntity, _targetTime: string, incomingPlan: CompressionPlan) => {
          previewCalled = incomingPlan.status === 'COMPRESS_CONFIRM';
        },
        () => {
          advanceCalled = true;
        },
        () => {
          compressCalled = true;
        },
        () => {
          menuCalled = true;
        }
      );

      // Assert
      expect(previewCalled).assertTrue();
      expect(advanceCalled).assertFalse();
      expect(compressCalled).assertFalse();
      expect(menuCalled).assertFalse();
    });
  });
}
