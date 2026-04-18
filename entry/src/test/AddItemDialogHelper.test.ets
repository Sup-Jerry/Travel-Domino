import { describe, it, expect } from '@ohos/hypium';
import {
  isAddItemMapPickerEnabled,
  isAddItemCoordinateValid,
  resolveAddItemScopedStorageKey,
  resolveAddItemDuration,
  resolveAddItemMode
} from '../main/ets/pages/components/dialogs/AddItemDialog';

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
  });
}
