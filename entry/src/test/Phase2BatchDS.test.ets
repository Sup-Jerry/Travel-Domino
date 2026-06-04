import { describe, expect, it } from '@ohos/hypium';
import {
  GeocodeSearch,
  PoiSearch,
  PoiSearchBound
} from '@amap/amap_lbs_search';
import { common } from '@kit.AbilityKit';
import { AmapService, GeoCoordinate, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';

interface AmapPrivateDS {
  extractPoiItems(result: Object | undefined): PoiSearchItem[];

  readPoiCache(cacheKey: string): PoiSearchItem[] | null;

  writePoiCache(cacheKey: string, items: PoiSearchItem[]): void;

  buildPoiCacheKey(keyword: string, centerLat: number, centerLng: number, limit: number): string;

  searchPoiBySdk(
    context: common.Context,
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number,
    nearbyOnly: boolean
  ): Promise<PoiSearchItem[]>;

  searchPoiByWebApi(
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number,
    nearbyOnly: boolean
  ): Promise<PoiSearchItem[]>;

  searchPoiWithWebFallback(
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number
  ): Promise<PoiSearchItem[]>;

  getGeocodeBySdkKeyword(address: string, context: common.Context): Promise<GeoCoordinate | null>;

  getGeocodeBySdkGeoSearch(address: string, context: common.Context): Promise<GeoCoordinate | null>;

  getCityCodeBySdkGeoSearch(context: common.Context, lat: number, lng: number): Promise<string | null>;

  getRegeoBySdkNearby(context: common.Context, lat: number, lng: number): Promise<string | null>;

  getRegeoBySdkGeoSearch(context: common.Context, lat: number, lng: number): Promise<string | null>;
}

interface HttpResponseDS {
  responseCode: number;
  result: string;
}

class LatLonPointMockDS {
  private readonly latitude: number;
  private readonly longitude: number;

  constructor(latitude: number, longitude: number) {
    this.latitude = latitude;
    this.longitude = longitude;
  }

  getLatitude(): number {
    return this.latitude;
  }

  getLongitude(): number {
    return this.longitude;
  }
}

class PoiItemMockDS {
  private readonly title: string;
  private readonly snippet: string;
  private readonly latitude: number;
  private readonly longitude: number;
  private readonly distance: number;

  constructor(
    title: string,
    snippet: string,
    latitude: number,
    longitude: number,
    distance: number = 0
  ) {
    this.title = title;
    this.snippet = snippet;
    this.latitude = latitude;
    this.longitude = longitude;
    this.distance = distance;
  }

  getLatLonPoint(): LatLonPointMockDS {
    return new LatLonPointMockDS(this.latitude, this.longitude);
  }

  getTitle(): string {
    return this.title;
  }

  getSnippet(): string {
    return this.snippet;
  }

  getDistance(): number {
    return this.distance;
  }
}

class PoiListMockDS {
  private readonly items: Object[];

  constructor(items: Object[]) {
    this.items = items;
  }

  size(): number {
    return this.items.length;
  }

  get(index: number): Object | undefined {
    return this.items[index];
  }

  forEach(callback: (item: Object) => void): void {
    this.items.forEach(callback);
  }
}

class PoiResultMockDS {
  private readonly pois: Object[];

  constructor(pois: Object[]) {
    this.pois = pois;
  }

  getPois(): PoiListMockDS {
    return new PoiListMockDS(this.pois);
  }
}

class ForEachOnlyPoiListMockDS {
  private readonly items: Object[];

  constructor(items: Object[]) {
    this.items = items;
  }

  forEach(callback: (item: Object) => void): void {
    this.items.forEach(callback);
  }
}

class ForEachOnlyPoiResultMockDS {
  private readonly pois: Object[];

  constructor(pois: Object[]) {
    this.pois = pois;
  }

  getPois(): ForEachOnlyPoiListMockDS {
    return new ForEachOnlyPoiListMockDS(this.pois);
  }
}

class GeocodeItemMockDS {
  private readonly latitude: number;
  private readonly longitude: number;

  constructor(latitude: number, longitude: number) {
    this.latitude = latitude;
    this.longitude = longitude;
  }

  getLatLonPoint(): LatLonPointMockDS {
    return new LatLonPointMockDS(this.latitude, this.longitude);
  }
}

class TitlePoiMockDS {
  private readonly title: string;

  constructor(title: string) {
    this.title = title;
  }

  getTitle(): string {
    return this.title;
  }
}

class RegeoResultMockDS {
  private readonly adCode: string;
  private readonly cityCode: string;
  private readonly formattedAddress: string;
  private readonly pois: Object[];

  constructor(
    adCode: string = '',
    cityCode: string = '',
    formattedAddress: string = '',
    pois: Object[] = []
  ) {
    this.adCode = adCode;
    this.cityCode = cityCode;
    this.formattedAddress = formattedAddress;
    this.pois = pois;
  }

  getAdCode(): string {
    return this.adCode;
  }

  getCityCode(): string {
    return this.cityCode;
  }

  getFormatAddress(): string {
    return this.formattedAddress;
  }

  getPois(): PoiListMockDS {
    return new PoiListMockDS(this.pois);
  }
}

class AmapWebHooksDS {
  private readonly originValidateAmapWebConfig: Object;
  private readonly originRequest: Object;

  constructor() {
    this.originValidateAmapWebConfig = Reflect.get(AppConfig as Object, 'validateAmapWebConfig') as Object;
    this.originRequest = Reflect.get(HttpRequestHelper as Object, 'request') as Object;
  }

  setValidateNoop(): void {
    Reflect.set(AppConfig as Object, 'validateAmapWebConfig', (): void => {
    });
  }

  setRequest(fn: (ownerTag: string, requestName: string, url: string, options: Object) => Promise<Object>): void {
    Reflect.set(HttpRequestHelper as Object, 'request', fn);
  }

  restore(): void {
    Reflect.set(AppConfig as Object, 'validateAmapWebConfig', this.originValidateAmapWebConfig);
    Reflect.set(HttpRequestHelper as Object, 'request', this.originRequest);
  }
}

class BoundMarkerDS {
  marker: string = 'circle_bound_ds';
}

class AmapSdkHooksDS {
  private readonly poiPrototype: Object;
  private readonly geocodePrototype: Object;
  private readonly originSearchPOI: Object;
  private readonly originSetBound: Object;
  private readonly originGetFromLocationName: Object;
  private readonly originGetFromLocation: Object;
  private readonly originCreateCircleSearchBound: Object;

  constructor() {
    this.poiPrototype = Reflect.get(PoiSearch as Object, 'prototype') as Object;
    this.geocodePrototype = Reflect.get(GeocodeSearch as Object, 'prototype') as Object;
    this.originSearchPOI = Reflect.get(this.poiPrototype, 'searchPOI') as Object;
    this.originSetBound = Reflect.get(this.poiPrototype, 'setBound') as Object;
    this.originGetFromLocationName = Reflect.get(this.geocodePrototype, 'getFromLocationName') as Object;
    this.originGetFromLocation = Reflect.get(this.geocodePrototype, 'getFromLocation') as Object;
    this.originCreateCircleSearchBound =
      Reflect.get(PoiSearchBound as Object, 'createCircleSearchBound') as Object;
  }

  setSearchPOI(fn: () => Promise<Object>): void {
    Reflect.set(this.poiPrototype, 'searchPOI', fn);
  }

  setBound(fn: (bound: Object) => void): void {
    Reflect.set(this.poiPrototype, 'setBound', fn);
  }

  setGetFromLocationName(fn: () => Promise<Object>): void {
    Reflect.set(this.geocodePrototype, 'getFromLocationName', fn);
  }

  setGetFromLocation(fn: () => Promise<Object>): void {
    Reflect.set(this.geocodePrototype, 'getFromLocation', fn);
  }

  setCreateCircleSearchBound(fn: (center: Object, radius: number, strict: boolean) => Object): void {
    Reflect.set(PoiSearchBound as Object, 'createCircleSearchBound', fn);
  }

  restore(): void {
    Reflect.set(this.poiPrototype, 'searchPOI', this.originSearchPOI);
    Reflect.set(this.poiPrototype, 'setBound', this.originSetBound);
    Reflect.set(this.geocodePrototype, 'getFromLocationName', this.originGetFromLocationName);
    Reflect.set(this.geocodePrototype, 'getFromLocation', this.originGetFromLocation);
    Reflect.set(PoiSearchBound as Object, 'createCircleSearchBound', this.originCreateCircleSearchBound);
  }
}

class AmapStaticHooksDS {
  private readonly originSearchPoiBySdk: Object;
  private readonly originSearchPoiWithWebFallback: Object;

  constructor() {
    this.originSearchPoiBySdk = Reflect.get(AmapService as Object, 'searchPoiBySdk') as Object;
    this.originSearchPoiWithWebFallback = Reflect.get(AmapService as Object, 'searchPoiWithWebFallback') as Object;
  }

  setSearchPoiBySdk(fn: (
    context: common.Context,
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number,
    nearbyOnly: boolean
  ) => Promise<PoiSearchItem[]>): void {
    Reflect.set(AmapService as Object, 'searchPoiBySdk', fn);
  }

  setSearchPoiWithWebFallback(fn: (
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number
  ) => Promise<PoiSearchItem[]>): void {
    Reflect.set(AmapService as Object, 'searchPoiWithWebFallback', fn);
  }

  restore(): void {
    Reflect.set(AmapService as Object, 'searchPoiBySdk', this.originSearchPoiBySdk);
    Reflect.set(AmapService as Object, 'searchPoiWithWebFallback', this.originSearchPoiWithWebFallback);
  }
}

class PoiCacheEntryMockDS {
  ts: number;
  items: PoiSearchItem[];

  constructor(ts: number, items: PoiSearchItem[]) {
    this.ts = ts;
    this.items = items;
  }
}

function buildPoiPayloadDS(pois: string): string {
  return `{"status":"1","pois":[${pois}]}`;
}

export default function phase2BatchDSTest() {
  describe('phase2BatchDSTest', () => {
    it('normal: amap_search_poi_by_sdk_should_resolve_items_and_apply_nearby_bound', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      let boundApplied = false;
      hooks.setCreateCircleSearchBound((_center: Object, _radius: number, _strict: boolean): Object => {
        return new BoundMarkerDS() as Object;
      });
      hooks.setBound((_bound: Object): void => {
        boundApplied = true;
      });
      hooks.setSearchPOI(async (): Promise<Object> => {
        return new PoiResultMockDS([
          new PoiItemMockDS('Museum', 'Road', 31.23, 121.47, 88)
        ]) as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiBySdk({} as common.Context, 'Museum', 31.23, 121.47, 2, true);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(boundApplied).assertTrue();
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Museum');
      expect(items[0].distance ?? 0).assertEqual(88);
    });

    it('normal: amap_search_poi_by_web_api_should_parse_nearby_result', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      let capturedUrl = '';
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        capturedUrl = url;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: buildPoiPayloadDS('{"name":"Museum","address":"Road","location":"121.470000,31.230000","distance":"88"}')
        };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiByWebApi('Museum', 31.23, 121.47, 2, true);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Museum');
      expect(items[0].distance ?? 0).assertEqual(88);
      expect(capturedUrl.includes('/around?')).assertTrue();
      expect(capturedUrl.includes('location=121.47,31.23')).assertTrue();
    });

    it('boundary: amap_search_poi_with_web_fallback_should_merge_nearby_and_nationwide', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      let aroundCalls = 0;
      let textCalls = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        if (url.includes('/around?')) {
          aroundCalls += 1;
          const response: HttpResponseDS = {
            responseCode: 200,
            result: buildPoiPayloadDS('{"name":"Nearby","address":"A","location":"121.400000,31.200000","distance":"10"}')
          };
          return response as Object;
        }
        textCalls += 1;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: buildPoiPayloadDS(
            '{"name":"Nearby","address":"A2","location":"121.400000,31.200000","distance":"99"},' +
              '{"name":"Nationwide","address":"B","location":"120.100000,30.100000","distance":"200"}'
          )
        };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiWithWebFallback('coffee', 31.2, 121.4, 3);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(aroundCalls).assertEqual(1);
      expect(textCalls).assertEqual(1);
      expect(items.length).assertEqual(2);
      expect(items[0].name).assertEqual('Nearby');
      expect(items[1].name).assertEqual('Nationwide');
    });

    it('invalid: amap_search_poi_by_web_api_should_return_empty_on_non_200', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const response: HttpResponseDS = { responseCode: 500, result: '{}' };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiByWebApi('bad', 31.23, 121.47, 2, false);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(0);
    });

    it('boundary: amap_get_geocode_by_sdk_keyword_should_return_top_coordinate', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setSearchPOI(async (): Promise<Object> => {
        return new PoiResultMockDS([
          new PoiItemMockDS('Library', 'Street', 30.11, 120.22, 12)
        ]) as Object;
      });

      // Act
      let coordinate: GeoCoordinate | null = null;
      try {
        coordinate = await api.getGeocodeBySdkKeyword('Library', {} as common.Context);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(coordinate?.lat ?? 0).assertEqual(30.11);
      expect(coordinate?.lng ?? 0).assertEqual(120.22);
    });

    it('invalid: amap_get_geocode_by_sdk_geo_search_should_return_null_for_invalid_coordinate', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setGetFromLocationName(async (): Promise<Object> => {
        return new PoiListMockDS([new GeocodeItemMockDS(0, 0)]) as Object;
      });

      // Act
      let coordinate: GeoCoordinate | null = null;
      try {
        coordinate = await api.getGeocodeBySdkGeoSearch('Invalid', {} as common.Context);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(coordinate === null).assertTrue();
    });

    it('conflict: amap_get_city_code_by_sdk_geo_search_should_prefer_adcode_over_citycode', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setGetFromLocation(async (): Promise<Object> => {
        return new RegeoResultMockDS('310000', '021') as Object;
      });

      // Act
      let cityCode: string | null = null;
      try {
        cityCode = await api.getCityCodeBySdkGeoSearch({} as common.Context, 31.23, 121.47);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(cityCode ?? '').assertEqual('310000');
    });

    it('regression: amap_get_regeo_by_sdk_nearby_should_return_null_when_top_name_blank', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setCreateCircleSearchBound((_center: Object, _radius: number, _strict: boolean): Object => {
        const bound = new BoundMarkerDS();
        bound.marker = 'nearby_bound_ds';
        return bound as Object;
      });
      hooks.setBound((_bound: Object): void => {
      });
      hooks.setSearchPOI(async (): Promise<Object> => {
        return new PoiResultMockDS([
          new PoiItemMockDS('   ', 'Road', 31.24, 121.48, 5)
        ]) as Object;
      });

      // Act
      let place: string | null = null;
      try {
        place = await api.getRegeoBySdkNearby({} as common.Context, 31.24, 121.48);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(place === null).assertTrue();
    });

    it('combined: amap_get_regeo_by_sdk_geo_search_should_fallback_to_formatted_address', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setGetFromLocation(async (): Promise<Object> => {
        return new RegeoResultMockDS('', '', 'Nanjing Road', [new TitlePoiMockDS('   ')]) as Object;
      });

      // Act
      let place: string | null = null;
      try {
        place = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.24, 121.49);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(place ?? '').assertEqual('Nanjing Road');
    });

    it('boundary: amap_extract_poi_items_should_use_for_each_when_index_getter_missing', 0, () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const result = new ForEachOnlyPoiResultMockDS([
        new PoiItemMockDS('ForEach Museum', 'Side Road', 31.26, 121.49, 66)
      ]);

      // Act
      const items = api.extractPoiItems(result as Object);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('ForEach Museum');
      expect(items[0].distance ?? 0).assertEqual(66);
    });

    it('boundary: amap_poi_cache_should_return_copy_until_entry_expires', 0, () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
      const cacheKey = api.buildPoiCacheKey('Museum', 31.23456, 121.45678, 3);
      cache.delete(cacheKey);

      // Act
      api.writePoiCache(cacheKey, [new PoiSearchItem('Cached', 'A', 31.2, 121.4, 1)]);
      const hit = api.readPoiCache(cacheKey);
      cache.set(cacheKey, new PoiCacheEntryMockDS(
        Date.now() - 30_000,
        [new PoiSearchItem('Expired', 'B', 31.3, 121.5, 2)]
      ) as Object);
      const expired = api.readPoiCache(cacheKey);

      // Assert
      expect(hit?.length ?? 0).assertEqual(1);
      expect(hit?.[0].name ?? '').assertEqual('Cached');
      expect(expired === null).assertTrue();
    });

    it('regression: amap_search_poi_should_use_web_fallback_when_sdk_md5_auth_failed', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      let fallbackCalls = 0;
      hooks.setSearchPoiBySdk(async (): Promise<PoiSearchItem[]> => {
        throw new Error('MD5 安全码未通过');
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        fallbackCalls += 1;
        return [new PoiSearchItem('Web Fallback', 'Road', 31.2, 121.4, 9)];
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await AmapService.searchPoi({} as common.Context, ' fallback md5 ', 31.2, 121.4, 1);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(fallbackCalls).assertEqual(1);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Web Fallback');
    });

    it('invalid: amap_search_poi_should_return_empty_when_sdk_and_web_fallback_both_fail', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      hooks.setSearchPoiBySdk(async (): Promise<PoiSearchItem[]> => {
        throw new Error('sdk_failed_ds');
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        throw new Error('web_failed_ds');
      });

      // Act
      let items: PoiSearchItem[] = [new PoiSearchItem('stale', '', 1, 1)];
      try {
        items = await AmapService.searchPoi({} as common.Context, ' fallback fail ', 31.3, 121.5, 2);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(0);
    });

    it('normal: amap_driving_duration_by_web_api_should_round_seconds_to_minutes', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let capturedUrl = '';
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        capturedUrl = url;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"1","route":{"paths":[{"duration":"121"}]}}'
        };
        return response as Object;
      });

      // Act
      let minutes: number | null = null;
      try {
        minutes = await AmapService.getDrivingDurationByWebApi(31.2, 121.4, 31.3, 121.5, 2.9);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(minutes ?? 0).assertEqual(3);
      expect(capturedUrl.includes('strategy=2')).assertTrue();
    });

    it('invalid: amap_driving_duration_by_web_api_should_reject_invalid_coordinates_and_duration', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"1","route":{"paths":[{"duration":"0"}]}}'
        };
        return response as Object;
      });

      // Act
      let invalidCoordinate: number | null = 1;
      let invalidDuration: number | null = 1;
      try {
        invalidCoordinate = await AmapService.getDrivingDurationByWebApi(0, 121.4, 31.3, 121.5);
        invalidDuration = await AmapService.getDrivingDurationByWebApi(31.2, 121.4, 31.3, 121.5);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(invalidCoordinate === null).assertTrue();
      expect(invalidDuration === null).assertTrue();
    });
  });
}
