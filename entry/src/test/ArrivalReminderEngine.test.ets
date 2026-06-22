import { describe, it, expect } from '@ohos/hypium';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';

export default function arrivalReminderEngineTest() {
  describe('arrivalReminderEngineTest', () => {
    it('invalid: location_filter_should_reject_low_quality_or_high_speed', 0, () => {
      // Arrange
      // Act
      // Assert
      const lowAccuracyAccepted = ArrivalReminderEngine.isLocationSampleAccepted(
        31.23,
        121.47,
        500,
        3,
        400,
        20
      );
      const highSpeedAccepted = ArrivalReminderEngine.isLocationSampleAccepted(
        31.23,
        121.47,
        20,
        30,
        400,
        20
      );
      expect(lowAccuracyAccepted).assertEqual(false);
      expect(highSpeedAccepted).assertEqual(false);
    });

    it('normal: location_filter_should_accept_normal_sample', 0, () => {
      // Arrange
      // Act
      // Assert
      const accepted = ArrivalReminderEngine.isLocationSampleAccepted(
        31.23,
        121.47,
        35,
        2,
        400,
        20
      );
      expect(accepted).assertEqual(true);
    });

    it('conflict: cooldown_should_block_duplicate_trigger', 0, () => {
      // Arrange
      // Act
      // Assert
      const now = 1_000_000;
      const allowedEarly = ArrivalReminderEngine.isEventOutOfCooldown(999_500, now, 1000);
      const allowedLater = ArrivalReminderEngine.isEventOutOfCooldown(998_000, now, 1000);
      expect(allowedEarly).assertEqual(false);
      expect(allowedLater).assertEqual(true);
    });
  });
  describe('unit_test_case_generator_autofill_ArrivalReminderEngine', () => {
    it('boundary: location_filter_should_accept_samples_at_accuracy_and_speed_limits', 0, () => {
      // Arrange
      const latitude = 31.23;
      const longitude = 121.47;

      // Act
      const accepted = ArrivalReminderEngine.isLocationSampleAccepted(
        latitude,
        longitude,
        400,
        20,
        400,
        20
      );

      // Assert
      expect(accepted).assertTrue();
    });

    it('regression: candidate_time_delta_should_prefer_non_negative_cached_value', 0, () => {
      // Arrange
      const now = 1_700_000_000_000;
      const dynamicStartTime = now + 5 * 60_000;

      // Act
      const cachedDelta = ArrivalReminderEngine.resolveCandidateTimeDelta(90_000, dynamicStartTime, now);
      const recalculatedDelta = ArrivalReminderEngine.resolveCandidateTimeDelta(-1, dynamicStartTime, now);
      const fallbackDelta = ArrivalReminderEngine.resolveCandidateTimeDelta(undefined, 0, now);

      // Assert
      expect(cachedDelta).assertEqual(90_000);
      expect(recalculatedDelta).assertEqual(300_000);
      expect(fallbackDelta).assertEqual(Number.MAX_SAFE_INTEGER);
    });

    it('combined: singleton_and_cooldown_checks_should_coordinate_with_live_time_delta_evaluation', 0, () => {
      // Arrange
      const now = 2_000_000;

      // Act
      const first = ArrivalReminderEngine.getInstance();
      const second = ArrivalReminderEngine.getInstance();
      const cooldownBlocked = ArrivalReminderEngine.isEventOutOfCooldown(now - 500, now, 1000);
      const cooldownReleased = ArrivalReminderEngine.isEventOutOfCooldown(now - 2000, now, 1000);
      const liveDelta = ArrivalReminderEngine.resolveCandidateTimeDelta(undefined, now + 60_000, now);

      // Assert
      expect(first === second).assertTrue();
      expect(cooldownBlocked).assertFalse();
      expect(cooldownReleased).assertTrue();
      expect(liveDelta).assertEqual(60_000);
    });
  });
}
