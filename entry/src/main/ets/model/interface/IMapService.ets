/**
 * 防腐层接口：地图服务
 * 隔离第三方地图 SDK 与 业务逻辑
 */
export interface LocationInfo {
  name: string;
  address?: string;
  latitude?: number;
  longitude?: number;
}

export interface IMapService {
  /**
   * 搜索地点 (MVP 阶段返回 Mock 数据)
   */
  getLocationInfo(keyword: string): Promise<LocationInfo[]>;

  /**
   * 计算通勤时间
   * @param from 起点名称
   * @param to 终点名称
   * @returns 分钟数 (Promise)
   */
  calculateCommute(from: string, to: string): Promise<number>;

  /**
   * 计算驾车耗时
   * @returns 分钟
   */
  getDriveDuration(
    origin: LocationInfo,
    destination: LocationInfo,
    strategy: DriveStrategy
  ): Promise<number>;

  getDurationByMode(
    origin: LocationInfo,
    destination: LocationInfo,
    mode: number,
    startTime?: string
  ): Promise<number>;
}

export enum DriveStrategy {
  FASTEST = 0,    // 速度优先
  AVOID_CONGESTION = 4, // 躲避拥堵
  ECONOMICAL = 1,  // 避免收费 (节约)
}
