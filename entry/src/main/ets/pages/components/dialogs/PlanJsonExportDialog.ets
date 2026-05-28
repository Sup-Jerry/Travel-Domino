import pasteboard from '@ohos.pasteboard';
import { promptAction } from '@kit.ArkUI';

export function canCopyPlanJsonText(jsonText: string): boolean {
  return jsonText.length > 0;
}

@CustomDialog
export struct PlanJsonExportDialog {
  controller: CustomDialogController;
  jsonText: string = '';

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private async copyJson(): Promise<void> {
    if (!canCopyPlanJsonText(this.jsonText)) {
      this.safeShowToast('没有可复制的内容');
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.jsonText);
      const board = pasteboard.getSystemPasteboard();
      await board.setData(data);
      this.safeShowToast('JSON 已复制到剪贴板');
    } catch (_error) {
      this.safeShowToast('复制失败，请手动长按复制');
    }
  }

  private handleCloseClick(): void {
    this.controller.close();
  }

  private handleCopyClick(): void {
    void this.copyJson();
  }

  build() {
    Column() {
      Text('导出计划 JSON')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })

      Text('可复制后保存到备忘录；卸载重装后在“导入JSON”粘贴恢复。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 10 })

      TextArea({ text: this.jsonText })
        .height(320)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(8)
        .fontSize(12)

      Row() {
        Button('关闭')
          .backgroundColor('#F0F0F0')
          .fontColor($r('app.color.text_secondary'))
          .width('42%')
          .onClick(() => {
            this.handleCloseClick();
          })

        Button('复制JSON')
          .backgroundColor($r('app.color.card_bg'))
          .fontColor(Color.White)
          .width('42%')
          .onClick(() => {
            this.handleCopyClick();
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












