import { describe, expect, it } from '@ohos/hypium';
import { MapsInitializer } from '@amap/amap_lbs_map3d';
import {
  AddItemDialog,
  isAddItemMapPickerEnabled
} from '../main/ets/pages/components/dialogs/AddItemDialog';

interface AddItemDialogPrivateET {
  controller: Object;
  initName: string;
  initNote: string;
  initDuration: number;
  initIsSchedule: boolean;
  initFixedTime: string;
  initSuggestedTime: string;
  initIsAnchor: boolean;
  initDayOffset: number;
  initPreTravel: number;
  initPriority: number;
  storageScopePlanId: number;
  planStartDate: number;
  initLat: number;
  initLng: number;
  globalDefaultDuration: number;
  showTip: boolean;
  name: string;
  note: string;
  duration: number;
  isSchedule: boolean;
  isAnchor: boolean;
  preTravel: number;
  startTime: Date;
  endTime: Date;
  isMustVisit: boolean;
  latitude: number;
  longitude: number;
  isGeocoding: boolean;
  mode: number;
  effectiveTheme: string;
  safeShowToast(message: string): void;
  aboutToAppear(): void;
  isMapNativeRuntimeReady(): Promise<boolean>;
  initialRender(): void;
}

class AddDialogControllerMockET {
  public closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

class MapsInitializerHooksET {
  private readonly originGetVersion: Object;

  constructor() {
    this.originGetVersion = Reflect.get(MapsInitializer as Object, 'getVersion') as Object;
  }

  setGetVersion(fn: () => string): void {
    Reflect.set(MapsInitializer as Object, 'getVersion', fn);
  }

  restore(): void {
    Reflect.set(MapsInitializer as Object, 'getVersion', this.originGetVersion);
  }
}

export default function phase2BatchETTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchET_add_item_runtime', () => {
    it('normal: add_item_native_runtime_should_report_ready_when_sdk_version_exists', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const hooks = new MapsInitializerHooksET();
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateET;
      hooks.setGetVersion((): string => '9.8.7');

      const ready = await page.isMapNativeRuntimeReady();

      expect(ready).assertTrue();
      hooks.restore();
      done();
    });

    it('boundary: add_item_native_runtime_should_report_not_ready_when_sdk_version_blank', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const hooks = new MapsInitializerHooksET();
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateET;
      hooks.setGetVersion((): string => '   ');

      const ready = await page.isMapNativeRuntimeReady();

      expect(ready).assertFalse();
      hooks.restore();
      done();
    });

    it('invalid: add_item_native_runtime_should_report_not_ready_when_sdk_probe_throws', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const hooks = new MapsInitializerHooksET();
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateET;
      hooks.setGetVersion((): string => {
        throw new Error('sdk_probe_failed_et');
      });

      const ready = await page.isMapNativeRuntimeReady();

      expect(ready).assertFalse();
      hooks.restore();
      done();
    });

    it('conflict: add_item_toast_and_map_picker_guard_should_stay_independent', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateET;
      let threw = false;

      try {
        page.safeShowToast('toast_only_et');
      } catch (_error) {
        threw = true;
      }
      const enabled = isAddItemMapPickerEnabled('demo-key');
      const disabled = isAddItemMapPickerEnabled('   ');

      expect(threw).assertFalse();
      expect(enabled).assertTrue();
      expect(disabled).assertFalse();
    });

    it('combined: add_item_initial_render_should_support_new_backlog_loading_state', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateET;
      let threw = false;

      page.controller = new AddDialogControllerMockET() as Object;
      page.initName = '';
      page.initNote = '';
      page.initDuration = 0;
      page.initIsSchedule = false;
      page.initFixedTime = '';
      page.initSuggestedTime = '';
      page.initIsAnchor = false;
      page.initDayOffset = 0;
      page.initPreTravel = -1;
      page.initPriority = 0;
      page.storageScopePlanId = 0;
      page.planStartDate = new Date(2026, 3, 20, 0, 0, 0, 0).getTime();
      page.initLat = 0;
      page.initLng = 0;
      page.globalDefaultDuration = 90;
      page.name = 'coffee';
      page.note = 'quick stop';
      page.duration = 90;
      page.isSchedule = false;
      page.isAnchor = false;
      page.preTravel = -1;
      page.startTime = new Date(2026, 3, 20, 8, 0, 0, 0);
      page.endTime = new Date(2026, 3, 20, 9, 30, 0, 0);
      page.isMustVisit = true;
      page.latitude = 0;
      page.longitude = 0;
      page.isGeocoding = true;
      page.mode = 0;
      page.showTip = true;
      page.effectiveTheme = 'light';

      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      expect(threw).assertFalse();
    });

    it('regression: add_item_initial_render_should_support_edit_schedule_branch_with_anchor', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateET;
      let threw = false;

      page.controller = new AddDialogControllerMockET() as Object;
      page.globalDefaultDuration = 45;
      page.initName = 'museum';
      page.initNote = 'ticket booked';
      page.initDuration = 75;
      page.initIsSchedule = true;
      page.initFixedTime = '10:15';
      page.initSuggestedTime = '';
      page.initIsAnchor = true;
      page.initDayOffset = 1;
      page.initPreTravel = 20;
      page.initPriority = 1;
      page.storageScopePlanId = 7;
      page.planStartDate = new Date(2026, 3, 20, 0, 0, 0, 0).getTime();
      page.initLat = 39.91;
      page.initLng = 116.39;
      page.aboutToAppear();
      page.showTip = true;
      page.isGeocoding = false;
      page.mode = 1;
      page.effectiveTheme = 'dark';

      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      expect(page.isMustVisit).assertTrue();
      expect(page.isAnchor).assertTrue();
      expect(page.preTravel).assertEqual(20);
      expect(page.latitude).assertEqual(39.91);
      expect(page.longitude).assertEqual(116.39);
      expect(threw).assertFalse();
    });
  });
}
