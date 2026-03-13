// 文件路径: ets/pages/components/AiInputDialog.ets
import { promptAction } from '@kit.ArkUI';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';

@CustomDialog
export struct AiInputDialog {
  controller: CustomDialogController
  // 回调函数，将输入文本传回给调用方
  onConfirm: (text: string) => void = (text: string) => {}
  @State inputText: string = ''
  @State isLoading: boolean = false
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light'

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Column() {
      Text('AI 灵感助手 ✨')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 16, top: 8 })

      TextArea({ placeholder: '例如：帮我规划一个西安两日游，想看兵马俑和吃面...' })
        .height(120)
        .backgroundColor(this.getPalette().cardBgSoft)
        .fontColor(this.getPalette().textPrimary)
        .placeholderColor(this.getPalette().textTertiary)
        .borderRadius(8)
        .onChange((value) => {
          this.inputText = value;
        })

      if (this.isLoading) {
        Row() {
          LoadingProgress().width(24).height(24).margin({ right: 8 })
          Text('正在生成行程，请稍候...').fontSize(14).fontColor(this.getPalette().textSecondary)
        }
        .margin({ top: 20 })
      } else {
        Row() {
          Button('取消')
            .height(42)
            .backgroundColor(this.getPalette().cardBg)
            .border({ width: 1, color: this.getPalette().border, radius: 12 })
            .borderRadius(12)
            .fontColor(this.getPalette().textSecondary)
            .onClick(() => {
              this.controller.close();
            })
            .width('40%')

          Button('生成')
            .height(42)
            .backgroundColor(this.getPalette().primary)
            .fontColor(Color.White)
            .borderRadius(12)
            .enabled(this.inputText.trim().length > 0)
            .onClick(() => {
              if (this.inputText.trim().length > 0) {
                this.isLoading = true;
                this.onConfirm(this.inputText);
                // 注意：不立即关闭，等待外部处理（例如成功后再关闭）
              } else {
                promptAction.openToast({ message: '请输入需求' });
              }
            })
            .width('40%')
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .margin({ top: 24 })
      }
    }
    .padding(20)
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(16)
    .width('90%')
  }
}









