import { promptAction } from '@kit.ArkUI';
import { PlanJsonImportCancelToken } from '../../../infrastructure/services/PlanImportExportService';
import { DeepLinkService } from '../../../domain/services/DeepLinkService';
import { CompactPlanSerializer } from '../../../domain/serializers/CompactPlanSerializer';

export type PlanImportPayloadKind = 'empty' | 'deep_link' | 'compressed' | 'plain';

export function classifyPlanImportPayload(rawInput: string): PlanImportPayloadKind {
  const raw = rawInput.trim();
  if (raw.length === 0) {
    return 'empty';
  }
  if (raw.startsWith('travelapp://import')) {
    return 'deep_link';
  }
  if (raw.startsWith('{"v":1')) {
    return 'compressed';
  }
  return 'plain';
}

export function canStartPlanImport(rawInput: string): boolean {
  return classifyPlanImportPayload(rawInput) !== 'empty';
}

export function cancelPlanImport(
  importing: boolean,
  cancelToken: PlanJsonImportCancelToken | null,
  close: () => void
): void {
  if (importing && cancelToken) {
    cancelToken.cancel();
  }
  close();
}

@CustomDialog
export struct PlanImportDialog {
  controller: CustomDialogController;
  onImport: (jsonText: string, cancelToken: PlanJsonImportCancelToken) => Promise<void> =
    async (_jsonText: string, _cancelToken: PlanJsonImportCancelToken) => {};
  @State inputJson: string = '';
  @State importing: boolean = false;
  private importCancelToken: PlanJsonImportCancelToken | null = null;

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private async doImport(): Promise<void> {
    const raw = this.inputJson.trim();
    if (!canStartPlanImport(raw)) {
      this.safeShowToast('请先粘贴分享数据');
      return;
    }

    let jsonToImport = raw;
    const payloadKind = classifyPlanImportPayload(raw);

    // 检测是否为 Deep Link
    if (payloadKind === 'deep_link') {
      try {
        const compressedJson = DeepLinkService.parseShareLink(raw);
        const decompressed = CompactPlanSerializer.decompressFromShare(compressedJson);
        jsonToImport = JSON.stringify({ schemaVersion: 1, exportedAt: Date.now(), sourcePlanId: 0, plan: decompressed.plan, events: decompressed.events });
      } catch (error) {
        this.safeShowToast('Deep Link 解析失败');
        return;
      }
    }
    // 检测是否为压缩格式
    else if (payloadKind === 'compressed') {
      try {
        const decompressed = CompactPlanSerializer.decompressFromShare(raw);
        jsonToImport = JSON.stringify({ schemaVersion: 1, exportedAt: Date.now(), sourcePlanId: 0, plan: decompressed.plan, events: decompressed.events });
      } catch (error) {
        this.safeShowToast('压缩数据解析失败');
        return;
      }
    }

    this.importCancelToken = new PlanJsonImportCancelToken();
    this.importing = true;
    try {
      await this.onImport(jsonToImport, this.importCancelToken);
      this.controller.close();
    } finally {
      this.importCancelToken = null;
      this.importing = false;
    }
  }

  build() {
    Column() {
      Text('导入计划')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })

      Text('粘贴分享数据或扫码导入，将创建一个新计划。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 10 })

      TextArea({ placeholder: '请粘贴分享数据或 Deep Link ...', text: this.inputJson })
        .height(320)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(8)
        .fontSize(12)
        .onChange((value: string) => {
          this.inputJson = value;
        })

      if (this.importing) {
        Row() {
          LoadingProgress().width(20).height(20).margin({ right: 6 })
          Text('正在导入...')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: 10 })
      }

      Row() {
        Button('取消')
          .backgroundColor('#F0F0F0')
          .fontColor($r('app.color.text_secondary'))
          .width('42%')
          .onClick(() => {
            cancelPlanImport(this.importing, this.importCancelToken, (): void => this.controller.close());
          })

        Button('开始导入')
          .backgroundColor($r('app.color.card_bg'))
          .fontColor(Color.White)
          .width('42%')
          .enabled(!this.importing)
          .onClick(() => {
            void this.doImport();
          })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')
      .margin({ top: 16 })
    }
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width('92%')
  }
}

