// 文件路径: ets/pages/components/RenameDialog.ets

type RenameDialogConfirmAction = (newName: string) => void;

export function normalizeRenameDialogName(input: string): string {
  return (input || '').trim();
}

export function canRenameDialogSubmit(input: string): boolean {
  return normalizeRenameDialogName(input).length > 0;
}

export function confirmRenameDialog(
  input: string,
  onConfirm: (newName: string) => void,
  close: () => void
): boolean {
  if (!canRenameDialogSubmit(input)) {
    return false;
  }
  onConfirm(input);
  close();
  return true;
}

@CustomDialog
export struct RenameDialog {
  controller: CustomDialogController;
  initName: string = '';
  onConfirm: RenameDialogConfirmAction = () => {};

  @State name: string = '';

  aboutToAppear() {
    this.name = this.initName;
  }

  build() {
    Column() {
      Text('修改计划名称')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })

      TextInput({ text: this.name, placeholder: '请输入计划名称' })
        .maxLength(20) // 限制长度
        .onChange((value: string) => {
          this.name = value;
        })
        .margin({ bottom: 20 })
        .width('100%')

      Row() {
        Button('取消')
          .backgroundColor($r('app.color.card_bg'))
          .fontColor($r('app.color.text_secondary'))
          .width('40%')
          .onClick(() => {
            this.controller.close();
          })

        Blank()

        Button('确定')
          .width('40%')
          .onClick(() => {
            confirmRenameDialog(this.name, this.onConfirm, (): void => this.controller.close());
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width('80%') // 弹窗宽度
  }
}
