import { describe, it, expect } from '@ohos/hypium';
import { ArrivalReminderEngine } from '../../../main/ets/common/utils/ArrivalReminderEngine';

export default function arrivalReminderFlowIntegrationTest() {
  describe('ArrivalReminderFlowIntegrationTest', () => {
    it('location_sample_should_be_filtered_for_low_quality_or_high_speed', 0, () => {
      const poorAccuracy = ArrivalReminderEngine.isLocationSampleAccepted(31.23, 121.47, 800, 1, 400, 20);
      const highSpeed = ArrivalReminderEngine.isLocationSampleAccepted(31.23, 121.47, 20, 35, 400, 20);
      expect(poorAccuracy).assertEqual(false);
      expect(highSpeed).assertEqual(false);
    });

    it('location_sample_should_pass_for_valid_case', 0, () => {
      const accepted = ArrivalReminderEngine.isLocationSampleAccepted(31.23, 121.47, 30, 2, 400, 20);
      expect(accepted).assertEqual(true);
    });

    it('cooldown_rule_should_prevent_duplicate_trigger', 0, () => {
      const now = 1_000_000;
      const blocked = ArrivalReminderEngine.isEventOutOfCooldown(999_700, now, 500);
      const passed = ArrivalReminderEngine.isEventOutOfCooldown(999_000, now, 500);
      expect(blocked).assertEqual(false);
      expect(passed).assertEqual(true);
    });

    it('candidate_time_delta_should_prefer_cached_value', 0, () => {
      const now = 1_000_000;
      const fromCache = ArrivalReminderEngine.resolveCandidateTimeDelta(120_000, 0, now);
      const fromDynamic = ArrivalReminderEngine.resolveCandidateTimeDelta(undefined, 900_000, now);
      const fallback = ArrivalReminderEngine.resolveCandidateTimeDelta(undefined, 0, now);
      expect(fromCache).assertEqual(120_000);
      expect(fromDynamic).assertEqual(100_000);
      expect(fallback).assertEqual(Number.MAX_SAFE_INTEGER);
    });
  });
}
