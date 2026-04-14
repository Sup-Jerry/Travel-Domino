/**
 * 闃茶厫灞傛帴鍙ｏ細鍦板浘鏈嶅姟
 * 闅旂绗笁鏂瑰湴鍥?SDK 涓?涓氬姟閫昏緫
 */
export interface LocationInfo {
  name: string;
  address?: string;
  latitude?: number;
  longitude?: number;
}

export interface IMapService {
  /**
   * 鎼滅储鍦扮偣 (MVP 闃舵杩斿洖 Mock 鏁版嵁)
   */
  getLocationInfo(keyword: string): Promise<LocationInfo[]>;

  /**
   * 璁＄畻閫氬嫟鏃堕棿
   * @param from 璧风偣鍚嶇О
   * @param to 缁堢偣鍚嶇О
   * @returns 鍒嗛挓鏁?(Promise)
   */
  calculateCommute(from: string, to: string): Promise<number>;

  /**
   * 璁＄畻椹捐溅鑰楁椂
   * @returns 鍒嗛挓
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
  FASTEST = 0,    // 閫熷害浼樺厛
  AVOID_CONGESTION = 4, // 韬查伩鎷ュ牭
  ECONOMICAL = 1,  // 閬垮厤鏀惰垂 (鑺傜害)
}

export const DEFAULT_DRIVE_STRATEGY: DriveStrategy = DriveStrategy.FASTEST;

