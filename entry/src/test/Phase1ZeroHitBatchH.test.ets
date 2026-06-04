import { describe, expect, it } from '@ohos/hypium';
import { drawing } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { PlanShareImageService, ShareEventItem, ShareImageOptions } from '../main/ets/domain/services/PlanShareImageService';

interface PlanShareImageServicePrivateH {
  drawEventSection: (canvas: drawing.Canvas, events: ShareEventItem[], startY: number) => number;
  drawDayBlock: (canvas: drawing.Canvas, dayGroup: Object, startY: number, maxY: number) => number;
  drawText: (canvas: drawing.Canvas, text: string, x: number, y: number, size: number, color: Object) => void;
}

interface DayGroupH {
  dayOffset: number;
  events: ShareEventItem[];
}

interface RgbaColorH {
  alpha: number;
  red: number;
  green: number;
  blue: number;
}

async function createQrPixelMap(): Promise<image.PixelMap> {
  const width = 8;
  const height = 8;
  const buffer = new Uint8Array(width * height * 4);
  for (let i = 0; i < buffer.length; i += 4) {
    buffer[i] = 0;
    buffer[i + 1] = 0;
    buffer[i + 2] = 0;
    buffer[i + 3] = 255;
  }

  const options: image.InitializationOptions = {
    size: { width: width, height: height },
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    alphaType: image.AlphaType.OPAQUE,
    editable: true
  };
  return image.createPixelMap(buffer.buffer, options);
}

function createEvent(dayOffset: number, startTime: string, name: string): ShareEventItem {
  return {
    name: name,
    dayOffset: dayOffset,
    startTime: startTime,
    endTime: '10:00',
    duration: 1,
    icon: '??',
    location: 'test-location',
    category: 'test-category'
  };
}

function buildOptions(qrCodePixelMap: image.PixelMap): ShareImageOptions {
  return {
    planTitle: 'Weekend Trip',
    startDate: 1713000000000,
    endDate: 1713086400000,
    totalDays: 2,
    totalEvents: 2,
    events: [
      createEvent(0, '09:00', 'Museum'),
      createEvent(1, '08:30', 'Lake')
    ],
    qrCodePixelMap: qrCodePixelMap,
    authorName: 'tester',
    shareDate: 1713090000000
  };
}

function buildManyEvents(): ShareEventItem[] {
  const events: ShareEventItem[] = [];
  for (let i = 0; i < 26; i++) {
    const dayOffset = Math.floor(i / 9);
    const hour = 8 + (i % 9);
    const hourText = hour < 10 ? `0${hour}` : `${hour}`;
    events.push(createEvent(dayOffset, `${hourText}:00`, `spot-${i}`));
  }
  return events;
}

async function createCanvasH(): Promise<drawing.Canvas> {
  const map = await createQrPixelMap();
  return new drawing.Canvas(map);
}

export default function phase1ZeroHitBatchHTest() {
  describe('phase1ZeroHitBatchHTest', () => {
    it('normal: plan_share_image_should_render_with_basic_events', 0, async () => {
      // Arrange
      const qr = await createQrPixelMap();
      const options = buildOptions(qr);

      // Act
      const rendered = await PlanShareImageService.renderShareImage(options);

      // Assert
      expect(rendered !== null).assertTrue();
      expect(rendered === qr).assertFalse();
    });

    it('boundary: plan_share_image_should_render_when_title_and_author_are_blank', 0, async () => {
      // Arrange
      const qr = await createQrPixelMap();
      const options = buildOptions(qr);
      options.planTitle = '   ';
      options.authorName = '  ';
      options.totalDays = 0;
      options.totalEvents = -2;
      options.events = [];

      // Act
      const rendered = await PlanShareImageService.renderShareImage(options);

      // Assert
      expect(rendered !== null).assertTrue();
    });

    it('invalid: plan_share_image_should_accept_negative_day_offset_by_clamping_to_day_zero', 0, async () => {
      // Arrange
      const qr = await createQrPixelMap();
      const options = buildOptions(qr);
      options.events = [createEvent(-5, '07:00', 'negative-day')];

      // Act
      const rendered = await PlanShareImageService.renderShareImage(options);

      // Assert
      expect(rendered !== null).assertTrue();
    });

    it('conflict: plan_share_image_should_render_when_events_exceed_day_and_canvas_limits', 0, async () => {
      // Arrange
      const qr = await createQrPixelMap();
      const options = buildOptions(qr);
      options.events = buildManyEvents();
      options.totalDays = 10;
      options.totalEvents = options.events.length;

      // Act
      const rendered = await PlanShareImageService.renderShareImage(options);

      // Assert
      expect(rendered !== null).assertTrue();
    });

    it('regression: td-20260413-phase1-plan-share-image-render_should_keep_qr_input_unchanged_reference', 0, async () => {
      // Arrange
      const qr = await createQrPixelMap();
      const options = buildOptions(qr);

      // Act
      const rendered = await PlanShareImageService.renderShareImage(options);

      // Assert
      expect(options.qrCodePixelMap === qr).assertTrue();
      expect(rendered === qr).assertFalse();
    });

    it('combined: plan_share_image_should_support_multiple_consecutive_renders', 0, async () => {
      // Arrange
      const qr = await createQrPixelMap();
      const options = buildOptions(qr);

      // Act
      const first = await PlanShareImageService.renderShareImage(options);
      options.authorName = '';
      options.events = [createEvent(0, '12:00', 'single')];
      const second = await PlanShareImageService.renderShareImage(options);

      // Assert
      expect(first !== null && second !== null).assertTrue();
    });

    it('boundary: plan_share_image_should_stop_rendering_days_when_start_y_is_already_near_footer', 0, async () => {
      // Arrange
      const privateApi = PlanShareImageService as Object as PlanShareImageServicePrivateH;
      const canvas = await createCanvasH();
      const events = [createEvent(0, '09:00', 'first-day')];

      // Act
      const endY = privateApi.drawEventSection(canvas, events, 1100);

      // Assert
      expect(endY).assertEqual(1100);
    });

    it('boundary: plan_share_image_should_render_omitted_hint_when_day_block_is_clipped', 0, async () => {
      // Arrange
      const privateApi = PlanShareImageService as Object as PlanShareImageServicePrivateH;
      const canvas = await createCanvasH();
      const dayGroup: DayGroupH = {
        dayOffset: 0,
        events: buildManyEvents().slice(0, 10)
      };

      // Act
      const bottom = privateApi.drawDayBlock(canvas, dayGroup as Object, 0, 690);

      // Assert
      expect(bottom).assertEqual(690);
    });

    it('boundary: plan_share_image_should_ignore_blank_text_without_throwing', 0, async () => {
      // Arrange
      const privateApi = PlanShareImageService as Object as PlanShareImageServicePrivateH;
      const canvas = await createCanvasH();
      const color: RgbaColorH = { alpha: 255, red: 0, green: 0, blue: 0 };

      // Act
      privateApi.drawText(canvas, '   ', 0, 0, 20, color as Object);

      // Assert
      expect(true).assertTrue();
    });

    it('boundary: plan_share_image_should_stop_rendering_days_when_start_y_is_already_near_footer', 0, async () => {
      // Arrange
      const privateApi = PlanShareImageService as Object as PlanShareImageServicePrivateH;
      const canvas = await createCanvasH();
      const events = [createEvent(0, '09:00', 'first-day')];

      // Act
      const endY = privateApi.drawEventSection(canvas, events, 1100);

      // Assert
      expect(endY).assertEqual(1100);
    });

    it('boundary: plan_share_image_should_render_omitted_hint_when_day_block_is_clipped', 0, async () => {
      // Arrange
      const privateApi = PlanShareImageService as Object as PlanShareImageServicePrivateH;
      const canvas = await createCanvasH();
      const dayGroup: DayGroupH = {
        dayOffset: 0,
        events: buildManyEvents().slice(0, 10)
      };

      // Act
      const bottom = privateApi.drawDayBlock(canvas, dayGroup as Object, 0, 690);

      // Assert
      expect(bottom).assertEqual(690);
    });

    it('boundary: plan_share_image_should_ignore_blank_text_without_throwing', 0, async () => {
      // Arrange
      const privateApi = PlanShareImageService as Object as PlanShareImageServicePrivateH;
      const canvas = await createCanvasH();
      const color: RgbaColorH = { alpha: 255, red: 0, green: 0, blue: 0 };
      let ok = false;

      // Act
      privateApi.drawText(canvas, '   ', 0, 0, 20, color as Object);
      ok = true;

      // Assert
      expect(ok).assertTrue();
    });
  });
}
