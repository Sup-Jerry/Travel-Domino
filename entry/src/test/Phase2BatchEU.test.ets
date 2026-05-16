import { describe, expect, it } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  AddItemDialog,
  isAddItemCoordinateValid,
  resolveAddItemDuration,
  resolveAddItemMode,
  resolveAddItemScopedStorageKey
} from '../main/ets/pages/components/dialogs/AddItemDialog';

interface AddItemDialogPaletteEU {
  textPrimary: Object;
  primary: Object;
  cardBgSoft: Object;
}

interface AddItemDialogPrivateEU {
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
  aboutToAppear(): void;
  calculateDuration(): void;
  recalculateEndTime(): void;
  formatTime(date: Date): string;
  applyTimeString(target: Date, timeText: string): Date;
  isValidCoordinate(lat: number, lng: number): boolean;
  scopedStorageKey(base: string): string;
  getPalette(): AddItemDialogPaletteEU;
  initialRender(): void;
}

class AddDialogControllerMockEU {
  public closeCount: number = 0;

  close(): void {
    this.closeCount += 1;
  }
}

export default function phase2BatchEUTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEU_add_item_extra', () => {
    it('normal: add_item_about_to_appear_should_use_suggested_time_and_new_item_pretravel', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateEU;

      page.globalDefaultDuration = 50;
      page.initName = '';
      page.initNote = 'note-eu';
      page.initDuration = 0;
      page.initIsSchedule = false;
      page.initFixedTime = '';
      page.initSuggestedTime = '14:35';
      page.initIsAnchor = false;
      page.initDayOffset = 2;
      page.initPreTravel = 25;
      page.initPriority = 0;
      page.planStartDate = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
      page.initLat = 30.2;
      page.initLng = 120.1;

      page.aboutToAppear();

      expect(page.mode).assertEqual(1);
      expect(page.duration).assertEqual(50);
      expect(page.preTravel).assertEqual(-1);
      expect(page.note).assertEqual('note-eu');
      expect(page.formatTime(page.startTime)).assertEqual('14:35');
      expect(page.formatTime(page.endTime)).assertEqual('15:25');
    });

    it('boundary: add_item_time_helpers_should_keep_duration_when_end_not_after_start', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateEU;

      page.duration = 70;
      page.startTime = new Date(2026, 3, 10, 11, 0, 0, 0);
      page.endTime = new Date(2026, 3, 10, 11, 0, 0, 0);
      page.calculateDuration();
      page.recalculateEndTime();

      expect(page.duration).assertEqual(70);
      expect(page.formatTime(page.endTime)).assertEqual('12:10');
    });

    it('invalid: add_item_apply_time_string_should_ignore_invalid_extracted_parts', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateEU;
      const target = new Date(2026, 3, 10, 9, 5, 0, 0);

      const invalidHour = page.applyTimeString(target, 'aa:20');
      const invalidMinute = page.applyTimeString(target, '09:bb');
      const validWrapped = page.applyTimeString(target, 'memo 18:45');

      expect(invalidHour.getTime()).assertEqual(target.getTime());
      expect(invalidMinute.getTime()).assertEqual(target.getTime());
      expect(page.formatTime(validWrapped)).assertEqual('18:45');
    });

    it('conflict: add_item_coordinate_storage_and_mode_helpers_should_keep_rules_independent', 0, () => {
      // Arrange
      // Act
      // Assert
      const mode = resolveAddItemMode('spot', false);
      const duration = resolveAddItemDuration(0, 35);
      const key = resolveAddItemScopedStorageKey('pickedLocationStr', -2);
      const validCoord = isAddItemCoordinateValid(-90, 180);
      const invalidCoord = isAddItemCoordinateValid(91, 0);

      expect(mode).assertEqual(0);
      expect(duration).assertEqual(35);
      expect(key).assertEqual('pickedLocationStr');
      expect(validCoord).assertTrue();
      expect(invalidCoord).assertFalse();
    });

    it('regression: add_item_palette_and_private_accessors_should_follow_dark_theme_and_scope', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateEU;

      page.effectiveTheme = 'dark';
      page.storageScopePlanId = 88;
      const palette = page.getPalette();
      const scopedKey = page.scopedStorageKey('tempDialogState');
      const validCoord = page.isValidCoordinate(45.5, 73.6);
      const invalidCoord = page.isValidCoordinate(0, 0);

      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(palette.cardBgSoft).assertEqual(ThemeCenter.getPalette('dark').cardBgSoft);
      expect(scopedKey).assertEqual('tempDialogState_88');
      expect(validCoord).assertTrue();
      expect(invalidCoord).assertFalse();
    });

    it('combined: add_item_initial_render_should_support_edit_backlog_branch_with_max_name_length', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateEU;
      let threw = false;

      page.controller = new AddDialogControllerMockEU() as Object;
      page.initName = 'existing backlog item';
      page.initNote = 'n';
      page.initDuration = 30;
      page.initIsSchedule = false;
      page.initFixedTime = '';
      page.initSuggestedTime = '08:10';
      page.initIsAnchor = false;
      page.initDayOffset = 0;
      page.initPreTravel = 0;
      page.initPriority = 0;
      page.storageScopePlanId = 2;
      page.planStartDate = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
      page.initLat = 0;
      page.initLng = 0;
      page.name = '123456789012345678901234567890';
      page.note = 'branch';
      page.duration = 30;
      page.isSchedule = false;
      page.isAnchor = false;
      page.preTravel = 0;
      page.startTime = new Date(2026, 3, 10, 8, 10, 0, 0);
      page.endTime = new Date(2026, 3, 10, 8, 40, 0, 0);
      page.isMustVisit = false;
      page.latitude = 0;
      page.longitude = 0;
      page.isGeocoding = false;
      page.mode = 0;
      page.effectiveTheme = 'light';

      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      expect(threw).assertFalse();
    });

    it('combined: add_item_initial_render_should_support_schedule_branch_with_geocoding_idle_state', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateEU;
      let threw = false;

      page.controller = new AddDialogControllerMockEU() as Object;
      page.globalDefaultDuration = 60;
      page.initName = 'gallery';
      page.initNote = 'exhibit';
      page.initDuration = 60;
      page.initIsSchedule = true;
      page.initFixedTime = '16:20';
      page.initSuggestedTime = '';
      page.initIsAnchor = true;
      page.initDayOffset = 1;
      page.initPreTravel = 10;
      page.initPriority = 1;
      page.storageScopePlanId = 5;
      page.planStartDate = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
      page.initLat = 31.2;
      page.initLng = 121.5;
      page.aboutToAppear();
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
      expect(page.latitude).assertEqual(31.2);
      expect(page.longitude).assertEqual(121.5);
      expect(threw).assertFalse();
    });
  });
}
