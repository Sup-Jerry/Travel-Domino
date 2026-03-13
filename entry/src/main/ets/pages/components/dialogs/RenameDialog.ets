// 文件路径: ets/pages/components/RenameDialog.ets

@CustomDialog
export struct RenameDialog {
  controller: CustomDialogController;
  initName: string = '';
  onConfirm: (newName: string) => void = () => {};

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
            if (this.name.trim().length > 0) {
              this.onConfirm(this.name);
              this.controller.close();
            }
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








