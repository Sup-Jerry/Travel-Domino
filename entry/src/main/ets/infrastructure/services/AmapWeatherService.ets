import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../../common/utils/AppConfig';
import { HttpRequestHelper } from '../adapters/HttpRequestHelper';
import { IWeatherAdapter, WeatherInfo, WeatherGeoPointRequest } from '../adapters/IWeatherAdapter';
import { AmapService } from './AmapService';
import { WeatherCache } from './WeatherCache';
import { WeatherSnapshot } from '../../domain/services/WeatherModels';

interface AmapLiveWeatherNode {
  adcode?: string;
  weather?: string;
  temperature?: string;
  humidity?: string;
  windpower?: string;
  reporttime?: string;
}

interface AmapLiveWeatherResponse {
  status?: string;
  lives?: AmapLiveWeatherNode[];
}

const TAG = 'AmapWeatherService';

export class AmapWeatherService implements IWeatherAdapter {
  private readonly cache: WeatherCache = new WeatherCache();
  private readonly planningTtlMs: number = 45 * 60 * 1000;
  private readonly executionTtlMs: number = 15 * 60 * 1000;

  public static toPointKey(lat: number, lng: number, targetTime?: number): string {
    return WeatherCache.buildLocationKey(lat, lng, targetTime ?? Date.now());
  }

  public async getWeather(cityName: string): Promise<WeatherInfo | null> {
    if (!cityName || cityName.trim().length === 0) {
      return null;
    }
    try {
      AppConfig.validateAmapWebConfig();
      const url =
        `https://restapi.amap.com/v3/weather/weatherInfo?city=${encodeURIComponent(cityName)}` +
        `&extensions=base&key=${AppConfig.AMAP_WEB_API_KEY}`;
      const response = await HttpRequestHelper.request(TAG, 'getWeather', url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      if (response.responseCode !== 200) {
        return null;
      }
      const payload = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const parsed = JSON.parse(payload) as AmapLiveWeatherResponse;
      return this.mapLiveNodeToInfo(parsed.lives && parsed.lives.length > 0 ? parsed.lives[0] : undefined);
    } catch (error) {
      hilog.warn(0x0000, TAG, `[WEATHER][getWeather] failed reason=${JSON.stringify(error)}`);
      return null;
    }
  }

  public async getWeatherByGeoPoint(
    latitude: number,
    longitude: number,
    targetTime?: number,
    sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION',
    forceRefresh: boolean = false
  ): Promise<WeatherInfo | null> {
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || (latitude === 0 && longitude === 0)) {
      return null;
    }
    const pointKey = AmapWeatherService.toPointKey(latitude, longitude, targetTime);
    const cacheKey = this.cache.buildCacheKey(sourceType, pointKey);
    const ttl = sourceType === 'CURRENT_LOCATION' ? this.executionTtlMs : this.planningTtlMs;
    if (!forceRefresh) {
      const cached = this.cache.get(cacheKey, ttl);
      if (cached) {
        return this.snapshotToInfo(cached);
      }
    }

    try {
      const cityCode = await AmapService.getCityCodeByCoordinate(latitude, longitude);
      if (!cityCode) {
        return null;
      }
      const info = await this.getWeather(cityCode);
      if (!info) {
        return null;
      }
      const snapshot = this.infoToSnapshot(pointKey, info, sourceType);
      this.cache.set(cacheKey, snapshot);
      return info;
    } catch (error) {
      hilog.warn(0x0000, TAG, `[WEATHER][geo] failed lat=${latitude}, lng=${longitude}, reason=${JSON.stringify(error)}`);
      return null;
    }
  }

  public async batchGetWeather(points: WeatherGeoPointRequest[]): Promise<Map<string, WeatherInfo>> {
    const result: Map<string, WeatherInfo> = new Map<string, WeatherInfo>();
    if (!points || points.length === 0) {
      return result;
    }

    const dedup: Map<string, WeatherGeoPointRequest> = new Map<string, WeatherGeoPointRequest>();
    points.forEach((point: WeatherGeoPointRequest) => {
      if (!Number.isFinite(point.latitude) || !Number.isFinite(point.longitude)) {
        return;
      }
      if (point.latitude === 0 && point.longitude === 0) {
        return;
      }
      const key = AmapWeatherService.toPointKey(point.latitude, point.longitude, point.targetTime);
      if (!dedup.has(key)) {
        dedup.set(key, point);
      }
    });

    const entries = Array.from(dedup.entries());
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const pointKey = entry[0];
      const point = entry[1];
      const weather = await this.getWeatherByGeoPoint(
        point.latitude,
        point.longitude,
        point.targetTime,
        point.sourceType ?? 'PLAN_LOCATION',
        point.forceRefresh ?? false
      );
      if (weather) {
        result.set(pointKey, weather);
      }
    }
    return result;
  }

  public toSnapshotByPoint(pointKey: string, info: WeatherInfo): WeatherSnapshot {
    return this.infoToSnapshot(pointKey, info);
  }

  private mapLiveNodeToInfo(node?: AmapLiveWeatherNode): WeatherInfo | null {
    if (!node || !node.weather) {
      return null;
    }
    const temperature = Number.parseFloat(node.temperature ?? '0');
    const humidity = Number.parseFloat(node.humidity ?? '0');
    const windSpeed = Number.parseFloat(node.windpower ?? '0');
    return {
      temperature: Number.isFinite(temperature) ? temperature : 0,
      condition: node.weather ?? '',
      humidity: Number.isFinite(humidity) ? humidity : 0,
      windSpeed: Number.isFinite(windSpeed) ? windSpeed : 0,
      reportTime: node.reporttime,
      cityCode: node.adcode
    };
  }

  private infoToSnapshot(
    locationKey: string,
    info: WeatherInfo,
    sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION'
  ): WeatherSnapshot {
    return {
      locationKey: locationKey,
      sourceType: sourceType,
      weatherTime: Date.now(),
      fetchTime: Date.now(),
      conditionCode: info.condition || 'UNKNOWN',
      conditionText: info.condition || '天气未知',
      temperatureCelsius: info.temperature,
      humidity: info.humidity,
      windSpeed: info.windSpeed,
      reportTime: info.reportTime,
      cityCode: info.cityCode
    };
  }

  private snapshotToInfo(snapshot: WeatherSnapshot): WeatherInfo {
    return {
      temperature: snapshot.temperatureCelsius ?? 0,
      condition: snapshot.conditionText || snapshot.conditionCode || '天气未知',
      humidity: snapshot.humidity ?? 0,
      windSpeed: snapshot.windSpeed ?? 0,
      reportTime: snapshot.reportTime,
      cityCode: snapshot.cityCode
    };
  }
}
