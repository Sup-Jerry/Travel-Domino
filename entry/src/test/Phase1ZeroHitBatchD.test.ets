import { describe, expect, it } from '@ohos/hypium';
import { ArrivalLiveActivityBridge } from '../main/ets/common/utils/ArrivalLiveActivityBridge';
import { NotificationGateway } from '../main/ets/infrastructure/adapters/NotificationGateway';
import { QRCodeService } from '../main/ets/domain/services/QRCodeService';

const LIVE_SEQ_KEY = 'ArrivalLiveActivitySeq';
const LIVE_PAYLOAD_KEY = 'ArrivalLiveActivityPayload';

interface LivePayloadSnapshot {
  seq: number;
  planId: number;
  eventId: number;
  placeName: string;
  status: string;
  updatedAt: number;
}

function readLivePayload(): LivePayloadSnapshot | null {
  const raw = AppStorage.get<string>(LIVE_PAYLOAD_KEY) ?? '';
  if (!raw || raw.length <= 0) {
    return null;
  }
  return JSON.parse(raw) as LivePayloadSnapshot;
}

async function expectReject(action: () => Promise<Object>, message: string): Promise<void> {
  let actual = '';
  try {
    await action();
  } catch (error) {
    actual = (error as Error).message;
  }
  expect(actual).assertEqual(message);
}

export default function phase1ZeroHitBatchDTest() {
  describe('phase1ZeroHitBatchDTest', () => {
    it('normal: live_bridge_start_should_write_reminding_payload', 0, async () => {
      // Arrange
      ArrivalLiveActivityBridge.init();
      // Act
      ArrivalLiveActivityBridge.start(1, 101, 'museum');
      const payload = readLivePayload();
      // Assert
      expect(payload !== null).assertTrue();
      expect(payload!.status).assertEqual('REMINDING');
      expect(payload!.eventId).assertEqual(101);
    });

    it('boundary: live_bridge_update_should_allow_empty_place_name', 0, async () => {
      // Arrange
      ArrivalLiveActivityBridge.init();
      // Act
      ArrivalLiveActivityBridge.update(2, 202, '', 'ACKED');
      const payload = readLivePayload();
      // Assert
      expect(payload !== null).assertTrue();
      expect(payload!.placeName).assertEqual('');
      expect(payload!.status).assertEqual('ACKED');
    });

    it('invalid: qrcode_service_should_reject_blank_content', 0, async () => {
      // Arrange
      const blank = '   ';
      // Act
      // Assert
      await expectReject(() => QRCodeService.generateQRCode(blank, 200), 'qr_content_empty');
    });

    it('conflict: notification_gateway_should_not_throw_when_forwarding_fails', 0, async () => {
      // Arrange
      let reached = false;
      // Act
      await NotificationGateway.updateScheduleNotification('t', 'c', 1, 2, true);
      reached = true;
      // Assert
      expect(reached).assertTrue();
    });

    it('regression: td-20260412-batchd-live_bridge_end_should_write_ended_status', 0, async () => {
      // Arrange
      ArrivalLiveActivityBridge.init();
      // Act
      ArrivalLiveActivityBridge.end(3, 303, 'hotel');
      const payload = readLivePayload();
      // Assert
      expect(payload !== null).assertTrue();
      expect(payload!.status).assertEqual('ENDED');
      expect(payload!.planId).assertEqual(3);
    });

    it('combined: live_bridge_sequence_should_increase_across_start_update_end', 0, async () => {
      // Arrange
      ArrivalLiveActivityBridge.init();
      // Act
      ArrivalLiveActivityBridge.start(4, 401, 'spot-a');
      const seqAfterStart = AppStorage.get<number>(LIVE_SEQ_KEY) ?? 0;
      ArrivalLiveActivityBridge.update(4, 401, 'spot-a', 'STARTED');
      const seqAfterUpdate = AppStorage.get<number>(LIVE_SEQ_KEY) ?? 0;
      ArrivalLiveActivityBridge.end(4, 401, 'spot-a');
      const seqAfterEnd = AppStorage.get<number>(LIVE_SEQ_KEY) ?? 0;
      const payload = readLivePayload();
      // Assert
      expect(seqAfterStart > 0).assertTrue();
      expect(seqAfterUpdate > seqAfterStart).assertTrue();
      expect(seqAfterEnd > seqAfterUpdate).assertTrue();
      expect(payload !== null).assertTrue();
      expect(payload!.status).assertEqual('ENDED');
    });
  });
}

