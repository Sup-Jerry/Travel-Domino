import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionSwipeUpdate,
  shouldCompanionEnterControlMode
} from '../main/ets/pages/components/views/companion/CompanionSwipeHelper';

export default function companionSwipeHelperVelocityTest() {
  describe('unit_test_case_generator_autofill_CompanionSwipeHelperVelocity', () => {
    it('normal: enter_control_mode_should_trigger_by_distance_even_with_non_negative_offset', 0, () => {
      // Arrange
      const peakDistance = 150;
      const offsetY = 10;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1300,
        120,
        999
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('boundary: enter_control_mode_should_use_minimum_duration_one_when_timestamp_is_reversed', 0, () => {
      // Arrange
      const peakDistance = 0;
      const offsetY = -50;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        2000,
        1990,
        100,
        40
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('invalid: enter_control_mode_should_remain_false_when_no_upward_drag_and_no_peak_distance', 0, () => {
      // Arrange
      const peakDistance = 0;
      const offsetY = 20;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1200,
        10,
        10
      );

      // Assert
      expect(shouldEnter).assertFalse();
    });

    it('conflict: enter_control_mode_should_take_current_upward_drag_when_it_exceeds_peak', 0, () => {
      // Arrange
      const peakDistance = 20;
      const offsetY = -80;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1200,
        90,
        0.3
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('regression: enter_control_mode_should_use_peak_distance_even_when_current_offset_turns_positive', 0, () => {
      // Arrange
      const peakDistance = 80;
      const offsetY = 20;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        2000,
        75,
        999
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('combined: swipe_update_and_enter_control_mode_should_keep_clamp_and_threshold_consistent', 0, () => {
      // Arrange
      const update = getCompanionSwipeUpdate(-500, 30, 5000);

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        update.peakDistance,
        update.dragOffsetY,
        4900,
        5000,
        520,
        6
      );

      // Assert
      expect(update.dragOffsetY).assertEqual(-150);
      expect(update.peakDistance).assertEqual(500);
      expect(shouldEnter).assertFalse();
    });
  });
}
