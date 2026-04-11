import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionSwipeUpdate,
  shouldCompanionEnterControlMode
} from '../main/ets/pages/components/views/companion/CompanionSwipeHelper';

export default function companionSwipeHelperThresholdsTest() {
  describe('unit_test_case_generator_autofill_CompanionSwipeHelperThresholds', () => {
    it('normal: enter_control_mode_should_trigger_when_distance_equals_threshold', 0, () => {
      // Arrange
      const peakDistance = 120;
      const offsetY = -100;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1400,
        120,
        999
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('boundary: enter_control_mode_should_trigger_when_velocity_equals_threshold', 0, () => {
      // Arrange
      const peakDistance = 60;
      const offsetY = -60;
      const swipeStartTs = 1000;
      const nowTs = 1060;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        swipeStartTs,
        nowTs,
        999,
        1
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('invalid: swipe_update_should_keep_existing_peak_when_offset_is_zero', 0, () => {
      // Arrange
      const currentPeak = 88;

      // Act
      const update = getCompanionSwipeUpdate(0, currentPeak, 5000);

      // Assert
      expect(update.peakDistance).assertEqual(88);
      expect(update.dragOffsetY).assertEqual(0);
    });

    it('conflict: enter_control_mode_should_use_peak_when_current_offset_is_shallower', 0, () => {
      // Arrange
      const peakDistance = 140;
      const offsetY = -20;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1200,
        120,
        999
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('regression: update_then_enter_should_not_trigger_when_damped_offset_small_and_peak_below_distance', 0, () => {
      // Arrange
      const update = getCompanionSwipeUpdate(-80, 10, 3000);

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        update.peakDistance,
        update.dragOffsetY,
        2900,
        3000,
        120,
        2
      );

      // Assert
      expect(update.dragOffsetY).assertEqual(-30.4);
      expect(update.peakDistance).assertEqual(80);
      expect(shouldEnter).assertFalse();
    });

    it('combined: threshold_decision_should_change_when_only_velocity_threshold_is_relaxed', 0, () => {
      // Arrange
      const peakDistance = 70;
      const offsetY = -70;
      const swipeStartTs = 1000;
      const nowTs = 1100;

      // Act
      const strictDecision = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        swipeStartTs,
        nowTs,
        120,
        1
      );
      const relaxedDecision = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        swipeStartTs,
        nowTs,
        120,
        0.69
      );

      // Assert
      expect(strictDecision).assertFalse();
      expect(relaxedDecision).assertTrue();
    });
  });
}
