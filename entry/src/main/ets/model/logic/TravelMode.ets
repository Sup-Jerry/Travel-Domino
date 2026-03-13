// 文件路径: ets/model/logic/TravelMode.ets

/**
 * 交通方式枚举
 * 严格对应高德地图 API 的路径规划分类
 */
export enum TravelMode {
  WALKING = 0,   // 步行
  CYCLING = 1,   // 骑行
  DRIVING = 2,   // 驾车 (默认避开拥堵策略)
  TRANSIT = 3    // 公交/地铁
}