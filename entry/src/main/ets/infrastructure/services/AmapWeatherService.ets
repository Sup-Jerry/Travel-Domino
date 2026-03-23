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
  forecasts?: AmapForecastNode[];
}

interface AmapForecastCastNode {
  dayweather?: string;
  daytemp?: string;
  nighttemp?: string;
}

interface AmapForecastNode {
  adcode?: string;
  casts?: AmapForecastCastNode[];
}

interface CityBatchPoint {
  pointKey: string;
  point: WeatherGeoPointRequest;
  order: number;
}

const TAG = 'AmapWeatherService';

export class AmapWeatherService implements IWeatherAdapter {
  private static readonly MAX_BATCH_CITY_GROUPS: number = 5;
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
      const mapped = this.mapResponseToInfo(parsed);
      if (!mapped) {
        hilog.warn(
          0x0000,
          TAG,
          `[WEATHER][getWeather] empty business payload city=${cityName}, status=${parsed.status ?? ''}, lives=${parsed.lives?.length ?? 0}, forecasts=${parsed.forecasts?.length ?? 0}`
        );
      }
      return mapped;
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
    hilog.info(0x0000, TAG, `[WEATHER][batch] input=${points.length}, dedup=${entries.length}`);

    const groupedByCity: Map<string, CityBatchPoint[]> = new Map<string, CityBatchPoint[]>();
    let cityMissCount = 0;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const pointKey = entry[0];
      const point = entry[1];
      const sourceType = point.sourceType ?? 'PLAN_LOCATION';
      const ttl = sourceType === 'CURRENT_LOCATION' ? this.executionTtlMs : this.planningTtlMs;
      if (!(point.forceRefresh ?? false)) {
        const cacheKey = this.cache.buildCacheKey(sourceType, pointKey);
        const cached = this.cache.get(cacheKey, ttl);
        if (cached) {
          result.set(pointKey, this.snapshotToInfo(cached));
          continue;
        }
      }
      const cityCode = await AmapService.getCityCodeByCoordinate(point.latitude, point.longitude);
      if (!cityCode || cityCode.trim().length === 0) {
        cityMissCount += 1;
        continue;
      }
      const list = groupedByCity.get(cityCode) ?? [];
      const cityItem: CityBatchPoint = {
        pointKey: pointKey,
        point: point,
        order: i
      };
      list.push(cityItem);
      groupedByCity.set(cityCode, list);
    }

    const cityEntries = Array.from(groupedByCity.entries());
    cityEntries.forEach((entry: [string, CityBatchPoint[]]) => {
      entry[1].sort((x, y) => x.order - y.order);
    });
    cityEntries.sort((a: [string, CityBatchPoint[]], b: [string, CityBatchPoint[]]) => {
      const firstA = a[1][0];
      const firstB = b[1][0];
      const rank = (item?: CityBatchPoint): number => {
        if (!item) {
          return 9;
        }
        if ((item.point.sourceType ?? 'PLAN_LOCATION') === 'CURRENT_LOCATION') {
          return 1;
        }
        return item.order === 0 ? 0 : 2;
      };
      const rankDiff = rank(firstA) - rank(firstB);
      if (rankDiff !== 0) {
        return rankDiff;
      }
      return (firstA?.order ?? 0) - (firstB?.order ?? 0);
    });
    const hasCurrentLocationTarget = entries.some((entry: [string, WeatherGeoPointRequest]) =>
      (entry[1].sourceType ?? 'PLAN_LOCATION') === 'CURRENT_LOCATION'
    );
    const applyCityCap = hasCurrentLocationTarget;
    const cityCappedCount = applyCityCap && cityEntries.length > AmapWeatherService.MAX_BATCH_CITY_GROUPS
      ? cityEntries.length - AmapWeatherService.MAX_BATCH_CITY_GROUPS
      : 0;
    const selectedCities = applyCityCap
      ? cityEntries.slice(0, AmapWeatherService.MAX_BATCH_CITY_GROUPS)
      : cityEntries;
    hilog.info(
      0x0000,
      TAG,
      `[WEATHER_CITY][batch] cityGroupCount=${cityEntries.length}, cityCappedCount=${cityCappedCount}, cityMissCount=${cityMissCount}, capEnabled=${applyCityCap ? 1 : 0}`
    );

    for (let i = 0; i < selectedCities.length; i++) {
      const selected = selectedCities[i];
      const cityCode = selected[0];
      const cityPoints = selected[1];
      const weather = await this.getWeather(cityCode);
      if (!weather) {
        continue;
      }
      for (let j = 0; j < cityPoints.length; j++) {
        const item = cityPoints[j];
        result.set(item.pointKey, weather);
        const sourceType = item.point.sourceType ?? 'PLAN_LOCATION';
        const cacheKey = this.cache.buildCacheKey(sourceType, item.pointKey);
        this.cache.set(cacheKey, this.infoToSnapshot(item.pointKey, weather, sourceType));
      }
    }
    hilog.info(0x0000, TAG, `[WEATHER][batch] output=${result.size}`);
    return result;
  }

  public toSnapshotByPoint(pointKey: string, info: WeatherInfo): WeatherSnapshot {
    return this.infoToSnapshot(pointKey, info);
  }

  private mapResponseToInfo(response: AmapLiveWeatherResponse): WeatherInfo | null {
    const liveNode = response.lives && response.lives.length > 0 ? response.lives[0] : undefined;
    const liveMapped = this.mapLiveNodeToInfo(liveNode);
    if (liveMapped) {
      return liveMapped;
    }

    const forecastNode = response.forecasts && response.forecasts.length > 0 ? response.forecasts[0] : undefined;
    const forecastMapped = this.mapForecastNodeToInfo(forecastNode);
    if (forecastMapped) {
      hilog.info(0x0000, TAG, '[WEATHER][getWeather] fallback to forecast payload');
      return forecastMapped;
    }
    return null;
  }

  private mapLiveNodeToInfo(node?: AmapLiveWeatherNode): WeatherInfo | null {
    if (!node) {
      return null;
    }
    const condition = this.readAsText(node.weather);
    if (condition.length === 0) {
      return null;
    }
    const temperature = this.readAsNumber(node.temperature);
    const humidity = this.readAsNumber(node.humidity);
    const windSpeed = this.readAsNumber(node.windpower);
    return {
      temperature: Number.isFinite(temperature) ? temperature : 0,
      condition: condition,
      humidity: Number.isFinite(humidity) ? humidity : 0,
      windSpeed: Number.isFinite(windSpeed) ? windSpeed : 0,
      reportTime: this.readAsText(node.reporttime),
      cityCode: this.readAsText(node.adcode)
    };
  }

  private mapForecastNodeToInfo(node?: AmapForecastNode): WeatherInfo | null {
    if (!node || !node.casts || node.casts.length === 0) {
      return null;
    }
    const cast = node.casts[0];
    const condition = this.readAsText(cast.dayweather);
    if (condition.length === 0) {
      return null;
    }
    const dayTemp = this.readAsNumber(cast.daytemp);
    const nightTemp = this.readAsNumber(cast.nighttemp);
    let temperature = dayTemp;
    if (Number.isFinite(dayTemp) && Number.isFinite(nightTemp)) {
      temperature = (dayTemp + nightTemp) / 2;
    } else if (!Number.isFinite(dayTemp) && Number.isFinite(nightTemp)) {
      temperature = nightTemp;
    }
    return {
      temperature: Number.isFinite(temperature) ? temperature : 0,
      condition: condition,
      humidity: 0,
      windSpeed: 0,
      cityCode: this.readAsText(node.adcode)
    };
  }

  private readAsText(value: string | undefined): string {
    if (!value) {
      return '';
    }
    return value.trim();
  }

  private readAsNumber(value: string | undefined): number {
    if (!value) {
      return Number.NaN;
    }
    const parsed = Number.parseFloat(value.trim());
    return Number.isFinite(parsed) ? parsed : Number.NaN;
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
