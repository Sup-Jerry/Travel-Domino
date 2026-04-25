import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';

class AmapSearchHooksGX {
  private readonly originSearchPoiBySdk: Object;

  constructor() {
    this.originSearchPoiBySdk = Reflect.get(AmapService as Object, 'searchPoiBySdk') as Object;
  }

  public setSearchPoiBySdk(
    handler: (
      context: Object,
      keyword: string,
      centerLat: number,
      centerLng: number,
      limit: number,
      nearbyOnly: boolean
    ) => Promise<PoiSearchItem[]>
  ): void {
    Reflect.set(AmapService as Object, 'searchPoiBySdk', handler);
  }

  public restore(): void {
    Reflect.set(AmapService as Object, 'searchPoiBySdk', this.originSearchPoiBySdk);
  }
}

function clearAmapPoiCacheGX(): void {
  const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
  cache.clear();
}

function waitMicrotaskGX(): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => resolve(), 0);
  });
}

function buildPoiGX(name: string, lat: number, lng: number, distance: number): PoiSearchItem {
  return new PoiSearchItem(name, `${name}_addr`, lat, lng, distance);
}

export default function phase2BatchGXTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGX_amap_search_poi_background_callbacks', () => {
    it('normal: amap_service_should_merge_background_nationwide_results_into_cache_after_nearby_return', 0, async () => {
      // Arrange
      clearAmapPoiCacheGX();
      const hooks = new AmapSearchHooksGX();
      hooks.setSearchPoiBySdk(async (
        _context: Object,
        _keyword: string,
        _centerLat: number,
        _centerLng: number,
        _limit: number,
        nearbyOnly: boolean
      ): Promise<PoiSearchItem[]> => {
        if (nearbyOnly) {
          return [buildPoiGX('nearby', 31.21, 121.41, 10)];
        }
        return [
          buildPoiGX('nearby', 31.21, 121.41, 10),
          buildPoiGX('nationwide', 31.31, 121.51, 20)
        ];
      });

      try {
        // Act
        const first = await AmapService.searchPoi({} as common.Context, 'museum_gx_ok', 31.2, 121.4, 5);
        await waitMicrotaskGX();
        const second = await AmapService.searchPoi({} as common.Context, 'museum_gx_ok', 31.2, 121.4, 5);

        // Assert
        expect(first.length).assertEqual(1);
        expect(first[0].name).assertEqual('nearby');
        expect(second.length).assertEqual(2);
        expect(second[0].name).assertEqual('nearby');
        expect(second[1].name).assertEqual('nationwide');
      } finally {
        hooks.restore();
        clearAmapPoiCacheGX();
      }
    });

    it('regression: amap_service_should_keep_nearby_cache_when_background_nationwide_request_rejects', 0, async () => {
      // Arrange
      clearAmapPoiCacheGX();
      const hooks = new AmapSearchHooksGX();
      hooks.setSearchPoiBySdk(async (
        _context: Object,
        _keyword: string,
        _centerLat: number,
        _centerLng: number,
        _limit: number,
        nearbyOnly: boolean
      ): Promise<PoiSearchItem[]> => {
        if (nearbyOnly) {
          return [buildPoiGX('nearby_only', 31.25, 121.45, 11)];
        }
        throw new Error('nationwide_fail_gx');
      });

      try {
        // Act
        const first = await AmapService.searchPoi({} as common.Context, 'museum_gx_fail', 31.2, 121.4, 5);
        await waitMicrotaskGX();
        const second = await AmapService.searchPoi({} as common.Context, 'museum_gx_fail', 31.2, 121.4, 5);

        // Assert
        expect(first.length).assertEqual(1);
        expect(second.length).assertEqual(1);
        expect(second[0].name).assertEqual('nearby_only');
      } finally {
        hooks.restore();
        clearAmapPoiCacheGX();
      }
    });
  });
}
