// 文件路径: ets/infrastructure/services/AmapService.ets
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../../common/utils/AppConfig';
import { HttpRequestHelper } from '../adapters/HttpRequestHelper';
import {
  PoiSearch, PoiQuery, PoiSearchBound, LatLonPoint, PoiResult, PoiItem,
  GeocodeSearch, GeocodeQuery, ReGeocodeQuery
} from '@amap/amap_lbs_search';
import { common } from '@kit.AbilityKit';

export class GeoCoordinate {
  lat: number = 0;
  lng: number = 0;

  constructor(lat: number, lng: number) {
    this.lat = lat;
    this.lng = lng;
  }
}

export interface AmapGeocodeNode {
  location: string;
}

export interface AmapResponse {
  status: string;
  info?: string;
  infocode?: string;
  geocodes?: AmapGeocodeNode[];
}

export interface AmapPoi {
  name: string;
}

export interface AmapPoiSearchNode {
  id?: string;
  name?: string;
  address?: string;
  location?: string;
  distance?: string;
}

export interface AmapPoiSearchResponse {
  status: string;
  pois?: AmapPoiSearchNode[];
}

interface AmapRoutePathNode {
  duration?: string;
}

interface AmapDrivingRouteNode {
  paths?: AmapRoutePathNode[];
}

interface AmapDrivingRouteResponse {
  status: string;
  info?: string;
  infocode?: string;
  route?: AmapDrivingRouteNode;
}

interface PoiItemListLike {
  length?: number;
  size?: (() => number) | number;
  get?: (index: number) => PoiItem | undefined;
  forEach?: (callback: (value: PoiItem) => void) => void;
}

interface GenericListLike {
  length?: number;
  size?: (() => number) | number;
}

interface GenericListGetter<T> {
  get?: (idx: number) => T | undefined;
}

interface LatLonPointCarrier {
  getLatLonPoint: () => LatLonPoint | undefined;
}

interface PoiTitleCarrier {
  getTitle: () => string | undefined;
}

interface PoiSearchCacheEntry {
  ts: number;
  items: PoiSearchItem[];
}

export class PoiSearchItem {
  name: string = '';
  address: string = '';
  lat: number = 0;
  lng: number = 0;
  distance?: number;

  constructor(name: string, address: string, lat: number, lng: number, distance?: number) {
    this.name = name;
    this.address = address;
    this.lat = lat;
    this.lng = lng;
    this.distance = distance;
  }
}

export interface AmapAddressComponent {
  citycode?: string;
  adcode?: string;
}

export interface AmapRegeocode {
  formatted_address: string;
  pois?: AmapPoi[];
  addressComponent?: AmapAddressComponent;
}

export interface AmapRegeoResponse {
  status: string;
  info?: string;
  infocode?: string;
  regeocode?: AmapRegeocode;
}

export class AmapService {
  private static readonly TAG = 'AmapService';
  private static readonly POI_MIN_NEARBY_COUNT = 5;
  private static readonly POI_DEFAULT_LIMIT = 10;
  private static readonly POI_NEARBY_RADIUS_METERS = 50000;
  private static readonly POI_CACHE_TTL_MS = 20_000;
  private static readonly poiSearchCache: Map<string, PoiSearchCacheEntry> = new Map();
  private static runtimeContext: common.Context | null = null;

  public static bindRuntimeContext(context: common.Context): void {
    AmapService.runtimeContext = context;
  }

  public static getRuntimeContext(): common.Context | null {
    return AmapService.runtimeContext;
  }

  private static isValidCoordinate(lat: number, lng: number): boolean {
    return Number.isFinite(lat) &&
      Number.isFinite(lng) &&
      Math.abs(lat) <= 90 &&
      Math.abs(lng) <= 180 &&
      !(lat === 0 && lng === 0);
  }

  private static async getGeocodeByWeb(address: string): Promise<GeoCoordinate | null> {
    if (!address || address.trim() === '') {
      hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode] empty address, skip request');
      return null;
    }

    try {
      AppConfig.validateAmapWebConfig();
      const url =
        `https://restapi.amap.com/v3/geocode/geo?address=${encodeURIComponent(address)}` +
        `&key=${AppConfig.AMAP_WEB_API_KEY}`;

      const response = await HttpRequestHelper.request(AmapService.TAG, 'getGeocode', url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });

      if (response.responseCode === 200) {
        const resultData = JSON.parse(response.result as string) as AmapResponse;

        if (resultData.status === '1' && resultData.geocodes && resultData.geocodes.length > 0) {
          const locationStr: string = resultData.geocodes[0].location;
          const parts = locationStr.split(',');
          if (parts.length === 2) {
            const lat = Number.parseFloat(parts[1]);
            const lng = Number.parseFloat(parts[0]);
            if (AmapService.isValidCoordinate(lat, lng)) {
              const coordinate = new GeoCoordinate(lat, lng);
              hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode] resolve success');
              return coordinate;
            }
            hilog.warn(0x0000, AmapService.TAG, `[AMAP_TRACE][getGeocode] invalid coordinate lat=${lat}, lng=${lng}`);
          }
        }

        hilog.warn(
          0x0000,
          AmapService.TAG,
          `[AMAP_TRACE][getGeocode] business miss, status=${resultData.status}, info=${resultData.info ?? ''}, infocode=${resultData.infocode ?? ''}`
        );
        if (resultData.infocode === '10009') {
          hilog.error(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode] USERKEY_PLAT_NOMATCH: 请替换为高德Web服务Key');
        }
      } else {
        hilog.warn(0x0000, AmapService.TAG, `[AMAP_TRACE][getGeocode] non-200 responseCode=${response.responseCode}`);
      }
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getGeocode] failed, error=${JSON.stringify(error)}`);
    }

    return null;
  }

  public static shouldFallbackToNationwide(nearbyCount: number, minNearby: number = AmapService.POI_MIN_NEARBY_COUNT): boolean {
    return nearbyCount < minNearby;
  }

  public static parsePoiResponse(payload: string): PoiSearchItem[] {
    if (!payload || payload.trim() === '') {
      return [];
    }

    try {
      const resultData = JSON.parse(payload) as AmapPoiSearchResponse;
      if (resultData.status !== '1') {
        return [];
      }
      return AmapService.normalizePoiNodes(resultData.pois);
    } catch (error) {
      hilog.warn(0x0000, AmapService.TAG, `[AMAP_TRACE][parsePoiResponse] parse failed, error=${JSON.stringify(error)}`);
      return [];
    }
  }

  public static normalizePoiNodes(nodes: AmapPoiSearchNode[] | undefined): PoiSearchItem[] {
    if (!nodes || nodes.length === 0) {
      return [];
    }

    const normalized: PoiSearchItem[] = [];
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i];
      const location = AmapService.readAsText(node.location);
      if (location.length === 0) {
        continue;
      }

      const parts = location.split(',');
      if (parts.length !== 2) {
        continue;
      }

      const lng = Number.parseFloat(parts[0]);
      const lat = Number.parseFloat(parts[1]);
      if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat === 0 || lng === 0) {
        continue;
      }

      const name = AmapService.readAsText(node.name);
      if (name.length === 0) {
        continue;
      }

      const address = AmapService.readAsText(node.address);
      const parsedDistance = AmapService.readAsNumber(node.distance);
      const distance = Number.isFinite(parsedDistance) && parsedDistance >= 0 ? parsedDistance : undefined;
      normalized.push(new PoiSearchItem(name, address, lat, lng, distance));
    }

    return normalized;
  }

  private static readAsText(value: Object | undefined): string {
    if (typeof value === 'string') {
      return value.trim();
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
      return `${value}`.trim();
    }
    return '';
  }

  private static readAsNumber(value: Object | undefined): number {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value.trim());
      return Number.isFinite(parsed) ? parsed : Number.NaN;
    }
    return Number.NaN;
  }

  public static mergePoiResults(primary: PoiSearchItem[], secondary: PoiSearchItem[], limit: number): PoiSearchItem[] {
    const merged: PoiSearchItem[] = [];
    const seen = new Set<string>();
    const safeLimit = limit > 0 ? limit : AmapService.POI_DEFAULT_LIMIT;
    const all = [...primary, ...secondary];

    for (let i = 0; i < all.length; i++) {
      const item = all[i];
      const key = `${item.name}|${item.lat.toFixed(6)}|${item.lng.toFixed(6)}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      merged.push(item);
      if (merged.length >= safeLimit) {
        break;
      }
    }

    return merged;
  }

  public static toPoiSearchItem(poi: PoiItem | undefined): PoiSearchItem | null {
    if (!poi) {
      return null;
    }

    const point = poi.getLatLonPoint();
    if (!point) {
      return null;
    }

    const lat = point.getLatitude();
    const lng = point.getLongitude();
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat === 0 || lng === 0) {
      return null;
    }

    const name = (poi.getTitle() ?? '').trim();
    if (name.length === 0) {
      return null;
    }

    const address = (poi.getSnippet() ?? '').trim();
    const rawDistance = poi.getDistance();
    const distance = Number.isFinite(rawDistance) && rawDistance >= 0 ? rawDistance : undefined;
    return new PoiSearchItem(name, address, lat, lng, distance);
  }

  private static resolvePoiListCount(listObj: PoiItemListLike): number {
    if (typeof listObj.length === 'number' && Number.isFinite(listObj.length)) {
      return listObj.length;
    }
    if (typeof listObj.size === 'number' && Number.isFinite(listObj.size)) {
      return listObj.size;
    }
    if (typeof listObj.size === 'function') {
      const size = listObj.size();
      if (Number.isFinite(size)) {
        return size;
      }
    }
    return 0;
  }

  private static extractPoiItems(result: PoiResult | undefined): PoiSearchItem[] {
    if (!result) {
      return [];
    }

    const pois = result.getPois();
    if (!pois) {
      return [];
    }

    const listObj = pois as PoiItemListLike;

    const resolved: PoiSearchItem[] = [];
    const length = AmapService.resolvePoiListCount(listObj);
    if (length > 0 && typeof listObj.get === 'function') {
      for (let i = 0; i < length; i++) {
        const poi = listObj.get(i);
        const mapped = AmapService.toPoiSearchItem(poi);
        if (mapped) {
          resolved.push(mapped);
        }
      }
      if (resolved.length > 0) {
        return resolved;
      }
    }

    if (typeof listObj.forEach === 'function') {
      listObj.forEach((poi: PoiItem) => {
        const mapped = AmapService.toPoiSearchItem(poi);
        if (mapped) {
          resolved.push(mapped);
        }
      });
    }

    return resolved;
  }

  private static async searchPoiBySdk(
    context: common.Context,
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number,
    nearbyOnly: boolean
  ): Promise<PoiSearchItem[]> {
    const query = new PoiQuery(keyword, '', '');
    query.setPageNum(1);
    query.setPageSize(limit);
    query.setCityLimit(false);

    const center = new LatLonPoint(centerLat, centerLng);
    query.setLocation(center);
    query.setDistanceSort(nearbyOnly);
    query.setExtensions(PoiSearch.EXTENSIONS_BASE);

    const search = new PoiSearch(context, query);
    if (nearbyOnly) {
      const bound = PoiSearchBound.createCircleSearchBound(center, AmapService.POI_NEARBY_RADIUS_METERS, true);
      search.setBound(bound);
    }

    const result = await search.searchPOI();
    const resolved = AmapService.extractPoiItems(result);
    hilog.info(
      0x0000,
      AmapService.TAG,
      `[AMAP_TRACE][searchPoiBySdk] keyword_len=${keyword.length}, nearbyOnly=${nearbyOnly}, resolved=${resolved.length}`
    );
    return resolved;
  }

  private static async searchPoiByWebApi(
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number,
    nearbyOnly: boolean
  ): Promise<PoiSearchItem[]> {
    AppConfig.validateAmapWebConfig();
    const safeLimit = limit > 0 ? limit : AmapService.POI_DEFAULT_LIMIT;
    const encodedKeyword = encodeURIComponent(keyword);
    const base = 'https://restapi.amap.com/v3/place';
    const url = nearbyOnly
      ? `${base}/around?key=${AppConfig.AMAP_WEB_API_KEY}&location=${centerLng},${centerLat}` +
        `&keywords=${encodedKeyword}&radius=${AmapService.POI_NEARBY_RADIUS_METERS}&sortrule=distance` +
        `&offset=${safeLimit}&page=1&extensions=base`
      : `${base}/text?key=${AppConfig.AMAP_WEB_API_KEY}&keywords=${encodedKeyword}` +
        `&offset=${safeLimit}&page=1&extensions=base`;

    const response = await HttpRequestHelper.request(AmapService.TAG, 'searchPoiByWebApi', url, {
      method: http.RequestMethod.GET,
      connectTimeout: 5000,
      readTimeout: 5000
    });

    if (response.responseCode !== 200) {
      hilog.warn(
        0x0000,
        AmapService.TAG,
        `[AMAP_TRACE][searchPoiByWebApi] non-200 responseCode=${response.responseCode}, nearbyOnly=${nearbyOnly}`
      );
      return [];
    }

    const payload = String(response.result ?? '');
    const resolved = AmapService.parsePoiResponse(payload);
    hilog.info(
      0x0000,
      AmapService.TAG,
      `[AMAP_TRACE][searchPoiByWebApi] keyword_len=${keyword.length}, nearbyOnly=${nearbyOnly}, resolved=${resolved.length}`
    );
    return resolved;
  }

  private static isSdkMd5AuthError(error: Object): boolean {
    const raw = JSON.stringify(error);
    return raw.includes('"errorCode":1008') || raw.includes('MD5') || raw.includes('安全码未通过');
  }

  private static async searchPoiWithWebFallback(
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number
  ): Promise<PoiSearchItem[]> {
    const nearby = await AmapService.searchPoiByWebApi(keyword, centerLat, centerLng, limit, true);
    if (!AmapService.shouldFallbackToNationwide(nearby.length)) {
      return nearby.slice(0, limit);
    }
    const nationwide = await AmapService.searchPoiByWebApi(keyword, centerLat, centerLng, limit, false);
    return AmapService.mergePoiResults(nearby, nationwide, limit);
  }

  private static buildPoiCacheKey(keyword: string, centerLat: number, centerLng: number, limit: number): string {
    return `${keyword.toLowerCase()}|${centerLat.toFixed(4)}|${centerLng.toFixed(4)}|${limit}`;
  }

  private static readPoiCache(cacheKey: string): PoiSearchItem[] | null {
    const hit = AmapService.poiSearchCache.get(cacheKey);
    if (!hit) {
      return null;
    }
    if (Date.now() - hit.ts > AmapService.POI_CACHE_TTL_MS) {
      AmapService.poiSearchCache.delete(cacheKey);
      return null;
    }
    return hit.items;
  }

  private static writePoiCache(cacheKey: string, items: PoiSearchItem[]): void {
    const cacheEntry: PoiSearchCacheEntry = {
      ts: Date.now(),
      items: items
    };
    AmapService.poiSearchCache.set(cacheKey, cacheEntry);
  }

  public static async searchPoi(
    context: common.Context,
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number = AmapService.POI_DEFAULT_LIMIT
  ): Promise<PoiSearchItem[]> {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) {
      return [];
    }

    const safeLimit = limit > 0 ? limit : AmapService.POI_DEFAULT_LIMIT;
    const cacheKey = AmapService.buildPoiCacheKey(trimmed, centerLat, centerLng, safeLimit);
    const cached = AmapService.readPoiCache(cacheKey);
    if (cached) {
      return cached.slice(0, safeLimit);
    }

    try {
      const nearby = await AmapService.searchPoiBySdk(context, trimmed, centerLat, centerLng, safeLimit, true);
      if (!AmapService.shouldFallbackToNationwide(nearby.length)) {
        const slicedNearby = nearby.slice(0, safeLimit);
        AmapService.writePoiCache(cacheKey, slicedNearby);
        return slicedNearby;
      }

      if (nearby.length > 0) {
        const slicedNearby = nearby.slice(0, safeLimit);
        AmapService.writePoiCache(cacheKey, slicedNearby);
        void AmapService.searchPoiBySdk(context, trimmed, centerLat, centerLng, safeLimit, false)
          .then((nationwide: PoiSearchItem[]) => {
            const merged = AmapService.mergePoiResults(nearby, nationwide, safeLimit);
            AmapService.writePoiCache(cacheKey, merged);
          })
          .catch((_error: Error) => {
          });
        return slicedNearby;
      }

      const nationwide = await AmapService.searchPoiBySdk(context, trimmed, centerLat, centerLng, safeLimit, false);
      const merged = AmapService.mergePoiResults(nearby, nationwide, safeLimit);
      AmapService.writePoiCache(cacheKey, merged);
      return merged;
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][searchPoi] sdk failed, error=${JSON.stringify(error)}`);
      try {
        const fallback = await AmapService.searchPoiWithWebFallback(trimmed, centerLat, centerLng, safeLimit);
        AmapService.writePoiCache(cacheKey, fallback);
        if (AmapService.isSdkMd5AuthError(error)) {
          hilog.warn(
            0x0000,
            AmapService.TAG,
            `[AMAP_TRACE][searchPoi] sdk_auth_1008_fallback_web resolved=${fallback.length}`
          );
        } else {
          hilog.warn(
            0x0000,
            AmapService.TAG,
            `[AMAP_TRACE][searchPoi] sdk_failed_fallback_web resolved=${fallback.length}`
          );
        }
        return fallback;
      } catch (fallbackError) {
        hilog.error(
          0x0000,
          AmapService.TAG,
          `[AMAP_TRACE][searchPoi] web fallback failed, error=${JSON.stringify(fallbackError)}`
        );
        return [];
      }
    }
  }

  private static getListSize(listObj: Object | undefined): number {
    if (!listObj) {
      return 0;
    }
    const dynamicList = listObj as GenericListLike;
    if (typeof dynamicList.length === 'number' && Number.isFinite(dynamicList.length)) {
      return dynamicList.length;
    }
    if (typeof dynamicList.size === 'number' && Number.isFinite(dynamicList.size)) {
      return dynamicList.size;
    }
    if (typeof dynamicList.size === 'function') {
      const size = dynamicList.size();
      if (Number.isFinite(size)) {
        return size;
      }
    }
    return 0;
  }

  private static getListItem<T>(listObj: Object | undefined, index: number): T | undefined {
    if (!listObj || index < 0) {
      return undefined;
    }
    const dynamicList = listObj as GenericListGetter<T>;
    if (typeof dynamicList.get === 'function') {
      return dynamicList.get(index);
    }
    return undefined;
  }

  private static async getGeocodeBySdkKeyword(
    address: string,
    context: common.Context
  ): Promise<GeoCoordinate | null> {
    try {
      const query = new PoiQuery(address, '', '');
      query.setPageNum(1);
      query.setPageSize(5);
      query.setCityLimit(false);
      query.setExtensions(PoiSearch.EXTENSIONS_BASE);
      const search = new PoiSearch(context, query);
      const result = await search.searchPOI();
      const resolved = AmapService.extractPoiItems(result);
      if (resolved.length <= 0) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode_sdk] empty_result');
        return null;
      }
      const top = resolved[0];
      if (!AmapService.isValidCoordinate(top.lat, top.lng)) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode_sdk] invalid_top_coordinate');
        return null;
      }
      hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode_sdk] resolve success');
      return new GeoCoordinate(top.lat, top.lng);
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getGeocode_sdk] failed, error=${JSON.stringify(error)}`);
      return null;
    }
  }

  private static async getGeocodeBySdkGeoSearch(
    address: string,
    context: common.Context
  ): Promise<GeoCoordinate | null> {
    try {
      const query = new GeocodeQuery(address, '');
      const search = new GeocodeSearch(context);
      const list = await search.getFromLocationName(query);
      const size = AmapService.getListSize(list);
      if (size <= 0) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode_sdk_geo] empty_result');
        return null;
      }
      const first = AmapService.getListItem<LatLonPointCarrier>(list, 0);
      const point = first?.getLatLonPoint();
      const lat = point?.getLatitude() ?? Number.NaN;
      const lng = point?.getLongitude() ?? Number.NaN;
      if (!AmapService.isValidCoordinate(lat, lng)) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode_sdk_geo] invalid_coordinate');
        return null;
      }
      hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getGeocode_sdk_geo] resolve success');
      return new GeoCoordinate(lat, lng);
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getGeocode_sdk_geo] failed, error=${JSON.stringify(error)}`);
      return null;
    }
  }

  public static async getGeocode(address: string, context?: common.Context | null): Promise<GeoCoordinate | null> {
    const effectiveContext = context ?? AmapService.getRuntimeContext();
    if (effectiveContext) {
      const sdkGeoResult = await AmapService.getGeocodeBySdkGeoSearch(address, effectiveContext);
      if (sdkGeoResult && AmapService.isValidCoordinate(sdkGeoResult.lat, sdkGeoResult.lng)) {
        return sdkGeoResult;
      }
      const sdkKeywordResult = await AmapService.getGeocodeBySdkKeyword(address, effectiveContext);
      if (sdkKeywordResult && AmapService.isValidCoordinate(sdkKeywordResult.lat, sdkKeywordResult.lng)) {
        return sdkKeywordResult;
      }
    }
    const webResult = await AmapService.getGeocodeByWeb(address);
    if (webResult && AmapService.isValidCoordinate(webResult.lat, webResult.lng)) {
      return webResult;
    }
    return null;
  }

  public static async getDrivingDurationByWebApi(
    fromLat: number,
    fromLng: number,
    toLat: number,
    toLng: number,
    strategy: number = 0
  ): Promise<number | null> {
    if (!AmapService.isValidCoordinate(fromLat, fromLng) || !AmapService.isValidCoordinate(toLat, toLng)) {
      hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][route_web] invalid coordinate, skip request');
      return null;
    }
    try {
      AppConfig.validateAmapWebConfig();
      const safeStrategy = Number.isFinite(strategy) ? Math.max(0, Math.floor(strategy)) : 0;
      const url =
        `https://restapi.amap.com/v3/direction/driving?key=${AppConfig.AMAP_WEB_API_KEY}` +
        `&origin=${fromLng},${fromLat}` +
        `&destination=${toLng},${toLat}` +
        `&strategy=${safeStrategy}`;
      const response = await HttpRequestHelper.request(AmapService.TAG, 'getDrivingDurationByWebApi', url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      if (response.responseCode !== 200) {
        hilog.warn(0x0000, AmapService.TAG, `[AMAP_TRACE][route_web] non-200 responseCode=${response.responseCode}`);
        return null;
      }
      const payload = JSON.parse(String(response.result ?? '')) as AmapDrivingRouteResponse;
      if (payload.status !== '1') {
        hilog.warn(
          0x0000,
          AmapService.TAG,
          `[AMAP_TRACE][route_web] business miss status=${payload.status}, info=${payload.info ?? ''}, infocode=${payload.infocode ?? ''}`
        );
        if (payload.infocode === '10009') {
          hilog.error(0x0000, AmapService.TAG, '[AMAP_TRACE][route_web] USERKEY_PLAT_NOMATCH: 请替换为高德Web服务Key');
        }
        return null;
      }
      const durationRaw = payload.route?.paths && payload.route.paths.length > 0
        ? payload.route.paths[0].duration
        : undefined;
      if (!durationRaw) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][route_web] empty path duration');
        return null;
      }
      const durationSeconds = Number.parseInt(durationRaw, 10);
      if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) {
        hilog.warn(0x0000, AmapService.TAG, `[AMAP_TRACE][route_web] invalid duration=${durationRaw}`);
        return null;
      }
      const minutes = Math.max(1, Math.ceil(durationSeconds / 60));
      hilog.info(0x0000, AmapService.TAG, `[AMAP_TRACE][route_web] success minutes=${minutes}`);
      return minutes;
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][route_web] failed, error=${JSON.stringify(error)}`);
      return null;
    }
  }

  public static async getCityCodeByCoordinate(lat: number, lng: number): Promise<string | null> {
    if (lat === 0 || lng === 0) {
      hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getCityCodeByCoordinate] invalid coordinate, skip request');
      return null;
    }

    const boundContext = AmapService.getRuntimeContext();
    if (boundContext) {
      const sdkCity = await AmapService.getCityCodeBySdkGeoSearch(boundContext, lat, lng);
      if (sdkCity && sdkCity.trim().length > 0) {
        return sdkCity;
      }
    }

    try {
      AppConfig.validateAmapWebConfig();
      const url =
        `https://restapi.amap.com/v3/geocode/regeo?location=${lng},${lat}` +
        `&key=${AppConfig.AMAP_WEB_API_KEY}&extensions=base`;

      const response = await HttpRequestHelper.request(AmapService.TAG, 'getCityCodeByCoordinate', url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });

      if (response.responseCode === 200) {
        const resultData = JSON.parse(response.result as string) as AmapRegeoResponse;
        const adCode = resultData.regeocode?.addressComponent?.adcode?.trim() ?? '';
        const cityCode = resultData.regeocode?.addressComponent?.citycode?.trim() ?? '';
        const weatherCity = adCode.length > 0 ? adCode : cityCode;

        if (resultData.status === '1' && weatherCity.length > 0) {
          hilog.info(0x0000, AmapService.TAG, `[AMAP_TRACE][getCityCodeByCoordinate] resolve success weatherCity=${weatherCity}, adCode=${adCode}, cityCode=${cityCode}`);
          return weatherCity;
        }

        hilog.warn(
          0x0000,
          AmapService.TAG,
          `[AMAP_TRACE][getCityCodeByCoordinate] business miss, status=${resultData.status}, info=${resultData.info ?? ''}, infocode=${resultData.infocode ?? ''}, adCode=${adCode}, cityCode=${cityCode}`
        );
      } else {
        hilog.warn(
          0x0000,
          AmapService.TAG,
          `[AMAP_TRACE][getCityCodeByCoordinate] non-200 responseCode=${response.responseCode}`
        );
      }
    } catch (error) {
      hilog.error(
        0x0000,
        AmapService.TAG,
        `[AMAP_TRACE][getCityCodeByCoordinate] failed, error=${JSON.stringify(error)}`
      );
    }

    return null;
  }

  private static async getCityCodeBySdkGeoSearch(
    context: common.Context,
    lat: number,
    lng: number
  ): Promise<string | null> {
    try {
      const search = new GeocodeSearch(context);
      const query = new ReGeocodeQuery(
        new LatLonPoint(lat, lng),
        300,
        GeocodeSearch.AMAP
      );
      query.setExtensions(GeocodeSearch.EXTENSIONS_BASE);
      const result = await search.getFromLocation(query);
      if (!result) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getCityCode_sdk_geo] empty_result');
        return null;
      }
      const adCode = (result.getAdCode() ?? '').trim();
      const cityCode = (result.getCityCode() ?? '').trim();
      const resolved = adCode.length > 0 ? adCode : cityCode;
      if (resolved.length <= 0) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getCityCode_sdk_geo] empty_city_code');
        return null;
      }
      hilog.info(0x0000, AmapService.TAG, `[AMAP_TRACE][getCityCode_sdk_geo] success city=${resolved}`);
      return resolved;
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getCityCode_sdk_geo] failed, error=${JSON.stringify(error)}`);
      return null;
    }
  }

  public static async getRegeo(lat: number, lng: number): Promise<string | null> {
    if (lat === 0 || lng === 0) {
      hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo] invalid coordinate, skip request');
      return null;
    }

    try {
      AppConfig.validateAmapWebConfig();
      const url =
        `https://restapi.amap.com/v3/geocode/regeo?location=${lng},${lat}` +
        `&key=${AppConfig.AMAP_WEB_API_KEY}&extensions=all`;

      const response = await HttpRequestHelper.request(AmapService.TAG, 'getRegeo', url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });

      if (response.responseCode === 200) {
        const resultData = JSON.parse(response.result as string) as AmapRegeoResponse;

        if (resultData.status === '1' && resultData.regeocode) {
          if (resultData.regeocode.pois && resultData.regeocode.pois.length > 0) {
            hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo] resolve poi success');
            return resultData.regeocode.pois[0].name;
          }
          if (resultData.regeocode.formatted_address) {
            hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo] resolve address success');
            return resultData.regeocode.formatted_address;
          }
        }

        hilog.warn(
          0x0000,
          AmapService.TAG,
          `[AMAP_TRACE][getRegeo] business miss, status=${resultData.status}, info=${resultData.info ?? ''}, infocode=${resultData.infocode ?? ''}`
        );
        if (resultData.infocode === '10009') {
          hilog.error(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo] USERKEY_PLAT_NOMATCH: 请替换为高德Web服务Key');
        }
      } else {
        hilog.warn(0x0000, AmapService.TAG, `[AMAP_TRACE][getRegeo] non-200 responseCode=${response.responseCode}`);
      }
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getRegeo] failed, error=${JSON.stringify(error)}`);
    }

    return null;
  }

  private static async getRegeoBySdkNearby(context: common.Context, lat: number, lng: number): Promise<string | null> {
    try {
      const center = new LatLonPoint(lat, lng);
      const query = new PoiQuery('', '', '');
      query.setPageNum(1);
      query.setPageSize(10);
      query.setLocation(center);
      query.setDistanceSort(true);
      query.setExtensions(PoiSearch.EXTENSIONS_BASE);

      const search = new PoiSearch(context, query);
      const bound = PoiSearchBound.createCircleSearchBound(center, 500, true);
      search.setBound(bound);
      const result = await search.searchPOI();
      const resolved = AmapService.extractPoiItems(result);
      if (resolved.length <= 0) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo_sdk] empty_result');
        return null;
      }
      const top = resolved[0];
      const name = (top.name ?? '').trim();
      if (name.length <= 0) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo_sdk] top_name_empty');
        return null;
      }
      hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo_sdk] resolve poi success');
      return name;
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getRegeo_sdk] failed, error=${JSON.stringify(error)}`);
      return null;
    }
  }

  private static async getRegeoBySdkGeoSearch(context: common.Context, lat: number, lng: number): Promise<string | null> {
    try {
      const search = new GeocodeSearch(context);
      const query = new ReGeocodeQuery(
        new LatLonPoint(lat, lng),
        300,
        GeocodeSearch.AMAP
      );
      query.setExtensions(GeocodeSearch.EXTENSIONS_ALL);
      const result = await search.getFromLocation(query);
      if (!result) {
        hilog.warn(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo_sdk_geo] empty_result');
        return null;
      }
      const pois = result.getPois();
      const poiSize = AmapService.getListSize(pois);
      if (poiSize > 0) {
        const topPoi = AmapService.getListItem<PoiTitleCarrier>(pois, 0);
        const title = (topPoi?.getTitle() ?? '').trim();
        if (title.length > 0) {
          hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo_sdk_geo] resolve poi success');
          return title;
        }
      }
      const formatted = (result.getFormatAddress() ?? '').trim();
      if (formatted.length > 0) {
        hilog.info(0x0000, AmapService.TAG, '[AMAP_TRACE][getRegeo_sdk_geo] resolve address success');
        return formatted;
      }
      return null;
    } catch (error) {
      hilog.error(0x0000, AmapService.TAG, `[AMAP_TRACE][getRegeo_sdk_geo] failed, error=${JSON.stringify(error)}`);
      return null;
    }
  }

  public static async getRegeoWithSdkFallback(
    lat: number,
    lng: number,
    context?: common.Context | null
  ): Promise<string | null> {
    if (context) {
      const sdkGeo = await AmapService.getRegeoBySdkGeoSearch(context, lat, lng);
      if (sdkGeo && sdkGeo.trim().length > 0) {
        return sdkGeo;
      }
    }
    const webResult = await AmapService.getRegeo(lat, lng);
    if (webResult && webResult.trim().length > 0) {
      return webResult;
    }
    if (!context) {
      return null;
    }
    return AmapService.getRegeoBySdkNearby(context, lat, lng);
  }
}
