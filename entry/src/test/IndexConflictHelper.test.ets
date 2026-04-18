import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexConflictHelper } from '../main/ets/pages/index/IndexConflictHelper';
import { IndexDialogManager } from '../main/ets/pages/index/IndexDialogManager';
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

class OpenCounterControllerMock {
  public openCount: number = 0;

  open(): void {
    this.openCount += 1;
  }
}

class ConflictPreviewMock {
  hasRigidConflict: boolean = false;
  conflictItemId: number = -1;
  gapMinutes: number = 0;
}

class DateShiftVmMock {
  public events: EventEntity[] = [];
  public updatePlanDateCalls: number = 0;
  public updatedDateMs: number = -1;
  public preview: ConflictPreviewMock = new ConflictPreviewMock();
  public updateEventInfoCalls: number = 0;

  previewPlanDateShift(_dateMs: number): ConflictPreviewMock {
    return this.preview;
  }

  updatePlanDate(dateMs: number): Promise<void> {
    this.updatePlanDateCalls += 1;
    this.updatedDateMs = dateMs;
    return Promise.resolve();
  }

  updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    _fixedTime: string | undefined,
    _dayOffset: number,
    _isLocked: boolean,
    _note: string,
    _priority: number,
    _latitude: number,
    _longitude: number
  ): Promise<void> {
    this.updateEventInfoCalls += 1;
    return Promise.resolve();
  }
}

class AdvanceContextMock {
  candidates: number[] = [];
}

class AdvanceResultMock {
  success: boolean = true;
  appliedShiftMinutes: number = 0;
  remainingGapMinutes: number = 0;
  message: string = '';
}

class AdvanceDialogVmMock {
  public context: AdvanceContextMock | null = null;
  public result: AdvanceResultMock = new AdvanceResultMock();
  public applyCalls: number = 0;
  public events: EventEntity[] = [];

  buildAdvanceAdjustContext(_index: number): AdvanceContextMock | null {
    return this.context;
  }

  applyAdvanceAdjust(_index: number, _selectedIds: Set<number>, _nextStartTime: string): Promise<AdvanceResultMock> {
    this.applyCalls += 1;
    return Promise.resolve(this.result);
  }
}

class CompressContextMock {
  neededGapMinutes: number = 0;
}

class CompressDialogVmMock {
  public events: EventEntity[] = [];
  public context: CompressContextMock | null = null;
  public plan: CompressionPlan = { status: 'NO_ACTION', msg: '', affectedItems: [] };

  buildCompressionSelectionContext(_index: number, _targetTime: string): CompressContextMock | null {
    return this.context;
  }

  calculateCompressionPlanBySelection(
    _index: number,
    _targetTime: string,
    _selectedIds: Set<number>,
    _mode: 'FIXED' | 'RATIO'
  ): CompressionPlan {
    return this.plan;
  }
}

class UiContextAlertMock {
  public dialogConfig: Record<string, Object> | null = null;

  showAlertDialog(config: Record<string, Object>): void {
    this.dialogConfig = config;
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

  describe('unit_test_case_generator_autofill_IndexConflictHelperBranchFill', () => {
    it('normal: request_plan_date_update_should_apply_directly_when_no_rigid_conflict', 0, () => {
      // Arrange
      const vm = new DateShiftVmMock();
      vm.preview.hasRigidConflict = false;
      const timestamp = new Date('2026-01-02T17:20:00.000Z').getTime();
      let conflictMenuCalls = 0;

      // Act
      IndexConflictHelper.requestPlanDateUpdate(
        vm as Object as TimelineViewModel,
        timestamp,
        () => {
          conflictMenuCalls += 1;
        }
      );

      // Assert
      expect(vm.updatePlanDateCalls).assertEqual(1);
      expect(conflictMenuCalls).assertEqual(0);
    });

    it('boundary: request_plan_date_update_should_fallback_apply_when_conflict_item_missing', 0, () => {
      // Arrange
      const vm = new DateShiftVmMock();
      vm.preview.hasRigidConflict = true;
      vm.preview.conflictItemId = 777;
      vm.preview.gapMinutes = 12;
      vm.events = [];
      let conflictMenuCalls = 0;

      // Act
      IndexConflictHelper.requestPlanDateUpdate(
        vm as Object as TimelineViewModel,
        Date.now(),
        () => {
          conflictMenuCalls += 1;
        }
      );

      // Assert
      expect(vm.updatePlanDateCalls).assertEqual(1);
      expect(conflictMenuCalls).assertEqual(0);
    });

    it('invalid: open_advance_adjust_dialog_should_return_null_when_no_candidate', 0, () => {
      // Arrange
      const vm = new AdvanceDialogVmMock();
      const context = new AdvanceContextMock();
      context.candidates = [];
      vm.context = context;
      const event = buildConflictEvent(20);
      let toastCount = 0;

      // Act
      const controller = IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        0,
        event,
        '09:00',
        (_t?: string) => {},
        (_msg: string) => {
          toastCount += 1;
        },
        () => {},
        (_gap: number) => {}
      );

      // Assert
      expect(controller === null).assertTrue();
      expect(toastCount).assertEqual(1);
    });

    it('conflict: open_advance_adjust_dialog_should_reopen_when_apply_failed', 0, async (done: Function) => {
      // Arrange
      const vm = new AdvanceDialogVmMock();
      const context = new AdvanceContextMock();
      context.candidates = [1, 2];
      vm.context = context;
      vm.result.success = false;
      vm.result.message = 'apply_failed';
      const event = buildConflictEvent(21);
      const controllerMock = new OpenCounterControllerMock();
      let reopenCount = 0;
      let openConflictCount = 0;
      let savedCount = 0;
      const originAdvance = Reflect.get(IndexDialogManager as Object, 'createAdvanceAdjustController') as Object;
      Reflect.set(IndexDialogManager as Object, 'createAdvanceAdjustController', (callbacks: Object): Object => {
        const callbackMap = callbacks as Record<string, Function>;
        void callbackMap['onConfirm']([21], '10:10');
        return controllerMock as Object;
      });

      // Act
      IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        0,
        event,
        '09:30',
        (_t?: string) => {
          savedCount += 1;
        },
        (_msg: string) => {},
        () => {
          reopenCount += 1;
        },
        (_gap: number) => {
          openConflictCount += 1;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 40));
      Reflect.set(IndexDialogManager as Object, 'createAdvanceAdjustController', originAdvance);

      // Assert
      expect(controllerMock.openCount).assertEqual(1);
      expect(vm.applyCalls).assertEqual(1);
      expect(reopenCount).assertEqual(1);
      expect(openConflictCount).assertEqual(0);
      expect(savedCount).assertEqual(0);
      done();
    });

    it('regression: open_compress_selection_dialog_should_callback_on_no_action_plan', 0, async (done: Function) => {
      // Arrange
      const vm = new CompressDialogVmMock();
      const context = new CompressContextMock();
      context.neededGapMinutes = 5;
      vm.context = context;
      vm.plan = { status: 'NO_ACTION', msg: '', affectedItems: [] };
      const event = buildConflictEvent(22);
      const controllerMock = new OpenCounterControllerMock();
      let savedCount = 0;
      const originCompress = Reflect.get(IndexDialogManager as Object, 'createConflictCompressController') as Object;
      Reflect.set(IndexDialogManager as Object, 'createConflictCompressController', (callbacks: Object): Object => {
        const callbackMap = callbacks as Record<string, Function>;
        void callbackMap['onConfirm']([1, 2], 'RATIO');
        return controllerMock as Object;
      });

      // Act
      IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        0,
        event,
        '11:00',
        (_t?: string) => {
          savedCount += 1;
        },
        () => {},
        (_msg: string) => {},
        () => {},
        () => {}
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 30));
      Reflect.set(IndexDialogManager as Object, 'createConflictCompressController', originCompress);

      // Assert
      expect(controllerMock.openCount).assertEqual(1);
      expect(savedCount).assertEqual(1);
      done();
    });

    it('combined: handle_event_conflict_action_should_route_advance_to_advance_dialog', 0, () => {
      // Arrange
      const event = buildConflictEvent(23);
      const vm = new ActionConflictVmMock([event], { status: 'COMPRESS_CONFIRM', msg: '', affectedItems: [] });
      let previewCalled = false;
      let advanceCalled = false;
      let compressCalled = false;

      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        event,
        'advance',
        9,
        undefined,
        () => {
          previewCalled = true;
        },
        () => {
          advanceCalled = true;
        },
        () => {
          compressCalled = true;
        },
        () => {}
      );

      // Assert
      expect(previewCalled).assertFalse();
      expect(advanceCalled).assertTrue();
      expect(compressCalled).assertFalse();
    });

    it('normal: open_conflict_menu_should_open_and_route_callbacks', 0, () => {
      // Arrange
      const vm = new ActionConflictVmMock([buildConflictEvent(31)], { status: 'COMPRESS_CONFIRM', msg: '', affectedItems: [] });
      const event = buildConflictEvent(31);
      const controllerMock = new OpenCounterControllerMock();
      const originConflict = Reflect.get(IndexDialogManager as Object, 'createConflictSelectionController') as Object;
      let previewCount = 0;
      let compressCount = 0;
      let advanceCount = 0;
      Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', (callbacks: Object): Object => {
        const callbackMap = callbacks as Record<string, Function>;
        callbackMap['onDelayY']();
        callbackMap['onCompressX']();
        callbackMap['onAdvanceAdjust']();
        callbackMap['onShiftSameDay']();
        callbackMap['onSmartAdjust']();
        return controllerMock as Object;
      });

      // Act
      IndexConflictHelper.openConflictMenu(
        vm as Object as TimelineViewModel,
        0,
        event,
        '10:00',
        12,
        (_t?: string) => {},
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _plan: CompressionPlan, _saveFn: (t?: string) => void, _backFn: () => void) => {
          previewCount += 1;
        },
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _saveFn: (t?: string) => void, _backFn: () => void) => {
          compressCount += 1;
        },
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _saveFn: (t?: string) => void) => {
          advanceCount += 1;
        }
      );
      Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', originConflict);

      // Assert
      expect(controllerMock.openCount).assertEqual(1);
      expect(previewCount > 0).assertTrue();
      expect(compressCount > 0).assertTrue();
      expect(advanceCount).assertEqual(2);
    });

    it('boundary: show_compression_blocked_dialog_should_trigger_both_actions', 0, () => {
      // Arrange
      const uiContext = new UiContextAlertMock();
      const vm = new ActionConflictVmMock([], { status: 'COMPRESS_CONFIRM', msg: '', affectedItems: [] });
      const event = buildConflictEvent(32);
      const plan: CompressionPlan = {
        status: 'OVERLOAD',
        msg: 'overload',
        affectedItems: [],
        remainingGapMinutes: 18,
        suggestedTime: '11:40'
      };
      let reopenCount = 0;
      let previewCount = 0;

      // Act
      IndexConflictHelper.showCompressionBlockedDialog(
        uiContext as Object as UIContext,
        0,
        event,
        '11:00',
        plan,
        [1, 2],
        'RATIO',
        (_t?: string) => {},
        () => {},
        (_idx: number, _it: EventEntity, _time: string, _save: (t?: string) => void, _back: () => void, _ids: number[], _mode: 'FIXED' | 'RATIO' | 'EQUAL') => {
          reopenCount += 1;
        },
        (_idx: number, _it: EventEntity, _time: string, _next: CompressionPlan, _save: (t?: string) => void, _back: () => void) => {
          previewCount += 1;
        },
        vm as Object as TimelineViewModel
      );
      const cfg = uiContext.dialogConfig as Record<string, Object>;
      const primaryButton = cfg['primaryButton'] as Record<string, Function>;
      const secondaryButton = cfg['secondaryButton'] as Record<string, Function>;
      primaryButton['action']();
      secondaryButton['action']();

      // Assert
      expect(reopenCount).assertEqual(1);
      expect(previewCount).assertEqual(1);
    });

    it('invalid: open_compress_selection_dialog_should_show_toast_when_context_missing', 0, () => {
      // Arrange
      const vm = new CompressDialogVmMock();
      vm.context = null;
      const event = buildConflictEvent(33);
      let toastCount = 0;

      // Act
      const controller = IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        0,
        event,
        '12:00',
        (_t?: string) => {},
        () => {},
        (_msg: string) => {
          toastCount += 1;
        },
        () => {},
        () => {}
      );

      // Assert
      expect(controller === null).assertTrue();
      expect(toastCount).assertEqual(1);
    });
  });
}
