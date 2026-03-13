import { ThemeCenter } from '../../../common/utils/ThemeCenter';

@CustomDialog
export struct PlanSettingsDialog {
  controller: CustomDialogController;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onRename: () => void = () => {};
  onReschedule: () => void = () => {};
  onAutoRouteChange: (enabled: boolean) => void = () => {};
  autoRouteEnabled: boolean = true;

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Column() {
      Row()
        .width(40)
        .height(4)
        .backgroundColor(this.getPalette().divider)
        .borderRadius(2)
        .margin({ top: 12, bottom: 20 });

      Text('计划设置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 24 });

      Row() {
        Text('[R]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('修改计划名称')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('为本次行程设置更清晰的名称')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('>')
          .fontSize(16)
          .fontColor(this.getPalette().textTertiary);
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.controller.close();
        this.onRename();
      });

      Divider().color(this.getPalette().divider).margin({ top: 8, bottom: 8 });

      Row() {
        Text('[D]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('调整出发时间')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('整体平移计划内所有日程')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('>')
          .fontSize(16)
          .fontColor(this.getPalette().textTertiary);
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.controller.close();
        this.onReschedule();
      });

      Divider().color(this.getPalette().divider).margin({ top: 8, bottom: 8 });

      Row() {
        Text('[A]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('自动计算高德通勤时间')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('进入计划或新增地点时，自动计算未锁定地点的通勤时间')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 })
            .maxLines(2);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Toggle({ type: ToggleType.Switch, isOn: this.autoRouteEnabled })
          .selectedColor(this.getPalette().primary)
          .onChange((value: boolean) => {
            this.onAutoRouteChange(value);
          });
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 });

      Button('取消')
        .type(ButtonType.Normal)
        .backgroundColor(this.getPalette().cardBgSoft)
        .fontColor(this.getPalette().textSecondary)
        .width('100%')
        .height(48)
        .borderRadius(12)
        .margin({ top: 32 })
        .onClick(() => {
          this.controller.close();
        });
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 20 })
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}









