import { describe, expect, it } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  IndexDialogManager,
  SettingsCallbacks,
  ShareDialogCallbacks
} from '../main/ets/pages/index/IndexDialogManager';
import { IndexConflictHelper } from '../main/ets/pages/index/IndexConflictHelper';
import { IndexEventHandlers } from '../main/ets/pages/index/IndexEventHandlers';
import { IndexLifecycleHelper } from '../main/ets/pages/index/IndexLifecycleHelper';
import { IndexPageShowHelper } from '../main/ets/pages/index/IndexPageShowHelper';
import { IndexSettingsFlowHelper } from '../main/ets/pages/index/IndexSettingsFlowHelper';
import { InitDialogData } from '../main/ets/pages/index/IndexTypes';
import { TimelineInteractionHelper } from '../main/ets/viewmodel/TimelineInteractionHelper';
import { CompressionMode, CompressionPlan, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

function waitMsBS(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function buildEventBS(id: number, name: string = `E${id}`): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.duration = 60;
  event.fixed_start_time = '09:00';
  event.computed_time = '09:30';
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.lock_status = 0;
  event.note = '';
  event.priority = 0;
  event.latitude = 0;
  event.longitude = 0;
  event.gap_minutes = 0;
  event.conflict_msg = '';
  return event;
}

class DialogControllerMockBS {
  openCount: number = 0;

  open(): void {
    this.openCount += 1;
  }
}

class WeatherPreferenceBS implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CapturedDialogOptionsBS {
  alignmentLabel: string = '';
  autoCancel: boolean = false;
  customStyle: boolean = false;
  hasBuilder: boolean = false;
  hasOffset: boolean = false;
  offsetDy: number = 0;

  constructor(options: Object) {
    const alignment = Reflect.get(options as Object, 'alignment');
    this.alignmentLabel = alignment !== null && alignment !== undefined ? String(alignment) : '';

    const autoCancel = Reflect.get(options as Object, 'autoCancel');
    if (typeof autoCancel === 'boolean') {
      this.autoCancel = autoCancel;
    }

    const customStyle = Reflect.get(options as Object, 'customStyle');
    if (typeof customStyle === 'boolean') {
      this.customStyle = customStyle;
    }

    const builder = Reflect.get(options as Object, 'builder');
    this.hasBuilder = builder !== null && builder !== undefined;

    const offset = Reflect.get(options as Object, 'offset');
    if (offset !== null && offset !== undefined) {
      this.hasOffset = true;
      const dy = Reflect.get(offset as Object, 'dy');
      if (typeof dy === 'number') {
        this.offsetDy = dy;
      }
    }
  }
}

let activeDialogRecorderBS: DialogRecorderBS | null = null;

class CustomDialogControllerStubBS {
  dialogOptions: CapturedDialogOptionsBS;
  openCount: number = 0;

  constructor(options: Object, _owner?: Object) {
    this.dialogOptions = new CapturedDialogOptionsBS(options);
    if (activeDialogRecorderBS !== null) {
      activeDialogRecorderBS.record(this);
    }
  }

  open(): void {
    this.openCount += 1;
  }
}

class DialogAlignmentStubBS {
  Bottom: string = 'BOTTOM';
  Center: string = 'CENTER';
}

class DialogRecorderBS {
  private readonly originController: Object;
  private readonly originAlignment: Object;
  controllers: CustomDialogControllerStubBS[] = [];

  constructor() {
    this.originController = Reflect.get(globalThis as Object, 'CustomDialogController') as Object;
    this.originAlignment = Reflect.get(globalThis as Object, 'DialogAlignment') as Object;
  }

  install(): void {
    this.controllers = [];
    activeDialogRecorderBS = this;
    Reflect.set(globalThis as Object, 'CustomDialogController', CustomDialogControllerStubBS as Object);
    Reflect.set(globalThis as Object, 'DialogAlignment', new DialogAlignmentStubBS() as Object);
  }

  record(controller: CustomDialogControllerStubBS): void {
    this.controllers.push(controller);
  }

  restore(): void {
    activeDialogRecorderBS = null;
    Reflect.set(globalThis as Object, 'CustomDialogController', this.originController);
    Reflect.set(globalThis as Object, 'DialogAlignment', this.originAlignment);
  }
}

class SettingsVmMockBS {
  planStartDate: number = new Date(2026, 3, 30).getTime();
  preferenceReadCount: number = 0;

  getWeatherUserPreference(): WeatherUserPreference {
    this.preferenceReadCount += 1;
    return new WeatherPreferenceBS();
  }

  async updateWeatherUserPreference(_preference: WeatherUserPreference): Promise<void> {}

  isWeatherFeatureEnabled(): boolean {
    return false;
  }

  isExecutionWeatherStage(): boolean {
    return false;
  }

  async refreshPlanningWeather(_force: boolean): Promise<void> {}

  async refreshExecutionWeather(_force: boolean, _source: string): Promise<void> {}
}

class SettingsDefaultHooksBS {
  private readonly originCreateSettings: Object;
  private readonly originOpenPlanDatePicker: Object;
  private readonly originCreateRename: Object;
  private readonly originCreateShare: Object;
  private readonly originExportPlanToJson: Object;
  settingsController: DialogControllerMockBS = new DialogControllerMockBS();
  renameController: DialogControllerMockBS = new DialogControllerMockBS();
  shareController: DialogControllerMockBS = new DialogControllerMockBS();
  settingsCallbacks?: SettingsCallbacks;
  renameInitName: string = '';
  renameConfirm?: (name: string) => void;
  shareCallbacks?: ShareDialogCallbacks;
  pickerPlanStartDate: number = -1;
  pickerResultDateMs: number = new Date(2026, 4, 2).getTime();
  exportPlanId: number = -1;
  exportedJson: string = '{"from":"default_bs"}';

  constructor() {
    this.originCreateSettings = Reflect.get(IndexDialogManager as Object, 'createSettingsController') as Object;
    this.originOpenPlanDatePicker = Reflect.get(IndexDialogManager as Object, 'openPlanDatePicker') as Object;
    this.originCreateRename = Reflect.get(IndexDialogManager as Object, 'createRenameController') as Object;
    this.originCreateShare = Reflect.get(IndexDialogManager as Object, 'createShareController') as Object;
    this.originExportPlanToJson = Reflect.get(PlanImportExportService as Object, 'exportPlanToJson') as Object;
  }

  installSettings(): void {
    Reflect.set(IndexDialogManager as Object, 'createSettingsController', (callbacks: SettingsCallbacks): Object => {
      this.settingsCallbacks = callbacks;
      return this.settingsController as Object;
    });
    Reflect.set(
      IndexDialogManager as Object,
      'openPlanDatePicker',
      (_uiContext: UIContext, planStartDate: number, onAccept: (dateMs: number) => void): void => {
        this.pickerPlanStartDate = planStartDate;
        onAccept(this.pickerResultDateMs);
      }
    );
  }

  installRename(): void {
    Reflect.set(
      IndexDialogManager as Object,
      'createRenameController',
      (initName: string, onConfirm: (name: string) => void): Object => {
        this.renameInitName = initName;
        this.renameConfirm = onConfirm;
        return this.renameController as Object;
      }
    );
  }

  installShare(): void {
    Reflect.set(IndexDialogManager as Object, 'createShareController', (callbacks: ShareDialogCallbacks): Object => {
      this.shareCallbacks = callbacks;
      return this.shareController as Object;
    });
    Reflect.set(
      PlanImportExportService as Object,
      'exportPlanToJson',
      async (planId: number): Promise<string> => {
        this.exportPlanId = planId;
        return this.exportedJson;
      }
    );
  }

  restore(): void {
    Reflect.set(IndexDialogManager as Object, 'createSettingsController', this.originCreateSettings);
    Reflect.set(IndexDialogManager as Object, 'openPlanDatePicker', this.originOpenPlanDatePicker);
    Reflect.set(IndexDialogManager as Object, 'createRenameController', this.originCreateRename);
    Reflect.set(IndexDialogManager as Object, 'createShareController', this.originCreateShare);
    Reflect.set(PlanImportExportService as Object, 'exportPlanToJson', this.originExportPlanToJson);
  }
}

class ConflictVmMockBS {
  events: EventEntity[] = [];
  delayPlan: CompressionPlan = {
    status: 'COMPRESS_CONFIRM',
    msg: '',
    affectedItems: []
  };

  calculateDelayPlan(_index: number): CompressionPlan {
    return this.delayPlan;
  }
}

class AlertDialogButtonBS {
  value: string = '';
  action: () => void = () => {};
}

class AlertDialogOptionsBS {
  title: string = '';
  message: string = '';
  primaryButton: AlertDialogButtonBS = new AlertDialogButtonBS();
  secondaryButton: AlertDialogButtonBS = new AlertDialogButtonBS();
}

class AlertDialogHostBS {
  lastOptions?: AlertDialogOptionsBS;

  showAlertDialog(options: Object): void {
    this.lastOptions = options as AlertDialogOptionsBS;
  }
}

class ConflictSelectionHooksBS {
  private readonly originConflict: Object;
  controller: DialogControllerMockBS = new DialogControllerMockBS();
  conflictCallbacks?: Record<string, Function>;

  constructor() {
    this.originConflict = Reflect.get(IndexDialogManager as Object, 'createConflictSelectionController') as Object;
  }

  install(): void {
    Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', (callbacks: Object): Object => {
      this.conflictCallbacks = callbacks as Record<string, Function>;
      return this.controller as Object;
    });
  }

  restore(): void {
    Reflect.set(IndexDialogManager as Object, 'createConflictSelectionController', this.originConflict);
  }
}

class TimelineInteractionHooksBS {
  private readonly originHandleCommuteChange: Object;
  callCount: number = 0;
  lastMinutes: number = 0;
  lastGapEventId: number = -1;

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
          this.lastGapEventId = item.id;
          onGapFound(item);
        }
      }
    );
  }

  restore(): void {
    Reflect.set(TimelineInteractionHelper as Object, 'handleCommuteChange', this.originHandleCommuteChange);
  }
}

class EventHandlerVmMockBS {
  events: EventEntity[] = [];
}

class RouteParamsBS {
  planId: Object = 0;
  title: Object = '';
  isNewPlan: Object = false;
  autoStartFromReminder: Object = false;
  forceCompanionMode: Object = false;
  reminderEventId: Object = 0;
}

class RouterMockBS {
  private readonly params: Object;

  constructor(params: Object) {
    this.params = params;
  }

  getParams(): Record<string, Object> {
    return this.params as Record<string, Object>;
  }
}

class UiContextMockBS {
  private readonly router: RouterMockBS;

  constructor(params: Object) {
    this.router = new RouterMockBS(params);
  }

  getRouter(): RouterMockBS {
    return this.router;
  }
}

class LifecycleVmMockBS {
  loadPlanId: number = -1;
  unsavedKey: string = '';

  setHasUnsavedPostponeStorageKey(key: string): void {
    this.unsavedKey = key;
  }

  async loadData(planId: number): Promise<void> {
    this.loadPlanId = planId;
  }

  getStrategyMode(): number {
    return 2;
  }

  isWeatherFeatureEnabled(): boolean {
    return true;
  }

  shouldAutoRefreshPlanningWeather(): boolean {
    return false;
  }

  async refreshPlanningWeather(_force: boolean): Promise<void> {}

  stopExecutionWeatherScheduler(): void {}
}

class PageShowVmMockBS {
  reloadMinEventDurationLimit(): Promise<void> {
    return Promise.resolve();
  }

  reloadRouteSwitches(): Promise<void> {
    return Promise.resolve();
  }
}

class PageShowProbeBS {
  startCount: number = 0;
  refreshCount: number = 0;
  clearCount: number = 0;
  toastCount: number = 0;
  openCount: number = 0;
  lastDialogData?: InitDialogData;
  private readonly tempStateRaw: string;
  private readonly pickedRaw: string;

  constructor(tempStateRaw: string, pickedRaw: string) {
    this.tempStateRaw = tempStateRaw;
    this.pickedRaw = pickedRaw;
  }

  run(): void {
    IndexPageShowHelper.handlePageShow({
      vm: new PageShowVmMockBS() as Object as TimelineViewModel,
      onStartArrivalReminderEngine: () => {
        this.startCount += 1;
      },
      onRefreshUnsavedFlag: () => {
        this.refreshCount += 1;
      },
      onReadDraftStorage: (key: string) => {
        if (key === AppStorageKeys.TEMP_DIALOG_STATE) {
          return this.tempStateRaw;
        }
        if (key === AppStorageKeys.PICKED_LOCATION_STR) {
          return this.pickedRaw;
        }
        return '';
      },
      onClearDraftStorage: () => {
        this.clearCount += 1;
      },
      onOpenDialog: (initData?: InitDialogData) => {
        this.openCount += 1;
        this.lastDialogData = initData;
      },
      onSafeToast: (_message: string) => {
        this.toastCount += 1;
      },
      onSanitizeError: (_error: Object) => 'sanitized_bs'
    });
  }
}

function buildTempStateRawBS(name: string, dayOffset: number): string {
  return JSON.stringify({
    name: name,
    note: 'note',
    duration: 45,
    isAnchor: false,
    fixedTime: '08:30',
    dayOffset: dayOffset,
    isSchedule: true,
    lat: 10.1,
    lng: 20.2
  });
}

export default function phase2BatchBSTest() {
  describe('phase2BatchBS_index_dialog_manager', () => {
    it('normal: create_bottom_sheet_controllers_should_capture_expected_flags', 0, () => {
      // Arrange
      const recorder = new DialogRecorderBS();
      recorder.install();

      // Act
      const dateController = IndexDialogManager.createDateFilterController({
        onShowAll: () => {},
        onSelectDate: () => {},
        onSelectRange: () => {}
      }) as Object as CustomDialogControllerStubBS;
      const settingsController = IndexDialogManager.createSettingsController({
        onRename: () => {},
        onReschedule: () => {},
        onShare: () => {},
        weatherUserPreference: new WeatherPreferenceBS(),
        onWeatherPreferenceChange: async (_preference: WeatherUserPreference) => {}
      }) as Object as CustomDialogControllerStubBS;
      recorder.restore();

      // Assert
      expect(recorder.controllers.length).assertEqual(2);
      expect(dateController.dialogOptions.alignmentLabel).assertEqual('BOTTOM');
      expect(dateController.dialogOptions.autoCancel).assertTrue();
      expect(dateController.dialogOptions.customStyle).assertTrue();
      expect(dateController.dialogOptions.hasBuilder).assertTrue();
      expect(settingsController.dialogOptions.alignmentLabel).assertEqual('BOTTOM');
      expect(settingsController.dialogOptions.autoCancel).assertTrue();
      expect(settingsController.dialogOptions.customStyle).assertTrue();
    });

    it('boundary: create_center_dialog_controllers_should_capture_expected_flags', 0, () => {
      // Arrange
      const recorder = new DialogRecorderBS();
      recorder.install();
      const vm = new ConflictVmMockBS();

      // Act
      const renameController = IndexDialogManager.createRenameController('origin', (_name: string) => {}) as Object as CustomDialogControllerStubBS;
      const aiController = IndexDialogManager.createAiDialogController({
        hasAiHistory: true,
        onConfirm: async (_text: string, _strategy: number) => {},
        onRegenerate: async (_strategy: number) => {}
      }) as Object as CustomDialogControllerStubBS;
      const suggestionController = IndexDialogManager.createSuggestionController({
        itemName: 'A',
        conflictName: 'B',
        targetTime: '09:00',
        suggestedTime: '09:20',
        detailMsg: 'detail',
        onConfirm: () => {},
        onBack: () => {}
      }) as Object as CustomDialogControllerStubBS;
      const selectionController = IndexDialogManager.createConflictSelectionController({
        gapMinutes: 12,
        onDelayY: () => {},
        onCompressX: () => {},
        onShiftSameDay: () => {},
        onAdvanceAdjust: () => {},
        onSmartAdjust: () => {}
      }) as Object as CustomDialogControllerStubBS;
      const compressController = IndexDialogManager.createConflictCompressController({
        vm: vm as Object as TimelineViewModel,
        targetIndex: 0,
        targetTime: '09:00',
        targetName: 'A',
        initialMode: 'RATIO',
        initialSelectedIds: [1],
        onCancel: () => {},
        onConfirm: (_ids: number[], _mode: CompressionMode) => {}
      }) as Object as CustomDialogControllerStubBS;
      const advanceController = IndexDialogManager.createAdvanceAdjustController({
        vm: vm as Object as TimelineViewModel,
        targetIndex: 0,
        targetName: 'A',
        onCancel: () => {},
        onConfirm: (_ids: number[], _time: string) => {}
      }) as Object as CustomDialogControllerStubBS;
      const shareController = IndexDialogManager.createShareController({
        planId: 7,
        planTitle: 'share',
        startDate: 1,
        endDate: 2,
        totalDays: 1,
        totalEvents: 1,
        compressedJson: '{}'
      }) as Object as CustomDialogControllerStubBS;
      recorder.restore();

      // Assert
      expect(recorder.controllers.length).assertEqual(7);
      expect(renameController.dialogOptions.alignmentLabel).assertEqual('CENTER');
      expect(renameController.dialogOptions.autoCancel).assertTrue();
      expect(renameController.dialogOptions.customStyle).assertFalse();
      expect(aiController.dialogOptions.alignmentLabel).assertEqual('CENTER');
      expect(aiController.dialogOptions.autoCancel).assertFalse();
      expect(aiController.dialogOptions.customStyle).assertTrue();
      expect(suggestionController.dialogOptions.customStyle).assertTrue();
      expect(selectionController.dialogOptions.autoCancel).assertFalse();
      expect(compressController.dialogOptions.autoCancel).assertFalse();
      expect(advanceController.dialogOptions.autoCancel).assertFalse();
      expect(shareController.dialogOptions.alignmentLabel).assertEqual('CENTER');
    });

    it('combined: create_special_dialog_controllers_should_capture_offset_and_conflict_flags', 0, () => {
      // Arrange
      const recorder = new DialogRecorderBS();
      recorder.install();
      const vm = new ConflictVmMockBS();

      // Act
      const gapController = IndexDialogManager.createGapResolutionController({
        vm: vm as Object as TimelineViewModel,
        currentGap: null
      }) as Object as CustomDialogControllerStubBS;
      const conflictController = IndexDialogManager.createDateConflictController({
        conflictDateStr: '2026-04-20',
        planStartDateStr: '2026-04-18',
        planStartDate: 100,
        onChangeItemDate: () => {},
        onMoveToBacklog: () => {},
        onChangePlanStartDate: () => {},
        onCancel: () => {}
      }) as Object as CustomDialogControllerStubBS;
      const addController = IndexDialogManager.createAddItemController({
        initName: 'spot',
        initNote: 'note',
        initDuration: 60,
        initIsAnchor: false,
        initFixedTime: '09:00',
        initSuggestedTime: '09:20',
        initIsSchedule: true,
        initDayOffset: 1,
        initPreTravel: 0,
        initPriority: 0,
        storageScopePlanId: 8,
        planStartDate: 9,
        initLat: 0,
        initLng: 0,
        onDateChangedRecommendTime: (_dayOffset: number, currentTime: string) => currentTime,
        onConfirm: async (
          _name: string,
          _duration: number,
          _isSchedule: boolean
        ): Promise<void> => {}
      }) as Object as CustomDialogControllerStubBS;
      recorder.restore();

      // Assert
      expect(recorder.controllers.length).assertEqual(3);
      expect(gapController.dialogOptions.hasOffset).assertTrue();
      expect(gapController.dialogOptions.offsetDy).assertEqual(0);
      expect(gapController.dialogOptions.customStyle).assertTrue();
      expect(conflictController.dialogOptions.autoCancel).assertFalse();
      expect(addController.dialogOptions.hasOffset).assertTrue();
      expect(addController.dialogOptions.offsetDy).assertEqual(-50);
      expect(addController.dialogOptions.autoCancel).assertTrue();
      expect(addController.dialogOptions.customStyle).assertTrue();
    });
  });

  describe('phase2BatchBS_index_settings_flow_helper', () => {
    it('regression: open_settings_dialog_without_deps_should_use_default_dialog_manager_and_picker', 0, async (done: Function) => {
      // Arrange
      const hooks = new SettingsDefaultHooksBS();
      hooks.installSettings();
      const vm = new SettingsVmMockBS();
      let receivedDateMs = -1;

      // Act
      try {
        IndexSettingsFlowHelper.openSettingsDialog({
          uiContext: new Object() as UIContext,
          vm: vm as Object as TimelineViewModel,
          onRename: () => {},
          onReschedule: (dateMs: number) => {
            receivedDateMs = dateMs;
          },
          onShare: async () => {},
          onWeatherPreferenceError: () => {}
        });
        (hooks.settingsCallbacks as SettingsCallbacks).onReschedule();
        await waitMsBS(130);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(hooks.settingsController.openCount).assertEqual(1);
      expect(vm.preferenceReadCount).assertEqual(1);
      expect(hooks.pickerPlanStartDate).assertEqual(vm.planStartDate);
      expect(receivedDateMs).assertEqual(hooks.pickerResultDateMs);
      done();
    });

    it('boundary: open_rename_dialog_without_deps_should_use_default_rename_factory', 0, () => {
      // Arrange
      const hooks = new SettingsDefaultHooksBS();
      hooks.installRename();
      let receivedName = '';

      // Act
      try {
        IndexSettingsFlowHelper.openRenameDialog('plan_bs', (name: string) => {
          receivedName = name;
        });
        (hooks.renameConfirm as (name: string) => void)('renamed_bs');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(hooks.renameController.openCount).assertEqual(1);
      expect(hooks.renameInitName).assertEqual('plan_bs');
      expect(receivedName).assertEqual('renamed_bs');
    });

    it('normal: open_share_dialog_without_deps_should_use_default_export_and_share_factory', 0, async (done: Function) => {
      // Arrange
      const hooks = new SettingsDefaultHooksBS();
      hooks.installShare();
      const schedule = buildEventBS(71);
      schedule.dynamic_day_offset = 2;
      schedule.day_offset = 0;

      // Act
      let controller: CustomDialogController | null = null;
      try {
        controller = await IndexSettingsFlowHelper.openShareDialog({
          planId: 71,
          planTitle: 'share_bs',
          planStartDate: new Date(2026, 3, 18).getTime(),
          events: [schedule]
        });
      } finally {
        hooks.restore();
      }

      // Assert
      expect((controller as Object) !== null).assertTrue();
      expect(hooks.exportPlanId).assertEqual(71);
      expect(hooks.shareController.openCount).assertEqual(1);
      expect((hooks.shareCallbacks as ShareDialogCallbacks).compressedJson).assertEqual(hooks.exportedJson);
      expect((hooks.shareCallbacks as ShareDialogCallbacks).totalEvents).assertEqual(1);
      expect((hooks.shareCallbacks as ShareDialogCallbacks).totalDays).assertEqual(3);
      done();
    });
  });

  describe('phase2BatchBS_index_conflict_helper', () => {
    it('invalid: resolve_conflict_gap_should_use_positive_fallback_when_message_invalid', 0, () => {
      // Arrange
      const event = buildEventBS(81);
      event.gap_minutes = 0;
      event.conflict_msg = 'no-valid-gap';

      // Act
      const gap = IndexConflictHelper.resolveConflictGapMinutes(event, 14);

      // Assert
      expect(gap).assertEqual(14);
    });

    it('conflict: handle_event_conflict_action_should_reopen_menu_with_latest_gap_after_preview_back', 0, () => {
      // Arrange
      const vm = new ConflictVmMockBS();
      const event = buildEventBS(82);
      event.conflict_msg = '仍有 33 分钟冲突';
      vm.events = [event];
      let previewCount = 0;
      let reopenedGap = -1;
      let reopenedTime = '';

      // Act
      IndexConflictHelper.handleEventConflictAction(
        vm as Object as TimelineViewModel,
        event,
        'delay',
        12,
        undefined,
        (_index: number, _target: EventEntity, _targetTime: string, _plan: CompressionPlan, _saveCallback: (t?: string) => void,
          onBack: () => void) => {
          previewCount += 1;
          onBack();
        },
        () => {},
        () => {},
        (_index: number, _target: EventEntity, targetTime: string, gap: number, _saveCallback: (t?: string) => void) => {
          reopenedGap = gap;
          reopenedTime = targetTime;
        }
      );

      // Assert
      expect(previewCount).assertEqual(1);
      expect(reopenedGap).assertEqual(33);
      expect(reopenedTime).assertEqual('09:00');
    });

    it('boundary: show_compression_blocked_dialog_should_use_target_time_when_suggestion_missing', 0, () => {
      // Arrange
      const alertHost = new AlertDialogHostBS();
      const vm = new ConflictVmMockBS();
      const event = buildEventBS(83);
      const plan: CompressionPlan = {
        status: 'OVERLOAD',
        msg: '',
        affectedItems: [],
        remainingGapMinutes: 7
      };
      let reopenCount = 0;
      let previewCount = 0;
      let reopenTargetTime = '';
      let reopenMode = '';

      // Act
      IndexConflictHelper.showCompressionBlockedDialog(
        alertHost as Object as UIContext,
        1,
        event,
        '09:40',
        plan,
        [1, 2],
        'RATIO',
        () => {},
        () => {},
        (_index: number, _item: EventEntity, targetTime: string, _saveFn: (t?: string) => void, _backFn: () => void,
          _presetSelectedIds: number[], presetMode: CompressionMode) => {
          reopenCount += 1;
          reopenTargetTime = targetTime;
          reopenMode = String(presetMode);
        },
        (_index: number, _item: EventEntity, targetTime: string, _plan: CompressionPlan, _saveFn: (t?: string) => void, _backFn: () => void) => {
          previewCount += 1;
          reopenTargetTime = targetTime;
        },
        vm as Object as TimelineViewModel
      );
      const options = alertHost.lastOptions as AlertDialogOptionsBS;
      options.primaryButton.action();
      options.secondaryButton.action();

      // Assert
      expect(options.message.indexOf('09:40') >= 0).assertTrue();
      expect(reopenCount).assertEqual(1);
      expect(previewCount).assertEqual(1);
      expect(reopenTargetTime).assertEqual('09:40');
      expect(reopenMode).assertEqual('RATIO');
    });

    it('regression: open_conflict_menu_should_reopen_after_compress_back', 0, () => {
      // Arrange
      const hooks = new ConflictSelectionHooksBS();
      hooks.install();
      const vm = new ConflictVmMockBS();
      const event = buildEventBS(84);
      let compressCount = 0;

      // Act
      try {
        IndexConflictHelper.openConflictMenu(
          vm as Object as TimelineViewModel,
          0,
          event,
          '10:00',
          16,
          () => {},
          () => {},
          (_index: number, _target: EventEntity, _targetTime: string, _saveFn: (t?: string) => void, backFn: () => void) => {
            compressCount += 1;
            backFn();
          },
          () => {}
        );
        (hooks.conflictCallbacks as Record<string, Function>).onCompressX();
      } finally {
        hooks.restore();
      }

      // Assert
      expect(compressCount).assertEqual(1);
      expect(hooks.controller.openCount).assertEqual(2);
    });
  });

  describe('phase2BatchBS_index_event_handlers', () => {
    it('invalid: handle_date_conflict_should_block_when_archived_direct_wrapper_invoked', 0, () => {
      // Arrange
      const event = buildEventBS(91);
      let called = false;

      // Act
      IndexEventHandlers.handleDateConflict(
        true,
        event,
        'smart',
        18,
        (_target: EventEntity, _strategy: string, _gap: number) => {
          called = true;
        }
      );

      // Assert
      expect(called).assertFalse();
    });

    it('normal: handle_commute_change_should_forward_positive_minutes_to_interaction_helper', 0, () => {
      // Arrange
      const hooks = new TimelineInteractionHooksBS();
      hooks.install();
      const vm = new EventHandlerVmMockBS();
      const event = buildEventBS(92);
      let gapEventId = -1;

      // Act
      try {
        IndexEventHandlers.handleCommuteChange(
          vm as Object as TimelineViewModel,
          event,
          18,
          (target: EventEntity) => {
            gapEventId = target.id;
          }
        );
      } finally {
        hooks.restore();
      }

      // Assert
      expect(hooks.callCount).assertEqual(1);
      expect(hooks.lastMinutes).assertEqual(18);
      expect(gapEventId).assertEqual(92);
    });
  });

  describe('phase2BatchBS_index_lifecycle_helper', () => {
    it('normal: handle_about_to_appear_should_use_route_title_and_load_strategy_explanation', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMockBS();
      const params = new RouteParamsBS();
      params.planId = 101;
      params.title = '计划BS';
      let currentPlanId = -1;
      let title = '';
      let manualRefresh = true;
      let explanationCount = 0;

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMockBS(params) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (planId: number) => {
          currentPlanId = planId;
        },
        onSetManualWeatherRefresh: (value: boolean) => {
          manualRefresh = value;
        },
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (value: string) => {
          title = value;
        },
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {
          explanationCount += 1;
        },
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await waitMsBS(30);

      // Assert
      expect(currentPlanId).assertEqual(101);
      expect(vm.loadPlanId).assertEqual(101);
      expect(vm.unsavedKey.indexOf(AppStorageKeys.HAS_UNSAVED_POSTPONE) >= 0).assertTrue();
      expect(manualRefresh).assertFalse();
      expect(title).assertEqual('计划BS');
      expect(explanationCount).assertEqual(1);
      done();
    });
  });

  describe('phase2BatchBS_index_page_show_helper', () => {
    it('boundary: handle_page_show_should_clear_orphan_picked_without_toast', 0, () => {
      // Arrange
      const picked = JSON.stringify({
        lat: 22.6,
        lng: 114.1,
        address: 'picked_only'
      });
      const probe = new PageShowProbeBS('', picked);

      // Act
      probe.run();

      // Assert
      expect(probe.startCount).assertEqual(1);
      expect(probe.refreshCount).assertEqual(1);
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(0);
    });

    it('combined: handle_page_show_should_use_coordinate_fallback_name_when_picked_address_blank', 0, () => {
      // Arrange
      const picked = JSON.stringify({
        lat: 22.54321,
        lng: 114.12345,
        address: '   '
      });
      const probe = new PageShowProbeBS(buildTempStateRawBS('old_name', 4), picked);

      // Act
      probe.run();

      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(1);
      expect(((probe.lastDialogData as InitDialogData).name).indexOf('已选位置(') >= 0).assertTrue();
      expect((probe.lastDialogData as InitDialogData).lat).assertEqual(22.54321);
      expect((probe.lastDialogData as InitDialogData).lng).assertEqual(114.12345);
    });
  });
}
