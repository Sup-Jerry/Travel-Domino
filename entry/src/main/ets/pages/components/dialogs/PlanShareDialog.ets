import { promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import pasteboard from '@ohos.pasteboard';
import fileIo from '@ohos.file.fs';
import { DeepLinkService } from '../../../domain/services/DeepLinkService';
import { QRCodeService } from '../../../domain/services/QRCodeService';
import { PlanShareImageService, ShareEventItem, ShareImageOptions } from '../../../domain/services/PlanShareImageService';

const MAX_SHARE_EVENTS = 50;
const SAVE_MAX_ATTEMPTS = 2;

export function clampPlanShareEvents(eventsCount: number, maxShareEvents: number = MAX_SHARE_EVENTS): number {
  if (eventsCount <= 0) {
    return 0;
  }
  if (eventsCount > maxShareEvents) {
    return maxShareEvents;
  }
  return eventsCount;
}

export function canCopyPlanShareCompressedText(compressedJson: string): boolean {
  return compressedJson.length > 0;
}

export function resolvePlanShareSaveQuality(attempt: number): number {
  return attempt === 0 ? 95 : 80;
}

@CustomDialog
export struct PlanShareDialog {
  controller: CustomDialogController;
  planId: number = 0;
  planTitle: string = '';
  startDate: number = 0;
  endDate: number = 0;
  totalDays: number = 0;
  totalEvents: number = 0;
  events: ShareEventItem[] = [];
  compressedJson: string = '';

  @State includeAuthor: boolean = false;
  @State authorName: string = '';
  @State shareImage: image.PixelMap | null = null;
  @State isGenerating: boolean = false;

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  build() {
    Column() {
      this.buildHeader()
      this.buildOptions()
      if (this.shareImage) {
        this.buildPreview()
      }
      this.buildActions()
    }
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width('92%')
  }

  @Builder
  buildHeader() {
    Text('分享计划')
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 12 })

    Text('生成精美分享图片，扫码即可导入')
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .margin({ bottom: 16 })
  }

  @Builder
  buildOptions() {
    Row() {
      Text('包含作者信息')
        .fontSize(14)
      Toggle({ type: ToggleType.Switch, isOn: this.includeAuthor })
        .onChange((isOn: boolean) => {
          this.includeAuthor = isOn;
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ bottom: 12 })

    if (this.includeAuthor) {
      TextInput({ placeholder: '输入作者昵称', text: this.authorName })
        .onChange((value: string) => {
          this.authorName = value;
        })
        .margin({ bottom: 12 })
    }
  }

  @Builder
  buildPreview() {
    Text('预览')
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .margin({ bottom: 8 })

    Image(this.shareImage)
      .width('100%')
      .height(300)
      .objectFit(ImageFit.Contain)
      .borderRadius(8)
      .margin({ bottom: 12 })
  }

  @Builder
  buildActions() {
    Row() {
      Button('关闭')
        .backgroundColor('#F0F0F0')
        .fontColor($r('app.color.text_secondary'))
        .width('30%')
        .onClick(() => {
          this.controller.close();
        })

      Button(this.shareImage ? '保存到相册' : '生成分享图片')
        .backgroundColor($r('app.color.card_bg'))
        .fontColor(Color.White)
        .width('65%')
        .enabled(!this.isGenerating)
        .onClick(() => {
          if (this.shareImage) {
            void this.saveToAlbum();
          } else {
            void this.generateShareImage();
          }
        })
    }
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
    .margin({ top: 16 })
  }

  private async generateShareImage(): Promise<void> {
    this.isGenerating = true;
    try {
      const deepLink = DeepLinkService.buildShareLink(this.compressedJson);
      const qrCode = await QRCodeService.generateQRCode(deepLink, 200);
      const renderEvents = this.getRenderableEvents();

      const options: ShareImageOptions = {
        planTitle: this.planTitle,
        startDate: this.startDate,
        endDate: this.endDate,
        totalDays: this.totalDays,
        totalEvents: this.totalEvents,
        events: renderEvents,
        qrCodePixelMap: qrCode,
        authorName: this.includeAuthor ? this.authorName : undefined,
        shareDate: Date.now()
      };

      this.shareImage = await this.renderShareImageWithRetry(options);
      this.safeShowToast('图片生成成功');
    } catch (_error) {
      const copied = await this.copyShareTextToClipboard();
      if (copied) {
        this.safeShowToast('二维码生成失败，已复制文本分享内容');
      } else {
        this.safeShowToast('生成失败，请重试');
      }
    } finally {
      this.isGenerating = false;
    }
  }

  private async saveToAlbum(): Promise<void> {
    if (!this.shareImage) {
      return;
    }

    const granted = await this.requestAlbumPermission();
    if (!granted) {
      this.safeShowToast('未获取相册权限，无法保存图片');
      return;
    }

    try {
      const context = getContext(this);
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      await this.writeImageWithRetry(uri);

      this.safeShowToast('已保存到相册');
      this.controller.close();
    } catch (_error) {
      const copied = await this.copyShareTextToClipboard();
      if (copied) {
        this.safeShowToast('保存失败，已复制文本分享内容');
      } else {
        this.safeShowToast('保存失败，请检查相册权限');
      }
    }
  }

  private async requestAlbumPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenID = bundleInfo.appInfo.accessTokenId;
      const checkStatus = await atManager.checkAccessToken(tokenID, 'ohos.permission.WRITE_IMAGEVIDEO');
      if (checkStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }

      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const requestResult = await atManager.requestPermissionsFromUser(context, ['ohos.permission.WRITE_IMAGEVIDEO']);
      for (let i = 0; i < requestResult.authResults.length; i++) {
        if (requestResult.authResults[i] === 0) {
          return true;
        }
      }
      return false;
    } catch (_error) {
      return false;
    }
  }

  private getRenderableEvents(): ShareEventItem[] {
    const renderableCount = clampPlanShareEvents(this.events.length);
    if (renderableCount >= this.events.length) {
      return this.events;
    }
    this.safeShowToast(`分享图片最多展示 ${MAX_SHARE_EVENTS} 条事件`);
    return this.events.slice(0, renderableCount);
  }

  private async renderShareImageWithRetry(options: ShareImageOptions): Promise<image.PixelMap> {
    try {
      return await PlanShareImageService.renderShareImage(options);
    } catch (_error) {
      const fallbackOptions: ShareImageOptions = {
        planTitle: options.planTitle,
        startDate: options.startDate,
        endDate: options.endDate,
        totalDays: options.totalDays,
        totalEvents: options.totalEvents,
        events: options.events,
        qrCodePixelMap: options.qrCodePixelMap,
        authorName: undefined,
        shareDate: options.shareDate
      };
      return PlanShareImageService.renderShareImage(fallbackOptions);
    }
  }

  private async writeImageWithRetry(uri: string): Promise<void> {
    let lastError: Error | null = null;
    for (let attempt = 0; attempt < SAVE_MAX_ATTEMPTS; attempt++) {
      const quality = resolvePlanShareSaveQuality(attempt);
      try {
        await this.writeImageToUri(uri, quality);
        return;
      } catch (error) {
        if (error instanceof Error) {
          lastError = error;
        }
      }
    }
    throw (lastError ?? new Error('save_failed'));
  }

  private async writeImageToUri(uri: string, quality: number): Promise<void> {
    if (!this.shareImage) {
      throw new Error('no_share_image');
    }
    const imagePackerApi = image.createImagePacker();
    const packOpts: image.PackingOption = { format: 'image/jpeg', quality: quality };
    const buffer = await imagePackerApi.packToData(this.shareImage, packOpts);
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, buffer);
    } finally {
      await fileIo.close(file);
    }
  }

  private async copyShareTextToClipboard(): Promise<boolean> {
    if (!canCopyPlanShareCompressedText(this.compressedJson)) {
      return false;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.compressedJson);
      const board = pasteboard.getSystemPasteboard();
      await board.setData(data);
      return true;
    } catch (_error) {
      return false;
    }
  }
}



