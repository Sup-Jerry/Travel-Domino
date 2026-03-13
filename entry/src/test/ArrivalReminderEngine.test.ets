import { describe, it, expect } from '@ohos/hypium';
import { ArrivalReminderEngine } from '../main/ets/common/utils/ArrivalReminderEngine';

export default function arrivalReminderEngineTest() {
  describe('arrivalReminderEngineTest', () => {
    it('location_filter_should_reject_low_quality_or_high_speed', 0, () => {
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

    it('location_filter_should_accept_normal_sample', 0, () => {
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

    it('cooldown_should_block_duplicate_trigger', 0, () => {
      const now = 1_000_000;
      const allowedEarly = ArrivalReminderEngine.isEventOutOfCooldown(999_500, now, 1000);
      const allowedLater = ArrivalReminderEngine.isEventOutOfCooldown(998_000, now, 1000);
      expect(allowedEarly).assertEqual(false);
      expect(allowedLater).assertEqual(true);
    });
  });
}
