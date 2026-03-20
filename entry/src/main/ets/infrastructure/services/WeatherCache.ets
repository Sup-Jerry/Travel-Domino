import { WeatherSnapshot, WeatherSourceType } from '../../domain/services/WeatherModels';

interface CachedWeather {
  data: WeatherSnapshot;
  cachedAt: number;
}

export class WeatherCache {
  private static readonly DEFAULT_TTL_MS = 45 * 60 * 1000;
  private readonly cache: Map<string, CachedWeather> = new Map<string, CachedWeather>();

  public static buildLocationKey(lat: number, lng: number, bucketTs: number = Date.now()): string {
    const safeLat = Number.isFinite(lat) ? lat.toFixed(3) : '0.000';
    const safeLng = Number.isFinite(lng) ? lng.toFixed(3) : '0.000';
    const hourBucket = Math.floor(bucketTs / (60 * 60 * 1000));
    return `${safeLat}:${safeLng}:${hourBucket}`;
  }

  public buildCacheKey(sourceType: WeatherSourceType, locationKey: string): string {
    return `weather:${sourceType}:${locationKey}`;
  }

  public get(cacheKey: string, ttlMs: number = WeatherCache.DEFAULT_TTL_MS): WeatherSnapshot | null {
    const hit = this.cache.get(cacheKey);
    if (!hit) {
      return null;
    }
    if (Date.now() - hit.cachedAt > ttlMs) {
      this.cache.delete(cacheKey);
      return null;
    }
    return hit.data;
  }

  public set(cacheKey: string, weather: WeatherSnapshot): void {
    this.cache.set(cacheKey, {
      data: weather,
      cachedAt: Date.now()
    });
  }

  public cleanup(ttlMs: number = WeatherCache.DEFAULT_TTL_MS): void {
    const now = Date.now();
    this.cache.forEach((entry: CachedWeather, key: string) => {
      if (now - entry.cachedAt > ttlMs) {
        this.cache.delete(key);
      }
    });
  }
}
