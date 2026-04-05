import { drawing } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';

// 分享图片选项
export interface ShareImageOptions {
  planTitle: string;
  startDate: number;
  endDate: number;
  totalDays: number;
  totalEvents: number;
  events: ShareEventItem[];
  qrCodePixelMap: image.PixelMap;
  authorName?: string;
  shareDate: number;
}

// 分享事件项
export interface ShareEventItem {
  name: string;
  dayOffset: number;
  startTime: string;
  endTime: string;
  duration: number;
  icon: string;
  location: string;
  category: string;
}

/**
 * 计划分享图片渲染服务
 */
export class PlanShareImageService {
  // 画布配置
  private static readonly CANVAS_WIDTH = 750;
  private static readonly CANVAS_HEIGHT = 1334;

  // 颜色配置
  private static readonly COLOR_BG = '#FFFFFF';
  private static readonly COLOR_PRIMARY = '#1A1A1A';
  private static readonly COLOR_SECONDARY = '#666666';
  private static readonly COLOR_BORDER = '#E5E5E5';
  private static readonly COLOR_TIMELINE = '#4A90E2';

  // 间距配置
  private static readonly PADDING = 40;
  private static readonly CARD_MARGIN = 20;

  /**
   * 渲染分享图片
   */
  public static async renderShareImage(options: ShareImageOptions): Promise<image.PixelMap> {
    // 创建画布
    const canvas = PlanShareImageService.createCanvas();

    // 绘制背景
    PlanShareImageService.drawBackground(canvas);

    // 绘制头部
    let yOffset = PlanShareImageService.drawHeader(canvas, options);

    // 绘制分隔线
    yOffset = PlanShareImageService.drawDivider(canvas, yOffset);

    // 绘制事件卡片（最多3天）
    yOffset = PlanShareImageService.drawEventCards(canvas, options, yOffset);

    // 绘制底部
    PlanShareImageService.drawFooter(canvas, options, yOffset);

    // 转换为 PixelMap
    return PlanShareImageService.canvasToPixelMap(canvas);
  }

  private static createCanvas(): drawing.Canvas {
    const bitmap = new drawing.Bitmap();
    bitmap.build(PlanShareImageService.CANVAS_WIDTH, PlanShareImageService.CANVAS_HEIGHT, {
      colorType: drawing.ColorType.RGBA_8888,
      alphaType: drawing.AlphaType.OPAQUE
    });
    return new drawing.Canvas(bitmap);
  }

  private static drawBackground(canvas: drawing.Canvas): void {
    // 绘制白色背景
    const paint = new drawing.Pen();
    paint.setColor({ alpha: 255, red: 255, green: 255, blue: 255 });
    canvas.drawRect({
      left: 0,
      top: 0,
      right: PlanShareImageService.CANVAS_WIDTH,
      bottom: PlanShareImageService.CANVAS_HEIGHT
    });
  }

  private static drawHeader(canvas: drawing.Canvas, options: ShareImageOptions): number {
    let y = PlanShareImageService.PADDING;
    const dateStr = PlanShareImageService.formatDateRange(options.startDate, options.endDate);
    const statsStr = `📅 ${dateStr}  |  ${options.totalDays}天${options.totalDays - 1}晚 · ${options.totalEvents}个景点`;

    PlanShareImageService.drawText(canvas, `🗺️  ${options.planTitle}`, PlanShareImageService.PADDING, y, 48);
    y += 70;
    PlanShareImageService.drawText(canvas, statsStr, PlanShareImageService.PADDING, y, 28);
    y += 50;
    return y;
  }

  private static drawDivider(canvas: drawing.Canvas, y: number): number {
    const pen = new drawing.Pen();
    pen.setColor(PlanShareImageService.hexToColor(PlanShareImageService.COLOR_BORDER));
    pen.setStrokeWidth(2);
    canvas.attachPen(pen);
    canvas.drawLine(PlanShareImageService.PADDING, y, PlanShareImageService.CANVAS_WIDTH - PlanShareImageService.PADDING, y);
    canvas.detachPen();
    return y + 30;
  }

  private static drawEventCards(canvas: drawing.Canvas, options: ShareImageOptions, startY: number): number {
    let y = startY;
    const eventsByDay = PlanShareImageService.groupEventsByDay(options.events);
    const maxDays = 3;
    const daysToShow = Math.min(eventsByDay.length, maxDays);

    for (let i = 0; i < daysToShow; i++) {
      const dayEvents = eventsByDay[i];
      y = PlanShareImageService.drawDayCard(canvas, dayEvents, options.startDate, i, y);
      y += PlanShareImageService.CARD_MARGIN;
    }

    if (eventsByDay.length > maxDays) {
      const remaining = eventsByDay.length - maxDays;
      PlanShareImageService.drawText(canvas, `... 还有${remaining}天精彩行程`, PlanShareImageService.PADDING, y, 28);
      y += 50;
    }

    return y;
  }

  private static drawFooter(canvas: drawing.Canvas, options: ShareImageOptions, y: number): void {
    const footerY = PlanShareImageService.CANVAS_HEIGHT - 200;

    // 绘制提示文本
    PlanShareImageService.drawText(canvas, '💡 AI 智能规划', PlanShareImageService.PADDING, footerY, 24);

    // 绘制作者信息（如果有）
    if (options.authorName) {
      PlanShareImageService.drawText(canvas, `👤 @${options.authorName}`, PlanShareImageService.PADDING, footerY + 40, 24);
    }

    // 绘制扫码提示
    PlanShareImageService.drawText(canvas, '扫码导入到你的旅行计划 →', PlanShareImageService.PADDING, footerY + 80, 24);

    // 绘制二维码（右下角）
    // TODO: 实际绘制 PixelMap
  }

  private static groupEventsByDay(events: ShareEventItem[]): ShareEventItem[][] {
    const grouped: Map<number, ShareEventItem[]> = new Map();

    for (const event of events) {
      const day = event.dayOffset;
      if (!grouped.has(day)) {
        grouped.set(day, []);
      }
      grouped.get(day)!.push(event);
    }

    return Array.from(grouped.values());
  }

  private static drawDayCard(canvas: drawing.Canvas, events: ShareEventItem[], startDate: number, dayIndex: number, y: number): number {
    const cardX = PlanShareImageService.PADDING;
    const cardWidth = PlanShareImageService.CANVAS_WIDTH - 2 * PlanShareImageService.PADDING;
    let cardY = y;

    // 绘制卡片边框
    const pen = new drawing.Pen();
    pen.setColor(PlanShareImageService.hexToColor(PlanShareImageService.COLOR_BORDER));
    pen.setStrokeWidth(2);
    canvas.attachPen(pen);

    const cardHeight = 40 + events.length * 100;
    canvas.drawRect({ left: cardX, top: cardY, right: cardX + cardWidth, bottom: cardY + cardHeight });
    canvas.detachPen();

    // 绘制日期标题
    const date = new Date(startDate + dayIndex * 24 * 60 * 60 * 1000);
    const dateStr = `${date.getMonth() + 1}月${date.getDate()}日`;
    PlanShareImageService.drawText(canvas, `Day ${dayIndex + 1} ─────────────── ${dateStr}`, cardX + 20, cardY + 30, 28);
    cardY += 60;

    // 绘制事件列表
    for (const event of events) {
      cardY = PlanShareImageService.drawEventItem(canvas, event, cardX + 20, cardY);
    }

    return cardY + 20;
  }

  private static drawEventItem(canvas: drawing.Canvas, event: ShareEventItem, x: number, y: number): number {
    // 绘制时间线
    PlanShareImageService.drawText(canvas, `${event.startTime} ━━━━━━━━ ${event.endTime}`, x, y, 24);

    // 绘制事件名称
    PlanShareImageService.drawText(canvas, `${event.icon}  ${event.name}`, x, y + 35, 28);

    // 绘制位置和分类
    PlanShareImageService.drawText(canvas, `📍 ${event.location}  |  ⏱️ ${event.duration}h  |  ${event.category}`, x, y + 65, 22);

    return y + 100;
  }

  private static drawText(canvas: drawing.Canvas, text: string, x: number, y: number, size: number): void {
    const font = new drawing.Font();
    font.setSize(size);

    const textBlob = drawing.TextBlob.makeFromString(text, font, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    const brush = new drawing.Brush();
    brush.setColor(PlanShareImageService.hexToColor(PlanShareImageService.COLOR_PRIMARY));

    canvas.attachBrush(brush);
    canvas.drawTextBlob(textBlob, x, y);
    canvas.detachBrush();
  }

  private static formatDateRange(start: number, end: number): string {
    const startDate = new Date(start);
    const endDate = new Date(end);
    return `${startDate.getFullYear()}.${String(startDate.getMonth() + 1).padStart(2, '0')}.${String(startDate.getDate()).padStart(2, '0')} - ${String(endDate.getMonth() + 1).padStart(2, '0')}.${String(endDate.getDate()).padStart(2, '0')}`;
  }

  private static hexToColor(hex: string): { alpha: number; red: number; green: number; blue: number } {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return { alpha: 255, red: r, green: g, blue: b };
  }

  private static async canvasToPixelMap(canvas: drawing.Canvas): Promise<image.PixelMap> {
    const bitmap = canvas.getBitmap();
    const pixels = new Uint8Array(PlanShareImageService.CANVAS_WIDTH * PlanShareImageService.CANVAS_HEIGHT * 4);
    bitmap.readPixels(pixels.buffer);

    const imageInfo: image.ImageInfo = {
      size: { height: PlanShareImageService.CANVAS_HEIGHT, width: PlanShareImageService.CANVAS_WIDTH },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.OPAQUE
    };

    const pixelMap = await image.createPixelMap(pixels.buffer, imageInfo);
    return pixelMap;
  }
}
