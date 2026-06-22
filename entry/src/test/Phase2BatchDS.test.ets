import { describe, expect, it } from '@ohos/hypium';
import {
  GeocodeSearch,
  PoiSearch,
  PoiSearchBound,
  PoiItem
} from '@amap/amap_lbs_search';
import { common } from '@kit.AbilityKit';
import { AmapPoiSearchNode, AmapService, GeoCoordinate, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';

interface AmapPrivateDS {
  extractPoiItems(result: Object | undefined): PoiSearchItem[];
  normalizePoiNodes(nodes: Object | undefined): PoiSearchItem[];
  readAsText(value: Object | undefined): string;
  readAsNumber(value: Object | undefined): number;
  getListSize(listObj: Object | undefined): number;

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

class PoiItemNoPointMockDS {
  getLatLonPoint(): LatLonPointMockDS | undefined {
    return undefined;
  }

  getTitle(): string {
    return 'no_point_ds';
  }

  getSnippet(): string {
    return 'snippet_ds';
  }

  getDistance(): number {
    return 0;
  }
}

class EmptyObjectDS {
}

class LengthListMockDS {
  length: number;

  constructor(length: number) {
    this.length = length;
  }
}

class NumericSizeListMockDS {
  size: number;

  constructor(size: number) {
    this.size = size;
  }
}

class FunctionSizeListMockDS {
  private readonly value: number;

  constructor(value: number) {
    this.value = value;
  }

  size(): number {
    return this.value;
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

class NaNSizeListMockDS {
  size(): number {
    return Number.NaN;
  }
}

class NoIterPoiResultMockDS {
  getPois(): NaNSizeListMockDS {
    return new NaNSizeListMockDS();
  }
}

class AmapPoiSearchNodeMockDS implements AmapPoiSearchNode {
  id?: string;
  name?: string;
  address?: string;
  location?: string;
  distance?: string;

  constructor(name: string, address: string, location: string, distance: string) {
    this.name = name;
    this.address = address;
    this.location = location;
    this.distance = distance;
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

  setGetFromLocationName(fn: () => Promise<Object | null>): void {
    Reflect.set(this.geocodePrototype, 'getFromLocationName', fn);
  }

  setGetFromLocation(fn: () => Promise<Object | null>): void {
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

class Md5AuthErrorDS extends Error {
  errorCode: number;

  constructor(message: string, errorCode: number = 1008) {
    super(message);
    this.errorCode = errorCode;
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
      hooks.setGetFromLocation(async (): Promise<Object | null> => {
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
      hooks.setGetFromLocation(async (): Promise<Object | null> => {
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

    it('normal: amap_get_geocode_should_parse_web_coordinate_when_sdk_context_missing', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"1","geocodes":[{"location":"121.470000,31.230000"}]}'
        };
        return response as Object;
      });

      // Act
      let coordinate: GeoCoordinate | null = null;
      try {
        coordinate = await AmapService.getGeocode('Museum DS');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(coordinate?.lat ?? 0).assertEqual(31.23);
      expect(coordinate?.lng ?? 0).assertEqual(121.47);
    });

    it('invalid: amap_get_geocode_should_return_null_for_web_non_200_and_exception', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let call = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        call += 1;
        if (call === 1) {
          const response: HttpResponseDS = { responseCode: 503, result: '{}' };
          return response as Object;
        }
        throw new Error('geocode_web_failed_ds');
      });

      // Act
      let non200: GeoCoordinate | null = new GeoCoordinate(1, 1);
      let failed: GeoCoordinate | null = new GeoCoordinate(1, 1);
      try {
        non200 = await AmapService.getGeocode('Bad DS');
        failed = await AmapService.getGeocode('Throw DS');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(non200 === null).assertTrue();
      expect(failed === null).assertTrue();
    });

    it('invalid: amap_get_geocode_should_return_null_for_web_invalid_coordinate_pair', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"1","geocodes":[{"location":"121.47,95"}]}'
        };
        return response as Object;
      });

      // Act
      let coordinate: GeoCoordinate | null = new GeoCoordinate(1, 1);
      try {
        coordinate = await AmapService.getGeocode('invalid_coordinate_pair_ds');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(coordinate === null).assertTrue();
    });

    it('boundary: amap_private_scalar_helpers_should_handle_empty_and_mixed_inputs', 0, () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;

      // Act
      const emptyNodes = api.normalizePoiNodes(undefined);
      const textFromNumber = api.readAsText(123 as Object);
      const textFromObject = api.readAsText(new EmptyObjectDS() as Object);
      const numericValue = api.readAsNumber(23 as Object);
      const invalidNumeric = api.readAsNumber('bad' as Object);
      const objectNumeric = api.readAsNumber(new EmptyObjectDS() as Object);
      const lengthSize = api.getListSize(new LengthListMockDS(2) as Object);
      const numberSize = api.getListSize(new NumericSizeListMockDS(3) as Object);
      const fnSize = api.getListSize(new FunctionSizeListMockDS(4) as Object);
      const fallbackSize = api.getListSize(new FunctionSizeListMockDS(Number.NaN) as Object);
      const missingSize = api.getListSize(new EmptyObjectDS() as Object);

      // Assert
      expect(emptyNodes.length).assertEqual(0);
      expect(textFromNumber).assertEqual('123');
      expect(textFromObject).assertEqual('');
      expect(numericValue).assertEqual(23);
      expect(Number.isNaN(invalidNumeric)).assertTrue();
      expect(Number.isNaN(objectNumeric)).assertTrue();
      expect(lengthSize).assertEqual(2);
      expect(numberSize).assertEqual(3);
      expect(fnSize).assertEqual(4);
      expect(fallbackSize).assertEqual(0);
      expect(missingSize).assertEqual(0);
    });

    it('boundary: amap_search_poi_should_query_nationwide_when_nearby_empty', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      let sdkCalls = 0;
      hooks.setSearchPoiBySdk(async (
        _context: common.Context,
        _keyword: string,
        _centerLat: number,
        _centerLng: number,
        _limit: number,
        nearbyOnly: boolean
      ): Promise<PoiSearchItem[]> => {
        sdkCalls += 1;
        return nearbyOnly ? [] : [new PoiSearchItem('Nationwide DS', 'Road', 31.7, 121.8, 30)];
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => []);

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await AmapService.searchPoi({} as common.Context, 'nationwide_ds', 31.7, 121.8, 3);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(sdkCalls).assertEqual(2);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Nationwide DS');
    });

    it('regression: amap_search_poi_should_detect_md5_error_and_cache_web_fallback', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      let fallbackCalls = 0;
      hooks.setSearchPoiBySdk(async (): Promise<PoiSearchItem[]> => {
        throw new Md5AuthErrorDS('sdk auth failed ds');
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        fallbackCalls += 1;
        return [new PoiSearchItem('MD5 Fallback DS', 'Road', 31.8, 121.9, 40)];
      });

      // Act
      let first: PoiSearchItem[] = [];
      let second: PoiSearchItem[] = [];
      try {
        first = await AmapService.searchPoi({} as common.Context, 'md5_cache_ds', 31.8, 121.9, 3);
        second = await AmapService.searchPoi({} as common.Context, 'md5_cache_ds', 31.8, 121.9, 3);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(fallbackCalls).assertEqual(1);
      expect(first.length).assertEqual(1);
      expect(second.length).assertEqual(1);
      expect(second[0].name).assertEqual('MD5 Fallback DS');
    });

    it('invalid: amap_city_code_and_regeo_web_should_return_null_for_business_miss', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let call = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        call += 1;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: call === 1
            ? '{"status":"0","info":"bad","infocode":"10009","regeocode":{"addressComponent":{"adcode":"","citycode":""}}}'
            : '{"status":"0","info":"bad","infocode":"10009"}'
        };
        return response as Object;
      });

      // Act
      let cityCode: string | null = 'stale';
      let place: string | null = 'stale';
      try {
        cityCode = await AmapService.getCityCodeByCoordinate(31.21, 121.41);
        place = await AmapService.getRegeo(31.22, 121.42);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(cityCode === null).assertTrue();
      expect(place === null).assertTrue();
    });

    it('invalid: amap_city_code_and_regeo_web_should_return_null_for_non_200_and_exception', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let call = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        call += 1;
        if (call === 1) {
          const response: HttpResponseDS = { responseCode: 500, result: '{}' };
          return response as Object;
        }
        throw new Error('amap_web_failed_ds');
      });

      // Act
      let cityCode: string | null = 'stale';
      let place: string | null = 'stale';
      try {
        cityCode = await AmapService.getCityCodeByCoordinate(31.25, 121.45);
        place = await AmapService.getRegeo(31.26, 121.46);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(cityCode === null).assertTrue();
      expect(place === null).assertTrue();
    });

    it('boundary: amap_search_poi_with_web_fallback_should_return_nearby_only_when_count_is_enough', 0, async () => {
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
            result: buildPoiPayloadDS(
              '{"name":"A","address":"RoadA","location":"121.400000,31.200000","distance":"10"},' +
                '{"name":"B","address":"RoadB","location":"121.410000,31.210000","distance":"20"},' +
                '{"name":"C","address":"RoadC","location":"121.420000,31.220000","distance":"30"},' +
                '{"name":"D","address":"RoadD","location":"121.430000,31.230000","distance":"40"},' +
                '{"name":"E","address":"RoadE","location":"121.440000,31.240000","distance":"50"}'
            )
          };
          return response as Object;
        }
        textCalls += 1;
        const response: HttpResponseDS = { responseCode: 200, result: buildPoiPayloadDS('') };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiWithWebFallback('enough', 31.2, 121.4, 3);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(aroundCalls).assertEqual(1);
      expect(textCalls).assertEqual(0);
      expect(items.length).assertEqual(3);
      expect(items[0].name).assertEqual('A');
      expect(items[2].name).assertEqual('C');
    });

    it('boundary: amap_search_poi_should_return_empty_for_blank_keyword', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      let sdkCalls = 0;
      hooks.setSearchPoiBySdk(async (): Promise<PoiSearchItem[]> => {
        sdkCalls += 1;
        return [];
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        return [new PoiSearchItem('unexpected', '', 31.2, 121.4, 1)];
      });

      // Act
      let items: PoiSearchItem[] = [new PoiSearchItem('stale', '', 31.2, 121.4, 1)];
      try {
        items = await AmapService.searchPoi({} as common.Context, '   ', 31.2, 121.4, 5);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(0);
      expect(sdkCalls).assertEqual(0);
    });

    it('normal: amap_search_poi_should_return_sliced_nearby_and_refresh_cache_with_background_nationwide', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      const api = AmapService as Object as AmapPrivateDS;
      const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
      const cacheKey = api.buildPoiCacheKey('nearby_refresh_ds', 31.66, 121.77, 3);
      cache.delete(cacheKey);
      let sdkCalls = 0;
      hooks.setSearchPoiBySdk(async (
        _context: common.Context,
        _keyword: string,
        _centerLat: number,
        _centerLng: number,
        _limit: number,
        nearbyOnly: boolean
      ): Promise<PoiSearchItem[]> => {
        sdkCalls += 1;
        if (nearbyOnly) {
          return [
            new PoiSearchItem('Nearby-1', 'A', 31.6601, 121.7701, 1),
            new PoiSearchItem('Nearby-2', 'B', 31.6602, 121.7702, 2)
          ];
        }
        return [
          new PoiSearchItem('Nearby-1', 'A2', 31.6601, 121.7701, 10),
          new PoiSearchItem('Nearby-2', 'B2', 31.6602, 121.7702, 20),
          new PoiSearchItem('Nationwide-3', 'C', 31.6603, 121.7703, 30)
        ];
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        return [];
      });

      // Act
      let first: PoiSearchItem[] = [];
      let cached: PoiSearchItem[] | null = null;
      try {
        first = await AmapService.searchPoi({} as common.Context, 'nearby_refresh_ds', 31.66, 121.77, 3);
        await Promise.resolve();
        cached = api.readPoiCache(cacheKey);
      } finally {
        cache.delete(cacheKey);
        hooks.restore();
      }

      // Assert
      expect(sdkCalls).assertEqual(2);
      expect(first.length).assertEqual(2);
      expect(first[0].name).assertEqual('Nearby-1');
      expect(cached?.length ?? 0).assertEqual(3);
      expect(cached?.[2].name ?? '').assertEqual('Nationwide-3');
    });

    it('invalid: amap_get_city_code_by_sdk_geo_search_should_return_null_for_exception_and_empty_code', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      let call = 0;
      hooks.setGetFromLocation(async (): Promise<Object> => {
        call += 1;
        if (call === 1) {
          throw new Error('city_code_sdk_fail_ds');
        }
        return new RegeoResultMockDS('', '') as Object;
      });

      // Act
      let failedResult: string | null = 'stale';
      let emptyCode: string | null = 'stale';
      try {
        failedResult = await api.getCityCodeBySdkGeoSearch({} as common.Context, 31.2, 121.4);
        emptyCode = await api.getCityCodeBySdkGeoSearch({} as common.Context, 31.2, 121.4);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(failedResult === null).assertTrue();
      expect(emptyCode === null).assertTrue();
    });

    it('invalid: amap_get_geocode_sdk_variants_should_return_null_for_empty_and_invalid_results', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      let poiCall = 0;
      let geocodeCall = 0;
      hooks.setSearchPOI(async (): Promise<Object> => {
        poiCall += 1;
        if (poiCall === 1) {
          return new PoiResultMockDS([]) as Object;
        }
        return new PoiResultMockDS([
          new PoiItemMockDS('Invalid', 'Road', 0, 0, 10)
        ]) as Object;
      });
      hooks.setGetFromLocationName(async (): Promise<Object> => {
        geocodeCall += 1;
        return new PoiListMockDS([]) as Object;
      });

      // Act
      let keywordEmpty: GeoCoordinate | null = new GeoCoordinate(1, 1);
      let keywordInvalid: GeoCoordinate | null = new GeoCoordinate(1, 1);
      let geoEmpty: GeoCoordinate | null = new GeoCoordinate(1, 1);
      try {
        keywordEmpty = await api.getGeocodeBySdkKeyword('empty_ds', {} as common.Context);
        keywordInvalid = await api.getGeocodeBySdkKeyword('invalid_ds', {} as common.Context);
        geoEmpty = await api.getGeocodeBySdkGeoSearch('geo_empty_ds', {} as common.Context);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(keywordEmpty === null).assertTrue();
      expect(keywordInvalid === null).assertTrue();
      expect(geoEmpty === null).assertTrue();
      expect(geocodeCall).assertEqual(1);
    });

    it('invalid: amap_get_regeo_by_sdk_geo_search_should_return_null_for_exception_and_blank_address', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      let call = 0;
      hooks.setGetFromLocation(async (): Promise<Object> => {
        call += 1;
        if (call === 1) {
          throw new Error('regeo_sdk_fail_ds');
        }
        return new RegeoResultMockDS('', '', '   ', [new TitlePoiMockDS('   ')]) as Object;
      });

      // Act
      let failedResult: string | null = 'stale';
      let blankFallback: string | null = 'stale';
      try {
        failedResult = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.24, 121.49);
        blankFallback = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.24, 121.49);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(failedResult === null).assertTrue();
      expect(blankFallback === null).assertTrue();
    });

    it('boundary: amap_get_regeo_variants_should_use_address_fallbacks_and_empty_result_guards', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const sdkHooks = new AmapSdkHooksDS();
      const webHooks = new AmapWebHooksDS();
      let poiCall = 0;
      sdkHooks.setSearchPOI(async (): Promise<Object> => {
        poiCall += 1;
        return new PoiResultMockDS([]) as Object;
      });
      sdkHooks.setGetFromLocation(async (): Promise<Object | null> => {
        return new RegeoResultMockDS('', '', 'Address Fallback DS', [new TitlePoiMockDS('   ')]) as Object;
      });
      webHooks.setValidateNoop();
      webHooks.setRequest(async (): Promise<Object> => {
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"1","regeocode":{"formatted_address":"Web Address DS","pois":[]}}'
        };
        return response as Object;
      });

      // Act
      let nearbyEmpty: string | null = 'stale';
      let geoAddress: string | null = 'stale';
      let webAddress: string | null = 'stale';
      try {
        nearbyEmpty = await api.getRegeoBySdkNearby({} as common.Context, 31.24, 121.48);
        geoAddress = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.24, 121.49);
        webAddress = await AmapService.getRegeo(31.3, 121.5);
      } finally {
        sdkHooks.restore();
        webHooks.restore();
      }

      // Assert
      expect(nearbyEmpty === null).assertTrue();
      expect(geoAddress ?? '').assertEqual('Address Fallback DS');
      expect(webAddress ?? '').assertEqual('Web Address DS');
      expect(poiCall).assertEqual(1);
    });

    it('invalid: amap_get_geocode_and_route_web_should_return_null_for_business_miss_and_empty_path', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let call = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        call += 1;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: call === 1
            ? '{"status":"0","info":"bad","infocode":"10009"}'
            : call === 2
              ? '{"status":"1","geocodes":[{"location":"121.47"}]}'
              : call === 3
                ? '{"status":"0","info":"bad","infocode":"10009"}'
                : '{"status":"1","route":{"paths":[]}}'
        };
        return response as Object;
      });

      // Act
      let businessMiss: GeoCoordinate | null = new GeoCoordinate(1, 1);
      let invalidLocation: GeoCoordinate | null = new GeoCoordinate(1, 1);
      let routeBusinessMiss: number | null = 1;
      let routeEmptyPath: number | null = 1;
      try {
        businessMiss = await AmapService.getGeocode('business_miss_ds');
        invalidLocation = await AmapService.getGeocode('invalid_location_ds');
        routeBusinessMiss = await AmapService.getDrivingDurationByWebApi(31.2, 121.4, 31.3, 121.5);
        routeEmptyPath = await AmapService.getDrivingDurationByWebApi(31.2, 121.4, 31.3, 121.5);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(businessMiss === null).assertTrue();
      expect(invalidLocation === null).assertTrue();
      expect(routeBusinessMiss === null).assertTrue();
      expect(routeEmptyPath === null).assertTrue();
    });

    it('boundary: amap_get_regeo_with_sdk_fallback_should_return_web_result_without_nearby_retry', 0, async () => {
      // Arrange
      const originGetRegeoBySdkGeoSearch = Reflect.get(AmapService as Object, 'getRegeoBySdkGeoSearch') as Object;
      const originGetRegeo = Reflect.get(AmapService as Object, 'getRegeo') as Object;
      const originGetRegeoBySdkNearby = Reflect.get(AmapService as Object, 'getRegeoBySdkNearby') as Object;
      let nearbyCalls = 0;
      Reflect.set(AmapService as Object, 'getRegeoBySdkGeoSearch', async (): Promise<string | null> => null);
      Reflect.set(AmapService as Object, 'getRegeo', async (): Promise<string | null> => 'Web Place DS');
      Reflect.set(AmapService as Object, 'getRegeoBySdkNearby', async (): Promise<string | null> => {
        nearbyCalls += 1;
        return 'Nearby Place DS';
      });

      // Act
      let place: string | null = null;
      try {
        place = await AmapService.getRegeoWithSdkFallback(31.28, 121.52, {} as common.Context);
      } finally {
        Reflect.set(AmapService as Object, 'getRegeoBySdkGeoSearch', originGetRegeoBySdkGeoSearch);
        Reflect.set(AmapService as Object, 'getRegeo', originGetRegeo);
        Reflect.set(AmapService as Object, 'getRegeoBySdkNearby', originGetRegeoBySdkNearby);
      }

      // Assert
      expect(place ?? '').assertEqual('Web Place DS');
      expect(nearbyCalls).assertEqual(0);
    });

    it('boundary: amap_merge_poi_results_should_dedupe_and_use_default_limit_for_non_positive_limit', 0, () => {
      // Arrange
      const first = new PoiSearchItem('Museum', 'A', 31.2, 121.4, 10);
      const duplicate = new PoiSearchItem('Museum', 'B', 31.2, 121.4, 12);
      const second = new PoiSearchItem('Cafe', 'C', 31.3, 121.5, 20);

      // Act
      const merged = AmapService.mergePoiResults([first], [duplicate, second], 0);

      // Assert
      expect(merged.length).assertEqual(2);
      expect(merged[0].name).assertEqual('Museum');
      expect(merged[1].name).assertEqual('Cafe');
    });

    it('boundary: amap_should_fallback_to_nationwide_should_cover_threshold_edges', 0, () => {
      // Arrange
      // Act
      const fallbackTrue = AmapService.shouldFallbackToNationwide(2, 3);
      const fallbackFalse = AmapService.shouldFallbackToNationwide(3, 3);

      // Assert
      expect(fallbackTrue).assertTrue();
      expect(fallbackFalse).assertFalse();
    });

    it('invalid: amap_to_poi_search_item_should_return_null_for_missing_point_invalid_coordinate_and_blank_name', 0, () => {
      // Arrange
      const noPoint = new PoiItemNoPointMockDS();
      const invalidCoordinate = new PoiItemMockDS('BadCoord', 'Addr', 0, 0, 5);
      const blankName = new PoiItemMockDS('   ', 'Addr', 31.24, 121.48, 5);

      // Act
      const noPointItem = AmapService.toPoiSearchItem(noPoint as never);
      const invalidCoordinateItem = AmapService.toPoiSearchItem(invalidCoordinate as never);
      const blankNameItem = AmapService.toPoiSearchItem(blankName as never);

      // Assert
      expect(noPointItem === null).assertTrue();
      expect(invalidCoordinateItem === null).assertTrue();
      expect(blankNameItem === null).assertTrue();
    });

    it('boundary: amap_to_poi_search_item_should_drop_negative_distance_but_keep_valid_core_fields', 0, () => {
      // Arrange
      const poi = new PoiItemMockDS('Library', 'West Rd', 31.25, 121.49, -8);

      // Act
      const item = AmapService.toPoiSearchItem(poi as never);

      // Assert
      expect(item !== null).assertTrue();
      expect(item?.name ?? '').assertEqual('Library');
      expect(item?.distance === undefined).assertTrue();
    });

    it('boundary: amap_normalize_poi_nodes_should_skip_malformed_location_segments', 0, () => {
      // Arrange
      const nodes: AmapPoiSearchNode[] = [
        new AmapPoiSearchNodeMockDS('Malformed DS', 'Road', '121.470000', '12')
      ];

      // Act
      const items = AmapService.normalizePoiNodes(nodes);

      // Assert
      expect(items.length).assertEqual(0);
    });

    it('boundary: amap_extract_poi_items_should_return_empty_when_list_has_no_iteration_methods', 0, () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const result = new NoIterPoiResultMockDS();

      // Act
      const items = api.extractPoiItems(result);

      // Assert
      expect(items.length).assertEqual(0);
    });

    it('boundary: amap_search_poi_by_sdk_should_skip_bound_when_not_nearby_only', 0, async () => {
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
          new PoiItemMockDS('Museum Text DS', 'Road', 31.33, 121.57, 18)
        ]) as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiBySdk({} as common.Context, 'Museum Text DS', 31.33, 121.57, 2, false);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(boundApplied).assertFalse();
      expect(items.length).assertEqual(1);
    });

    it('boundary: amap_search_poi_by_web_api_should_use_text_endpoint_and_default_limit_for_non_positive_limit', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      let capturedUrl = '';
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        capturedUrl = url;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: buildPoiPayloadDS('{"name":"Text DS","address":"Road","location":"121.510000,31.220000","distance":"11"}')
        };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiByWebApi('text ds', 31.22, 121.51, 0, false);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(1);
      expect(capturedUrl.includes('/text?')).assertTrue();
      expect(capturedUrl.includes('&offset=10')).assertTrue();
    });

    it('boundary: amap_search_poi_should_fallback_for_non_md5_sdk_error', 0, async () => {
      // Arrange
      const hooks = new AmapStaticHooksDS();
      let fallbackCalls = 0;
      hooks.setSearchPoiBySdk(async (): Promise<PoiSearchItem[]> => {
        throw new Error('plain sdk failed ds');
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        fallbackCalls += 1;
        return [new PoiSearchItem('Plain Fallback DS', 'Road', 31.91, 121.91, 9)];
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await AmapService.searchPoi({} as common.Context, 'plain_fallback_ds', 31.91, 121.91, 2);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(fallbackCalls).assertEqual(1);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Plain Fallback DS');
    });

    it('invalid: amap_get_geocode_sdk_keyword_should_return_null_when_top_coordinate_becomes_invalid', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      const originExtractPoiItems = Reflect.get(AmapService as Object, 'extractPoiItems') as Object;
      hooks.setSearchPOI(async (): Promise<Object> => {
        return new PoiResultMockDS([
          new PoiItemMockDS('Ignored DS', 'Road', 31.2, 121.4, 1)
        ]) as Object;
      });
      Reflect.set(AmapService as Object, 'extractPoiItems', (_result: Object): PoiSearchItem[] => {
        return [new PoiSearchItem('Invalid Top DS', 'Road', 0, 0, 1)];
      });

      // Act
      let coordinate: GeoCoordinate | null = new GeoCoordinate(1, 1);
      try {
        coordinate = await api.getGeocodeBySdkKeyword('invalid_top_ds', {} as common.Context);
      } finally {
        Reflect.set(AmapService as Object, 'extractPoiItems', originExtractPoiItems);
        hooks.restore();
      }

      // Assert
      expect(coordinate === null).assertTrue();
    });

    it('normal: amap_get_geocode_sdk_geo_search_should_return_coordinate_for_valid_point', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setGetFromLocationName(async (): Promise<Object> => {
        return new PoiListMockDS([new GeocodeItemMockDS(31.28, 121.58)]) as Object;
      });

      // Act
      let coordinate: GeoCoordinate | null = null;
      try {
        coordinate = await api.getGeocodeBySdkGeoSearch('valid_geo_ds', {} as common.Context);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(coordinate?.lat ?? 0).assertEqual(31.28);
      expect(coordinate?.lng ?? 0).assertEqual(121.58);
    });

    it('boundary: amap_get_geocode_should_fallback_to_web_when_sdk_keyword_returns_null', 0, async () => {
      // Arrange
      const originGetRuntimeContext = Reflect.get(AmapService as Object, 'getRuntimeContext') as Object;
      const originGetGeocodeBySdkGeoSearch = Reflect.get(AmapService as Object, 'getGeocodeBySdkGeoSearch') as Object;
      const originGetGeocodeBySdkKeyword = Reflect.get(AmapService as Object, 'getGeocodeBySdkKeyword') as Object;
      const originGetGeocodeByWeb = Reflect.get(AmapService as Object, 'getGeocodeByWeb') as Object;
      Reflect.set(AmapService as Object, 'getRuntimeContext', (): Object => new EmptyObjectDS() as Object);
      Reflect.set(AmapService as Object, 'getGeocodeBySdkGeoSearch', async (): Promise<GeoCoordinate | null> => null);
      Reflect.set(AmapService as Object, 'getGeocodeBySdkKeyword', async (): Promise<GeoCoordinate | null> => null);
      Reflect.set(AmapService as Object, 'getGeocodeByWeb', async (): Promise<GeoCoordinate | null> => {
        return new GeoCoordinate(30.55, 120.66);
      });

      // Act
      let coordinate: GeoCoordinate | null = null;
      try {
        coordinate = await AmapService.getGeocode('web_only_ds');
      } finally {
        Reflect.set(AmapService as Object, 'getRuntimeContext', originGetRuntimeContext);
        Reflect.set(AmapService as Object, 'getGeocodeBySdkGeoSearch', originGetGeocodeBySdkGeoSearch);
        Reflect.set(AmapService as Object, 'getGeocodeBySdkKeyword', originGetGeocodeBySdkKeyword);
        Reflect.set(AmapService as Object, 'getGeocodeByWeb', originGetGeocodeByWeb);
      }

      // Assert
      expect(coordinate?.lat ?? 0).assertEqual(30.55);
      expect(coordinate?.lng ?? 0).assertEqual(120.66);
    });

    it('invalid: amap_route_web_should_cover_nan_strategy_non_200_and_non_10009_business_miss', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let call = 0;
      let firstUrl = '';
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        call += 1;
        if (call === 1) {
          firstUrl = url;
          const response: HttpResponseDS = {
            responseCode: 500,
            result: '{}'
          };
          return response as Object;
        }
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"0","info":"bad","infocode":"10001"}'
        };
        return response as Object;
      });

      // Act
      let non200: number | null = 1;
      let businessMiss: number | null = 1;
      try {
        non200 = await AmapService.getDrivingDurationByWebApi(31.2, 121.4, 31.3, 121.5, Number.NaN);
        businessMiss = await AmapService.getDrivingDurationByWebApi(31.2, 121.4, 31.3, 121.5, 2);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(firstUrl.includes('strategy=0')).assertTrue();
      expect(non200 === null).assertTrue();
      expect(businessMiss === null).assertTrue();
    });

    it('invalid: amap_get_city_code_sdk_geo_search_should_return_null_when_sdk_result_missing', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setGetFromLocation(async (): Promise<Object | null> => null);

      // Act
      let cityCode: string | null = 'stale';
      try {
        cityCode = await api.getCityCodeBySdkGeoSearch({} as common.Context, 31.29, 121.59);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(cityCode === null).assertTrue();
    });

    it('invalid: amap_get_regeo_should_return_null_for_non_200_and_empty_success_payload', 0, async () => {
      // Arrange
      const hooks = new AmapWebHooksDS();
      let call = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (): Promise<Object> => {
        call += 1;
        if (call === 1) {
          const response: HttpResponseDS = {
            responseCode: 500,
            result: '{}'
          };
          return response as Object;
        }
        const response: HttpResponseDS = {
          responseCode: 200,
          result: '{"status":"1","regeocode":{"pois":[],"formatted_address":""},"info":"ok","infocode":"10001"}'
        };
        return response as Object;
      });

      // Act
      let non200: string | null = 'stale';
      let emptySuccess: string | null = 'stale';
      try {
        non200 = await AmapService.getRegeo(31.31, 121.61);
        emptySuccess = await AmapService.getRegeo(31.32, 121.62);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(non200 === null).assertTrue();
      expect(emptySuccess === null).assertTrue();
    });

    it('normal: amap_get_regeo_by_sdk_nearby_should_return_top_name_when_available', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      hooks.setCreateCircleSearchBound((_center: Object, _radius: number, _strict: boolean): Object => {
        return new BoundMarkerDS() as Object;
      });
      hooks.setBound((_bound: Object): void => {
      });
      hooks.setSearchPOI(async (): Promise<Object> => {
        return new PoiResultMockDS([
          new PoiItemMockDS('Nearby Success DS', 'Road', 31.34, 121.64, 6)
        ]) as Object;
      });

      // Act
      let place: string | null = null;
      try {
        place = await api.getRegeoBySdkNearby({} as common.Context, 31.34, 121.64);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(place ?? '').assertEqual('Nearby Success DS');
    });

    it('invalid: amap_get_regeo_by_sdk_nearby_should_return_null_for_blank_top_name', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      const originExtractPoiItems = Reflect.get(AmapService as Object, 'extractPoiItems') as Object;
      hooks.setCreateCircleSearchBound((_center: Object, _radius: number, _strict: boolean): Object => {
        return new BoundMarkerDS() as Object;
      });
      hooks.setBound((_bound: Object): void => {
      });
      hooks.setSearchPOI(async (): Promise<Object> => {
        return new EmptyObjectDS() as Object;
      });
      Reflect.set(AmapService as Object, 'extractPoiItems', (): PoiSearchItem[] => {
        return [new PoiSearchItem('   ', 'Road', 31.35, 121.65, 6)];
      });

      // Act
      let place: string | null = 'stale';
      try {
        place = await api.getRegeoBySdkNearby({} as common.Context, 31.35, 121.65);
      } finally {
        Reflect.set(AmapService as Object, 'extractPoiItems', originExtractPoiItems);
        hooks.restore();
      }

      // Assert
      expect(place === null).assertTrue();
    });

    it('boundary: amap_get_regeo_sdk_geo_search_should_cover_missing_result_empty_pois_and_poi_title_success', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapSdkHooksDS();
      let call = 0;
      hooks.setGetFromLocation(async (): Promise<Object | null> => {
        call += 1;
        if (call === 1) {
          return null;
        }
        if (call === 2) {
          return new RegeoResultMockDS('', '', 'Address Only DS', []) as Object;
        }
        return new RegeoResultMockDS('', '', '', [new TitlePoiMockDS('Poi Success DS')]) as Object;
      });

      // Act
      let missing: string | null = 'stale';
      let addressOnly: string | null = 'stale';
      let poiTitle: string | null = 'stale';
      try {
        missing = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.35, 121.65);
        addressOnly = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.35, 121.65);
        poiTitle = await api.getRegeoBySdkGeoSearch({} as common.Context, 31.35, 121.65);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(missing === null).assertTrue();
      expect(addressOnly ?? '').assertEqual('Address Only DS');
      expect(poiTitle ?? '').assertEqual('Poi Success DS');
    });
  });
}
