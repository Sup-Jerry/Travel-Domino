import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexConflictHelper } from '../main/ets/pages/index/IndexConflictHelper';
import {
  DateFilterCallbacks,
  DateFilterOpenCallbacks,
  IndexDialogManager,
  SettingsCallbacks,
  ShareDialogCallbacks
} from '../main/ets/pages/index/IndexDialogManager';
import { IndexEventHandlers } from '../main/ets/pages/index/IndexEventHandlers';
import { IndexLifecycleHelper } from '../main/ets/pages/index/IndexLifecycleHelper';
import { IndexSettingsFlowDeps, IndexSettingsFlowHelper } from '../main/ets/pages/index/IndexSettingsFlowHelper';
import { CompressionMode, CompressionPlan, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

function sleepBH(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function buildEventBH(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `E${id}`;
  event.status = 1;
  event.duration = 45;
  event.fixed_start_time = '09:00';
  event.computed_time = '09:00';
  event.day_offset = 1;
  event.dynamic_day_offset = 1;
  event.lock_status = 0;
  event.note = '';
  event.priority = 0;
  event.latitude = 0;
  event.longitude = 0;
  event.gap_minutes = 0;
  event.conflict_msg = '';
  return event;
}

class DialogControllerMockBH {
  openCount: number = 0;

  open(): void {
    this.openCount += 1;
  }
}

class DateFilterHooksBH {
  private readonly originCreate: Object;
  private readonly originSingle: Object;
  private readonly originRange: Object;
  controller: DialogControllerMockBH = new DialogControllerMockBH();
  callbacks: DateFilterCallbacks | null = null;
  singleCallCount: number = 0;
  rangeCallCount: number = 0;
  singleDateMs: number = -1;
  rangeStartMs: number = -1;
  rangeEndMs: number = -1;

  constructor() {
    this.originCreate = Reflect.get(IndexDialogManager as Object, 'createDateFilterController') as Object;
    this.originSingle = Reflect.get(IndexDialogManager as Object, 'openSingleDateFilterPicker') as Object;
    this.originRange = Reflect.get(IndexDialogManager as Object, 'openRangeDateFilterPicker') as Object;
  }

  install(): void {
    Reflect.set(IndexDialogManager as Object, 'createDateFilterController', (callbacks: DateFilterCallbacks): Object => {
      this.callbacks = callbacks;
      return this.controller as Object;
    });

    Reflect.set(
      IndexDialogManager as Object,
      'openSingleDateFilterPicker',
      (_uiContext: UIContext, planStartDate: number, onAccept: (dateMs: number) => void): void => {
        this.singleCallCount += 1;
        onAccept(planStartDate + 1);
      }
    );

    Reflect.set(
      IndexDialogManager as Object,
      'openRangeDateFilterPicker',
      (_uiContext: UIContext, _planStartDate: number, onAccept: (startMs: number, endMs: number) => void): void => {
        this.rangeCallCount += 1;
        onAccept(1000, 2000);
      }
    );
  }

  restore(): void {
    Reflect.set(IndexDialogManager as Object, 'createDateFilterController', this.originCreate);
    Reflect.set(IndexDialogManager as Object, 'openSingleDateFilterPicker', this.originSingle);
    Reflect.set(IndexDialogManager as Object, 'openRangeDateFilterPicker', this.originRange);
  }
}

class ConflictDialogHooksBH {
  private readonly originAdvance: Object;
  private readonly originCompress: Object;
  private readonly originConflict: Object;
  advanceController: DialogControllerMockBH = new DialogControllerMockBH();
  compressController: DialogControllerMockBH = new DialogControllerMockBH();
  conflictController: DialogControllerMockBH = new DialogControllerMockBH();
  advanceCallbacks: Record<string, Function> | null = null;
  compressCallbacks: Record<string, Function> | null = null;
  conflictCallbacks: Record<string, Function> | null = null;

  constructor() {
    this.originAdvance = Reflect.get(IndexDialogManager as Object, 'createAdvanceAdjustController') as Object;
    this.originCompress = Reflect.get(IndexDialogManager as Object, 'createConflictCompressController') as Object;
    this.originConflict = Reflect.get(IndexDialogManager as Object, 'createConflictSelectionController') as Object;
  }

  installAdvance(): void {
    Reflect.set(IndexDialogManager as Object, 'createAdvanceAdjustController', (callbacks: Object): Object => {
      this.advanceCallbacks = callbacks as Record<string, Function>;
      return this.advanceController as Object;
    });
  }

  installCompress(): void {
    Reflect.set(IndexDialogManager as Object, 'createConflictCompressController', (callbacks: Object): Object => {
      this.compressCallbacks = callbacks as Record<string, Function>;
      return this.compressController as Object;
    });
  }

  installConflict(): void {
    Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', (callbacks: Object): Object => {
      this.conflictCallbacks = callbacks as Record<string, Function>;
      return this.conflictController as Object;
    });
  }

  restore(): void {
    Reflect.set(IndexDialogManager as Object, 'createAdvanceAdjustController', this.originAdvance);
    Reflect.set(IndexDialogManager as Object, 'createConflictCompressController', this.originCompress);
    Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', this.originConflict);
  }
}

class ConflictVmMockBH {
  events: EventEntity[] = [];
  updateCalls: number = 0;
  lastFixedTime: string = '';
  lastUpdatedPlanDate: number = -1;
  compressionPlan: CompressionPlan = {
    status: 'NO_ACTION',
    msg: '',
    affectedItems: []
  };

  buildAdvanceAdjustContext(_index: number): Object {
    return {
      candidates: [{ id: 1 }]
    };
  }

  async applyAdvanceAdjust(_index: number, _ids: Set<number>, _nextStartTime: string): Promise<Object> {
    return {
      success: true,
      appliedCount: 1,
      appliedShiftMinutes: 20,
      remainingGapMinutes: 0,
      message: ''
    };
  }

  buildCompressionSelectionContext(_index: number, _targetTime: string): Object {
    return {
      neededGapMinutes: 10
    };
  }

  calculateCompressionPlanBySelection(
    _index: number,
    _targetTime: string,
    _selectedIds: Set<number>,
    _mode: CompressionMode
  ): CompressionPlan {
    return this.compressionPlan;
  }

  calculateDelayPlan(_index: number): CompressionPlan {
    return {
      status: 'COMPRESS_CONFIRM',
      msg: '',
      affectedItems: []
    };
  }

  previewPlanDateShift(_date: number): Object {
    return {
      hasRigidConflict: true,
      conflictItemId: 1,
      gapMinutes: 17
    };
  }

  async updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    fixedTime: string | undefined,
    _dayOffset: number,
    _isLocked: boolean,
    _note: string,
    _priority: number,
    _latitude: number,
    _longitude: number
  ): Promise<void> {
    this.updateCalls += 1;
    this.lastFixedTime = fixedTime || '';
  }

  async updatePlanDate(dateMs: number): Promise<void> {
    this.lastUpdatedPlanDate = dateMs;
  }
}

class SettingsFlowDepsErrorMockBH implements IndexSettingsFlowDeps {
  createSettingsController(_callbacks: SettingsCallbacks): CustomDialogController {
    return new DialogControllerMockBH() as Object as CustomDialogController;
  }

  openPlanDatePicker(_uiContext: UIContext, _planStartDate: number, _onAccept: (dateMs: number) => void): void {
  }

  createRenameController(_initName: string, _onConfirm: (newName: string) => void): CustomDialogController {
    return new DialogControllerMockBH() as Object as CustomDialogController;
  }

  createShareController(_callbacks: ShareDialogCallbacks): CustomDialogController {
    return new DialogControllerMockBH() as Object as CustomDialogController;
  }

  async exportPlanToJson(_planId: number): Promise<string> {
    throw new Error('export_failed_bh');
  }
}

class LifecycleVmMockBH {
  loadReject: boolean = false;

  setHasUnsavedPostponeStorageKey(_key: string): void {}

  async loadData(_planId: number): Promise<void> {
    if (this.loadReject) {
      throw new Error('load_failed_bh');
    }
  }

  getStrategyMode(): number {
    return 0;
  }

  isWeatherFeatureEnabled(): boolean {
    return false;
  }

  shouldAutoRefreshPlanningWeather(): boolean {
    return false;
  }

  async refreshPlanningWeather(_force: boolean): Promise<void> {}

  stopExecutionWeatherScheduler(): void {}
}

class RouterMockBH {
  private readonly params: Object;

  constructor(params: Object) {
    this.params = params;
  }

  getParams(): Record<string, Object> {
    return this.params as Record<string, Object>;
  }
}

class UiContextMockBH {
  private readonly router: RouterMockBH;

  constructor(params: Object) {
    this.router = new RouterMockBH(params);
  }

  getRouter(): RouterMockBH {
    return this.router;
  }
}

class EventHandlerVmMockBH {
  events: EventEntity[];
  moveIndex: number = -2;
  moveDirection: string = '';
  lastTravelMode: number = -1;
  lastManualMinutes: number = -1;

  constructor(events: EventEntity[]) {
    this.events = events;
  }

  moveEvent(index: number, direction: 'up' | 'down'): void {
    this.moveIndex = index;
    this.moveDirection = direction;
  }

  updateTravelMode(_item: EventEntity, mode: number): void {
    this.lastTravelMode = mode;
  }

  updateManualCommute(_item: EventEntity, minutes: number): void {
    this.lastManualMinutes = minutes;
  }
}

export default function phase2BatchBHTest() {
  describe('phase2BatchBH_index_dialog_manager', () => {
    it('normal: open_date_filter_dialog_should_dispatch_show_all_select_date_and_range_callbacks', 0, () => {
      // Arrange
      const hooks = new DateFilterHooksBH();
      hooks.install();
      let showAllCount = 0;
      let selectedDate = -1;
      let rangeStart = -1;
      let rangeEnd = -1;

      // Act
      IndexDialogManager.openDateFilterDialog(
        new Object() as UIContext,
        500,
        {
          onShowAll: () => {
            showAllCount += 1;
          },
          onSelectDate: (dateMs: number) => {
            selectedDate = dateMs;
          },
          onSelectRange: (startMs: number, endMs: number) => {
            rangeStart = startMs;
            rangeEnd = endMs;
          }
        } as DateFilterOpenCallbacks
      );
      (hooks.callbacks as DateFilterCallbacks).onShowAll();
      (hooks.callbacks as DateFilterCallbacks).onSelectDate();
      (hooks.callbacks as DateFilterCallbacks).onSelectRange();
      hooks.restore();

      // Assert
      expect(hooks.controller.openCount).assertEqual(1);
      expect(showAllCount).assertEqual(1);
      expect(hooks.singleCallCount).assertEqual(1);
      expect(hooks.rangeCallCount).assertEqual(1);
      expect(selectedDate).assertEqual(501);
      expect(rangeStart).assertEqual(1000);
      expect(rangeEnd).assertEqual(2000);
    });
  });

  describe('phase2BatchBH_index_conflict_helper', () => {
    it('normal: open_advance_adjust_dialog_should_save_and_toast_when_gap_fully_resolved', 0, async (done: Function) => {
      // Arrange
      const hooks = new ConflictDialogHooksBH();
      hooks.installAdvance();
      const vm = new ConflictVmMockBH();
      const item = buildEventBH(1);
      let saveTime = '';
      let reopenGap = -1;
      let toastMessage = '';

      // Act
      IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        0,
        item,
        '09:40',
        (t?: string) => {
          saveTime = t || '';
        },
        (message: string) => {
          toastMessage = message;
        },
        () => {},
        (gap: number) => {
          reopenGap = gap;
        }
      );
      (hooks.advanceCallbacks as Record<string, Function>).onConfirm([1], '09:10');
      await sleepBH(20);
      hooks.restore();

      // Assert
      expect(hooks.advanceController.openCount).assertEqual(1);
      expect(saveTime).assertEqual('09:40');
      expect(reopenGap).assertEqual(-1);
      expect(toastMessage.indexOf('20') >= 0).assertTrue();
      done();
    });

    it('boundary: open_compress_selection_dialog_should_save_directly_when_plan_status_is_no_action', 0, () => {
      // Arrange
      const hooks = new ConflictDialogHooksBH();
      hooks.installCompress();
      const vm = new ConflictVmMockBH();
      vm.compressionPlan = {
        status: 'NO_ACTION',
        msg: '',
        affectedItems: []
      };
      const item = buildEventBH(2);
      let saveTime = '';
      let previewCount = 0;
      let blockedCount = 0;

      // Act
      const controller = IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        0,
        item,
        '10:10',
        (t?: string) => {
          saveTime = t || '';
        },
        () => {},
        () => {},
        () => {
          previewCount += 1;
        },
        () => {
          blockedCount += 1;
        }
      );
      (hooks.compressCallbacks as Record<string, Function>).onConfirm([2], 'RATIO');
      hooks.restore();

      // Assert
      expect((controller as Object) !== null).assertTrue();
      expect(saveTime).assertEqual('10:10');
      expect(previewCount).assertEqual(0);
      expect(blockedCount).assertEqual(0);
    });

    it('normal: open_conflict_menu_should_route_compress_and_smart_to_compress_dialog', 0, () => {
      // Arrange
      const hooks = new ConflictDialogHooksBH();
      hooks.installConflict();
      const vm = new ConflictVmMockBH();
      const item = buildEventBH(3);
      let compressCount = 0;

      // Act
      IndexConflictHelper.openConflictMenu(
        vm as Object as TimelineViewModel,
        0,
        item,
        '09:30',
        8,
        () => {},
        () => {},
        (_index: number, _target: EventEntity, _targetTime: string, _saveCallback: (t?: string) => void, _backFn: () => void) => {
          compressCount += 1;
        },
        () => {}
      );
      (hooks.conflictCallbacks as Record<string, Function>).onCompressX();
      (hooks.conflictCallbacks as Record<string, Function>).onSmartAdjust();
      hooks.restore();

      // Assert
      expect(hooks.conflictController.openCount).assertEqual(1);
      expect(compressCount).assertEqual(2);
    });

    it('invalid: handle_event_conflict_action_should_route_compress_strategy_and_trigger_on_done_after_save', 0, async (done: Function) => {
      // Arrange
      const vm = new ConflictVmMockBH();
      const item = buildEventBH(4);
      vm.events = [item];
      let doneCount = 0;
      let compressCalled = false;

      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        item,
        'compress',
        9,
        () => {
          doneCount += 1;
        },
        () => {},
        () => {},
        (_index: number, _target: EventEntity, _targetTime: string, saveCallback: (t?: string) => void, _onBack: () => void) => {
          compressCalled = true;
          saveCallback('10:20');
        },
        () => {}
      );
      await sleepBH(20);

      // Assert
      expect(compressCalled).assertTrue();
      expect(vm.updateCalls).assertEqual(1);
      expect(vm.lastFixedTime).assertEqual('10:20');
      expect(doneCount).assertEqual(1);
      done();
    });

    it('boundary: request_plan_date_update_should_fallback_to_preview_gap_when_event_gap_invalid', 0, () => {
      // Arrange
      const vm = new ConflictVmMockBH();
      const item = buildEventBH(1);
      item.gap_minutes = 0;
      item.conflict_msg = 'invalid_gap';
      vm.events = [item];
      const inputDate = new Date(2026, 3, 18, 13, 20, 0, 0).getTime();
      let receivedGap = -1;

      // Act
      IndexConflictHelper.requestPlanDateUpdate(
        vm as Object as TimelineViewModel,
        inputDate,
        (_index: number, _item: EventEntity, _targetTime: string, gap: number, _save: (t?: string) => void) => {
          receivedGap = gap;
        }
      );

      // Assert
      expect(receivedGap).assertEqual(17);
    });
  });

  describe('phase2BatchBH_index_settings_flow_helper', () => {
    it('invalid: open_share_dialog_should_throw_when_export_fails', 0, async (done: Function) => {
      // Arrange
      const deps = new SettingsFlowDepsErrorMockBH();
      let message = '';

      // Act
      try {
        await IndexSettingsFlowHelper.openShareDialog({
          planId: 5,
          planTitle: 'x',
          planStartDate: 0,
          events: []
        }, deps);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('export_failed_bh');
      done();
    });
  });

  describe('phase2BatchBH_index_lifecycle_helper', () => {
    it('boundary: handle_about_to_appear_should_use_default_title_and_init_backlog_even_when_load_fails', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMockBH();
      vm.loadReject = true;
      let title = '';
      let initPlanId = -1;
      let initIsNewPlan = true;
      let errorReason = '';

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMockBH({ planId: 66 }) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (value: string) => {
          title = value;
        },
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean) => {
          initPlanId = planId;
          initIsNewPlan = isNewPlan;
        },
        onLoadDataError: (reason: string) => {
          errorReason = reason;
        }
      });
      await sleepBH(30);

      // Assert
      expect(title).assertEqual('行程详情');
      expect(initPlanId).assertEqual(66);
      expect(initIsNewPlan).assertFalse();
      expect(errorReason).assertEqual('load_failed_bh');
      done();
    });

    it('boundary: handle_about_to_appear_should_not_enter_companion_mode_when_reminder_id_invalid_and_force_disabled', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMockBH();
      let companionCount = 0;
      let tryStartCount = 0;

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMockBH({ planId: 67, autoStartFromReminder: true, reminderEventId: 0 }) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_value: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {
          companionCount += 1;
        },
        onTryStartEvent: async (_eventId: number) => {
          tryStartCount += 1;
          return true;
        },
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await sleepBH(30);

      // Assert
      expect(companionCount).assertEqual(0);
      expect(tryStartCount).assertEqual(0);
      done();
    });
  });

  describe('phase2BatchBH_index_event_handlers', () => {
    it('normal: handle_time_click_should_invoke_callback_when_plan_active', 0, () => {
      // Arrange
      const item = buildEventBH(8);
      let receivedId = -1;

      // Act
      IndexEventHandlers.handleTimeClick(false, item, (event: EventEntity) => {
        receivedId = event.id;
      });

      // Assert
      expect(receivedId).assertEqual(8);
    });

    it('boundary: handle_add_item_should_block_when_archived', 0, () => {
      // Arrange
      let blockedCount = 0;
      let openCount = 0;

      // Act
      IndexEventHandlers.handleAddItem(true, () => {
        blockedCount += 1;
      }, () => {
        openCount += 1;
      });

      // Assert
      expect(blockedCount).assertEqual(1);
      expect(openCount).assertEqual(0);
    });

    it('combined: ai_suggestion_and_move_wrappers_should_forward_to_underlying_handlers', 0, () => {
      // Arrange
      const item = buildEventBH(9);
      const vm = new EventHandlerVmMockBH([item]);
      let aiOpenCount = 0;

      // Act
      IndexEventHandlers.handleAiSuggestion(false, () => {}, () => {
        aiOpenCount += 1;
      });
      IndexEventHandlers.handleMoveUp(vm as Object as TimelineViewModel, item);
      IndexEventHandlers.handleTravelModeChange(vm as Object as TimelineViewModel, item, 2);
      IndexEventHandlers.handleManualTravelInput(vm as Object as TimelineViewModel, item, 12);

      // Assert
      expect(aiOpenCount).assertEqual(1);
      expect(vm.moveIndex).assertEqual(0);
      expect(vm.moveDirection).assertEqual('up');
      expect(vm.lastTravelMode).assertEqual(2);
      expect(vm.lastManualMinutes).assertEqual(12);
    });
  });
}
