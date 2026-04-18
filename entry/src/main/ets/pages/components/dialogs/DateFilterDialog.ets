// 文件路径: ets/pages/components/DateFilterDialog.ets

export type DateFilterDialogAction = 'show_all' | 'select_date' | 'select_range';

export interface DateFilterDialogOption {
  action: DateFilterDialogAction;
  title: string;
  description: string;
}

export function getDateFilterDialogOptions(): DateFilterDialogOption[] {
  return [
    {
      action: 'show_all',
      title: '显示全部行程',
      description: '展开所有日期的完整时间轴'
    },
    {
      action: 'select_date',
      title: '选择具体日期',
      description: '专注某一天的游玩计划'
    },
    {
      action: 'select_range',
      title: '选择日期范围',
      description: '查看比如 26号 到 29号 之间的行程'
    }
  ];
}

export function getDateFilterDialogActions(): DateFilterDialogAction[] {
  return getDateFilterDialogOptions().map((item: DateFilterDialogOption) => item.action);
}

export function isDateFilterDialogActionSupported(action: string): boolean {
  return getDateFilterDialogActions().indexOf(action as DateFilterDialogAction) >= 0;
}

@CustomDialog
export struct DateFilterDialog {
  controller: CustomDialogController;

  // 回调
  onShowAll: () => void = () => {};
  onSelectDate: () => void = () => {};
  // ✅ [新增] 范围选择回调
  onSelectRange: () => void = () => {};

  build() {
    Column() {
      // 1. 顶部装饰条
      Row()
        .width(40)
        .height(4)
        .backgroundColor('#E0E0E0')
        .borderRadius(2)
        .margin({ top: 12, bottom: 20 })

      // 2. 标题区
      Text('日期筛选')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Text('只查看特定日期的行程，让视图更清爽')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 24 })

      // 3. 选项 A: 显示全部
      Row() {
        Text('♾️').fontSize(20).margin({ right: 16 })
        Column() {
          Text('显示全部行程').fontSize(16).fontColor($r('app.color.text_secondary')).fontWeight(FontWeight.Medium)
          Text('展开所有日期的完整时间轴').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 4 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('>').fontSize(16).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor(Color.Transparent)
      .onClick(() => {
        this.controller.close();
        this.onShowAll();
      })

      Divider().color('#F5F5F5').margin({ top: 8, bottom: 8 })

      // 4. 选项 B: 选择具体日期 (单日)
      Row() {
        Text('📅').fontSize(20).margin({ right: 16 })
        Column() {
          Text('选择具体日期').fontSize(16).fontColor($r('app.color.text_secondary')).fontWeight(FontWeight.Medium)
          Text('专注某一天的游玩计划').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 4 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('>').fontSize(16).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.controller.close();
        this.onSelectDate();
      })

      Divider().color('#F5F5F5').margin({ top: 8, bottom: 8 })

      // 5. ✅ [新增] 选项 C: 选择日期范围
      Row() {
        Text('↔️').fontSize(20).margin({ right: 16 }) // 双向箭头图标
        Column() {
          Text('选择日期范围').fontSize(16).fontColor($r('app.color.text_secondary')).fontWeight(FontWeight.Medium)
          Text('查看比如 26号 到 29号 之间的行程').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 4 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('>').fontSize(16).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.controller.close();
        this.onSelectRange(); // 触发新回调
      })

      // 6. 取消按钮
      Button('取消')
        .type(ButtonType.Normal)
        .backgroundColor($r('app.color.card_bg'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .height(48)
        .borderRadius(12)
        .margin({ top: 32 })
        .onClick(() => {
          this.controller.close();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 20 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}









