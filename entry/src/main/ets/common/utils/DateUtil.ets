import { hilog } from '@kit.PerformanceAnalysisKit';

export class DateUtil {
  // 静态常量
  private static DAY_MINUTES: number = 24 * 60;
  private static readonly TAG: string = 'DateUtil';

  /**
   * 提取时间表达式中的纯 HH:mm
   * 支持:
   * - "09:00"
   * - "12-21 09:00"
   * - "次日 09:00"
   */
  public static extractPureTime(timeStr: string): string {
    if (!timeStr) {
      return '';
    }

    const trimmed = timeStr.trim();
    const match = trimmed.match(/(\d{1,2}:\d{2})/);
    if (!match || match.length < 2) {
      return '';
    }

    return match[1];
  }

  /**
   * 判断时间表达式是否合法
   */
  public static isValidTimeString(timeStr: string): boolean {
    const pureTime = DateUtil.extractPureTime(timeStr);
    if (!pureTime) {
      return false;
    }

    const parts: string[] = pureTime.split(':');
    if (parts.length !== 2) {
      return false;
    }

    const hours: number = parseInt(parts[0], 10);
    const minutes: number = parseInt(parts[1], 10);

    if (isNaN(hours) || isNaN(minutes)) {
      return false;
    }

    return hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59;
  }

  /**
   * 获取跨天偏移
   * 当前仅确认并支持“次日”语义
   */
  public static getDayShift(timeStr: string): number {
    if (!timeStr) {
      return 0;
    }

    return timeStr.includes('次日') ? 1 : 0;
  }

  /**
   * 将时间表达式转换为分钟数
   * 支持:
   * - "HH:mm"
   * - "MM-dd HH:mm"
   * - "次日 HH:mm"
   *
   * 返回值仅表示“当天内的分钟数”，不包含跨天偏移。
   * 跨天偏移请配合 getDayShift() 使用。
   */
  public static timeToMinutes(timeStr: string): number {
    const pureTime = DateUtil.extractPureTime(timeStr);
    if (!pureTime) {
      return 0;
    }

    const parts: string[] = pureTime.split(':');
    const hours: number = parseInt(parts[0], 10);
    const minutes: number = parseInt(parts[1], 10);

    if (isNaN(hours) || isNaN(minutes)) {
      return 0;
    }

    return hours * 60 + minutes;
  }

  /**
   * [Day 3 新增] 真实的日期格式化
   * 解决“炸弹三”，支持显示 "12-21 09:00"
   */
  public static formatRealTime(baseDate: Date, offsetMinutes: number): string {
    // 克隆日期对象，加上偏移分钟
    const target = new Date(baseDate.getTime() + offsetMinutes * 60 * 1000);

    const month = (target.getMonth() + 1).toString().padStart(2, '0');
    const day = target.getDate().toString().padStart(2, '0');
    const hour = target.getHours().toString().padStart(2, '0');
    const minute = target.getMinutes().toString().padStart(2, '0');

    // 修复：比较同一天时必须同时比较 年、月、日，防止跨月/跨年同“日号”误判。
    const isSameDay = DateUtil.isSameCalendarDay(target, baseDate);

    hilog.info(
      0x0000,
      DateUtil.TAG,
      `[DATE_TRACE][formatRealTime] baseYMD=${DateUtil.toYmd(baseDate)}, targetYMD=${DateUtil.toYmd(target)}, offsetMinutes=${offsetMinutes}, isSameDay=${isSameDay}`
    );

    if (isSameDay) {
      return `${hour}:${minute}`;
    } else {
      return `${month}-${day} ${hour}:${minute}`;
    }
  }

  /**
   * 验收辅助：应用启动时可调用，验证跨月/跨年格式化行为。
   */
  public static logBoundarySelfCheck(): void {
    const crossMonthBase = new Date(2026, 0, 31, 23, 50, 0, 0);
    const crossYearBase = new Date(2026, 11, 31, 23, 50, 0, 0);

    const crossMonthResult = DateUtil.formatRealTime(crossMonthBase, 20);
    const crossYearResult = DateUtil.formatRealTime(crossYearBase, 20);

    hilog.info(
      0x0000,
      DateUtil.TAG,
      `[DATE_TRACE][selfCheck] crossMonthResult=${crossMonthResult}, crossYearResult=${crossYearResult}`
    );
  }

  /**
   * 旧方法保留 (兼容旧代码)
   */
  public static minutesToTime(totalMinutes: number): string {
    const days: number = Math.floor(totalMinutes / DateUtil.DAY_MINUTES);
    const remainingMinutes: number = totalMinutes % DateUtil.DAY_MINUTES;

    const h: number = Math.floor(remainingMinutes / 60);
    const m: number = remainingMinutes % 60;

    const timeStr: string = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;

    if (days > 0) {
      return `次日 ${timeStr}`;
    }
    return timeStr;
  }

  /**
   * 基础加法
   */
  public static addMinutes(baseTimeStr: string, minutesToAdd: number): number {
    const base: number = DateUtil.timeToMinutes(baseTimeStr);
    return base + minutesToAdd;
  }

  /**
   * [Priority 4 新增] 通用日期格式化
   * ✅ [修复] 增加对 'MM月dd日' 的支持
   */
  public static formatDate(date: Date, format: string): string {
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    const h = date.getHours().toString().padStart(2, '0');
    const mi = date.getMinutes().toString().padStart(2, '0');

    if (format === 'MM月dd日') {
      return `${m}月${d}日`;
    }

    if (format === 'MM-dd HH:mm') {
      return `${m}-${d} ${h}:${mi}`;
    }
    if (format === 'HH:mm') {
      return `${h}:${mi}`;
    }

    return `${h}:${mi}`;
  }

  public static formatPlanDate(timestamp: number | undefined): string {
    if (!timestamp) {
      return '待定';
    }
    const date = new Date(timestamp);
    return DateUtil.formatMonthDay(date);
  }

  public static formatLocalDate(timestamp: number | undefined): string {
    if (!timestamp) {
      return '--';
    }
    const date = new Date(timestamp);
    const y = date.getFullYear().toString();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  public static formatMonthDay(date: Date): string {
    const m = (date.getMonth() + 1).toString();
    const d = date.getDate().toString();
    return `${m}月${d}日`;
  }

  /**
   * [Priority 1 新增] 获取分组标题
   * @param baseDate 计划开始的基准日期
   * @param minutesFromStart 从第0天0点开始累计的分钟数
   * @returns 格式如 "12月20日 周五"
   */
  public static getDateHeader(baseDate: Date, minutesFromStart: number): string {
    const target = new Date(baseDate.getTime());
    target.setTime(target.getTime() + minutesFromStart * 60 * 1000);

    const m = (target.getMonth() + 1).toString();
    const d = target.getDate().toString();

    const weeks = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const w = weeks[target.getDay()];

    return `${m}月${d}日 ${w}`;
  }

  /**
   * 计算结束时间
   * 支持开始时间为:
   * - "HH:mm"
   * - "MM-dd HH:mm"
   * - "次日 HH:mm"
   */
  public static calculateEndTime(startTimeStr: string | undefined, durationMinutes: number): string {
    if (!startTimeStr || !DateUtil.isValidTimeString(startTimeStr)) {
      return '--:--';
    }

    const startMinutes: number =
      DateUtil.timeToMinutes(startTimeStr) + DateUtil.getDayShift(startTimeStr) * DateUtil.DAY_MINUTES;

    const safeDuration: number = durationMinutes > 0 ? durationMinutes : 0;
    const totalEndMin: number = startMinutes + safeDuration;

    return DateUtil.minutesToTime(totalEndMin);
  }

  private static isSameCalendarDay(left: Date, right: Date): boolean {
    return left.getFullYear() === right.getFullYear() &&
      left.getMonth() === right.getMonth() &&
      left.getDate() === right.getDate();
  }

  private static toYmd(date: Date): string {
    const year = date.getFullYear().toString().padStart(4, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
