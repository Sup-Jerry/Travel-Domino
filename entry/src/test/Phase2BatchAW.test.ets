import { describe, expect, it } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { TimelineDatePolicy } from '../main/ets/domain/policy/TimelineDatePolicy';
import { WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexDialogManager } from '../main/ets/pages/index/IndexDialogManager';
import { ConflictActionStrategy, IndexEventHandlers } from '../main/ets/pages/index/IndexEventHandlers';
import { IndexConflictHelper } from '../main/ets/pages/index/IndexConflictHelper';
import { IndexSettingsFlowDeps, IndexSettingsFlowHelper } from '../main/ets/pages/index/IndexSettingsFlowHelper';
import { IndexLifecycleHelper } from '../main/ets/pages/index/IndexLifecycleHelper';
import { IndexStateManager } from '../main/ets/pages/index/IndexStateManager';
import { TimelineInteractionHelper } from '../main/ets/viewmodel/TimelineInteractionHelper';
import { CompressionMode, CompressionPlan, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

function waitMsAW(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function captureSyncMessageAW(action: () => void): string {
  let message = '';
  try {
    action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  return message;
}

function normalizeDayStartAW(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function buildEventAW(id: number, name: string = `E${id}`): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.duration = 60;
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.fixed_start_time = '09:00';
  event.computed_time = '09:30';
  event.lock_status = 0;
  event.note = '';
  event.priority = 0;
  event.latitude = 0;
  event.longitude = 0;
  event.gap_minutes = 0;
  event.conflict_msg = '';
  return event;
}

class DialogControllerMockAW {
  openCount: number = 0;

  open(): void {
    this.openCount += 1;
  }
}

class DateNowHooksAW {
  private readonly originNow: Object;

  constructor() {
    this.originNow = Reflect.get(Date as Object, 'now') as Object;
  }

  setNow(value: number): void {
    Reflect.set(Date as Object, 'now', (): number => value);
  }

  restore(): void {
    Reflect.set(Date as Object, 'now', this.originNow);
  }
}

class PreferenceSetCallAW {
  key: string;
  value: Object;

  constructor(key: string, value: Object) {
    this.key = key;
    this.value = value;
  }
}

class PreferenceStoreMockAW {
  readonly values: Map<string, Object> = new Map<string, Object>();
  readonly setCalls: PreferenceSetCallAW[] = [];
  readonly getCalls: string[] = [];

  async setValue(key: string, value: Object): Promise<void> {
    this.setCalls.push(new PreferenceSetCallAW(key, value));
    this.values.set(key, value);
  }

  async getValue(key: string, defaultValue: Object): Promise<Object> {
    this.getCalls.push(key);
    return this.values.has(key) ? (this.values.get(key) as Object) : defaultValue;
  }
}

class PreferenceHooksAW {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
  }

  setInstance(instance: Object): void {
    Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => instance);
  }

  restore(): void {
    Reflect.set(PreferenceManager as Object, 'getInstance', this.originGetInstance);
  }
}

class TimelineInteractionHooksAW {
  private readonly originHandleCommuteChange: Object;
  callCount: number = 0;
  lastMinutes: number = 0;
  gapCallbackTriggered: boolean = false;

  constructor() {
    this.originHandleCommuteChange = Reflect.get(TimelineInteractionHelper as Object, 'handleCommuteChange') as Object;
  }

  install(): void {
    Reflect.set(
      TimelineInteractionHelper as Object,
      'handleCommuteChange',
      (_vm: Object, item: EventEntity, minutes: number, onGapFound?: (event: EventEntity) => void): void => {
        this.callCount += 1;
        this.lastMinutes = minutes;
        if (onGapFound) {
          this.gapCallbackTriggered = true;
          onGapFound(item);
        }
      }
    );
  }

  restore(): void {
    Reflect.set(TimelineInteractionHelper as Object, 'handleCommuteChange', this.originHandleCommuteChange);
  }
}

class IndexDialogManagerHooksAW {
  private readonly originAdvance: Object;
  private readonly originCompress: Object;
  private readonly originConflict: Object;
  advanceController: DialogControllerMockAW = new DialogControllerMockAW();
  compressController: DialogControllerMockAW = new DialogControllerMockAW();
  conflictController: DialogControllerMockAW = new DialogControllerMockAW();
  advanceCallbacks: Object | null = null;
  conflictCallbacks: Object | null = null;
  compressCallbacksHistory: Object[] = [];

  constructor() {
    this.originAdvance = Reflect.get(IndexDialogManager as Object, 'createAdvanceAdjustController') as Object;
    this.originCompress = Reflect.get(IndexDialogManager as Object, 'createConflictCompressController') as Object;
    this.originConflict = Reflect.get(IndexDialogManager as Object, 'createConflictSelectionController') as Object;
  }

  hookAdvance(): void {
    Reflect.set(
      IndexDialogManager as Object,
      'createAdvanceAdjustController',
      (callbacks: Object): Object => {
        this.advanceCallbacks = callbacks;
        return this.advanceController as Object;
      }
    );
  }

  hookCompress(): void {
    Reflect.set(
      IndexDialogManager as Object,
      'createConflictCompressController',
      (callbacks: Object): Object => {
        this.compressCallbacksHistory.push(callbacks);
        return this.compressController as Object;
      }
    );
  }

  hookConflict(): void {
    Reflect.set(
      IndexDialogManager as Object,
      'createConflictSelectionController',
      (callbacks: Object): Object => {
        this.conflictCallbacks = callbacks;
        return this.conflictController as Object;
      }
    );
  }

  restore(): void {
    Reflect.set(IndexDialogManager as Object, 'createAdvanceAdjustController', this.originAdvance);
    Reflect.set(IndexDialogManager as Object, 'createConflictCompressController', this.originCompress);
    Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', this.originConflict);
  }
}

class EventHandlerVmMockAW {
  events: EventEntity[];
  moveIndex: number = -2;
  moveDirection: string = '';
  travelMode: number = -1;
  manualMinutes: number = -1;

  constructor(events: EventEntity[]) {
    this.events = events;
  }

  moveEvent(index: number, direction: 'up' | 'down'): void {
    this.moveIndex = index;
    this.moveDirection = direction;
  }

  updateTravelMode(_item: EventEntity, mode: number): void {
    this.travelMode = mode;
  }

  updateManualCommute(_item: EventEntity, minutes: number): void {
    this.manualMinutes = minutes;
  }
}

class AdvanceAdjustCandidateStubAW {
  id: number;

  constructor(id: number) {
    this.id = id;
  }
}

class AdvanceAdjustContextStubAW {
  candidates: AdvanceAdjustCandidateStubAW[] = [];

  constructor(candidateIds: number[] = []) {
    for (let index = 0; index < candidateIds.length; index++) {
      this.candidates.push(new AdvanceAdjustCandidateStubAW(candidateIds[index]));
    }
  }
}

class AdvanceAdjustApplyResultStubAW {
  success: boolean;
  appliedCount: number;
  appliedShiftMinutes: number;
  remainingGapMinutes: number;
  message: string;

  constructor(
    success: boolean = true,
    appliedCount: number = 1,
    appliedShiftMinutes: number = 15,
    remainingGapMinutes: number = 0,
    message: string = ''
  ) {
    this.success = success;
    this.appliedCount = appliedCount;
    this.appliedShiftMinutes = appliedShiftMinutes;
    this.remainingGapMinutes = remainingGapMinutes;
    this.message = message;
  }
}

class PlanDateShiftPreviewStubAW {
  hasRigidConflict: boolean;
  conflictItemId: number;
  gapMinutes: number;

  constructor(hasRigidConflict: boolean, conflictItemId: number, gapMinutes: number) {
    this.hasRigidConflict = hasRigidConflict;
    this.conflictItemId = conflictItemId;
    this.gapMinutes = gapMinutes;
  }
}

class CompressionArgsStubAW {
  index: number = 0;
  selectedIds: number[] = [];
  targetStartTime: string = '';
  targetTime: string = '';
  mode: CompressionMode = 'RATIO';
}

class UpdateEventCallAW {
  id: number;
  name: string;
  duration: number;
  fixedTime: string;
  dayOffset: number;
  isLocked: boolean;
  note: string;
  priority: number;
  latitude: number;
  longitude: number;

  constructor(
    id: number,
    name: string,
    duration: number,
    fixedTime: string,
    dayOffset: number,
    isLocked: boolean,
    note: string,
    priority: number,
    latitude: number,
    longitude: number
  ) {
    this.id = id;
    this.name = name;
    this.duration = duration;
    this.fixedTime = fixedTime;
    this.dayOffset = dayOffset;
    this.isLocked = isLocked;
    this.note = note;
    this.priority = priority;
    this.latitude = latitude;
    this.longitude = longitude;
  }
}

class CompressionSelectionContextStubAW {
  neededGapMinutes: number;

  constructor(neededGapMinutes: number) {
    this.neededGapMinutes = neededGapMinutes;
  }
}

class ConflictVmMockAW {
  events: EventEntity[] = [];
  delayPlan: CompressionPlan = {
    status: 'COMPRESS_CONFIRM',
    msg: '',
    affectedItems: []
  };
  advanceContext: Object | null = null;
  advanceResult: Object = new AdvanceAdjustApplyResultStubAW();
  advanceErrorMessage: string = '';
  compressionContext: Object | null = null;
  compressionPlan: CompressionPlan = {
    status: 'NO_ACTION',
    msg: '',
    affectedItems: []
  };
  previewPlanDateShiftResult: Object = new PlanDateShiftPreviewStubAW(false, -1, 0);
  updateEventCalls: UpdateEventCallAW[] = [];
  updatedPlanDates: number[] = [];
  lastCompressionArgs: CompressionArgsStubAW | null = null;

  calculateDelayPlan(_targetIndex: number): CompressionPlan {
    return this.delayPlan;
  }

  buildAdvanceAdjustContext(_index: number): Object | null {
    return this.advanceContext;
  }

  async applyAdvanceAdjust(index: number, selectedIds: Set<number>, targetStartTime: string): Promise<Object> {
    if (this.advanceErrorMessage.length > 0) {
      throw new Error(this.advanceErrorMessage);
    }
    const args = new CompressionArgsStubAW();
    args.index = index;
    args.selectedIds = Array.from(selectedIds);
    args.targetStartTime = targetStartTime;
    this.lastCompressionArgs = args;
    return this.advanceResult;
  }

  buildCompressionSelectionContext(_index: number, _targetTime: string): Object | null {
    return this.compressionContext;
  }

  calculateCompressionPlanBySelection(
    index: number,
    targetTime: string,
    selectedIds: Set<number>,
    mode: CompressionMode
  ): CompressionPlan {
    const args = new CompressionArgsStubAW();
    args.index = index;
    args.targetTime = targetTime;
    args.selectedIds = Array.from(selectedIds);
    args.mode = mode;
    this.lastCompressionArgs = args;
    return this.compressionPlan;
  }

  previewPlanDateShift(_timestamp: number): Object {
    return this.previewPlanDateShiftResult;
  }

  updatePlanDate(timestamp: number): void {
    this.updatedPlanDates.push(timestamp);
  }

  async updateEventInfo(
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
  ): Promise<void> {
    this.updateEventCalls.push(
      new UpdateEventCallAW(
        id,
        name,
        duration,
        fixedTime ?? '',
        dayOffset,
        isLocked,
        note,
        priority,
        latitude,
        longitude
      )
    );
  }
}

class AlertDialogHostMockAW {
  lastOptions: Object | null = null;

  showAlertDialog(options: Object): void {
    this.lastOptions = options;
  }
}

class WeatherPreferenceMockAW implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class SettingsFlowVmMockAW {
  planStartDate: number = new Date(2026, 3, 20, 8, 0, 0, 0).getTime();
  updateCalled: number = 0;
  refreshPlanningCount: number = 0;
  refreshExecutionCount: number = 0;
  weatherEnabled: boolean = true;
  executionWeatherStage: boolean = true;
  shouldThrowUpdate: boolean = false;

  getWeatherUserPreference(): WeatherUserPreference {
    return new WeatherPreferenceMockAW();
  }

  async updateWeatherUserPreference(_preference: WeatherUserPreference): Promise<void> {
    this.updateCalled += 1;
    if (this.shouldThrowUpdate) {
      throw new Error('update_failed_aw');
    }
  }

  isWeatherFeatureEnabled(): boolean {
    return this.weatherEnabled;
  }

  isExecutionWeatherStage(): boolean {
    return this.executionWeatherStage;
  }

  async refreshPlanningWeather(_force: boolean): Promise<void> {
    this.refreshPlanningCount += 1;
  }

  async refreshExecutionWeather(_force: boolean, _source: string): Promise<void> {
    this.refreshExecutionCount += 1;
  }
}

class SettingsFlowDepsMockAW implements IndexSettingsFlowDeps {
  settingsController: DialogControllerMockAW = new DialogControllerMockAW();
  renameController: DialogControllerMockAW = new DialogControllerMockAW();
  shareController: DialogControllerMockAW = new DialogControllerMockAW();
  settingsCallbacks: Record<string, Object> | null = null;
  renameInitName: string = '';
  renameConfirm: ((newName: string) => void) | null = null;
  shareCallbacks: Record<string, Object> | null = null;
  pickerDateMs: number = 123456789;
  exportCount: number = 0;
  exportedJson: string = '{"aw":true}';

  createSettingsController(callbacks: Object): CustomDialogController {
    this.settingsCallbacks = callbacks as Record<string, Object>;
    return this.settingsController as Object as CustomDialogController;
  }

  openPlanDatePicker(_uiContext: UIContext, _planStartDate: number, onAccept: (dateMs: number) => void): void {
    onAccept(this.pickerDateMs);
  }

  createRenameController(initName: string, onConfirm: (newName: string) => void): CustomDialogController {
    this.renameInitName = initName;
    this.renameConfirm = onConfirm;
    return this.renameController as Object as CustomDialogController;
  }

  createShareController(callbacks: Object): CustomDialogController {
    this.shareCallbacks = callbacks as Record<string, Object>;
    return this.shareController as Object as CustomDialogController;
  }

  async exportPlanToJson(_planId: number): Promise<string> {
    this.exportCount += 1;
    return this.exportedJson;
  }
}

class RouterMockAW {
  private readonly params: Object;

  constructor(params: Object) {
    this.params = params;
  }

  getParams(): Record<string, Object> {
    return this.params as Record<string, Object>;
  }
}

class RouteParamsAW {
  planId: number;
  forceCompanionMode: boolean;

  constructor(planId: number, forceCompanionMode: boolean = false) {
    this.planId = planId;
    this.forceCompanionMode = forceCompanionMode;
  }
}

class UiContextMockAW {
  private readonly router: RouterMockAW;

  constructor(params: Object) {
    this.router = new RouterMockAW(params);
  }

  getRouter(): RouterMockAW {
    return this.router;
  }
}

class LifecycleVmMockAW {
  loadPlanId: number = -1;
  unsavedKey: string = '';
  strategyMode: number = 2;
  weatherEnabled: boolean = true;
  autoRefreshPlanning: boolean = true;
  stopExecutionSchedulerCount: number = 0;
  refreshPlanningCount: number = 0;
  loadRejectValue: Object | null = null;

  setHasUnsavedPostponeStorageKey(key: string): void {
    this.unsavedKey = key;
  }

  loadData(planId: number): Promise<void> {
    this.loadPlanId = planId;
    if (this.loadRejectValue !== null) {
      return Promise.reject(this.loadRejectValue);
    }
    return Promise.resolve();
  }

  getStrategyMode(): number {
    return this.strategyMode;
  }

  isWeatherFeatureEnabled(): boolean {
    return this.weatherEnabled;
  }

  shouldAutoRefreshPlanningWeather(): boolean {
    return this.autoRefreshPlanning;
  }

  refreshPlanningWeather(_force: boolean): Promise<void> {
    this.refreshPlanningCount += 1;
    return Promise.resolve();
  }

  stopExecutionWeatherScheduler(): void {
    this.stopExecutionSchedulerCount += 1;
  }
}

export default function phase2BatchAWTest() {
  describe('phase2BatchAW_index_event_handlers', () => {
    it('normal: handle_filter_should_call_callback_once', 0, () => {
      // Arrange
      let openCount = 0;
      // Act
      IndexEventHandlers.handleFilter(() => {
        openCount += 1;
      });
      // Assert
      expect(openCount).assertEqual(1);
    });

    it('boundary: handle_drag_drop_should_forward_zero_index_and_direction', 0, () => {
      // Arrange
      const target = buildEventAW(1);
      const vm = new EventHandlerVmMockAW([target, buildEventAW(2)]);
      // Act
      IndexEventHandlers.handleDragDrop(vm as Object as TimelineViewModel, target, 'down');
      // Assert
      expect(vm.moveIndex).assertEqual(0);
      expect(vm.moveDirection).assertEqual('down');
    });

    it('invalid: handle_filter_should_throw_when_runtime_callback_missing', 0, () => {
      // Arrange
      // Act
      const message = captureSyncMessageAW(() => {
        IndexEventHandlers.handleFilter(null as never);
      });
      // Assert
      expect(message.indexOf('is not a function') >= 0).assertTrue();
    });

    it('normal: handle_edit_item_should_delegate_to_open_edit_when_active', 0, () => {
      // Arrange
      const item = buildEventAW(3);
      let receivedId = -1;
      // Act
      IndexEventHandlers.handleEditItem(false, item, (event: EventEntity) => {
        receivedId = event.id;
      });
      // Assert
      expect(receivedId).assertEqual(3);
    });

    it('boundary: handle_time_click_should_ignore_archived_plan', 0, () => {
      // Arrange
      const item = buildEventAW(4);
      let called = false;
      // Act
      IndexEventHandlers.handleTimeClick(true, item, (_event: EventEntity) => {
        called = true;
      });
      // Assert
      expect(called).assertFalse();
    });

    it('normal: handle_delete_item_and_move_to_backlog_should_forward_item_reference', 0, () => {
      // Arrange
      const item = buildEventAW(5);
      let deletedId = -1;
      let movedId = -1;
      // Act
      IndexEventHandlers.handleDeleteItem(item, (event: EventEntity) => {
        deletedId = event.id;
      });
      IndexEventHandlers.handleMoveToBacklog(item, (event: EventEntity) => {
        movedId = event.id;
      });
      // Assert
      expect(deletedId).assertEqual(5);
      expect(movedId).assertEqual(5);
    });

    it('boundary: handle_add_item_and_ai_suggestion_should_open_when_plan_active', 0, () => {
      // Arrange
      let addOpened = 0;
      let aiOpened = 0;
      let blocked = 0;
      // Act
      IndexEventHandlers.handleAddItem(false, () => {
        blocked += 1;
      }, () => {
        addOpened += 1;
      });
      IndexEventHandlers.handleAiSuggestion(false, () => {
        blocked += 1;
      }, () => {
        aiOpened += 1;
      });
      // Assert
      expect(addOpened).assertEqual(1);
      expect(aiOpened).assertEqual(1);
      expect(blocked).assertEqual(0);
    });

    it('invalid: handle_commute_change_should_delegate_negative_minutes_to_interaction_helper', 0, () => {
      // Arrange
      const hooks = new TimelineInteractionHooksAW();
      hooks.install();
      const item = buildEventAW(6);
      const vm = new EventHandlerVmMockAW([item]);
      let gapTriggered = false;
      // Act
      IndexEventHandlers.handleCommuteChange(vm as Object as TimelineViewModel, item, -8, (_event: EventEntity) => {
        gapTriggered = true;
      });
      hooks.restore();
      // Assert
      expect(hooks.callCount).assertEqual(1);
      expect(hooks.lastMinutes).assertEqual(-8);
      expect(hooks.gapCallbackTriggered).assertTrue();
      expect(gapTriggered).assertTrue();
    });

    it('normal: handle_date_conflict_should_dispatch_callback_when_active', 0, () => {
      // Arrange
      const item = buildEventAW(7);
      let receivedGap = -1;
      let receivedStrategy = '';
      // Act
      IndexEventHandlers.handleDateConflict(
        false,
        item,
        'smart',
        25,
        (_event: EventEntity, strategy: ConflictActionStrategy, gap: number) => {
          receivedStrategy = strategy;
          receivedGap = gap;
        }
      );
      // Assert
      expect(receivedStrategy).assertEqual('smart');
      expect(receivedGap).assertEqual(25);
    });
  });

  describe('phase2BatchAW_index_conflict_helper', () => {
    it('normal: get_conflict_target_time_should_extract_pure_time_from_fixed_start_time', 0, () => {
      // Arrange
      const item = buildEventAW(11);
      item.fixed_start_time = '娆℃棩 10:20';
      item.computed_time = '09:10';
      // Act
      const targetTime = IndexConflictHelper.getConflictTargetTime(item);
      // Assert
      expect(targetTime).assertEqual('10:20');
    });

    it('boundary: get_conflict_target_time_should_fallback_to_computed_time_when_fixed_empty', 0, () => {
      // Arrange
      const item = buildEventAW(12);
      item.fixed_start_time = '';
      item.computed_time = '12-21 08:45';
      // Act
      const targetTime = IndexConflictHelper.getConflictTargetTime(item);
      // Assert
      expect(targetTime).assertEqual('08:45');
    });

    it('boundary: save_conflict_time_should_skip_update_when_new_time_missing_but_still_run_on_done', 0, async (done: Function) => {
      // Arrange
      const vm = new ConflictVmMockAW();
      const item = buildEventAW(13);
      let doneCalled = false;
      // Act
      await IndexConflictHelper.saveConflictTime(vm as Object as TimelineViewModel, item, undefined, () => {
        doneCalled = true;
      });
      // Assert
      expect(vm.updateEventCalls.length).assertEqual(0);
      expect(doneCalled).assertTrue();
      done();
    });

    it('invalid: save_conflict_time_should_skip_update_when_item_id_invalid', 0, async (done: Function) => {
      // Arrange
      const vm = new ConflictVmMockAW();
      const item = buildEventAW(0);
      let doneCalled = false;
      // Act
      await IndexConflictHelper.saveConflictTime(vm as Object as TimelineViewModel, item, '10:10', () => {
        doneCalled = true;
      });
      // Assert
      expect(vm.updateEventCalls.length).assertEqual(0);
      expect(doneCalled).assertTrue();
      done();
    });

    it('boundary: handle_event_conflict_action_should_return_when_item_not_in_schedule', 0, () => {
      // Arrange
      const vm = new ConflictVmMockAW();
      const item = buildEventAW(14);
      let previewCalled = false;
      let advanceCalled = false;
      let compressCalled = false;
      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        item,
        'delay',
        18,
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
      expect(advanceCalled).assertFalse();
      expect(compressCalled).assertFalse();
    });

    it('normal: handle_event_conflict_action_should_route_advance_strategy_to_advance_dialog', 0, () => {
      // Arrange
      const item = buildEventAW(15);
      const vm = new ConflictVmMockAW();
      vm.events = [item];
      let advanceCalled = false;
      let previewCalled = false;
      let compressCalled = false;
      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        item,
        'advance',
        9,
        undefined,
        () => {
          previewCalled = true;
        },
        (_index: number, _target: EventEntity, targetTime: string, _saveCallback: (t?: string) => void) => {
          advanceCalled = targetTime === '09:00';
        },
        () => {
          compressCalled = true;
        },
        () => {}
      );
      // Assert
      expect(advanceCalled).assertTrue();
      expect(previewCalled).assertFalse();
      expect(compressCalled).assertFalse();
    });

    it('invalid: handle_event_conflict_action_should_route_smart_strategy_to_compress_dialog', 0, () => {
      // Arrange
      const item = buildEventAW(16);
      const vm = new ConflictVmMockAW();
      vm.events = [item];
      let compressCalled = false;
      let advanceCalled = false;
      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        item,
        'smart',
        22,
        undefined,
        () => {},
        () => {
          advanceCalled = true;
        },
        (_index: number, _target: EventEntity, _targetTime: string, _saveCallback: (t?: string) => void, _onBack: () => void) => {
          compressCalled = true;
        },
        () => {}
      );
      // Assert
      expect(compressCalled).assertTrue();
      expect(advanceCalled).assertFalse();
    });

    it('boundary: open_advance_adjust_dialog_should_show_toast_when_context_missing', 0, () => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookAdvance();
      const vm = new ConflictVmMockAW();
      vm.advanceContext = new AdvanceAdjustContextStubAW();
      const item = buildEventAW(17);
      const messages: string[] = [];
      // Act
      const controller = IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        0,
        item,
        '09:00',
        () => {},
        (message: string) => {
          messages.push(message);
        },
        () => {},
        () => {}
      );
      hooks.restore();
      // Assert
      expect(controller === null).assertTrue();
      expect(messages.length).assertEqual(1);
      expect(messages[0]).assertEqual('当前冲突前不存在可调整区间');
    });

    it('normal: open_advance_adjust_dialog_should_save_and_reopen_conflict_when_gap_remains', 0, async (done: Function) => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookAdvance();
      const vm = new ConflictVmMockAW();
      vm.advanceContext = new AdvanceAdjustContextStubAW([1]);
      vm.advanceResult = new AdvanceAdjustApplyResultStubAW(true, 1, 15, 8, '');
      const item = buildEventAW(18);
      const messages: string[] = [];
      let savedTime = '';
      let reopenedGap = -1;
      // Act
      const controller = IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        1,
        item,
        '09:40',
        (nextTime?: string) => {
          savedTime = nextTime || '';
        },
        (message: string) => {
          messages.push(message);
        },
        () => {},
        (gap: number) => {
          reopenedGap = gap;
        }
      );
      const callbacks = hooks.advanceCallbacks as Record<string, Function>;
      callbacks.onConfirm([1], '09:20');
      await waitMsAW(30);
      hooks.restore();
      // Assert
      expect((controller as Object) !== null).assertTrue();
      expect(hooks.advanceController.openCount).assertEqual(1);
      expect(savedTime).assertEqual('09:40');
      expect(reopenedGap).assertEqual(8);
      expect(messages[messages.length - 1]).assertEqual('已前移15 分钟，仍有8 分钟冲突');
      done();
    });

    it('invalid: open_advance_adjust_dialog_should_reopen_when_apply_result_fails', 0, async (done: Function) => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookAdvance();
      const vm = new ConflictVmMockAW();
      vm.advanceContext = new AdvanceAdjustContextStubAW([2]);
      vm.advanceResult = new AdvanceAdjustApplyResultStubAW(false, 0, 0, 0, '失败原因');
      const item = buildEventAW(19);
      const messages: string[] = [];
      let reopenCount = 0;
      // Act
      IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        2,
        item,
        '10:00',
        () => {},
        (message: string) => {
          messages.push(message);
        },
        () => {
          reopenCount += 1;
        },
        () => {}
      );
      const callbacks = hooks.advanceCallbacks as Record<string, Function>;
      callbacks.onConfirm([2], '09:30');
      await waitMsAW(30);
      hooks.restore();
      // Assert
      expect(messages[0]).assertEqual('失败原因');
      expect(reopenCount).assertEqual(1);
      done();
    });

    it('invalid: open_advance_adjust_dialog_should_show_default_error_when_apply_throws', 0, async (done: Function) => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookAdvance();
      const vm = new ConflictVmMockAW();
      vm.advanceContext = new AdvanceAdjustContextStubAW([3]);
      vm.advanceErrorMessage = 'boom';
      const item = buildEventAW(20);
      const messages: string[] = [];
      // Act
      IndexConflictHelper.openAdvanceAdjustDialog(
        vm as Object as TimelineViewModel,
        3,
        item,
        '10:30',
        () => {},
        (message: string) => {
          messages.push(message);
        },
        () => {},
        () => {}
      );
      const callbacks = hooks.advanceCallbacks as Record<string, Function>;
      callbacks.onConfirm([3], '10:00');
      await waitMsAW(30);
      hooks.restore();
      // Assert
      expect(messages[messages.length - 1]).assertEqual('前移调整失败');
      done();
    });

    it('normal: show_compression_blocked_dialog_should_bind_primary_and_secondary_actions', 0, () => {
      // Arrange
      const uiContext = new AlertDialogHostMockAW();
      const item = buildEventAW(21);
      const plan: CompressionPlan = {
        status: 'OVERLOAD',
        msg: '',
        affectedItems: [],
        remainingGapMinutes: 12,
        suggestedTime: '09:50'
      };
      const vm = new ConflictVmMockAW();
      let reopenCount = 0;
      let previewCount = 0;
      // Act
      IndexConflictHelper.showCompressionBlockedDialog(
        uiContext as Object as UIContext,
        1,
        item,
        '09:40',
        plan,
        [21],
        'RATIO',
        () => {},
        () => {},
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _saveFn: (t?: string) => void, _backFn: () => void) => {
          reopenCount += 1;
        },
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _nextPlan: CompressionPlan, _saveFn: (t?: string) => void, _backFn: () => void) => {
          previewCount += 1;
        },
        vm as Object as TimelineViewModel
      );
      const options = uiContext.lastOptions as Record<string, Object>;
      (options.primaryButton as Record<string, Function>).action();
      (options.secondaryButton as Record<string, Function>).action();
      // Assert
      expect(String(options.title)).assertEqual('鉀?鍘嬬缉鍚庝粛鍐茬獊');
      expect(String(options.message).indexOf('12 鍒嗛挓鍐茬獊') >= 0).assertTrue();
      expect(reopenCount).assertEqual(1);
      expect(previewCount).assertEqual(1);
    });

    it('invalid: open_compress_selection_dialog_should_show_toast_when_context_missing', 0, () => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookCompress();
      const vm = new ConflictVmMockAW();
      vm.compressionContext = null;
      const item = buildEventAW(22);
      const messages: string[] = [];
      // Act
      const controller = IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        0,
        item,
        '09:00',
        () => {},
        () => {},
        (message: string) => {
          messages.push(message);
        },
        () => {},
        () => {}
      );
      hooks.restore();
      // Assert
      expect(controller === null).assertTrue();
      expect(messages[0]).assertEqual('当前上下文无法计算压缩方案，请稍后重试');
    });

    it('boundary: open_compress_selection_dialog_should_save_directly_when_gap_not_needed', 0, () => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookCompress();
      const vm = new ConflictVmMockAW();
      vm.compressionContext = new CompressionSelectionContextStubAW(0);
      const item = buildEventAW(23);
      let savedTime = '';
      // Act
      const controller = IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        1,
        item,
        '11:20',
        (time?: string) => {
          savedTime = time || '';
        },
        () => {},
        () => {},
        () => {},
        () => {}
      );
      hooks.restore();
      // Assert
      expect(controller === null).assertTrue();
      expect(savedTime).assertEqual('11:20');
    });

    it('normal: open_compress_selection_dialog_should_route_overload_plan_to_blocked_dialog', 0, async (done: Function) => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookCompress();
      const vm = new ConflictVmMockAW();
      vm.compressionContext = new CompressionSelectionContextStubAW(20);
      vm.compressionPlan = {
        status: 'OVERLOAD',
        msg: '',
        affectedItems: [],
        remainingGapMinutes: 6
      };
      const item = buildEventAW(24);
      let blockedCalls = 0;
      let previewCalls = 0;
      // Act
      IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        2,
        item,
        '12:00',
        () => {},
        () => {},
        () => {},
        () => {
          previewCalls += 1;
        },
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _planVal: CompressionPlan, _selectedIds: number[], _mode: CompressionMode, _saveFn: (t?: string) => void, _backFn: () => void) => {
          blockedCalls += 1;
        }
      );
      const callbacks = hooks.compressCallbacksHistory[0] as Record<string, Function>;
      callbacks.onConfirm([24], 'RATIO');
      await waitMsAW(20);
      hooks.restore();
      // Assert
      expect(blockedCalls).assertEqual(1);
      expect(previewCalls).assertEqual(0);
      done();
    });

    it('normal: open_compress_selection_dialog_should_open_preview_and_reopen_with_presets', 0, async (done: Function) => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookCompress();
      const vm = new ConflictVmMockAW();
      vm.compressionContext = new CompressionSelectionContextStubAW(30);
      vm.compressionPlan = {
        status: 'COMPRESS_CONFIRM',
        msg: '',
        affectedItems: []
      };
      const item = buildEventAW(25);
      let previewCalled = false;
      // Act
      IndexConflictHelper.openCompressSelectionDialog(
        vm as Object as TimelineViewModel,
        3,
        item,
        '13:00',
        () => {},
        () => {},
        () => {},
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, _planVal: CompressionPlan, _saveFn: (t?: string) => void, backFn: () => void) => {
          previewCalled = true;
          backFn();
        },
        () => {}
      );
      const firstCallbacks = hooks.compressCallbacksHistory[0] as Record<string, Function>;
      firstCallbacks.onConfirm([25], 'RATIO');
      await waitMsAW(20);
      hooks.restore();
      // Assert
      expect(previewCalled).assertTrue();
      expect(hooks.compressController.openCount).assertEqual(2);
      expect(hooks.compressCallbacksHistory.length).assertEqual(2);
      const reopenCallbacks = hooks.compressCallbacksHistory[1] as Record<string, Object>;
      const reopenIds = reopenCallbacks.initialSelectedIds as number[];
      expect(reopenIds.length).assertEqual(1);
      expect(reopenIds[0]).assertEqual(25);
      expect(String(reopenCallbacks.initialMode)).assertEqual('RATIO');
      done();
    });

    it('normal: open_conflict_menu_should_route_delay_to_preview_and_support_reopen', 0, () => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookConflict();
      const vm = new ConflictVmMockAW();
      const item = buildEventAW(26);
      vm.delayPlan = {
        status: 'COMPRESS_CONFIRM',
        msg: '',
        affectedItems: []
      };
      let previewCount = 0;
      // Act
      IndexConflictHelper.openConflictMenu(
        vm as Object as TimelineViewModel,
        0,
        item,
        '09:00',
        16,
        () => {},
        (_indexVal: number, _itemVal: EventEntity, _targetTimeVal: string, plan: CompressionPlan, _saveFn: (t?: string) => void, backFn: () => void) => {
          previewCount += 1;
          expect(plan.status).assertEqual('COMPRESS_CONFIRM');
          backFn();
        },
        () => {},
        () => {}
      );
      const callbacks = hooks.conflictCallbacks as Record<string, Function>;
      callbacks.onDelayY();
      hooks.restore();
      // Assert
      expect(previewCount).assertEqual(1);
      expect(hooks.conflictController.openCount).assertEqual(2);
    });

    it('boundary: open_conflict_menu_should_route_advance_and_shift_same_day_to_same_callback', 0, () => {
      // Arrange
      const hooks = new IndexDialogManagerHooksAW();
      hooks.hookConflict();
      const vm = new ConflictVmMockAW();
      const item = buildEventAW(27);
      let advanceCount = 0;
      // Act
      IndexConflictHelper.openConflictMenu(
        vm as Object as TimelineViewModel,
        1,
        item,
        '09:30',
        14,
        () => {},
        () => {},
        () => {},
        () => {
          advanceCount += 1;
        }
      );
      const callbacks = hooks.conflictCallbacks as Record<string, Function>;
      callbacks.onAdvanceAdjust();
      callbacks.onShiftSameDay();
      hooks.restore();
      // Assert
      expect(advanceCount).assertEqual(2);
    });

    it('normal: request_plan_date_update_should_apply_normalized_date_when_no_conflict', 0, () => {
      // Arrange
      const vm = new ConflictVmMockAW();
      vm.previewPlanDateShiftResult = new PlanDateShiftPreviewStubAW(false, -1, 0);
      const inputDate = new Date(2026, 3, 22, 18, 30, 0, 0).getTime();
      // Act
      IndexConflictHelper.requestPlanDateUpdate(
        vm as Object as TimelineViewModel,
        inputDate,
        () => {}
      );
      // Assert
      expect(vm.updatedPlanDates.length).assertEqual(1);
      expect(vm.updatedPlanDates[0]).assertEqual(normalizeDayStartAW(inputDate));
    });

    it('boundary: request_plan_date_update_should_fallback_to_apply_when_conflict_item_missing', 0, () => {
      // Arrange
      const vm = new ConflictVmMockAW();
      vm.previewPlanDateShiftResult = new PlanDateShiftPreviewStubAW(true, 999, 6);
      const inputDate = new Date(2026, 3, 23, 10, 0, 0, 0).getTime();
      // Act
      IndexConflictHelper.requestPlanDateUpdate(
        vm as Object as TimelineViewModel,
        inputDate,
        () => {}
      );
      // Assert
      expect(vm.updatedPlanDates.length).assertEqual(1);
      expect(vm.updatedPlanDates[0]).assertEqual(normalizeDayStartAW(inputDate));
    });

    it('invalid: request_plan_date_update_should_open_conflict_menu_and_save_then_apply', 0, async (done: Function) => {
      // Arrange
      const vm = new ConflictVmMockAW();
      const conflictItem = buildEventAW(28);
      conflictItem.dynamic_day_offset = 2;
      conflictItem.day_offset = 0;
      conflictItem.fixed_start_time = '08:20';
      vm.events = [conflictItem];
      vm.previewPlanDateShiftResult = new PlanDateShiftPreviewStubAW(true, 28, 11);
      const inputDate = new Date(2026, 3, 24, 15, 45, 0, 0).getTime();
      let capturedGap = -1;
      // Act
      IndexConflictHelper.requestPlanDateUpdate(
        vm as Object as TimelineViewModel,
        inputDate,
        (_index: number, _item: EventEntity, _targetTime: string, gap: number, saveCallback: (t?: string) => void) => {
          capturedGap = gap;
          saveCallback('10:15');
        }
      );
      await waitMsAW(30);
      // Assert
      expect(capturedGap).assertEqual(11);
      expect(vm.updateEventCalls.length).assertEqual(1);
      expect(String(vm.updateEventCalls[0].fixedTime)).assertEqual('10:15');
      expect(Number(vm.updateEventCalls[0].dayOffset)).assertEqual(2);
      expect(vm.updatedPlanDates[0]).assertEqual(normalizeDayStartAW(inputDate));
      done();
    });
  });

  describe('phase2BatchAW_index_settings_flow_helper', () => {
    it('normal: open_settings_dialog_should_route_rename_after_delay', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMockAW();
      const deps = new SettingsFlowDepsMockAW();
      let renameCount = 0;
      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new Object() as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {
          renameCount += 1;
        },
        onReschedule: (_dateMs: number) => {},
        onShare: async () => {},
        onWeatherPreferenceError: () => {}
      }, deps);
      (deps.settingsCallbacks as Record<string, Function>).onRename();
      await waitMsAW(130);
      // Assert
      expect(deps.settingsController.openCount).assertEqual(1);
      expect(renameCount).assertEqual(1);
      done();
    });

    it('boundary: open_settings_dialog_should_route_share_after_delay', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMockAW();
      const deps = new SettingsFlowDepsMockAW();
      let shareCount = 0;
      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new Object() as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {},
        onReschedule: (_dateMs: number) => {},
        onShare: async () => {
          shareCount += 1;
        },
        onWeatherPreferenceError: () => {}
      }, deps);
      (deps.settingsCallbacks as Record<string, Function>).onShare();
      await waitMsAW(130);
      // Assert
      expect(shareCount).assertEqual(1);
      done();
    });

    it('invalid: open_settings_dialog_should_skip_weather_refresh_when_feature_disabled', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMockAW();
      vm.weatherEnabled = false;
      const deps = new SettingsFlowDepsMockAW();
      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new Object() as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {},
        onReschedule: (_dateMs: number) => {},
        onShare: async () => {},
        onWeatherPreferenceError: () => {}
      }, deps);
      await (deps.settingsCallbacks as Record<string, Function>).onWeatherPreferenceChange(new WeatherPreferenceMockAW());
      // Assert
      expect(vm.updateCalled).assertEqual(1);
      expect(vm.refreshPlanningCount).assertEqual(0);
      expect(vm.refreshExecutionCount).assertEqual(0);
      done();
    });

    it('boundary: open_rename_dialog_should_keep_blank_title_and_forward_blank_name', 0, () => {
      // Arrange
      const deps = new SettingsFlowDepsMockAW();
      let receivedName = 'not_set';
      // Act
      IndexSettingsFlowHelper.openRenameDialog('   ', (newName: string) => {
        receivedName = newName;
      }, deps);
      (deps.renameConfirm as (newName: string) => void)('   ');
      // Assert
      expect(deps.renameController.openCount).assertEqual(1);
      expect(deps.renameInitName).assertEqual('   ');
      expect(receivedName).assertEqual('   ');
    });

    it('invalid: open_share_dialog_should_return_null_when_plan_id_not_positive', 0, async (done: Function) => {
      // Arrange
      const deps = new SettingsFlowDepsMockAW();
      // Act
      const controller = await IndexSettingsFlowHelper.openShareDialog({
        planId: 0,
        planTitle: 'x',
        planStartDate: 0,
        events: []
      }, deps);
      // Assert
      expect(controller === null).assertTrue();
      expect(deps.exportCount).assertEqual(0);
      expect(deps.shareController.openCount).assertEqual(0);
      done();
    });

    it('boundary: open_share_dialog_should_use_now_and_minimum_day_count_when_schedule_empty', 0, async (done: Function) => {
      // Arrange
      const deps = new SettingsFlowDepsMockAW();
      const nowHooks = new DateNowHooksAW();
      const fixedNow = new Date(2026, 3, 25, 9, 30, 0, 0).getTime();
      const backlogItem = buildEventAW(1);
      backlogItem.status = 0;
      nowHooks.setNow(fixedNow);
      // Act
      const controller = await IndexSettingsFlowHelper.openShareDialog({
        planId: 66,
        planTitle: 'share_aw',
        planStartDate: 0,
        events: [backlogItem]
      }, deps);
      nowHooks.restore();
      // Assert
      expect((controller as Object) !== null).assertTrue();
      expect(deps.shareController.openCount).assertEqual(1);
      expect(Number((deps.shareCallbacks as Record<string, Object>).startDate)).assertEqual(fixedNow);
      expect(Number((deps.shareCallbacks as Record<string, Object>).endDate)).assertEqual(
        TimelineDatePolicy.dayOffsetToDayStartMs(fixedNow, 0)
      );
      expect(Number((deps.shareCallbacks as Record<string, Object>).totalDays)).assertEqual(1);
      expect(Number((deps.shareCallbacks as Record<string, Object>).totalEvents)).assertEqual(0);
      done();
    });
  });

  describe('phase2BatchAW_index_lifecycle_helper', () => {
    it('normal: handle_about_to_appear_should_force_companion_mode_without_starting_event', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMockAW();
      const params = new RouteParamsAW(31, true);
      let manualRefreshValue = true;
      let bindCount = 0;
      let companionCount = 0;
      let startedEventId = -1;
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMockAW(params) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (value: boolean) => {
          manualRefreshValue = value;
        },
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {
          bindCount += 1;
        },
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {
          companionCount += 1;
        },
        onTryStartEvent: async (eventId: number) => {
          startedEventId = eventId;
          return true;
        },
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await waitMsAW(30);
      // Assert
      expect(manualRefreshValue).assertFalse();
      expect(bindCount).assertEqual(1);
      expect(companionCount).assertEqual(1);
      expect(startedEventId).assertEqual(-1);
      done();
    });

    it('boundary: handle_about_to_appear_should_skip_planning_refresh_when_auto_refresh_disabled', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMockAW();
      vm.autoRefreshPlanning = false;
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMockAW(new RouteParamsAW(32)) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await waitMsAW(30);
      // Assert
      expect(vm.refreshPlanningCount).assertEqual(0);
      done();
    });

    it('invalid: handle_about_to_appear_should_report_unknown_error_when_rejection_not_error', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMockAW();
      vm.loadRejectValue = new Object();
      let reason = '';
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMockAW(new RouteParamsAW(33)) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (value: string) => {
          reason = value;
        }
      });
      await waitMsAW(30);
      // Assert
      expect(reason).assertEqual('unknown_error');
      done();
    });

    it('boundary: handle_about_to_disappear_should_not_reset_timer_when_already_minus_one', 0, () => {
      // Arrange
      let setTimerCount = 0;
      let cleanupCount = 0;
      // Act
      IndexLifecycleHelper.handleAboutToDisappear({
        strategyAdaptationCheckTimer: -1,
        onUnbindReminderSubscriptions: () => {
          cleanupCount += 1;
        },
        onStopArrivalEngine: () => {
          cleanupCount += 1;
        },
        onStopExecutionWeatherScheduler: () => {
          cleanupCount += 1;
        },
        onUnbindPlanState: () => {
          cleanupCount += 1;
        },
        onClearDialogDraftStorage: () => {
          cleanupCount += 1;
        },
        onSetStrategyAdaptationCheckTimer: (_timer: number) => {
          setTimerCount += 1;
        }
      });
      // Assert
      expect(cleanupCount).assertEqual(5);
      expect(setTimerCount).assertEqual(0);
    });

    it('invalid: handle_about_to_disappear_should_clear_zero_timer_value', 0, () => {
      // Arrange
      let timerValue = 99;
      // Act
      IndexLifecycleHelper.handleAboutToDisappear({
        strategyAdaptationCheckTimer: 0,
        onUnbindReminderSubscriptions: () => {},
        onStopArrivalEngine: () => {},
        onStopExecutionWeatherScheduler: () => {},
        onUnbindPlanState: () => {},
        onClearDialogDraftStorage: () => {},
        onSetStrategyAdaptationCheckTimer: (value: number) => {
          timerValue = value;
        }
      });
      // Assert
      expect(timerValue).assertEqual(-1);
    });
  });

  describe('phase2BatchAW_index_state_manager', () => {
    it('invalid: scoped_storage_key_should_keep_base_when_plan_id_negative', 0, () => {
      // Arrange
      // Act
      const scoped = IndexStateManager.scopedStorageKey('draft_aw', -5);
      // Assert
      expect(scoped).assertEqual('draft_aw');
    });

    it('normal: clear_dialog_draft_storage_should_clear_scoped_and_global_values', 0, () => {
      // Arrange
      const planId = 88;
      const draftKey = 'phase2_aw_draft';
      const locationKey = 'phase2_aw_location';
      AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(draftKey, planId), 'scoped_draft');
      AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(locationKey, planId), 'scoped_location');
      AppStorage.setOrCreate(draftKey, 'global_draft');
      AppStorage.setOrCreate(locationKey, 'global_location');
      // Act
      IndexStateManager.clearDialogDraftStorage(planId, draftKey, locationKey);
      // Assert
      expect(String(AppStorage.get<string>(IndexStateManager.scopedStorageKey(draftKey, planId)) || '')).assertEqual('');
      expect(String(AppStorage.get<string>(IndexStateManager.scopedStorageKey(locationKey, planId)) || '')).assertEqual('');
      expect(String(AppStorage.get<string>(draftKey) || '')).assertEqual('');
      expect(String(AppStorage.get<string>(locationKey) || '')).assertEqual('');
    });

    it('normal: read_draft_storage_with_fallback_should_prefer_scoped_value', 0, () => {
      // Arrange
      const planId = 89;
      const key = 'phase2_aw_read_scoped';
      AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(key, planId), 'scoped_value');
      AppStorage.setOrCreate(key, 'global_value');
      // Act
      const value = IndexStateManager.readDraftStorageWithFallback(planId, key);
      // Assert
      expect(value).assertEqual('scoped_value');
    });

    it('boundary: read_draft_storage_with_fallback_should_use_global_value_when_scoped_blank', 0, () => {
      // Arrange
      const planId = 90;
      const key = 'phase2_aw_read_global';
      AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(key, planId), '   ');
      AppStorage.setOrCreate(key, 'global_only');
      // Act
      const value = IndexStateManager.readDraftStorageWithFallback(planId, key);
      // Assert
      expect(value).assertEqual('global_only');
    });

    it('invalid: read_draft_storage_with_fallback_should_return_empty_when_all_values_blank', 0, () => {
      // Arrange
      const planId = 91;
      const key = 'phase2_aw_read_empty';
      AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(key, planId), '   ');
      AppStorage.setOrCreate(key, '');
      // Act
      const value = IndexStateManager.readDraftStorageWithFallback(planId, key);
      // Assert
      expect(value).assertEqual('');
    });

    it('normal: read_unsaved_flag_should_return_true_from_scoped_storage', 0, () => {
      // Arrange
      const key = 'phase2_aw_unsaved_true';
      AppStorage.setOrCreate(IndexStateManager.scopedStorageKey(key, 92), true);
      // Act
      const value = IndexStateManager.readUnsavedFlag(92, key);
      // Assert
      expect(value).assertTrue();
    });

    it('boundary: read_unsaved_flag_should_return_false_when_storage_missing', 0, () => {
      // Arrange
      const key = 'phase2_aw_unsaved_missing';
      // Act
      const value = IndexStateManager.readUnsavedFlag(93, key);
      // Assert
      expect(value).assertFalse();
    });

    it('normal: set_unsaved_flag_should_write_true_value_and_return_true', 0, () => {
      // Arrange
      const key = 'phase2_aw_set_unsaved_true';
      // Act
      const result = IndexStateManager.setUnsavedFlag(94, key, true);
      // Assert
      expect(result).assertTrue();
      expect(AppStorage.get<boolean>(IndexStateManager.scopedStorageKey(key, 94))).assertTrue();
    });

    it('boundary: set_unsaved_flag_should_write_false_value_and_return_false', 0, () => {
      // Arrange
      const key = 'phase2_aw_set_unsaved_false';
      // Act
      const result = IndexStateManager.setUnsavedFlag(95, key, false);
      // Assert
      expect(result).assertFalse();
      expect(AppStorage.get<boolean>(IndexStateManager.scopedStorageKey(key, 95))).assertFalse();
    });

    it('normal: init_backlog_expanded_state_should_expand_new_plan_and_mark_initialized', 0, async (done: Function) => {
      // Arrange
      const hooks = new PreferenceHooksAW();
      const pref = new PreferenceStoreMockAW();
      hooks.setInstance(pref as Object);
      // Act
      const expanded = await IndexStateManager.initBacklogExpandedState(101, true);
      hooks.restore();
      // Assert
      expect(expanded).assertTrue();
      expect(pref.values.get(IndexStateManager.getBacklogExpandedKey(101)) === true).assertTrue();
      expect(pref.values.get(IndexStateManager.getBacklogInitializedKey(101)) === true).assertTrue();
      done();
    });

    it('boundary: init_backlog_expanded_state_should_return_saved_value_when_initialized', 0, async (done: Function) => {
      // Arrange
      const hooks = new PreferenceHooksAW();
      const pref = new PreferenceStoreMockAW();
      pref.values.set(IndexStateManager.getBacklogInitializedKey(102), true);
      pref.values.set(IndexStateManager.getBacklogExpandedKey(102), true);
      hooks.setInstance(pref as Object);
      // Act
      const expanded = await IndexStateManager.initBacklogExpandedState(102, false);
      hooks.restore();
      // Assert
      expect(expanded).assertTrue();
      expect(pref.setCalls.length).assertEqual(0);
      done();
    });

    it('invalid: init_backlog_expanded_state_should_default_false_and_initialize_old_plan', 0, async (done: Function) => {
      // Arrange
      const hooks = new PreferenceHooksAW();
      const pref = new PreferenceStoreMockAW();
      hooks.setInstance(pref as Object);
      // Act
      const expanded = await IndexStateManager.initBacklogExpandedState(103, false);
      hooks.restore();
      // Assert
      expect(expanded).assertFalse();
      expect(pref.values.get(IndexStateManager.getBacklogExpandedKey(103)) === false).assertTrue();
      expect(pref.values.get(IndexStateManager.getBacklogInitializedKey(103)) === true).assertTrue();
      done();
    });

    it('normal: persist_backlog_expanded_should_write_value_for_positive_plan_id', 0, async (done: Function) => {
      // Arrange
      const hooks = new PreferenceHooksAW();
      const pref = new PreferenceStoreMockAW();
      hooks.setInstance(pref as Object);
      // Act
      IndexStateManager.persistBacklogExpanded(104, true);
      await waitMsAW(10);
      hooks.restore();
      // Assert
      expect(pref.values.get(IndexStateManager.getBacklogExpandedKey(104)) === true).assertTrue();
      done();
    });

    it('boundary: persist_backlog_expanded_should_ignore_zero_plan_id', 0, async (done: Function) => {
      // Arrange
      const hooks = new PreferenceHooksAW();
      const pref = new PreferenceStoreMockAW();
      hooks.setInstance(pref as Object);
      // Act
      IndexStateManager.persistBacklogExpanded(0, true);
      await waitMsAW(10);
      hooks.restore();
      // Assert
      expect(pref.setCalls.length).assertEqual(0);
      done();
    });

    it('normal: is_day_collapsed_should_return_true_when_offset_present', 0, () => {
      // Arrange
      const collapsed = [1, 4, 7];
      // Act
      const value = IndexStateManager.isDayCollapsed(collapsed, 4);
      // Assert
      expect(value).assertTrue();
    });

    it('invalid: is_day_collapsed_should_return_false_for_empty_list', 0, () => {
      // Arrange
      const collapsed: number[] = [];
      // Act
      const value = IndexStateManager.isDayCollapsed(collapsed, 1);
      // Assert
      expect(value).assertFalse();
    });

    it('conflict: capture_sync_message_should_return_thrown_message_when_handler_conflicts', 0, () => {
      // Arrange
      // Act
      const message = captureSyncMessageAW(() => {
        throw new Error('conflict_aw');
      });
      // Assert
      expect(message).assertEqual('conflict_aw');
    });

    it('regression: normalize_day_start_should_keep_same_result_after_repeat_calls', 0, () => {
      // Arrange
      const input = new Date(2026, 3, 17, 16, 45, 30).getTime();
      // Act
      const first = normalizeDayStartAW(input);
      const second = normalizeDayStartAW(first);
      // Assert
      expect(first).assertEqual(second);
      expect(new Date(second).getHours()).assertEqual(0);
    });

    it('combined: wait_and_normalize_helpers_should_support_async_follow_up_flow', 0, async () => {
      // Arrange
      const input = new Date(2026, 3, 18, 11, 20, 10).getTime();
      // Act
      await waitMsAW(1);
      const message = captureSyncMessageAW(() => {});
      const normalized = normalizeDayStartAW(input);
      // Assert
      expect(message).assertEqual('');
      expect(new Date(normalized).getMinutes()).assertEqual(0);
      expect(new Date(normalized).getHours()).assertEqual(0);
    });
  });
}

