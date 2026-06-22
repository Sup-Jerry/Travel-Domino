import { drawing } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';

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

interface RgbaColor {
  alpha: number;
  red: number;
  green: number;
  blue: number;
}

interface DayGroup {
  dayOffset: number;
  events: ShareEventItem[];
}

export class PlanShareImageService {
  private static readonly CANVAS_WIDTH = 750;
  private static readonly CANVAS_HEIGHT = 1334;
  private static readonly PADDING = 40;
  private static readonly EVENT_LINE_HEIGHT = 26;
  private static readonly FOOTER_RESERVED_HEIGHT = 250;
  private static readonly QR_SIZE = 180;
  private static readonly MAX_EVENTS_PER_DAY = 8;

  private static readonly COLOR_BG: RgbaColor = { alpha: 255, red: 255, green: 255, blue: 255 };
  private static readonly COLOR_PRIMARY: RgbaColor = { alpha: 255, red: 26, green: 26, blue: 26 };
  private static readonly COLOR_SECONDARY: RgbaColor = { alpha: 255, red: 102, green: 102, blue: 102 };
  private static readonly COLOR_BORDER: RgbaColor = { alpha: 255, red: 229, green: 229, blue: 229 };
  private static readonly COLOR_TAG_BG: RgbaColor = { alpha: 255, red: 246, green: 248, blue: 252 };

  public static async renderShareImage(options: ShareImageOptions): Promise<image.PixelMap> {
    const targetMap = await PlanShareImageService.createCanvasPixelMap();
    const canvas = new drawing.Canvas(targetMap);

    PlanShareImageService.drawBackground(canvas);
    let cursorY = PlanShareImageService.drawHeader(canvas, options);
    cursorY = PlanShareImageService.drawDivider(canvas, cursorY);
    cursorY = PlanShareImageService.drawEventSection(canvas, options.events, cursorY);
    PlanShareImageService.drawFooter(canvas, options, cursorY);

    return targetMap;
  }

  private static async createCanvasPixelMap(): Promise<image.PixelMap> {
    const totalBytes = PlanShareImageService.CANVAS_WIDTH * PlanShareImageService.CANVAS_HEIGHT * 4;
    const buffer = new Uint8Array(totalBytes);
    for (let i = 0; i < totalBytes; i += 4) {
      buffer[i] = 255;
      buffer[i + 1] = 255;
      buffer[i + 2] = 255;
      buffer[i + 3] = 255;
    }

    const initOptions: image.InitializationOptions = {
      size: {
        width: PlanShareImageService.CANVAS_WIDTH,
        height: PlanShareImageService.CANVAS_HEIGHT
      },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.OPAQUE,
      editable: true
    };
    return image.createPixelMap(buffer.buffer, initOptions);
  }

  private static drawBackground(canvas: drawing.Canvas): void {
    const brush = new drawing.Brush();
    PlanShareImageService.applyColorToBrush(brush, PlanShareImageService.COLOR_BG);
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, PlanShareImageService.CANVAS_WIDTH, PlanShareImageService.CANVAS_HEIGHT);
    canvas.detachBrush();
  }

  private static drawHeader(canvas: drawing.Canvas, options: ShareImageOptions): number {
    let y = PlanShareImageService.PADDING + 36;
    const title = options.planTitle.trim().length > 0 ? options.planTitle.trim() : 'Travel Plan';
    const dateText = PlanShareImageService.formatDateRange(options.startDate, options.endDate);
    const stats = `${Math.max(1, options.totalDays)} days · ${Math.max(0, options.totalEvents)} events`;

    PlanShareImageService.drawText(canvas, title, PlanShareImageService.PADDING, y, 40, PlanShareImageService.COLOR_PRIMARY);
    y += 42;
    PlanShareImageService.drawText(canvas, dateText, PlanShareImageService.PADDING, y, 24, PlanShareImageService.COLOR_SECONDARY);
    y += 30;
    PlanShareImageService.drawText(canvas, stats, PlanShareImageService.PADDING, y, 24, PlanShareImageService.COLOR_SECONDARY);
    return y + 28;
  }

  private static drawDivider(canvas: drawing.Canvas, y: number): number {
    const pen = new drawing.Pen();
    PlanShareImageService.applyColorToPen(pen, PlanShareImageService.COLOR_BORDER);
    pen.setStrokeWidth(2);
    canvas.attachPen(pen);
    canvas.drawLine(
      PlanShareImageService.PADDING,
      y,
      PlanShareImageService.CANVAS_WIDTH - PlanShareImageService.PADDING,
      y
    );
    canvas.detachPen();
    return y + 30;
  }

  private static drawEventSection(canvas: drawing.Canvas, events: ShareEventItem[], startY: number): number {
    const grouped = PlanShareImageService.groupEventsByDay(events);
    let y = startY;
    const maxContentY = PlanShareImageService.CANVAS_HEIGHT - PlanShareImageService.FOOTER_RESERVED_HEIGHT;
    let dayRendered = 0;

    for (const dayGroup of grouped) {
      if (y + 120 > maxContentY) {
        break;
      }
      dayRendered += 1;
      y = PlanShareImageService.drawDayBlock(canvas, dayGroup, y, maxContentY);
      y += 14;
      if (y >= maxContentY) {
        break;
      }
    }

    if (dayRendered < grouped.length) {
      PlanShareImageService.drawText(
        canvas,
        `+ ${grouped.length - dayRendered} more days`,
        PlanShareImageService.PADDING,
        Math.min(maxContentY - 10, y + 24),
        22,
        PlanShareImageService.COLOR_SECONDARY
      );
    }

    return y;
  }

  private static drawDayBlock(canvas: drawing.Canvas, dayGroup: DayGroup, startY: number, maxY: number): number {
    let y = startY;
    const cardLeft = PlanShareImageService.PADDING;
    const cardRight = PlanShareImageService.CANVAS_WIDTH - PlanShareImageService.PADDING;

    const shownEvents = dayGroup.events.slice(0, PlanShareImageService.MAX_EVENTS_PER_DAY);
    const hiddenCount = Math.max(0, dayGroup.events.length - shownEvents.length);
    const cardHeight = 52 + shownEvents.length * 82 + (hiddenCount > 0 ? 30 : 0);
    const cardBottom = Math.min(maxY, y + cardHeight);

    const backgroundBrush = new drawing.Brush();
    PlanShareImageService.applyColorToBrush(backgroundBrush, PlanShareImageService.COLOR_TAG_BG);
    canvas.attachBrush(backgroundBrush);
    canvas.drawRect(cardLeft, y, cardRight, cardBottom);
    canvas.detachBrush();

    const borderPen = new drawing.Pen();
    PlanShareImageService.applyColorToPen(borderPen, PlanShareImageService.COLOR_BORDER);
    borderPen.setStrokeWidth(1);
    canvas.attachPen(borderPen);
    canvas.drawRect(cardLeft, y, cardRight, cardBottom);
    canvas.detachPen();

    let lineY = y + 32;
    PlanShareImageService.drawText(
      canvas,
      `Day ${dayGroup.dayOffset + 1}`,
      cardLeft + 20,
      lineY,
      26,
      PlanShareImageService.COLOR_PRIMARY
    );
    lineY += 30;

    for (const eventItem of shownEvents) {
      if (lineY + 56 > cardBottom) {
        break;
      }
      lineY = PlanShareImageService.drawEventLine(canvas, eventItem, cardLeft + 20, lineY);
    }

    if (hiddenCount > 0 && lineY + 20 < cardBottom) {
      PlanShareImageService.drawText(
        canvas,
        `... ${hiddenCount} events omitted`,
        cardLeft + 20,
        lineY + 20,
        20,
        PlanShareImageService.COLOR_SECONDARY
      );
    }

    return cardBottom;
  }

  private static drawEventLine(canvas: drawing.Canvas, eventItem: ShareEventItem, x: number, y: number): number {
    const title = `${eventItem.icon} ${eventItem.name}`.trim();
    const timeline = `${eventItem.startTime} - ${eventItem.endTime}`;
    const subline = `${eventItem.location} · ${eventItem.duration}h · ${eventItem.category}`;

    PlanShareImageService.drawText(canvas, title, x, y + 24, 24, PlanShareImageService.COLOR_PRIMARY);
    PlanShareImageService.drawText(canvas, timeline, x, y + 46, 20, PlanShareImageService.COLOR_SECONDARY);
    PlanShareImageService.drawText(canvas, subline, x, y + 68, 20, PlanShareImageService.COLOR_SECONDARY);
    return y + 82;
  }

  private static drawFooter(canvas: drawing.Canvas, options: ShareImageOptions, contentY: number): void {
    const footerTop = Math.max(
      PlanShareImageService.CANVAS_HEIGHT - PlanShareImageService.FOOTER_RESERVED_HEIGHT,
      contentY + 10
    );
    const qrLeft = PlanShareImageService.CANVAS_WIDTH - PlanShareImageService.PADDING - PlanShareImageService.QR_SIZE;
    const qrTop = footerTop + 24;

    const dividerPen = new drawing.Pen();
    PlanShareImageService.applyColorToPen(dividerPen, PlanShareImageService.COLOR_BORDER);
    dividerPen.setStrokeWidth(2);
    canvas.attachPen(dividerPen);
    canvas.drawLine(
      PlanShareImageService.PADDING,
      footerTop,
      PlanShareImageService.CANVAS_WIDTH - PlanShareImageService.PADDING,
      footerTop
    );
    canvas.detachPen();

    PlanShareImageService.drawText(
      canvas,
      'Scan to import this plan',
      PlanShareImageService.PADDING,
      footerTop + 42,
      24,
      PlanShareImageService.COLOR_PRIMARY
    );

    const date = new Date(options.shareDate);
    PlanShareImageService.drawText(
      canvas,
      `Generated at ${date.getFullYear()}-${PlanShareImageService.pad(date.getMonth() + 1)}-${PlanShareImageService.pad(date.getDate())}`,
      PlanShareImageService.PADDING,
      footerTop + 72,
      20,
      PlanShareImageService.COLOR_SECONDARY
    );

    if (options.authorName && options.authorName.trim().length > 0) {
      PlanShareImageService.drawText(
        canvas,
        `Author: ${options.authorName.trim()}`,
        PlanShareImageService.PADDING,
        footerTop + 100,
        20,
        PlanShareImageService.COLOR_SECONDARY
      );
    }

    canvas.drawImageRect(
      options.qrCodePixelMap,
      {
        left: qrLeft,
        top: qrTop,
        right: qrLeft + PlanShareImageService.QR_SIZE,
        bottom: qrTop + PlanShareImageService.QR_SIZE
      }
    );
  }

  private static drawText(
    canvas: drawing.Canvas,
    text: string,
    x: number,
    y: number,
    size: number,
    color: RgbaColor
  ): void {
    const normalized = text.trim();
    if (normalized.length === 0) {
      return;
    }
    const font = new drawing.Font();
    font.setSize(size);
    const blob = drawing.TextBlob.makeFromString(normalized, font, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    const brush = new drawing.Brush();
    PlanShareImageService.applyColorToBrush(brush, color);
    canvas.attachBrush(brush);
    canvas.drawTextBlob(blob, x, y);
    canvas.detachBrush();
  }

  private static groupEventsByDay(events: ShareEventItem[]): DayGroup[] {
    const buckets: Map<number, ShareEventItem[]> = new Map<number, ShareEventItem[]>();
    const sorted = events.slice().sort((left: ShareEventItem, right: ShareEventItem): number => {
      if (left.dayOffset !== right.dayOffset) {
        return left.dayOffset - right.dayOffset;
      }
      return left.startTime.localeCompare(right.startTime);
    });

    for (const eventItem of sorted) {
      const day = Math.max(0, Math.floor(eventItem.dayOffset));
      if (!buckets.has(day)) {
        buckets.set(day, []);
      }
      buckets.get(day)!.push(eventItem);
    }

    const entries = Array.from(buckets.entries()).sort((left, right) => left[0] - right[0]);
    const groups: DayGroup[] = [];
    for (const entry of entries) {
      const group: DayGroup = {
        dayOffset: entry[0],
        events: entry[1]
      };
      groups.push(group);
    }
    return groups;
  }

  private static formatDateRange(start: number, end: number): string {
    const startDate = new Date(start);
    const endDate = new Date(end);
    const startText = `${startDate.getFullYear()}-${PlanShareImageService.pad(startDate.getMonth() + 1)}-${PlanShareImageService.pad(startDate.getDate())}`;
    const endText = `${endDate.getFullYear()}-${PlanShareImageService.pad(endDate.getMonth() + 1)}-${PlanShareImageService.pad(endDate.getDate())}`;
    return `${startText} ~ ${endText}`;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static applyColorToPen(pen: drawing.Pen, color: RgbaColor): void {
    pen.setColor(color.alpha, color.red, color.green, color.blue);
  }

  private static applyColorToBrush(brush: drawing.Brush, color: RgbaColor): void {
    brush.setColor(color.alpha, color.red, color.green, color.blue);
  }
}
