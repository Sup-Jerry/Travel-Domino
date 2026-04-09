// path: infrastructure/services/TrafficEngine.ets
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { IMapService, LocationInfo, DriveStrategy } from '../../model/interface/IMapService';
import { MapServiceImpl } from '../../model/acl/MapServiceImpl';
import { DomainConstants } from '../../common/constants/DomainConstants';

const TAG = 'TrafficEngine';
const ROUTE_GEO_FIX_PREFIX = '[ROUTE_GEO_FIX]';
const CACHE_GUARD_PREFIX = '[CACHE_GUARD]';
const ROUTE_DIAG_PREFIX = '[ROUTE_DIAG]';

export class TrafficEngine {
  private static instance: TrafficEngine;
  private static readonly FALLBACK_MINUTES: number = 60;
  private static readonly TRANSIENT_FAILURE_TTL_MS: number = 15 * 1000;
  private static readonly TRAFFIC_SIGNAL_DEBOUNCE_MS: number = 350;

  // 由 EntryAbility 注入的长生命周期服务实例
  private mapService: IMapService | null = null;

  // 内存缓存: "FromName->ToName_Strategy" => 分钟数
  private cache: Map<string, number> = new Map();

  // 失败保护窗口（避免瞬时网络抖动导致请求风暴）
  private transientFailureUntil: Map<string, number> = new Map();
  private trafficSignalTimer: number = -1;

  private constructor() {}

  private isValidCoordinate(lat?: number, lng?: number): boolean {
    return Number.isFinite(lat ?? NaN) &&
      Number.isFinite(lng ?? NaN) &&
      (lat ?? 0) !== 0 &&
      (lng ?? 0) !== 0;
  }

  private buildRouteCacheKey(from: LocationInfo, to: LocationInfo, mode: number): string {
    const fromCoord = this.isValidCoordinate(from.latitude, from.longitude)
      ? `${(from.latitude as number).toFixed(5)},${(from.longitude as number).toFixed(5)}`
      : 'NOCOORD';
    const toCoord = this.isValidCoordinate(to.latitude, to.longitude)
      ? `${(to.latitude as number).toFixed(5)},${(to.longitude as number).toFixed(5)}`
      : 'NOCOORD';
    return `${from.name}->${to.name}_M${mode}_F${fromCoord}_T${toCoord}`;
  }

  public static getInstance(): TrafficEngine {
    if (!TrafficEngine.instance) {
      TrafficEngine.instance = new TrafficEngine();
    }
    return TrafficEngine.instance;
  }

  public initialize(context: common.Context): void {
    if (this.mapService) {
      hilog.info(0x0000, TAG, '[LIFECYCLE_GUARD] initialize skipped: already initialized.');
      return;
    }
    this.mapService = new MapServiceImpl(context);
    hilog.info(0x0000, TAG, '[LIFECYCLE_GUARD] initialized with long-lived Ability/Application context.');
  }

  private markTransientFailure(key: string, reason: string): void {
    const until = Date.now() + TrafficEngine.TRANSIENT_FAILURE_TTL_MS;
    this.transientFailureUntil.set(key, until);
    hilog.warn(
      0x0000,
      TAG,
      `${CACHE_GUARD_PREFIX} transient_failure key=${key} reason=${reason} ttl_ms=${TrafficEngine.TRANSIENT_FAILURE_TTL_MS}`
    );
  }

  private clearTransientFailure(key: string): void {
    if (this.transientFailureUntil.has(key)) {
      this.transientFailureUntil.delete(key);
      hilog.info(0x0000, TAG, `${CACHE_GUARD_PREFIX} transient_failure_cleared key=${key}`);
    }
  }

  private emitTrafficDataUpdated(): void {
    if (this.trafficSignalTimer > 0) {
      clearTimeout(this.trafficSignalTimer);
    }
    this.trafficSignalTimer = setTimeout(() => {
      this.trafficSignalTimer = -1;
      AppStorage.setOrCreate('TrafficDataUpdated', Date.now());
    }, TrafficEngine.TRAFFIC_SIGNAL_DEBOUNCE_MS) as number;
  }

  /**
   * 获取路程时间
   * @param from 起点信息
   * @param to 终点信息
   * @param mode 出行模式
   */
  public getCommuteMinutes(from: LocationInfo, to: LocationInfo, mode: number = 0, startTime?: string): number {
    if (!from.name || !to.name) {
      hilog.warn(
        0x0000,
        TAG,
        `${ROUTE_DIAG_PREFIX}[entry] skip_empty_name mode=${mode} from_len=${from.name?.length ?? 0} to_len=${to.name?.length ?? 0}`
      );
      return 0;
    }

    if (!this.mapService) {
      hilog.warn(0x0000, TAG, '[LIFECYCLE_GUARD] map service not initialized. Fallback to 60 minutes.');
      return TrafficEngine.FALLBACK_MINUTES;
    }

    const key = this.buildRouteCacheKey(from, to, mode);
    const fromCoordValid = this.isValidCoordinate(from.latitude, from.longitude);
    const toCoordValid = this.isValidCoordinate(to.latitude, to.longitude);
    hilog.info(
      0x0000,
      TAG,
      `${ROUTE_DIAG_PREFIX}[entry] key=${key} mode=${mode} startTime=${startTime ?? ''} from_coord=${fromCoordValid} to_coord=${toCoordValid}`
    );
    const now = Date.now();
    const blockedUntil = this.transientFailureUntil.get(key) ?? 0;

    if (blockedUntil > now) {
      hilog.warn(0x0000, TAG, `${CACHE_GUARD_PREFIX} transient_hit key=${key} remain_ms=${blockedUntil - now}`);
      return TrafficEngine.FALLBACK_MINUTES;
    }

    if (blockedUntil > 0) {
      this.transientFailureUntil.delete(key);
    }

    if (this.cache.has(key)) {
      const val = this.cache.get(key);
      if (val === -1) {
        hilog.info(0x0000, TAG, `${ROUTE_DIAG_PREFIX}[cache] loading_hit key=${key}`);
        return -2;
      }

      // 兼容旧版本遗留的毒缓存值
      if (val === DomainConstants.COMMUTE_FALLBACK_UNKNOWN) {
        this.cache.delete(key);
        hilog.warn(
          0x0000,
          TAG,
          `${CACHE_GUARD_PREFIX} legacy_dirty_cache_evicted key=${key} value=${DomainConstants.COMMUTE_FALLBACK_UNKNOWN}`
        );
      } else {
        hilog.info(0x0000, TAG, `${ROUTE_DIAG_PREFIX}[cache] value_hit key=${key} value=${val ?? 0}`);
        return val ?? 0;
      }
    }

    hilog.info(0x0000, TAG, `${ROUTE_DIAG_PREFIX}[cache] miss key=${key} trigger_async=true`);
    this.fetchMultiModalTrafficAsync(from, to, mode, key, startTime);
    return -2;
  }

  private async fetchMultiModalTrafficAsync(
    from: LocationInfo,
    to: LocationInfo,
    mode: number,
    key: string,
    startTime?: string
  ) {
    if (this.cache.get(key) === -1) return;
    this.cache.set(key, -1);

    try {
      if (!this.mapService) {
        this.cache.delete(key);
        this.markTransientFailure(key, 'service_unavailable');
        this.emitTrafficDataUpdated();
        hilog.warn(0x0000, TAG, '[LIFECYCLE_GUARD] async fetch skipped: service unavailable.');
        return;
      }

      hilog.info(0x0000, TAG, `${ROUTE_GEO_FIX_PREFIX}[engine] fetch_start key=${key} mode=${mode}`);
      const duration = await this.mapService.getDurationByMode(from, to, mode, startTime);
      const fromCoordValid = this.isValidCoordinate(from.latitude, from.longitude);
      const toCoordValid = this.isValidCoordinate(to.latitude, to.longitude);
      const canCacheDuration = Number.isFinite(duration) && duration > 0;
      if (canCacheDuration) {
        this.cache.set(key, duration);
        if (duration === TrafficEngine.FALLBACK_MINUTES && (!fromCoordValid || !toCoordValid)) {
          hilog.warn(
            0x0000,
            TAG,
            `${ROUTE_DIAG_PREFIX}[engine] fallback_60_cached_for_invalid_coord key=${key} from_coord=${fromCoordValid} to_coord=${toCoordValid}`
          );
        }
      } else {
        this.cache.delete(key);
      }
      this.clearTransientFailure(key);
      hilog.info(0x0000, TAG, `${ROUTE_GEO_FIX_PREFIX}[engine] fetch_done key=${key} mode=${mode} duration=${duration}`);
      if (duration <= 0 || duration === TrafficEngine.FALLBACK_MINUTES) {
        hilog.warn(
          0x0000,
          TAG,
          `${ROUTE_DIAG_PREFIX}[engine] suspicious_duration key=${key} mode=${mode} duration=${duration}`
        );
      }
      this.emitTrafficDataUpdated();
    } catch (e) {
      this.cache.delete(key);
      this.markTransientFailure(key, 'multi_modal_exception');
      hilog.error(0x0000, TAG, `${ROUTE_GEO_FIX_PREFIX}[engine] fetch_failed key=${key} mode=${mode} err=${JSON.stringify(e)}`);
      this.emitTrafficDataUpdated();
    }
  }

  private async fetchAmapTrafficAsync(from: LocationInfo, to: LocationInfo, strategy: DriveStrategy, key: string) {
    if (this.cache.get(key) === -1) return;
    this.cache.set(key, -1);

    try {
      if (!this.mapService) {
        this.cache.delete(key);
        this.markTransientFailure(key, 'drive_service_unavailable');
        this.emitTrafficDataUpdated();
        hilog.warn(0x0000, TAG, '[LIFECYCLE_GUARD] drive fetch skipped: service unavailable.');
        return;
      }

      hilog.info(0x0000, TAG, `${ROUTE_GEO_FIX_PREFIX}[engine] drive_fetch_start key=${key} strategy=${strategy}`);
      const duration = await this.mapService.getDriveDuration(from, to, strategy);
      this.cache.set(key, duration);
      this.clearTransientFailure(key);
      hilog.info(0x0000, TAG, `${ROUTE_GEO_FIX_PREFIX}[engine] drive_fetch_done key=${key} strategy=${strategy} duration=${duration}`);
      this.emitTrafficDataUpdated();
    } catch (e) {
      this.cache.delete(key);
      this.markTransientFailure(key, 'drive_exception');
      hilog.error(0x0000, TAG, `${ROUTE_GEO_FIX_PREFIX}[engine] drive_fetch_failed key=${key} strategy=${strategy} err=${JSON.stringify(e)}`);
      this.emitTrafficDataUpdated();
    }
  }
}
