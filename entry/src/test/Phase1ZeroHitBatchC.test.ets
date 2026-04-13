import { describe, expect, it } from '@ohos/hypium';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';

function buildPayload(planId: number, eventId: number, seq: number): ArrivalReminderPayload {
  return {
    seq: seq,
    planId: planId,
    eventId: eventId,
    placeName: `place-${eventId}`,
    distanceMeters: 120,
    triggerAt: 1713000000000 + seq
  };
}

export default function phase1ZeroHitBatchCTest() {
  describe('phase1ZeroHitBatchCTest', () => {
    it('normal: arrival_store_should_write_and_read_payload', 0, () => {
      // Arrange
      ArrivalReminderStore.ensureDefaults();
      const payload = buildPayload(11, 101, 3);
      // Act
      ArrivalReminderStore.writePayload(payload);
      const readBack = ArrivalReminderStore.readPayload(11);
      // Assert
      expect(readBack !== null).assertTrue();
      expect(readBack!.eventId).assertEqual(101);
      expect(readBack!.seq).assertEqual(3);
    });

    it('boundary: arrival_store_next_seq_should_start_from_one_after_defaults', 0, () => {
      // Arrange
      ArrivalReminderStore.ensureDefaults();
      AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_SEQ_KEY, 0);
      // Act
      const next = ArrivalReminderStore.nextSeq();
      // Assert
      expect(next).assertEqual(1);
    });

    it('invalid: arrival_store_should_return_null_and_clear_when_payload_is_invalid_json', 0, () => {
      // Arrange
      ArrivalReminderStore.ensureDefaults();
      AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY, '{invalid-json');
      // Act
      const parsed = ArrivalReminderStore.readPayload();
      const afterClear = AppStorage.get<string>(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY) ?? 'x';
      // Assert
      expect(parsed === null).assertTrue();
      expect(afterClear).assertEqual('');
    });

    it('conflict: clear_payload_if_event_matches_should_only_clear_target_event', 0, () => {
      // Arrange
      const payload = buildPayload(12, 202, 9);
      ArrivalReminderStore.writePayload(payload);
      // Act
      ArrivalReminderStore.clearPayloadIfEventMatches(999);
      const stillThere = ArrivalReminderStore.readPayload(12);
      ArrivalReminderStore.clearPayloadIfEventMatches(202);
      const cleared = ArrivalReminderStore.readPayload(12);
      // Assert
      expect(stillThere !== null).assertTrue();
      expect(cleared === null).assertTrue();
    });

    it('regression: td-20260412-batchc-scoped_payload_should_be_preferred_for_plan', 0, () => {
      // Arrange
      const payloadPlan = buildPayload(33, 303, 7);
      const payloadGlobal = buildPayload(44, 404, 8);
      ArrivalReminderStore.writePayload(payloadPlan);
      AppStorage.setOrCreate(ArrivalReminderStore.ARRIVAL_REMINDER_PAYLOAD_KEY, JSON.stringify(payloadGlobal));
      // Act
      const scoped = ArrivalReminderStore.readPayload(33);
      // Assert
      expect(scoped !== null).assertTrue();
      expect(scoped!.planId).assertEqual(33);
      expect(scoped!.eventId).assertEqual(303);
    });

    it('combined: arrival_store_should_manage_global_and_scoped_payload_lifecycle', 0, () => {
      // Arrange
      const payload = buildPayload(55, 505, 13);
      // Act
      ArrivalReminderStore.writePayload(payload);
      const seqAfterWrite = AppStorage.get<number>(ArrivalReminderStore.ARRIVAL_REMINDER_SEQ_KEY) ?? 0;
      const scopedKey = ArrivalReminderStore.buildScopedPayloadKey(55);
      const scopedRaw = AppStorage.get<string>(scopedKey) ?? '';
      ArrivalReminderStore.clearPayload(55);
      const scopedCleared = AppStorage.get<string>(scopedKey) ?? 'x';
      // Assert
      expect(seqAfterWrite).assertEqual(13);
      expect(scopedRaw.length > 0).assertTrue();
      expect(scopedCleared).assertEqual('');
    });
  });
}

