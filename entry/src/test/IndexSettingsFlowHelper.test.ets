import { describe, it, expect } from '@ohos/hypium';
import { TimelineDatePolicy } from '../main/ets/domain/policy/TimelineDatePolicy';
import { WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexSettingsFlowDeps, IndexSettingsFlowHelper } from '../main/ets/pages/index/IndexSettingsFlowHelper';
import { IndexDialogManager, SettingsCallbacks, ShareDialogCallbacks } from '../main/ets/pages/index/IndexDialogManager';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class DialogControllerMock {
  openCount: number = 0;

  open(): void {
    this.openCount += 1;
  }
}

class WeatherPreferenceMock implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class SettingsFlowVmMock {
  planStartDate: number = new Date(2026, 3, 20).getTime();
  updateCalled: boolean = false;
  refreshPlanningCount: number = 0;
  refreshExecutionCount: number = 0;
  weatherEnabled: boolean = true;
  executionWeatherStage: boolean = true;
  shouldThrowUpdate: boolean = false;

  getWeatherUserPreference(): WeatherUserPreference {
    return new WeatherPreferenceMock();
  }

  async updateWeatherUserPreference(_preference: WeatherUserPreference): Promise<void> {
    if (this.shouldThrowUpdate) {
      throw new Error('update_failed');
    }
    this.updateCalled = true;
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

class SettingsFlowDepsMock implements IndexSettingsFlowDeps {
  settingsController: DialogControllerMock = new DialogControllerMock();
  renameController: DialogControllerMock = new DialogControllerMock();
  shareController: DialogControllerMock = new DialogControllerMock();
  settingsCallbacks?: SettingsCallbacks;
  shareCallbacks?: ShareDialogCallbacks;
  renameInitName: string = '';
  renameConfirm?: (newName: string) => void;
  pickerDateMs: number = 123456789;
  exportedJson: string = '{"ok":true}';

  createSettingsController(callbacks: SettingsCallbacks): CustomDialogController {
    this.settingsCallbacks = callbacks;
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

  createShareController(callbacks: ShareDialogCallbacks): CustomDialogController {
    this.shareCallbacks = callbacks;
    return this.shareController as Object as CustomDialogController;
  }

  async exportPlanToJson(_planId: number): Promise<string> {
    return this.exportedJson;
  }
}

class UiContextMock {}

function buildShareEvent(id: number, status: number, dayOffset: number, dynamicDayOffset: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `E${id}`;
  event.status = status;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dynamicDayOffset;
  return event;
}

export default function indexSettingsFlowHelperTest() {
  describe('unit_test_case_generator_autofill_IndexSettingsFlowHelper', () => {
    it('normal: open_settings_dialog_should_open_and_refresh_weather_on_change', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMock();
      const deps = new SettingsFlowDepsMock();
      let errorCount = 0;

      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new UiContextMock() as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {},
        onReschedule: (_dateMs: number) => {},
        onShare: async () => {},
        onWeatherPreferenceError: () => {
          errorCount += 1;
        }
      }, deps);
      await (deps.settingsCallbacks as SettingsCallbacks).onWeatherPreferenceChange(new WeatherPreferenceMock());

      // Assert
      expect(deps.settingsController.openCount).assertEqual(1);
      expect(vm.updateCalled).assertTrue();
      expect(vm.refreshPlanningCount).assertEqual(1);
      expect(vm.refreshExecutionCount).assertEqual(1);
      expect(errorCount).assertEqual(0);
      done();
    });

    it('boundary: open_settings_dialog_should_skip_execution_refresh_when_stage_disabled', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMock();
      vm.executionWeatherStage = false;
      const deps = new SettingsFlowDepsMock();

      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new UiContextMock() as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {},
        onReschedule: (_dateMs: number) => {},
        onShare: async () => {},
        onWeatherPreferenceError: () => {}
      }, deps);
      await (deps.settingsCallbacks as SettingsCallbacks).onWeatherPreferenceChange(new WeatherPreferenceMock());

      // Assert
      expect(vm.refreshPlanningCount).assertEqual(1);
      expect(vm.refreshExecutionCount).assertEqual(0);
      done();
    });

    it('invalid: open_settings_dialog_should_call_error_callback_when_update_fails', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMock();
      vm.shouldThrowUpdate = true;
      const deps = new SettingsFlowDepsMock();
      let errorCount = 0;

      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new UiContextMock() as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {},
        onReschedule: (_dateMs: number) => {},
        onShare: async () => {},
        onWeatherPreferenceError: () => {
          errorCount += 1;
        }
      }, deps);
      await (deps.settingsCallbacks as SettingsCallbacks).onWeatherPreferenceChange(new WeatherPreferenceMock());

      // Assert
      expect(errorCount).assertEqual(1);
      expect(vm.refreshPlanningCount).assertEqual(0);
      expect(vm.refreshExecutionCount).assertEqual(0);
      done();
    });

    it('conflict: open_settings_dialog_should_route_reschedule_result_to_callback', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMock();
      const deps = new SettingsFlowDepsMock();
      let receivedDateMs = -1;

      // Act
      IndexSettingsFlowHelper.openSettingsDialog({
        uiContext: new UiContextMock() as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onRename: () => {},
        onReschedule: (dateMs: number) => {
          receivedDateMs = dateMs;
        },
        onShare: async () => {},
        onWeatherPreferenceError: () => {}
      }, deps);
      (deps.settingsCallbacks as SettingsCallbacks).onReschedule();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });

      // Assert
      expect(receivedDateMs).assertEqual(deps.pickerDateMs);
      done();
    });

    it('regression: open_rename_dialog_should_open_and_forward_name', 0, () => {
      // Arrange
      const deps = new SettingsFlowDepsMock();
      let receivedName = '';

      // Act
      IndexSettingsFlowHelper.openRenameDialog('origin_name', (newName: string) => {
        receivedName = newName;
      }, deps);
      (deps.renameConfirm as (newName: string) => void)('renamed');

      // Assert
      expect(deps.renameController.openCount).assertEqual(1);
      expect(deps.renameInitName).assertEqual('origin_name');
      expect(receivedName).assertEqual('renamed');
    });

    it('combined: open_share_dialog_should_build_payload_and_open_share_controller', 0, async (done: Function) => {
      // Arrange
      const deps = new SettingsFlowDepsMock();
      const events: EventEntity[] = [
        buildShareEvent(1, 1, 0, 1),
        buildShareEvent(2, 1, 1, 3),
        buildShareEvent(3, 0, 2, 7)
      ];
      const planStartDate = new Date(2026, 3, 5, 8, 0, 0, 0).getTime();

      // Act
      const controller = await IndexSettingsFlowHelper.openShareDialog({
        planId: 66,
        planTitle: 'share_title',
        planStartDate: planStartDate,
        events: events
      }, deps);

      // Assert
      expect((controller as Object) !== null).assertTrue();
      expect(deps.shareController.openCount).assertEqual(1);
      expect((deps.shareCallbacks as ShareDialogCallbacks).planId).assertEqual(66);
      expect((deps.shareCallbacks as ShareDialogCallbacks).totalEvents).assertEqual(2);
      expect((deps.shareCallbacks as ShareDialogCallbacks).totalDays).assertEqual(4);
      expect((deps.shareCallbacks as ShareDialogCallbacks).startDate).assertEqual(planStartDate);
      expect((deps.shareCallbacks as ShareDialogCallbacks).endDate).assertEqual(
        TimelineDatePolicy.dayOffsetToDayStartMs(planStartDate, 3)
      );
      expect((deps.shareCallbacks as ShareDialogCallbacks).compressedJson).assertEqual('{"ok":true}');
      done();
    });

    it('combined: default_flow_deps_should_delegate_to_dialog_manager_and_export_service', 0, async (done: Function) => {
      // Arrange
      const vm = new SettingsFlowVmMock();
      const uiContext = new UiContextMock() as Object as UIContext;
      const controller = new DialogControllerMock();
      const renameController = new DialogControllerMock();
      const shareController = new DialogControllerMock();
      const events: EventEntity[] = [
        buildShareEvent(1, 1, 0, 0),
        buildShareEvent(2, 1, 0, 1)
      ];
      const originalCreateSettings = Reflect.get(IndexDialogManager as Object, 'createSettingsController') as Object;
      const originalOpenPlanDatePicker = Reflect.get(IndexDialogManager as Object, 'openPlanDatePicker') as Object;
      const originalCreateRename = Reflect.get(IndexDialogManager as Object, 'createRenameController') as Object;
      const originalCreateShare = Reflect.get(IndexDialogManager as Object, 'createShareController') as Object;
      const originalExport = Reflect.get(PlanImportExportService as Object, 'exportPlanToJson') as Object;
      let renameHit = '';
      let rescheduleHit = -1;
      let settingsCallbacks: SettingsCallbacks = {
        onRename: () => {},
        onReschedule: () => {},
        onShare: () => {},
        weatherUserPreference: new WeatherPreferenceMock(),
        onWeatherPreferenceChange: async (_preference: WeatherUserPreference): Promise<void> => {}
      };
      let shareCallbacks: ShareDialogCallbacks = {
        planId: 0,
        planTitle: '',
        startDate: 0,
        endDate: 0,
        totalDays: 0,
        totalEvents: 0,
        compressedJson: ''
      };

      Reflect.set(IndexDialogManager as Object, 'createSettingsController', (callbacks: SettingsCallbacks): Object => {
        settingsCallbacks = callbacks;
        return controller as Object;
      });
      Reflect.set(
        IndexDialogManager as Object,
        'openPlanDatePicker',
        (_ctx: UIContext, _planStartDate: number, onAccept: (dateMs: number) => void): void => {
          onAccept(24680);
        }
      );
      Reflect.set(
        IndexDialogManager as Object,
        'createRenameController',
        (_initName: string, onConfirm: (newName: string) => void): Object => {
          onConfirm('renamed_default');
          return renameController as Object;
        }
      );
      Reflect.set(IndexDialogManager as Object, 'createShareController', (callbacks: ShareDialogCallbacks): Object => {
        shareCallbacks = callbacks;
        return shareController as Object;
      });
      Reflect.set(
        PlanImportExportService as Object,
        'exportPlanToJson',
        async (_planId: number): Promise<string> => '{"delegated":true}'
      );

      try {
        // Act
        IndexSettingsFlowHelper.openSettingsDialog({
          uiContext: uiContext,
          vm: vm as Object as TimelineViewModel,
          onRename: () => {},
          onReschedule: (dateMs: number) => {
            rescheduleHit = dateMs;
          },
          onShare: async () => {},
          onWeatherPreferenceError: () => {}
        });
        settingsCallbacks.onReschedule();
        await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
          setTimeout(() => resolve(), 130);
        });
        IndexSettingsFlowHelper.openRenameDialog('origin_default', (newName: string) => {
          renameHit = newName;
        });
        const shareDialog = await IndexSettingsFlowHelper.openShareDialog({
          planId: 77,
          planTitle: 'default_share',
          planStartDate: vm.planStartDate,
          events: events
        });

        // Assert
        expect(controller.openCount).assertEqual(1);
        expect(renameController.openCount).assertEqual(1);
        expect((shareDialog as Object) !== null).assertTrue();
        expect(shareController.openCount).assertEqual(1);
        expect(renameHit).assertEqual('renamed_default');
        expect(rescheduleHit).assertEqual(24680);
        expect(shareCallbacks.compressedJson).assertEqual('{"delegated":true}');
        done();
      } finally {
        Reflect.set(IndexDialogManager as Object, 'createSettingsController', originalCreateSettings);
        Reflect.set(IndexDialogManager as Object, 'openPlanDatePicker', originalOpenPlanDatePicker);
        Reflect.set(IndexDialogManager as Object, 'createRenameController', originalCreateRename);
        Reflect.set(IndexDialogManager as Object, 'createShareController', originalCreateShare);
        Reflect.set(PlanImportExportService as Object, 'exportPlanToJson', originalExport);
      }
    });
  });
}
