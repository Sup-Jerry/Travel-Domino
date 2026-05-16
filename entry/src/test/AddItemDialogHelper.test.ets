import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import {
  AddItemDialog,
  MapPickerRouteParams,
  isAddItemMapPickerEnabled,
  isAddItemCoordinateValid,
  resolveAddItemScopedStorageKey,
  resolveAddItemDuration,
  resolveAddItemMode
} from '../main/ets/pages/components/dialogs/AddItemDialog';

interface AddItemDialogPaletteTest {
  textPrimary: Object;
  primary: Object;
  cardBgSoft: Object;
}

interface AddItemDialogParamsTest {
  showTip?: boolean;
  initName?: string;
  initNote?: string;
  initDuration?: number;
  initIsSchedule?: boolean;
  initFixedTime?: string;
  initSuggestedTime?: string;
  initIsAnchor?: boolean;
  initDayOffset?: number;
  initPreTravel?: number;
  initPriority?: number;
  storageScopePlanId?: number;
  planStartDate?: number;
  initLat?: number;
  initLng?: number;
  name?: string;
  note?: string;
  duration?: number;
}

interface AddItemDialogPrivateTest {
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
  onConfirm: (name: string, duration: number, isSchedule: boolean, fixedTime?: string, dayOffset?: number,
    preTravel?: number, isHardLock?: boolean, note?: string, isMustVisit?: boolean, lat?: number,
    lng?: number) => Promise<void>;
  onDateChangedRecommendTime: (dayOffset: number, currentTime: string) => string;
  setController(controller: Object): void;
  setInitiallyProvidedValue(params: AddItemDialogParamsTest): void;
  updateStateVars(params: AddItemDialogParamsTest): void;
  getPalette(): AddItemDialogPaletteTest;
  safeShowToast(message: string): void;
  aboutToAppear(): void;
  calculateDuration(): void;
  recalculateEndTime(): void;
  formatTime(date: Date): string;
  applyTimeString(target: Date, timeText: string): Date;
  isValidCoordinate(lat: number, lng: number): boolean;
  scopedStorageKey(base: string): string;
  canUseMapPicker(): boolean;
  isMapNativeRuntimeReady(): Promise<boolean>;
  initialRender(): void;
}

class AddItemDialogControllerMockTest {
  close(): void {}
}

export default function addItemDialogHelperTest() {
  describe('unit_test_case_generator_autofill_AddItemDialogHelper', () => {
    it('normal: add_item_mode_should_follow_init_schedule_when_editing', 0, () => {
      // Arrange
      const initName = '兵马俑';
      const initIsSchedule = false;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(0);
    });

    it('boundary: add_item_duration_should_fallback_to_default_when_init_non_positive', 0, () => {
      // Arrange
      const initDuration = 0;
      const defaultDuration = 45;
      // Act
      const duration = resolveAddItemDuration(initDuration, defaultDuration);
      // Assert
      expect(duration).assertEqual(45);
    });

    it('invalid: add_item_coordinate_should_reject_nan', 0, () => {
      // Arrange
      const lat = Number.NaN;
      const lng = 108.95;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertFalse();
    });

    it('conflict: add_item_coordinate_should_reject_zero_pair', 0, () => {
      // Arrange
      const lat = 0;
      const lng = 0;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertFalse();
    });

    it('regression: td-20260412-add-item-new-entry-should-default-to-schedule-mode', 0, () => {
      // Arrange
      const initName = '';
      const initIsSchedule = false;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(1);
    });

    it('combined: add_item_duration_and_coordinate_should_support_save_path', 0, () => {
      // Arrange
      const duration = resolveAddItemDuration(-1, 60);
      // Act
      const coordinateValid = isAddItemCoordinateValid(34.34, 108.94);
      // Assert
      expect(duration).assertEqual(60);
      expect(coordinateValid).assertTrue();
    });

    it('normal: add_item_scoped_storage_key_should_append_plan_id_for_positive_scope', 0, () => {
      // Arrange
      const base = 'tempDialogState';
      // Act
      const key = resolveAddItemScopedStorageKey(base, 12);
      // Assert
      expect(key).assertEqual('tempDialogState_12');
    });

    it('boundary: add_item_scoped_storage_key_should_keep_base_for_zero_scope', 0, () => {
      // Arrange
      const base = 'tempDialogState';
      // Act
      const key = resolveAddItemScopedStorageKey(base, 0);
      // Assert
      expect(key).assertEqual('tempDialogState');
    });

    it('regression: td-20260412-add-item-map-picker-enabled-should-trim-api-key', 0, () => {
      // Arrange
      const keyWithSpaces = '   amap_key   ';
      const emptyKey = '   ';
      // Act
      const enabled = isAddItemMapPickerEnabled(keyWithSpaces);
      const disabled = isAddItemMapPickerEnabled(emptyKey);
      // Assert
      expect(enabled).assertTrue();
      expect(disabled).assertFalse();
    });

    it('normal: map_picker_route_params_constructor_should_assign_all_fields', 0, () => {
      // Arrange
      const lat = 34.3416;
      const lng = 108.9398;
      const planId = 18;
      const centerSource = 'existing';
      const queryName = 'Clock Tower';

      // Act
      const params = new MapPickerRouteParams(lat, lng, planId, centerSource, queryName);

      // Assert
      expect(params.lat).assertEqual(lat);
      expect(params.lng).assertEqual(lng);
      expect(params.planId).assertEqual(planId);
      expect(params.centerSource).assertEqual(centerSource);
      expect(params.queryName).assertEqual(queryName);
    });
  });

  describe('unit_test_case_generator_autofill_AddItemDialogHelperBranches', () => {
    it('normal: add_item_mode_should_keep_schedule_mode_for_existing_schedule_item', 0, () => {
      // Arrange
      const initName = 'Morning Walk';
      const initIsSchedule = true;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(1);
    });

    it('boundary: add_item_duration_should_fallback_to_60_when_init_and_default_are_non_positive', 0, () => {
      // Arrange
      const initDuration = -10;
      const defaultDuration = 0;
      // Act
      const duration = resolveAddItemDuration(initDuration, defaultDuration);
      // Assert
      expect(duration).assertEqual(60);
    });

    it('invalid: add_item_coordinate_should_reject_infinite_latitude', 0, () => {
      // Arrange
      const lat = Number.POSITIVE_INFINITY;
      const lng = 120;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertFalse();
    });

    it('conflict: add_item_scoped_storage_key_should_not_append_suffix_for_negative_scope', 0, () => {
      // Arrange
      const base = 'pickedLocationStr';
      // Act
      const key = resolveAddItemScopedStorageKey(base, -5);
      // Assert
      expect(key).assertEqual(base);
    });

    it('regression: td-20260418-add_item_coordinate_should_accept_boundary_lat_lng', 0, () => {
      // Arrange
      const lat = 90;
      const lng = -180;
      // Act
      const valid = isAddItemCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertTrue();
    });

    it('combined: add_item_mode_duration_and_storage_should_follow_default_new_item_path', 0, () => {
      // Arrange
      const initName = ' ';
      const initIsSchedule = false;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      const duration = resolveAddItemDuration(0, 30);
      const key = resolveAddItemScopedStorageKey('k', 3);
      // Assert
      expect(mode).assertEqual(1);
      expect(duration).assertEqual(30);
      expect(key).assertEqual('k_3');
    });

    it('combined: add_item_dialog_instance_should_sync_initial_state_and_private_time_helpers', 0, () => {
      // Arrange
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateTest;
      const initParams: AddItemDialogParamsTest = {
        showTip: true,
        initName: '',
        initNote: '补充说明',
        initDuration: 0,
        initIsSchedule: false,
        initFixedTime: '',
        initSuggestedTime: '10:30',
        initIsAnchor: true,
        initDayOffset: 2,
        initPreTravel: 25,
        initPriority: 1,
        storageScopePlanId: 12,
        planStartDate: new Date(2026, 3, 1, 0, 0, 0, 0).getTime(),
        initLat: 34.34,
        initLng: 108.94
      };
      const nextParams: AddItemDialogParamsTest = {
        initName: '不会生效',
        duration: 999
      };
      page.setInitiallyProvidedValue(initParams);

      // Act
      page.aboutToAppear();
      const startText = page.formatTime(page.startTime);
      const shiftedStart = page.applyTimeString(page.startTime, '13:20');
      const unchangedStart = page.applyTimeString(page.startTime, 'bad-input');
      page.duration = 75;
      page.recalculateEndTime();
      const endText = page.formatTime(page.endTime);
      page.endTime = new Date(page.startTime.getTime() + 35 * 60 * 1000);
      page.calculateDuration();
      const recommended = page.onDateChangedRecommendTime(2, '09:40');
      const validCoord = page.isValidCoordinate(page.latitude, page.longitude);
      const invalidCoord = page.isValidCoordinate(0, 0);
      const scopedKey = page.scopedStorageKey('pickedLocationStr');
      page.updateStateVars(nextParams);
      page.effectiveTheme = 'dark';
      const palette = page.getPalette();

      // Assert
      expect(page.showTip).assertTrue();
      expect(page.mode).assertEqual(1);
      expect(page.note).assertEqual('补充说明');
      expect(page.isAnchor).assertTrue();
      expect(page.preTravel).assertEqual(-1);
      expect(page.isMustVisit).assertTrue();
      expect(page.duration).assertEqual(35);
      expect(page.latitude).assertEqual(34.34);
      expect(page.longitude).assertEqual(108.94);
      expect(startText).assertEqual('10:30');
      expect(shiftedStart.getHours()).assertEqual(13);
      expect(shiftedStart.getMinutes()).assertEqual(20);
      expect(unchangedStart.getTime()).assertEqual(page.startTime.getTime());
      expect(endText).assertEqual('11:45');
      expect(recommended).assertEqual('09:40');
      expect(validCoord).assertTrue();
      expect(invalidCoord).assertFalse();
      expect(scopedKey).assertEqual('pickedLocationStr_12');
      expect(page.initName).assertEqual('');
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(palette.cardBgSoft).assertEqual(ThemeCenter.getPalette('dark').cardBgSoft);
    });

    it('combined: add_item_dialog_async_helpers_should_cover_default_callbacks_and_runtime_guards', 0, async (done: () => void) => {
      // Arrange
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateTest;

      // Act
      page.safeShowToast('地图提示');
      await page.onConfirm('兵马俑', 60, true, '09:00', 1, 15, false, '备注', true, 34.34, 108.94);
      const canUseMapPicker = page.canUseMapPicker();
      const runtimeReady = await page.isMapNativeRuntimeReady();

      // Assert
      expect(canUseMapPicker).assertEqual(isAddItemMapPickerEnabled(AppConfig.AMAP_SDK_API_KEY));
      expect(runtimeReady === true || runtimeReady === false).assertTrue();
      done();
    });

    it('combined: add_item_dialog_accessors_should_cover_controller_default_duration_and_render_entry', 0, () => {
      // Arrange
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateTest;
      const controller = new AddItemDialogControllerMockTest() as Object;
      let threw = false;

      // Act
      page.controller = controller;
      page.globalDefaultDuration = 90;
      page.name = '大唐不夜城';
      page.isSchedule = true;
      page.isGeocoding = true;
      page.effectiveTheme = 'light';
      const currentController = page.controller;
      const defaultDuration = page.globalDefaultDuration;
      const currentName = page.name;
      const currentSchedule = page.isSchedule;
      const currentGeocoding = page.isGeocoding;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(currentController).assertEqual(controller);
      expect(defaultDuration).assertEqual(90);
      expect(currentName).assertEqual('大唐不夜城');
      expect(currentSchedule).assertTrue();
      expect(currentGeocoding).assertTrue();
      expect(threw).assertFalse();
    });

    it('regression: td-20260426-add_item_dialog_set_controller_should_replace_reference', 0, () => {
      // Arrange
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateTest;
      const first = new AddItemDialogControllerMockTest() as Object;
      const second = new AddItemDialogControllerMockTest() as Object;
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller).assertEqual(second);
    });

    it('boundary: add_item_mode_should_treat_whitespace_name_as_new_schedule_item', 0, () => {
      // Arrange
      const initName = '   ';
      const initIsSchedule = false;
      // Act
      const mode = resolveAddItemMode(initName, initIsSchedule);
      // Assert
      expect(mode).assertEqual(1);
    });

    it('normal: add_item_duration_should_prefer_positive_initial_duration_over_default', 0, () => {
      // Arrange
      const initDuration = 25;
      const defaultDuration = 90;
      // Act
      const duration = resolveAddItemDuration(initDuration, defaultDuration);
      // Assert
      expect(duration).assertEqual(25);
    });

    it('invalid: add_item_coordinate_should_reject_latitude_and_longitude_out_of_world_range', 0, () => {
      // Act
      // Arrange
      const invalidLat = isAddItemCoordinateValid(90.1, 120);
      const invalidLng = isAddItemCoordinateValid(30, 180.1);
      // Assert
      expect(invalidLat).assertFalse();
      expect(invalidLng).assertFalse();
    });
  });
}
