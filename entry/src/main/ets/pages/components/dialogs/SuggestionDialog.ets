// 文件路径: ets/pages/components/SuggestionDialog.ets

import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SuggestionDialog';

@CustomDialog
export struct SuggestionDialog {
  controller: CustomDialogController;

  itemName: string = '';       // 地点 X (当前)
  conflictName: string = '';   // 地点 Y (前序/冲突源)
  targetTime: string = '';
  suggestedTime: string = '';
  detailMsg: string = '';
  summaryText: string = '';

  // 回调
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
  onBack: () => void = () => {}; // ✅ [新增] 返回上一级菜单

  build() {
    Column() {
      // ... 标题保持不变 ...
      Text('⏳ 调整预览')
        .fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 16 })

      if ((this.summaryText || '').trim().length > 0) {
        Text(this.summaryText)
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(24)
          .width('100%')
          .margin({ bottom: 12 })
      } else {
        // 核心文本 (双色区分)
        Text() {
          Span('地点 ')
          Span(this.itemName)
            .fontColor($r('app.color.text_secondary')) // 🔵 蓝色：当前修改的地点 X
            .fontWeight(FontWeight.Bold)
          Span(' 设定在 ' + this.targetTime + ' 无法实现，和地点 ')
          Span(this.conflictName)
            .fontColor('#7D00FF') // 🟣 紫色：冲突来源 Y
            .fontWeight(FontWeight.Bold)
          Span(' 冲突。\n\n系统建议方案：将 ')
          Span(this.itemName)
            .fontColor($r('app.color.text_secondary')) // 🔵 X
            .fontWeight(FontWeight.Bold)
          Span(' 调整为 ')
          Span(this.suggestedTime)
            .fontColor('#E65100') // 🟠 橙色：最终时间
            .fontSize(18).fontWeight(FontWeight.Bold)
        }
        .fontSize(16).fontColor($r('app.color.text_secondary')).lineHeight(24).margin({ bottom: 12 })
      }

      Text('⚠️ 后果预览：')
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_secondary')).width('100%').margin({ bottom: 4 })

      Scroll() {
        Text(this.detailMsg)
          .fontSize(14).fontColor($r('app.color.text_secondary')).lineHeight(20)
      }
      .height(60).align(Alignment.TopStart).width('100%').margin({ bottom: 20 })

      // 按钮组 (返回 | 放弃 | 确认)
      Row() {
        // 1. 返回按钮 (回到三选一)
        Button('上一步')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.accent_primary'))
          .fontColor(Color.White)
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            hilog.info(0x0000, TAG, `[CONFLICT_UI][preview_back_click] itemName=${this.itemName}, conflictName=${this.conflictName}`);
            this.controller.close();
            setTimeout(() => {
              hilog.info(0x0000, TAG, `[CONFLICT_UI][preview_back_callback] itemName=${this.itemName}`);
              this.onBack(); // 🔙 触发返回
            }, 80);
          })

        Blank().width(12)

        // 2. 确认按钮
        Button('应用修改')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.accent_primary'))
          .fontColor(Color.White)
          .borderRadius(8)
          .height(40)
          .layoutWeight(2) // 权重更大，更显眼
          .onClick(() => {
            this.controller.close();
            this.onConfirm();
          })
      }
      .width('100%')
    }
    .padding(24).backgroundColor($r('app.color.card_bg')).borderRadius(16).width('90%')
  }
}












