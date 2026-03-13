@CustomDialog
export struct DateConflictDialog {
  controller: CustomDialogController
  conflictDateStr: string = "" // 冲突的日期，如 "05月01日"
  planStartDateStr: string = "" // 计划开始日期，如 "05月05日"
  planStartDate: number = 0
  // 决策回调
  onChangeItemDate: () => void = () => {}      // 选项1: 更改地点日期
  onMoveToBacklog: () => void = () => {}      // 选项2: 放入暂存池
  onChangePlanStartDate: () => void = () => {} // 选项3: 更改计划出发日期
  onCancel: () => void = () => {}

  build() {
    Column() {
      Text("📅 日期逻辑冲突").fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

      Text(`该地点的日期 (${this.conflictDateStr}) 早于计划出发日 (${this.planStartDateStr})。`)
        .fontSize(15).fontColor($r('app.color.text_secondary')).margin({ bottom: 4 }).textAlign(TextAlign.Center)
      Text("请选择处理方式：").fontSize(15).fontColor($r('app.color.text_secondary')).margin({ bottom: 20 })

      // 选项 1
      Button("1. 更改地点日期")
        .onClick(() => { this.onChangeItemDate(); this.controller.close() })
        .width('100%').margin({ bottom: 10 }).backgroundColor($r('app.color.card_bg'))

      // 选项 2
      Button("2. 放入暂存池 (暂不设日期)")
        .onClick(() => { this.onMoveToBacklog(); this.controller.close() })
        .width('100%').margin({ bottom: 10 }).backgroundColor('#666')

      // 选项 3
      Button("3. 更改计划出发日期")
        .onClick(() => { this.onChangePlanStartDate(); this.controller.close() })
        .width('100%').margin({ bottom: 10 }).backgroundColor('#FFA500')

      Text("放弃添加")
        .fontColor(Color.Gray).margin({ top: 10 })
        .onClick(() => { this.onCancel(); this.controller.close() })
    }
    .padding(24).backgroundColor($r('app.color.card_bg')).borderRadius(16).width('90%')
  }
}









