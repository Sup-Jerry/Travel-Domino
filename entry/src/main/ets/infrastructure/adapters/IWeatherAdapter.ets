/**
 * 天气服务接口 - 预留用于未来天气自适应功能
 */

export interface WeatherInfo {
  temperature: number;      // 温度（摄氏度）
  condition: string;        // 天气状况（晴/雨/雪等）
  humidity: number;         // 湿度（百分比）
  windSpeed: number;        // 风速（km/h）
  reportTime?: string;      // 观测时间
  cityCode?: string;        // 城市编码(adcode)
}

export interface WeatherGeoPointRequest {
  latitude: number;
  longitude: number;
  targetTime?: number;
  sourceType?: 'CURRENT_LOCATION' | 'PLAN_LOCATION';
  forceRefresh?: boolean;
}

export interface IWeatherAdapter {
  /**
   * 获取指定城市的天气信息
   */
  getWeather(cityName: string): Promise<WeatherInfo | null>;

  /**
   * 按坐标获取天气
   */
  getWeatherByGeoPoint(
    latitude: number,
    longitude: number,
    targetTime?: number,
    sourceType?: 'CURRENT_LOCATION' | 'PLAN_LOCATION',
    forceRefresh?: boolean
  ): Promise<WeatherInfo | null>;

  /**
   * 批量获取天气（内部需做去重/节流）
   */
  batchGetWeather(points: WeatherGeoPointRequest[]): Promise<Map<string, WeatherInfo>>;
}
