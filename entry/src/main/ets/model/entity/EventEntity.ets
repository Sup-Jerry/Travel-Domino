// 文件路径: ets/model/entity/EventEntity.ets
import { TravelPlanItem } from '../interface/IStandardEvent'; // 确保引入接口
import { TravelMode } from '../logic/TravelMode';



@Observed
export class EventEntity {


  static readonly TABLE_NAME = 'events';


  // ==================== 基础信息 ====================
  static readonly ID = 'id';
  static readonly PLAN_ID = 'plan_id'; // 外键：关联 PlanEntity
  static readonly NAME = 'name';

  /**
   * [详情] 备注/备忘录
   * 作用：存储预约号、注意事项等细节信息。
   */
  static readonly NOTE = 'note';

  static readonly DURATION = 'duration'; // 游玩时长 (分钟)

  // ==================== 交通与位置 (Map Kit 预留) ====================
  /**
   * [路程] 前往此地的通勤时间 (分钟)
   * 作用：时间引擎计算 StartTime = Prev.EndTime + PreTravel
   */
  static readonly PRE_TRAVEL_MINUTES = 'pre_travel_min';
  static readonly IS_TRAVEL_MANUAL = 'is_travel_manual';
  static readonly TRAVEL_MODE = 'travel_mode';


  /**
   * [交通] 交通方式
   * 0:未知, 1:步行(显示小人), 2:驾车(显示汽车), 3:公交/地铁(显示地铁)
   * 作用：未来调用地图 API 时，决定路径规划的策略。
   */
  // 兼容旧 JSON 字段；数据库只存 TRAVEL_MODE。
  static readonly TRANSPORT_MODE = 'transport_mode';

  /**
   * [缓存] 经度 & 纬度
   * 作用：缓存地图 API 返回的坐标。
   * 价值：1. 减少 API 调用省钱；2. 离线也能计算两个地点的直线距离。
   */
  static readonly LATITUDE = 'latitude';
  static readonly LONGITUDE = 'longitude';

  /**
   * [展示] 具体地址字符串
   * 作用：显示在卡片上，如 "北京市东城区景山前街4号"。
   */
  static readonly ADDRESS = 'address';

  // ==================== 核心逻辑 (Solver 引擎) ====================
  /**
   * [锚点] 锁定状态 (二态逻辑)
   * 0: 非刚性 (Non-Rigid) - 弹性时间。
   * - 若设置了 fixed_start_time：早到会等(Gap)，晚到会顺延(Push)。
   * - 若没设置：完全紧随上一站。
   * 1: 刚性 (Rigid) - 绝对时间。
   * - 必须有 fixed_start_time。
   * - 逻辑无法改变它，迟到则报错(Conflict)。
   */
  static readonly LOCK_STATUS = 'lock_status';

  /**
   * [锚点] 固定开始时间 (仅当 lock_status > 0 时有效)
   * 格式: "HH:mm"
   */
  static readonly FIXED_START_TIME = 'fixed_start_time';

  static readonly DAY_OFFSET = 'day_offset';

  /**
   * [暂存] 状态
   * 0: 许愿池/暂存 (Backlog) - 不参与时间轴计算
   * 1: 日程表 (Schedule) - 参与时间轴计算
   */
  static readonly STATUS = 'status';

  /**
   * [排序] 链表顺序
   * 作用：Gap Strategy 核心字段 (0, 100, 200...)，支持高性能拖拽。
   */
  static readonly SORT_ORDER = 'sort_order';

  // ==================== 视觉与交互 (许愿池) ====================
  /**
   * [分类] 地点类型
   * 0:景点(绿), 1:美食(橙), 2:住宿(蓝), 3:交通(灰)
   * 作用：决定许愿池标签的颜色。
   */
  static readonly TYPE = 'type';

  /**
   * [权重] 优先级
   * 0:普通, 1:必去(重要)
   * 作用：决定许愿池标签的大小，或气泡的物理体积。
   */
  static readonly PRIORITY = 'priority';

  /**
   * [组合] 编组 ID
   * 作用：未来功能。拖拽时，拥有相同 GroupID 的事件会被视为一个整体块一起移动。
   */
  static readonly GROUP_ID = 'group_id';

  // ==================== AI 接入 (预留接口) ====================
  /**
   * [来源] 数据来源
   * 0: 用户手填
   * 1: AI 推荐 (显示魔法棒图标)
   * 2: 模板导入
   */
  static readonly SOURCE = 'source';

  /**
   * [AI] 推荐理由
   * 作用：存 AI 生成的文本，如 "推荐此地是因为离你上个地点仅 500米"。
   */
  static readonly AI_REASONING = 'ai_reasoning';

  // ==================== 安全与容错 ====================
  static readonly DEL_FLAG = 'del_flag';       // 事件级软删除
  static readonly DELETE_TIME = 'delete_time'; // 删除时间

  // ==================== 伴游模式 (现实状态) ====================
  // // 修改点：新增现实时间与完成状态的字段定义
  static readonly ACTUAL_START_TIME = 'actual_start_time'; // 实际开始时间戳
  static readonly ACTUAL_END_TIME = 'actual_end_time';     // 实际结束时间戳
  static readonly COMPLETION_STATUS = 'completion_status'; // 完成状态

  // 完成状态枚举
  static readonly STATE_PENDING = 0;   // 未开始
  static readonly STATE_COMPLETED = 1; // 已完成
  static readonly STATE_SKIPPED = 2;   // 已跃迁 (跳过)

  // ==================== 建表语句 ====================
  static readonly SQL_CREATE_TABLE = `
    CREATE TABLE IF NOT EXISTS ${EventEntity.TABLE_NAME} (
      ${EventEntity.ID} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${EventEntity.PLAN_ID} INTEGER NOT NULL,
      ${EventEntity.NAME} TEXT NOT NULL,
      ${EventEntity.NOTE} TEXT,
      ${EventEntity.DURATION} INTEGER DEFAULT 0,
      ${EventEntity.PRE_TRAVEL_MINUTES} INTEGER DEFAULT 0,
      ${EventEntity.IS_TRAVEL_MANUAL} INTEGER DEFAULT 0,
      ${EventEntity.TRAVEL_MODE} INTEGER DEFAULT 0,
      ${EventEntity.LOCK_STATUS} INTEGER DEFAULT 0,
      ${EventEntity.FIXED_START_TIME} TEXT,
      ${EventEntity.DAY_OFFSET} INTEGER DEFAULT 0,
      ${EventEntity.STATUS} INTEGER DEFAULT 0,
      ${EventEntity.SORT_ORDER} INTEGER DEFAULT 0,
      ${EventEntity.TYPE} INTEGER DEFAULT 0,
      ${EventEntity.PRIORITY} INTEGER DEFAULT 0,
      ${EventEntity.LATITUDE} REAL DEFAULT 0,
      ${EventEntity.LONGITUDE} REAL DEFAULT 0,
      ${EventEntity.ADDRESS} TEXT,
      ${EventEntity.GROUP_ID} INTEGER DEFAULT 0,
      ${EventEntity.SOURCE} INTEGER DEFAULT 0,
      ${EventEntity.AI_REASONING} TEXT,
      ${EventEntity.DEL_FLAG} INTEGER DEFAULT 0,
      ${EventEntity.DELETE_TIME} INTEGER DEFAULT 0,
      ${EventEntity.ACTUAL_START_TIME} INTEGER DEFAULT 0,
      ${EventEntity.ACTUAL_END_TIME} INTEGER DEFAULT 0,
      ${EventEntity.COMPLETION_STATUS} INTEGER DEFAULT 0
    )
  `;


  id: number = 0;
  plan_id: number = 0;
  name: string = '';

  // [详情]
  note: string = ''; // 对应 NOTE
  duration: number = 30; // 默认30分钟

  // [交通]
  pre_travel_min: number = 0;
  is_travel_manual: number = 0;
  travel_mode: number = 2;
  transport_mode: number = 2;
  latitude: number = 0;
  longitude: number = 0;
  address: string = '';

  // [逻辑]
  lock_status: number = 0;
  fixed_start_time: string = ''; // 格式 "HH:mm"
  day_offset: number = 0;
  dynamic_day_offset: number = 0; // 仅用于渲染推演结果，不入库
  status: number = 0;
  sort_order: number = 0;

  // [视觉]
  type: number = 0;
  priority: number = 0;
  group_id: number = 0;

  // [AI]
  source: number = 0;
  ai_reasoning: string = '';

  // [安全]
  del_flag: number = 0;
  delete_time: number = 0;

  actual_start_time: number = 0; // 修改点
  actual_end_time: number = 0;   // 修改点
  completion_status: number = 0; // 修改点
  dynamic_start_time: number = 0;
  dynamic_end_time: number = 0;
  last_from_id: number = -1;
  // 构造函数 (可选，方便 new)
  constructor(name: string = '', plan_id: number = 0) {
    this.name = name;
    this.plan_id = plan_id;
  }


  // ==================== ⬇️ 新增：UI 渲染专用 (不入库) ====================
  // 是否冲突 (Solver 计算得出)
  is_conflict: boolean = false;
  transit_warning: boolean = false; // ✅ 新增：是否显示高铁预警

  // 冲突描述 (如 "冲突 15 min")
  conflict_msg: string = '';
  computed_time: string = '';

  forecast_start_time: string = '';
  forecast_end_time: string = '';
  is_forecast_conflict: boolean = false;
  is_ignore_wait: boolean = false;
  has_gap: boolean = false;
  gap_minutes: number = 0;
  natural_start_time: string = '';

  static fromInterface(item: TravelPlanItem, planId: number): EventEntity {
    const entity = new EventEntity(item.name, planId);
    entity.id = item.id || 0;
    entity.note = item.note || '';
    const normalizedMode = item.travelMode ?? item.transportMode ?? 0;
    entity.travel_mode = normalizedMode;
    entity.duration = item.duration;
    entity.pre_travel_min = item.preTravelMinutes || 0;
    entity.is_travel_manual = item.isTravelManual || 0;
    entity.transport_mode = normalizedMode;
    entity.latitude = item.latitude || 0;
    entity.longitude = item.longitude || 0;
    entity.address = item.address || '';

    entity.lock_status = item.lockStatus || 0;
    entity.fixed_start_time = item.fixedStartTime || '';
    entity.day_offset = item.dayOffset || 0;
    entity.dynamic_day_offset = item.dynamicDayOffset ?? entity.day_offset;
    entity.status = item.status || 0;
    entity.sort_order = item.sortOrder;

    entity.type = item.itemType || 0; // 注意：Interface里的 itemType 对应 Entity里的 type
    entity.priority = item.priority || 0;
    entity.group_id = item.groupId || 0;
    entity.source = item.source || 0;
    entity.ai_reasoning = item.aiReasoning || '';
    entity.del_flag = item.delFlag || 0;
    entity.actual_start_time = item.actualStartTime || 0;
    entity.actual_end_time = item.actualEndTime || 0;
    entity.dynamic_start_time = item.dynamicStartTime || 0;
    entity.dynamic_end_time = item.dynamicEndTime || 0;
    entity.completion_status = item.completionStatus || 0;
    entity.is_ignore_wait = item.ignoreWait || false;
    entity.last_from_id = item.lastFromId ?? -1;
    entity.transit_warning = item.transitWarning || false;
    return entity;
  }


  toInterface(): TravelPlanItem {
    return {
      travelMode: this.travel_mode,
      id: this.id,
      name: this.name,
      note: this.note,
      duration: this.duration,
      preTravelMinutes: this.pre_travel_min,
      isTravelManual: this.is_travel_manual,
      status: this.status,
      sortOrder: this.sort_order,

      // Solver 需要的 type 是字符串 'ANCHOR'|'FLOW'
      type: (this.lock_status > 0) ? 'ANCHOR' : 'FLOW',
      itemType: this.type, // 许愿池的分类

      lockStatus: this.lock_status,
      fixedStartTime: this.fixed_start_time,
      dayOffset: this.day_offset,
      dynamicDayOffset: this.dynamic_day_offset,
      priority: this.priority,
      transportMode: this.travel_mode,
      latitude: this.latitude,
      longitude: this.longitude,
      source: this.source,
      address: this.address,
      lastFromId: this.last_from_id,
      transitWarning: this.transit_warning,
      aiReasoning: this.ai_reasoning,
      groupId: this.group_id,
      delFlag: this.del_flag,
      actualStartTime: this.actual_start_time,
      actualEndTime: this.actual_end_time,
      dynamicStartTime: this.dynamic_start_time,
      dynamicEndTime: this.dynamic_end_time,
      completionStatus: this.completion_status,
      ignoreWait: this.is_ignore_wait
    };
  }
}
