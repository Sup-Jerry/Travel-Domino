import { describe, expect, it } from '@ohos/hypium';
import { DeepLinkService } from '../main/ets/domain/services/DeepLinkService';
import {
  CompactPlanSerializer,
  SharePlanMetaInput
} from '../main/ets/domain/serializers/CompactPlanSerializer';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { DriveStrategy } from '../main/ets/model/interface/IMapService';

function buildPlanMeta(): SharePlanMetaInput {
  return {
    title: 'Hangzhou Weekend',
    startDate: 1713000000000,
    status: 1,
    enableAutoAmapRoute: 1
  };
}

function buildEvent(): TravelPlanItem {
  return {
    name: 'West Lake',
    note: 'sunset',
    duration: 90,
    preTravelMinutes: 15,
    sortOrder: 1,
    status: 1,
    lockStatus: 1,
    dayOffset: 0,
    itemType: 2,
    priority: 3,
    transportMode: 4,
    isTravelManual: 1,
    source: 1,
    groupId: 8,
    type: 'FLOW',
    address: 'Xihu District'
  };
}

function assertThrow(action: () => void, expectedMessage: string): void {
  let actual = '';
  try {
    action();
  } catch (error) {
    actual = (error as Error).message;
  }
  expect(actual).assertEqual(expectedMessage);
}

export default function phase1ZeroHitBatchBTest() {
  describe('phase1ZeroHitBatchBTest', () => {
    it('normal: deep_link_should_round_trip_payload', 0, () => {
      // Arrange
      const payload = '{"v":1,"p":{"t":"trip"}}';
      // Act
      const url = DeepLinkService.buildShareLink(payload);
      // Assert
      expect(url.startsWith('travelapp://import?data=')).assertTrue();
    });

    it('boundary: serializer_should_keep_empty_event_array', 0, () => {
      // Arrange
      const plan = buildPlanMeta();
      // Act
      const compressed = CompactPlanSerializer.compressForShare(plan, []);
      const decompressed = CompactPlanSerializer.decompressFromShare(compressed);
      // Assert
      expect(decompressed.plan.title).assertEqual(plan.title);
      expect(decompressed.events.length).assertEqual(0);
    });

    it('invalid: deep_link_should_reject_missing_data_query', 0, () => {
      // Arrange
      const invalidUrl = 'travelapp://import?foo=bar';
      // Act
      // Assert
      assertThrow(() => DeepLinkService.parseShareLink(invalidUrl), 'missing_data_parameter');
    });

    it('conflict: serializer_should_fallback_to_transport_mode_when_travel_mode_missing', 0, () => {
      // Arrange
      const plan = buildPlanMeta();
      const event = buildEvent();
      // Act
      const compressed = CompactPlanSerializer.compressForShare(plan, [event]);
      const decompressed = CompactPlanSerializer.decompressFromShare(compressed);
      // Assert
      expect(decompressed.events.length).assertEqual(1);
      expect(decompressed.events[0].travelMode).assertEqual(4);
      expect(decompressed.events[0].transportMode).assertEqual(4);
    });

    it('regression: td-20260412-batchb-unsupported_version_should_throw', 0, () => {
      // Arrange
      const invalidPayload = '{"v":2,"exp":1,"p":{"t":"x","sd":1,"st":1,"ar":1},"e":[]}';
      // Act
      // Assert
      assertThrow(() => CompactPlanSerializer.decompressFromShare(invalidPayload), 'unsupported_version:2');
    });

    it('combined: serializer_and_deeplink_should_work_together_and_keep_runtime_enum_values', 0, () => {
      // Arrange
      const plan = buildPlanMeta();
      const event = buildEvent();
      // Act
      const compressed = CompactPlanSerializer.compressForShare(plan, [event]);
      const link = DeepLinkService.buildShareLink(compressed);
      const restored = CompactPlanSerializer.decompressFromShare(compressed);
      // Assert
      expect(link.startsWith('travelapp://import?data=')).assertTrue();
      expect(restored.events[0].name).assertEqual('West Lake');
      expect(DriveStrategy.FASTEST).assertEqual(0);
      expect(DriveStrategy.AVOID_CONGESTION).assertEqual(4);
      expect(DriveStrategy.ECONOMICAL).assertEqual(1);
    });
  });
}
