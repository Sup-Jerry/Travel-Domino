import { promptAction } from '@kit.ArkUI';
import { PlanJsonImportCancelToken } from '../../../infrastructure/services/PlanImportExportService';

export function normalizePlanJsonImportInput(inputJson: string): string {
  return inputJson.trim();
}

export function canStartPlanJsonImport(inputJson: string): boolean {
  return normalizePlanJsonImportInput(inputJson).length > 0;
}

export function cancelPlanJsonImport(
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
export struct PlanJsonImportDialog {
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
    const raw = normalizePlanJsonImportInput(this.inputJson);
    if (!canStartPlanJsonImport(this.inputJson)) {
      this.safeShowToast('请先粘贴 JSON 内容');
      return;
    }
    this.importCancelToken = new PlanJsonImportCancelToken();
    this.importing = true;
    try {
      await this.onImport(raw, this.importCancelToken);
      this.controller.close();
    } finally {
      this.importCancelToken = null;
      this.importing = false;
    }
  }

  build() {
    Column() {
      Text('导入计划 JSON')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })

      Text('粘贴导出的完整 JSON，导入后会创建一个新计划。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 10 })

      TextArea({ placeholder: '请粘贴 JSON ...', text: this.inputJson })
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
            cancelPlanJsonImport(this.importing, this.importCancelToken, (): void => this.controller.close());
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


