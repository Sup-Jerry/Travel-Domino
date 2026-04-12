// 文件路径: ets/pages/components/ConflictSelectionDialog.ets


export function getConflictSelectionGapPrompt(gapMinutes: number): string {
  return `?????????? ${gapMinutes} ???????????`;
}

export function shouldUseConflictAdvanceAdjust(hasAdvanceAdjust: boolean): boolean {
  return hasAdvanceAdjust;
}

@CustomDialog
export struct ConflictSelectionDialog {
  controller: CustomDialogController;

  gapMinutes: number = 0; // 缺口时间 (冲突了多少分钟)

  // 回调
  onDelayY: () => void = () => {};        // 方案1: 延迟自己
  onCompressX: () => void = () => {};     // 方案2: 选择前序地点压缩
  onShiftSameDay: () => void = () => {};  // 兼容回调
  onAdvanceAdjust: () => void = () => {}; // 方案3: 前移调整
  onSmartAdjust: () => void = () => {};   // 兼容保留，不再展示入口
  onCancel: () => void = () => {};        // 关闭

  build() {
    Column() {
      // 标题栏 + 关闭按钮
      Row() {
        Text('⚠️ 行程冲突')
          .fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Text('✕') // 关闭按钮
          .fontSize(20).fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
            this.onCancel();
          })
      }
      .width('100%').margin({ bottom: 20 })

      Text(`当前设置导致行程重叠 ${this.gapMinutes} 分钟，请选择处理方式：`)
        .fontSize(15).fontColor($r('app.color.text_secondary')).margin({ bottom: 20 })

      // 选项 A: 顺延 (延迟 Y)
      this.OptionCard(
        '🕐', '向后顺延', '保持前序行程时长，当前地点推迟开始', '#E3F2FD', '#007DFF',
        () => { this.controller.close(); this.onDelayY(); }
      )

      // 选项 B: 强压 (压缩 X)
      this.OptionCard(
        '🙌', '压缩前序', '选择前序地点并按策略压缩，保持当前开始时间', '#FCE4EC', '#D81B60',
        () => { this.controller.close(); this.onCompressX(); }
      )

      // 选项 C: 前移调整
      this.OptionCard(
        '⏪', '前移调整', '选择同 DayX 前序连续地点并设置新的开始时间', '#E8F5E9', '#2E7D32',
        () => {
          this.controller.close();
          if (shouldUseConflictAdvanceAdjust(!!this.onAdvanceAdjust)) {
            this.onAdvanceAdjust();
            return;
          }
          this.onShiftSameDay();
        }
      )
    }
    .padding(24)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width('90%')
  }

  @Builder
  OptionCard(icon: string, title: string, desc: string, bg: string, color: string, action: () => void) {
    Row() {
      Text(icon).fontSize(24).margin({ right: 16 })
      Column() {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(color).margin({ bottom: 4 })
        Text(desc).fontSize(12).fontColor($r('app.color.text_secondary')).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(24).fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor(bg) // 淡色背景
    .borderRadius(12)
    .margin({ bottom: 12 })
    .onClick(action)
  }
}











