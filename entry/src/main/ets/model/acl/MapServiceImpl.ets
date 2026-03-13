import {
  RouteSearchV2,
  RouteSearch,
  DriveRouteQueryV2,
  LatLonPoint,
  FromAndTo
} from '@amap/amap_lbs_search';
import { IMapService, LocationInfo, DriveStrategy } from '../interface/IMapService';
import { BusinessError } from '@kit.BasicServicesKit';
import ArrayList from '@ohos.util.ArrayList';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { AmapService, GeoCoordinate } from '../../common/utils/AmapService';
import { hilog } from '@kit.PerformanceAnalysisKit';

import {
  WalkRouteQueryV2,
  RideRouteQueryV2,
  BusRouteQueryV2,
} from '@amap/amap_lbs_search';

class ResolvedCoordinate {
  lat: number;
  lng: number;
  source: string;
  keyword: string;

  constructor(lat: number, lng: number, source: string, keyword: string) {
    this.lat = lat;
    this.lng = lng;
    this.source = source;
    this.keyword = keyword;
  }
}

class ResolvedRouteEndpoints {
  fromLat: number;
  fromLng: number;
  toLat: number;
  toLng: number;
  ok: boolean;

  constructor(fromLat: number, fromLng: number, toLat: number, toLng: number, ok: boolean) {
    this.fromLat = fromLat;
    this.fromLng = fromLng;
    this.toLat = toLat;
    this.toLng = toLng;
    this.ok = ok;
  }
}

interface MapServiceTestHooks {
  routeApiEnabledResolver?: () => Promise<boolean>;
  geocodeResolver?: (address: string) => Promise<GeoCoordinate | null>;
  cityCodeResolver?: (lat: number, lng: number) => Promise<string | null>;
  modeSecondsResolver?: (
    mode: number,
    fromLat: number,
    fromLng: number,
    toLat: number,
    toLng: number,
    startTime: string
  ) => Promise<number>;
}

export class MapServiceImpl implements IMapService {
  private static readonly TAG = 'MapServiceImpl';
  private static readonly GEO_FIX_PREFIX = '[ROUTE_GEO_FIX]';
  private static testHooks: MapServiceTestHooks | null = null;

  public static setTestHooks(hooks: MapServiceTestHooks | null): void {
    MapServiceImpl.testHooks = hooks;
  }

  private routeSearch: RouteSearchV2 | null = null;
  private context: common.Context | null;

  constructor(context: common.Context | null) {
    this.context = context;
  }

  private sanitizeError(error: Object): string {
    if (error instanceof Error && typeof error.message === 'string' && error.message.length > 0) {
      return error.message;
    }
    return 'unknown_error';
  }

  private maskCoordinate(value: number): string {
    if (!Number.isFinite(value)) {
      return 'nan';
    }
    return value.toFixed(2);
  }

  private calculateAirDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371000;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lng2 - lng1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
  }

  private reportRouteApiFailure(message: string): void {
    console.error(`[MapService] ${message}`);
    try {
      promptAction.showToast({ message });
    } catch (e) {
      console.error(`[MapService] Toast 显示失败: ${this.sanitizeError(e)}`);
    }
  }

  private fallbackDurationWithError(message: string): number {
    this.reportRouteApiFailure(message);
    return 60;
  }

  private isValidCoordinate(lat: number, lng: number): boolean {
    return Number.isFinite(lat) && Number.isFinite(lng) && lat !== 0 && lng !== 0;
  }

  private pickLocationKeyword(location: LocationInfo): string {
    const address = location.address?.trim() ?? '';
    if (address.length > 0) {
      return address;
    }
    return location.name?.trim() ?? '';
  }

  private async resolveCoordinate(
    location: LocationInfo,
    role: 'origin' | 'destination'
  ): Promise<ResolvedCoordinate> {
    const rawLat = location.latitude ?? 0;
    const rawLng = location.longitude ?? 0;

    if (this.isValidCoordinate(rawLat, rawLng)) {
      hilog.info(
        0x0000,
        MapServiceImpl.TAG,
        `${MapServiceImpl.GEO_FIX_PREFIX}[coord] role=${role} source=input lat=${this.maskCoordinate(rawLat)} lng=${this.maskCoordinate(rawLng)}`
      );
      return new ResolvedCoordinate(rawLat, rawLng, 'input', '');
    }

    const keyword = this.pickLocationKeyword(location);
    if (!keyword) {
      hilog.warn(
        0x0000,
        MapServiceImpl.TAG,
        `${MapServiceImpl.GEO_FIX_PREFIX}[coord] role=${role} source=invalid reason=empty_keyword`
      );
      return new ResolvedCoordinate(rawLat, rawLng, 'invalid', '');
    }

    hilog.info(
      0x0000,
      MapServiceImpl.TAG,
      `${MapServiceImpl.GEO_FIX_PREFIX}[coord] role=${role} source=geocode_start keyword_len=${keyword.length}`
    );
    const hook = MapServiceImpl.testHooks?.geocodeResolver;
    const geocode = hook ? await hook(keyword) : await AmapService.getGeocode(keyword);
    if (geocode && this.isValidCoordinate(geocode.lat, geocode.lng)) {
      location.latitude = geocode.lat;
      location.longitude = geocode.lng;
      hilog.info(
        0x0000,
        MapServiceImpl.TAG,
        `${MapServiceImpl.GEO_FIX_PREFIX}[coord] role=${role} source=geocode_success lat=${this.maskCoordinate(geocode.lat)} lng=${this.maskCoordinate(geocode.lng)}`
      );
      return new ResolvedCoordinate(geocode.lat, geocode.lng, 'geocode', keyword);
    }

    hilog.warn(
      0x0000,
      MapServiceImpl.TAG,
      `${MapServiceImpl.GEO_FIX_PREFIX}[coord] role=${role} source=invalid reason=geocode_miss keyword_len=${keyword.length}`
    );
    return new ResolvedCoordinate(rawLat, rawLng, 'invalid', keyword);
  }

  private async resolveRouteEndpoints(
    origin: LocationInfo,
    destination: LocationInfo
  ): Promise<ResolvedRouteEndpoints> {
    const fromResolved = await this.resolveCoordinate(origin, 'origin');
    const toResolved = await this.resolveCoordinate(destination, 'destination');

    const ok =
      this.isValidCoordinate(fromResolved.lat, fromResolved.lng) &&
      this.isValidCoordinate(toResolved.lat, toResolved.lng);

    hilog.info(
      0x0000,
      MapServiceImpl.TAG,
      `${MapServiceImpl.GEO_FIX_PREFIX}[coord] origin=${fromResolved.source} destination=${toResolved.source} ok=${ok}`
    );

    return new ResolvedRouteEndpoints(fromResolved.lat, fromResolved.lng, toResolved.lat, toResolved.lng, ok);
  }

  private async canUseAmapRouteApi(): Promise<boolean> {
    if (MapServiceImpl.testHooks?.routeApiEnabledResolver) {
      return MapServiceImpl.testHooks.routeApiEnabledResolver();
    }
    try {
      const pref = PreferenceManager.getInstance();
      const enabled = await pref.isAmapRouteApiEnabled();
      console.info(`[AMAP_SWITCH] enableAmapRouteApi = ${enabled}`);
      return enabled;
    } catch (error) {
      console.error(`[AMAP_SWITCH] read failed: ${this.sanitizeError(error)}`);
      this.reportRouteApiFailure('高德路线开关读取失败，已按 60 分钟处理');
      return false;
    }
  }

  async getDurationByMode(origin: LocationInfo, destination: LocationInfo, mode: number, startTime?: string): Promise<number> {
    hilog.info(
      0x0000,
      MapServiceImpl.TAG,
      `${MapServiceImpl.GEO_FIX_PREFIX}[route] mode=${mode} startTime=${startTime ?? ''} from_len=${origin.name?.length ?? 0} to_len=${destination.name?.length ?? 0}`
    );

    const routeApiEnabled = await this.canUseAmapRouteApi();
    if (!routeApiEnabled) {
      this.reportRouteApiFailure('高德路线 API 已关闭，已按 60 分钟处理');
      return 60;
    }

    const resolved = await this.resolveRouteEndpoints(origin, destination);
    if (!resolved.ok) {
      return this.fallbackDurationWithError('高德路线计算失败：坐标无效且补偿失败，已按 60 分钟处理');
    }

    const fromLat = resolved.fromLat;
    const fromLng = resolved.fromLng;
    const toLat = resolved.toLat;
    const toLng = resolved.toLng;

    try {
      if (MapServiceImpl.testHooks?.modeSecondsResolver) {
        const hookSeconds = await MapServiceImpl.testHooks.modeSecondsResolver(
          mode,
          fromLat,
          fromLng,
          toLat,
          toLng,
          startTime ?? ''
        );
        if (hookSeconds > 0) {
          return Math.ceil(hookSeconds / 60);
        }
        return this.fallbackDurationWithError('高德路线计算无有效结果，已按 60 分钟处理');
      }

      const fromAndTo = new FromAndTo(new LatLonPoint(fromLat, fromLng), new LatLonPoint(toLat, toLng));
      let seconds = 0;

      if (mode === 0 || mode === 4) {
        const search = this.getSearch();
        if (mode === 0) {
          const distance = this.calculateAirDistance(fromLat, fromLng, toLat, toLng);
          if (distance > 5000) return -5;
        }
        const res = await search.calculateWalkRoute(new WalkRouteQueryV2(fromAndTo));
        if (res.getPaths()?.length > 0) {
          seconds = res.getPaths()[0].getDuration();
        }
      } else if (mode === 1) {
        const search = this.getSearch();
        const res = await search.calculateRideRoute(new RideRouteQueryV2(fromAndTo));
        if (res.getPaths()?.length > 0) {
          seconds = res.getPaths()[0].getDuration();
        }
      } else if (mode === 3) {
        const cityCodeResolver = MapServiceImpl.testHooks?.cityCodeResolver;
        const originCityCode = cityCodeResolver
          ? await cityCodeResolver(fromLat, fromLng)
          : await AmapService.getCityCodeByCoordinate(fromLat, fromLng);
        const destinationCityCode = cityCodeResolver
          ? await cityCodeResolver(toLat, toLng)
          : await AmapService.getCityCodeByCoordinate(toLat, toLng);
        const city = originCityCode ?? destinationCityCode ?? '';
        const cityd = destinationCityCode ?? originCityCode ?? city;

        hilog.info(
          0x0000,
          MapServiceImpl.TAG,
          `[BUS_CITY_FIX] mode=3 originCity=${originCityCode ?? 'null'} destinationCity=${destinationCityCode ?? 'null'} city=${city} cityd=${cityd}`
        );

        if (!city || !cityd) {
          return this.fallbackDurationWithError('高德公交路线计算失败：城市编码缺失，已按 60 分钟处理');
        }

        const search = this.getSearch();
        const query = new BusRouteQueryV2(fromAndTo, 0, city, 0);
        query.setCityd(cityd);

        const res = await search.calculateBusRoute(query);
        if (!res.getPaths() || res.getPaths().length === 0) {
          return this.fallbackDurationWithError('高德公交路线为空，已按 60 分钟处理');
        }

        const firstPath = res.getPaths()[0];
        seconds = firstPath.getDuration();
      } else {
        const search = this.getSearch();
        const emptyPoiList = new ArrayList<LatLonPoint>();
        const emptyPolygonList = new ArrayList<ArrayList<LatLonPoint>>();

        const query = new DriveRouteQueryV2(fromAndTo, 0, emptyPoiList, emptyPolygonList, "");
        const res = await search.calculateDriveRoute(query);

        if (res.getPaths()?.length > 0) {
          const firstPath = res.getPaths()[0];
          seconds = firstPath.getDuration();

          if (seconds === 0 && firstPath.getCost) {
            const costObj = firstPath.getCost();
            if (costObj && typeof costObj.getDuration === 'function') {
              seconds = costObj.getDuration();
            }
          }
        }
      }

      console.info(`[AMAP_RESULT] Mode: ${mode}, 最终秒数: ${seconds}s`);
      hilog.info(0x0000, MapServiceImpl.TAG, `${MapServiceImpl.GEO_FIX_PREFIX}[result] mode=${mode} seconds=${seconds}`);

      if (seconds > 0) {
        return Math.ceil(seconds / 60);
      }

      return this.fallbackDurationWithError('高德路线计算无有效结果，已按 60 分钟处理');
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[MapService] 高德抓取崩溃! Mode: ${mode}, ErrorCode: ${err?.code}, Msg: ${err?.message}`);
      hilog.error(
        0x0000,
        MapServiceImpl.TAG,
        `${MapServiceImpl.GEO_FIX_PREFIX}[error] mode=${mode} code=${err?.code} msg=${err?.message}`
      );
      return this.fallbackDurationWithError('高德路线请求失败，已按 60 分钟处理');
    }
  }

  private getSearch(): RouteSearchV2 {
    if (!this.routeSearch) {
      if (!this.context) {
        throw new Error('context_unavailable');
      }
      this.routeSearch = new RouteSearchV2(this.context);
    }
    return this.routeSearch;
  }

  async getDriveDuration(origin: LocationInfo, destination: LocationInfo, strategy: DriveStrategy): Promise<number> {
    console.info(`[AMAP_TEST] 准备计算路程: [${origin.name}] -> [${destination.name}]`);
    console.info(`[AMAP_TEST] 原始坐标(脱敏): 起点(${this.maskCoordinate(origin.latitude ?? 0)}, ${this.maskCoordinate(origin.longitude ?? 0)}) 终点(${this.maskCoordinate(destination.latitude ?? 0)}, ${this.maskCoordinate(destination.longitude ?? 0)})`);
    hilog.info(
      0x0000,
      MapServiceImpl.TAG,
      `${MapServiceImpl.GEO_FIX_PREFIX}[drive] strategy=${strategy} from_len=${origin.name?.length ?? 0} to_len=${destination.name?.length ?? 0}`
    );

    const routeApiEnabled = await this.canUseAmapRouteApi();
    if (!routeApiEnabled) {
      this.reportRouteApiFailure('高德路线 API 已关闭，已按 60 分钟处理');
      return 60;
    }

    const resolved = await this.resolveRouteEndpoints(origin, destination);
    if (!resolved.ok) {
      return this.fallbackDurationWithError('高德驾车路线计算失败：坐标无效且补偿失败，已按 60 分钟处理');
    }

    const fromLat: number = resolved.fromLat;
    const fromLng: number = resolved.fromLng;
    const toLat: number = resolved.toLat;
    const toLng: number = resolved.toLng;

    const fromPoint = new LatLonPoint(fromLat, fromLng);
    const toPoint = new LatLonPoint(toLat, toLng);
    const fromAndTo = new FromAndTo(fromPoint, toPoint);

    let amapMode: number = RouteSearch.DRIVING_SINGLE_DEFAULT;
    if (strategy === DriveStrategy.AVOID_CONGESTION) {
      amapMode = RouteSearch.DRIVING_SINGLE_AVOID_CONGESTION;
    } else if (strategy === DriveStrategy.ECONOMICAL) {
      amapMode = RouteSearch.DRIVING_SINGLE_SAVE_MONEY;
    }

    const query = new DriveRouteQueryV2(fromAndTo, amapMode, undefined, undefined, "");

    try {
      const result = await this.getSearch().calculateDriveRoute(query);
      const paths = result.getPaths();

      if (paths !== null && paths.length > 0) {
        const firstPath = paths[0];
        let seconds = firstPath.getDuration();

        if (seconds === 0 && firstPath.getCost) {
          const costObj = firstPath.getCost();
          console.info(`[AMAP_TEST] 探测 Cost 对象: ${JSON.stringify(costObj)}`);
          if (costObj && typeof costObj.getDuration === 'function') {
            seconds = costObj.getDuration();
          }
        }

        console.info(`[AMAP_RESULT] 最终秒数: ${seconds}s, 转换分钟: ${Math.ceil(seconds / 60)}min`);
        hilog.info(
          0x0000,
          MapServiceImpl.TAG,
          `${MapServiceImpl.GEO_FIX_PREFIX}[result] mode=drive strategy=${strategy} seconds=${seconds}`
        );

        if (seconds > 0) {
          return Math.ceil(seconds / 60);
        }
      }

      return this.fallbackDurationWithError('高德驾车路线无有效结果，已按 60 分钟处理');
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[AMAP_ERROR] 调用失败: ${err.code}, ${err.message}`);
      hilog.error(
        0x0000,
        MapServiceImpl.TAG,
        `${MapServiceImpl.GEO_FIX_PREFIX}[error] mode=drive strategy=${strategy} code=${err?.code} msg=${err?.message}`
      );
      return this.fallbackDurationWithError('高德驾车路线请求失败，已按 60 分钟处理');
    }
  }

  async getLocationInfo(keyword: string): Promise<LocationInfo[]> { return []; }
  async calculateCommute(from: string, to: string): Promise<number> { return 30; }
}




