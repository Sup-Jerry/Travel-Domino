import { promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { CompactPlanSerializer } from '../../../domain/serializers/CompactPlanSerializer';
import { DeepLinkService } from '../../../domain/services/DeepLinkService';
import { QRCodeService } from '../../../domain/services/QRCodeService';
import { PlanShareImageService, ShareImageOptions } from '../../../domain/services/PlanShareImageService';

@CustomDialog
export struct PlanShareDialog {
  controller: CustomDialogController;
  planId: number = 0;
  planTitle: string = '';
  startDate: number = 0;
  endDate: number = 0;
  totalDays: number = 0;
  totalEvents: number = 0;
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

      const options: ShareImageOptions = {
        planTitle: this.planTitle,
        startDate: this.startDate,
        endDate: this.endDate,
        totalDays: this.totalDays,
        totalEvents: this.totalEvents,
        events: [],
        qrCodePixelMap: qrCode,
        authorName: this.includeAuthor ? this.authorName : undefined,
        shareDate: Date.now()
      };

      this.shareImage = await PlanShareImageService.renderShareImage(options);
      this.safeShowToast('图片生成成功');
    } catch (error) {
      this.safeShowToast('生成失败，请重试');
    } finally {
      this.isGenerating = false;
    }
  }

  private async saveToAlbum(): Promise<void> {
    if (!this.shareImage) {
      return;
    }

    try {
      const context = getContext(this);
      const helper = photoAccessHelper.getPhotoAccessHelper(context);

      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const file = await helper.openAsset('rw', uri);

      const imagePackerApi = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 95 };
      const buffer = await imagePackerApi.packing(this.shareImage, packOpts);

      await file.write(buffer);
      await file.close();

      this.safeShowToast('已保存到相册');
      this.controller.close();
    } catch (error) {
      this.safeShowToast('保存失败，请检查相册权限');
    }
  }
}
