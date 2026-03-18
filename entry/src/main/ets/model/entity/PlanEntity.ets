export class PlanEntity {
  static readonly TABLE_NAME = 'plans';

  // ==================== 基础信息 ====================
  static readonly ID = 'id';
  static readonly NAME = 'name'; // 计划标题（UI层限制19字截断）

  // ==================== 核心逻辑 ====================
  /**
   * [底层锚点] 计划的起始日期时间戳 (毫秒)
   * 作用：用于计算 "Day 1", "Day 2" 对应的真实日期 (如 12月18日)。
   * 未来功能：支持行程整体改期，只需改此字段，所有事件自动平移。
   */
  static readonly START_DATE = 'start_date';

  /**
   * [生命周期] 计划状态
   * 0: 规划中 (默认，可编辑)
   * 1: 锁定 (即将出发，防止误触)
   * 2: 归档 (旅行结束，变为只读模式，移入"回忆"列表)
   */
  static readonly STATUS = 'status';

  // ==================== 安全与容错 ====================
  /**
   * [软删除] 删除标记
   * 0: 正常
   * 1: 已删除 (进入回收站)
   * 作用：用户点击删除时，只更新此字段，不物理删除数据。
   */
  static readonly DEL_FLAG = 'del_flag';

  /**
   * [回收站] 删除时间
   * 作用：配合软删除，后台任务定期检查，若 (当前时间 - delete_time) > 30天，则物理销毁。
   */
  static readonly DELETE_TIME = 'delete_time';

  /**
   * [外部接口] 上次导出到系统日历的时间
   * 作用：防止重复导出。如果用户点了两次导出，可根据此时间判断是"覆盖"还是"新增"。
   */
  static readonly LAST_EXPORT_TIME = 'last_export_time';
  static readonly ENABLE_AUTO_AMAP_ROUTE = 'enable_auto_amap_route';

  // ==================== 视觉装修 ====================
  static readonly COVER_COLOR = 'cover_color'; // [预留] 计划封面的主题色
  static readonly CREATED_AT = 'created_at';   // 创建时间，用于默认排序

  // ==================== AI策略系统 ====================
  static readonly STRATEGY_MODE = 'strategy_mode';
  static readonly STRATEGY_VERSION = 'strategy_version';
  static readonly LAST_AI_PROMPT = 'last_ai_prompt';
  static readonly LAST_STRATEGY_EXPLANATION = 'last_strategy_explanation';
  static readonly STRATEGY_DENSITY = 'strategy_density';
  static readonly STRATEGY_PACE = 'strategy_pace';
  static readonly STRATEGY_PREFERENCE = 'strategy_preference';
  static readonly STRATEGY_ENERGY = 'strategy_energy';

  // ==================== 建表语句 ====================
  static readonly SQL_CREATE_TABLE = `
    CREATE TABLE IF NOT EXISTS ${PlanEntity.TABLE_NAME} (
      ${PlanEntity.ID} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${PlanEntity.NAME} TEXT NOT NULL,
      ${PlanEntity.START_DATE} INTEGER DEFAULT 0,
      ${PlanEntity.STATUS} INTEGER DEFAULT 0,
      ${PlanEntity.DEL_FLAG} INTEGER DEFAULT 0,
      ${PlanEntity.DELETE_TIME} INTEGER DEFAULT 0,
      ${PlanEntity.COVER_COLOR} TEXT,
      ${PlanEntity.LAST_EXPORT_TIME} INTEGER DEFAULT 0,
      ${PlanEntity.ENABLE_AUTO_AMAP_ROUTE} INTEGER DEFAULT 1,
      ${PlanEntity.CREATED_AT} INTEGER NOT NULL,
      ${PlanEntity.STRATEGY_MODE} INTEGER DEFAULT 0,
      ${PlanEntity.STRATEGY_VERSION} INTEGER DEFAULT 1,
      ${PlanEntity.LAST_AI_PROMPT} TEXT,
      ${PlanEntity.LAST_STRATEGY_EXPLANATION} TEXT,
      ${PlanEntity.STRATEGY_DENSITY} INTEGER DEFAULT 1,
      ${PlanEntity.STRATEGY_PACE} INTEGER DEFAULT 1,
      ${PlanEntity.STRATEGY_PREFERENCE} INTEGER DEFAULT 0,
      ${PlanEntity.STRATEGY_ENERGY} INTEGER DEFAULT 1
    )
  `;
}
