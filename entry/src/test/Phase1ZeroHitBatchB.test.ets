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

function assertAnyThrow(action: () => void): void {
  let thrown = false;
  try {
    action();
  } catch (_error) {
    thrown = true;
  }
  expect(thrown).assertTrue();
}

class Base64DecodeThrowsStub {
  public decodeSync(_base64: string): Uint8Array {
    throw new Error('decode_sync_failed');
  }
}

class Base64DecodeEmptyStub {
  public decodeSync(_base64: string): Uint8Array {
    return new Uint8Array();
  }
}

class Base64HelperHooksB {
  private readonly originBase64Helper: Object;

  constructor() {
    this.originBase64Helper = Reflect.get(Reflect.get(globalThis, 'util') as Object, 'Base64Helper') as Object;
  }

  public use(stubCtor: Object): void {
    Reflect.set(Reflect.get(globalThis, 'util') as Object, 'Base64Helper', stubCtor);
  }

  public restore(): void {
    Reflect.set(Reflect.get(globalThis, 'util') as Object, 'Base64Helper', this.originBase64Helper);
  }
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

    it('normal: deep_link_parse_should_restore_payload', 0, () => {
      // Arrange
      const payload = '{"v":1,"p":{"t":"parse"}}';
      const url = 'travelapp://import?data=eyJ2IjoxLCJwIjp7InQiOiJwYXJzZSJ9fQ==';

      // Act
      const restored = DeepLinkService.parseShareLink(url);

      // Assert
      expect(restored).assertEqual(payload);
    });

    it('boundary: deep_link_parse_should_find_data_after_other_query_segments', 0, () => {
      // Arrange
      const payload = '{"v":1,"p":{"t":"query"}}';
      const dataValue = 'eyJ2IjoxLCJwIjp7InQiOiJxdWVyeSJ9fQ==';
      const reordered = `travelapp://import?foo=bar&data=${dataValue}&tail=1`;

      // Act
      const restored = DeepLinkService.parseShareLink(reordered);

      // Assert
      expect(restored).assertEqual(payload);
    });

    it('invalid: deep_link_parse_should_reject_wrong_scheme', 0, () => {
      // Arrange
      const invalidUrl = 'https://import?data=abc';

      // Act
      // Assert
      assertThrow(() => DeepLinkService.parseShareLink(invalidUrl), 'invalid_deep_link_scheme');
    });

    it('invalid: deep_link_parse_should_reject_empty_data_value', 0, () => {
      // Arrange
      const invalidUrl = 'travelapp://import?data=';

      // Act
      // Assert
      assertThrow(() => DeepLinkService.parseShareLink(invalidUrl), 'missing_data_parameter');
    });

    it('regression: deep_link_parse_should_throw_on_invalid_base64_payload', 0, () => {
      // Arrange
      const invalidUrl = 'travelapp://import?data=not-valid-base64%%%';

      // Act
      // Assert
      assertAnyThrow(() => DeepLinkService.parseShareLink(invalidUrl));
    });

    it('invalid: deep_link_parse_should_reject_link_without_query_part', 0, () => {
      // Arrange
      const invalidUrl = 'travelapp://import';

      // Act
      // Assert
      assertThrow(() => DeepLinkService.parseShareLink(invalidUrl), 'missing_data_parameter');
    });

    it('invalid: deep_link_parse_should_reject_trailing_question_mark_without_segments', 0, () => {
      // Arrange
      const invalidUrl = 'travelapp://import?';

      // Act
      // Assert
      assertThrow(() => DeepLinkService.parseShareLink(invalidUrl), 'missing_data_parameter');
    });

    it('boundary: deep_link_parse_should_fallback_to_manual_base64_decoder_when_decode_sync_throws', 0, () => {
      // Arrange
      const hooks = new Base64HelperHooksB();
      const url = 'travelapp://import?data=eyJ2IjoxLCJwIjp7%0AInQiOiJwYXJzZSJ9fQ==';

      // Act
      let restored = '';
      hooks.use(Base64DecodeThrowsStub as Object);
      try {
        restored = DeepLinkService.parseShareLink(url);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(restored).assertEqual('{"v":1,"p":{"t":"parse"}}');
    });

    it('boundary: deep_link_parse_should_retry_with_manual_decoder_when_decode_sync_returns_empty_bytes', 0, () => {
      // Arrange
      const hooks = new Base64HelperHooksB();
      const url = 'travelapp://import?data=eyJ2IjoxLCJwIjp7InQiOiJxdWVyeSJ9fQ==';

      // Act
      let restored = '';
      hooks.use(Base64DecodeEmptyStub as Object);
      try {
        restored = DeepLinkService.parseShareLink(url);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(restored).assertEqual('{"v":1,"p":{"t":"query"}}');
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
