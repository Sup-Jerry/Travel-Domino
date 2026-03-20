// 路径: ets/model/interface/IStandardEvent.ets

export interface TravelPlanItem {
  id?: number;
  name: string;
  note?: string;

  transitWarning?: boolean;
  // 核心枚举
  itemType?: number;    // 对应 DB 的 TYPE (颜色)
  priority?: number;    // (气泡大小)
  lockStatus?: number; // (锚点逻辑)
  travelMode?: number; // 使用 TravelMode 枚举值
  transportMode?: number; // 兼容旧字段，内部统一以 travelMode 为准
  isTravelManual?: number;
  lastFromId?: number;
  status: number;       // (暂存/日程)
  source?: number;      // (AI/User)

  // 基础数据
  duration: number;
  preTravelMinutes: number;
  sortOrder: number;
  fixedStartTime?: string;
  dayOffset?: number;
  dynamicDayOffset?: number; // 新增：动态推演归属日，不回写用户基准

  // 地理与元数据
  latitude?: number;
  longitude?: number;
  address?: string;
  aiReasoning?: string;
  groupId?: number;
  delFlag?: number;

  // [伴游模式] // 修改点：新增接口定义
  actualStartTime?: number;
  actualEndTime?: number;
  dynamicStartTime?: number; // 新增：推算的动态开始时间戳
  dynamicEndTime?: number;   // 新增：推算的动态结束时间戳
  completionStatus?: number; // 0:Pending, 1:Completed, 2:Skipped
  weatherCondition?: string;
  weatherTemperature?: number;
  weatherText?: string;
  weatherFetchTime?: number;

  // 兼容字段 (可逐步废弃)
  type: string; // 'ANCHOR' | 'FLOW'

  // 计算输出
  computedStartTime?: string;
  computedEndTime?: string;
  isConflict?: boolean;
  conflictMsg?: string;
  suggestedShiftMinutes?: number;

  hasGap?: boolean;
  gapMinutes?: number;
  naturalStartTime?: string;
  ignoreWait?: boolean;
}
