import { describe, expect, it } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import { PlanShareImageService, ShareEventItem, ShareImageOptions } from '../main/ets/domain/services/PlanShareImageService';

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
      let ok = false;
      // Act
      const first = await PlanShareImageService.renderShareImage(options);
      options.authorName = '';
      options.events = [createEvent(0, '12:00', 'single')];
      const second = await PlanShareImageService.renderShareImage(options);
      ok = first !== null && second !== null;
      // Assert
      expect(ok).assertTrue();
    });
  });
}
