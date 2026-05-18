import { describe, it, expect } from '@ohos/hypium';
import {
  AddItemDialogCallbacks,
  AdvanceAdjustCallbacks,
  AiDialogCallbacks,
  ConflictCompressCallbacks,
  ConflictSelectionCallbacks,
  DateConflictCallbacks,
  GapResolutionCallbacks,
  IndexDialogManager,
  SettingsCallbacks,
  ShareDialogCallbacks,
  SuggestionDialogCallbacks
} from '../main/ets/pages/index/IndexDialogManager';
import { WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { CompressionMode, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface DatePickerDialogOptionsLike {
  start: Date;
  end: Date;
  selected: Date;
  onAccept: (value: DatePickerResult) => void;
}

interface DateFilterCallbackBagLike {
  onShowAll: () => void;
  onSelectDate: () => void;
  onSelectRange: () => void;
}

class DatePickerResultMock {
  year: number;
  month: number;
  day: number;

  constructor(year: number, month: number, day: number) {
    this.year = year;
    this.month = month;
    this.day = day;
  }
}

class PickerUiContextMock {
  showCount: number = 0;
  dialogs: DatePickerDialogOptionsLike[] = [];

  showDatePickerDialog(options: DatePickerDialogOptionsLike): void {
    this.showCount += 1;
    this.dialogs.push(options);
  }
}

class DateFilterControllerMock {
  openCount: number = 0;

  open(): void {
    this.openCount += 1;
  }
}

class CapturedDialogOptionsLike {
  alignmentLabel: string = '';
  autoCancel: boolean = false;
  customStyle: boolean = false;
  hasBuilder: boolean = false;
  hasOffset: boolean = false;
  offsetDy: number = 0;

  constructor(options: Object) {
    const alignment = Reflect.get(options as Object, 'alignment') as Object | undefined | null;
    this.alignmentLabel = alignment === undefined || alignment === null ? '' : String(alignment);

    const autoCancel = Reflect.get(options as Object, 'autoCancel') as boolean | undefined;
    if (typeof autoCancel === 'boolean') {
      this.autoCancel = autoCancel;
    }

    const customStyle = Reflect.get(options as Object, 'customStyle') as boolean | undefined;
    if (typeof customStyle === 'boolean') {
      this.customStyle = customStyle;
    }

    const builder = Reflect.get(options as Object, 'builder') as Object | undefined | null;
    this.hasBuilder = builder !== undefined && builder !== null;

    const offset = Reflect.get(options as Object, 'offset') as Object | undefined | null;
    if (offset !== undefined && offset !== null) {
      this.hasOffset = true;
      const dy = Reflect.get(offset as Object, 'dy') as number | undefined;
      if (typeof dy === 'number') {
        this.offsetDy = dy;
      }
    }
  }
}

let activeDialogRecorder: DialogRecorderLike | null = null;

class CustomDialogControllerStubLike {
  dialogOptions: CapturedDialogOptionsLike;
  openCount: number = 0;

  constructor(options: Object, _owner?: Object) {
    this.dialogOptions = new CapturedDialogOptionsLike(options);
    if (activeDialogRecorder !== null) {
      activeDialogRecorder.record(this);
    }
  }

  open(): void {
    this.openCount += 1;
  }
}

class DialogAlignmentStubLike {
  Bottom: string = 'BOTTOM';
  Center: string = 'CENTER';
}

class DialogRecorderLike {
  private readonly originController: Object;
  private readonly originAlignment: Object;
  controllers: CustomDialogControllerStubLike[] = [];

  constructor() {
    this.originController = Reflect.get(globalThis as Object, 'CustomDialogController') as Object;
    this.originAlignment = Reflect.get(globalThis as Object, 'DialogAlignment') as Object;
  }

  install(): void {
    this.controllers = [];
    activeDialogRecorder = this;
    Reflect.set(globalThis as Object, 'CustomDialogController', CustomDialogControllerStubLike as Object);
    Reflect.set(globalThis as Object, 'DialogAlignment', new DialogAlignmentStubLike() as Object);
  }

  record(controller: CustomDialogControllerStubLike): void {
    this.controllers.push(controller);
  }

  restore(): void {
    activeDialogRecorder = null;
    Reflect.set(globalThis as Object, 'CustomDialogController', this.originController);
    Reflect.set(globalThis as Object, 'DialogAlignment', this.originAlignment);
  }
}

class WeatherPreferenceStubLike implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class TimelineVmStubLike {
}

export default function indexDialogManagerTest() {
  describe('unit_test_case_generator_autofill_IndexDialogManager', () => {
    it('normal: open_plan_date_picker_should_emit_day_start_timestamp', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let actualDateMs = -1;

      // Act
      IndexDialogManager.openPlanDatePicker(uiContext as Object as UIContext, 0, (dateMs: number) => {
        actualDateMs = dateMs;
      });
      const accept = new DatePickerResultMock(2026, 3, 8);
      uiContext.dialogs[0].onAccept(accept as Object as DatePickerResult);

      // Assert
      const expected = new Date();
      expected.setFullYear(2026, 3, 8);
      expected.setHours(0, 0, 0, 0);
      expect(actualDateMs).assertEqual(expected.getTime());
    });

    it('boundary: open_range_end_picker_should_emit_end_of_day_timestamp', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const startDate = new Date(2026, 3, 9, 0, 0, 0, 0);
      let actualStartMs = -1;
      let actualEndMs = -1;

      // Act
      IndexDialogManager.openRangeEndDatePicker(uiContext as Object as UIContext, startDate, (startMs: number, endMs: number) => {
        actualStartMs = startMs;
        actualEndMs = endMs;
      });
      const accept = new DatePickerResultMock(2026, 3, 10);
      uiContext.dialogs[0].onAccept(accept as Object as DatePickerResult);

      // Assert
      const expectedEnd = new Date();
      expectedEnd.setFullYear(2026, 3, 10);
      expectedEnd.setHours(23, 59, 59, 999);
      expect(actualStartMs).assertEqual(startDate.getTime());
      expect(actualEndMs).assertEqual(expectedEnd.getTime());
    });

    it('invalid: open_single_date_filter_picker_should_work_when_plan_start_is_zero', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let actualDateMs = -1;

      // Act
      IndexDialogManager.openSingleDateFilterPicker(uiContext as Object as UIContext, 0, (dateMs: number) => {
        actualDateMs = dateMs;
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      const accept = new DatePickerResultMock(2026, 4, 1);
      uiContext.dialogs[0].onAccept(accept as Object as DatePickerResult);

      // Assert
      const expected = new Date();
      expected.setFullYear(2026, 4, 1);
      expected.setHours(0, 0, 0, 0);
      expect(uiContext.showCount).assertEqual(1);
      expect(actualDateMs).assertEqual(expected.getTime());
      done();
    });

    it('conflict: open_range_date_filter_picker_should_open_end_picker_after_start_selection', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let startMs = -1;
      let endMs = -1;

      // Act
      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 3, 5).getTime(),
        (s: number, e: number) => {
          startMs = s;
          endMs = e;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      const firstAccept = new DatePickerResultMock(2026, 3, 11);
      uiContext.dialogs[0].onAccept(firstAccept as Object as DatePickerResult);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 360);
      });

      // Assert
      expect(uiContext.showCount).assertEqual(2);
      const expectedStart = new Date();
      expectedStart.setFullYear(2026, 3, 11);
      expectedStart.setHours(0, 0, 0, 0);
      expect(uiContext.dialogs[1].start.getTime()).assertEqual(expectedStart.getTime());
      expect(startMs).assertEqual(-1);
      expect(endMs).assertEqual(-1);
      done();
    });

    it('regression: open_range_date_filter_picker_should_emit_selected_range_when_end_accepted', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let actualStartMs = -1;
      let actualEndMs = -1;

      // Act
      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 3, 5).getTime(),
        (startMs: number, endMs: number) => {
          actualStartMs = startMs;
          actualEndMs = endMs;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      const firstAccept = new DatePickerResultMock(2026, 3, 14);
      uiContext.dialogs[0].onAccept(firstAccept as Object as DatePickerResult);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 360);
      });
      const secondAccept = new DatePickerResultMock(2026, 3, 16);
      uiContext.dialogs[1].onAccept(secondAccept as Object as DatePickerResult);

      // Assert
      const expectedStart = new Date();
      expectedStart.setFullYear(2026, 3, 14);
      expectedStart.setHours(0, 0, 0, 0);
      const expectedEnd = new Date();
      expectedEnd.setFullYear(2026, 3, 16);
      expectedEnd.setHours(23, 59, 59, 999);
      expect(actualStartMs).assertEqual(expectedStart.getTime());
      expect(actualEndMs).assertEqual(expectedEnd.getTime());
      done();
    });

    it('combined: single_and_plan_picker_should_keep_callbacks_isolated', 0, async (done: Function) => {
      // Arrange
      const singleUi = new PickerUiContextMock();
      const planUi = new PickerUiContextMock();
      let singleDateMs = -1;
      let planDateMs = -1;

      // Act
      IndexDialogManager.openSingleDateFilterPicker(singleUi as Object as UIContext, new Date(2026, 0, 1).getTime(), (dateMs: number) => {
        singleDateMs = dateMs;
      });
      IndexDialogManager.openPlanDatePicker(planUi as Object as UIContext, new Date(2026, 0, 2).getTime(), (dateMs: number) => {
        planDateMs = dateMs;
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      singleUi.dialogs[0].onAccept(new DatePickerResultMock(2026, 0, 5) as Object as DatePickerResult);
      planUi.dialogs[0].onAccept(new DatePickerResultMock(2026, 0, 6) as Object as DatePickerResult);

      // Assert
      const expectedSingle = new Date();
      expectedSingle.setFullYear(2026, 0, 5);
      expectedSingle.setHours(0, 0, 0, 0);
      const expectedPlan = new Date();
      expectedPlan.setFullYear(2026, 0, 6);
      expectedPlan.setHours(0, 0, 0, 0);
      expect(singleDateMs).assertEqual(expectedSingle.getTime());
      expect(planDateMs).assertEqual(expectedPlan.getTime());
      done();
    });

    it('regression: open_date_filter_dialog_should_wrap_select_callbacks_with_plan_context', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const controller = new DateFilterControllerMock();
      const planStartDate = new Date(2026, 3, 20).getTime();
      let showAllCount = 0;
      let singleCalled = false;
      let rangeCalled = false;
      let singlePlanStartDate = -1;
      let rangePlanStartDate = -1;
      let capturedCallbacks: DateFilterCallbackBagLike = {
        onShowAll: (): void => {},
        onSelectDate: (): void => {},
        onSelectRange: (): void => {}
      };
      const originalCreate = Reflect.get(IndexDialogManager as Object, 'createDateFilterController') as (callbacks: Object) => Object;
      const originalOpenSingle = Reflect.get(IndexDialogManager as Object, 'openSingleDateFilterPicker') as (
        uiContext: UIContext,
        startDate: number,
        onAccept: (dateMs: number) => void
      ) => void;
      const originalOpenRange = Reflect.get(IndexDialogManager as Object, 'openRangeDateFilterPicker') as (
        uiContext: UIContext,
        startDate: number,
        onAccept: (startMs: number, endMs: number) => void
      ) => void;

      Reflect.set(IndexDialogManager as Object, 'createDateFilterController', (callbacks: Object): Object => {
        capturedCallbacks = callbacks as DateFilterCallbackBagLike;
        return controller as Object;
      });
      Reflect.set(
        IndexDialogManager as Object,
        'openSingleDateFilterPicker',
        (_uiContext: UIContext, startDate: number, _onAccept: (dateMs: number) => void): void => {
          singleCalled = true;
          singlePlanStartDate = startDate;
        }
      );
      Reflect.set(
        IndexDialogManager as Object,
        'openRangeDateFilterPicker',
        (_uiContext: UIContext, startDate: number, _onAccept: (startMs: number, endMs: number) => void): void => {
          rangeCalled = true;
          rangePlanStartDate = startDate;
        }
      );

      try {
        // Act
        const returnedController = IndexDialogManager.openDateFilterDialog(
          uiContext as Object as UIContext,
          planStartDate,
          {
            onShowAll: (): void => {
              showAllCount += 1;
            },
            onSelectDate: (_dateMs: number): void => {
            },
            onSelectRange: (_startMs: number, _endMs: number): void => {
            }
          }
        ) as Object;
        capturedCallbacks.onShowAll();
        capturedCallbacks.onSelectDate();
        capturedCallbacks.onSelectRange();

        // Assert
        expect(returnedController === controller as Object).assertTrue();
        expect(controller.openCount).assertEqual(1);
        expect(showAllCount).assertEqual(1);
        expect(singleCalled).assertTrue();
        expect(rangeCalled).assertTrue();
        expect(singlePlanStartDate).assertEqual(planStartDate);
        expect(rangePlanStartDate).assertEqual(planStartDate);
      } finally {
        Reflect.set(IndexDialogManager as Object, 'createDateFilterController', originalCreate);
        Reflect.set(IndexDialogManager as Object, 'openSingleDateFilterPicker', originalOpenSingle);
        Reflect.set(IndexDialogManager as Object, 'openRangeDateFilterPicker', originalOpenRange);
      }
    });

    it('normal: create_date_filter_settings_rename_and_suggestion_controllers_should_keep_expected_dialog_config', 0, () => {
      // Arrange
      const weatherPreference = new WeatherPreferenceStubLike();

      // Act
      const dateController = IndexDialogManager.createDateFilterController({
        onShowAll: (): void => {},
        onSelectDate: (): void => {},
        onSelectRange: (): void => {}
      }) as Object;
      const settingsController = IndexDialogManager.createSettingsController({
          onRename: (): void => {},
          onReschedule: (): void => {},
          onShare: (): void => {},
          weatherUserPreference: weatherPreference,
          onWeatherPreferenceChange: async (_preference): Promise<void> => {}
        } as SettingsCallbacks) as Object;
      const renameController = IndexDialogManager.createRenameController('trip-name', (_name: string): void => {}) as Object;
      const suggestionController = IndexDialogManager.createSuggestionController({
          itemName: 'museum',
          conflictName: 'traffic',
          targetTime: '09:00',
          suggestedTime: '09:30',
          detailMsg: 'shift by 30m',
          onConfirm: (): void => {},
          onBack: (): void => {}
        } as SuggestionDialogCallbacks) as Object;

      // Assert
      expect(typeof Reflect.get(dateController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(settingsController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(renameController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(suggestionController, 'open')).assertEqual('function');
    });

    it('boundary: create_ai_dialog_controller_should_cover_default_and_explicit_strategy_mode_paths', 0, () => {
      // Arrange
      const defaultCallbacks: AiDialogCallbacks = {
        hasAiHistory: true,
        onConfirm: async (_text: string, _strategy: number): Promise<void> => {},
        onRegenerate: async (_strategy: number): Promise<void> => {}
      };
      const explicitCallbacks: AiDialogCallbacks = {
        hasAiHistory: true,
        currentStrategyMode: 2,
        onConfirm: async (_text: string, _strategy: number): Promise<void> => {},
        onRegenerate: async (_strategy: number): Promise<void> => {}
      };
      // Act
      const defaultController = IndexDialogManager.createAiDialogController(defaultCallbacks) as Object;
      const explicitController = IndexDialogManager.createAiDialogController(explicitCallbacks) as Object;

      // Assert
      expect(defaultCallbacks.currentStrategyMode === undefined).assertTrue();
      expect(explicitCallbacks.currentStrategyMode).assertEqual(2);
      expect(typeof Reflect.get(defaultController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(explicitController, 'open')).assertEqual('function');
    });

    it('invalid: create_advance_adjust_controller_should_cover_missing_forced_gap_fallback', 0, () => {
      // Arrange
      const vm = new TimelineVmStubLike() as Object as TimelineViewModel;
      // Act
      const defaultController = IndexDialogManager.createAdvanceAdjustController({
          vm: vm,
          targetIndex: 1,
          targetName: 'station',
          onCancel: (): void => {},
          onConfirm: (_ids: number[], _nextStartTime: string): void => {}
        } as AdvanceAdjustCallbacks) as Object;
      const explicitController = IndexDialogManager.createAdvanceAdjustController({
          vm: vm,
          targetIndex: 2,
          targetName: 'museum',
          forcedGapMinutes: 25,
          onCancel: (): void => {},
          onConfirm: (_ids: number[], _nextStartTime: string): void => {}
        } as AdvanceAdjustCallbacks) as Object;

      // Assert
      expect(typeof Reflect.get(defaultController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(explicitController, 'open')).assertEqual('function');
    });

    it('conflict: create_conflict_and_date_conflict_controllers_should_keep_non_auto_cancel_flow', 0, () => {
      // Arrange
      const vm = new TimelineVmStubLike() as Object as TimelineViewModel;
      // Act
      const selectionController = IndexDialogManager.createConflictSelectionController({
          gapMinutes: 45,
          onDelayY: (): void => {},
          onCompressX: (): void => {},
          onShiftSameDay: (): void => {},
          onAdvanceAdjust: (): void => {},
          onSmartAdjust: (): void => {}
        } as ConflictSelectionCallbacks) as Object;
      const compressController = IndexDialogManager.createConflictCompressController({
          vm: vm,
          targetIndex: 3,
          targetTime: '10:00',
          targetName: 'bridge',
          initialMode: 'RATIO' as CompressionMode,
          initialSelectedIds: [1, 2],
          onCancel: (): void => {},
          onConfirm: (_ids: number[], _mode: CompressionMode): void => {}
        } as ConflictCompressCallbacks) as Object;
      const dateConflictController = IndexDialogManager.createDateConflictController({
          conflictDateStr: '2026-05-16',
          planStartDateStr: '2026-05-15',
          planStartDate: new Date(2026, 4, 15).getTime(),
          onChangeItemDate: (): void => {},
          onMoveToBacklog: (): void => {},
          onChangePlanStartDate: (): void => {},
          onCancel: (): void => {}
        } as DateConflictCallbacks) as Object;

      // Assert
      expect(typeof Reflect.get(selectionController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(compressController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(dateConflictController, 'open')).assertEqual('function');
    });

    it('regression: create_gap_add_and_share_controllers_should_preserve_offset_and_style_contract', 0, () => {
      // Arrange
      const vm = new TimelineVmStubLike() as Object as TimelineViewModel;

      // Act
      const gapController = IndexDialogManager.createGapResolutionController({
          vm: vm,
          currentGap: null
        } as GapResolutionCallbacks) as Object;
      const addController = IndexDialogManager.createAddItemController({
          initName: 'cafe',
          initNote: 'window seat',
          initDuration: 90,
          initIsAnchor: false,
          initFixedTime: '11:00',
          initSuggestedTime: '11:10',
          initIsSchedule: true,
          initDayOffset: 1,
          initPreTravel: 15,
          initPriority: 2,
          storageScopePlanId: 9,
          planStartDate: new Date(2026, 4, 16).getTime(),
          initLat: 31.2,
          initLng: 121.5,
          onDateChangedRecommendTime: (_dayOffset: number, currentTime: string): string => currentTime,
          onConfirm: async (
            _name: string,
            _duration: number,
            _isSchedule: boolean
          ): Promise<void> => {}
        } as AddItemDialogCallbacks) as Object;
      const shareController = IndexDialogManager.createShareController({
          planId: 9,
          planTitle: 'weekend',
          startDate: 1,
          endDate: 2,
          totalDays: 2,
          totalEvents: 5,
          compressedJson: '{"id":9}'
        } as ShareDialogCallbacks) as Object;

      // Assert
      expect(typeof Reflect.get(gapController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(addController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(shareController, 'open')).assertEqual('function');
    });

    it('combined: controller_matrix_should_expose_builder_and_default_fallbacks_for_target_wrappers', 0, () => {
      // Arrange
      const vm = new TimelineVmStubLike() as Object as TimelineViewModel;

      // Act
      const controllers = [
        IndexDialogManager.createDateFilterController({
          onShowAll: (): void => {},
          onSelectDate: (): void => {},
          onSelectRange: (): void => {}
        }) as Object,
        IndexDialogManager.createAiDialogController({
          hasAiHistory: false,
          currentStrategyMode: 1,
          onConfirm: async (_text: string, _strategy: number): Promise<void> => {},
          onRegenerate: async (_strategy: number): Promise<void> => {}
        } as AiDialogCallbacks) as Object,
        IndexDialogManager.createAddItemController({
          initName: 'park',
          initNote: '',
          initDuration: 30,
          initIsAnchor: true,
          initFixedTime: '',
          initSuggestedTime: '14:00',
          initIsSchedule: false,
          initDayOffset: 0,
          initPreTravel: 0,
          initPriority: 0,
          storageScopePlanId: 2,
          planStartDate: 3,
          initLat: 0,
          initLng: 0,
          onDateChangedRecommendTime: (_dayOffset: number, currentTime: string): string => currentTime,
          onConfirm: async (
            _name: string,
            _duration: number,
            _isSchedule: boolean
          ): Promise<void> => {}
        } as AddItemDialogCallbacks) as Object,
        IndexDialogManager.createGapResolutionController({
          vm: vm,
          currentGap: null
        } as GapResolutionCallbacks) as Object
      ];

      // Assert
      expect(controllers.length).assertEqual(4);
      for (let i = 0; i < controllers.length; i++) {
        expect(typeof Reflect.get(controllers[i], 'open')).assertEqual('function');
      }
    });

    it('combined: controller_matrix_should_keep_remaining_wrapper_defaults_consistent', 0, () => {
      // Arrange
      const weatherPreference = new WeatherPreferenceStubLike();

      // Act
      const controllers = [
        IndexDialogManager.createSettingsController({
          onRename: (): void => {},
          onReschedule: (): void => {},
          onShare: (): void => {},
          weatherUserPreference: weatherPreference,
          onWeatherPreferenceChange: async (_preference): Promise<void> => {}
        } as SettingsCallbacks) as Object,
        IndexDialogManager.createRenameController(
          'trip',
          (_name: string): void => {}
        ) as Object,
        IndexDialogManager.createShareController({
          planId: 3,
          planTitle: 'trip',
          startDate: 1,
          endDate: 2,
          totalDays: 2,
          totalEvents: 6,
          compressedJson: '{}'
        } as ShareDialogCallbacks) as Object
      ];

      // Assert
      expect(controllers.length).assertEqual(3);
      for (let i = 0; i < controllers.length; i++) {
        expect(typeof Reflect.get(controllers[i], 'open')).assertEqual('function');
      }
    });

    it('boundary: open_date_filter_dialog_should_open_returned_controller_once', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const originalCreate = Reflect.get(IndexDialogManager as Object, 'createDateFilterController') as (callbacks: Object) => Object;
      const controllerStub = new DateFilterControllerMock();

      Reflect.set(IndexDialogManager as Object, 'createDateFilterController', (_callbacks: Object): Object => {
        return controllerStub as Object;
      });

      try {
        // Act
        const controller = IndexDialogManager.openDateFilterDialog(uiContext as Object as UIContext, 123, {
          onShowAll: (): void => {},
          onSelectDate: (_dateMs: number): void => {},
          onSelectRange: (_startMs: number, _endMs: number): void => {}
        });

        // Assert
        expect(controller === controllerStub as Object).assertTrue();
        expect(controllerStub.openCount).assertEqual(1);
      } finally {
        Reflect.set(IndexDialogManager as Object, 'createDateFilterController', originalCreate);
      }
    });

    it('boundary: open_single_date_filter_picker_should_use_plan_start_date_for_dialog_defaults', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const planStartDate = new Date(2026, 5, 2, 0, 0, 0, 0).getTime();

      // Act
      IndexDialogManager.openSingleDateFilterPicker(
        uiContext as Object as UIContext,
        planStartDate,
        (_dateMs: number): void => {}
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });

      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(uiContext.dialogs[0].start.getTime()).assertEqual(planStartDate);
      expect(uiContext.dialogs[0].selected.getTime()).assertEqual(planStartDate);
      expect(uiContext.dialogs[0].end.getTime()).assertEqual(4102416000000);
      done();
    });

    it('combined: open_range_end_date_picker_should_keep_start_date_as_dialog_contract_before_accept', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const startDate = new Date(2026, 6, 8, 0, 0, 0, 0);
      let acceptedStartMs = -1;
      let acceptedEndMs = -1;

      // Act
      IndexDialogManager.openRangeEndDatePicker(
        uiContext as Object as UIContext,
        startDate,
        (startMs: number, endMs: number): void => {
          acceptedStartMs = startMs;
          acceptedEndMs = endMs;
        }
      );

      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(uiContext.dialogs[0].start.getTime()).assertEqual(startDate.getTime());
      expect(uiContext.dialogs[0].selected.getTime()).assertEqual(startDate.getTime());
      expect(acceptedStartMs).assertEqual(-1);
      expect(acceptedEndMs).assertEqual(-1);
    });

    it('combined: open_date_filter_dialog_should_forward_wrapper_callbacks_to_single_and_range_pickers', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const originalCreate = Reflect.get(IndexDialogManager as Object, 'createDateFilterController') as (callbacks: Object) => Object;
      const originalSingle = Reflect.get(IndexDialogManager as Object, 'openSingleDateFilterPicker') as Object;
      const originalRange = Reflect.get(IndexDialogManager as Object, 'openRangeDateFilterPicker') as Object;
      const controllerStub = new DateFilterControllerMock();
      let capturedBag: Object | null = null;
      let singlePlanStartDate = -1;
      let rangePlanStartDate = -1;
      let selectedDateMs = -1;
      let selectedStartMs = -1;
      let selectedEndMs = -1;

      Reflect.set(IndexDialogManager as Object, 'createDateFilterController', (callbacks: Object): Object => {
        capturedBag = callbacks as DateFilterCallbackBagLike;
        return controllerStub as Object;
      });
      Reflect.set(IndexDialogManager as Object, 'openSingleDateFilterPicker', (_uiContext: UIContext, planStartDate: number, onAccept: (dateMs: number) => void): void => {
        singlePlanStartDate = planStartDate;
        onAccept(111);
      });
      Reflect.set(IndexDialogManager as Object, 'openRangeDateFilterPicker', (_uiContext: UIContext, planStartDate: number, onAccept: (startMs: number, endMs: number) => void): void => {
        rangePlanStartDate = planStartDate;
        onAccept(222, 333);
      });

      try {
        // Act
        const controller = IndexDialogManager.openDateFilterDialog(uiContext as Object as UIContext, 456, {
          onShowAll: (): void => {},
          onSelectDate: (dateMs: number): void => {
            selectedDateMs = dateMs;
          },
          onSelectRange: (startMs: number, endMs: number): void => {
            selectedStartMs = startMs;
            selectedEndMs = endMs;
          }
        });
        if (capturedBag !== null) {
          const callbackBag = capturedBag as DateFilterCallbackBagLike;
          callbackBag.onSelectDate();
          callbackBag.onSelectRange();
        }

        // Assert
        expect(controller === controllerStub as Object).assertTrue();
        expect(controllerStub.openCount).assertEqual(1);
        expect(singlePlanStartDate).assertEqual(456);
        expect(rangePlanStartDate).assertEqual(456);
        expect(selectedDateMs).assertEqual(111);
        expect(selectedStartMs).assertEqual(222);
        expect(selectedEndMs).assertEqual(333);
      } finally {
        Reflect.set(IndexDialogManager as Object, 'createDateFilterController', originalCreate);
        Reflect.set(IndexDialogManager as Object, 'openSingleDateFilterPicker', originalSingle);
        Reflect.set(IndexDialogManager as Object, 'openRangeDateFilterPicker', originalRange);
      }
    });

    it('combined: open_range_end_date_picker_should_emit_same_day_end_when_start_and_end_pick_same_date', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const startDate = new Date(2026, 7, 9, 0, 0, 0, 0);
      let actualStartMs = -1;
      let actualEndMs = -1;

      // Act
      IndexDialogManager.openRangeEndDatePicker(
        uiContext as Object as UIContext,
        startDate,
        (startMs: number, endMs: number): void => {
          actualStartMs = startMs;
          actualEndMs = endMs;
        }
      );
      uiContext.dialogs[0].onAccept(new DatePickerResultMock(2026, 7, 9) as Object as DatePickerResult);

      // Assert
      const expectedEnd = new Date();
      expectedEnd.setFullYear(2026, 7, 9);
      expectedEnd.setHours(23, 59, 59, 999);
      expect(actualStartMs).assertEqual(startDate.getTime());
      expect(actualEndMs).assertEqual(expectedEnd.getTime());
    });

    it('boundary: open_plan_date_picker_should_keep_explicit_plan_start_as_selected_before_accept', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const planStartDate = new Date(2026, 9, 3, 0, 0, 0, 0).getTime();
      let actualDateMs = -1;

      // Act
      IndexDialogManager.openPlanDatePicker(
        uiContext as Object as UIContext,
        planStartDate,
        (dateMs: number): void => {
          actualDateMs = dateMs;
        }
      );

      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(uiContext.dialogs[0].start.getTime()).assertEqual(946684800000);
      expect(uiContext.dialogs[0].selected.getTime()).assertEqual(planStartDate);
      expect(uiContext.dialogs[0].end.getTime()).assertEqual(4102416000000);
      expect(actualDateMs).assertEqual(-1);
    });
  });
}
