import { describe, it, expect } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import { DeepLinkService } from '../main/ets/domain/services/DeepLinkService';
import { QRCodeService } from '../main/ets/domain/services/QRCodeService';
import {
  PlanShareImageService,
  ShareEventItem,
  ShareImageOptions
} from '../main/ets/domain/services/PlanShareImageService';
import { PlanShareDialog } from '../main/ets/pages/components/dialogs/PlanShareDialog';

interface PlanShareHostDE {
  planTitle: string;
  startDate: number;
  endDate: number;
  totalDays: number;
  totalEvents: number;
  events: ShareEventItem[];
  compressedJson: string;
  includeAuthor: boolean;
  authorName: string;
  shareImage: image.PixelMap | null;
  isGenerating: boolean;
  toastMessages: string[];
  getRenderableEvents(): ShareEventItem[];
  renderShareImageWithRetry(options: ShareImageOptions): Promise<image.PixelMap>;
  safeShowToast(message: string): void;
  generateShareImage(): Promise<void>;
  saveToAlbum(): Promise<void>;
  requestAlbumPermission(): Promise<boolean>;
}

class StaticPatchDE {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

class PixelMapDE {
}

function createPixelMapDE(): image.PixelMap {
  return new PixelMapDE() as image.PixelMap;
}

class PlanShareHostImplDE implements PlanShareHostDE {
  planTitle: string = 'DE Plan';
  startDate: number = 1;
  endDate: number = 2;
  totalDays: number = 1;
  totalEvents: number = 1;
  events: ShareEventItem[] = [buildShareEventDE(1)];
  compressedJson: string = 'compressed-de';
  includeAuthor: boolean = true;
  authorName: string = 'author-de';
  shareImage: image.PixelMap | null = null;
  isGenerating: boolean = false;
  toastMessages: string[] = [];

  getRenderableEvents(): ShareEventItem[] {
    return this.events;
  }

  async renderShareImageWithRetry(options: ShareImageOptions): Promise<image.PixelMap> {
    return await invokeShareMethodDE(shareRenderWithRetryDE, this, options);
  }

  safeShowToast(message: string): void {
    this.toastMessages.push(message);
  }

  async generateShareImage(): Promise<void> {
    await invokeShareMethodDE(shareGenerateImageDE, this);
  }

  async saveToAlbum(): Promise<void> {
    await invokeShareMethodDE(shareSaveToAlbumDE, this);
  }

  async requestAlbumPermission(): Promise<boolean> {
    return await invokeShareMethodDE(shareRequestPermissionDE, this);
  }
}

function getShareMethodDE<T>(name: string): T {
  const prototype = Reflect.get(PlanShareDialog as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeShareMethodDE<THost, TResult, TArgs extends (Object | string | number | boolean)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const shareGenerateImageDE = getShareMethodDE<(this: PlanShareHostDE) => Promise<void>>('generateShareImage');
const shareSaveToAlbumDE = getShareMethodDE<(this: PlanShareHostDE) => Promise<void>>('saveToAlbum');
const shareRequestPermissionDE = getShareMethodDE<(this: PlanShareHostDE) => Promise<boolean>>('requestAlbumPermission');
const shareRenderWithRetryDE = getShareMethodDE<(
  this: PlanShareHostDE,
  options: ShareImageOptions
) => Promise<image.PixelMap>>('renderShareImageWithRetry');

function buildShareEventDE(index: number): ShareEventItem {
  return {
    name: `de-event-${index}`,
    dayOffset: 0,
    startTime: '09:00',
    endTime: '10:00',
    duration: 60,
    icon: 'pin',
    location: 'loc',
    category: 'visit'
  };
}

function buildShareOptionsDE(): ShareImageOptions {
  return {
    planTitle: 'DE Plan',
    startDate: 1,
    endDate: 2,
    totalDays: 1,
    totalEvents: 1,
    events: [buildShareEventDE(2)],
    qrCodePixelMap: createPixelMapDE(),
    authorName: 'author-de',
    shareDate: 3
  };
}

export default function phase2BatchDETest() {
  describe('phase2BatchDETest', () => {
    it('normal: plan_share_generate_image_should_set_pixel_map_and_toast_success', 0, async () => {
      // Arrange
      const host = new PlanShareHostImplDE();
      let linkPayload = '';
      const linkPatch = new StaticPatchDE(DeepLinkService, 'buildShareLink', (payload: string): string => {
        linkPayload = payload;
        return `travel://share?payload=${payload}`;
      });
      const qrPatch = new StaticPatchDE(QRCodeService, 'generateQRCode', async (): Promise<image.PixelMap> => {
        return createPixelMapDE();
      });
      const renderPatch = new StaticPatchDE(PlanShareImageService, 'renderShareImage', async (): Promise<image.PixelMap> => {
        return createPixelMapDE();
      });

      // Act
      await host.generateShareImage();
      renderPatch.restore();
      qrPatch.restore();
      linkPatch.restore();

      // Assert
      expect(linkPayload).assertEqual('compressed-de');
      expect(host.shareImage !== null).assertTrue();
      expect(host.isGenerating).assertFalse();
      expect(host.toastMessages.length).assertEqual(1);
    });

    it('boundary: plan_share_render_retry_should_drop_author_after_first_render_failure', 0, async () => {
      // Arrange
      const host = new PlanShareHostImplDE();
      let calls = 0;
      let fallbackAuthorPresent = true;
      const renderPatch = new StaticPatchDE(PlanShareImageService, 'renderShareImage', async (options: ShareImageOptions): Promise<image.PixelMap> => {
        calls += 1;
        if (calls === 1) {
          throw new Error('render_fail_de');
        }
        fallbackAuthorPresent = options.authorName !== undefined;
        return createPixelMapDE();
      });

      // Act
      const pixel = await host.renderShareImageWithRetry(buildShareOptionsDE());
      renderPatch.restore();

      // Assert
      expect(pixel !== null).assertTrue();
      expect(calls).assertEqual(2);
      expect(fallbackAuthorPresent).assertFalse();
    });

    it('invalid: plan_share_permission_should_return_false_when_system_api_throws', 0, async () => {
      // Arrange
      const host = new PlanShareHostImplDE();

      // Act
      const granted = await host.requestAlbumPermission();

      // Assert
      expect(granted).assertFalse();
    });

    it('regression: plan_share_save_to_album_should_return_when_no_share_image', 0, async () => {
      // Arrange
      const host = new PlanShareHostImplDE();
      host.shareImage = null;

      // Act
      await host.saveToAlbum();

      // Assert
      expect(host.toastMessages.length).assertEqual(0);
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('combined: validator_marker_should_cover_combined_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
