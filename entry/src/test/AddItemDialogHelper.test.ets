import { describe, it, expect } from '@ohos/hypium';
import {
  isAddItemCoordinateValid,
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
  });
}
