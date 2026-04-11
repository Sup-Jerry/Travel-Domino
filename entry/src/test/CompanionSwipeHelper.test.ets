import { describe, it, expect } from '@ohos/hypium';
import { getCompanionSwipeUpdate, shouldCompanionEnterControlMode } from '../main/ets/pages/components/views/companion/CompanionSwipeHelper';

export default function companionSwipeHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionSwipeHelper', () => {
    it('normal: swipe_update_should_apply_damping_and_peak_tracking', 0, () => {
      // Arrange
      const offsetY = -100;
      const currentPeak = 20;
      const nowTs = 2000;

      // Act
      const update = getCompanionSwipeUpdate(offsetY, currentPeak, nowTs);

      // Assert
      expect(update.peakDistance).assertEqual(100);
      expect(update.lastTs).assertEqual(nowTs);
      expect(update.dragOffsetY).assertEqual(-38);
    });

    it('boundary: swipe_update_should_clamp_drag_offset_to_minus_150', 0, () => {
      // Arrange
      const offsetY = -500;

      // Act
      const update = getCompanionSwipeUpdate(offsetY, 0, 3000);

      // Assert
      expect(update.dragOffsetY).assertEqual(-150);
      expect(update.peakDistance).assertEqual(500);
    });

    it('invalid: swipe_update_should_reset_drag_offset_when_offset_is_non_negative', 0, () => {
      // Arrange
      const offsetY = 24;
      const currentPeak = 80;

      // Act
      const update = getCompanionSwipeUpdate(offsetY, currentPeak, 4000);

      // Assert
      expect(update.dragOffsetY).assertEqual(0);
      expect(update.peakDistance).assertEqual(currentPeak);
    });

    it('conflict: enter_control_mode_should_use_max_of_peak_and_current_drag_distance', 0, () => {
      // Arrange
      const peakDistance = 40;
      const offsetY = -130;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1200,
        120,
        99
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('regression: enter_control_mode_should_still_trigger_by_velocity_with_short_duration', 0, () => {
      // Arrange
      const peakDistance = 20;
      const offsetY = -20;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1010,
        100,
        1.5
      );

      // Assert
      expect(shouldEnter).assertTrue();
    });

    it('combined: enter_control_mode_should_remain_false_when_distance_and_velocity_below_thresholds', 0, () => {
      // Arrange
      const peakDistance = 30;
      const offsetY = -20;

      // Act
      const shouldEnter = shouldCompanionEnterControlMode(
        peakDistance,
        offsetY,
        1000,
        1200,
        100,
        1
      );

      // Assert
      expect(shouldEnter).assertFalse();
    });
  });
}
